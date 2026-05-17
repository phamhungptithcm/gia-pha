#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$SCRIPT_DIR/../mobile/befam"
DEFAULT_IOS_DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-$HOME/Library/Android/sdk}"

IOS_DEVELOPER_DIR="${IOS_DEVELOPER_DIR:-${DEVELOPER_DIR:-}}"
if [[ -z "$IOS_DEVELOPER_DIR" ]] && command -v xcode-select >/dev/null 2>&1; then
  IOS_DEVELOPER_DIR="$(xcode-select -p 2>/dev/null || true)"
fi
if [[ -z "$IOS_DEVELOPER_DIR" ]] && [[ -d "$DEFAULT_IOS_DEVELOPER_DIR" ]]; then
  IOS_DEVELOPER_DIR="$DEFAULT_IOS_DEVELOPER_DIR"
fi

FMT_RESET=""
FMT_BOLD=""
FMT_DIM=""
FMT_BLUE=""
FMT_GREEN=""
FMT_YELLOW=""
FMT_RED=""
if [[ "${TERM:-dumb}" != "dumb" ]] && ([[ -t 1 ]] || [[ -t 2 ]]); then
  FMT_RESET=$'\033[0m'
  FMT_BOLD=$'\033[1m'
  FMT_DIM=$'\033[2m'
  FMT_BLUE=$'\033[34m'
  FMT_GREEN=$'\033[32m'
  FMT_YELLOW=$'\033[33m'
  FMT_RED=$'\033[31m'
fi

print_heading() {
  printf '%b%s%b\n' "${FMT_BOLD}${FMT_BLUE}" "$1" "$FMT_RESET"
}

print_section() {
  printf '%b%s%b\n' "$FMT_BOLD" "$1" "$FMT_RESET"
}

print_info() {
  printf '%bInfo:%b %s\n' "$FMT_BLUE" "$FMT_RESET" "$1"
}

print_success() {
  printf '%bOK:%b %s\n' "$FMT_GREEN" "$FMT_RESET" "$1"
}

print_warn() {
  printf '%bWarning:%b %s\n' "$FMT_YELLOW" "$FMT_RESET" "$1"
}

print_hint() {
  printf '%bHint:%b %s\n' "$FMT_DIM" "$FMT_RESET" "$1"
}

print_error() {
  printf '%bError:%b %s\n' "$FMT_RED" "$FMT_RESET" "$1" >&2
}

usage() {
  cat <<'EOF'
Run the BeFam app from one script (Android, iOS, or Web).
You can use interactive mode and pick options from a friendly menu.

Usage:
  ./run_flutter_targets.sh [interactive]
  ./run_flutter_targets.sh <target> [device-or-port] [extra flutter args...]

Targets:
  interactive
    - Open a guided menu (platform + mode + device/port)

  devices
    - Show all available Flutter devices

  android-doctor
    - Show Android target diagnostics (Flutter + adb + quick fixes)

  android-restart-adb
    - Restart the adb server, then show Android diagnostics

  android-emulator-start [avd_name]
    - Start an Android emulator (or choose one from a list)

  android-debug [device_id]
    - Run Android in debug mode (prefers a connected USB device, otherwise emulator)

  android-sim [device_id]
    - Legacy alias for android-debug

  android-release [device_id]
    - Run Android in release mode (prefers a connected USB device, otherwise emulator)
    - Requires release signing (env vars or android/key.properties)

  android-usb [device_id]
    - Run Android in debug mode on a physical USB device only

  android-usb-release [device_id]
    - Run Android in release mode on a physical USB device only
    - Requires release signing (env vars or android/key.properties)

  android-usb-staging-release [device_id]
    - Run Android on a physical USB device with staging release defaults
    - Requires real staging signing (env vars or android/key.properties)

  android-usb-release-ci [device_id]
    - Run Android in release mode on a physical USB device only
    - Uses a temporary local signing keystore when real signing is not configured

  android-build-aab [extra flutter args...]
    - CI-like local release build:
      flutter clean -> flutter pub get -> flutter gen-l10n -> flutter build appbundle --release
    - Requires release signing envs (or key.properties)

  android-build-aab-ci [extra flutter args...]
    - Same as android-build-aab, but auto-generates a temporary signing keystore
      if release signing envs are not available (for quick local test only)

  ios-sim [device_id]
    - Run iOS Simulator in debug mode (choose simulator if omitted)

  ios-device [device_udid]
    - Run iOS real device in debug mode (choose device if omitted)

  ios-device-release [device_udid]
    - Run iOS real device in release mode (choose device if omitted)

  ios-device-staging-release [device_udid]
    - Run iOS real device in release mode with staging-safe defaults
    - Prefers local staging env or bundled staging Firebase config

  web-chrome
    - Run on Chrome (debug)

  web-server [port]
    - Run on local web server (asks for port in interactive mode)

  web-build-release
    - Build a release web bundle

Examples:
  ./run_flutter_targets.sh
  ./run_flutter_targets.sh devices
  ./run_flutter_targets.sh android-doctor
  ./run_flutter_targets.sh android-restart-adb
  ./run_flutter_targets.sh android-debug
  ./run_flutter_targets.sh android-usb
  ./run_flutter_targets.sh android-usb-staging-release
  ./run_flutter_targets.sh android-usb-release-ci
  ./run_flutter_targets.sh android-build-aab
  ./run_flutter_targets.sh android-build-aab-ci
  ./run_flutter_targets.sh ios-sim ios
  ./run_flutter_targets.sh ios-device-release
  ./run_flutter_targets.sh ios-device-staging-release
  ./run_flutter_targets.sh web-server 8080
  ./run_flutter_targets.sh android-debug emulator-5554 --dart-define=BEFAM_USE_LIVE_AUTH=false

Notes:
  - The script auto-injects `--dart-define=BEFAM_ALLOW_BUNDLED_FIREBASE_OPTIONS=true`
    unless you override it explicitly in extra Flutter args.
  - Any exported supported `BEFAM_*` env value (Firebase/app-check/billing/store links)
    will also be forwarded as `--dart-define` so you can switch runtime setup
    without changing source files.
  - Release targets auto-load local release defaults from:
      BEFAM_LOCAL_RELEASE_ENV_FILE -> scripts/local-release.env -> staging examples
  - For AAB build targets, you can override version metadata with:
      BEFAM_BUILD_NAME=1.2.3
      BEFAM_BUILD_NUMBER=123
EOF
}

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    print_error "I couldn't find a required command: $cmd"
    exit 1
  fi
}

