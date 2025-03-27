#!/bin/bash

# Load environment variables
set -a
source .env
set +a

set -e

echo "⚠️ WARNING: This will permanently delete and purge Azure ML resources in: $RESOURCE_GROUP"
read -p "Type 'yes' to continue: " confirm
if [[ "$confirm" != "yes" ]]; then
  echo "❌ Deletion cancelled."
  exit 1
fi

echo "🧹 Deleting compute instance: $NOTEBOOK_COMPUTE_NAME..."
az ml compute delete \
  --name "$NOTEBOOK_COMPUTE_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --workspace-name "$WORKSPACE_NAME" --yes || true

echo "🧹 Deleting dataset: $DATASET_NAME..."
az ml data delete \
  --name "$DATASET_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --workspace-name "$WORKSPACE_NAME" --yes || true

echo "🧹 Deleting Azure ML Workspace: $WORKSPACE_NAME..."
az ml workspace delete \
  --name "$WORKSPACE_NAME" \
  --resource-group "$RESOURCE_GROUP" --yes || true

echo "🧼 Purging soft-deleted ML workspace (if it exists)..."
az rest --method delete \
  --url "https://management.azure.com/subscriptions/$SUBSCRIPTION_ID/providers/Microsoft.MachineLearningServices/locations/$LOCATION/workspaces/$WORKSPACE_NAME?api-version=2023-04-01" || true

echo "🧹 Deleting Key Vault: $KEY_VAULT_NAME..."
az keyvault delete --name "$KEY_VAULT_NAME" --resource-group "$RESOURCE_GROUP" || true

echo "🧼 Purging soft-deleted Key Vault..."
az keyvault purge --name "$KEY_VAULT_NAME" || true

echo "🧹 Deleting Application Insights: $APP_INSIGHTS_NAME..."
az resource delete \
  --resource-group "$RESOURCE_GROUP" \
  --name "$APP_INSIGHTS_NAME" \
  --resource-type "Microsoft.Insights/components" || true

echo "🧹 Deleting Storage Account: $STORAGE_ACCOUNT_NAME..."
az storage account delete \
  --name "$STORAGE_ACCOUNT_NAME" \
  --resource-group "$RESOURCE_GROUP" --yes || true

# Optional: Delete the config file one level up
CONFIG_PATH="../config.json"
if [ -f "$CONFIG_PATH" ]; then
  echo "🗑️  Deleting config file: $CONFIG_PATH"
  rm "$CONFIG_PATH"
fi

echo "✅ All resources have been deleted and purged where applicable."