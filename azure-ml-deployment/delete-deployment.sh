#!/bin/bash

# Load environment variables
set -a
source .env
set +a

set -e

echo "⚠️ WARNING: This will delete the entire resource group: $RESOURCE_GROUP in $LOCATION"
read -p "Type 'yes' to confirm: " confirm
if [[ "$confirm" != "yes" ]]; then
  echo "❌ Deletion cancelled."
  exit 1
fi

echo "🧨 Deleting resource group: $RESOURCE_GROUP..."
az group delete --name "$RESOURCE_GROUP" --yes --no-wait

# Optional: Remove config.json if it exists
CONFIG_PATH="../config.json"
if [ -f "$CONFIG_PATH" ]; then
  echo "🗑️  Deleting config file: $CONFIG_PATH"
  rm "$CONFIG_PATH"
fi

echo "✅ Deletion command issued. Resources will be deleted asynchronously."