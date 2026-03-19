#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_DIR="$REPO_ROOT/mobile/befam"
FUNCTIONS_DIR="$REPO_ROOT/firebase/functions"

SETUP_MOBILE=1
SETUP_FUNCTIONS=1
RUN_DOCTOR=1
SKIP_IOS_PODS=0
INSTALL_MISSING=0

INTERACTIVE=0
SHOW_PRESET_LIST=0
DEFAULT_PRESET="standard"
ACTIVE_PRESET="$DEFAULT_PRESET"

usage() {
  cat <<'EOF'
BeFam local environment setup (quick and friendly).

Usage:
  ./scripts/setup_project_env.sh [options]

Quick start:
  ./scripts/setup_project_env.sh
    Opens a guided wizard with ready-made setup profiles.

Presets:
  standard       Mobile + Functions, run doctor, no auto-install (safe default)
  mobile-fast    Mobile only, skip iOS pods and doctor (fast local UI loop)
  functions-fast Functions only (fast backend loop)
  full-auto      Mobile + Functions, doctor, and auto-install missing tools
  custom         Guided choices with quick menu options

Options:
  --preset NAME        Apply preset: standard|mobile-fast|functions-fast|full-auto|custom
  --interactive        Force interactive wizard mode
  --list-presets       Print preset details and exit
  --mobile-only        Setup Flutter app only
  --functions-only     Setup Firebase Functions only
  --skip-ios-pods      Skip `pod install` for iOS
  --skip-doctor        Skip `flutter doctor -v` at the end
  --install-missing    Try installing missing tools with Homebrew/npm (macOS)
  -h, --help           Show this help

Examples:
  ./scripts/setup_project_env.sh --preset standard
  ./scripts/setup_project_env.sh --preset full-auto
  ./scripts/setup_project_env.sh --functions-only --install-missing
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

list_presets() {
  cat <<'EOF'
Available setup presets:

1) standard
   - Mobile + Functions
   - Runs flutter doctor
   - Does not auto-install missing dependencies
   - Best when you want predictable changes on your machine

2) mobile-fast
   - Mobile only
   - Skips iOS pod install
   - Skips flutter doctor
   - Best for quick Flutter UI iteration

3) functions-fast
   - Functions only
   - Installs npm packages for firebase/functions
   - Best for backend and callable development

4) full-auto
   - Mobile + Functions + flutter doctor
   - Tries to auto-install missing tools (brew/npm)
   - Fastest path when setting up a new dev machine
   - Trade-off: can modify local toolchain versions automatically

5) custom
   - Guided menu with predefined choices
   - Best when you need a tailored setup
EOF
}

apply_preset() {
  local preset="${1:-$DEFAULT_PRESET}"
  ACTIVE_PRESET="$preset"
  case "$preset" in
    standard)
      SETUP_MOBILE=1
      SETUP_FUNCTIONS=1
      RUN_DOCTOR=1
      SKIP_IOS_PODS=0
      INSTALL_MISSING=0
      ;;
    mobile-fast)
      SETUP_MOBILE=1
      SETUP_FUNCTIONS=0
      RUN_DOCTOR=0
      SKIP_IOS_PODS=1
      INSTALL_MISSING=0
      ;;
    functions-fast)
      SETUP_MOBILE=0
      SETUP_FUNCTIONS=1
      RUN_DOCTOR=0
      SKIP_IOS_PODS=1
      INSTALL_MISSING=0
      ;;
    full-auto)
      SETUP_MOBILE=1
      SETUP_FUNCTIONS=1
      RUN_DOCTOR=1
      SKIP_IOS_PODS=0
      INSTALL_MISSING=1
      ;;
    custom)
      # custom values are set by the interactive wizard.
      ;;
    *)
      die "Unknown preset '$preset'. Use --list-presets to see valid values."
      ;;
  esac
}

