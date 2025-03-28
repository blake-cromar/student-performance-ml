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
# 🧼 Purge soft-deleted ML workspace (with retry)
# ------------------------------------------------------------------------------
echo "🧼 Attempting to purge soft-deleted ML workspace: $WORKSPACE_NAME..."

PURGE_ATTEMPT=0
PURGE_MAX_ATTEMPTS=10
PURGE_DELAY=30  # seconds

PURGE_URL="https://management.azure.com/subscriptions/$SUBSCRIPTION_ID/providers/Microsoft.MachineLearningServices/locations/$LOCATION/workspaces/$WORKSPACE_NAME?api-version=2023-04-01"

while [ $PURGE_ATTEMPT -lt $PURGE_MAX_ATTEMPTS ]; do
  if az rest --method delete --url "$PURGE_URL"; then
    echo "✅ ML workspace purge succeeded."
    break
  else
    PURGE_ATTEMPT=$((PURGE_ATTEMPT + 1))
    echo "⚠️  Purge failed or workspace not ready (attempt $PURGE_ATTEMPT/$PURGE_MAX_ATTEMPTS). Retrying in $PURGE_DELAY seconds..."

    for ((i=PURGE_DELAY; i>0; i--)); do
      echo -ne "⏳ Retrying purge in ${i}s\r"
      sleep 1
    done
    echo ""
  fi
done

if [ $PURGE_ATTEMPT -eq $PURGE_MAX_ATTEMPTS ]; then
  echo "❌ ERROR: Failed to purge ML workspace after $PURGE_MAX_ATTEMPTS attempts. You may need to purge it manually later."
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