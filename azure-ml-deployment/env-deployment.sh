#!/bin/bash

# ------------------------------------------------------------------------------
# 🚧 Load environment variables
# ------------------------------------------------------------------------------
set -a
source .env
set +a

set -e

# ------------------------------------------------------------------------------
# 🧩 Source shared function definitions
# ------------------------------------------------------------------------------
source ./env_check.sh
source ./retry_utils.sh

# ------------------------------------------------------------------------------
# 📋 Check all required environment variables
# ------------------------------------------------------------------------------
check_required_variables

# ------------------------------------------------------------------------------
# 🧪 Setup - Derive any computed values
# ------------------------------------------------------------------------------
echo "🧪 Deriving dataset blob name from local file path..."

# Ensure BLOB_NAME is dynamically set based on the loaded DATASET_PATH
BLOB_NAME=$(basename "$DATASET_PATH")

echo "📄 Blob name resolved as '$BLOB_NAME'."

# Generate created_at timestamp in ISO 8601 format (local time with timezone offset)
CREATED_AT=$(date +"%Y-%m-%dT%H:%M:%S%z")

# Extract parts for a detailed breakdown (local time)
CREATED_YEAR=$(date +"%Y")
CREATED_MONTH=$(date +"%B")   
CREATED_DAY=$(date +"%d")
CREATED_TIME=$(date +"%H:%M:%S %Z")

# Time Output
echo "📆 Workspace creation timestamp:"
echo "   🗓️  Date : $CREATED_MONTH $CREATED_DAY, $CREATED_YEAR"
echo "   ⏰ Time : $CREATED_TIME"
echo "   🧾 Full : $CREATED_AT"

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
# 🔑 Retrieve Storage Account Key (for auth-mode fallback)
# ------------------------------------------------------------------------------

echo "🔑 Retrieving storage account key for '$STORAGE_ACCOUNT_NAME'..."

STORAGE_KEY=$(az storage account keys list \
  --resource-group "$RESOURCE_GROUP" \
  --account-name "$STORAGE_ACCOUNT_NAME" \
  --query "[0].value" -o tsv)

if [[ -z "$STORAGE_KEY" ]]; then
  echo "❌ ERROR: Failed to retrieve storage account key. Check permissions or account name."
  exit 1
fi

echo "✅ Storage account key retrieved successfully."

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

retry_with_countdown 2 60 "az ml workspace create \
  --name \"$WORKSPACE_NAME\" \
  --resource-group \"$RESOURCE_GROUP\" \
  --location \"$LOCATION\" \
  --storage-account \"$STORAGE_ACCOUNT_ID\" \
  --key-vault \"$KEY_VAULT_ID\" \
  --application-insights \"$APP_INSIGHTS_ID\" \
  --update-dependent-resources"

# ------------------------------------------------------------------------------
# 🛢️ Creating Blob Storage Container
# ------------------------------------------------------------------------------

echo "🛢️  Creating container '$CONTAINER_NAME' in Storage Account '$STORAGE_ACCOUNT_NAME'..."

az storage container create \
  --name "$CONTAINER_NAME" \
  --account-name "$STORAGE_ACCOUNT_NAME" \
  --account-key "$STORAGE_KEY" \
  --only-show-errors \
  --output none

echo "✅ Container check complete. Continuing with dataset upload..."
echo ""

# ------------------------------------------------------------------------------
# 🗃️ Create custom Azure ML Datastore pointing to the uploaded container
# ------------------------------------------------------------------------------
echo "🗃️  Ensuring custom datastore '$DATASTORE_NAME' exists for container '$CONTAINER_NAME'..."

if az ml datastore show \
  --name "$DATASTORE_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --workspace-name "$WORKSPACE_NAME" \
  --only-show-errors > /dev/null 2>&1; then
  echo "✅ Datastore '$DATASTORE_NAME' already exists. Skipping creation."
else
  echo "📦 Creating custom datastore '$DATASTORE_NAME' using spec file..."

# 📝 Generate datastore.yml
cat <<EOF > datastore.yml
name: $DATASTORE_NAME
type: azure_blob
description: Custom Azure Blob datastore for project file storage
account_name: $STORAGE_ACCOUNT_NAME
container_name: $CONTAINER_NAME
credentials:
  account_key: $STORAGE_KEY
EOF

  # 🚀 Create the datastore
  if az ml datastore create \
    --file datastore.yml \
    --resource-group "$RESOURCE_GROUP" \
    --workspace-name "$WORKSPACE_NAME" \
    --only-show-errors; then
    echo "✅ Custom datastore '$DATASTORE_NAME' created successfully."
  else
    echo "❌ ERROR: Failed to create datastore '$DATASTORE_NAME'."
    rm -f datastore.yml
    exit 1
  fi

  # 🧹 Clean up
  rm -f datastore.yml
fi

# ------------------------------------------------------------------------------
# 📤 Uploading Dataset to Azure Blob Storage
# ------------------------------------------------------------------------------

