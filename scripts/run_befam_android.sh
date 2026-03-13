#!/usr/bin/env bash

set -euo pipefail

export JAVA_HOME="/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home"
export ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-$HOME/Library/Android/sdk}"
export ANDROID_HOME="$ANDROID_SDK_ROOT"
export PATH="/opt/homebrew/share/flutter/bin:/opt/homebrew/opt/openjdk@17/bin:$ANDROID_SDK_ROOT/platform-tools:$ANDROID_SDK_ROOT/emulator:$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:$PATH"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$SCRIPT_DIR/../mobile/befam"
DEVICE_ID="${1:-emulator-5554}"

cd "$APP_DIR"
flutter run -d "$DEVICE_ID"
