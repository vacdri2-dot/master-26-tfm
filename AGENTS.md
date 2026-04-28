# AGENTS.md — Source of Truth

All AI agents working on this project MUST read this file first.

---

## Project

**TFM — Plataforma de Agentes IA Autónomos en Azure**
Master's in Cloud Computing & AI — 2026
Team: 4 people

Cloud-native platform on Azure for deploying and orchestrating autonomous AI agent systems.
Infrastructure managed with Terraform, dual observability (Azure Monitor + LangFuse), CI/CD with GitHub Actions.

---

## Architecture

Orchestrator-Worker pattern: a central agent decomposes tasks and delegates to specialized agents.
Each agent is an independent microservice deployed on Azure Container Apps.

```
User → API Gateway → Orchestrator (LangGraph + GPT-4o)
                        ├── RAG Agent (Azure AI Search + embeddings)
                        ├── Code Agent (GPT-4o + Container Apps Jobs sandbox)
                        ├── API Agent (iter 2)
                        └── Evaluator (iter 2)
```

Communication: HTTP internal (private ingress) within VNet. No public traffic between agents.

---

## Stack

| Layer | Tech |
|-------|------|
| Language | Python 3.12+ |
| API | FastAPI (async, Pydantic, OpenAPI) |
| Agent orchestration | LangGraph |
| LLM | Azure OpenAI (GPT-4o + text-embedding-3-small) |
| IaC | Terraform (modular, state in Azure Storage) |
| Compute | Azure Container Apps (KEDA auto-scaling) |
| Registry | Azure Container Registry |
| Vector search | Azure AI Search |
| Storage | Azure Blob Storage |
| Secrets | Azure Key Vault + Managed Identity |
| Observability (infra) | OpenTelemetry → Application Insights + Log Analytics |
| Observability (LLM) | LangFuse (self-hosted Container App + PostgreSQL) |
| CI/CD | GitHub Actions |
| Frontend (iter 2) | Next.js (TypeScript) |

---

## Project Structure (target)

```
tfm/
├── AGENTS.md                  # This file — source of truth
├── CLAUDE.md                  # Claude Code config → points here
├── README.md                  # Project overview
├── .agents/                   # Agent configurations
│   └── skills/                # Shared skills (empty for now)
├── .claude/                   # Claude Code settings
│   └── settings.json
├── .codex/                    # Codex settings
│   └── config.toml
├── .mcp.json                  # MCP servers (Linear)
├── Dockerfile                 # Parametrized multi-stage build (all agents)
├── docker-compose.yml         # Local dev: all agents with one command
├── .dockerignore              # Excludes infra, docs, caches from build context
├── docs/                      # Project documentation
│   ├── architecture.md
│   ├── cicd.md
│   ├── objectives.md
│   ├── roadmap.md
│   ├── scope.md
│   └── stack.md
├── infra/                     # Terraform modules
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── environments/
│   │   └── dev/
│   └── modules/
│       ├── networking/
│       ├── security/
│       ├── compute/
│       ├── data/
│       ├── ai/
│       ├── observability/
│       └── langfuse/
├── agents/                    # Agent source code
│   ├── orchestrator/
│   ├── rag/
│   └── code/
├── shared/                    # Shared Python libs
└── .github/
    ├── pull_request_template.md
    └── workflows/
```

---

## Terraform Modules

| Module | Resources |
|--------|-----------|
| `networking` | VNet, subnets, NSGs, private DNS, private endpoints |
| `security` | Key Vault, Managed Identities, RBAC |
| `compute` | Container Apps Environment, Container Apps, ACR |
| `data` | AI Search, Blob Storage |
| `ai` | Azure OpenAI deployments (GPT-4o + embeddings) |
| `observability` | Application Insights, Log Analytics, alerts |
| `langfuse` | LangFuse Container App, PostgreSQL Flexible Server |

---

## Terraform Remote Backend

State is stored remotely in Azure Blob Storage. See [`infra/AGENTS.md`](infra/AGENTS.md) for full backend setup, bootstrap instructions, and file reference.

---

## Code Quality & Automation

Every commit and every PR is automatically validated. Mechanical issues are caught before code review.

### Pre-commit hooks

Installed locally, runs on every commit. Setup: `pre-commit install && pre-commit install --hook-type commit-msg`

