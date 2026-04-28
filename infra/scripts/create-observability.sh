#!/usr/bin/env bash
set -euo pipefail

# Config
CONF_FILE="$(dirname "$0")/create-observability.conf"

if [[ ! -f "$CONF_FILE" ]]; then
  echo "ERROR: Config file not found: $CONF_FILE"
  exit 1
fi

source "$CONF_FILE"
echo "-> Config loaded from $CONF_FILE"

#  Login check
echo "-> Verifying Azure login..."
az account show > /dev/null 2>&1 || { echo "ERROR: Not logged in. Run 'az login' first."; exit 1; }

SUBSCRIPTION=$(az account show --query "name" -o tsv)
echo "   Active subscription: $SUBSCRIPTION"

#  Resource Group
echo "-> Checking resource group '$RESOURCE_GROUP'..."
if az group show --name "$RESOURCE_GROUP" > /dev/null 2>&1; then
  echo "   Already exists, reusing."
else
  echo "   Creating resource group..."
  az group create \
    --name "$RESOURCE_GROUP" \
    --location "$LOCATION" \
    --tags $TAGS
  echo "   Resource group created."
fi

#  Log Analytics Workspace
echo "-> Checking Log Analytics workspace '$LOG_ANALYTICS_NAME'..."
if az monitor log-analytics workspace show \
    --workspace-name "$LOG_ANALYTICS_NAME" \
    --resource-group "$RESOURCE_GROUP" > /dev/null 2>&1; then
  echo "   Already exists, reusing."
else
  echo "   Creating Log Analytics workspace..."
  az monitor log-analytics workspace create \
    --workspace-name "$LOG_ANALYTICS_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --location "$LOCATION" \
    --retention-time "$RETENTION_DAYS" \
    --tags $TAGS
  echo "   Log Analytics workspace created."
fi

#  Application Insights
echo "-> Checking Application Insights '$APP_INSIGHTS_NAME'..."
if az monitor app-insights component show \
    --app "$APP_INSIGHTS_NAME" \
    --resource-group "$RESOURCE_GROUP" > /dev/null 2>&1; then
  echo "   Already exists, reusing."
else
  echo "   Creating Application Insights..."

  WORKSPACE_ID=$(az monitor log-analytics workspace show \
    --workspace-name "$LOG_ANALYTICS_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --query "id" -o tsv)

  az monitor app-insights component create \
    --app "$APP_INSIGHTS_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --location "$LOCATION" \
    --kind "web" \
    --application-type "web" \
    --workspace "$WORKSPACE_ID" \
    --tags $TAGS
  echo "   Application Insights created."
fi

#  Output
echo ""
echo "All resources created successfully."
echo ""
echo "--- Data for the team --------------------------------------------------------"

WORKSPACE_ID=$(az monitor log-analytics workspace show \
  --workspace-name "$LOG_ANALYTICS_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query "customerId" -o tsv)

INSTRUMENTATION_KEY=$(az monitor app-insights component show \
  --app "$APP_INSIGHTS_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query "instrumentationKey" -o tsv)

CONNECTION_STRING=$(az monitor app-insights component show \
  --app "$APP_INSIGHTS_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query "connectionString" -o tsv)

echo "   Log Analytics Workspace : $LOG_ANALYTICS_NAME"
echo "   Workspace ID            : $WORKSPACE_ID"
echo "   App Insights            : $APP_INSIGHTS_NAME"
echo "   Instrumentation Key     : *** retrieve from Key Vault ***"
echo "   Connection String       : *** retrieve from Key Vault ***"
echo ""
echo "   IMPORTANT: store the Connection String in Key Vault, not in code."
echo "------------------------------------------------------------------------------"