load_env_file_safe_defaults() {
  local file="$1"
  local line=""
  local key=""
  local value=""
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ -z "${line//[[:space:]]/}" ]] && continue
    if [[ "$line" =~ ^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)=(.*) ]]; then
      key="${BASH_REMATCH[1]}"
      value="${BASH_REMATCH[2]}"
      if [[ "$value" =~ ^\"(.*)\"$ ]] || [[ "$value" =~ ^\'(.*)\'$ ]]; then
        value="${BASH_REMATCH[1]}"
      fi
      if [[ -z "${!key-}" ]]; then
        export "$key=$value"
      fi
    fi
  done < "$file"
}

normalize_release_profile() {
  local raw="${1:-}"
  raw="$(printf '%s' "$raw" | tr '[:upper:]' '[:lower:]' | xargs)"
  case "$raw" in
    staging|stage)
      echo "staging"
      ;;
    production|prod|env)
      echo "env"
      ;;
    *)
      echo ""
      ;;
  esac
}

read_env_file_release_profile() {
  local file="$1"
  local line=""
  local key=""
  local value=""
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ -z "${line//[[:space:]]/}" ]] && continue
    if [[ "$line" =~ ^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)=(.*) ]]; then
      key="${BASH_REMATCH[1]}"
      value="${BASH_REMATCH[2]}"
      if [[ "$key" != "BEFAM_RELEASE_PROFILE" ]]; then
        continue
      fi
      if [[ "$value" =~ ^\"(.*)\"$ ]] || [[ "$value" =~ ^\'(.*)\'$ ]]; then
        value="${BASH_REMATCH[1]}"
      fi
      normalize_release_profile "$value"
      return 0
    fi
  done < "$file"
  echo ""
  return 0
}

env_file_matches_release_profile() {
  local file="$1"
  local requested_profile
  requested_profile="$(normalize_release_profile "${2:-}")"
  local declared_profile
  declared_profile="$(read_env_file_release_profile "$file")"

  if [[ -z "$requested_profile" ]]; then
    return 0
  fi
  if [[ -z "$declared_profile" ]]; then
    return 0
  fi
  [[ "$requested_profile" == "$declared_profile" ]]
}

pick_release_env_file() {
  local profile
  profile="$(normalize_release_profile "${BEFAM_RELEASE_PROFILE:-staging}")"
  if [[ -z "$profile" ]]; then
    profile="staging"
  fi
  local -a candidates=()
  local candidate=""

  if [[ -n "${BEFAM_LOCAL_RELEASE_ENV_FILE:-}" ]]; then
    candidates+=("${BEFAM_LOCAL_RELEASE_ENV_FILE}")
  fi

  candidates+=("$SCRIPT_DIR/local-release.env")

  if [[ "$profile" == "staging" ]]; then
    candidates+=(
      "$SCRIPT_DIR/local-release.env.example"
      "$SCRIPT_DIR/github-staging.env.example"
    )
  else
    candidates+=("$SCRIPT_DIR/local-release.env.example")
  fi

  for candidate in "${candidates[@]}"; do
    if [[ -f "$candidate" ]]; then
      if ! env_file_matches_release_profile "$candidate" "$profile"; then
        echo "Warning: Skipping $(basename "$candidate") because it is tagged for a different release profile." >&2
        continue
      fi
      echo "$candidate"
      return 0
    fi
  done

  echo ""
  return 0
}

load_release_env_defaults_if_needed() {
  if [[ "${BEFAM_RELEASE_ENV_DEFAULTS_LOADED:-false}" == "true" ]]; then
    return 0
  fi

  local env_file=""
  env_file="$(pick_release_env_file)"
  if [[ -z "$env_file" ]]; then
    return 0
  fi

  print_info "Loading release defaults from $(basename "$env_file")."
  load_env_file_safe_defaults "$env_file"
  export BEFAM_RELEASE_ENV_DEFAULTS_LOADED="true"
}

target_needs_release_defaults() {
  case "$1" in
    android-release|android-usb-release|android-usb-staging-release|android-usb-release-ci|android-build-aab|android-build-aab-ci|ios-device-release|ios-device-staging-release)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

run_flutter_cmd() {
  flutter "$@"
}

run_flutter_ios_cmd() {
  if [[ -n "$IOS_DEVELOPER_DIR" ]] && [[ -d "$IOS_DEVELOPER_DIR" ]]; then
    DEVELOPER_DIR="$IOS_DEVELOPER_DIR" flutter "$@"
    return 0
  fi
  flutter "$@"
}

run_flutter_devices() {
  cd "$APP_DIR"
  run_flutter_cmd devices
}

run_flutter_devices_machine() {
  cd "$APP_DIR"
  run_flutter_cmd devices --machine
}

run_adb() {
  local adb_cmd=""
  if [[ -x "$ANDROID_SDK_ROOT/platform-tools/adb" ]]; then
    adb_cmd="$ANDROID_SDK_ROOT/platform-tools/adb"
  elif command -v adb >/dev/null 2>&1; then
    adb_cmd="$(command -v adb)"
  else
    return 127
  fi
  "$adb_cmd" "$@"
}

list_flutter_devices_tsv() {
  local platform_hint="$1"
  local kind="${2:-any}"

  run_flutter_devices_machine 2>/dev/null | python3 -c "$(cat <<'PY'
import json
import sys

platform_hint = sys.argv[1].strip().lower()
kind = sys.argv[2].strip().lower()

try:
    devices = json.load(sys.stdin)
except Exception:
    devices = []

rows = []
for device in devices:
    device_id = (device.get("id") or "").strip()
    name = (device.get("name") or "").strip()
    target = (device.get("targetPlatform") or "").strip().lower()
    sdk = (device.get("sdk") or "").strip()
    if not device_id:
        continue
    if platform_hint != "all" and platform_hint not in target:
        continue

    is_emulator = bool(device.get("emulator")) or device_id.startswith("emulator-")
    device_kind = "simulator" if is_emulator else "physical"
    if kind == "simulator" and not is_emulator:
        continue
    if kind == "physical" and is_emulator:
        continue

    rows.append(
        {
            "sort_group": 1 if is_emulator else 0,
            "name": name or device_id,
            "id": device_id,
            "target": target,
            "kind": device_kind,
            "details": sdk,
        }
    )

if platform_hint == "android":
    rows.sort(key=lambda row: (row["sort_group"], row["name"].lower(), row["id"].lower()))
else:
    rows.sort(key=lambda row: (row["name"].lower(), row["id"].lower()))

for row in rows:
    print(
        "\t".join(
            [
                row["name"],
                row["id"],
                row["target"],
                row["kind"],
                row["details"],
            ]
        )
    )
PY
)" "$platform_hint" "$kind"
}

