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
  BEFAM_E2E_SKIP_DEP_PREP       true/false. If true, skip flutter pub get/gen-l10n pre-step in this script.
  BEFAM_E2E_FAST_MODE           true/false. If true, pass fast-mode test defines to integration tests.
  BEFAM_E2E_SKIP_SCREENSHOTS    true/false. If true, integration tests skip screenshot capture.
  BEFAM_E2E_IOS_MAX_ATTEMPTS    Optional integer override for iOS retry attempts (default: smoke=1, full=2).
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

seconds_now() {
  date +%s
}

print_duration() {
  local label="$1"
  local started_at="$2"
  local ended_at
  local elapsed
  ended_at="$(seconds_now)"
  elapsed=$((ended_at - started_at))
  printf '::notice::%s completed in %ss\n' "${label}" "${elapsed}"
}

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

machine_output_has_ios_transient_start_failure() {
  local machine_output_file="$1"
  python3 - <<'PY' "${machine_output_file}"
import sys
from pathlib import Path

path = Path(sys.argv[1])
if not path.exists():
    print("0")
    raise SystemExit(0)

content = path.read_text(encoding="utf-8", errors="ignore").lower()
needles = (
    "connecting to the vm service timed out",
    "unable to start the app on the device",
)
print("1" if any(needle in content for needle in needles) else "0")
PY
}

reboot_ios_simulator() {
  local simulator_udid="$1"
  if [[ -z "${simulator_udid}" ]]; then
    return 1
  fi
  if ! command -v xcrun >/dev/null 2>&1; then
    return 1
  fi

  log "Rebooting iOS simulator (${simulator_udid}) before retry"
  xcrun simctl shutdown "${simulator_udid}" >/dev/null 2>&1 || true
  sleep 3
  xcrun simctl boot "${simulator_udid}" >/dev/null 2>&1 || true

  if ! xcrun simctl bootstatus "${simulator_udid}" -b >/dev/null 2>&1; then
    local state=""
    for _ in $(seq 1 60); do
      state="$(
        xcrun simctl list devices -j | python3 -c 'import json,sys;target=sys.argv[1].strip();payload=json.load(sys.stdin);state=next(((d.get("state") or "").strip() for entries in payload.get("devices", {}).values() for d in entries if (d.get("udid") or "").strip()==target),"");print(state)' "${simulator_udid}"
      )"
      if [[ "${state}" == "Booted" ]]; then
        break
      fi
      sleep 2
    done
    if [[ "${state}" != "Booted" ]]; then
      echo "Simulator ${simulator_udid} did not return to Booted state after retry reboot." >&2
      return 1
    fi
  fi
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
  local retry_attempt=1
  local max_attempts=1
  local run_started_at
  local ios_max_attempts="${BEFAM_E2E_IOS_MAX_ATTEMPTS:-}"
  local tests=()
  local defines=(
    "--dart-define=BEFAM_ALLOW_BUNDLED_FIREBASE_OPTIONS=true"
    "--dart-define=BEFAM_OTP_PROVIDER=${BEFAM_E2E_OTP_PROVIDER:-firebase}"
    "--dart-define=BEFAM_ALLOW_FIREBASE_PHONE_FALLBACK=false"
    "--dart-define=BEFAM_ENABLE_APP_CHECK=false"
    "--dart-define=BEFAM_E2E_FAST_MODE=${BEFAM_E2E_FAST_MODE:-false}"
    "--dart-define=BEFAM_E2E_SKIP_SCREENSHOTS=${BEFAM_E2E_SKIP_SCREENSHOTS:-false}"
  )

  if [[ "${MODE}" == "live" ]]; then
    : "${BEFAM_E2E_TEST_PHONE:?BEFAM_E2E_TEST_PHONE is required for live mode}"
    : "${BEFAM_E2E_TEST_OTP:?BEFAM_E2E_TEST_OTP is required for live mode}"
    if [[ "${SUITE}" == "smoke" ]]; then
      tests=("integration_test/e2e_live_smoke_gate_test.dart")
    else
      tests=(
        "integration_test/e2e_live_smoke_gate_test.dart"
        "integration_test/e2e_live_firebase_test.dart"
      )
    fi
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

  if [[ "${target_platform}" == "ios" ]]; then
    if [[ -n "${ios_max_attempts}" ]]; then
      max_attempts="${ios_max_attempts}"
    elif [[ "${SUITE}" == "smoke" ]]; then
      max_attempts=1
    else
      max_attempts=2
    fi
  fi

  run_started_at="$(seconds_now)"

  while true; do
    log "Running ${MODE} E2E on ${target_platform} (${device_id}) [attempt ${retry_attempt}/${max_attempts}]"
    set +e
    (
      cd "${APP_DIR}"
      set -o pipefail
      flutter test "${tests[@]}" \
        -d "${device_id}" \
        "${defines[@]}" \
        --no-pub \
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

    if [[ ${flutter_exit_code} -eq 0 ]]; then
      break
    fi

    if [[ "${target_platform}" == "ios" && "${retry_attempt}" -lt "${max_attempts}" ]]; then
      local has_transient_ios_failure
      has_transient_ios_failure="$(machine_output_has_ios_transient_start_failure "${machine_output_file}")"
      if [[ "${has_transient_ios_failure}" == "1" ]]; then
        log "Detected transient iOS startup/VM-service failure. Retrying once..."
        reboot_ios_simulator "${device_id}" || true
        retry_attempt=$((retry_attempt + 1))
        continue
      fi
    fi

    break
  done

  {
    echo "mode=${MODE}"
    echo "platform=${target_platform}"
    echo "suite=${SUITE}"
    echo "device_id=${device_id}"
    echo "machine_output=${machine_output_file}"
    echo "timestamp_utc=$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    echo "attempt_count=${retry_attempt}"
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

  print_duration "E2E ${target_platform}/${SUITE}" "${run_started_at}"
}

main() {
  local prepare_started_at
  local run_started_at
  run_started_at="$(seconds_now)"

  if [[ "${BEFAM_E2E_SKIP_DEP_PREP:-false}" != "true" ]]; then
    prepare_started_at="$(seconds_now)"
    log "Preparing Flutter dependencies (${MODE}/${PLATFORM}/${SUITE})"
    (
      cd "${APP_DIR}"
      flutter pub get
      if [[ "${BEFAM_E2E_SKIP_GEN_L10N:-false}" != "true" ]]; then
        flutter gen-l10n
      fi
    )
    print_duration "Dependency preparation" "${prepare_started_at}"
  else
    echo "::notice::Skipping dependency preparation (BEFAM_E2E_SKIP_DEP_PREP=true)."
  fi

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

  print_duration "Total E2E run (${MODE}/${PLATFORM}/${SUITE})" "${run_started_at}"
  log "E2E execution completed. Artifacts at ${ARTIFACTS_DIR}"
}

main
