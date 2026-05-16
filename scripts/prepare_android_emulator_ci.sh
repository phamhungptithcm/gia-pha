#!/usr/bin/env bash
set -euo pipefail

avd_name="${1:-befam_ci_api35}"
api_level="${BEFAM_ANDROID_API_LEVEL:-35}"
system_image="${BEFAM_ANDROID_SYSTEM_IMAGE:-google_apis}"
arch="${BEFAM_ANDROID_ARCH:-x86_64}"
device="${BEFAM_ANDROID_DEVICE:-pixel_6}"
temp_root="${RUNNER_TEMP:-/tmp}"
sdk_root="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-$temp_root/android-sdk}}"
cmdline_tools_dir="$sdk_root/cmdline-tools/latest"
emulator_log="$temp_root/android-emulator.log"

export ANDROID_HOME="$sdk_root"
export ANDROID_SDK_ROOT="$sdk_root"

mkdir -p "$sdk_root"

add_tool_path() {
  case ":$PATH:" in
    *":$1:"*) ;;
    *) export PATH="$1:$PATH" ;;
  esac
  if [ -n "${GITHUB_PATH:-}" ]; then
    echo "$1" >> "$GITHUB_PATH"
  fi
}

persist_android_env() {
  if [ -n "${GITHUB_ENV:-}" ]; then
    {
      echo "ANDROID_HOME=$ANDROID_HOME"
      echo "ANDROID_SDK_ROOT=$ANDROID_SDK_ROOT"
    } >> "$GITHUB_ENV"
  fi
}

resolve_cmdline_tools_url() {
  local repo_xml="$temp_root/android-repository.xml"
  curl -fsSL "https://dl.google.com/android/repository/repository2-1.xml" -o "$repo_xml"
  python3 - "$repo_xml" <<'PY'
import sys
import xml.etree.ElementTree as ET

def local_name(tag):
    return tag.rsplit("}", 1)[-1]

root = ET.parse(sys.argv[1]).getroot()
for package in root.iter():
    if local_name(package.tag) != "remotePackage":
        continue
    if package.attrib.get("path") != "cmdline-tools;latest":
        continue
    for archive in package.iter():
        if local_name(archive.tag) != "archive":
            continue
        host = None
        url = None
        for node in archive.iter():
            name = local_name(node.tag)
            if name == "host-os":
                host = (node.text or "").strip()
            elif name == "url":
                url = (node.text or "").strip()
        if host == "linux" and url:
            print("https://dl.google.com/android/repository/" + url)
            raise SystemExit(0)
raise SystemExit("Could not resolve latest Android command-line tools URL")
PY
}

ensure_cmdline_tools() {
  add_tool_path "$cmdline_tools_dir/bin"
  add_tool_path "$sdk_root/platform-tools"
  add_tool_path "$sdk_root/emulator"

  if command -v sdkmanager >/dev/null 2>&1 && command -v avdmanager >/dev/null 2>&1; then
    return
  fi

  local existing_sdkmanager
  existing_sdkmanager="$(
    find "$sdk_root" -path "*/cmdline-tools/*/bin/sdkmanager" -type f 2>/dev/null \
      | sort \
      | tail -n 1
  )"
  if [ -n "$existing_sdkmanager" ]; then
    add_tool_path "$(dirname "$existing_sdkmanager")"
    return
  fi

  local archive="$temp_root/android-commandline-tools.zip"
  local extracted="$temp_root/android-commandline-tools"
  rm -rf "$archive" "$extracted" "$cmdline_tools_dir"
  mkdir -p "$extracted" "$sdk_root/cmdline-tools"

  curl -fsSL "$(resolve_cmdline_tools_url)" -o "$archive"
  unzip -q "$archive" -d "$extracted"
  mv "$extracted/cmdline-tools" "$cmdline_tools_dir"
  add_tool_path "$cmdline_tools_dir/bin"
}

ensure_android_tool() {
  local tool_name="$1"
  if ! command -v "$tool_name" >/dev/null 2>&1; then
    echo "::error::$tool_name is not available after Android SDK setup."
    find "$sdk_root" -maxdepth 4 -type f -name "$tool_name" 2>/dev/null || true
    exit 127
  fi
}

accept_android_licenses() {
  local sdkmanager_status

  set +e
  set +o pipefail
  yes | sdkmanager --sdk_root="$sdk_root" --licenses >/dev/null
  sdkmanager_status="${PIPESTATUS[1]}"
  set -o pipefail
  set -e

  if [ "$sdkmanager_status" -ne 0 ]; then
    echo "::error::Android SDK license acceptance failed."
    exit "$sdkmanager_status"
  fi
}

ensure_cmdline_tools
persist_android_env
ensure_android_tool sdkmanager
ensure_android_tool avdmanager

accept_android_licenses
sdkmanager \
  --sdk_root="$sdk_root" \
  "platform-tools" \
  "platforms;android-$api_level" \
  "emulator" \
  "system-images;android-$api_level;$system_image;$arch"

echo "no" | avdmanager create avd \
  --force \
  --name "$avd_name" \
  --package "system-images;android-$api_level;$system_image;$arch" \
  --device "$device"

sudo chmod 666 /dev/kvm || true
nohup emulator \
  -avd "$avd_name" \
  -no-window \
  -gpu swiftshader_indirect \
  -no-audio \
  -no-boot-anim \
  -no-snapshot \
  > "$emulator_log" 2>&1 &

adb wait-for-device

boot_completed=0
for _ in $(seq 1 90); do
  if [ "$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = "1" ]; then
    boot_completed=1
    break
  fi
  sleep 2
done

if [ "$boot_completed" != "1" ]; then
  echo "::error::Android emulator did not boot within the timeout."
  tail -n 200 "$emulator_log" || true
  exit 1
fi

adb shell settings put global window_animation_scale 0
adb shell settings put global transition_animation_scale 0
adb shell settings put global animator_duration_scale 0
adb devices
