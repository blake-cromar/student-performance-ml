#!/bin/bash

# Load environment variables from .env file
set -a  # Automatically export all variables
source .env
set +a  # Stop exporting

# Exit on error
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

echo "🔍 Checking required environment variables..."
check_variable "SUBSCRIPTION_ID"
check_variable "RESOURCE_GROUP"
check_variable "LOCATION"
check_variable "WORKSPACE_NAME"
check_variable "STORAGE_ACCOUNT_NAME"
check_variable "COMPUTE_SIZE"
check_variable "DATASET_NAME"
check_variable "DATASET_PATH"
check_variable "DATASET_DESCRIPTION"

echo "🚀 Starting deployment..."
echo

# Step 1: Create Resource Group
echo "🛠  Creating Resource Group: $RESOURCE_GROUP in $LOCATION..."
az group create --name "$RESOURCE_GROUP" --location "$LOCATION" || {
  echo "❌ ERROR: Failed to create resource group."
  exit 1
}
echo

# Step 2: Create Storage Account
echo "🛠  Creating Storage Account: $STORAGE_ACCOUNT_NAME..."
az storage account create --name "$STORAGE_ACCOUNT_NAME" --resource-group "$RESOURCE_GROUP" --location "$LOCATION" --sku "Standard_LRS" || {
  echo "❌ ERROR: Failed to create storage account."
  exit 1
}
echo

# Step 3: Create Azure ML Workspace
echo "🛠  Creating Azure ML Workspace: $WORKSPACE_NAME..."
STORAGE_ACCOUNT_ID="/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}/providers/Microsoft.Storage/storageAccounts/${STORAGE_ACCOUNT_NAME}"
echo "📦 Using storage account resource ID:"
echo "$STORAGE_ACCOUNT_ID"

az ml workspace create \
  --name "$WORKSPACE_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --storage-account "$STORAGE_ACCOUNT_ID" || {
    echo "❌ ERROR: Failed to create Azure ML workspace."
    exit 1
}
echo "✅ Azure ML Workspace created."
echo

# Step 4: Upload and register dataset
echo "📤 Uploading dataset: $DATASET_NAME from $DATASET_PATH..."

az ml data create --name "$DATASET_NAME" \
  --path "$DATASET_PATH" \
  --type uri_file \
  --description "$DATASET_DESCRIPTION" \
  --resource-group "$RESOURCE_GROUP" \
  --workspace-name "$WORKSPACE_NAME" || {
    echo "❌ ERROR: Failed to upload dataset."
    exit 1
}

echo "✅ Dataset '$DATASET_NAME' uploaded and registered in workspace."