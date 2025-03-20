#!/bin/bash

# Load environment variables from .env file
set -a  # Automatically export all variables
source .env
set +a  # Stop exporting

# Set script to exit on error
set -e

# Function to check if a required variable is set
check_variable() {
  if [[ -z "${!1}" ]]; then
    echo "❌ ERROR: Required variable '$1' is not set. Please check your .env file."
    exit 1
  fi
}

# Validate required environment variables
check_variable "SUBSCRIPTION_ID"
check_variable "RESOURCE_GROUP"
check_variable "LOCATION"
check_variable "WORKSPACE_NAME"
check_variable "STORAGE_ACCOUNT_NAME"
check_variable "COMPUTE_SIZE"

echo "🚀 Starting deployment..."

# Step 1: Create Resource Group
echo "🛠  Creating Resource Group: $RESOURCE_GROUP in $LOCATION..."
az group create --name "$RESOURCE_GROUP" --location "$LOCATION" || { echo "❌ ERROR: Failed to create resource group."; exit 1; }

# Step 2: Create Storage Account (Required for Azure ML)
echo "🛠  Creating Storage Account: $STORAGE_ACCOUNT_NAME..."
az storage account create --name "$STORAGE_ACCOUNT_NAME" --resource-group "$RESOURCE_GROUP" --location "$LOCATION" --sku "Standard_LRS" ||
{ echo "❌ ERROR: Failed to create storage account."; exit 1; }

# Step 3: Create Azure ML Workspace (Using Defaults for ACR, Key Vault, and App Insights)
echo "🛠  Creating Azure ML Workspace: $WORKSPACE_NAME..."
az ml workspace create --name "$WORKSPACE_NAME" --resource-group "$RESOURCE_GROUP" --location "$LOCATION" \
  --storage-account "/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}/providers/Microsoft.Storage/storageAccounts/${STORAGE_ACCOUNT_NAME}" || \
  { echo "❌ ERROR: Failed to create Azure ML workspace."; exit 1; }

# Step 4: Create Compute Instance with Improved Error Handling
echo "🛠  Creating Compute Instance with Standard_DS3_v2..."
az ml compute create --name "notebook-compute" --resource-group "$RESOURCE_GROUP" --workspace-name "$WORKSPACE_NAME" --size "$COMPUTE_SIZE" --type ComputeInstance ||
{ echo "⚠️ WARNING: Compute instance creation failed. Please check if Standard_DS3_v2 is available in your region."; exit 1; }

echo "✅ Deployment completed successfully!"
