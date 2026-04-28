# System Architecture

## High-level diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                        User / UI                                │
└─────────────────────────┬───────────────────────────────────────┘
                          │ HTTP
                          ▼
┌─────────────────────────────────────────────────────────────────┐
│                    API Gateway (Ingress)                        │
│                   Azure Container Apps                          │
└─────────────────────────┬───────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────────┐
│                     Orchestrator Agent                          │
│         LangGraph + GPT-4o  │  FastAPI  │  Container App        │
│                             │                                   │
│  1. Receives task from user                                     │
│  2. Analyzes and generates a subtask plan                       │
│  3. Delegates to specialized agents                             │
│  4. Composes the final response                                 │
└──────────┬───────────────────────────┬──────────────────────────┘
           │                           │
           ▼                           ▼
┌──────────────────────┐   ┌───────────────────────┐
│     RAG Agent        │   │      Code Agent        │
│  FastAPI │ Container │   │  FastAPI │ Container   │
│                      │   │                        │
│  - Receives query    │   │  - Receives task       │
│  - Searches AI Search│   │  - Generates code      │
│  - Returns relevant  │   │  - Executes in sandbox │
│    context           │   │  - Returns result      │
└──────────┬───────────┘   └───────────┬────────────┘
           │                           │
           ▼                           ▼
┌──────────────────────┐   ┌───────────────────────┐
│   Azure AI Search    │   │  Container Apps Jobs   │
│  + Blob Storage      │   │  (execution sandbox)   │
│  (RAG documents)     │   │                        │
└──────────────────────┘   └───────────────────────┘

                    Cross-cutting concerns:
┌─────────────────────────────────────────────────────────────────┐
│  Infra observability:  OpenTelemetry → Application Insights     │
│    HTTP traces, container health, latency, scaling events       │
├─────────────────────────────────────────────────────────────────┤
│  LLM observability:    LangFuse (Container App + PostgreSQL)    │
│    Tokens, costs, prompts, completions, evaluations,            │
│    LangGraph traces                                             │
└─────────────────────────────────────────────────────────────────┘
```

---

## Typical execution flow

```
1. User sends a question or task to the API Gateway

2. Orchestrator receives the request
   └── Analyzes with GPT-4o whether it needs to:
       ├── Search documents     → delegates to RAG Agent
       ├── Execute code         → delegates to Code Agent
       └── Direct response      → responds without delegating

3. RAG Agent (if applicable)
   └── Generates embedding for the query
   └── Searches for relevant chunks in Azure AI Search
   └── Returns context to the Orchestrator

4. Code Agent (if applicable)
   └── Generates code with GPT-4o
   └── Executes in Container Apps Job (isolated sandbox)
   └── Returns output to the Orchestrator

5. Orchestrator composes the final response
   └── Integrates results from agents
   └── Returns response to the user

6. The entire flow is traced in two layers:
   └── Application Insights: HTTP latency, health, errors
   └── LangFuse: tokens consumed, cost, prompt/completion, orchestrator decisions
