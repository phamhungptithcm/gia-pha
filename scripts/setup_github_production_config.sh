#!/usr/bin/env bash

set -euo pipefail

DEFAULT_ENVIRONMENT="production"

usage() {
  cat <<'EOF'
Usage:
  ./scripts/setup_github_production_config.sh [--repo owner/name] [--env production]

Required environment variables:
  FIREBASE_PROJECT_ID
  FIREBASE_FUNCTIONS_REGION
  APP_TIMEZONE
  FIREBASE_SERVICE_ACCOUNT
  BILLING_WEBHOOK_SECRET

Optional environment variables:
  BILLING_PENDING_TIMEOUT_MINUTES
  BILLING_PENDING_TIMEOUT_LIMIT
  BILLING_ALLOW_MANUAL_SETTLEMENT
  BILLING_CARD_CHECKOUT_URL_BASE
  OTP_PROVIDER
  OTP_ALLOWED_DIAL_CODES
  OTP_TWILIO_VERIFY_SERVICE_SID
  OTP_TWILIO_TIMEOUT_MS
  OTP_TWILIO_MAX_RETRIES
  OTP_TWILIO_BACKOFF_MS
  DEBUG_TOKEN_SIGNER_SERVICE_ACCOUNT
  APP_RUNTIME_CONFIG_COLLECTION
  APP_RUNTIME_CONFIG_DOC_ID
  BEFAM_ALLOW_BUNDLED_FIREBASE_OPTIONS
  BEFAM_INVALID_CHECKOUT_HOSTS
  BEFAM_FIREBASE_PROJECT_ID
  BEFAM_FIREBASE_STORAGE_BUCKET
  BEFAM_FIREBASE_ANDROID_API_KEY
  BEFAM_FIREBASE_ANDROID_APP_ID
  BEFAM_FIREBASE_ANDROID_MESSAGING_SENDER_ID
  BEFAM_FIREBASE_IOS_API_KEY
  BEFAM_FIREBASE_IOS_APP_ID
  BEFAM_FIREBASE_IOS_MESSAGING_SENDER_ID
  BEFAM_FIREBASE_IOS_BUNDLE_ID
  BEFAM_FIREBASE_WEB_API_KEY
  BEFAM_FIREBASE_WEB_APP_ID
  BEFAM_FIREBASE_WEB_MESSAGING_SENDER_ID
  BEFAM_FIREBASE_WEB_AUTH_DOMAIN
  BEFAM_FIREBASE_WEB_MEASUREMENT_ID

Optional environment secrets:
  CARD_WEBHOOK_SECRET
  OTP_TWILIO_ACCOUNT_SID
  OTP_TWILIO_AUTH_TOKEN
EOF
}

infer_repo() {
  local remote
  remote="$(git remote get-url origin 2>/dev/null || true)"
  if [[ -z "$remote" ]]; then
    return 1
  fi
  if [[ "$remote" =~ github\.com[:/]([^/]+/[^/.]+)(\.git)?$ ]]; then
    printf '%s\n' "${BASH_REMATCH[1]}"
    return 0
  fi
  return 1
}

require_command() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Missing required command: $cmd" >&2
    exit 1
  fi
}

require_non_empty_env() {
  local key="$1"
  local value="${!key:-}"
  if [[ -z "$value" ]]; then
    echo "Missing required env: $key" >&2
    return 1
  fi
  return 0
}

set_var_if_present() {
  local key="$1"
  local value="${!key:-}"
  if [[ -z "$value" ]]; then
    return 0
  fi
  gh variable set "$key" \
    --repo "$REPO" \
    --env "$ENV_NAME" \
    --body "$value" >/dev/null
  echo "Set variable: $key"
}

set_secret_if_present() {
  local key="$1"
  local value="${!key:-}"
  if [[ -z "$value" ]]; then
    return 0
  fi
  printf '%s' "$value" | gh secret set "$key" \
    --repo "$REPO" \
    --env "$ENV_NAME" >/dev/null
  echo "Set secret: $key"
}

