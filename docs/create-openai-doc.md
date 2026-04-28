# Azure OpenAI Service — Provisioning Script

## Overview

The `create-openai.sh` script automates the creation of the Azure OpenAI resource and the deployment of the models required by the project. It is designed to be run manually **once per environment**, as Azure OpenAI provisioning has long propagation times and is not managed directly with Terraform.

---

## Files

| File | Description |
|------|-------------|
| `create-openai.sh` | Main bash script. Creates the resource group, the OpenAI resource and both model deployments |
| `create-openai.conf` | Configuration file. Contains all parametrizable variables used by the script |


---

## Configuration (`create-openai.conf`)

| Variable | Value | Description |
|----------|-------|-------------|
| `RESOURCE_GROUP` | `rg-tfm-ucm-g2-dev` | Resource group where the resource is created |
| `LOCATION` | `swedencentral` | Azure region. Only European region available due to tenant policy |
| `OPENAI_NAME` | `oai-tfm-ucm-g2-dev` | Azure OpenAI resource name |
| `GPT4O_DEPLOYMENT` | `gpt-4o` | GPT-4o deployment name |
| `GPT4O_MODEL` | `gpt-4o` | Base model |
| `GPT4O_VERSION` | `2024-11-20` | GPT-4o model version |
| `GPT4O_CAPACITY` | `10` | Capacity in thousands of tokens per minute (10K TPM) |
| `EMBEDDING_DEPLOYMENT` | `text-embedding-3-small` | Embeddings deployment name |
| `EMBEDDING_MODEL` | `text-embedding-3-small` | Base embeddings model |
| `EMBEDDING_VERSION` | `1` | Embeddings model version |
| `EMBEDDING_CAPACITY` | `10` | Capacity in thousands of tokens per minute (10K TPM) |
| `TAGS` | `environment=dev project=tfm-ucm-g2 managed-by=terraform` | Tags applied to all resources |

---

## Deployed Models

| Deployment | Model | Version | SKU | Capacity | Usage |
|------------|-------|---------|-----|----------|-------|
| `gpt-4o` | `gpt-4o` | `2024-11-20` | GlobalStandard | 10K TPM | Orchestrator + agents |
| `text-embedding-3-small` | `text-embedding-3-small` | `1` | GlobalStandard | 10K TPM | RAG Agent (embeddings) |

---

## Execution Flow

```
1. Load configuration from create-openai.conf
2. Verify active Azure login (az account show)
3. Check if the resource group exists
   └── If not → create it with az group create
   └── If exists → reuse it
4. Create the Azure OpenAI resource (az cognitiveservices account create)
   └── Kind: OpenAI | SKU: S0 | Custom domain = resource name
5. Deploy GPT-4o (az cognitiveservices account deployment create)
6. Deploy text-embedding-3-small (az cognitiveservices account deployment create)
7. Retrieve and display endpoint + API key
```

---

## Prerequisites

- Azure CLI installed (`az --version`)
- Active session with sufficient permissions (`az login`)
- Available quota in `swedencentral` for both models
- Maximum 1 OpenAI S0 resource per subscription in the region (`OpenAI.S0.AccountCount = 1`)

---

## How to Run

```bash
chmod +x create-openai.sh
./create-openai.sh
```

---

## Expected Output

```
✓ Everything created successfully.

─── Team data ─────────────────────────────────────────────────────────────
  Endpoint : https://oai-tfm-ucm-g2-dev.openai.azure.com/
  API Key  : *** retrieve from Key Vault ***
  GPT-4o deployment name     : gpt-4o
  Embedding deployment name  : text-embedding-3-small
──────────────────────────────────────────────────────────────────────────
```

> **IMPORTANT:** Save the endpoint and API key in **Azure Key Vault** immediately. Never store them in code or plain text environment variables.

---

## Design Decisions

| Decision | Reason |
|----------|--------|
| Bash script instead of Terraform | Long provisioning times and quota restrictions make Azure OpenAI unviable to manage with Terraform in the MVP |
| Region `swedencentral` | Only European region enabled by tenant policy for Azure OpenAI |
| GlobalStandard SKU | Higher token capacity and access to the latest model versions |
| 10K TPM capacity | Sufficient for the dev environment; adjustable in `.conf` without modifying the script logic |
| Configuration separated in `.conf` | Allows parameter changes without modifying the script logic |

---

## Notes

- **Idempotent on resource group**: if it already exists, it is reused without error.
- **Not idempotent on the OpenAI resource**: if the resource already exists, `az cognitiveservices account create` will fail. Run only if the resource does not yet exist.
- Quota `OpenAI.S0.AccountCount` = 1 maximum per subscription in `swedencentral`.