list_adb_android_devices_tsv() {
  local kind="${1:-any}"

  run_adb devices -l 2>/dev/null | python3 -c "$(cat <<'PY'
import sys

kind = sys.argv[1].strip().lower()

for raw_line in sys.stdin:
    line = raw_line.strip()
    if not line or line.startswith("List of devices attached"):
        continue
    parts = line.split()
    if len(parts) < 2:
        continue

    serial = parts[0].strip()
    state = parts[1].strip().lower()
    details = " ".join(parts[2:]).strip()
    is_emulator = serial.startswith("emulator-")
    device_kind = "simulator" if is_emulator else "physical"

    if kind == "simulator" and not is_emulator:
        continue
    if kind == "physical" and is_emulator:
        continue

    name = f"Android via adb ({'emulator' if is_emulator else 'usb'})"
    print("\t".join([name, serial, "android", device_kind, state, details]))
PY
)" "$kind"
}

print_android_connection_help() {
  cat >&2 <<'EOF'
Android connection checklist:
  1. Unlock the phone and keep the screen on.
  2. Enable Developer options > USB debugging.
  3. Accept the "Allow USB debugging" prompt on the phone.
  4. Use a data-capable USB cable, not a charge-only cable.
  5. Confirm the device appears as "device" in: adb devices -l

Helpful commands:
  ./run_flutter_targets.sh android-doctor
  ./run_flutter_targets.sh android-restart-adb
  ./run_flutter_targets.sh android-emulator-start
EOF
}

restart_adb_server() {
  if run_adb kill-server >/dev/null 2>&1; then
    :
  else
    local status=$?
    if [[ $status -eq 127 ]]; then
      print_error "adb is not installed or not reachable from this shell."
    else
      print_error "Failed to stop the adb server."
    fi
    return 1
  fi

  if ! run_adb start-server >/dev/null 2>&1; then
    print_error "Failed to start the adb server."
    return 1
  fi

  print_success "The adb server was restarted."
}

show_android_doctor() {
  local flutter_rows=""
  local adb_rows=""
  local adb_status=0
  local flutter_target_count=0
  local flutter_physical_count=0
  local adb_target_count=0
  local adb_ready_count=0
  local adb_physical_ready_count=0
  local adb_physical_unauthorized_count=0
  local adb_physical_offline_count=0

  flutter_rows="$(list_flutter_devices_tsv "android" "any" || true)"
  if ! adb_rows="$(list_adb_android_devices_tsv "any")"; then
    adb_status=$?
    adb_rows=""
  fi

  print_heading "Android target diagnostics"
  echo
  print_section "Flutter-visible Android targets"
  if [[ -n "$flutter_rows" ]]; then
    while IFS=$'\t' read -r name id platform device_kind details; do
      [[ -n "${id:-}" ]] || continue
      flutter_target_count=$((flutter_target_count + 1))
      if [[ "$device_kind" == "physical" ]]; then
        flutter_physical_count=$((flutter_physical_count + 1))
      fi
      printf '  - %s [%s] | %s' "$name" "$id" "$device_kind"
      if [[ -n "${details:-}" ]]; then
        printf ' | %s' "$details"
      fi
      printf '\n'
    done <<<"$flutter_rows"
  else
    echo "  - None"
  fi

  echo
  print_section "adb-visible Android targets"
  if [[ $adb_status -eq 127 ]]; then
    echo "  - adb not found"
  elif [[ -n "$adb_rows" ]]; then
    while IFS=$'\t' read -r name id platform device_kind state details; do
      [[ -n "${id:-}" ]] || continue
      adb_target_count=$((adb_target_count + 1))
      if [[ "$state" == "device" ]]; then
        adb_ready_count=$((adb_ready_count + 1))
        if [[ "$device_kind" == "physical" ]]; then
          adb_physical_ready_count=$((adb_physical_ready_count + 1))
        fi
      fi
      if [[ "$device_kind" == "physical" && "$state" == "unauthorized" ]]; then
        adb_physical_unauthorized_count=$((adb_physical_unauthorized_count + 1))
      fi
      if [[ "$device_kind" == "physical" && "$state" == "offline" ]]; then
        adb_physical_offline_count=$((adb_physical_offline_count + 1))
      fi
      printf '  - %s [%s] | %s | state=%s' "$name" "$id" "$device_kind" "$state"
      if [[ -n "${details:-}" ]]; then
        printf ' | %s' "$details"
      fi
      printf '\n'
    done <<<"$adb_rows"
  else
    echo "  - None"
  fi

  echo
  print_section "Recommended next steps"
  if [[ $adb_status -eq 127 ]]; then
    print_warn "Install Android platform-tools or make sure ANDROID_SDK_ROOT points to a valid SDK."
  elif (( adb_physical_unauthorized_count > 0 )); then
    print_warn "At least one USB device is unauthorized. Accept the USB debugging prompt on the phone, then run ./run_flutter_targets.sh android-restart-adb if the state does not refresh."
  elif (( adb_physical_offline_count > 0 )); then
    print_warn "At least one USB device is offline. Reconnect the cable, unlock the phone, and restart adb with ./run_flutter_targets.sh android-restart-adb."
  elif (( adb_physical_ready_count > 0 && flutter_physical_count == 0 )); then
    print_warn "adb can see a physical Android device, but Flutter cannot. Run flutter doctor -v, then unplug and reconnect the device."
  elif (( adb_target_count == 0 && flutter_target_count == 0 )); then
    print_hint "No Android target is connected right now. Connect a USB device or start an emulator."
  elif (( adb_physical_ready_count == 1 )); then
    print_info "Exactly one USB device is ready. The script will auto-select it for android-usb and android-usb-release."
  elif (( adb_ready_count > 0 )); then
    print_info "Android targets are available. If you want the fastest path to a real phone, use ./run_flutter_targets.sh android-usb."
  else
    print_hint "No adb target is in the ready state yet. Use the checklist below and try again."
  fi

  echo
  print_android_connection_help
}

