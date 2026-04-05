#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$SCRIPT_DIR/../mobile/befam"
IOS_DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
LOCAL_ENV_FILE="${BEFAM_LOCAL_RELEASE_ENV_FILE:-$SCRIPT_DIR/local-release.env.example}"

SKIP_ANDROID="false"
SKIP_IOS="false"
INTERACTIVE_MODE="auto"
PROFILE="${BEFAM_RELEASE_PROFILE:-auto}"
BUILD_NAME="${BEFAM_BUILD_NAME:-}"
BUILD_NUMBER="${BEFAM_BUILD_NUMBER:-}"
IOS_EXPORT_OPTIONS_PLIST="${BEFAM_IOS_EXPORT_OPTIONS_PLIST:-}"
EXTRA_FLUTTER_ARGS=()
BEFAM_DART_DEFINE_ARGS=()

ANDROID_TEST_ADMOB_APP_ID="ca-app-pub-3940256099942544~3347511713"
IOS_TEST_ADMOB_APP_ID="ca-app-pub-3940256099942544~1458002511"
ANDROID_TEST_BANNER_AD_UNIT_ID="ca-app-pub-3940256099942544/6300978111"
IOS_TEST_BANNER_AD_UNIT_ID="ca-app-pub-3940256099942544/2934735716"
ANDROID_TEST_INTERSTITIAL_AD_UNIT_ID="ca-app-pub-3940256099942544/1033173712"
IOS_TEST_INTERSTITIAL_AD_UNIT_ID="ca-app-pub-3940256099942544/4411468910"
ANDROID_TEST_REWARDED_AD_UNIT_ID="ca-app-pub-3940256099942544/5224354917"
IOS_TEST_REWARDED_AD_UNIT_ID="ca-app-pub-3940256099942544/1712485313"

IOS_KEYCHAIN_PATH=""
IOS_PROFILE_PATH=""
IOS_EXPORT_OPTIONS_TMP=""
IOS_RESOLVED_TEAM_ID=""
IOS_RESOLVED_PROFILE_NAME=""
IOS_XCCONFIG_PATCHED="false"
IOS_XCCONFIG_ORIGINAL_CONTENT=""
_SHOULD_INTERACTIVE="false"

usage() {
  cat <<'EOF'
Build local mobile release artifacts for BeFam (Android AAB + iOS IPA).
Default behavior is selection + auto-fill (no manual typing required).

Usage:
  ./scripts/build_mobile_release_local.sh [options] [-- extra flutter args]

Main options:
  --interactive                Force selection mode (menu)
  --non-interactive            Disable selection mode
  --profile <name>             release profile: staging|env
                               - staging: mimic release-staging defaults
                               - env: keep your current env as-is
  --skip-android               Build only iOS IPA
  --skip-ios                   Build only Android AAB

Optional overrides:
  --build-name <name>          Override Flutter build name
  --build-number <number>      Override Flutter build number
  --ios-export-options <plist> Path to ExportOptions.plist for flutter build ipa
  -h, --help                   Show this help

Auto-filled by default:
  - Build name/build number:
    1) Try scripts/next_release_version.mjs (same release logic as CI)
    2) Fallback to pubspec.yaml version

Env file auto-load (interactive: selection menu):
  1) scripts/local-release.env.example  (default)
  2) scripts/github-staging.env.example
  Override with BEFAM_LOCAL_RELEASE_ENV_FILE.

Android signing sources (auto-detect):
  1) ANDROID_STAGING_KEYSTORE_PATH + password + alias
  2) ANDROID_STAGING_KEYSTORE_BASE64 + password + alias
  3) ANDROID_RELEASE_KEYSTORE_BASE64 / ANDROID_KEYSTORE_BASE64 + password + alias
  4) ANDROID_KEYSTORE_PATH (file) + password + alias
  5) mobile/befam/android/key.properties

iOS signing sources (auto-detect):
  1) --ios-export-options / BEFAM_IOS_EXPORT_OPTIONS_PLIST
  2) ios/ExportOptions.plist
  3) IOS_STAGING_P12_BASE64 + password + profile + team id
     (script auto-imports cert/profile and generates ExportOptions.plist)
  4) Fallback to local Xcode signing setup

Examples:
  ./scripts/build_mobile_release_local.sh
  ./scripts/build_mobile_release_local.sh --profile staging
  ./scripts/build_mobile_release_local.sh --skip-ios
  ./scripts/build_mobile_release_local.sh --non-interactive --profile staging
EOF
}

say() {
  printf "\n==> %s\n" "$*"
}

warn() {
  printf "Warning: %s\n" "$*" >&2
}

