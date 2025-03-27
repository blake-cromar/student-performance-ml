#!/bin/bash

# Load environment variables
set -a
source .env
set +a

set -e

# Function to check if a required variable is set
check_variable() {
  if [[ -z "${!1}" ]]; then
    echo "❌ ERROR: Required variable '$1' is not set. Please check your .env file."
    exit 1
  else
    echo "✅ '$1' is set to: ${!1}"
  fi
}

# Check all required environment variables
echo "🔍 Checking required environment variables..."
for var in SUBSCRIPTION_ID RESOURCE_GROUP LOCATION WORKSPACE_NAME STORAGE_ACCOUNT_NAME COMPUTE_SIZE \
           DATASET_NAME DATASET_PATH DATASET_DESCRIPTION NOTEBOOK_COMPUTE_NAME NOTEBOOK_COMPUTE_SIZE \
           APP_INSIGHTS_NAME KEY_VAULT_NAME CONTAINER_NAME
do
  check_variable "$var"
done

echo "🚀 Starting deployment..."
echo

# Step 1: Create Resource Group
echo "🛠  Creating Resource Group: $RESOURCE_GROUP in $LOCATION..."
az group create --name "$RESOURCE_GROUP" --location "$LOCATION"
echo

# Step 2: Create Storage Account
echo "🛠  Creating Storage Account: $STORAGE_ACCOUNT_NAME..."
az storage account create --name "$STORAGE_ACCOUNT_NAME" \
  --resource-group "$RESOURCE_GROUP" --location "$LOCATION" --sku "Standard_LRS"
echo

# Step 3: Create Application Insights
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

# Step 4: Create Key Vault
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

# Step 5: Create Azure ML Workspace with retry
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
    echo "⚠️  Workspace creation failed (attempt $attempt/$max_attempts). Retrying in $delay seconds..."
    sleep $delay
  fi
done

if [ $attempt -eq $max_attempts ]; then
  echo "❌ ERROR: Azure ML Workspace creation failed after $max_attempts attempts."
  exit 1
fi
echo

# Step 6: Creating a container for the data
  echo "🗂  Creating container '$CONTAINER_NAME' if it does not exist..."

  # Create the container (this step will always run)
  az storage container create \
    --name "$CONTAINER_NAME" \
    --account-name "$STORAGE_ACCOUNT_NAME" \
    --connection-string "$CONNECTION_STRING"

  echo "✅ Container '$CONTAINER_NAME' created."

# Step 7: Automated Dataset Upload
# Check if dataset file exists locally
if [ -f "$DATASET_PATH" ]; then
  echo "📤 Dataset file found locally at $DATASET_PATH. Uploading to Azure Blob Storage..."

  # Get the storage account connection string
  CONNECTION_STRING=$(az storage account show-connection-string \
    --name "$STORAGE_ACCOUNT_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --query connectionString -o tsv)



  # Upload the dataset to Azure Blob Storage
  az storage blob upload \
    --account-name "$STORAGE_ACCOUNT_NAME" \
    --container-name "$CONTAINER_NAME" \
    --file "$DATASET_PATH" \
    --name "$(basename "$DATASET_PATH")" \
    --connection-string "$CONNECTION_STRING" \
    --overwrite

  # Get the URI for the uploaded file
  DATASET_URI="https://${STORAGE_ACCOUNT_NAME}.blob.core.windows.net/$CONTAINER_NAME/$(basename "$DATASET_PATH")"
  echo "✅ Dataset uploaded to Azure Blob Storage at: $DATASET_URI"
else
  echo "❌ ERROR: Dataset file not found at $DATASET_PATH"
  exit 1
fi

# Step 8: Register dataset with Azure ML
echo "📤 Registering dataset '$DATASET_NAME' in Azure ML..."
az ml data create --name "$DATASET_NAME" \
  --path "$DATASET_URI" \
  --type uri_file \
  --description "$DATASET_DESCRIPTION" \
  --resource-group "$RESOURCE_GROUP" \
  --workspace-name "$WORKSPACE_NAME"
echo "✅ Dataset '$DATASET_NAME' registered in Azure ML."

# Step 9: Create compute instance for notebooks
echo "💻 Creating compute instance: $NOTEBOOK_COMPUTE_NAME..."
az ml compute create \
  --name "$NOTEBOOK_COMPUTE_NAME" \
  --size "$NOTEBOOK_COMPUTE_SIZE" \
  --type ComputeInstance \
  --resource-group "$RESOURCE_GROUP" \
  --workspace-name "$WORKSPACE_NAME"
echo "✅ Compute instance '$NOTEBOOK_COMPUTE_NAME' created."

# Step 10: Writing the config file
CONFIG_FILE="../config.json"
echo "📝 Writing config file to $CONFIG_FILE..."

cat <<EOF > "$CONFIG_FILE"
{
  "subscriptionId": "$SUBSCRIPTION_ID",
  "resourceGroup": "$RESOURCE_GROUP",
  "location": "$LOCATION",
  "workspaceName": "$WORKSPACE_NAME",
  "storageAccountId": "$STORAGE_ACCOUNT_ID",
  "keyVaultId": "$KEY_VAULT_ID",
  "appInsightsId": "$APP_INSIGHTS_ID",
  "datasetName": "$DATASET_NAME",
  "datasetPath": "$DATASET_URI",
  "computeName": "$NOTEBOOK_COMPUTE_NAME",
  "computeSize": "$NOTEBOOK_COMPUTE_SIZE"
}
EOF

echo "✅ Config written to $CONFIG_FILE"