# env_check.sh

# ------------------------------------------------------------------------------
# 🧪 Function to check if a single required variable is set
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
# 📋 Function to check all required environment variables
# ------------------------------------------------------------------------------
check_required_variables() {
  echo "🔍 Checking required environment variables..."
  for var in SUBSCRIPTION_ID RESOURCE_GROUP LOCATION WORKSPACE_NAME STORAGE_ACCOUNT_NAME COMPUTE_SIZE \
             DATASET_NAME DATASET_PATH DATASET_DESCRIPTION NOTEBOOK_COMPUTE_NAME NOTEBOOK_COMPUTE_SIZE \
             APP_INSIGHTS_NAME KEY_VAULT_NAME CONTAINER_NAME CONFIG_FILE DATASTORE_NAME DATASET_VERSION
  do
    check_variable "$var"
  done
  echo "🚀 Starting deployment..."
  echo
}