die() {
  printf "Error: %s\n" "$*" >&2
  exit 1
}

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    die "Missing required command: $cmd"
  fi
}

has_interactive_tty() {
  [[ -t 0 && -t 1 ]]
}

has_android_signing() {
  if [[ -n "${ANDROID_STAGING_KEYSTORE_PATH:-}" ]] && \
     [[ -n "${ANDROID_STAGING_KEYSTORE_PASSWORD:-}" ]] && \
     [[ -n "${ANDROID_STAGING_KEY_ALIAS:-}" ]] && \
     [[ -n "${ANDROID_STAGING_KEY_PASSWORD:-}" ]] && \
     [[ -f "${ANDROID_STAGING_KEYSTORE_PATH}" ]]; then
    return 0
  fi
  if [[ -n "${ANDROID_KEYSTORE_PATH:-}" ]] && \
     [[ -n "${ANDROID_KEYSTORE_PASSWORD:-}" ]] && \
     [[ -n "${ANDROID_KEY_ALIAS:-}" ]] && \
     [[ -n "${ANDROID_KEY_PASSWORD:-}" ]] && \
     [[ -f "${ANDROID_KEYSTORE_PATH}" ]]; then
    return 0
  fi
  if [[ -n "${ANDROID_STAGING_KEYSTORE_BASE64:-}" ]] && \
     [[ -n "${ANDROID_STAGING_KEYSTORE_PASSWORD:-}" ]] && \
     [[ -n "${ANDROID_STAGING_KEY_ALIAS:-}" ]] && \
     [[ -n "${ANDROID_STAGING_KEY_PASSWORD:-}" ]]; then
    return 0
  fi
  if [[ -n "${ANDROID_KEYSTORE_BASE64:-}" ]] && \
     [[ -n "${ANDROID_KEYSTORE_PASSWORD:-}" ]] && \
     [[ -n "${ANDROID_KEY_ALIAS:-}" ]] && \
     [[ -n "${ANDROID_KEY_PASSWORD:-}" ]]; then
    return 0
  fi
  if [[ -n "${ANDROID_RELEASE_KEYSTORE_BASE64:-}" ]] && \
     [[ -n "${ANDROID_RELEASE_KEYSTORE_PASSWORD:-}" ]] && \
     [[ -n "${ANDROID_RELEASE_KEY_ALIAS:-}" ]] && \
     [[ -n "${ANDROID_RELEASE_KEY_PASSWORD:-}" ]]; then
    return 0
  fi
  if [[ -f "$APP_DIR/android/key.properties" ]]; then
    return 0
  fi
  return 1
}

prompt_choice() {
  local prompt="$1"
  local default_index="$2"
  shift 2
  local options=("$@")
  local max="${#options[@]}"

  while true; do
    echo >&2
    echo "$prompt" >&2
    local i=1
    for option in "${options[@]}"; do
      printf "  %d) %s\n" "$i" "$option" >&2
      i=$((i + 1))
    done
    printf "Choose [1-%d] (default %d): " "$max" "$default_index" >&2
    local choice=""
    IFS= read -r choice || die "Interactive input is unavailable."
    if [[ -z "$choice" ]]; then
      choice="$default_index"
    fi
    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= max )); then
      printf "%s" "$choice"
      return 0
    fi
    warn "Please choose a number from 1 to $max."
  done
}

