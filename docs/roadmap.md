# Project Roadmap

## Overview

The project is divided into 2 main iterations. The goal is to have a functional, demonstrable MVP before moving on to advanced features.

---

## Iteration 1 — MVP

**Goal:** Functional end-to-end demo. Someone sends a task, the orchestrator decides, delegates, and returns a response. Everything deployed with a single `terraform apply`.

### Infrastructure (Terraform)
- [x] `networking` module — VNet, subnets, private endpoints
- [x] `security` module — Key Vault, Managed Identity, RBAC
- [ ] `compute` module — Container Apps Environment + Container Registry
- [ ] `data` module — AI Search + Blob Storage
- [x] `ai` module — Azure OpenAI (GPT-4o + embeddings)
- [x] `observability` module — Application Insights + Log Analytics
- [ ] `langfuse` module — LangFuse Container App + PostgreSQL Flexible Server
- [x] Remote state in Azure Storage (Terraform backend)
- [ ] Functional `dev` environment

### Agents
- [ ] **Orchestrator** — LangGraph + GPT-4o, delegation logic
- [ ] **RAG Agent** — FastAPI + Azure AI Search + embeddings
- [ ] **Code Agent** — FastAPI + GPT-4o + Container Apps Jobs (sandbox)
- [ ] Internal HTTP communication between agents (private ingress)

### CI/CD
- [ ] GitHub Actions pipeline: `terraform plan` on PR, `terraform apply` on merge to main
- [ ] GitHub Actions pipeline: build + push Docker images to ACR
- [ ] Automatic deploy to Container Apps after push

### Observability (two layers)
- [ ] **Infra (Azure Monitor):** OpenTelemetry integrated in all 3 agents → App Insights
- [ ] HTTP tracing: user → orchestrator → agent → response
- [ ] Container metrics: latency, errors, health, scaling
- [ ] **LLM (LangFuse):** LangFuse callback handler in LangGraph
- [ ] Token usage and cost per request
- [ ] Prompt/completion logging for every GPT-4o call
- [ ] LangGraph execution traces (which agent was called and why)

### Infra emphasis — what differentiates the demo
> The MVP agents are maintained (Orchestrator + RAG + Code). The differentiator of the thesis
> is the quality of the cloud platform, not the number of agents. Spend extra MVP time
> on these infrastructure points:

- [ ] **Azure Monitor Dashboard** — live agent metrics panel (latency, tokens, costs per request)
- [ ] **Auto-scaling rules** in Container Apps — KEDA rules to scale agents under load
- [ ] **Health probes + restart policies** — liveness/readiness on each Container App
- [ ] **Documented cost breakdown** — monthly cost idle vs. under load (Azure Cost Management)
- [ ] **Destroy/apply demo** — prepare script for full `terraform destroy` + `terraform apply` in < 20 min as a wow moment

### MVP success criteria
- `terraform apply` from scratch in < 20 minutes (excl. initial Azure OpenAI provisioning)
- Working end-to-end demo: question → orchestrator → agent → response
- Tracing flow visible in Application Insights
- Azure Monitor dashboard with agent metrics accessible during the demo
- Health probes responding on all 3 Container Apps

---

## Iteration 2 — Full Platform

**Goal:** Production-ready platform with automated evaluation, enhanced security, and demo UI.

### Additional agents
- [ ] **API Agent** — integration with external APIs via Function Calling
- [ ] **Evaluator Agent** — validates response quality before delivering

### Automated evaluation
- [ ] Evaluation pipeline: LLM-as-a-judge (primary)
- [ ] Task completion rate (did the orchestrator delegate correctly?)
- [ ] Latency and cost per query
- [ ] Exact match for queries with a fixed factual answer
- [ ] Azure Monitor dashboards with evaluation results
- [ ] Automatic rollback if metrics drop below threshold

### Advanced infrastructure
- [ ] Multi-environment: `dev` + `staging` (Terraform workspaces)
- [ ] CosmosDB for conversation state
- [ ] Azure Firewall (if budget allows)

### Advanced CI/CD
- [ ] Manual `dev → staging` promotion with required approval
- [ ] Post-deploy integration tests
- [ ] Docker image security scan (Trivy)

### Demo UI (Frontend)
- [ ] Next.js (TypeScript) — chat interface
- [ ] Side panel with real-time tracing (orchestrator → agents)
- [ ] Deployed on Azure Static Web Apps or Container App

### Advanced observability
- [ ] Complete dashboards in Azure Monitor
- [ ] Configured alerts (latency, errors, cost)
- [ ] Structured logs with full context per decision

---

## KPIs to validate (final)

| KPI | Target |
|-----|--------|
| Full deployment time (`terraform apply` from scratch) | < 20 min (excl. initial Azure OpenAI provisioning) |
| Estimated monthly cost (idle infra) | < 200 EUR |
| Response quality (LLM-as-a-judge) | > 80% |
| End-to-end latency | < 30s (P95) |
| Tracing coverage | 100% of requests |
| Public endpoints with sensitive data | 0 |

---

## Suggested work division (4 people)

| Area | Suggested owner | Deliverables |
|------|----------------|--------------|
| Terraform (networking, security, compute) | 1 person (A) | Core Terraform modules, infra critical path |
| Shared library + Orchestrator | 1 person (B) | FastAPI base, Pydantic models, orchestrator agent |
| Terraform data/AI + RAG Agent | 1 person (C) | Data/AI modules, RAG agent, indexing |
| CI/CD + Code Agent + LangFuse | 1 person (D) | GitHub Actions pipelines, Code Agent sandbox, LangFuse infra |

> See the full week-by-week playbook in Linear: [MVP Execution Playbook](https://linear.app/master-26-tfm/document/playbook-de-ejecucion-mvp-semana-a-semana-4b0d1c35955a)