```

---

## Infrastructure layers

```
┌─────────────────────────────────────────────────────────────────┐
│  Network & Security                                             │
│  VNet → Subnets → Private Endpoints → NSGs                     │
│  Key Vault · Managed Identity · RBAC                           │
├─────────────────────────────────────────────────────────────────┤
│  Compute                                                        │
│  Container Apps Environment                                     │
│  ├── orchestrator (Container App)                               │
│  ├── rag-agent    (Container App)                               │
│  ├── code-agent   (Container App)                               │
│  └── code-sandbox (Container Apps Jobs)                         │
├─────────────────────────────────────────────────────────────────┤
│  Data                                                           │
│  Azure AI Search · Blob Storage                                 │
├─────────────────────────────────────────────────────────────────┤
│  AI                                                             │
│  Azure OpenAI Service                                           │
│  ├── GPT-4o (orchestration + agents)                            │
│  └── text-embedding-3-small (RAG)                               │
├─────────────────────────────────────────────────────────────────┤
│  Observability                                                  │
│  Application Insights · Log Analytics · Azure Monitor (infra)   │
│  LangFuse · PostgreSQL Flexible Server (LLM/agents)             │
└─────────────────────────────────────────────────────────────────┘
```

---

## Terraform Modules

| Module | Main resources |
|--------|---------------|
| `modules/networking` | VNet, subnets, NSGs, private DNS, private endpoints |
| `modules/security` | Key Vault, Managed Identities, RBAC assignments |
| `modules/compute` | Container Apps Environment, Container Apps, Container Registry |
| `modules/data` | AI Search, Blob Storage |
| `modules/ai` | Azure OpenAI deployments (GPT-4o + embeddings) |
| `modules/observability` | Application Insights, Log Analytics, alerts |
| `modules/langfuse` | LangFuse Container App, PostgreSQL Flexible Server |

---

## Agent communication

- Each agent exposes a REST API via FastAPI
- The Orchestrator calls agents over internal HTTP (private ingress)
- All communication occurs within the VNet (no public traffic between agents)
- LangGraph manages the execution graph and workflow state in the Orchestrator

### Resilience and timeouts

| Parameter | Default value | Notes |
|-----------|--------------|-------|
| HTTP timeout per request | 60s | Configurable per agent; Code Agent may need more |
| Retry policy | 1 retry with exponential backoff | Only for 5xx errors |
| Health check | `GET /health` | Liveness + readiness probes on each Container App |
| Circuit breaker | No (MVP) | Evaluate in iteration 2 if needed |

---

## Conversation state (MVP)

In-memory state (stateless per request). No conversation persistence in iteration 1.
CosmosDB is evaluated for iteration 2 if conversation history is needed.

---

## Code Agent — Sandbox Security

The Code Agent executes code generated by an LLM. This is the largest attack surface in the project.

### Sandbox isolation (Container Apps Jobs)

| Control | Detail |
|---------|--------|
| Network | No internet access; can only respond to the Code Agent via private ingress |
| Resources | CPU and memory limited by Job configuration (e.g. 0.5 vCPU, 1GB RAM) |
| Timeout | Hard maximum execution time (e.g. 30s); the Job is killed if exceeded |
| Runtime | Python only; no additional packages may be installed at runtime |
| Persistence | None between executions; each Job is ephemeral (read-only filesystem except /tmp) |
| Sanitization | Code Agent validates that code does not import forbidden modules (os, subprocess, socket, etc.) before sending it to the sandbox |

---

## External ingress authentication

The Orchestrator is the only agent exposed to the public internet (`external_ingress = true` in `infra/modules/compute/main.tf`). The RAG and Code agents use private ingress and are only reachable from inside the VNet.

### Mechanism (MVP — iteration 1)

API key authentication implemented as a FastAPI dependency in `shared/src/shared/auth.py`:

| Aspect | Detail |
|--------|--------|
| Scheme | `Authorization: Bearer <api_key>` |
| Expected key source | Environment variable `ORCHESTRATOR_API_KEY`, populated in the Container App from a Key Vault secret reference |
| Comparison | Constant-time (`secrets.compare_digest`) to avoid timing side channels |
| Response on failure | `401 Unauthorized` with `WWW-Authenticate: Bearer` header |
| Public routes | Only `/health` — always reachable without a token for Container App liveness/readiness probes |

Activation is opt-in via the `api_key` parameter of `shared.app.create_app`. When the parameter is `None` (or the env var is unset), no auth is enforced — the current MVP state, since the orchestrator only exposes `/health`. Task-execution endpoints added in iteration 2 attach the dependency exposed at `app.state.auth_dependency`.

### Iteration 2

- Migrate to JWT from Microsoft Entra ID (validated against OIDC discovery and an App Registration `audience` claim), eliminating the shared secret and enabling per-caller revocation
- Optionally place Azure API Management or Application Gateway in front of the Orchestrator and set `external_ingress = false` on the Container App

---

## Design decisions

| Decision | Discarded alternative | Reason |
|----------|-----------------------|--------|
| Azure Container Apps | AKS | Lower operational complexity, built-in KEDA, no K8s cluster to manage |
| LangGraph | Semantic Kernel / AutoGen / custom | Known by the team, visualizable, active community, Python-first |
| FastAPI per agent | Single monolithic service | Independent lifecycle, per-agent scaling, real microservices |
| Python | TypeScript | Standard AI ecosystem, accessible to the whole team |
| Managed Identity | API keys in environment variables | No secrets in code, Azure best practice |
| LangFuse (self-hosted) | Azure Monitor only / Arize SaaS | Open source, self-hostable (more Terraform infra), native LangGraph integration, complements App Insights |