select_target_interactive() {
  if [[ ! -t 0 ]]; then
    echo "devices"
    return 0
  fi
  echo "What would you like to run?" >&2
  local options=(
    "Android"
    "iOS"
    "Web"
    "Show connected devices"
    "Start Android emulator"
    "Exit"
  )
  local choice=""
  PS3="Please choose an option: "
  select choice in "${options[@]}"; do
    if [[ -z "${choice:-}" ]]; then
      echo "I didn't catch that. Please choose a number from the list." >&2
      continue
    fi
    case "$REPLY" in
      1)
        echo "$(select_android_target_interactive)"
        return 0
        ;;
      2)
        echo "$(select_ios_target_interactive)"
        return 0
        ;;
      3)
        echo "$(select_web_target_interactive)"
        return 0
        ;;
      4)
        echo "devices"
        return 0
        ;;
      5)
        echo "android-emulator-start"
        return 0
        ;;
      6)
        exit 0
        ;;
      *)
        echo "I didn't catch that. Please choose a number from the list." >&2
        ;;
    esac
  done
}

select_android_target_interactive() {
  local options=(
    "Android device or emulator (Debug)"
    "Android USB device only (Debug)"
    "Android device or emulator (Release, real signing required)"
    "Android USB device only (Staging release, real signing required)"
    "Android USB device only (Release, temporary local signing)"
    "Build Android AAB (Release, real signing required)"
    "Build Android AAB (CI-like local test)"
    "Show Android diagnostics"
    "Restart adb server"
    "Back"
  )
  local choice=""
  echo "Choose Android run mode:" >&2
  PS3="Android option: "
  select choice in "${options[@]}"; do
    if [[ -z "${choice:-}" ]]; then
      echo "I didn't catch that. Please choose a number from the list." >&2
      continue
    fi
    case "$REPLY" in
      1)
        echo "android-debug"
        return 0
        ;;
      2)
        echo "android-usb"
        return 0
        ;;
      3)
        echo "android-release"
        return 0
        ;;
      4)
        echo "android-usb-staging-release"
        return 0
        ;;
      5)
        echo "android-usb-release-ci"
        return 0
        ;;
      6)
        echo "android-build-aab"
        return 0
        ;;
      7)
        echo "android-build-aab-ci"
        return 0
        ;;
      8)
        echo "android-doctor"
        return 0
        ;;
      9)
        echo "android-restart-adb"
        return 0
        ;;
      10)
        echo "$(select_target_interactive)"
        return 0
        ;;
      *)
        echo "I didn't catch that. Please choose a number from the list." >&2
        ;;
    esac
  done
}