print_selected_plan() {
  local mobile="no"
  local functions="no"
  local doctor="no"
  local ios_pods="no"
  local install_missing="no"
  [[ "$SETUP_MOBILE" -eq 1 ]] && mobile="yes"
  [[ "$SETUP_FUNCTIONS" -eq 1 ]] && functions="yes"
  [[ "$RUN_DOCTOR" -eq 1 ]] && doctor="yes"
  if [[ "$(uname -s)" == "Darwin" && "$SKIP_IOS_PODS" -eq 0 && "$SETUP_MOBILE" -eq 1 ]]; then
    ios_pods="yes"
  fi
  [[ "$INSTALL_MISSING" -eq 1 ]] && install_missing="yes"

  cat <<EOF
Selected setup plan:
  - Setup mobile app:          $mobile
  - Setup functions:           $functions
  - Run flutter doctor:        $doctor
  - Run iOS pod install:       $ios_pods
  - Auto-install missing deps: $install_missing
EOF
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
    if ! IFS= read -r choice; then
      die "Interactive input is unavailable. Use --preset standard|mobile-fast|functions-fast|full-auto."
    fi
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

has_interactive_tty() {
  if [[ -t 0 && -t 1 ]]; then
    return 0
  fi

  return 1
}

run_interactive_wizard() {
  say "Welcome to BeFam quick setup wizard"
  echo "Pick a ready-made setup profile. No manual values required."

  local preset_choice
  preset_choice="$(prompt_choice \
    "What do you want to setup right now?" \
    1 \
    "Standard (recommended) - full dev setup, safe dependency policy" \
    "Mobile fast loop - skip heavy steps for UI coding" \
    "Functions fast loop - backend only" \
    "Full auto-repair - auto-install missing tools" \
    "Custom (guided options)")"

  case "$preset_choice" in
    1) apply_preset "standard" ;;
    2) apply_preset "mobile-fast" ;;
    3) apply_preset "functions-fast" ;;
    4) apply_preset "full-auto" ;;
    5)
      local scope_choice
      scope_choice="$(prompt_choice \
        "Choose setup scope:" \
        1 \
        "Mobile + Functions" \
        "Mobile only" \
        "Functions only")"

      case "$scope_choice" in
        1) SETUP_MOBILE=1; SETUP_FUNCTIONS=1 ;;
        2) SETUP_MOBILE=1; SETUP_FUNCTIONS=0 ;;
        3) SETUP_MOBILE=0; SETUP_FUNCTIONS=1 ;;
      esac

      local dependency_choice
      dependency_choice="$(prompt_choice \
        "Choose dependency strategy (trade-off):" \
        1 \
        "Safe stop mode (recommended) - stop and show install hints if tools are missing" \
        "Auto-fix mode - try installing missing tools using brew/npm")"
      if [[ "$dependency_choice" -eq 1 ]]; then
        INSTALL_MISSING=0
      else
        INSTALL_MISSING=1
      fi

      if [[ "$SETUP_MOBILE" -eq 1 ]]; then
        local pods_choice
        pods_choice="$(prompt_choice \
          "iOS pods step:" \
          1 \
          "Run pod install (recommended for iOS run/build)" \
          "Skip pod install (faster, but iOS build may fail)")"
        if [[ "$pods_choice" -eq 1 ]]; then
          SKIP_IOS_PODS=0
        else
          SKIP_IOS_PODS=1
        fi

        local doctor_choice
        doctor_choice="$(prompt_choice \
          "Flutter doctor check:" \
          1 \
          "Run flutter doctor -v at the end (recommended)" \
          "Skip flutter doctor (faster)")"
        if [[ "$doctor_choice" -eq 1 ]]; then
          RUN_DOCTOR=1
        else
          RUN_DOCTOR=0
        fi
      else
        RUN_DOCTOR=0
        SKIP_IOS_PODS=1
      fi
      ;;
  esac

  echo
  print_selected_plan
  local proceed_choice
  proceed_choice="$(prompt_choice \
    "Proceed with this setup plan?" \
    1 \
    "Yes, run setup now" \
    "No, exit without making changes")"
  if [[ "$proceed_choice" -ne 1 ]]; then
    say "Setup canceled. No changes were made."
    exit 0
  fi
}

print_issue_help() {
  cat <<'EOF'

Quick troubleshooting guide:
  1) If setup stopped because a command is missing:
     - Fast fix: rerun with --preset full-auto
     - Safe fix: install tools manually, then rerun standard preset

  2) If iOS build fails after skipping pods:
     - rerun with --preset standard
     - or run: cd mobile/befam/ios && pod install

  3) If function install/build fails:
     - check Node version (recommended: 20)
     - rerun: cd firebase/functions && npm ci
EOF
}