# Safe line-by-line env parser — does NOT execute shell code.
# Handles files with placeholder values like <your_app_id>, JSON, etc.
load_env_file_safe() {
  local file="$1"
  local line key value
  while IFS= read -r line || [[ -n "$line" ]]; do
    # Skip comments and blank lines
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ -z "${line//[[:space:]]/}" ]] && continue
    # Only process KEY=VALUE lines
    if [[ "$line" =~ ^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)=(.*) ]]; then
      key="${BASH_REMATCH[1]}"
      value="${BASH_REMATCH[2]}"
      # Strip surrounding single or double quotes
      if [[ "$value" =~ ^\"(.*)\"$ ]] || [[ "$value" =~ ^\'(.*)\'$ ]]; then
        value="${BASH_REMATCH[1]}"
      fi
      export "$key=$value"
    fi
  done < "$file"
}

load_local_env_file_if_present() {
  if [[ "$_SHOULD_INTERACTIVE" == "true" ]]; then
    # Build selection list from available env example files
    local env_options=()
    local env_paths=()

    if [[ -f "$SCRIPT_DIR/local-release.env.example" ]]; then
      env_options+=("local-release.env.example  (local signing + staging vars)")
      env_paths+=("$SCRIPT_DIR/local-release.env.example")
    fi
    if [[ -f "$SCRIPT_DIR/github-staging.env.example" ]]; then
      env_options+=("github-staging.env.example  (GitHub staging environment vars)")
      env_paths+=("$SCRIPT_DIR/github-staging.env.example")
    fi
    env_options+=("None — skip env file")
    env_paths+=("")

    local env_choice
    env_choice="$(prompt_choice "Choose env file to load:" 1 "${env_options[@]}")"
    local selected_path="${env_paths[$((env_choice - 1))]}"

    if [[ -n "$selected_path" ]]; then
      say "Loading env from $(basename "$selected_path")"
      load_env_file_safe "$selected_path"
    else
      warn "No env file loaded. Signing vars must already be set in environment."
    fi
  else
    # Non-interactive: load LOCAL_ENV_FILE if present, else fall back to github-staging.env.example
    local env_file_to_load=""
    if [[ -f "$LOCAL_ENV_FILE" ]]; then
      env_file_to_load="$LOCAL_ENV_FILE"
    elif [[ -f "$SCRIPT_DIR/github-staging.env.example" ]]; then
      warn "$(basename "$LOCAL_ENV_FILE") not found — falling back to github-staging.env.example"
      env_file_to_load="$SCRIPT_DIR/github-staging.env.example"
    fi
    if [[ -n "$env_file_to_load" ]]; then
      say "Loading env from $(basename "$env_file_to_load")"
      load_env_file_safe "$env_file_to_load"
    fi
  fi
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --interactive)
        INTERACTIVE_MODE="true"
        shift
        ;;
      --non-interactive)
        INTERACTIVE_MODE="false"
        shift
        ;;
      --profile)
        [[ $# -ge 2 ]] || die "--profile requires a value: staging|env"
        PROFILE="$2"
        shift 2
        ;;
      --skip-android)
        SKIP_ANDROID="true"
        shift
        ;;
      --skip-ios)
        SKIP_IOS="true"
        shift
        ;;
      --build-name)
        [[ $# -ge 2 ]] || die "--build-name requires a value"
        BUILD_NAME="$2"
        shift 2
        ;;
      --build-number)
        [[ $# -ge 2 ]] || die "--build-number requires a value"
        BUILD_NUMBER="$2"
        shift 2
        ;;
      --ios-export-options)
        [[ $# -ge 2 ]] || die "--ios-export-options requires a file path"
        IOS_EXPORT_OPTIONS_PLIST="$2"
        shift 2
        ;;
      --help|-h)
        usage
        exit 0
        ;;
      --)
        shift
        EXTRA_FLUTTER_ARGS+=("$@")
        break
        ;;
      *)
        EXTRA_FLUTTER_ARGS+=("$1")
        shift
        ;;
    esac
  done
}

run_selection_menu() {
  # Platform selection — pre-check Android signing to set a sensible default
  local android_signing_ok="false"
  has_android_signing && android_signing_ok="true"

  local platform_default=1
  if [[ "$android_signing_ok" == "false" ]]; then
    platform_default=3
    warn "Android signing not configured — defaulting to iOS only."
  fi

  local platform_choice
  platform_choice="$(prompt_choice \
    "Choose build target:" \
    "$platform_default" \
    "Android AAB + iOS IPA" \
    "Android AAB only" \
    "iOS IPA only")"

  case "$platform_choice" in
    1) SKIP_ANDROID="false"; SKIP_IOS="false" ;;
    2) SKIP_ANDROID="false"; SKIP_IOS="true" ;;
    3) SKIP_ANDROID="true"; SKIP_IOS="false" ;;
  esac

  # If Android is selected but signing is still missing, offer resolution
  if [[ "$SKIP_ANDROID" == "false" ]] && ! has_android_signing; then
    local android_fallback
    android_fallback="$(prompt_choice \
      "Android signing credentials not found. Choose action:" \
      1 \
      "Skip Android — build iOS only" \
      "Abort and configure signing first")"
    case "$android_fallback" in
      1)
        SKIP_ANDROID="true"
        warn "Android build skipped. Set ANDROID_STAGING_* vars in local-release.env.example to enable."
        ;;
      2)
        die "Aborted. Set ANDROID_STAGING_* (or ANDROID_*) vars and retry."
        ;;
    esac
  fi

  # Profile selection
  local profile_choice
  profile_choice="$(prompt_choice \
    "Choose release profile:" \
    1 \
    "Staging (same behavior as release-staging)" \
    "Use current environment values as-is")"

  case "$profile_choice" in
    1) PROFILE="staging" ;;
    2) PROFILE="env" ;;
  esac
}