prepare_android_release_signing() {
  local allow_temp_signing="${1:-false}"

  if [[ -z "${ANDROID_KEYSTORE_PATH:-}" ]] && \
     [[ -z "${ANDROID_KEYSTORE_PASSWORD:-}" ]] && \
     [[ -z "${ANDROID_KEY_ALIAS:-}" ]] && \
     [[ -z "${ANDROID_KEY_PASSWORD:-}" ]]; then
    if [[ -n "${ANDROID_STAGING_KEYSTORE_PATH:-}" ]] && \
       [[ -n "${ANDROID_STAGING_KEYSTORE_PASSWORD:-}" ]] && \
       [[ -n "${ANDROID_STAGING_KEY_ALIAS:-}" ]] && \
       [[ -n "${ANDROID_STAGING_KEY_PASSWORD:-}" ]]; then
      export ANDROID_KEYSTORE_PATH="$ANDROID_STAGING_KEYSTORE_PATH"
      export ANDROID_KEYSTORE_PASSWORD="$ANDROID_STAGING_KEYSTORE_PASSWORD"
      export ANDROID_KEY_ALIAS="$ANDROID_STAGING_KEY_ALIAS"
      export ANDROID_KEY_PASSWORD="$ANDROID_STAGING_KEY_PASSWORD"
    fi
  fi

  if [[ -n "${ANDROID_KEYSTORE_PATH:-}" ]] && \
     [[ -n "${ANDROID_KEYSTORE_PASSWORD:-}" ]] && \
     [[ -n "${ANDROID_KEY_ALIAS:-}" ]] && \
     [[ -n "${ANDROID_KEY_PASSWORD:-}" ]] && \
     [[ -f "${ANDROID_KEYSTORE_PATH}" ]]; then
    return 0
  fi

  if [[ -n "${ANDROID_RELEASE_KEYSTORE_BASE64:-}" ]] && \
     [[ -n "${ANDROID_RELEASE_KEYSTORE_PASSWORD:-}" ]] && \
     [[ -n "${ANDROID_RELEASE_KEY_ALIAS:-}" ]] && \
     [[ -n "${ANDROID_RELEASE_KEY_PASSWORD:-}" ]]; then
    local decoded_keystore_path
    decoded_keystore_path="$(mktemp "${TMPDIR:-/tmp}/befam-android-release-XXXXXX")"
    echo "$ANDROID_RELEASE_KEYSTORE_BASE64" | base64 --decode > "$decoded_keystore_path"
    export ANDROID_KEYSTORE_PATH="$decoded_keystore_path"
    export ANDROID_KEYSTORE_PASSWORD="$ANDROID_RELEASE_KEYSTORE_PASSWORD"
    export ANDROID_KEY_ALIAS="$ANDROID_RELEASE_KEY_ALIAS"
    export ANDROID_KEY_PASSWORD="$ANDROID_RELEASE_KEY_PASSWORD"
    return 0
  fi

  if [[ -n "${ANDROID_KEYSTORE_BASE64:-}" ]] && \
     [[ -n "${ANDROID_KEYSTORE_PASSWORD:-}" ]] && \
     [[ -n "${ANDROID_KEY_ALIAS:-}" ]] && \
     [[ -n "${ANDROID_KEY_PASSWORD:-}" ]]; then
    local inline_keystore_path
    inline_keystore_path="$(mktemp "${TMPDIR:-/tmp}/befam-android-inline-XXXXXX")"
    echo "$ANDROID_KEYSTORE_BASE64" | base64 --decode > "$inline_keystore_path"
    export ANDROID_KEYSTORE_PATH="$inline_keystore_path"
    return 0
  fi

  if [[ -n "${ANDROID_STAGING_KEYSTORE_BASE64:-}" ]] && \
     [[ -n "${ANDROID_STAGING_KEYSTORE_PASSWORD:-}" ]] && \
     [[ -n "${ANDROID_STAGING_KEY_ALIAS:-}" ]] && \
     [[ -n "${ANDROID_STAGING_KEY_PASSWORD:-}" ]]; then
    local staging_keystore_path
    staging_keystore_path="$(mktemp "${TMPDIR:-/tmp}/befam-android-staging-XXXXXX")"
    echo "$ANDROID_STAGING_KEYSTORE_BASE64" | base64 --decode > "$staging_keystore_path"
    export ANDROID_KEYSTORE_PATH="$staging_keystore_path"
    export ANDROID_KEYSTORE_PASSWORD="$ANDROID_STAGING_KEYSTORE_PASSWORD"
    export ANDROID_KEY_ALIAS="$ANDROID_STAGING_KEY_ALIAS"
    export ANDROID_KEY_PASSWORD="$ANDROID_STAGING_KEY_PASSWORD"
    return 0
  fi

  if [[ -f "$APP_DIR/android/key.properties" ]]; then
    return 0
  fi

  if [[ "$allow_temp_signing" == "true" ]]; then
    require_cmd keytool
    local temp_keystore_path
    temp_keystore_path="$(mktemp "${TMPDIR:-/tmp}/befam-android-ci-XXXXXX")"
    rm -f "$temp_keystore_path"
    if ! keytool -genkeypair \
      -v \
      -storetype PKCS12 \
      -keystore "$temp_keystore_path" \
      -storepass "android" \
      -alias "ci-upload" \
      -keyalg RSA \
      -keysize 2048 \
      -validity 3650 \
      -keypass "android" \
      -dname "CN=BeFam Local CI, OU=CI, O=BeFam, L=HCMC, S=HCMC, C=VN" >/dev/null 2>&1; then
      print_error "Failed to generate a temporary Android signing keystore."
      return 1
    fi
    export ANDROID_KEYSTORE_PATH="$temp_keystore_path"
    export ANDROID_KEYSTORE_PASSWORD="android"
    export ANDROID_KEY_ALIAS="ci-upload"
    export ANDROID_KEY_PASSWORD="android"
    return 0
  fi

  print_error "Android release signing is not configured."
  echo "Provide one of these before using Android release targets:" >&2
  echo "  1) mobile/befam/android/key.properties" >&2
  echo "  2) ANDROID_STAGING_KEYSTORE_* variables" >&2
  echo "  3) ANDROID_KEYSTORE_PATH + ANDROID_KEYSTORE_PASSWORD + ANDROID_KEY_ALIAS + ANDROID_KEY_PASSWORD" >&2
  echo "  4) ANDROID_KEYSTORE_BASE64 or ANDROID_RELEASE_KEYSTORE_BASE64 with password + alias" >&2
  echo >&2
  echo "If you only need a quick local run, use one of these instead:" >&2
  echo "  - ./run_flutter_targets.sh android-debug" >&2
  echo "  - ./run_flutter_targets.sh android-usb" >&2
  echo "  - ./run_flutter_targets.sh android-usb-staging-release" >&2
  echo "  - ./run_flutter_targets.sh android-usb-release-ci" >&2
  echo "  - ./run_flutter_targets.sh android-build-aab-ci" >&2
  echo >&2
  echo "If you are using the interactive menu, choose Android option 4 for staging release or option 5 for temporary local signing." >&2
  return 1
}

