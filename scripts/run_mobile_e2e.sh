#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-debug}"          # debug | live
PLATFORM="${2:-both}"       # android | ios | both
SUITE="${3:-full}"          # smoke | full

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="${ROOT_DIR}/mobile/befam"
FUNCTIONS_DIR="${ROOT_DIR}/firebase/functions"
ARTIFACTS_DIR="${APP_DIR}/artifacts"
SCREENSHOT_DIR="${APP_DIR}/integration_test/screenshots"
RELEASE_EXECUTION_TEMPLATE="${ROOT_DIR}/docs/vi/05-devops/release-test-execution-template.csv"
RELEASE_DASHBOARD_TEMPLATE="${ROOT_DIR}/docs/vi/05-devops/release-test-dashboard-template.csv"
E2E_REPORT_SCRIPT="${ROOT_DIR}/scripts/generate_e2e_release_report.py"

mkdir -p "${ARTIFACTS_DIR}" "${SCREENSHOT_DIR}"

log() {
  printf '\n==> %s\n' "$1"
}

usage() {
  cat <<'EOF'
Usage:
  ./scripts/run_mobile_e2e.sh [debug|live] [android|ios|both] [smoke|full]

Examples:
  ./scripts/run_mobile_e2e.sh
  ./scripts/run_mobile_e2e.sh debug android smoke
  ./scripts/run_mobile_e2e.sh debug ios full
  ./scripts/run_mobile_e2e.sh live ios

Environment:
  BEFAM_E2E_ANDROID_DEVICE      Optional Android device id (default: first connected android)
  BEFAM_E2E_IOS_DEVICE          Optional iOS simulator/device id (default: first connected iOS simulator)
  BEFAM_E2E_TEST_PHONE          Required for live mode
  BEFAM_E2E_TEST_OTP            Required for live mode
  BEFAM_E2E_SEED_DEBUG_PROFILES true/false. If true, run Firebase debug profile seed script first.
  FIREBASE_PROJECT_ID           Firebase project for debug profile seed script.
  FIREBASE_SERVICE_ACCOUNT_JSON Optional service account JSON path for seed script.
EOF
}

if [[ "${MODE}" != "debug" && "${MODE}" != "live" ]]; then
  usage
  echo "Unsupported mode: ${MODE}" >&2
  exit 1
fi

if [[ "${PLATFORM}" != "android" && "${PLATFORM}" != "ios" && "${PLATFORM}" != "both" ]]; then
  usage
  echo "Unsupported platform: ${PLATFORM}" >&2
  exit 1
fi

if [[ "${SUITE}" != "smoke" && "${SUITE}" != "full" ]]; then
  usage
  echo "Unsupported suite: ${SUITE}" >&2
  exit 1
fi

resolve_android_device() {
  if [[ -n "${BEFAM_E2E_ANDROID_DEVICE:-}" ]]; then
    echo "${BEFAM_E2E_ANDROID_DEVICE}"
    return 0
  fi
  flutter devices --machine 2>/dev/null | python3 -c '
import json, sys
try:
    devices = json.load(sys.stdin)
except Exception:
    print("")
    raise SystemExit(0)
for device in devices:
    target = (device.get("targetPlatform") or "").lower()
    if "android" in target:
        print((device.get("id") or "").strip())
        raise SystemExit(0)
print("")
'
}

resolve_ios_device() {
  if [[ -n "${BEFAM_E2E_IOS_DEVICE:-}" ]]; then
    echo "${BEFAM_E2E_IOS_DEVICE}"
    return 0
  fi
  flutter devices --machine 2>/dev/null | python3 -c '
import json, sys
try:
    devices = json.load(sys.stdin)
except Exception:
    print("")
    raise SystemExit(0)
fallback = ""
for device in devices:
    target = (device.get("targetPlatform") or "").lower()
    if "ios" not in target:
        continue
    device_id = (device.get("id") or "").strip()
    if not device_id:
        continue
    if device.get("emulator") is True:
        print(device_id)
        raise SystemExit(0)
    if not fallback:
        fallback = device_id
print(fallback)
'
}

