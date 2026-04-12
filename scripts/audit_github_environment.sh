#!/usr/bin/env bash

set -euo pipefail

DEFAULT_ENVIRONMENT="production"
STRICT_MODE="false"
REPO=""
ENV_NAME="$DEFAULT_ENVIRONMENT"

usage() {
  cat <<'EOF'
Usage:
  ./scripts/audit_github_environment.sh [--repo owner/name] [--env production|staging] [--strict]

What it checks:
  - Required GitHub environment vars
  - Required GitHub environment secrets
  - Production environment protection settings
  - Local app-ads.txt readiness for production web hosting

Examples:
  ./scripts/audit_github_environment.sh --repo phamhungptithcm/gia-pha --env production --strict
  ./scripts/audit_github_environment.sh --env staging
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

get_var_value() {
  local name="$1"
  gh variable get "$name" --repo "$REPO" --env "$ENV_NAME" 2>/dev/null || true
}

contains_name() {
  local haystack="$1"
  local needle="$2"
  jq -e --arg name "$needle" 'map(.name) | index($name) != null' <<<"$haystack" >/dev/null
}

print_missing_list() {
  local title="$1"
  shift
  local items=("$@")
  if [[ ${#items[@]} -eq 1 && -z "${items[0]}" ]]; then
    items=()
  fi
  echo "$title"
  if [[ ${#items[@]} -eq 0 ]]; then
    echo "  - none"
    return
  fi
  for item in "${items[@]}"; do
    echo "  - $item"
  done
}

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
    --strict)
      STRICT_MODE="true"
      shift
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
require_command jq
gh auth status >/dev/null

vars_json="$(gh variable list --repo "$REPO" --env "$ENV_NAME" --json name)"
secrets_json="$(gh secret list --repo "$REPO" --env "$ENV_NAME" --json name)"

required_vars=()
recommended_vars=()
required_secrets=()

case "$ENV_NAME" in
  production)
    required_vars=(
      FIREBASE_PROJECT_ID
      PRODUCTION_FIREBASE_PROJECT_ID
      STAGING_FIREBASE_PROJECT_ID
      FIREBASE_FUNCTIONS_REGION
      FIRESTORE_DATABASE_ID
      APP_TIMEZONE
      OTP_PROVIDER
      CALLABLE_ENFORCE_APP_CHECK
      GOOGLE_PLAY_PACKAGE_NAME
      BEFAM_ALLOW_BUNDLED_FIREBASE_OPTIONS
      BEFAM_ENABLE_APP_CHECK
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
      BEFAM_FIREBASE_FUNCTIONS_REGION
      BEFAM_DEFAULT_TIMEZONE
      BEFAM_OTP_PROVIDER
      BEFAM_WEB_BASE_URL
      BEFAM_INVALID_CHECKOUT_HOSTS
      BEFAM_IOS_APP_STORE_URL
      BEFAM_ANDROID_PLAY_STORE_URL
      BEFAM_ADMOB_ANDROID_APP_ID
      BEFAM_ADMOB_IOS_APP_ID
      BEFAM_ADMOB_ANDROID_BANNER_UNIT_ID
      BEFAM_ADMOB_ANDROID_INTERSTITIAL_UNIT_ID
      BEFAM_ADMOB_ANDROID_REWARDED_UNIT_ID
      BEFAM_ADMOB_IOS_BANNER_UNIT_ID
      BEFAM_ADMOB_IOS_INTERSTITIAL_UNIT_ID
      BEFAM_ADMOB_IOS_REWARDED_UNIT_ID
    )
    recommended_vars=(
      BEFAM_APP_CHECK_WEB_RECAPTCHA_SITE_KEY
    )
    required_secrets=(
      GCP_WORKLOAD_IDENTITY_PROVIDER
      GCP_SERVICE_ACCOUNT_EMAIL
      BILLING_WEBHOOK_SECRET
      APPLE_SHARED_SECRET
      ANDROID_RELEASE_KEYSTORE_BASE64
      ANDROID_RELEASE_KEYSTORE_PASSWORD
      ANDROID_RELEASE_KEY_ALIAS
      ANDROID_RELEASE_KEY_PASSWORD
      IOS_P12_BASE64
      IOS_P12_PASSWORD
      IOS_PROVISIONING_PROFILE_BASE64
      IOS_TEAM_ID
    )
    ;;
  staging)
    required_vars=(
      FIREBASE_PROJECT_ID
      FIREBASE_FUNCTIONS_REGION
      FIRESTORE_DATABASE_ID
      APP_TIMEZONE
      BEFAM_ALLOW_BUNDLED_FIREBASE_OPTIONS
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
      BEFAM_FIREBASE_FUNCTIONS_REGION
      BEFAM_DEFAULT_TIMEZONE
    )
    recommended_vars=(
      STAGING_MOBILE_PUBLISH_ENABLED
      CALLABLE_ENFORCE_APP_CHECK
      BEFAM_ENABLE_APP_CHECK
    )
    required_secrets=(
      FIREBASE_SERVICE_ACCOUNT
      ANDROID_STAGING_KEYSTORE_BASE64
      ANDROID_STAGING_KEYSTORE_PASSWORD
      ANDROID_STAGING_KEY_ALIAS
      ANDROID_STAGING_KEY_PASSWORD
    )
    ;;
  *)
    echo "Unsupported environment: $ENV_NAME" >&2
    exit 1
    ;;
esac

missing_required_vars=()
for key in "${required_vars[@]}"; do
  if ! contains_name "$vars_json" "$key"; then
    missing_required_vars+=("$key")
  fi
done

missing_recommended_vars=()
for key in "${recommended_vars[@]}"; do
  if ! contains_name "$vars_json" "$key"; then
    missing_recommended_vars+=("$key")
  fi
done

missing_required_secrets=()
for key in "${required_secrets[@]}"; do
  if ! contains_name "$secrets_json" "$key"; then
    missing_required_secrets+=("$key")
  fi
done

invalid_required_values=()

if [[ "$ENV_NAME" == "production" ]]; then
  befam_allow_bundled="$(get_var_value BEFAM_ALLOW_BUNDLED_FIREBASE_OPTIONS)"
  befam_otp_provider="$(get_var_value BEFAM_OTP_PROVIDER)"
  otp_provider="$(get_var_value OTP_PROVIDER)"
  callable_enforce_app_check="$(get_var_value CALLABLE_ENFORCE_APP_CHECK)"
  befam_web_base_url="$(get_var_value BEFAM_WEB_BASE_URL)"
  befam_ios_store_url="$(get_var_value BEFAM_IOS_APP_STORE_URL)"
  befam_android_store_url="$(get_var_value BEFAM_ANDROID_PLAY_STORE_URL)"
  firebase_project_id="$(get_var_value FIREBASE_PROJECT_ID)"
  production_project_id="$(get_var_value PRODUCTION_FIREBASE_PROJECT_ID)"
  staging_project_id="$(get_var_value STAGING_FIREBASE_PROJECT_ID)"
  befam_firebase_project_id="$(get_var_value BEFAM_FIREBASE_PROJECT_ID)"

  if [[ -n "$befam_allow_bundled" && "$befam_allow_bundled" != "false" ]]; then
    invalid_required_values+=("BEFAM_ALLOW_BUNDLED_FIREBASE_OPTIONS must be false for production")
  fi

  if [[ -n "$befam_otp_provider" && "$befam_otp_provider" != "twilio" ]]; then
    invalid_required_values+=("BEFAM_OTP_PROVIDER must be twilio for production")
  fi

  if [[ -n "$otp_provider" && "$otp_provider" != "twilio" ]]; then
    invalid_required_values+=("OTP_PROVIDER must be twilio for production")
  fi

  if [[ -n "$callable_enforce_app_check" && "$callable_enforce_app_check" != "true" ]]; then
    invalid_required_values+=("CALLABLE_ENFORCE_APP_CHECK must be true for production")
  fi

  if [[ -n "$befam_web_base_url" && ! "$befam_web_base_url" =~ ^https:// ]]; then
    invalid_required_values+=("BEFAM_WEB_BASE_URL must start with https://")
  fi

  if [[ -n "$befam_ios_store_url" && ! "$befam_ios_store_url" =~ ^https:// ]]; then
    invalid_required_values+=("BEFAM_IOS_APP_STORE_URL must start with https://")
  fi

  if [[ -n "$befam_android_store_url" && ! "$befam_android_store_url" =~ ^https:// ]]; then
    invalid_required_values+=("BEFAM_ANDROID_PLAY_STORE_URL must start with https://")
  fi

  if [[ -n "$firebase_project_id" && -n "$production_project_id" && "$firebase_project_id" != "$production_project_id" ]]; then
    invalid_required_values+=("FIREBASE_PROJECT_ID must match PRODUCTION_FIREBASE_PROJECT_ID in production")
  fi

  if [[ -n "$firebase_project_id" && -n "$staging_project_id" && "$firebase_project_id" == "$staging_project_id" ]]; then
    invalid_required_values+=("FIREBASE_PROJECT_ID must not match STAGING_FIREBASE_PROJECT_ID in production")
  fi

  if [[ -n "$befam_firebase_project_id" && -n "$firebase_project_id" && "$befam_firebase_project_id" != "$firebase_project_id" ]]; then
    invalid_required_values+=("BEFAM_FIREBASE_PROJECT_ID must match FIREBASE_PROJECT_ID in production")
  fi
fi

echo "GitHub environment audit"
echo "  repo: $REPO"
echo "  env:  $ENV_NAME"
echo
print_missing_list "Missing required vars:" "${missing_required_vars[@]:-}"
echo
print_missing_list "Missing recommended vars:" "${missing_recommended_vars[@]:-}"
echo
print_missing_list "Missing required secrets:" "${missing_required_secrets[@]:-}"
echo
print_missing_list "Invalid required values:" "${invalid_required_values[@]:-}"

app_ads_failed="false"
self_review_failed="false"
if [[ "$ENV_NAME" == "production" ]]; then
  echo
  if bash "$(dirname "$0")/verify_app_ads_txt.sh" "mobile/befam/web/app-ads.txt" >/tmp/befam-app-ads-audit.log 2>&1; then
    echo "app-ads.txt:"
    echo "  - ready"
  else
    app_ads_failed="true"
    echo "app-ads.txt:"
    sed 's/^/  - /' /tmp/befam-app-ads-audit.log
  fi

  echo
  env_json="$(gh api "repos/${REPO}/environments/${ENV_NAME}")"
  self_review_allowed="$(jq -r '.protection_rules[]? | select(.type=="required_reviewers") | .prevent_self_review // empty' <<<"$env_json" | head -n1)"
  if [[ "$self_review_allowed" == "true" ]]; then
    echo "Environment protection:"
    echo "  - prevent_self_review is enabled"
  else
    self_review_failed="true"
    echo "Environment protection:"
    echo "  - prevent_self_review is not enabled"
  fi
fi

has_failure="false"
if [[ ${#missing_required_vars[@]} -gt 0 || ${#missing_required_secrets[@]} -gt 0 ]]; then
  has_failure="true"
fi
if [[ ${#invalid_required_values[@]} -gt 0 ]]; then
  has_failure="true"
fi
if [[ "$ENV_NAME" == "production" && "$app_ads_failed" == "true" ]]; then
  has_failure="true"
fi
if [[ "$ENV_NAME" == "production" && "$self_review_failed" == "true" ]]; then
  has_failure="true"
fi

if [[ "$STRICT_MODE" == "true" && "$has_failure" == "true" ]]; then
  exit 1
fi
