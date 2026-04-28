# infra/AGENTS.md — Terraform Infrastructure

This directory contains all Terraform configuration for the project.
For project-wide conventions, see the root [AGENTS.md](../AGENTS.md).

---

## Tenant Requirements

The project is tenant-agnostic: any Azure subscription that meets the requirements below can host it.

### Required resource providers

Some providers must be registered per subscription before `terraform apply`. The most common blocker is `Microsoft.App` (creating the Container Apps Environment fails otherwise with `MissingSubscriptionRegistration`):

```bash
az provider register --namespace Microsoft.App --wait
az provider register --namespace Microsoft.CognitiveServices --wait
az provider register --namespace Microsoft.ContainerRegistry --wait
az provider register --namespace Microsoft.OperationalInsights --wait
az provider register --namespace Microsoft.KeyVault --wait
az provider register --namespace Microsoft.ManagedIdentity --wait
az provider register --namespace Microsoft.Network --wait
```

### Required access and capacity

- Azure OpenAI access in the target region (some subscriptions require an approval request)
- Capacity for `gpt-4o` and `text-embedding-3-small` deployments
- Region that supports Azure OpenAI, Container Apps, and AI Search

Starting reference capacities (verify per tenant with `az cognitiveservices account list-skus`):

| Deployment | Reference TPM | Used by |
|---|---|---|
| `gpt-4o` | 10K–40K | Orchestrator, Code Agent |
| `text-embedding-3-small` | 10K–120K | RAG Agent |

### Restricting the region via Azure Policy

If the tenant enforces an allowed-regions policy (e.g. Azure for Students), declare the list in `terraform.tfvars`:

```hcl
allowed_locations = ["norwayeast", "polandcentral", "italynorth", "germanywestcentral", "swedencentral"]
```

Leave `allowed_locations = null` (default) when no policy applies.

---

## Portability

### Globally-unique names

Two resource fields are unique across **all of Azure**, not just the tenant. If another tenant in the world already registered them, `terraform apply` fails with a name collision:

- `azurerm_cognitive_account.custom_subdomain_name` — the `<sub>.openai.azure.com` subdomain
- `azurerm_container_registry.name` — the registry login server

Set optional suffixes to avoid collisions:

```hcl
openai_subdomain_suffix = "g2carlos"
acr_name_suffix         = "g2carlos"
```

Suffixes affect only the globally-unique fields; resource names inside the resource group stay aligned with `name_prefix`.

### Adopting a pre-existing OpenAI account

When an OpenAI account already exists in Azure (manual provisioning, imported from another tenant, etc.), pass its resource ID to adopt it into state instead of creating a new one:

```hcl
openai_existing_account_id = "/subscriptions/<SUB_ID>/resourceGroups/<RG>/providers/Microsoft.CognitiveServices/accounts/<NAME>"
```

When `null` (default), `terraform apply` creates a fresh account.

---

## Tenant migration checklist

When moving the deployment from one tenant to another (e.g. at the end of a free-credit period):