maybe_seed_debug_profiles() {
  if [[ "${BEFAM_E2E_SEED_DEBUG_PROFILES:-false}" != "true" ]]; then
    return 0
  fi

  : "${FIREBASE_PROJECT_ID:?FIREBASE_PROJECT_ID is required when BEFAM_E2E_SEED_DEBUG_PROFILES=true}"

  log "Seeding debug_login_profiles in Firebase test environment"
  (
    cd "${FUNCTIONS_DIR}"
    ALLOW_TEST_DATA_SEED=true \
      FIREBASE_PROJECT_ID="${FIREBASE_PROJECT_ID}" \
      FIREBASE_SERVICE_ACCOUNT_JSON="${FIREBASE_SERVICE_ACCOUNT_JSON:-}" \
      npm run seed:debug-profiles
  )
}

run_suite_on_device() {
  local target_platform="$1"
  local device_id="$2"

  local machine_output_file="${ARTIFACTS_DIR}/e2e-${MODE}-${target_platform}-${SUITE}-machine.jsonl"
  local summary_output_file="${ARTIFACTS_DIR}/e2e-${MODE}-${target_platform}-${SUITE}-summary.txt"
  local release_execution_file="${ARTIFACTS_DIR}/release-execution-${MODE}-${target_platform}-${SUITE}.csv"
  local release_dashboard_file="${ARTIFACTS_DIR}/release-dashboard-${MODE}-${target_platform}-${SUITE}.csv"
  local release_report_file="${ARTIFACTS_DIR}/e2e-report-${MODE}-${target_platform}-${SUITE}.md"
  local run_id="RC-$(date +"%Y%m%d")-${MODE}-${target_platform}-${SUITE}"
  local app_version
  local build_sha
  local flutter_exit_code=0
  local tests=()
  local defines=(
    "--dart-define=BEFAM_ALLOW_BUNDLED_FIREBASE_OPTIONS=true"
    "--dart-define=BEFAM_ENABLE_APP_CHECK=false"
  )

  if [[ "${MODE}" == "live" ]]; then
    : "${BEFAM_E2E_TEST_PHONE:?BEFAM_E2E_TEST_PHONE is required for live mode}"
    : "${BEFAM_E2E_TEST_OTP:?BEFAM_E2E_TEST_OTP is required for live mode}"
    tests=("integration_test/e2e_live_firebase_test.dart")
    defines+=(
      "--dart-define=BEFAM_E2E_RUN_LIVE=true"
      "--dart-define=BEFAM_E2E_TEST_PHONE=${BEFAM_E2E_TEST_PHONE}"
      "--dart-define=BEFAM_E2E_TEST_OTP=${BEFAM_E2E_TEST_OTP}"
    )
  elif [[ "${SUITE}" == "smoke" ]]; then
    tests=("integration_test/e2e_smoke_ci_test.dart")
  else
    tests=(
      "integration_test/e2e_auth_and_role_matrix_test.dart"
      "integration_test/e2e_feature_journeys_test.dart"
    )
  fi

  app_version="$(awk '/^version:/{print $2; exit}' "${APP_DIR}/pubspec.yaml" || true)"
  build_sha="$(git -C "${ROOT_DIR}" rev-parse --short HEAD 2>/dev/null || true)"

  log "Running ${MODE} E2E on ${target_platform} (${device_id})"
  set +e
  (
    cd "${APP_DIR}"
    set -o pipefail
    flutter test "${tests[@]}" \
      -d "${device_id}" \
      "${defines[@]}" \
      --machine \
      | tee "${machine_output_file}"
  )
  flutter_exit_code=$?
  set -e

  if [[ ${flutter_exit_code} -eq 0 ]]; then
    local machine_has_failures
    machine_has_failures="$(
      python3 - <<'PY' "${machine_output_file}"
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
if not path.exists():
    print("0")
    raise SystemExit(0)

has_failure = False
for raw_line in path.read_text(encoding="utf-8", errors="ignore").splitlines():
    line = raw_line.strip()
    if not line:
        continue
    try:
        event = json.loads(line)
    except json.JSONDecodeError:
        continue
    if not isinstance(event, dict):
        continue
    if event.get("type") != "testDone":
        continue
    if bool(event.get("hidden", False)):
        continue
    result = str(event.get("result", "")).strip().lower()
    if result in {"failure", "error"}:
        has_failure = True
        break

print("1" if has_failure else "0")
PY
    )"
    if [[ "${machine_has_failures}" == "1" ]]; then
      flutter_exit_code=1
    fi
  fi

  {
    echo "mode=${MODE}"
    echo "platform=${target_platform}"
    echo "suite=${SUITE}"
    echo "device_id=${device_id}"
    echo "machine_output=${machine_output_file}"
    echo "timestamp_utc=$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    echo "flutter_exit_code=${flutter_exit_code}"
    echo "release_execution=${release_execution_file}"
    echo "release_dashboard=${release_dashboard_file}"
    echo "release_report=${release_report_file}"
  } > "${summary_output_file}"

  if [[ -f "${E2E_REPORT_SCRIPT}" ]]; then
    log "Generating release execution artifacts (${target_platform})"
    python3 "${E2E_REPORT_SCRIPT}" \
      --machine-file "${machine_output_file}" \
      --template-execution "${RELEASE_EXECUTION_TEMPLATE}" \
      --template-dashboard "${RELEASE_DASHBOARD_TEMPLATE}" \
      --output-execution "${release_execution_file}" \
      --output-dashboard "${release_dashboard_file}" \
      --output-report-md "${release_report_file}" \
      --repo-root "${ROOT_DIR}" \
      --pubspec-path "${APP_DIR}/pubspec.yaml" \
      --run-id "${run_id}" \
      --environment "${MODE}" \
      --device "${target_platform}:${device_id}" \
      --test-date "$(date +"%Y-%m-%d")" \
      --app-version "${app_version}" \
      --build-sha "${build_sha}" \
      --evidence-link "${machine_output_file}"

    cp -f "${release_execution_file}" "${ARTIFACTS_DIR}/release-execution.csv"
    cp -f "${release_dashboard_file}" "${ARTIFACTS_DIR}/release-dashboard.csv"
    cp -f "${release_report_file}" "${ARTIFACTS_DIR}/e2e-report.md"
  fi

  if [[ ${flutter_exit_code} -ne 0 ]]; then
    return ${flutter_exit_code}
  fi
}

main() {
  log "Preparing Flutter dependencies (${MODE}/${PLATFORM}/${SUITE})"
  (
    cd "${APP_DIR}"
    flutter pub get
    flutter gen-l10n
  )

  maybe_seed_debug_profiles

  local android_device=""
  local ios_device=""

  if [[ "${PLATFORM}" == "android" || "${PLATFORM}" == "both" ]]; then
    android_device="$(resolve_android_device)"
    if [[ -z "${android_device}" ]]; then
      echo "No Android device detected. Set BEFAM_E2E_ANDROID_DEVICE manually." >&2
      exit 1
    fi
    run_suite_on_device "android" "${android_device}"
  fi

  if [[ "${PLATFORM}" == "ios" || "${PLATFORM}" == "both" ]]; then
    ios_device="$(resolve_ios_device)"
    if [[ -z "${ios_device}" ]]; then
      echo "No iOS simulator detected. Set BEFAM_E2E_IOS_DEVICE manually." >&2
      exit 1
    fi
    run_suite_on_device "ios" "${ios_device}"
  fi

  log "E2E execution completed. Artifacts at ${ARTIFACTS_DIR}"
}

main