build_android_aab_release() {
  local allow_temp_signing="${1:-false}"
  shift || true

  cd "$APP_DIR"
  flutter clean
  flutter pub get
  flutter gen-l10n
  prepare_android_release_signing "$allow_temp_signing"

  local build_name="${BEFAM_BUILD_NAME:-0.0.0}"
  local build_number="${BEFAM_BUILD_NUMBER:-1}"
  flutter build appbundle \
    --release \
    --build-name "$build_name" \
    --build-number "$build_number" \
    "${BEFAM_DART_DEFINE_ARGS[@]}" \
    "$@"

  echo "AAB generated at: $APP_DIR/build/app/outputs/bundle/release/app-release.aab"
}

select_ios_target_interactive() {
  local options=(
    "iOS Simulator (Debug)"
    "iOS Real Device (Debug)"
    "iOS Real Device (Release)"
    "iOS Real Device (Staging Release)"
    "Back"
  )
  local choice=""
  echo "Choose iOS run mode:" >&2
  PS3="iOS option: "
  select choice in "${options[@]}"; do
    if [[ -z "${choice:-}" ]]; then
      echo "I didn't catch that. Please choose a number from the list." >&2
      continue
    fi
    case "$REPLY" in
      1)
        echo "ios-sim"
        return 0
        ;;
      2)
        echo "ios-device"
        return 0
        ;;
      3)
        echo "ios-device-release"
        return 0
        ;;
      4)
        echo "ios-device-staging-release"
        return 0
        ;;
      5)
        echo "$(select_target_interactive)"
        return 0
        ;;
      *)
        echo "I didn't catch that. Please choose a number from the list." >&2
        ;;
    esac
  done
}

select_web_target_interactive() {
  local options=(
    "Web on Chrome (Debug)"
    "Web on Local Server"
    "Build Web (Release)"
    "Back"
  )
  local choice=""
  echo "Choose web run mode:" >&2
  PS3="Web option: "
  select choice in "${options[@]}"; do
    if [[ -z "${choice:-}" ]]; then
      echo "I didn't catch that. Please choose a number from the list." >&2
      continue
    fi
    case "$REPLY" in
      1)
        echo "web-chrome"
        return 0
        ;;
      2)
        echo "web-server"
        return 0
        ;;
      3)
        echo "web-build-release"
        return 0
        ;;
      4)
        echo "$(select_target_interactive)"
        return 0
        ;;
      *)
        echo "I didn't catch that. Please choose a number from the list." >&2
        ;;
    esac
  done
}

