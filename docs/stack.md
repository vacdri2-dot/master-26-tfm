# Technology Stack — MVP

## Context
TFM: Autonomous AI Agents Platform on Azure with Terraform
Master's in Cloud Computing and Artificial Intelligence — March 2026
Team: 4 people

---

## MVP: Orchestrator + RAG Agent + Code Agent

### Backend (Python)

| Layer | Technology | Version | Notes |
|-------|-----------|---------|-------|
| Language | Python | 3.12+ | Standard in the AI ecosystem |
| API framework | FastAPI | latest | Async, typed with Pydantic, OpenAPI autodoc |
| Agent orchestration | LangGraph | latest | Orchestrator-Worker pattern, visualizable graph |
| LLM client | Azure OpenAI SDK | latest | GPT-4o + text-embedding-3-small |
| Observability (infra) | OpenTelemetry Python | latest | End-to-end distributed tracing |
| Observability (LLM) | LangFuse | latest | Token tracking, costs, prompt tracing, evaluations |
| Dependencies | uv | latest | Lockfiles, PEP 621, pyproject.toml per agent |
| Containers | Docker | latest | One image per agent |

### Infrastructure (Terraform)

| Resource | Azure Service | Notes |
|----------|--------------|-------|
| Compute | Azure Container Apps | One Container App per agent |
| Registry | Azure Container Registry | Docker images |
| LLM | Azure OpenAI Service | GPT-4o + embeddings |
| Vector search | Azure AI Search | RAG Agent |
| Storage | Azure Blob Storage | Documents for RAG |
| Secrets | Azure Key Vault | API keys, connection strings |
| Identity | Managed Identity | No credentials in code |
| Observability (infra) | Application Insights + Log Analytics | HTTP traces, container metrics, logs |
| Observability (LLM) | LangFuse (Container App + PostgreSQL) | Tokens, costs, prompts, agent evaluations |
| Networking | Virtual Network + Private Endpoints | Private communication between services |

### CI/CD

| Layer | Technology | Notes |
|-------|-----------|-------|
| Pipelines | GitHub Actions | IaC + image build/push |
| IaC | Terraform | Remote state in Azure Storage |

### Frontend (Demo UI — iteration 2)

| Layer | Technology | Notes |
|-------|-----------|-------|
| Framework | Next.js (TypeScript) | Chat interface for the committee |
| API call | REST → API Gateway | Consumes the orchestrator |
| Visualization | Real-time tracing panel | Shows orchestrator → agents flow |

---

## MVP Agents

| Agent | Responsibility | Tech |
|-------|---------------|------|
| Orchestrator | Receives task, decomposes, delegates, composes final response | LangGraph + GPT-4o |
| RAG Agent | Queries indexed documents | Azure AI Search + embeddings |
| Code Agent | Generates and executes code in sandbox | GPT-4o + Container Apps Jobs |

> API Agent and Evaluator are deferred to iteration 2.

---

## Out of MVP scope

- CosmosDB for conversation state (MVP is stateless per request, state in memory)
- Multi-environment (only `dev` in MVP)
- Automated evaluations (iteration 2)
- Automatic rollback (iteration 2)
- Interactive frontend (iteration 2; MVP uses API/CLI for demo)

---

## Key decisions

- **Container Apps over AKS**: lower operational complexity, built-in KEDA, Dapr available for inter-agent communication.
- **LangGraph over Semantic Kernel / custom**: known by the team, visualizable, mature, active community.
- **Python for agents**: standard AI ecosystem, accessible to the whole team.
- **TypeScript only in UI**: clean backend/frontend separation.
- **LangFuse over Azure Monitor alone**: Azure Monitor covers infra (HTTP, containers, scaling); LangFuse covers the LLM layer (tokens, costs, prompts, quality). They are complementary — two dashboards, two stories.
- **LangFuse over Arize/Braintrust/MLFlow**: open source, self-hostable as a Container App (more Terraform), native LangGraph integration, built-in evaluations. MLFlow is for ML training, not LLM tracing.
