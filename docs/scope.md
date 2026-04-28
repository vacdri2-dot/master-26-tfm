# Scope and Deliverables

## In scope

- Complete Terraform code for the entire infrastructure (reusable modules)
- Functional application with at least 3 specialized agents + orchestrator
- Functional CI/CD pipelines for infrastructure and applications
- Dual observability system: Azure Monitor (infra) + LangFuse (LLM/agents)
- Automated agent evaluation pipeline (iteration 2)
- Technical documentation and deployment guide
- Public GitHub repository with all the code
- Simplified graphical interface for general testing of the orchestrator agent (iteration 2; MVP uses API/CLI for demo)

## Out of scope

- AI model training or fine-tuning
- Multi-region deployment or advanced disaster recovery

---

## Success KPIs

| KPI | Target | Measurement method |
|-----|--------|--------------------|
| Full deployment time (`terraform apply` from scratch) | < 20 min (excl. initial Azure OpenAI provisioning) | Pipeline start/end timestamp |
| Reduction vs. manual deployment | > 75% | Documented comparison |
| Estimated monthly cost | < 200 EUR | Azure Cost Management |
| Agent response quality | > 80% accuracy | Automated evaluation pipeline |
| End-to-end latency | < 30s (P95) | Application Insights |
| Tracing coverage (infra) | 100% of requests | OpenTelemetry + App Insights |
| Tracing coverage (LLM) | 100% of GPT-4o calls | LangFuse dashboard |
| Public endpoints with sensitive data | 0 | Network topology review |

---

## Thesis structure

| Ch. | Title | Main contents |
|-----|-------|---------------|
| 1 | Introduction and context | Motivation, state of the art in multi-agent systems, objectives |
| 2 | Architecture design | Cloud architecture, multi-agent pattern, design decisions |
| 3 | Terraform implementation | Modules, remote state, environments, IaC best practices |
| 4 | Agent development | Implementation of each agent, orchestration, communication |
| 5 | CI/CD and automation | Pipelines, testing, deployment strategies |
| 6 | Observability and evaluation | Dual tracing (App Insights + LangFuse), metrics, dashboards, agent evaluation |
| 7 | Results and validation | KPIs, cost analysis, benchmarks, lessons learned |
| 8 | Conclusions and future work | Summary of achievements, improvement areas, and evolution |