resolve_profile_defaults() {
  if [[ "$PROFILE" == "auto" ]]; then
    PROFILE="staging"
  fi

  case "$PROFILE" in
    staging)
      export BEFAM_ALLOW_BUNDLED_FIREBASE_OPTIONS="true"
      export BEFAM_OTP_PROVIDER="firebase"
      export BEFAM_ALLOW_FIREBASE_PHONE_FALLBACK="false"
      : "${BEFAM_ENABLE_APP_CHECK:=true}"
      export BEFAM_ENABLE_APP_CHECK
      : "${ANDROID_ADMOB_APPLICATION_ID:=$ANDROID_TEST_ADMOB_APP_ID}"
      : "${ADMOB_APPLICATION_ID:=$IOS_TEST_ADMOB_APP_ID}"
      : "${BEFAM_ADMOB_ANDROID_BANNER_UNIT_ID:=$ANDROID_TEST_BANNER_AD_UNIT_ID}"
      : "${BEFAM_ADMOB_ANDROID_INTERSTITIAL_UNIT_ID:=$ANDROID_TEST_INTERSTITIAL_AD_UNIT_ID}"
      : "${BEFAM_ADMOB_ANDROID_REWARDED_UNIT_ID:=$ANDROID_TEST_REWARDED_AD_UNIT_ID}"
      : "${BEFAM_ADMOB_IOS_BANNER_UNIT_ID:=$IOS_TEST_BANNER_AD_UNIT_ID}"
      : "${BEFAM_ADMOB_IOS_INTERSTITIAL_UNIT_ID:=$IOS_TEST_INTERSTITIAL_AD_UNIT_ID}"
      : "${BEFAM_ADMOB_IOS_REWARDED_UNIT_ID:=$IOS_TEST_REWARDED_AD_UNIT_ID}"
      export ANDROID_ADMOB_APPLICATION_ID
      export ADMOB_APPLICATION_ID
      export BEFAM_ADMOB_ANDROID_BANNER_UNIT_ID
      export BEFAM_ADMOB_ANDROID_INTERSTITIAL_UNIT_ID
      export BEFAM_ADMOB_ANDROID_REWARDED_UNIT_ID
      export BEFAM_ADMOB_IOS_BANNER_UNIT_ID
      export BEFAM_ADMOB_IOS_INTERSTITIAL_UNIT_ID
      export BEFAM_ADMOB_IOS_REWARDED_UNIT_ID
      export ALLOW_TEST_ADMOB_APP_IDS="true"
      ;;
    env)
      :
      ;;
    *)
      die "Invalid profile '$PROFILE'. Use: staging|env"
      ;;
  esac
}

build_number_from_semver() {
  local version="$1"
  local major minor patch
  IFS=. read -r major minor patch <<<"$version"
  if [[ "$major" =~ ^[0-9]+$ && "$minor" =~ ^[0-9]+$ && "$patch" =~ ^[0-9]+$ ]]; then
    printf "%d" "$((major * 10000 + minor * 100 + patch))"
    return 0
  fi
  return 1
}

resolve_build_metadata_auto() {
  local pubspec_line pubspec_build_name pubspec_build_number
  pubspec_line="$(awk '/^version:/ {print $2; exit}' "$APP_DIR/pubspec.yaml")"
  if [[ -z "$pubspec_line" ]]; then
    die "Unable to read version from $APP_DIR/pubspec.yaml"
  fi

  pubspec_build_name="${pubspec_line%%+*}"
  if [[ "$pubspec_line" == *"+"* ]]; then
    pubspec_build_number="${pubspec_line##*+}"
  else
    pubspec_build_number=""
  fi

  local release_json auto_build_name auto_build_number
  if command -v node >/dev/null 2>&1 && [[ -f "$SCRIPT_DIR/next_release_version.mjs" ]]; then
    release_json="$(node "$SCRIPT_DIR/next_release_version.mjs" 2>/dev/null || true)"
    auto_build_name="$(printf '%s\n' "$release_json" | sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)"
    auto_build_number="$(printf '%s\n' "$release_json" | sed -n 's/.*"build_number"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)"
  else
    auto_build_name=""
    auto_build_number=""
  fi

  if [[ -z "$BUILD_NAME" ]]; then
    BUILD_NAME="${auto_build_name:-$pubspec_build_name}"
  fi

  if [[ -z "$BUILD_NUMBER" ]]; then
    if [[ -n "$auto_build_number" ]]; then
      BUILD_NUMBER="$auto_build_number"
    elif [[ -n "$pubspec_build_number" && "$pubspec_build_number" =~ ^[0-9]+$ ]]; then
      BUILD_NUMBER="$pubspec_build_number"
    elif derived_build_number="$(build_number_from_semver "$BUILD_NAME" 2>/dev/null)"; then
      BUILD_NUMBER="$derived_build_number"
    else
      BUILD_NUMBER="$(date +%y%m%d%H%M)"
    fi
  fi

  if ! [[ "$BUILD_NUMBER" =~ ^[0-9]+$ ]]; then
    die "build-number must be numeric. Current value: $BUILD_NUMBER"
  fi
}