pick_device_id() {
  local platform_hint="$1"
  local fallback="$2"
  local kind="${3:-any}"

  local -a labels=()
  local -a ids=()
  while IFS=$'\t' read -r name id platform device_kind details; do
    [[ -n "${id:-}" ]] || continue
    labels+=("$name [$id]")
    ids+=("$id")
  done < <(list_flutter_devices_tsv "$platform_hint" "$kind")

  if [[ "${#ids[@]}" -eq 0 && "$platform_hint" == "android" ]]; then
    while IFS=$'\t' read -r name id platform device_kind details; do
      [[ -n "${id:-}" ]] || continue
      labels+=("$name [$id]")
      ids+=("$id")
    done < <(
      list_adb_android_devices_tsv "$kind" | awk -F '\t' '$5 == "device" { print $1 "\t" $2 "\t" $3 "\t" $4 "\t" $6 }'
    )
  fi

  if [[ "${#ids[@]}" -eq 0 ]]; then
    if [[ -n "$fallback" ]]; then
      local fallback_present=""
      fallback_present="$(
        run_flutter_devices_machine 2>/dev/null | python3 -c "$(cat <<'PY'
import json
import sys

target = sys.argv[1].strip()

try:
    devices = json.load(sys.stdin)
except Exception:
    devices = []

for device in devices:
    if (device.get("id") or "").strip() == target:
        print(target)
        break
PY
)" "$fallback"
      )"
      if [[ -z "$fallback_present" ]]; then
        fallback_present="$(
          run_adb devices 2>/dev/null | awk -v target="$fallback" 'NR > 1 && $1 == target && $2 == "device" { print target; exit }'
        )"
      fi
      if [[ -n "$fallback_present" ]]; then
        if [[ -t 2 ]]; then
          echo "Info: Using fallback device [$fallback_present]." >&2
        fi
        echo "$fallback_present"
        return 0
      fi
    fi
    echo ""
    return 0
  fi

  if [[ "${#ids[@]}" -eq 1 ]]; then
    if [[ -t 2 ]]; then
      echo "Info: Using detected device ${labels[0]}." >&2
    fi
    echo "${ids[0]}"
    return 0
  fi

  if [[ ! -t 0 ]]; then
    echo "${ids[0]}"
    return 0
  fi

  echo "Choose a device to run on:" >&2
  local picked=""
  PS3="Device option: "
  select picked in "${labels[@]}"; do
    if [[ -z "${picked:-}" ]]; then
      echo "I didn't catch that. Please choose a number from the list." >&2
      continue
    fi
    local index=$((REPLY - 1))
    if (( index >= 0 && index < ${#ids[@]} )); then
      echo "${ids[$index]}"
      return 0
    fi
  done
}

describe_android_target() {
  local target_id="$1"
  local name=""
  local id=""
  local platform=""
  local device_kind=""
  local details=""
  local state=""

  while IFS=$'\t' read -r name id platform device_kind details; do
    [[ -n "${id:-}" ]] || continue
    if [[ "$id" == "$target_id" ]]; then
      printf '%s [%s]' "$name" "$id"
      return 0
    fi
  done < <(list_flutter_devices_tsv "android" "any")

  while IFS=$'\t' read -r name id platform device_kind state details; do
    [[ -n "${id:-}" ]] || continue
    if [[ "$id" == "$target_id" ]]; then
      printf '%s [%s]' "$name" "$id"
      return 0
    fi
  done < <(list_adb_android_devices_tsv "any")

  printf '%s' "$target_id"
}

resolve_android_device_id() {
  local provided_id="$1"
  local fallback="$2"
  local kind="${3:-any}"
  local empty_message="$4"
  local device_id="$provided_id"

  if [[ -z "$device_id" ]]; then
    device_id="$(pick_device_id "android" "$fallback" "$kind")"
  fi

  if [[ -z "$device_id" ]]; then
    print_error "$empty_message"
    print_android_connection_help
    exit 1
  fi

  echo "$device_id"
}

run_android_target() {
  local mode="$1"
  local device_id="$2"
  local allow_temp_signing="${3:-false}"
  shift 3

  local target_label=""
  target_label="$(describe_android_target "$device_id")"

  cd "$APP_DIR"
  print_info "Using Android target: $target_label"
  if [[ "$mode" == "release" ]]; then
    prepare_android_release_signing "$allow_temp_signing"
    if [[ "$allow_temp_signing" == "true" ]]; then
      print_warn "Using temporary local Android signing. Use this only for local testing."
    fi
  fi
  flutter pub get

  if [[ "$mode" == "release" ]]; then
    print_info "Starting Flutter in release mode."
    flutter run --release -d "$device_id" "${BEFAM_DART_DEFINE_ARGS[@]}" "$@"
    return 0
  fi

  print_info "Starting Flutter in debug mode."
  flutter run -d "$device_id" "${BEFAM_DART_DEFINE_ARGS[@]}" "$@"
}

pick_avd_name() {
  local fallback="${1:-flutter_android_test}"
  local emulator_cmd="$ANDROID_SDK_ROOT/emulator/emulator"
  if [[ ! -x "$emulator_cmd" ]]; then
    echo "$fallback"
    return 0
  fi

  local -a avds=()
  mapfile -t avds < <("$emulator_cmd" -list-avds)
  if [[ "${#avds[@]}" -eq 0 ]]; then
    echo "$fallback"
    return 0
  fi

  if [[ ! -t 0 ]]; then
    echo "${avds[0]}"
    return 0
  fi

  echo "Choose an Android emulator to start:" >&2
  local picked=""
  PS3="Emulator option: "
  select picked in "${avds[@]}"; do
    if [[ -z "${picked:-}" ]]; then
      echo "I didn't catch that. Please choose a number from the list." >&2
      continue
    fi
    echo "$picked"
    return 0
  done
}

prompt_with_default() {
  local question="$1"
  local default_value="$2"
  if [[ ! -t 0 ]]; then
    echo "$default_value"
    return 0
  fi
  local input=""
  read -r -p "$question [$default_value]: " input
  if [[ -z "$input" ]]; then
    echo "$default_value"
  else
    echo "$input"
  fi
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
    BEFAM_OTP_PROVIDER
    BEFAM_ALLOW_FIREBASE_PHONE_FALLBACK
    BEFAM_APP_CHECK_WEB_RECAPTCHA_SITE_KEY
    BEFAM_BILLING_PENDING_TIMEOUT_MINUTES
    BEFAM_IOS_APP_STORE_URL
    BEFAM_ANDROID_PLAY_STORE_URL
  )

  local key=""
  local value=""
  for key in "${firebase_define_keys[@]}"; do
    value="${!key:-}"
    if [[ -n "$value" ]]; then
      BEFAM_DART_DEFINE_ARGS+=("--dart-define=${key}=${value}")
    fi
  done
}

render_web_metadata() {
  local web_base_url="${BEFAM_WEB_BASE_URL:-}"
  if [[ -z "$web_base_url" && -n "${BEFAM_FIREBASE_PROJECT_ID:-}" ]]; then
    web_base_url="https://${BEFAM_FIREBASE_PROJECT_ID}.web.app"
  fi
  if [[ -z "$web_base_url" && -n "${FIREBASE_PROJECT_ID:-}" ]]; then
    web_base_url="https://${FIREBASE_PROJECT_ID}.web.app"
  fi
  "${SCRIPT_DIR}/render_web_metadata.sh" "$web_base_url"
}

TARGET="${1:-interactive}"
if [[ "$#" -gt 0 ]]; then
  shift
fi

if [[ "$TARGET" == "help" || "$TARGET" == "--help" || "$TARGET" == "-h" ]]; then
  usage
  exit 0
fi

require_cmd flutter

if [[ "$TARGET" == "interactive" || "$TARGET" == "menu" ]]; then
  TARGET="$(select_target_interactive)"
fi

if [[ "$TARGET" == "android-usb-staging-release" ]]; then
  export BEFAM_RELEASE_PROFILE="staging"
fi

if [[ "$TARGET" == "ios-device-staging-release" ]]; then
  export BEFAM_RELEASE_PROFILE="staging"
fi

if target_needs_release_defaults "$TARGET"; then
  load_release_env_defaults_if_needed
fi

BEFAM_DART_DEFINE_ARGS=()
build_befam_dart_define_args

case "$TARGET" in
  devices)
    run_flutter_devices
    ;;

  android-emulator-start)
    AVD_NAME="${1:-}"
    if [[ -n "$AVD_NAME" ]]; then
      shift
    else
      AVD_NAME="$(pick_avd_name "flutter_android_test")"
    fi
    "$SCRIPT_DIR/run_android_emulator.sh" "$AVD_NAME"
    ;;

  android-doctor)
    show_android_doctor
    ;;

  android-restart-adb)
    restart_adb_server
    echo
    show_android_doctor
    ;;

  android-debug)
    DEVICE_ID="${1:-}"
    if [[ -n "$DEVICE_ID" ]]; then
      shift
    fi
    DEVICE_ID="$(resolve_android_device_id "$DEVICE_ID" "emulator-5554" "any" "No Android device detected.")"
    run_android_target "debug" "$DEVICE_ID" "false" "$@"
    ;;

  android-usb)
    DEVICE_ID="${1:-}"
    if [[ -n "$DEVICE_ID" ]]; then
      shift
    fi
    DEVICE_ID="$(resolve_android_device_id "$DEVICE_ID" "" "physical" "No Android USB device detected.")"
    run_android_target "debug" "$DEVICE_ID" "false" "$@"
    ;;

  android-sim)
    DEVICE_ID="${1:-}"
    if [[ -n "$DEVICE_ID" ]]; then
      shift
    fi
    DEVICE_ID="$(resolve_android_device_id "$DEVICE_ID" "emulator-5554" "any" "No Android device detected. Connect an Android phone with USB debugging enabled, or start an emulator, then try again.")"
    run_android_target "debug" "$DEVICE_ID" "false" "$@"
    ;;

  android-release)
    DEVICE_ID="${1:-}"
    if [[ -n "$DEVICE_ID" ]]; then
      shift
    fi
    DEVICE_ID="$(resolve_android_device_id "$DEVICE_ID" "emulator-5554" "any" "No Android device detected. Connect an Android phone with USB debugging enabled, or start an emulator, then try again.")"
    run_android_target "release" "$DEVICE_ID" "false" "$@"
    ;;

  android-usb-release)
    DEVICE_ID="${1:-}"
    if [[ -n "$DEVICE_ID" ]]; then
      shift
    fi
    DEVICE_ID="$(resolve_android_device_id "$DEVICE_ID" "" "physical" "No Android USB device detected.")"
    run_android_target "release" "$DEVICE_ID" "false" "$@"
    ;;

  android-usb-staging-release)
    DEVICE_ID="${1:-}"
    if [[ -n "$DEVICE_ID" ]]; then
      shift
    fi
    DEVICE_ID="$(resolve_android_device_id "$DEVICE_ID" "" "physical" "No Android USB device detected.")"
    run_android_target "release" "$DEVICE_ID" "false" "$@"
    ;;

  android-usb-release-ci)
    DEVICE_ID="${1:-}"
    if [[ -n "$DEVICE_ID" ]]; then
      shift
    fi
    DEVICE_ID="$(resolve_android_device_id "$DEVICE_ID" "" "physical" "No Android USB device detected.")"
    run_android_target "release" "$DEVICE_ID" "true" "$@"
    ;;

  android-build-aab)
    build_android_aab_release "false" "$@"
    ;;

  android-build-aab-ci)
    build_android_aab_release "true" "$@"
    ;;

  ios-sim)
    DEVICE_ID="${1:-}"
    if [[ -n "$DEVICE_ID" ]]; then
      shift
    else
      DEVICE_ID="$(pick_device_id "ios" "ios" "simulator")"
    fi
    cd "$APP_DIR"
    flutter pub get
    run_flutter_ios_cmd run -d "$DEVICE_ID" "${BEFAM_DART_DEFINE_ARGS[@]}" "$@"
    ;;

  ios-device)
    DEVICE_ID="${1:-}"
    if [[ -n "$DEVICE_ID" ]]; then
      shift
    else
      DEVICE_ID="$(pick_device_id "ios" "" "physical")"
    fi
    if [[ -z "$DEVICE_ID" ]]; then
      echo "No iOS real device found. Please connect your iPhone/iPad and trust this computer, then try again." >&2
      exit 1
    fi
    cd "$APP_DIR"
    flutter pub get
    run_flutter_ios_cmd run -d "$DEVICE_ID" "${BEFAM_DART_DEFINE_ARGS[@]}" "$@"
    ;;

  ios-device-release)
    DEVICE_ID="${1:-}"
    if [[ -n "$DEVICE_ID" ]]; then
      shift
    else
      DEVICE_ID="$(pick_device_id "ios" "" "physical")"
    fi
    if [[ -z "$DEVICE_ID" ]]; then
      echo "No iOS real device found. Please connect your iPhone/iPad and trust this computer, then try again." >&2
      exit 1
    fi
    cd "$APP_DIR"
    flutter pub get
    run_flutter_ios_cmd run --release -d "$DEVICE_ID" "${BEFAM_DART_DEFINE_ARGS[@]}" "$@"
    ;;

  ios-device-staging-release)
    DEVICE_ID="${1:-}"
    if [[ -n "$DEVICE_ID" ]]; then
      shift
    else
      DEVICE_ID="$(pick_device_id "ios" "" "physical")"
    fi
    if [[ -z "$DEVICE_ID" ]]; then
      echo "No iOS real device found. Please connect your iPhone/iPad and trust this computer, then try again." >&2
      exit 1
    fi
    cd "$APP_DIR"
    flutter pub get
    run_flutter_ios_cmd run --release -d "$DEVICE_ID" "${BEFAM_DART_DEFINE_ARGS[@]}" "$@"
    ;;

  web-chrome)
    cd "$APP_DIR"
    flutter pub get
    render_web_metadata
    flutter run -d chrome "${BEFAM_DART_DEFINE_ARGS[@]}" "$@"
    ;;

  web-server)
    PORT="${1:-}"
    if [[ -n "$PORT" ]]; then
      shift
    else
      PORT="$(prompt_with_default "Web server port" "8080")"
    fi
    cd "$APP_DIR"
    flutter pub get
    render_web_metadata
    flutter run -d web-server --web-hostname 0.0.0.0 --web-port "$PORT" "${BEFAM_DART_DEFINE_ARGS[@]}" "$@"
    ;;

  web-build-release)
    cd "$APP_DIR"
    flutter pub get
    render_web_metadata
    flutter build web --release "${BEFAM_DART_DEFINE_ARGS[@]}" "$@"
    ;;

  *)
    echo "I don't recognize this target: $TARGET" >&2
    usage
    exit 1
    ;;
esac
