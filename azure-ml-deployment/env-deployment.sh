#!/bin/bash

# Load environment variables from .env file
set -a  # Automatically export all variables
source .env
set +a  # Stop exporting

# Set script to exit on error
set -e

echo "🚀 Starting deployment..."

# Step 1: Create Resource Group
echo "🛠  Creating Resource Group: $RESOURCE_GROUP in $LOCATION..."
az group create --name "$RESOURCE_GROUP" --location "$LOCATION"

# Step 2: Create Azure ML Workspace
echo "🛠  Creating Azure ML Workspace: $WORKSPACE_NAME..."
az ml workspace create --name "$WORKSPACE_NAME" --resource-group "$RESOURCE_GROUP" --location "$LOCATION"

# Step 3: Create Compute Instance
echo "🛠  Creating Compute Instance..."
az ml compute create --name "notebook-compute" --resource-group "$RESOURCE_GROUP" --workspace-name "$WORKSPACE_NAME" --size "Standard_D2s_v3"

# Step 4: Stop Compute Instance Immediately
echo "🛑 Stopping Compute Instance..."
az ml compute stop --name "notebook-compute" --resource-group "$RESOURCE_GROUP" --workspace-name "$WORKSPACE_NAME"

echo "✅ Deployment completed successfully!"
