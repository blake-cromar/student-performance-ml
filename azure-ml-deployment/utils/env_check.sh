#!/bin/bash

# ------------------------------------------------------------------------------
# 🔐 List of sensitive variables (won't be printed to the console)
# ------------------------------------------------------------------------------
SENSITIVE_VARS=("")

# ------------------------------------------------------------------------------
# 🧪 Function to check if a single required variable is set
# ------------------------------------------------------------------------------
check_variable() {
  local var_name="$1"
  local var_value="${!var_name}"

  if [[ -z "$var_value" ]]; then
    echo "❌ ERROR: Required variable '$var_name' is not set. Please check your .env file."
    exit 1
  else
    # If the variable is in the sensitive list, redact its value
    if [[ " ${SENSITIVE_VARS[*]} " =~ " $var_name " ]]; then
      echo "✅ '$var_name' is set to: [REDACTED]"
    else
      echo "✅ '$var_name' is set to: $var_value"
    fi
  fi
}

# ------------------------------------------------------------------------------
# 📋 Function to check all required environment variables
# ------------------------------------------------------------------------------
check_required_variables() {
  echo "🔍 Checking required environment variables..."
  for var in SUBSCRIPTION_ID RESOURCE_GROUP LOCATION WORKSPACE_NAME STORAGE_ACCOUNT_NAME \
             DATASET_NAME DATASET_PATH DATASET_DESCRIPTION NOTEBOOK_COMPUTE_NAME NOTEBOOK_COMPUTE_SIZE \
             APP_INSIGHTS_NAME KEY_VAULT_NAME CONTAINER_NAME CONFIG_FILE DATASTORE_NAME DATASET_VERSION \
             DELIMITER HAS_HEADER ENCODING CONFIG_DATASET_NAME CONFIG_BLOB_NAME JSON_VERSION
  do
    check_variable "$var"
  done
}