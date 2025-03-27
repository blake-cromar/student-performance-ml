#!/bin/bash

# --------------------------------------
# Load environment variables from .env
# --------------------------------------
set -a
source .env
set +a

# Exit immediately if any command fails
set -e

# --------------------------------------
# Confirm deletion to avoid accidents
# --------------------------------------
echo "⚠️ WARNING: This will delete the entire resource group: $RESOURCE_GROUP in $LOCATION"
read -p "Type 'yes' to confirm: " confirm
if [[ "$confirm" != "yes" ]]; then
  echo "❌ Deletion cancelled."
  exit 1
fi

# --------------------------------------
# Delete the entire resource group
# --------------------------------------
echo "🧨 Deleting resource group: $RESOURCE_GROUP..."
az group delete --name "$RESOURCE_GROUP" --yes --no-wait

# --------------------------------------
# Delay to ensure Azure registers the workspace deletion
# --------------------------------------
echo "⏳ Waiting for workspace deletion to register before purge..."
sleep 15

# --------------------------------------
# Purge the soft-deleted ML workspace (required to reuse name)
# --------------------------------------
echo "🧼 Purging soft-deleted ML workspace (if it exists)..."
if ! az rest --method delete \
  --url "https://management.azure.com/subscriptions/$SUBSCRIPTION_ID/providers/Microsoft.MachineLearningServices/locations/$LOCATION/workspaces/$WORKSPACE_NAME?api-version=2023-04-01"; then
  echo "⚠️  Workspace purge may have failed or wasn't necessary."
fi

# --------------------------------------
# Delete the generated config.json file (if it exists)
# --------------------------------------
CONFIG_PATH="../config.json"
if [ -f "$CONFIG_PATH" ]; then
  echo "🗑️  Deleting config file: $CONFIG_PATH"
  rm "$CONFIG_PATH"
fi

# --------------------------------------
# Wrap-up message
# --------------------------------------
echo "✅ Deletion command issued. Resources will be deleted asynchronously."