1. `az login` to the new tenant; confirm permissions on the target resource group
2. Register the providers listed in [Tenant Requirements](#tenant-requirements)
3. Verify Azure OpenAI access and quotas in the target region
4. Run `./scripts/bootstrap-backend.sh <new_subscription_id>` to create the state backend
5. Update `infra/environments/dev/terraform.tfvars`:
   - `subscription_id` → the new subscription
   - `openai_subdomain_suffix` and `acr_name_suffix` → unique values for the new tenant
   - `openai_existing_account_id` → `null` unless intentionally importing a pre-existing account
   - `allowed_locations` → adjust or remove per the new tenant's policy
6. `terraform init -reconfigure -backend-config=./environments/dev/backend.hcl`
7. `terraform plan -var-file=./environments/dev/terraform.tfvars`
8. `terraform apply`

Resources in the old tenant are orphaned. Run `terraform destroy` there first for a clean teardown, or let the subscription expire.

---

## Known provider drift

`azurerm_container_app_environment` declares:

```hcl
lifecycle {
  ignore_changes = [
    infrastructure_resource_group_name,
    workload_profile,
  ]
}
```

Azure populates `infrastructure_resource_group_name` and expands `workload_profile` after creation. Without `ignore_changes`, every subsequent plan shows a forced replacement. Do not remove the block unless the underlying azurerm provider bug has been fixed.

---

## Remote Backend

State is stored in Azure Blob Storage using the `azurerm` backend.
The backend block in `backend.tf` is intentionally empty — values are injected at init time via `-backend-config`.

| Setting | Value |
|---------|-------|
| Type | `azurerm` |
| Storage Account | Defined in `scripts/backend.conf` |
| Container | `tfstate` |
| State key (dev) | `dev.terraform.tfstate` |
| Auth | Azure AD (`use_azuread_auth = true`, `use_cli = true`) |

---

## Current Terraform Modules

| Module | Status | Resources |
|--------|--------|-----------|
| `networking` | Active | VNet, subnets, NSGs, subnet associations, private DNS zones |
| `security` | Active | Key Vault, managed identities, RBAC |
| `compute` | Active | Container Apps Environment, Container Apps, ACR (Basic SKU, AcrPull via per-agent Managed Identity — no admin_user, no private endpoint) |
| `ai` | Active | Azure OpenAI account, GPT-4o + text-embedding-3-small deployments, private endpoint |
| `data` | Planned | AI Search, Blob Storage |
| `observability` | Active | App Insights, Log Analytics |
| `langfuse` | Planned | LangFuse + PostgreSQL |

---


## File Reference

| File | Purpose |
|------|---------|
| `backend.tf` | Empty `azurerm` backend block |
| `versions.tf` | Terraform and provider version constraints (`>= 1.7`, `azurerm ~> 4.0`) |
| `providers.tf` | Provider configuration (`azurerm` with `subscription_id`) |
| `main.tf` | Root module entry point (modules added in later tasks) |
| `variables.tf` | Root module input variables (added in later tasks) |
| `outputs.tf` | Root module outputs (added in later tasks) |
| `scripts/backend.conf` | **Single source of truth** for backend identifiers (RG, storage account, container, key, location) |
| `scripts/bootstrap-backend.sh` | Idempotent script that creates backend infra and generates `backend.hcl` |
| `environments/dev/terraform.tfvars.example` | Template for dev environment variables — copy to `terraform.tfvars` and fill in |
| `environments/dev/backend.hcl` | Auto-generated by bootstrap script — **do not edit manually** (git-ignored) |
| `.terraform.lock.hcl` | Provider lock file — **tracked** for team consistency |

---
## Observability Module — Design Decisions and Constraints

### Configuration

| Parameter | Value | Reason |
|-----------|-------|--------|
| `retention_days` | 30 (default) | MVP cost optimization; raise to 90 in production |
| `daily_cap_gb` | 1 GB/day | Prevents billing spikes on $200/month student budget |
| `sampling_percentage` | 100% MVP, 5-20% production | Full fidelity in dev; reduce under high traffic |
| Workspace architecture | Single shared LAW per environment | One workspace for MVP; promote to per-environment in iteration 2 |
| App Insights type | Workspace-based | Classic App Insights is deprecated by Microsoft |

### Logs enabled (MVP scope)

Only the following are collected to avoid unnecessary cost and noise:
- Container Apps traces and exceptions (via OpenTelemetry SDK)
- Azure Activity Logs (via Diagnostic Settings)
- HTTP request/response latency and error rates

Not enabled: Storage, DNS, Key Vault verbose logs, Cosmos. Enable selectively in iteration 2.

### UCM tenant limitation — public ingestion

`internet_ingestion_enabled = true` is required because Private Link Scope (AMPLS)
is not available on the Azure for Students tenant due to RBAC restrictions.
Access is controlled via RBAC roles (Monitoring Reader, Log Analytics Reader).
Iteration 2: enable AMPLS when moving to a production tenant with full permissions.

### Security constraints

- Connection string and instrumentation key must be stored in Key Vault — never hardcoded
- Applications must never log: tokens, prompts, connection strings, or PII
- Access via RBAC roles only — never via access keys

> **Tenant exception — Container Apps value-secrets.** The project Key Vault has
> `public_network_access_enabled = false` and the GitHub Actions / local `az` clients
> are outside the VNet, so they cannot write to the KV data plane (`ForbiddenByConnection`).
> Two values therefore live as Container Apps value-secrets, encrypted at rest by the
> platform: `APPLICATIONINSIGHTS_CONNECTION_STRING` (PR #65) and `ORCHESTRATOR_API_KEY`
> (PR #66, generated by `random_password` in root `main.tf`). Promote both to KV when
> iteration 2 enables AMPLS / private endpoint reachable from CI.

---

## Secret rotation — Container Apps value-secrets

| Secret | Rotation command |
|---|---|
| `random_password.orchestrator_api_key` | `terraform apply -replace=random_password.orchestrator_api_key -var-file=./environments/dev/terraform.tfvars` |
| `APPLICATIONINSIGHTS_CONNECTION_STRING` | Not rotatable — bound to the App Insights component lifetime |

Container App revisions update automatically when the value changes.

---

## Bootstrap (first time only)

### Prerequisites

- Terraform >= 1.7
- Azure CLI installed and logged in (`az login`)
- Subscription permissions: Resource Group, Storage Account, Blob Container, Role Assignments
- Azure resource providers registered (see [Tenant Requirements](#tenant-requirements))

### Steps

```bash
az login
cd infra
bash ./scripts/bootstrap-backend.sh "<SUBSCRIPTION_ID>"
terraform init -backend-config=./environments/dev/backend.hcl
```

### Verification

```bash
terraform validate   # should pass cleanly
terraform plan -var-file="./environments/dev/terraform.tfvars"    # should show no changes (empty root module)
```

> **Note:** If `terraform init` fails with a 403 error, wait 1-5 minutes for RBAC propagation and retry.

---

## Conventions (infra-specific)

- One module per concern (see root AGENTS.md for the module table)
- Variables with descriptions and types
- Outputs for cross-module references
- `terraform fmt -recursive` before commit
- All files must end with a trailing newline
- `.terraform.lock.hcl` is always tracked
- `environments/*/backend.hcl` is always git-ignored (generated output)

### Resource tags

Every Azure resource created by Terraform must carry these tags (sourced from a shared `local.tags` map at the root module). Keys use **kebab-case**.

| Key | Value | Source |
|---|---|---|
| `environment` | `var.environment` (e.g. `dev`) | Root variable |
| `project` | `var.project_name` (e.g. `tfm-g2`) | Root variable |
| `managed-by` | `terraform` (literal) | Hardcoded |

Modules must receive the full tag map as an input variable (`var.tags`) and apply it to every taggable resource — no per-module tag definitions.
