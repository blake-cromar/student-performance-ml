#!/bin/bash

# Variables (customize these values)
RESOURCE_GROUP="student-performance-rg"
AML_WORKSPACE="student-performance-ws"
COMPUTE_NAME="jupyter-notebook"
LOCATION="norwayeast"  # Change to your preferred location
VM_SIZE="Standard_DS2_v2"  # The VM size you want to use for the compute instance
MIN_NODES=0  # Minimum number of nodes
MAX_NODES=1  # Maximum number of nodes (set 1 for a single instance)

# Create compute instance
echo "Creating compute instance: $COMPUTE_NAME"
az ml compute create \
  --name "$COMPUTE_NAME" \
  --type amlcompute \
  --size "$VM_SIZE" \
  --min-instances "$MIN_NODES" \
  --max-instances "$MAX_NODES" \
  --location "$LOCATION" \
  --resource-group "$RESOURCE_GROUP" \
  --workspace-name "$AML_WORKSPACE"

# Display the created compute instance
echo "Compute instance $COMPUTE_NAME has been created in workspace $AML_WORKSPACE."

