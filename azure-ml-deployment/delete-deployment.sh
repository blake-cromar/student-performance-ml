#!/bin/bash

# ------------------------------------------------------------------------------
# 🚧 Load environment variables
# ------------------------------------------------------------------------------
set -a
source .env
set +a

set -e

# ------------------------------------------------------------------------------
# ⚠️ Confirm deletion to avoid accidents
# ------------------------------------------------------------------------------
echo "⚠️  WARNING: This will delete the entire resource group: $RESOURCE_GROUP in $LOCATION"
read -p "Type 'yes' to confirm: " confirm
if [[ "$confirm" != "yes" ]]; then
  echo "❌ Deletion cancelled."
  exit 1
fi

# ------------------------------------------------------------------------------
# 🧨 Delete the entire resource group
# ------------------------------------------------------------------------------
echo "🧨 Deleting resource group: $RESOURCE_GROUP..."
az group delete --name "$RESOURCE_GROUP" --yes --no-wait

# ------------------------------------------------------------------------------
# 🧼 Purge soft-deleted ML workspace
# ------------------------------------------------------------------------------
echo "🧼 Attempting to purge soft-deleted ML workspace: $WORKSPACE_NAME..."

# Alternative approach using az ml workspace delete
if az ml workspace delete --name "$WORKSPACE_NAME" --subscription "$SUBSCRIPTION_ID" --yes; then
  echo "✅ ML workspace purge succeeded using az ml workspace delete."
else
  # Fallback to using az rest method if the above fails
  echo "⚠️ Attempting to purge using az rest method..."
  PURGE_URL="https://management.azure.com/subscriptions/$SUBSCRIPTION_ID/providers/Microsoft.MachineLearningServices/locations/$LOCATION/workspaces/$WORKSPACE_NAME?api-version=2023-04-01"
  
  if az rest --method delete --url "$PURGE_URL"; then
    echo "✅ ML workspace purge succeeded using az rest method."
  else
    echo "❌ ERROR: Failed to purge ML workspace. You may need to purge it manually."
  fi
fi

# ------------------------------------------------------------------------------
# 🧼 Purge soft-deleted Key Vault (if it exists)
# ------------------------------------------------------------------------------
echo "🧼 Purging soft-deleted Key Vault (if it exists)..."
if ! az keyvault purge --name "$KEY_VAULT_NAME"; then
  echo "⚠️  Key Vault purge may have failed or wasn't necessary."
fi

# ------------------------------------------------------------------------------
# 🗑️  Delete the generated config.json file (if it exists)
# ------------------------------------------------------------------------------
CONFIG_PATH="../config.json"
if [ -f "$CONFIG_PATH" ]; then
  echo "🗑️  Deleting config file: $CONFIG_PATH"
  rm "$CONFIG_PATH"
fi

# ------------------------------------------------------------------------------
# ✅ Wrap-up message
# ------------------------------------------------------------------------------
echo "✅ Deletion command issued. Resources will be deleted asynchronously."