| Order | Hook | What it catches |
|-------|------|----------------|
| 1 | `trailing-whitespace` | Trailing whitespace |
| 2 | `end-of-file-fixer` | Missing trailing newline |
| 3 | `check-yaml` | Broken YAML syntax |
| 4 | `check-toml` | Broken TOML syntax |
| 5 | `detect-secrets` | API keys, tokens, passwords |
| 6 | `ruff check` | Python lint violations |
| 7 | `ruff format` | Python formatting |
| 8 | `terraform fmt` | Terraform formatting |
| 9 | `commitlint` | Conventional commit message |

### CI pipeline (GitHub Actions)

Runs on every PR and push to `staging`/`main`. All jobs must pass for merge.

| Job | What it validates |
|-----|-------------------|
| `lint-format` | `ruff check` + `ruff format --check` |
| `typecheck` | `pyright` (standard mode) |
| `terraform` | `terraform fmt -check` + `validate` + `tflint` (azurerm) |
| `secrets` | `detect-secrets` scan against baseline |
| `commit-lint` | PR title follows conventional commit format |

### Tool configuration

| Tool | Config location | Purpose |
|------|----------------|---------|
| Ruff | `pyproject.toml` `[tool.ruff]` | Linter + formatter (replaces flake8, isort, black) |
| Pyright | `pyproject.toml` `[tool.pyright]` | Type checking (standard mode) |
| pre-commit | `.pre-commit-config.yaml` | Local hook framework |
| commitlint | `.commitlintrc.yaml` | Commit message validation |
| detect-secrets | `.secrets.baseline` | Secret scanning baseline |
| tflint | `infra/.tflint.hcl` | Terraform linting (azurerm plugin) |

### Third-party GitHub Actions

Third-party actions are pinned to an immutable commit SHA with the upstream tag as an inline comment (e.g., `uses: owner/repo@<sha> # v1.2.3`). First-party `actions/*` may use the `@v<major>` alias. To update a third-party action: review the upstream release changelog, replace both the SHA and the version comment in a single commit, and verify the workflow run.

---

## Conventions

### Code
- Python: type hints everywhere, Pydantic models for all data
- FastAPI: one router per domain, async handlers
- Docstrings on public classes and modules only — skip when the name is self-explanatory
- No secrets in code — Managed Identity + Key Vault references only
- No `print()` in production code — use structured logging
- No barrel re-exports in `__init__.py` — import directly from the source module (e.g., `from shared.models import TaskRequest`)
- Line length: 88 characters (formatter handles wrapping)

### Comments

Applies to all source files — Python, Terraform, YAML, Dockerfiles.

**Default: no comment.** Trust that clear names and module structure carry the meaning.

**Write one only when:**
- It captures a non-obvious **why** — tenant constraint, SKU requirement, invariant the code relies on, workaround for a bug.
- Removing it would leave a future reader genuinely stuck.

**Never write:**
- Comments describing **what** the code does — rename or restructure instead.
- Section dividers (`# --- Config ---`, `# Log Analytics Workspace`) — file and module structure already do that.
- Restatements of Terraform `description` fields, Pydantic `Field(description=...)`, or type hints.
- Ticket references or dated tracking prose (`# added for TFM-29`) — PR description and git history own that.
- Docstrings on trivial functions whose name already says it (`def get_user_id`).

**Keep it to one line.** If the rationale needs a paragraph, move it to `docs/`, not source.

**Enforcement:** PRs that add comments violating this section must be rejected. Pre-existing stale comments in files you touch should be cleaned up in the same PR.

### Terraform
- One module per concern (see table above)
- Variables with descriptions and types
- Outputs for cross-module references
- `terraform fmt` before commit (enforced by pre-commit hook)
- Remote state in Azure Storage (`tfstate` container)

### Python Dependencies
- Tool: `uv` (fast, lockfiles, PEP 621 compliant)
- One `pyproject.toml` per agent in `agents/<name>/`
- Shared code in `shared/` as installable local package