install_hint_or_try() {
  local cmd="$1"
  local install_hint="$2"
  local brew_formula="${3:-}"
  local use_cask="${4:-0}"
  local npm_global_pkg="${5:-}"

  if command -v "$cmd" >/dev/null 2>&1; then
    return 0
  fi

  if [[ "$INSTALL_MISSING" -ne 1 ]]; then
    echo >&2
    warn "Missing dependency: '$cmd'."
    echo "Install hint: $install_hint" >&2
    echo "Fast path: rerun with --preset full-auto to let the script try auto-install." >&2
    echo "Safe path: install manually and rerun --preset standard." >&2
    print_issue_help
    exit 1
  fi

  if [[ -n "$brew_formula" ]]; then
    command -v brew >/dev/null 2>&1 || die "Homebrew is required to auto-install '$cmd'."
    if [[ "$use_cask" -eq 1 ]]; then
      say "Installing $cmd via Homebrew cask..."
      brew install --cask "$brew_formula"
    else
      say "Installing $cmd via Homebrew..."
      brew install "$brew_formula"
    fi
  elif [[ -n "$npm_global_pkg" ]]; then
    command -v npm >/dev/null 2>&1 || die "npm is required to auto-install '$cmd'."
    say "Installing $cmd globally via npm..."
    npm install -g "$npm_global_pkg"
  else
    die "Missing '$cmd'. $install_hint"
  fi

  command -v "$cmd" >/dev/null 2>&1 || {
    warn "Auto-install finished but '$cmd' is still not available in PATH."
    print_issue_help
    exit 1
  }
}

normalize_local_env() {
  if [[ -z "${ANDROID_SDK_ROOT:-}" && -d "$HOME/Library/Android/sdk" ]]; then
    export ANDROID_SDK_ROOT="$HOME/Library/Android/sdk"
  fi
  if [[ -n "${ANDROID_SDK_ROOT:-}" ]]; then
    export ANDROID_HOME="$ANDROID_SDK_ROOT"
    export PATH="$ANDROID_SDK_ROOT/platform-tools:$ANDROID_SDK_ROOT/emulator:$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:$PATH"
  fi

  if [[ -z "${JAVA_HOME:-}" ]]; then
    if [[ -d "/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home" ]]; then
      export JAVA_HOME="/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home"
      export PATH="/opt/homebrew/opt/openjdk@17/bin:$PATH"
    elif [[ -d "/usr/local/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home" ]]; then
      export JAVA_HOME="/usr/local/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home"
      export PATH="/usr/local/opt/openjdk@17/bin:$PATH"
    fi
  fi

  if ! command -v flutter >/dev/null 2>&1; then
    if [[ -x "/opt/homebrew/share/flutter/bin/flutter" ]]; then
      export PATH="/opt/homebrew/share/flutter/bin:$PATH"
    elif [[ -x "/usr/local/share/flutter/bin/flutter" ]]; then
      export PATH="/usr/local/share/flutter/bin:$PATH"
    fi
  fi
}

check_node_version() {
  local node_version major
  node_version="$(node -v | sed 's/^v//')"
  major="${node_version%%.*}"
  if [[ "$major" -ne 20 ]]; then
    warn "Detected Node.js v$node_version. Firebase Functions expects Node.js 20."
  fi
}

run_step() {
  local title="$1"
  shift
  say "$title"
  if ! "$@"; then
    warn "Step failed: $title"
    print_issue_help
    exit 1
  fi
}

setup_mobile() {
  say "Preparing mobile dependencies..."
  install_hint_or_try "flutter" "Install Flutter from https://docs.flutter.dev/get-started/install" "flutter" 1
  install_hint_or_try "dart" "Dart comes with Flutter."

  if [[ "$(uname -s)" == "Darwin" ]]; then
    install_hint_or_try "xcodebuild" "Install Xcode from App Store and run: sudo xcodebuild -runFirstLaunch"
    if [[ "$SKIP_IOS_PODS" -ne 1 ]]; then
      install_hint_or_try "pod" "Install CocoaPods: sudo gem install cocoapods OR brew install cocoapods" "cocoapods"
    fi
  fi

  run_step "Running flutter pub get" bash -lc "cd \"$APP_DIR\" && flutter pub get"

  if [[ "$(uname -s)" == "Darwin" && "$SKIP_IOS_PODS" -ne 1 ]]; then
    run_step "Running pod install for iOS" bash -lc "cd \"$APP_DIR/ios\" && pod install"
  fi
}