prepare_android_release_signing() {
  if [[ -n "${ANDROID_STAGING_KEYSTORE_PATH:-}" ]] && \
     [[ -n "${ANDROID_STAGING_KEYSTORE_PASSWORD:-}" ]] && \
     [[ -n "${ANDROID_STAGING_KEY_ALIAS:-}" ]] && \
     [[ -n "${ANDROID_STAGING_KEY_PASSWORD:-}" ]] && \
     [[ -f "${ANDROID_STAGING_KEYSTORE_PATH}" ]]; then
    export ANDROID_KEYSTORE_PATH="$ANDROID_STAGING_KEYSTORE_PATH"
    export ANDROID_KEYSTORE_PASSWORD="$ANDROID_STAGING_KEYSTORE_PASSWORD"
    export ANDROID_KEY_ALIAS="$ANDROID_STAGING_KEY_ALIAS"
    export ANDROID_KEY_PASSWORD="$ANDROID_STAGING_KEY_PASSWORD"
    return 0
  fi

  if [[ -n "${ANDROID_KEYSTORE_PATH:-}" ]] && \
     [[ -n "${ANDROID_KEYSTORE_PASSWORD:-}" ]] && \
     [[ -n "${ANDROID_KEY_ALIAS:-}" ]] && \
     [[ -n "${ANDROID_KEY_PASSWORD:-}" ]] && \
     [[ -f "${ANDROID_KEYSTORE_PATH}" ]]; then
    return 0
  fi

  local keystore_b64="" keystore_password="" key_alias="" key_password=""

  if [[ -n "${ANDROID_STAGING_KEYSTORE_BASE64:-}" ]] && \
     [[ -n "${ANDROID_STAGING_KEYSTORE_PASSWORD:-}" ]] && \
     [[ -n "${ANDROID_STAGING_KEY_ALIAS:-}" ]] && \
     [[ -n "${ANDROID_STAGING_KEY_PASSWORD:-}" ]]; then
    keystore_b64="$ANDROID_STAGING_KEYSTORE_BASE64"
    keystore_password="$ANDROID_STAGING_KEYSTORE_PASSWORD"
    key_alias="$ANDROID_STAGING_KEY_ALIAS"
    key_password="$ANDROID_STAGING_KEY_PASSWORD"
  elif [[ -n "${ANDROID_KEYSTORE_BASE64:-}" ]] && \
       [[ -n "${ANDROID_KEYSTORE_PASSWORD:-}" ]] && \
       [[ -n "${ANDROID_KEY_ALIAS:-}" ]] && \
       [[ -n "${ANDROID_KEY_PASSWORD:-}" ]]; then
    keystore_b64="$ANDROID_KEYSTORE_BASE64"
    keystore_password="$ANDROID_KEYSTORE_PASSWORD"
    key_alias="$ANDROID_KEY_ALIAS"
    key_password="$ANDROID_KEY_PASSWORD"
  elif [[ -n "${ANDROID_RELEASE_KEYSTORE_BASE64:-}" ]] && \
       [[ -n "${ANDROID_RELEASE_KEYSTORE_PASSWORD:-}" ]] && \
       [[ -n "${ANDROID_RELEASE_KEY_ALIAS:-}" ]] && \
       [[ -n "${ANDROID_RELEASE_KEY_PASSWORD:-}" ]]; then
    keystore_b64="$ANDROID_RELEASE_KEYSTORE_BASE64"
    keystore_password="$ANDROID_RELEASE_KEYSTORE_PASSWORD"
    key_alias="$ANDROID_RELEASE_KEY_ALIAS"
    key_password="$ANDROID_RELEASE_KEY_PASSWORD"
  fi

  if [[ -n "$keystore_b64" ]]; then
    local decoded_keystore_path
    decoded_keystore_path="$(mktemp "${TMPDIR:-/tmp}/befam-android-release-XXXXXX")"
    printf '%s' "$keystore_b64" | base64 --decode > "$decoded_keystore_path"
    export ANDROID_KEYSTORE_PATH="$decoded_keystore_path"
    export ANDROID_KEYSTORE_PASSWORD="$keystore_password"
    export ANDROID_KEY_ALIAS="$key_alias"
    export ANDROID_KEY_PASSWORD="$key_password"
    return 0
  fi

  if [[ -f "$APP_DIR/android/key.properties" ]]; then
    return 0
  fi

  die "Missing Android signing. Set ANDROID_STAGING_* (or ANDROID_*) vars, or provide android/key.properties."
}

