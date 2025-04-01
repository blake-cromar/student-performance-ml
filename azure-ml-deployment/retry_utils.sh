# ------------------------------------------------------------------------------
# ⏳ Countdown function
# ------------------------------------------------------------------------------
countdown() {
  local seconds=$1
  for ((i=seconds; i>0; i--)); do
    printf "\r\033[K⏳ Retrying in $i seconds..."
    sleep 1
  done
  echo ""
}

# ------------------------------------------------------------------------------
# 🔁 Generic retry wrapper with countdown
# Usage: retry_with_countdown <max_attempts> <delay_seconds> "<command>"
# ------------------------------------------------------------------------------
retry_with_countdown() {
  local max_attempts=$1
  local delay=$2
  local command="$3"
  local attempt=1

  while [ $attempt -le $max_attempts ]; do
    echo "🔁 Attempt $attempt of $max_attempts..."
    
    if eval "$command"; then
      echo "✅ Command succeeded on attempt $attempt."
      return 0
    else
      if [ $attempt -lt $max_attempts ]; then
        echo "⚠️  Command failed. Retrying in $delay seconds..."
        countdown $delay
      fi
    fi

    ((attempt++))
  done

  echo "❌ ERROR: Command failed after $max_attempts attempts."
  return 1
}