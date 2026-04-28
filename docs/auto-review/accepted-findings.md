# Accepted Findings — Auto-Review Allowlist

Findings that the automated review sub-agents (`.claude/agents/*.md`) have previously reported and the team has accepted as intentional trade-offs or false positives. Each entry documents the acceptance rationale.

**Sub-agents MUST consult this file before emitting findings** and skip any candidate that matches an active entry. See [`README.md`](./README.md) for the full flow.

---

## How to read this file

Each table row is a single accepted finding. Columns:

| Column | Meaning |
| --- | --- |
| `ID` | Stable identifier. Prefix by category: `TF-` terraform, `PY-` python, `SEC-` security, `DOC-` docs, `DEP-` dependencies, `CMT-` comments. Reference in closure comments and re-surface notes. |
| `File pattern` | Glob or path pattern the acceptance covers. Sub-agents match candidate findings by substring or glob against this. |
| `Issue` | The one-line finding description the sub-agent would generate. Matched by keyword — small rewordings are fine. |
| `Reason` | Why the team accepted. Concrete: tenant constraint, MVP trade-off, false positive with technical explanation, deferred to later iteration. No "later" without a date. |
| `Date` | ISO `YYYY-MM-DD` when the acceptance was recorded. |
| `Ref` | PR(s) or issue(s) where the triage decision happened. |
| `Expires` | Optional ISO date. When set and past, the finding may be re-surfaced. Empty = permanent. |

Matching rule for sub-agents: if `File pattern` matches the file of a candidate finding AND the candidate's issue text contains the key nouns/verbs from `Issue`, the entry applies. When in doubt, skip and list the entry ID in the recap as "suppressed by ID".

---

## Terraform / Infrastructure

Consumed by [`terraform-reviewer`](../../.claude/agents/terraform-reviewer.md) and the infra section of [`security-scanner`](../../.claude/agents/security-scanner.md).

| ID | File pattern | Issue | Reason | Date | Ref | Expires |
| --- | --- | --- | --- | --- | --- | --- |
| TF-1 | `infra/environments/*/terraform.tfvars` | `subscription_id` committed in plaintext | `.gitignore:13` explicitly allowlists `environments/*/terraform.tfvars` (`!environments/*/terraform.tfvars`) — the file is intentionally tracked. The subscription ID is not sensitive in the UCM tenant; the canonical location is documented in `infra/AGENTS.md` step 5. | 2026-04-23 | #45, #51 | |
| TF-2 | `infra/modules/compute/main.tf` orchestrator | Orchestrator `external_ingress = true` with no IP allowlist, WAF, or API Gateway | MVP trade-off: APIM and Front Door add a new Terraform module and €50–700/mo in runtime cost (subscription cap is €200/mo). Iter 2 introduces APIM + Entra ID authN; documented in `docs/architecture.md > External ingress authentication`. Authentication at the app layer via TFM-61 mitigates the risk for MVP. | 2026-04-23 | #45, #51 | 2026-12-31 |
| TF-3 | `infra/modules/compute/main.tf` ACR | ACR on `Basic` SKU has no private endpoint support | Deliberate cost trade-off via TFM-56 / PR #39. Standard SKU + private endpoint costs ~€20/mo more and AcrPull via Managed Identity already pulls over TLS. Upgrade deferred to iter 2 when WAF and private DNS footprint are revisited. | 2026-04-23 | #43, #51 | 2026-12-31 |
| TF-4 | `infra/modules/observability/main.tf` | `internet_ingestion_enabled = true` on Log Analytics Workspace | Tenant constraint: UCM's Azure for Students tenant does not grant AMPLS permissions. Private-link ingestion is blocked at the subscription level. OTel SDK enforces TLS on ingestion; risk is accepted and documented inline at `infra/modules/observability/main.tf:9-10`. | 2026-04-23 | #45, #51, #53 | |
| TF-5 | `infra/modules/networking/main.tf` | `private_endpoint_network_policies = "Disabled"` deprecated string form | Not actionable today — the `azurerm` provider still accepts the string form. Re-surface only if `tflint` azurerm plugin actually raises the rule in CI. | 2026-04-24 | #51 | 2026-10-01 |
| TF-6 | `infra/modules/ai/main.tf` | `azurerm_cognitive_deployment` has no `tags` argument | Resource type does not support tags natively (it is a child resource of `azurerm_cognitive_account`). No code change possible. | 2026-04-24 | #51 | |
| TF-7 | `infra/environments/*/terraform.tfvars` | `openai_subdomain_suffix` / `acr_name_suffix` committed in plaintext | Tenant-agnostic dev convention documented in `infra/AGENTS.md > Portability`. The values become public DNS once provisioned (`<sub>.openai.azure.com`, `<acr>.azurecr.io`) and are not secrets. CI overrides per environment via `TF_VAR_openai_subdomain_suffix` / `TF_VAR_acr_name_suffix`. Same justification family as TF-1. | 2026-04-25 | #57, #58 | |
| TF-8 | `infra/modules/compute/main.tf` | `transport = "auto"` on internal-ingress agents (`rag`, `code`) | False positive. Container Apps Environment internal traffic runs through the platform mesh — `transport` only negotiates HTTP/1.1 vs HTTP/2, not encryption. Same family as SEC-3 (which covered external ingress only). | 2026-04-25 | #58 | |
| TF-9 | `infra/modules/security/main.tf` | RAG agent identity has only `Search Index Data Reader`, missing `Search Index Data Contributor` | RAG performs query-only access in MVP. Document ingestion is out-of-band (planned for iter 2 alongside the `data` module). Re-surface when an ingestion path lands inside the agent. | 2026-04-25 | #58 | 2026-12-31 |
| TF-10 | `infra/environments/*/backend.hcl` | Findings on this file's contents (comment wording, generated banner, etc.) | The path is git-ignored (`.gitignore:24`); the committed source of truth is the heredoc in `infra/scripts/bootstrap-backend.sh`. Findings against the working-copy file should be skipped. | 2026-04-25 | #58 | |