REPO=""
ENV_NAME="$DEFAULT_ENVIRONMENT"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)
      REPO="${2:-}"
      shift 2
      ;;
    --env)
      ENV_NAME="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ -z "$REPO" ]]; then
  REPO="$(infer_repo || true)"
fi

if [[ -z "$REPO" ]]; then
  echo "Could not infer GitHub repo. Please pass --repo owner/name." >&2
  exit 1
fi

require_command gh
gh auth status >/dev/null

missing=0
for key in \
  FIREBASE_PROJECT_ID \
  FIREBASE_FUNCTIONS_REGION \
  APP_TIMEZONE \
  FIREBASE_SERVICE_ACCOUNT \
  BILLING_WEBHOOK_SECRET; do
  if ! require_non_empty_env "$key"; then
    missing=1
  fi
done
if [[ "$missing" -ne 0 ]]; then
  echo "Abort: please export required env vars then rerun." >&2
  exit 1
fi

echo "Applying GitHub environment configuration:"
echo "  repo: $REPO"
echo "  env : $ENV_NAME"

set_var_if_present FIREBASE_PROJECT_ID
set_var_if_present FIREBASE_FUNCTIONS_REGION
set_var_if_present APP_TIMEZONE
set_var_if_present APP_RUNTIME_CONFIG_COLLECTION
set_var_if_present APP_RUNTIME_CONFIG_DOC_ID
set_var_if_present BEFAM_ALLOW_BUNDLED_FIREBASE_OPTIONS
set_var_if_present BILLING_PENDING_TIMEOUT_MINUTES
set_var_if_present BILLING_PENDING_TIMEOUT_LIMIT
set_var_if_present BILLING_ALLOW_MANUAL_SETTLEMENT
set_var_if_present BILLING_CARD_CHECKOUT_URL_BASE
set_var_if_present OTP_PROVIDER
set_var_if_present OTP_ALLOWED_DIAL_CODES
set_var_if_present OTP_TWILIO_VERIFY_SERVICE_SID
set_var_if_present OTP_TWILIO_TIMEOUT_MS
set_var_if_present OTP_TWILIO_MAX_RETRIES
set_var_if_present OTP_TWILIO_BACKOFF_MS
set_var_if_present DEBUG_TOKEN_SIGNER_SERVICE_ACCOUNT
set_var_if_present BEFAM_INVALID_CHECKOUT_HOSTS
set_var_if_present BEFAM_FIREBASE_PROJECT_ID
set_var_if_present BEFAM_FIREBASE_STORAGE_BUCKET
set_var_if_present BEFAM_FIREBASE_ANDROID_API_KEY
set_var_if_present BEFAM_FIREBASE_ANDROID_APP_ID
set_var_if_present BEFAM_FIREBASE_ANDROID_MESSAGING_SENDER_ID
set_var_if_present BEFAM_FIREBASE_IOS_API_KEY
set_var_if_present BEFAM_FIREBASE_IOS_APP_ID
set_var_if_present BEFAM_FIREBASE_IOS_MESSAGING_SENDER_ID
set_var_if_present BEFAM_FIREBASE_IOS_BUNDLE_ID
set_var_if_present BEFAM_FIREBASE_WEB_API_KEY
set_var_if_present BEFAM_FIREBASE_WEB_APP_ID
set_var_if_present BEFAM_FIREBASE_WEB_MESSAGING_SENDER_ID
set_var_if_present BEFAM_FIREBASE_WEB_AUTH_DOMAIN
set_var_if_present BEFAM_FIREBASE_WEB_MEASUREMENT_ID

set_secret_if_present FIREBASE_SERVICE_ACCOUNT
set_secret_if_present BILLING_WEBHOOK_SECRET
set_secret_if_present CARD_WEBHOOK_SECRET
set_secret_if_present OTP_TWILIO_ACCOUNT_SID
set_secret_if_present OTP_TWILIO_AUTH_TOKEN

echo "Done."
