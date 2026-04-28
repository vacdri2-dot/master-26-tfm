#!/usr/bin/env bash
set -euo pipefail

CONF_FILE="$(dirname "$0")/create-openai.conf"

if [[ ! -f "$CONF_FILE" ]]; then
  echo "ERROR: Configuration file not found: $CONF_FILE"
  exit 1
fi

source "$CONF_FILE"
echo "→ Configuration loaded from $CONF_FILE"

echo "→ Verifying Azure login..."
az account show > /dev/null 2>&1 || { echo "ERROR: Not logged in. Run 'az login' first."; exit 1; }

SUBSCRIPTION=$(az account show --query "name" -o tsv)
echo "  Active subscription: $SUBSCRIPTION"

echo "→ Checking resource group '$RESOURCE_GROUP'..."
if az group show --name "$RESOURCE_GROUP" > /dev/null 2>&1; then
  echo "  Already exists, reusing."
else
  echo "  Creating resource group..."
  az group create \
    --name "$RESOURCE_GROUP" \
    --location "$LOCATION" \
    --tags $TAGS
  echo "  Resource group created."
fi

echo "→ Checking Azure OpenAI resource '$OPENAI_NAME'..."
if az cognitiveservices account show --name "$OPENAI_NAME" --resource-group "$RESOURCE_GROUP" > /dev/null 2>&1; then
  echo "  Resource already exists, skipping creation."

  # Validate the existing resource is in a healthy state before continuing
  PROVISIONING_STATE=$(az cognitiveservices account show \
    --name "$OPENAI_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --query "properties.provisioningState" -o tsv)

  if [[ "$PROVISIONING_STATE" != "Succeeded" ]]; then
    echo "ERROR: Resource '$OPENAI_NAME' exists but is in state '$PROVISIONING_STATE'. Aborting."
    echo "       Resolve the resource state in the Azure Portal before re-running this script."
    exit 1
  fi

  echo "  Resource state: $PROVISIONING_STATE. Proceeding with deployments."
else
  echo "  Creating Azure OpenAI resource..."
  az cognitiveservices account create \
    --name "$OPENAI_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --location "$LOCATION" \
    --kind "OpenAI" \
    --sku "S0" \
    --custom-domain "$OPENAI_NAME" \
    --tags $TAGS
  echo "  OpenAI resource created."
fi

echo "→ Checking deployment '$GPT4O_DEPLOYMENT'..."
if az cognitiveservices account deployment show \
  --name "$OPENAI_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --deployment-name "$GPT4O_DEPLOYMENT" > /dev/null 2>&1; then
  echo "  Deployment '$GPT4O_DEPLOYMENT' already exists, skipping."
else
  echo "  Deploying model '$GPT4O_DEPLOYMENT'..."
  az cognitiveservices account deployment create \
    --name "$OPENAI_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --deployment-name "$GPT4O_DEPLOYMENT" \
    --model-name "$GPT4O_MODEL" \
    --model-version "$GPT4O_VERSION" \
    --model-format "OpenAI" \
    --sku-capacity "$GPT4O_CAPACITY" \
    --sku-name "GlobalStandard"
  echo "  GPT-4o deployed."
fi

echo "→ Checking deployment '$EMBEDDING_DEPLOYMENT'..."
if az cognitiveservices account deployment show \
  --name "$OPENAI_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --deployment-name "$EMBEDDING_DEPLOYMENT" > /dev/null 2>&1; then
  echo "  Deployment '$EMBEDDING_DEPLOYMENT' already exists, skipping."
else
  echo "  Deploying model '$EMBEDDING_DEPLOYMENT'..."
  az cognitiveservices account deployment create \
    --name "$OPENAI_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --deployment-name "$EMBEDDING_DEPLOYMENT" \
    --model-name "$EMBEDDING_MODEL" \
    --model-version "$EMBEDDING_VERSION" \
    --model-format "OpenAI" \
    --sku-capacity "$EMBEDDING_CAPACITY" \
    --sku-name "GlobalStandard"
  echo "  text-embedding-3-small deployed."
fi

echo ""
echo "✓ Done."
echo ""
echo "─── Team data ─────────────────────────────────────────────────────────────"
ENDPOINT=$(az cognitiveservices account show \
  --name "$OPENAI_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query "properties.endpoint" -o tsv)

echo "  Endpoint : $ENDPOINT"
echo "  API Key  : *** retrieve with: az keyvault secret show --name oai-api-key --vault-name <your-keyvault> ***"
echo "  GPT-4o deployment name     : $GPT4O_DEPLOYMENT"
echo "  Embedding deployment name  : $EMBEDDING_DEPLOYMENT"
echo ""
echo "  IMPORTANT: store the API key in Key Vault, never in code or environment variables."
echo "─────────────────────────────────────────────────────────────────────────────"
