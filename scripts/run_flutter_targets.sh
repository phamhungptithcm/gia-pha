#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$SCRIPT_DIR/../mobile/befam"
IOS_DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-$HOME/Library/Android/sdk}"

usage() {
  cat <<'EOF'
Run the BeFam app from one script (Android, iOS, or Web).
You can use interactive mode and pick options from a friendly menu.

Usage:
  ./scripts/run_flutter_targets.sh [interactive]
  ./scripts/run_flutter_targets.sh <target> [device-or-port] [extra flutter args...]

Targets:
  interactive
    - Open a guided menu (platform + mode + device/port)

  devices
    - Show all available Flutter devices

  android-emulator-start [avd_name]
    - Start an Android emulator (or choose one from a list)

  android-sim [device_id]
    - Run Android in debug mode (choose device if omitted)

  android-release [device_id]
    - Run Android in release mode (choose device if omitted)

  ios-sim [device_id]
    - Run iOS Simulator in debug mode (choose simulator if omitted)

  ios-device [device_udid]
    - Run iOS real device in debug mode (choose device if omitted)

  ios-device-release [device_udid]
    - Run iOS real device in release mode (choose device if omitted)

  web-chrome
    - Run on Chrome (debug)

  web-server [port]
    - Run on local web server (asks for port in interactive mode)

  web-build-release
    - Build a release web bundle

Examples:
  ./scripts/run_flutter_targets.sh
  ./scripts/run_flutter_targets.sh devices
  ./scripts/run_flutter_targets.sh android-sim
  ./scripts/run_flutter_targets.sh ios-sim ios
  ./scripts/run_flutter_targets.sh ios-device-release
  ./scripts/run_flutter_targets.sh web-server 8080
  ./scripts/run_flutter_targets.sh android-sim emulator-5554 --dart-define=BEFAM_USE_LIVE_AUTH=false
EOF
}

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "I couldn't find a required command: $cmd" >&2
    exit 1
  fi
}

run_flutter_devices() {
  cd "$APP_DIR"
  DEVELOPER_DIR="$IOS_DEVELOPER_DIR" flutter devices
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
    "Android simulator/device (Debug)"
    "Android simulator/device (Release)"
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
        echo "android-sim"
        return 0
        ;;
      2)
        echo "android-release"
        return 0
        ;;
      3)
        echo "$(select_target_interactive)"
        return 0
        ;;
      *)
        echo "I didn't catch that. Please choose a number from the list." >&2
        ;;
    esac
  done
}

select_ios_target_interactive() {
  local options=(
    "iOS Simulator (Debug)"
    "iOS Real Device (Debug)"
    "iOS Real Device (Release)"
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
  while IFS= read -r line; do
    [[ "$line" == *"•"* ]] || continue
    local name id platform details
    name="$(echo "$line" | awk -F '•' '{print $1}' | xargs)"
    id="$(echo "$line" | awk -F '•' '{print $2}' | xargs)"
    platform="$(echo "$line" | awk -F '•' '{print $3}' | tr '[:upper:]' '[:lower:]' | xargs)"
    details="$(echo "$line" | awk -F '•' '{print $4}' | tr '[:upper:]' '[:lower:]' | xargs)"
    [[ -n "$id" ]] || continue
    if [[ "$platform_hint" != "all" && "$platform" != *"$platform_hint"* ]]; then
      continue
    fi

    local is_simulator="0"
    if [[ "$details" == *"simulator"* || "$id" == emulator-* ]]; then
      is_simulator="1"
    fi
    if [[ "$kind" == "simulator" && "$is_simulator" != "1" ]]; then
      continue
    fi
    if [[ "$kind" == "physical" && "$is_simulator" == "1" ]]; then
      continue
    fi

    if [[ "$platform_hint" == "all" || "$platform" == *"$platform_hint"* ]]; then
      labels+=("$name [$id]")
      ids+=("$id")
    fi
  done < <(run_flutter_devices)

  if [[ "${#ids[@]}" -eq 0 ]]; then
    echo "$fallback"
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

  android-sim)
    DEVICE_ID="${1:-}"
    if [[ -n "$DEVICE_ID" ]]; then
      shift
    else
      DEVICE_ID="$(pick_device_id "android" "emulator-5554" "any")"
    fi
    cd "$APP_DIR"
    flutter pub get
    flutter run -d "$DEVICE_ID" "$@"
    ;;

  android-release)
    DEVICE_ID="${1:-}"
    if [[ -n "$DEVICE_ID" ]]; then
      shift
    else
      DEVICE_ID="$(pick_device_id "android" "emulator-5554" "any")"
    fi
    cd "$APP_DIR"
    flutter pub get
    flutter run --release -d "$DEVICE_ID" "$@"
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
    DEVELOPER_DIR="$IOS_DEVELOPER_DIR" flutter run -d "$DEVICE_ID" "$@"
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
    DEVELOPER_DIR="$IOS_DEVELOPER_DIR" flutter run -d "$DEVICE_ID" "$@"
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
    DEVELOPER_DIR="$IOS_DEVELOPER_DIR" flutter run --release -d "$DEVICE_ID" "$@"
    ;;

  web-chrome)
    cd "$APP_DIR"
    flutter pub get
    flutter run -d chrome "$@"
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
    flutter run -d web-server --web-hostname 0.0.0.0 --web-port "$PORT" "$@"
    ;;

  web-build-release)
    cd "$APP_DIR"
    flutter pub get
    flutter build web --release "$@"
    ;;

  *)
    echo "I don't recognize this target: $TARGET" >&2
    usage
    exit 1
    ;;
esac
