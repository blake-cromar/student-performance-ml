assign_role() {
  local principal_id="$1"
  local role="$2"
  local subscription_id="$3"
  local resource_group="$4"

  if [ -z "$principal_id" ]; then
    echo "❌ ERROR: Principal ID is empty. Cannot assign role."
    return 1
  fi

  local scope="/subscriptions/$subscription_id/resourceGroups/$resource_group"

  echo "🔐 Assigning '$role' to identity at scope: $scope"
  az role assignment create \
    --assignee "$principal_id" \
    --role "$role" \
    --scope "$scope" \
    --only-show-errors
}