---

## Python

Consumed by [`python-reviewer`](../../.claude/agents/python-reviewer.md).

| ID | File pattern | Issue | Reason | Date | Ref | Expires |
| --- | --- | --- | --- | --- | --- | --- |
| PY-1 | `agents/orchestrator/src/orchestrator/nodes.py` | Add `Callable[[OrchestratorState], Coroutine[Any, Any, dict[str, T]]]` return types to the `make_*_node` factories | Breaks LangGraph's `StateGraph.add_node` type inference. `add_node` requires the callable's parameter to be named exactly `state` (structural typing via `TypedDict`). Typing the factory return as `Callable[...]` erases the parameter name and pyright fails with 4 new errors in `graph.py:24-27`. The inner async functions already have correct typed-dict returns via `OrchestratorState`; adding explicit `dict[str, T]` is redundant. | 2026-04-23 | #44, #52 | |

---

## Security

Consumed by [`security-scanner`](../../.claude/agents/security-scanner.md). Terraform-related security findings also live in the Terraform table above.

| ID | File pattern | Issue | Reason | Date | Ref | Expires |
| --- | --- | --- | --- | --- | --- | --- |
| SEC-1 | `agents/orchestrator/tests/test_app.py`, `shared/tests/test_auth.py` | Hardcoded test API key literal `test-key-0123456789abcdef` | Test-only constant marked with `# pragma: allowlist secret`. Generating via `secrets.token_hex()` in a fixture adds complexity without security benefit: there is no production rotation path, and the literal never leaves the test scope. The allowlist pragma is the idiomatic `detect-secrets` suppression. | 2026-04-24 | #53 | |
| SEC-2 | `README.md` | `curl -LsSf https://astral.sh/uv/install.sh \| sh` is a remote-code-execution pattern | This is Astral's officially documented install method for `uv`. Alternatives (`pip install uv`) create a chicken-and-egg for contributors without Python tooling. The install script is version-pinnable and content-verifiable; documenting the trade-off is sufficient. | 2026-04-24 | #53 | |
| SEC-3 | `infra/modules/compute/main.tf` | `transport = "auto"` on Container App ingress allows HTTP downgrade | False positive. Container Apps external ingress **always** enforces HTTPS at the platform layer — `transport` only negotiates HTTP/1.1 vs HTTP/2 (both over TLS). There is no plaintext HTTP path. | 2026-04-24 | #53 | |
| SEC-4 | `infra/modules/security/main.tf` | `bypass = "AzureServices"` on Key Vault broadens attack surface | Defer until live testing confirms Container Apps secret references resolve with `bypass = "None"`. Premature change risks breaking Managed Identity secret resolution. Re-surface if a future change touches Key Vault bypass configuration. | 2026-04-24 | #51 | 2026-08-01 |
| SEC-5 | `infra/variables.tf`, `infra/modules/compute/main.tf` | `agent_min_replicas = 0` permits a theoretical race between platform ingress and lifespan startup before the auth dependency attaches | Race does not materialize for the current code: `auth_dependency` is set during `create_app()` at module import time, before the lifespan runs. Re-surface only if a future refactor moves auth setup into the lifespan, or when staging/prod are introduced and a warm replica becomes a hard requirement. | 2026-04-25 | #57 | 2026-08-01 |
| SEC-6 | `agents/rag/src/rag/app.py`, `agents/code/src/code_agent/app.py` | `create_app()` called without `api_key`; RAG and Code endpoints unauthenticated within the Container Apps Environment | Both agents have `external_ingress = false` in Terraform; reachable only from inside the VNet. Inter-agent auth model deferred until TFM-38 (orchestrator HTTP clients) lands and the real call pattern is observable. Same triage decision recorded in Issue #53 closure. | 2026-04-25 | #53, #57 | 2026-09-01 |

---

## Docs

Consumed by [`docs-sync`](../../.claude/agents/docs-sync.md). Currently no accepted entries — the docs-sync agent's 2026-04-24 run produced only valid drift fixes (PR #54).

---

## Dependencies

Consumed by [`dependency-updater`](../../.claude/agents/dependency-updater.md). Currently no accepted entries.

---

## Comments

Consumed by [`comment-minimalism-enforcer`](../../.claude/agents/comment-minimalism-enforcer.md). Currently no accepted entries.

---

## Maintenance

Entries are added, expired, or removed by PR. Ownership, review policy, and the end-to-end flow are described in [`README.md`](./README.md).