if [ -f "$DATASET_PATH" ]; then
  echo "📤 Dataset file found locally at '$DATASET_PATH'. Uploading to Azure Blob Storage..."

  az storage blob upload \
    --account-name "$STORAGE_ACCOUNT_NAME" \
    --account-key "$STORAGE_KEY" \
    --container-name "$CONTAINER_NAME" \
    --file "$DATASET_PATH" \
    --name "$BLOB_NAME" \
    --overwrite \
    --only-show-errors

  UPLOADED_BLOB_URI="https://${STORAGE_ACCOUNT_NAME}.blob.core.windows.net/$CONTAINER_NAME/$BLOB_NAME"
  echo "✅ Dataset uploaded successfully:"
  echo "   $UPLOADED_BLOB_URI"
else
  echo "❌ ERROR: Dataset file not found at '$DATASET_PATH'"
  exit 1
fi

# Optional: wait a bit to ensure Azure indexes the blob
echo "⏳ Waiting a moment to allow blob indexing..."
sleep 2

# ------------------------------------------------------------------------------
# 🧾 Register Dataset in Azure ML using workspaceblobstore
# ------------------------------------------------------------------------------

echo "🔎 Detecting container associated with datastore '$DATASTORE_NAME'..."

DATASTORE_CONTAINER_NAME=$(az ml datastore show \
  --name "$DATASTORE_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --workspace-name "$WORKSPACE_NAME" \
  --query "container_name" -o tsv)

if [ -z "$DATASTORE_CONTAINER_NAME" ]; then
  echo "❌ ERROR: Could not retrieve container name for datastore '$DATASTORE_NAME'."
  exit 1
fi

echo "📦 Datastore '$DATASTORE_NAME' is linked to container '$DATASTORE_CONTAINER_NAME'."

# Confirm file is uploaded to the correct container
if [ "$CONTAINER_NAME" != "$DATASTORE_CONTAINER_NAME" ]; then
  echo "⚠️ WARNING: File is uploaded to container '$CONTAINER_NAME',"
  echo "            but datastore '$DATASTORE_NAME' points to '$DATASTORE_CONTAINER_NAME'."
  echo "💡 Consider uploading to the correct container or creating a custom datastore."
  exit 1
fi

echo "🧾 Registering dataset '$DATASET_NAME' in Azure ML using datastore path..."

az ml data create \
  --name "$DATASET_NAME" \
  ${DATASET_VERSION:+--version "$DATASET_VERSION"} \
  --path "azureml://datastores/$DATASTORE_NAME/paths/$CONTAINER_NAME/$BLOB_NAME" \
  --type uri_file \
  --description "$DATASET_DESCRIPTION" \
  --resource-group "$RESOURCE_GROUP" \
  --workspace-name "$WORKSPACE_NAME"

echo "✅ Dataset '$DATASET_NAME' registered successfully. Verifying..."

# ------------------------------------------------------------------------------
# 🔍 Verifying registration
# ------------------------------------------------------------------------------

az ml data show \
  --name "$DATASET_NAME" \
  ${DATASET_VERSION:+--version "$DATASET_VERSION"} \
  --resource-group "$RESOURCE_GROUP" \
  --workspace-name "$WORKSPACE_NAME" \
  --only-show-errors > /dev/null

if [ $? -eq 0 ]; then
  echo "✅ Dataset '$DATASET_NAME' is verified and viewable in Azure ML Studio."
else
  echo "❌ ERROR: Dataset registration failed or dataset not found in Azure ML."
  exit 1
fi

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

# Define the dataset URI using the Azure ML datastore path
DATASET_URI="azureml://datastores/$DATASTORE_NAME/paths/$CONTAINER_NAME/$BLOB_NAME"

echo "📝 Writing config file to $CONFIG_FILE..."

cat <<EOF > "$CONFIG_FILE"
{
  "created_at": "$CREATED_AT",
  "created_year": "$CREATED_YEAR",
  "created_month": "$CREATED_MONTH",
  "created_day": "$CREATED_DAY",
  "created_time": "$CREATED_TIME",
  "subscription_id": "$SUBSCRIPTION_ID",
  "resource_group": "$RESOURCE_GROUP",
  "location": "$LOCATION",
  "workspace_name": "$WORKSPACE_NAME",
  "storage_account_id": "$STORAGE_ACCOUNT_ID",
  "key_vault_id": "$KEY_VAULT_ID",
  "application_insights_id": "$APP_INSIGHTS_ID",
  "datastore_name": "$DATASTORE_NAME",
  "container_name": "$CONTAINER_NAME",
  "blob_name": "$BLOB_NAME",
  "dataset_name": "$DATASET_NAME",
  "dataset_uri": "$DATASET_URI",
  "dataset_version": "$DATASET_VERSION",
  "dataset_description": "$DATASET_DESCRIPTION",
  "compute_name": "$NOTEBOOK_COMPUTE_NAME",
  "compute_size": "$NOTEBOOK_COMPUTE_SIZE"
}
EOF

echo "📄 Config file written to: $CONFIG_FILE"

az storage blob upload \
  --account-name "$STORAGE_ACCOUNT_NAME" \
  --container-name "$CONTAINER_NAME" \
  --file "$CONFIG_FILE" \
  --name "config.json" \
  --auth-mode login \
  --overwrite \
  --only-show-errors

echo "✅ config.json uploaded to: https://${STORAGE_ACCOUNT_NAME}.blob.core.windows.net/$CONTAINER_NAME/config.json"
echo "✅ Config written to $CONFIG_FILE"