cleanup_ios_signing() {
  # Restore Flutter Release xcconfig if it was patched for CI-style manual signing
  if [[ "$IOS_XCCONFIG_PATCHED" == "true" ]]; then
    local xcconfig_path="$APP_DIR/ios/Flutter/Release.xcconfig"
    if [[ -f "$xcconfig_path" ]]; then
      printf '%s' "$IOS_XCCONFIG_ORIGINAL_CONTENT" > "$xcconfig_path"
    fi
    IOS_XCCONFIG_PATCHED="false"
  fi
  if [[ -n "$IOS_KEYCHAIN_PATH" && -f "$IOS_KEYCHAIN_PATH" ]]; then
    security delete-keychain "$IOS_KEYCHAIN_PATH" >/dev/null 2>&1 || true
  fi
  if [[ -n "$IOS_PROFILE_PATH" && -f "$IOS_PROFILE_PATH" ]]; then
    rm -f "$IOS_PROFILE_PATH"
  fi
  if [[ -n "$IOS_EXPORT_OPTIONS_TMP" && -f "$IOS_EXPORT_OPTIONS_TMP" ]]; then
    rm -f "$IOS_EXPORT_OPTIONS_TMP"
  fi
}

prepare_ios_release_signing() {
  if [[ -n "$IOS_EXPORT_OPTIONS_PLIST" ]]; then
    [[ -f "$IOS_EXPORT_OPTIONS_PLIST" ]] || die "Export options plist not found: $IOS_EXPORT_OPTIONS_PLIST"
    return 0
  fi

  if [[ -f "$APP_DIR/ios/ExportOptions.plist" ]]; then
    IOS_EXPORT_OPTIONS_PLIST="$APP_DIR/ios/ExportOptions.plist"
    return 0
  fi

  local p12_b64="${IOS_STAGING_P12_BASE64:-${IOS_P12_BASE64:-}}"
  local p12_password="${IOS_STAGING_P12_PASSWORD:-${IOS_P12_PASSWORD:-}}"
  local profile_b64="${IOS_STAGING_PROVISIONING_PROFILE_BASE64:-${IOS_PROVISIONING_PROFILE_BASE64:-}}"
  local team_id="${IOS_STAGING_TEAM_ID:-${IOS_TEAM_ID:-}}"
  local bundle_id="${BEFAM_FIREBASE_IOS_BUNDLE_ID:-com.familyclanapp.befam}"

  if [[ -z "$p12_b64" || -z "$p12_password" || -z "$profile_b64" || -z "$team_id" ]]; then
    warn "iOS signing env bundle not found. Falling back to local Xcode signing setup."
    return 0
  fi

  require_cmd security

  local cert_path profile_plist profile_uuid profile_name keychain_password
  cert_path="$(mktemp "${TMPDIR:-/tmp}/befam-signing-cert-XXXXXX")"
  IOS_PROFILE_PATH="$(mktemp "${TMPDIR:-/tmp}/befam-profile-XXXXXX")"
  profile_plist="$(mktemp "${TMPDIR:-/tmp}/befam-profile-plist-XXXXXX")"
  IOS_KEYCHAIN_PATH="$(mktemp "${TMPDIR:-/tmp}/befam-signing-XXXXXX")"
  keychain_password="$(openssl rand -hex 24)"

  printf '%s' "$p12_b64" | base64 --decode > "$cert_path"
  printf '%s' "$profile_b64" | base64 --decode > "$IOS_PROFILE_PATH"

  security create-keychain -p "$keychain_password" "$IOS_KEYCHAIN_PATH"
  security set-keychain-settings -lut 21600 "$IOS_KEYCHAIN_PATH"
  security unlock-keychain -p "$keychain_password" "$IOS_KEYCHAIN_PATH"
  security list-keychains -d user -s "$IOS_KEYCHAIN_PATH" login.keychain-db
  security default-keychain -s "$IOS_KEYCHAIN_PATH"

  security import "$cert_path" \
    -k "$IOS_KEYCHAIN_PATH" \
    -P "$p12_password" \
    -A \
    -t cert \
    -f pkcs12
  security set-key-partition-list \
    -S apple-tool:,apple:,codesign: \
    -s \
    -k "$keychain_password" \
    "$IOS_KEYCHAIN_PATH"

  mkdir -p "$HOME/Library/MobileDevice/Provisioning Profiles"
  security cms -D -i "$IOS_PROFILE_PATH" > "$profile_plist"
  profile_uuid=$(/usr/libexec/PlistBuddy -c "Print UUID" "$profile_plist")
  profile_name=$(/usr/libexec/PlistBuddy -c "Print Name" "$profile_plist")
  cp "$IOS_PROFILE_PATH" "$HOME/Library/MobileDevice/Provisioning Profiles/${profile_uuid}.mobileprovision"

  IOS_EXPORT_OPTIONS_TMP="$(mktemp "${TMPDIR:-/tmp}/befam-export-options-XXXXXX")"
  cat > "$IOS_EXPORT_OPTIONS_TMP" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key>
  <string>app-store</string>
  <key>signingStyle</key>
  <string>manual</string>
  <key>teamID</key>
  <string>${team_id}</string>
  <key>provisioningProfiles</key>
  <dict>
    <key>${bundle_id}</key>
    <string>${profile_name}</string>
  </dict>
  <key>stripSwiftSymbols</key>
  <true/>
  <key>compileBitcode</key>
  <false/>
</dict>
</plist>
EOF
  IOS_EXPORT_OPTIONS_PLIST="$IOS_EXPORT_OPTIONS_TMP"
  IOS_RESOLVED_TEAM_ID="$team_id"
  IOS_RESOLVED_PROFILE_NAME="$profile_name"

  rm -f "$cert_path" "$profile_plist"
}

