# CI/CD and Automation

## Branch strategy

```
feature/* or fix/*  ──PR──→  staging (default, dev)  ──PR──→  main (production)
```

| Branch      | Role                                       | Protection                                     |
| ----------- | ------------------------------------------ | ---------------------------------------------- |
| `main`      | Production — stable, validated code        | PR required + 1 approval, only owner can merge |
| `staging`   | Development — where changes are integrated | PR required + 1 approval                       |
| `feature/*` | Work branches (features)                   | No protection, created from staging            |
| `fix/*`     | Work branches (fixes)                      | No protection, created from staging            |

---

## Pre-commit hooks (local)

Runs on every commit via [pre-commit](https://pre-commit.com/). First failure aborts the commit.

### Setup

```bash
pre-commit install
pre-commit install --hook-type commit-msg
```

### Hook chain

| Order | Hook                  | What it catches                   | Scope               |
| ----- | --------------------- | --------------------------------- | ------------------- |
| 1     | `trailing-whitespace` | Trailing whitespace               | Staged files        |
| 2     | `end-of-file-fixer`   | Missing trailing newline (POSIX)  | Staged files        |
| 3     | `check-yaml`          | Broken YAML syntax                | Staged `.yml/.yaml` |
| 4     | `check-toml`          | Broken TOML syntax                | Staged `.toml`      |
| 5     | `detect-secrets`      | API keys, tokens, passwords       | Staged files        |
| 6     | `ruff check`          | Python lint violations (auto-fix) | Staged `.py`        |
| 7     | `ruff format`         | Python formatting                 | Staged `.py`        |
| 8     | `terraform fmt`       | Terraform formatting              | Staged `.tf`        |
| 9     | `commitlint`          | Conventional commit message       | Commit message      |

**Config:** `.pre-commit-config.yaml`

**Why no pyright in hooks:** pyright needs to resolve the full project to check types. Running it on every commit adds 10-30s of latency. It runs in CI instead, where the full environment is available and latency is acceptable.

---

## Pipelines with GitHub Actions

### CI pipeline (`.github/workflows/ci.yml`)

**Trigger:** PRs to `staging` and `main`, pushes to `staging` and `main`.

**Jobs:** run in parallel, all must pass for merge.

| Job           | Runner          | What it validates                                        | Why in CI                                  |
| ------------- | --------------- | -------------------------------------------------------- | ------------------------------------------ |
| `lint-format` | `ubuntu-latest` | `ruff check` + `ruff format --check`                     | Hooks can be skipped with `--no-verify`    |
| `typecheck`   | `ubuntu-latest` | `pyright` (standard mode)                                | Too slow for pre-commit hooks              |
| `terraform`   | `ubuntu-latest` | `terraform fmt -check` + `validate` + `tflint` (azurerm) | validate needs init; tflint not in hooks   |
| `secrets`     | `ubuntu-latest` | `detect-secrets` scan against baseline                   | Defense in depth — catch what hooks missed |
| `commit-lint` | `ubuntu-latest` | PR title follows conventional commit pattern             | PR titles become the squash commit message |
| `pre-commit`  | `ubuntu-latest` | Full pre-commit hook suite (ruff, terraform fmt, secrets) | Ensures hooks can't be skipped via `--no-verify` |

**Concurrency:** new push to same branch cancels previous CI run (saves GitHub Actions minutes).

### Automatic Code Review (OpenCode)

| Event                                            | Action                                                |
| ------------------------------------------------ | ----------------------------------------------------- |
| PR opened, reopened, or marked ready for review  | OpenCode reviews the diff against project standards   |
| Comment with `/oc` or `/opencode` in PR or issue | OpenCode responds to the request or performs the task |

- **Action:** `anomalyco/opencode/github@27db54c859be74aa4caed3e58ae14ecc8bc34b30` <!-- v1.14.19 -->
- **Model:** `opencode/minimax-m2.5-free` (free tier, no API key required)
- **Review criteria:** Python (type hints, Pydantic, async), security (no secrets in code, Managed Identity), Terraform (typed variables, formatting), Docker (multi-stage, non-root), commit conventions
- **Workflows:**
  - `.github/workflows/opencode-review.yml` — automatic PR review on open/push
  - `.github/workflows/opencode.yml` — comment-triggered tasks (`/oc`, `/opencode`)

> **Note:** The AI review catches design/logic issues. The CI pipeline catches mechanical violations. Together they cover both layers.

### Infrastructure pipeline (Terraform)

Defined in `.github/workflows/terraform.yml`. Runs only when files under `infra/**` or the workflow itself change.

| Step         | Action          | Tool / Implementation                           |
| ------------ | --------------- | ----------------------------------------------- |
| **Auth**     | Azure login     | `azure/login@v2` with OIDC (no static secrets)  |
| **Format**   | Style check     | `terraform fmt -check -recursive`               |
| **Init**     | Remote backend  | `terraform init` with repo vars (Azure Storage) |
| **Lint**     | Static analysis | `tflint --recursive`                            |
| **Validate** | Syntax check    | `terraform validate`                            |
| **Plan**     | Preview changes | `terraform plan` (posted as PR comment)         |
| **Apply**    | Apply changes   | `terraform apply` (only on push to `staging`)   |

**Triggers:**

| Event                             | Action                                    |
| --------------------------------- | ----------------------------------------- |
| Pull Request to `staging`         | `fmt` + `init` + `lint` + `validate` + `plan` (posted as PR comment) |
| Push to `staging` (merge)         | Full pipeline + `terraform apply` on `dev` |
| Manual `workflow_dispatch`        | Full pipeline up to `plan` (never applies)   |

> Push validation on non-`staging` branches (`feature/*`, `fix/*`) is handled by the generic CI pipeline (`.github/workflows/ci.yml`), which runs `terraform fmt/validate/tflint` without backend access on every push. This avoids duplicating OIDC-authenticated jobs on every feature commit.

**Config contract (GitHub repository variables):**

| Prefix           | Purpose                                        |
| ---------------- | ---------------------------------------------- |
| `AZURE_*`        | OIDC authentication (client, tenant, sub, RG)  |
| `TF_BACKEND_*`   | Remote state backend (RG, account, container, key) |
| `TF_VAR_*`       | Terraform root-module input variables          |

All values live as repo-level variables so no `terraform.tfvars` file needs to be committed. Terraform requires lowercase variable names (`TF_VAR_subscription_id`), so the workflow maps each GitHub-uppercased variable into a lowercase env var.

### Application pipeline (agents) — MVP (iteration 1)

1. Docker image build (trigger: changes in `agents/` merged to `staging`)
2. Push to Azure Container Registry
3. Deploy to Container Apps with revision-based deployment
4. Smoke test: `curl /health` on each deployed agent

### Application pipeline — Advanced (iteration 2)

1. Docker image security scan (Trivy)
2. Post-deploy integration tests
3. Agent evaluation pipeline execution
4. Automatic rollback if quality metrics drop below threshold
5. Manual `staging → main` promotion with owner approval

### Azure OIDC Authentication (`.github/workflows/azure-oidc-validate.yml`)

GitHub Actions authenticates against Azure using OIDC (OpenID Connect) — no static secrets stored in the repository.

**How it works:** GitHub's OIDC provider issues a short-lived token on every workflow run. Azure trusts this token via federated credentials configured on an App Registration. The token expires after the job finishes.

**Azure resources:**

| Resource         | Value                                |
| ---------------- | ------------------------------------ |
| App Registration | `sp-tfm-ucm-g2-github-actions`       |
| RBAC role        | `Contributor` on `rg-tfm-ucm-g2-dev` |

**Federated credentials (3):**

| Name                  | Subject                                                | When it applies |
| --------------------- | ------------------------------------------------------ | --------------- |
| `github-pull-request` | `repo:cgaravitoq/master-26-tfm:pull_request`           | Any PR          |
| `github-staging`      | `repo:cgaravitoq/master-26-tfm:ref:refs/heads/staging` | Push to staging |
| `github-main`         | `repo:cgaravitoq/master-26-tfm:ref:refs/heads/main`    | Push to main    |

**GitHub repository variables:**

| Variable                | Purpose                    |
| ----------------------- | -------------------------- |
| `AZURE_CLIENT_ID`       | App Registration client ID |
| `AZURE_TENANT_ID`       | Azure AD tenant ID         |
| `AZURE_SUBSCRIPTION_ID` | Target subscription        |
| `AZURE_RESOURCE_GROUP`  | Target resource group      |

**Bootstrap steps (to replicate on another tenant):**

```bash
# 1. Create App Registration
az ad app create --display-name "sp-tfm-ucm-g2-github-actions"
APP_ID=$(az ad app list --display-name "sp-tfm-ucm-g2-github-actions" --query "[0].appId" -o tsv)

# 2. Create Service Principal
az ad sp create --id $APP_ID

# 3. Add federated credentials (repeat for each subject)
az ad app federated-credential create --id $APP_ID --parameters '{
  "name": "github-pull-request",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:<owner>/<repo>:pull_request",
  "audiences": ["api://AzureADTokenExchange"]
}'

# 4. Assign Contributor on the resource group
az role assignment create \
  --assignee $APP_ID \
  --role "Contributor" \
  --scope "/subscriptions/<sub-id>/resourceGroups/<rg-name>"

# 5. Set GitHub repository variables
gh variable set AZURE_CLIENT_ID --body "$APP_ID"
gh variable set AZURE_TENANT_ID --body "<tenant-id>"
gh variable set AZURE_SUBSCRIPTION_ID --body "<subscription-id>"
gh variable set AZURE_RESOURCE_GROUP --body "<resource-group>"
```

---

## Terraform remote state

- Backend: Azure Storage Account
- Locking: blob lease (prevents concurrent applies)
- MVP: single `dev` environment (deployed from `staging`)
- Iteration 2: workspaces per environment (`staging` → dev, `main` → prod)
