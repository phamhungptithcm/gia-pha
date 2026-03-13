#!/usr/bin/env bash

set -euo pipefail

export ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-$HOME/Library/Android/sdk}"
export ANDROID_HOME="$ANDROID_SDK_ROOT"
export PATH="$ANDROID_SDK_ROOT/emulator:$ANDROID_SDK_ROOT/platform-tools:$PATH"

EMULATOR_NAME="${1:-flutter_android_test}"

"$ANDROID_SDK_ROOT/emulator/emulator" -list-avds | grep -Fx "$EMULATOR_NAME" >/dev/null

nohup "$ANDROID_SDK_ROOT/emulator/emulator" -avd "$EMULATOR_NAME" -no-snapshot-load >/tmp/"$EMULATOR_NAME".log 2>&1 &

echo "Starting emulator: $EMULATOR_NAME"
echo "Log: /tmp/$EMULATOR_NAME.log"