build_befam_dart_define_args() {
  local allow_bundled="${BEFAM_ALLOW_BUNDLED_FIREBASE_OPTIONS:-true}"
  local otp_provider="${BEFAM_OTP_PROVIDER:-}"
  if [[ -z "$otp_provider" && "$allow_bundled" == "true" ]]; then
    otp_provider="firebase"
  fi

  BEFAM_DART_DEFINE_ARGS=(
    "--dart-define=BEFAM_ALLOW_BUNDLED_FIREBASE_OPTIONS=${allow_bundled}"
  )
  if [[ -n "$otp_provider" ]]; then
    BEFAM_DART_DEFINE_ARGS+=("--dart-define=BEFAM_OTP_PROVIDER=${otp_provider}")
  fi

  local firebase_define_keys=(
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
    BEFAM_INVALID_CHECKOUT_HOSTS
    BEFAM_ENABLE_APP_CHECK
    BEFAM_APP_CHECK_WEB_RECAPTCHA_SITE_KEY
    BEFAM_BILLING_PENDING_TIMEOUT_MINUTES
    BEFAM_IOS_APP_STORE_URL
    BEFAM_ANDROID_PLAY_STORE_URL
    BEFAM_ADMOB_ANDROID_BANNER_UNIT_ID
    BEFAM_ADMOB_ANDROID_INTERSTITIAL_UNIT_ID
    BEFAM_ADMOB_ANDROID_REWARDED_UNIT_ID
    BEFAM_ADMOB_IOS_BANNER_UNIT_ID
    BEFAM_ADMOB_IOS_INTERSTITIAL_UNIT_ID
    BEFAM_ADMOB_IOS_REWARDED_UNIT_ID
  )

  local key
  for key in "${firebase_define_keys[@]}"; do
    local value="${!key:-}"
    if [[ -n "$value" ]]; then
      BEFAM_DART_DEFINE_ARGS+=("--dart-define=${key}=${value}")
    fi
  done
}

build_android_aab() {
  prepare_android_release_signing
  flutter build appbundle \
    --release \
    --build-name "$BUILD_NAME" \
    --build-number "$BUILD_NUMBER" \
    ${BEFAM_DART_DEFINE_ARGS[@]+"${BEFAM_DART_DEFINE_ARGS[@]}"} \
    ${EXTRA_FLUTTER_ARGS[@]+"${EXTRA_FLUTTER_ARGS[@]}"}
}

