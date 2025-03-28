#!/bin/bash

# ------------------------------------------------------------------------------
# 🚧 Load environment variables
# ------------------------------------------------------------------------------
set -a
source .env
set +a

set -e

# ------------------------------------------------------------------------------
# 🧪 Function to check if a required variable is set
# ------------------------------------------------------------------------------
check_variable() {
  if [[ -z "${!1}" ]]; then
    echo "❌ ERROR: Required variable '$1' is not set. Please check your .env file."
    exit 1
  else
    echo "✅ '$1' is set to: ${!1}"
  fi
}

# ------------------------------------------------------------------------------
# 📋 Check all required environment variables
# ------------------------------------------------------------------------------
echo "🔍 Checking required environment variables..."
for var in SUBSCRIPTION_ID RESOURCE_GROUP LOCATION WORKSPACE_NAME STORAGE_ACCOUNT_NAME COMPUTE_SIZE \
           DATASET_NAME DATASET_PATH DATASET_DESCRIPTION NOTEBOOK_COMPUTE_NAME NOTEBOOK_COMPUTE_SIZE \
           APP_INSIGHTS_NAME KEY_VAULT_NAME CONTAINER_NAME CONFIG_FILE
do
  check_variable "$var"
done

echo "🚀 Starting deployment..."
echo

# ------------------------------------------------------------------------------
# 🛠  Create Resource Group
# ------------------------------------------------------------------------------
echo "🛠  Creating Resource Group: $RESOURCE_GROUP in $LOCATION..."
az group create --name "$RESOURCE_GROUP" --location "$LOCATION"
echo

# ------------------------------------------------------------------------------
# 💾 Create Storage Account
# ------------------------------------------------------------------------------
echo "💾 Creating Storage Account: $STORAGE_ACCOUNT_NAME..."
az storage account create --name "$STORAGE_ACCOUNT_NAME" \
  --resource-group "$RESOURCE_GROUP" --location "$LOCATION" --sku "Standard_LRS"
echo

# ------------------------------------------------------------------------------
# 📈 Create Application Insights
# ------------------------------------------------------------------------------
echo "📈 Creating Application Insights: $APP_INSIGHTS_NAME..."
az monitor app-insights component create \
  --app "$APP_INSIGHTS_NAME" \
  --location "$LOCATION" \
  --resource-group "$RESOURCE_GROUP" \
  --application-type web