### Git
- Branches: `main` (production, protected), `staging` (default, protected, dev environment)
- Feature branches `feature/`, fix branches `fix/` — **created automatically by Linear webhook** when an issue moves to "In Progress". Never create branches manually
- To start work: move the issue to "In Progress" in Linear, then `git fetch origin && git checkout <branch-name>`
- All PRs target `staging` — requires 1 approval before merge
- `staging` → `main` promotion: only repo owner, via PR
- Commits: conventional commits (`feat:`, `fix:`, `docs:`, `infra:`, `refactor:`, `test:`, `chore:`, `ci:`, `style:`, `perf:`)
- Commit message limits (enforced by commitlint): header ≤ 72 chars, body line ≤ 100 chars, blank line between header and body
- **Commit messages must be header-only — no body.** Use `git commit -m "<header>"`, never heredoc bodies. The full context lives in the PR description; commit bodies only add noise to the squash-merge bullets. Exceptions: a single short line in the body when documenting a one-off rationale that genuinely cannot fit elsewhere
- No direct pushes to `main` or `staging`
- No direct pushes to `main` or `staging`

### Pull Requests
- **Title:** must follow conventional commit format (e.g., `infra: configure remote backend`)
- **Description:** use the PR template (`.github/pull_request_template.md`) — do not leave it blank
- **One PR per Linear issue.** Linear bot auto-links the issue via branch name — no manual linking needed
- **Squash merge:** GitHub is configured to squash all commits into one on merge (PR title + commit messages as bullet points). No manual squash needed
- **Commit messages:** every commit message must follow conventional commits — they become the bullet points in the squashed merge commit
- **Language:** all PR content (title, description, comments, code, docs) must be in English
- **Self-check before requesting review:**
  - All files end with a trailing newline
  - No Spanish in code, comments, or docs
  - No secrets or credentials
  - `terraform fmt` (if Terraform changes)
  - Tests pass locally
  - `pre-commit run --all-files` passes

### Docker
- Single parametrized `Dockerfile` at repo root (build args: `PACKAGE`, `AGENT_DIR`, `MODULE`)
- Build from repo root: `docker build --build-arg PACKAGE=<name> --build-arg AGENT_DIR=<dir> --build-arg MODULE=<module> .`
- Local dev: `docker compose up --build` (builds and runs all agents)
- Multi-stage builds (builder + runtime)
- Non-root user in production images
- Health check endpoint: `GET /health`

### Testing (MVP)
- Unit tests for Orchestrator routing logic (mock LLM calls, no real GPT)
- `terraform validate` + `tflint` in CI
- Smoke test post-deploy: `curl /health` on all 3 agents
- `pytest` for each agent before push

---

## Roadmap

### Iteration 1 — MVP (current)
- Terraform modules for all infra (single `terraform apply` → full environment)
- Orchestrator + RAG Agent + Code Agent
- CI/CD pipelines (infra + app)
- Dual observability (App Insights + LangFuse)
- Infra emphasis: auto-scaling, health probes, Azure Monitor dashboard, cost breakdown, destroy/apply demo

### Iteration 2 — Full Platform
- API Agent + Evaluator Agent
- Automated evaluation pipeline (LLM-as-a-judge)
- Multi-environment (dev + staging)
- Next.js frontend with real-time tracing panel
- Advanced CI/CD (promotion, security scans)

---

## KPIs

| KPI | Target |
|-----|--------|
| `terraform apply` from scratch | < 20 min |
| Monthly cost (idle) | < 200 EUR |
| Response quality (LLM-as-a-judge) | > 80% |
| End-to-end latency | < 30s (P95) |
| Tracing coverage | 100% requests |
| Public endpoints with sensitive data | 0 |

---

## Documentation

Full docs in `docs/`:
- `objectives.md` — Goals, differentiators, evaluation criteria
- `architecture.md` — High-level diagram, execution flow, Terraform modules
- `stack.md` — Tech stack and design decisions
- `roadmap.md` — Iterations, work division, KPIs
- `scope.md` — Scope, deliverables, thesis structure
- `cicd.md` — CI/CD pipelines, remote state

---

## Rules for Agents

1. **Read this file first.** Always.
2. **No secrets in code.** Use `"stored in Key Vault"` as placeholder.
3. **Plan before executing** multi-step work.
4. **Follow the conventions** above (commits, Python style, Terraform format).
5. **Don't modify docs/ without asking** — those are shared team documents.
6. **Test locally before pushing** — `terraform validate`, `pytest`, `docker build`.
7. **Never create branches manually.** Linear webhook creates them automatically when an issue moves to "In Progress". Use `git fetch origin && git checkout <branch-name>`.
8. **Ask when unsure** — wrong confident code is worse than asking.