build_ios_ipa() {
  if [[ "$(uname -s)" != "Darwin" ]]; then
    die "iOS IPA build requires macOS. Use --skip-ios on non-macOS hosts."
  fi

  if ! command -v pod >/dev/null 2>&1; then
    die "Missing CocoaPods command 'pod'. Install it before building IPA."
  fi

  prepare_ios_release_signing

  (cd "$APP_DIR/ios" && pod install)

  # Mirror the CI signing approach: inject PROVISIONING_PROFILE_SPECIFIER into
  # Flutter's Release xcconfig so it applies ONLY to the Runner target.
  # Setting it via FLUTTER_XCODE_PROVISIONING_PROFILE_SPECIFIER (command-line)
  # would apply it globally to all xcodebuild targets including CocoaPods static
  # library pod targets, causing "does not support provisioning profiles" errors.
  if [[ -n "$IOS_RESOLVED_PROFILE_NAME" ]]; then
    local xcconfig_path="$APP_DIR/ios/Flutter/Release.xcconfig"
    IOS_XCCONFIG_ORIGINAL_CONTENT="$(cat "$xcconfig_path")"
    IOS_XCCONFIG_PATCHED="true"
    printf '\nPROVISIONING_PROFILE_SPECIFIER = %s\n' "$IOS_RESOLVED_PROFILE_NAME" \
      >> "$xcconfig_path"
    export FLUTTER_XCODE_CODE_SIGN_STYLE=Manual
    export FLUTTER_XCODE_CODE_SIGN_IDENTITY="Apple Distribution"
    export FLUTTER_XCODE_DEVELOPMENT_TEAM="$IOS_RESOLVED_TEAM_ID"
    say "Manual signing: profile='${IOS_RESOLVED_PROFILE_NAME}' team='${IOS_RESOLVED_TEAM_ID}'"
  fi

  local ios_args=(
    --release
    --build-name "$BUILD_NAME"
    --build-number "$BUILD_NUMBER"
  )
  if [[ -n "$IOS_EXPORT_OPTIONS_PLIST" ]]; then
    ios_args+=(--export-options-plist "$IOS_EXPORT_OPTIONS_PLIST")
  fi

  if [[ -d "$IOS_DEVELOPER_DIR" ]]; then
    DEVELOPER_DIR="$IOS_DEVELOPER_DIR" flutter build ipa \
      "${ios_args[@]}" \
      ${BEFAM_DART_DEFINE_ARGS[@]+"${BEFAM_DART_DEFINE_ARGS[@]}"} \
      ${EXTRA_FLUTTER_ARGS[@]+"${EXTRA_FLUTTER_ARGS[@]}"}
  else
    flutter build ipa \
      "${ios_args[@]}" \
      ${BEFAM_DART_DEFINE_ARGS[@]+"${BEFAM_DART_DEFINE_ARGS[@]}"} \
      ${EXTRA_FLUTTER_ARGS[@]+"${EXTRA_FLUTTER_ARGS[@]}"}
  fi
}

print_plan() {
  cat <<EOF
Release build plan:
  - Profile:       $PROFILE
  - Build name:    $BUILD_NAME
  - Build number:  $BUILD_NUMBER
  - Build Android: $([[ "$SKIP_ANDROID" == "true" ]] && echo "no" || echo "yes")
  - Build iOS:     $([[ "$SKIP_IOS" == "true" ]] && echo "no" || echo "yes")
EOF
}

main() {
  local original_argc="$#"
  parse_args "$@"

  if [[ "$SKIP_ANDROID" == "true" && "$SKIP_IOS" == "true" ]]; then
    die "Nothing to build. Remove one of --skip-android or --skip-ios."
  fi

  # Resolve interactive flag before any menus are shown
  if [[ "$INTERACTIVE_MODE" == "true" ]]; then
    _SHOULD_INTERACTIVE="true"
  elif [[ "$INTERACTIVE_MODE" == "auto" && "$original_argc" -eq 0 ]] && has_interactive_tty; then
    _SHOULD_INTERACTIVE="true"
  fi

  load_local_env_file_if_present

  if [[ "$_SHOULD_INTERACTIVE" == "true" ]]; then
    run_selection_menu
  fi

  resolve_profile_defaults
  resolve_build_metadata_auto
  print_plan

  require_cmd flutter
  cd "$APP_DIR"
  flutter clean
  flutter pub get
  flutter gen-l10n
  build_befam_dart_define_args

  trap cleanup_ios_signing EXIT

  if [[ "$SKIP_ANDROID" != "true" ]]; then
    say "Building Android AAB"
    build_android_aab
  fi

  if [[ "$SKIP_IOS" != "true" ]]; then
    say "Building iOS IPA"
    build_ios_ipa
  fi

  local aab_path="$APP_DIR/build/app/outputs/bundle/release/app-release.aab"
  local ipa_path="$APP_DIR/build/ios/ipa/Runner.ipa"

  echo
  echo "Build completed."
  if [[ "$SKIP_ANDROID" != "true" ]]; then
    echo "AAB: $aab_path"
  fi
  if [[ "$SKIP_IOS" != "true" ]]; then
    echo "IPA: $ipa_path"
  fi
}

main "$@"
