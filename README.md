# TFM — Autonomous AI Agents Platform on Azure

Master's in Cloud Computing & Artificial Intelligence — 2026

## Description

Design and implementation of a cloud-native platform on Azure for deploying and orchestrating autonomous AI agent systems. Infrastructure managed with Terraform, end-to-end observability with OpenTelemetry, and CI/CD with GitHub Actions.

The core is a multi-agent system using the Orchestrator-Worker pattern: a central agent decomposes tasks and delegates them to specialized agents (RAG, code, APIs). Each agent is an independent microservice deployed on Azure Container Apps.

## Documentation

| Doc | Contents |
|-----|----------|
| [`docs/objectives.md`](docs/objectives.md) | Goals, approach, differentiators, evaluation criteria |
| [`docs/architecture.md`](docs/architecture.md) | High-level diagram, execution flow, Terraform modules |
| [`docs/stack.md`](docs/stack.md) | Tech stack and design decisions |
| [`docs/roadmap.md`](docs/roadmap.md) | Roadmap by iteration, work division, KPIs |
| [`docs/scope.md`](docs/scope.md) | Scope, deliverables, KPIs with measurement methods, thesis structure |
| [`docs/cicd.md`](docs/cicd.md) | CI/CD pipelines (infrastructure + applications), Terraform remote state |

## Development Setup

### Prerequisites

```bash
# uv (Python package manager) — works on macOS and Linux
curl -LsSf https://astral.sh/uv/install.sh | sh

# Python 3.12 (managed by uv, isolated from system Python)
uv python install 3.12
```

Install pre-commit and tflint (only needed for infra work):

| | macOS | Linux |
|--|-------|-------|
| pre-commit | `brew install pre-commit` | `pip install pre-commit` |
| tflint | `brew install tflint` | See [tflint releases](https://github.com/terraform-linters/tflint/releases) |
| Terraform ≥ 1.6 | `brew install terraform` | See [terraform downloads](https://developer.hashicorp.com/terraform/install) |

### Project setup

```bash
# 1. Install Python deps (includes ruff, pyright as dev deps)
uv sync --all-packages

# 2. Install pre-commit hooks
pre-commit install
pre-commit install --hook-type commit-msg

# 3. (Optional) Run all hooks on existing files
pre-commit run --all-files
```

## Team

4 people — March 2026

## Agents

| Agent | Responsibility | Iteration |
|-------|---------------|-----------|
| Orchestrator | Receives task, decomposes, delegates, composes final response | MVP |
| RAG Agent | Queries indexed documents (Azure AI Search + embeddings) | MVP |
| Code Agent | Generates and executes code in sandbox (Container Apps Jobs) | MVP |
| API Agent | Interacts with external APIs via Function Calling | Iter 2 |
| Evaluator | Validates response quality before delivery | Iter 2 |
