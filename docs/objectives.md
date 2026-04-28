# Project Objectives

## General objective

Design and implement a modular architecture on Azure that enables deploying, orchestrating, and monitoring autonomous AI agents, managing the full infrastructure lifecycle with Terraform.

---

## Specific objectives

1. Design a microservices architecture where each AI agent is an independently deployable service on Azure Container Apps.
2. Implement an orchestrator agent capable of decomposing complex tasks and delegating them to specialized agents (RAG, code, APIs, analysis).
3. Create reusable Terraform modules for the entire infrastructure: networking, compute, data, AI, security, and observability.
4. Build CI/CD pipelines with GitHub Actions for automated deployment of infrastructure and applications.
5. Implement end-to-end observability with distributed tracing that allows visualizing the complete agent execution flow.
6. Design an automated evaluation system that measures response quality and the efficiency of the multi-agent system.
7. Validate the platform with cost, performance, deployment time, and reliability metrics.

---

## Approach and key differentiators

| Differentiator | Description |
|----------------|-------------|
| Multi-agent vs. monolithic | Instead of a single AI service, multiple specialized agents collaborate via an orchestration pattern |
| Agents as microservices | Each agent is deployed as an independent container with its own lifecycle, scaling, and versioning |
| Agent observability | Full traceability of every decision, delegation, and result through distributed tracing |
| Automated evaluations | Continuous evaluation pipeline that measures response quality and orchestration efficiency |

---

## Quality evaluation — proposed criteria

A combined use of the following is considered:
- **Exact match** — for queries with a fixed factual answer
- **LLM-as-a-judge** — main criterion for open-ended responses
- **Heuristic scoring** — complementary metrics (latency, correct delegation rate, cost)

> Pending validation of the optimal combination with the thesis supervisor.