setup_functions() {
  say "Preparing Firebase Functions dependencies..."
  install_hint_or_try "node" "Install Node.js 20 (recommended via nvm or Homebrew)." "node@20"
  install_hint_or_try "npm" "npm should be installed together with Node.js."
  check_node_version
  install_hint_or_try "firebase" "Install Firebase CLI: npm install -g firebase-tools" "" 0 "firebase-tools"

  run_step "Installing firebase/functions npm packages" bash -lc "cd \"$FUNCTIONS_DIR\" && npm ci"

  if [[ ! -f "$FUNCTIONS_DIR/.env" && -f "$FUNCTIONS_DIR/.env.example" ]]; then
    cp "$FUNCTIONS_DIR/.env.example" "$FUNCTIONS_DIR/.env"
    warn "Created firebase/functions/.env from .env.example. Review values before deploy."
  fi
}

final_checks() {
  if [[ "$RUN_DOCTOR" -eq 1 && "$SETUP_MOBILE" -eq 1 ]]; then
    run_step "Running flutter doctor -v" flutter doctor -v
  fi

  say "Setup completed successfully."
  echo "Suggested next commands:"
  if [[ "$SETUP_MOBILE" -eq 1 ]]; then
    echo "  ./scripts/run_flutter_targets.sh"
  fi
  if [[ "$SETUP_FUNCTIONS" -eq 1 ]]; then
    echo "  cd firebase/functions && npm run lint && npm run build"
    echo "  firebase login --reauth   # if not logged in yet"
  fi
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --preset)
        shift
        [[ $# -gt 0 ]] || die "--preset requires a value."
        apply_preset "$1"
        shift
        ;;
      --interactive)
        INTERACTIVE=1
        shift
        ;;
      --list-presets)
        SHOW_PRESET_LIST=1
        shift
        ;;
      --mobile-only)
        SETUP_MOBILE=1
        SETUP_FUNCTIONS=0
        shift
        ;;
      --functions-only)
        SETUP_MOBILE=0
        SETUP_FUNCTIONS=1
        shift
        ;;
      --skip-ios-pods)
        SKIP_IOS_PODS=1
        shift
        ;;
      --skip-doctor)
        RUN_DOCTOR=0
        shift
        ;;
      --install-missing)
        INSTALL_MISSING=1
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        usage
        die "Unknown option: $1"
        ;;
    esac
  done
}

main() {
  local arg_count="$#"
  parse_args "$@"

  if [[ "$SHOW_PRESET_LIST" -eq 1 ]]; then
    list_presets
    exit 0
  fi

  if [[ "$ACTIVE_PRESET" == "custom" ]]; then
    INTERACTIVE=1
  fi

  local has_tty=0
  if has_interactive_tty; then
    has_tty=1
  fi

  if [[ "$INTERACTIVE" -eq 1 && "$has_tty" -ne 1 ]]; then
    die "Interactive mode needs a terminal. Use --preset standard|mobile-fast|functions-fast|full-auto."
  fi

  if [[ "$INTERACTIVE" -eq 1 || ( "$arg_count" -eq 0 && "$has_tty" -eq 1 ) ]]; then
    run_interactive_wizard
  elif [[ "$arg_count" -eq 0 ]]; then
    say "No interactive terminal detected. Using preset '$DEFAULT_PRESET'."
    echo "Tip: use --preset <name> for CI/non-interactive runs."
    apply_preset "$DEFAULT_PRESET"
  fi

  normalize_local_env

  [[ -d "$APP_DIR" ]] || die "Missing app directory: $APP_DIR"
  [[ -d "$FUNCTIONS_DIR" ]] || die "Missing functions directory: $FUNCTIONS_DIR"
  [[ "$SETUP_MOBILE" -eq 1 || "$SETUP_FUNCTIONS" -eq 1 ]] || die "Nothing selected to setup."

  echo
  print_selected_plan

  if [[ "$SETUP_MOBILE" -eq 1 ]]; then
    setup_mobile
  fi
  if [[ "$SETUP_FUNCTIONS" -eq 1 ]]; then
    setup_functions
  fi

  final_checks
}

main "$@"