APP_INSIGHTS_ID=$(az monitor app-insights component show \
  --app "$APP_INSIGHTS_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query id -o tsv)
echo

# ------------------------------------------------------------------------------
# 🔐 Create Key Vault
# ------------------------------------------------------------------------------
echo "🔐 Creating Key Vault: $KEY_VAULT_NAME..."
az keyvault create \
  --name "$KEY_VAULT_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --location "$LOCATION"
KEY_VAULT_ID=$(az keyvault show \
  --name "$KEY_VAULT_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query id -o tsv)
echo

# ------------------------------------------------------------------------------
# 🧠 Create Azure ML Workspace with retry and countdown
# ------------------------------------------------------------------------------
echo "🧠 Creating Azure ML Workspace: $WORKSPACE_NAME..."
STORAGE_ACCOUNT_ID="/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}/providers/Microsoft.Storage/storageAccounts/${STORAGE_ACCOUNT_NAME}"

attempt=0
max_attempts=3
delay=60

while [ $attempt -lt $max_attempts ]; do
  if az ml workspace create \
    --name "$WORKSPACE_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --location "$LOCATION" \
    --storage-account "$STORAGE_ACCOUNT_ID" \
    --key-vault "$KEY_VAULT_ID" \
    --application-insights "$APP_INSIGHTS_ID" \
    --update-dependent-resources; then
    echo "✅ Azure ML Workspace created."
    break
  else
    attempt=$((attempt + 1))
    echo "⚠️  Workspace creation failed (attempt $attempt/$max_attempts) due to asynchronous loading issues. Retrying in $delay seconds..."

    echo -n "⏳ Waiting: "
    width=${#delay}

  for ((i=delay; i>0; i--)); do
    printf "\r⏳ Retrying in %2ds..." "$i"
    sleep 1
  done

    echo ""
  fi
done

if [ $attempt -eq $max_attempts ]; then
  echo "❌ ERROR: Azure ML Workspace creation failed after $max_attempts attempts."
  exit 1
fi

# ------------------------------------------------------------------------------
# 🛢️ Creating Blob Storage Container
# ------------------------------------------------------------------------------

echo "🛢️  Creating container '$CONTAINER_NAME' in Storage Account '$STORAGE_ACCOUNT_NAME'..."

az storage container create \
  --name "$CONTAINER_NAME" \
  --account-name "$STORAGE_ACCOUNT_NAME" \
  --auth-mode login \
  --only-show-errors \
  --output none

echo "✅ Container check complete. Continuing with dataset upload..."
echo ""

# ------------------------------------------------------------------------------
# 📤 Uploading Dataset to Azure Blob Storage
# ------------------------------------------------------------------------------

if [ -f "$DATASET_PATH" ]; then
  echo "📤 Dataset file found locally at '$DATASET_PATH'. Uploading to Azure Blob Storage..."

  CONNECTION_STRING=$(az storage account show-connection-string \
    --name "$STORAGE_ACCOUNT_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --query connectionString -o tsv)

  az storage blob upload \
    --account-name "$STORAGE_ACCOUNT_NAME" \
    --container-name "$CONTAINER_NAME" \
    --file "$DATASET_PATH" \
    --name "$(basename "$DATASET_PATH")" \
    --connection-string "$CONNECTION_STRING" \
    --overwrite \
    --only-show-errors

  DATASET_URI="https://${STORAGE_ACCOUNT_NAME}.blob.core.windows.net/$CONTAINER_NAME/$(basename "$DATASET_PATH")"
  echo "✅ Dataset uploaded successfully:"
  echo "   $DATASET_URI"
else
  echo "❌ ERROR: Dataset file not found at '$DATASET_PATH'"
  exit 1
fi

# ------------------------------------------------------------------------------
# 🧾 Register Dataset in Azure ML
# ------------------------------------------------------------------------------
echo "🧾 Registering dataset '$DATASET_NAME' in Azure ML..."
az ml data create --name "$DATASET_NAME" \
  --path "$DATASET_URI" \
  --type uri_file \
  --description "$DATASET_DESCRIPTION" \
  --resource-group "$RESOURCE_GROUP" \
  --workspace-name "$WORKSPACE_NAME"
echo "✅ Dataset '$DATASET_NAME' registered in Azure ML."

# ------------------------------------------------------------------------------
# 💻 Create Compute Instance for Notebooks
# ------------------------------------------------------------------------------
echo "💻 Creating compute instance: $NOTEBOOK_COMPUTE_NAME..."
az ml compute create \
  --name "$NOTEBOOK_COMPUTE_NAME" \
  --size "$NOTEBOOK_COMPUTE_SIZE" \
  --type ComputeInstance \
  --resource-group "$RESOURCE_GROUP" \
  --workspace-name "$WORKSPACE_NAME"
echo "✅ Compute instance '$NOTEBOOK_COMPUTE_NAME' created."

# ------------------------------------------------------------------------------
# 📝 Write and Upload config.json
# ------------------------------------------------------------------------------
echo "📝 Writing config file to $CONFIG_FILE..."

cat <<EOF > "$CONFIG_FILE"
{
  "subscription_id": "$SUBSCRIPTION_ID",
  "resource_group": "$RESOURCE_GROUP",
  "location": "$LOCATION",
  "workspace_name": "$WORKSPACE_NAME",
  "storage_account": "$STORAGE_ACCOUNT_ID",
  "key_vault": "$KEY_VAULT_ID",
  "application_insights": "$APP_INSIGHTS_ID",
  "container_registry": "$CONTAINER_REGISTRY_ID",
  "dataset_name": "$DATASET_NAME",
  "dataset_path": "$DATASET_URI",
  "compute_name": "$NOTEBOOK_COMPUTE_NAME",
  "compute_size": "$NOTEBOOK_COMPUTE_SIZE",
  "container_name": "$CONTAINER_NAME"
}
EOF

echo "📤 Uploading config.json to Azure Blob Storage..."
az storage blob upload \
  --account-name "$STORAGE_ACCOUNT_NAME" \
  --container-name "$CONTAINER_NAME" \
  --file "$CONFIG_FILE" \
  --name "config.json" \
  --connection-string "$CONNECTION_STRING" \
  --overwrite

echo "✅ config.json uploaded to: https://${STORAGE_ACCOUNT_NAME}.blob.core.windows.net/$CONTAINER_NAME/config.json"
echo "✅ Config written to $CONFIG_FILE"