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
# 🧼 Purge Key Vault (if it exists)
# ------------------------------------------------------------------------------
echo "🧼 Attempting to purge Key Vault: $KEY_VAULT_NAME..."
if ! az keyvault purge --name "$KEY_VAULT_NAME"; then
  echo "⚠️  Key Vault purge may have failed or wasn't necessary."
fi

# ------------------------------------------------------------------------------
# 🧼 Purge ML workspace
# ------------------------------------------------------------------------------
echo "🧼 Attempting to purge ML workspace: $WORKSPACE_NAME..."

# Attempt using az ml workspace delete
if az ml workspace delete --name "$WORKSPACE_NAME" --resource-group "$RESOURCE_GROUP" --subscription "$SUBSCRIPTION_ID" --permanently-delete --yes; then
  echo "✅ ML workspace purge succeeded."
else
  echo "❌ ERROR: Failed to purge ML workspace. You may need to purge it manually."
fi

# ------------------------------------------------------------------------------
# 🧨 Delete the entire resource group
# ------------------------------------------------------------------------------
echo "🧨 Deleting resource group: $RESOURCE_GROUP..."
if az group delete --name "$RESOURCE_GROUP" --yes --no-wait; then
  echo "✅ Resource group deletion initiated."
else
  echo "❌ Failed to delete resource group. Check for errors."
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