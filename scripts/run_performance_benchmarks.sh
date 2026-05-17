#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT_DIR/mobile/befam"
ARTIFACTS_DIR="${BEFAM_PERF_ARTIFACTS_DIR:-$APP_DIR/artifacts/performance}"
REPORT_PATH="$ARTIFACTS_DIR/performance-report.md"
PORT="${BEFAM_BENCHMARK_WEB_PORT:-4173}"
WEB_URL="http://127.0.0.1:$PORT"
PROFILE_DEVICE="${BEFAM_PROFILE_DEVICE:-}"
SERVER_PID=""

mkdir -p "$ARTIFACTS_DIR"

cleanup() {
  if [[ -n "$SERVER_PID" ]] && kill -0 "$SERVER_PID" >/dev/null 2>&1; then
    kill "$SERVER_PID" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

log() {
  printf '\n==> %s\n' "$1"
}

append_report() {
  printf '%s\n' "$1" >>"$REPORT_PATH"
}

run_and_capture() {
  local label="$1"
  local log_path="$2"
  shift 2
  log "$label"
  set +e
  "$@" 2>&1 | tee "$log_path"
  local status="${PIPESTATUS[0]}"
  set -e
  if [[ "$status" -eq 0 ]]; then
    append_report "- $label: PASS"
  else
    append_report "- $label: FAIL (see \`$log_path\`)"
  fi
  return "$status"
}

pick_profile_device() {
  printf '%s' "${PROFILE_DEVICE:-chrome}"
}

extract_lighthouse_metrics() {
  python3 - "$ARTIFACTS_DIR/lighthouse-web-release.json" <<'PY'
import json, sys
path = sys.argv[1]
with open(path, "r", encoding="utf-8") as handle:
    data = json.load(handle)

categories = data.get("categories", {})
audits = data.get("audits", {})

def score(name):
    value = categories.get(name, {}).get("score")
    return "n/a" if value is None else f"{value * 100:.0f}"

def audit(name):
    item = audits.get(name, {})
    return item.get("displayValue") or "n/a"

print("| Metric | Result |")
print("| --- | --- |")
print(f"| Performance score | {score('performance')} |")
print(f"| Accessibility score | {score('accessibility')} |")
print(f"| Best Practices score | {score('best-practices')} |")
print(f"| SEO score | {score('seo')} |")
print(f"| FCP | {audit('first-contentful-paint')} |")
print(f"| LCP | {audit('largest-contentful-paint')} |")
print(f"| Speed Index | {audit('speed-index')} |")
print(f"| TBT | {audit('total-blocking-time')} |")
print(f"| CLS | {audit('cumulative-layout-shift')} |")
PY
}

cd "$APP_DIR"

cat >"$REPORT_PATH" <<REPORT
# BeFam Performance Report

- Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
- Git SHA: $(git -C "$ROOT_DIR" rev-parse --short HEAD 2>/dev/null || echo unknown)
- Artifact directory: \`$ARTIFACTS_DIR\`

## Automated Runs
REPORT

run_and_capture \
  "Flutter dependency refresh" \
  "$ARTIFACTS_DIR/flutter-pub-get.log" \
  flutter pub get

run_and_capture \
  "Flutter localization generation" \
  "$ARTIFACTS_DIR/flutter-gen-l10n.log" \
  flutter gen-l10n

run_and_capture \
  "Genealogy visible-tree benchmark" \
  "$ARTIFACTS_DIR/genealogy-benchmark.log" \
  flutter test test/features/genealogy/genealogy_workspace_benchmark_test.dart \
    --dart-define=RUN_GENEALOGY_BENCHMARKS=true

run_and_capture \
  "Flutter web release build" \
  "$ARTIFACTS_DIR/flutter-build-web.log" \
  flutter build web --release --no-wasm-dry-run \
    --dart-define=BEFAM_ALLOW_BUNDLED_FIREBASE_OPTIONS=true \
    --dart-define=BEFAM_OTP_PROVIDER=firebase \
    --dart-define=BEFAM_ALLOW_FIREBASE_PHONE_FALLBACK=false \
    --dart-define=BEFAM_ENABLE_APP_CHECK=false

log "Serve Flutter web release build"
python3 -m http.server "$PORT" --directory "$APP_DIR/build/web" \
  >"$ARTIFACTS_DIR/web-server.log" 2>&1 &
SERVER_PID="$!"

for _ in {1..50}; do
  if curl -fsS "$WEB_URL" >/dev/null 2>&1; then
    break
  fi
  sleep 0.2
done
curl -fsS "$WEB_URL" >/dev/null

if command -v npx >/dev/null 2>&1; then
  run_and_capture \
    "Lighthouse web release audit" \
    "$ARTIFACTS_DIR/lighthouse.log" \
    npx --yes lighthouse "$WEB_URL" \
      --chrome-flags="--headless=new --no-sandbox" \
      --output=json \
      --output-path="$ARTIFACTS_DIR/lighthouse-web-release.json"

  if [[ -f "$ARTIFACTS_DIR/lighthouse-web-release.json" ]]; then
    {
      printf '\n## Lighthouse Web Release\n\n'
      extract_lighthouse_metrics
    } >>"$REPORT_PATH"
  fi
else
  append_report "- Lighthouse web release audit: SKIP (npx is unavailable)"
fi

profile_device="$(pick_profile_device || true)"
run_and_capture \
  "Flutter profile-mode web build ($profile_device)" \
  "$ARTIFACTS_DIR/flutter-profile-build.log" \
  flutter build web --profile --no-wasm-dry-run \
    --dart-define=BEFAM_ALLOW_BUNDLED_FIREBASE_OPTIONS=true \
    --dart-define=BEFAM_OTP_PROVIDER=firebase \
    --dart-define=BEFAM_ALLOW_FIREBASE_PHONE_FALLBACK=false \
    --dart-define=BEFAM_ENABLE_APP_CHECK=false

append_report "- Flutter profile-mode runtime: capture with \`flutter run --profile -d $profile_device\` when interactive DevTools profiling is needed"

{
  printf '\n## Firebase Performance Traces\n\n'
  printf 'The app now emits custom traces through Firebase Performance for workspace refreshes and frame timing batches. Inspect these trace names after a staging/profile run:\n\n'
  printf -- '- `befam_frames_batch_p95`\n'
  printf -- '- `befam_clan_workspace_refresh`\n'
  printf -- '- `befam_events_workspace_refresh`\n'
  printf -- '- `befam_funds_workspace_refresh`\n'
  printf -- '- `befam_billing_workspace_refresh`\n'
  printf -- '- `befam_profile_workspace_refresh`\n'
  printf -- '- `befam_calendar_month_refresh`\n'
  printf -- '- `befam_scholarship_workspace_refresh`\n'
} >>"$REPORT_PATH"

log "Performance report: $REPORT_PATH"
cat "$REPORT_PATH"
