#!/usr/bin/env bash

set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
PROJECT_ID="${FIREBASE_PROJECT_ID:-}"
ACCESS_TOKEN=""
NON_INTERACTIVE_ACTION=""

DEFAULT_LOG_SINCE_MINUTES=60
DEFAULT_LOG_LIMIT=100
DEFAULT_LOG_SEVERITY="ERROR"

LOG_SINCE_MINUTES="$DEFAULT_LOG_SINCE_MINUTES"
LOG_LIMIT="$DEFAULT_LOG_LIMIT"
LOG_SEVERITY="$DEFAULT_LOG_SEVERITY"
LOG_CONTAINS=""
LOG_FUNCTION=""
LOG_TRACE=""
LOG_UID=""
LOG_PHONE=""
LOG_MEMBER_ID=""
LOG_TXN_ID=""
LOG_OUTPUT_JSON=0
LOG_PRESET=""
EXPORT_PATH=""
RERUN_LAST=0

APP_LANG="${FQC_LANG:-en}"
HISTORY_DIR="${HOME}/.firebase-query-console"
HISTORY_FILE="${HISTORY_DIR}/query_history.jsonl"
LAST_QUERY_FILE="${HISTORY_DIR}/last_query.json"
HISTORY_REDACT_SENSITIVE="${FQC_HISTORY_REDACT_SENSITIVE:-true}"

COLOR_RESET=""
COLOR_DIM=""
COLOR_RED=""
COLOR_YELLOW=""
COLOR_GREEN=""
COLOR_CYAN=""

require_command() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Missing required command: $cmd" >&2
    exit 1
  fi
}

require_deps() {
  require_command firebase
  require_command jq
  require_command curl
  require_command node
}

txt() {
  local vi="$1"
  local en="$2"
  local lang
  lang="$(echo "${APP_LANG}" | tr '[:upper:]' '[:lower:]')"
  if [[ "$lang" == "en" ]]; then
    printf '%s' "$en"
  else
    printf '%s' "$vi"
  fi
}

normalize_language() {
  APP_LANG="$(echo "${APP_LANG}" | tr '[:upper:]' '[:lower:]')"
  case "$APP_LANG" in
    vi|en) ;;
    *)
      echo "$(txt "Ngôn ngữ --lang không hỗ trợ:" "Unsupported --lang:") $APP_LANG (use: vi|en)" >&2
      exit 1
      ;;
  esac
}

is_truthy() {
  local raw="${1:-}"
  local normalized
  normalized="$(echo "$raw" | tr '[:upper:]' '[:lower:]')"
  case "$normalized" in
    1|true|yes|y|on) return 0 ;;
    *) return 1 ;;
  esac
}

sanitize_history_sensitive_value() {
  local value="${1:-}"
  if [[ -z "$value" ]]; then
    printf '%s' ""
    return
  fi
  if ! is_truthy "$HISTORY_REDACT_SENSITIVE"; then
    printf '%s' "$value"
    return
  fi
  printf '[REDACTED:%s]' "${#value}"
}

restore_history_sensitive_value() {
  local value="${1:-}"
  if [[ "$value" == \[REDACTED:* ]]; then
    printf '%s' ""
    return
  fi
  printf '%s' "$value"
}

init_colors() {
  if [[ -t 1 ]]; then
    COLOR_RESET=$'\033[0m'
    COLOR_DIM=$'\033[2m'
    COLOR_RED=$'\033[31m'
    COLOR_YELLOW=$'\033[33m'
    COLOR_GREEN=$'\033[32m'
    COLOR_CYAN=$'\033[36m'
  fi
}

ensure_history_store() {
  mkdir -p "$HISTORY_DIR"
  touch "$HISTORY_FILE"
  if [[ -s "$HISTORY_FILE" ]] && ! jq -s '.' "$HISTORY_FILE" >/dev/null 2>&1; then
    local backup="${HISTORY_FILE}.corrupt.$(date +%s)"
    mv "$HISTORY_FILE" "$backup"
    touch "$HISTORY_FILE"
    echo "$(txt "Lịch sử query cũ bị lỗi format, đã backup tại:" "Detected corrupted history format, backed up to:") $backup" >&2
  fi
}

escape_json_string() {
  local value="${1:-}"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  value="${value//$'\n'/ }"
  printf '%s' "$value"
}

ensure_firebase_login() {
  if ! firebase projects:list --json >/dev/null 2>&1; then
    echo "$(txt "Firebase CLI chưa đăng nhập hoặc token hết hạn." "Firebase CLI is not logged in or token has expired.")" >&2
    echo "$(txt "Hãy chạy:" "Please run:") firebase login --reauth" >&2
    exit 1
  fi
}

load_access_token() {
  ACCESS_TOKEN="$(node <<'NODE'
const fs = require('fs');
const path = require('path');
const p = path.join(process.env.HOME || '', '.config', 'configstore', 'firebase-tools.json');
try {
  const raw = fs.readFileSync(p, 'utf8');
  const parsed = JSON.parse(raw);
  process.stdout.write(parsed?.tokens?.access_token || '');
} catch {
  process.stdout.write('');
}
NODE
)"

  if [[ -z "$ACCESS_TOKEN" ]]; then
    echo "$(txt "Không lấy được Firebase access token từ firebase-tools config." "Cannot read Firebase access token from firebase-tools config.")" >&2
    echo "$(txt "Hãy chạy:" "Please run:") firebase login --reauth" >&2
    exit 1
  fi
}

is_positive_int() {
  local value="${1:-}"
  [[ "$value" =~ ^[0-9]+$ ]] && [[ "$value" -gt 0 ]]
}

escape_logging_filter_value() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  printf '%s' "$value"
}

minutes_ago_iso_utc() {
  local minutes="$1"
  node -e '
const minutes = Number(process.argv[1] || "0");
const iso = new Date(Date.now() - minutes * 60_000).toISOString();
process.stdout.write(iso);
' "$minutes"
}

normalize_severity() {
  local severity="${1:-ERROR}"
  severity="$(echo "$severity" | tr '[:lower:]' '[:upper:]')"
  case "$severity" in
    DEFAULT|DEBUG|INFO|NOTICE|WARNING|ERROR|CRITICAL|ALERT|EMERGENCY)
      printf '%s' "$severity"
      ;;
    *)
      echo "$(txt "Mức severity không hợp lệ:" "Invalid severity:") $severity" >&2
      echo "$(txt "Dùng một trong:" "Use one of:") DEFAULT DEBUG INFO NOTICE WARNING ERROR CRITICAL ALERT EMERGENCY" >&2
      exit 1
      ;;
  esac
}

build_log_filter() {
  local since_minutes="$1"
  local severity="$2"
  local contains="$3"
  local function_name="$4"
  local trace_id="$5"
  local uid="$6"
  local phone="$7"
  local member_id="$8"
  local txn_id="$9"

  local since_iso
  since_iso="$(minutes_ago_iso_utc "$since_minutes")"

  local clauses=()
  clauses+=("timestamp >= \"$since_iso\"")
  clauses+=("severity >= $severity")
  clauses+=("(resource.type=\"cloud_function\" OR resource.type=\"cloud_run_revision\")")

  if [[ -n "$function_name" ]]; then
    local fn
    fn="$(escape_logging_filter_value "$function_name")"
    clauses+=(
      "(resource.labels.function_name=\"$fn\" OR resource.labels.service_name=\"$fn\")"
    )
  fi

  if [[ -n "$contains" ]]; then
    local needle
    needle="$(escape_logging_filter_value "$contains")"
    clauses+=(
      "(textPayload:\"$needle\" OR jsonPayload.message:\"$needle\" OR jsonPayload.error:\"$needle\" OR protoPayload.status.message:\"$needle\")"
    )
  fi

  if [[ -n "$trace_id" ]]; then
    local trace
    trace="$(escape_logging_filter_value "$trace_id")"
    clauses+=("trace:\"$trace\"")
  fi

  if [[ -n "$uid" ]]; then
    local uid_escaped
    uid_escaped="$(escape_logging_filter_value "$uid")"
    clauses+=(
      "(jsonPayload.uid=\"$uid_escaped\" OR jsonPayload.userId=\"$uid_escaped\" OR jsonPayload.ownerUid=\"$uid_escaped\" OR textPayload:\"$uid_escaped\")"
    )
  fi

  if [[ -n "$phone" ]]; then
    local phone_escaped
    phone_escaped="$(escape_logging_filter_value "$phone")"
    clauses+=(
      "(jsonPayload.phone=\"$phone_escaped\" OR jsonPayload.phoneNumber=\"$phone_escaped\" OR textPayload:\"$phone_escaped\")"
    )
  fi

  if [[ -n "$member_id" ]]; then
    local member_escaped
    member_escaped="$(escape_logging_filter_value "$member_id")"
    clauses+=(
      "(jsonPayload.memberId=\"$member_escaped\" OR jsonPayload.targetMemberId=\"$member_escaped\" OR textPayload:\"$member_escaped\")"
    )
  fi

  if [[ -n "$txn_id" ]]; then
    local txn_escaped
    txn_escaped="$(escape_logging_filter_value "$txn_id")"
    clauses+=(
      "(jsonPayload.transactionId=\"$txn_escaped\" OR jsonPayload.txnId=\"$txn_escaped\" OR jsonPayload.orderId=\"$txn_escaped\" OR textPayload:\"$txn_escaped\")"
    )
  fi

  local filter=""
  local clause
  for clause in "${clauses[@]}"; do
    if [[ -z "$filter" ]]; then
      filter="$clause"
    else
      filter="$filter AND $clause"
    fi
  done
  printf '%s' "$filter"
}

logging_query_entries() {
  local filter="$1"
  local page_size="$2"

  local payload
  payload="$(jq -n \
    --arg resource "projects/$PROJECT_ID" \
    --arg filter "$filter" \
    --argjson pageSize "$page_size" \
    '{
      resourceNames: [$resource],
      filter: $filter,
      orderBy: "timestamp desc",
      pageSize: $pageSize
    }')"

  local url="https://logging.googleapis.com/v2/entries:list"
  local response
  response="$(curl -sS \
    -H "Authorization: Bearer $ACCESS_TOKEN" \
    -H "Content-Type: application/json" \
    -X POST "$url" \
    --data "$payload")"

  if echo "$response" | jq -e '.error != null' >/dev/null 2>&1; then
    echo "$(txt "Cloud Logging API trả lỗi:" "Cloud Logging API returned an error:")" >&2
    echo "$response" | jq -r '.error'
    return 1
  fi

  echo "$response" | jq '.entries // []'
}

colorize_severity() {
  local severity="$1"
  local severity_upper
  severity_upper="$(echo "$severity" | tr '[:lower:]' '[:upper:]')"
  case "$severity_upper" in
    EMERGENCY|ALERT|CRITICAL|ERROR)
      printf '%b' "${COLOR_RED}${severity}${COLOR_RESET}"
      ;;
    WARNING|NOTICE)
      printf '%b' "${COLOR_YELLOW}${severity}${COLOR_RESET}"
      ;;
    INFO)
      printf '%b' "${COLOR_GREEN}${severity}${COLOR_RESET}"
      ;;
    DEBUG|DEFAULT)
      printf '%b' "${COLOR_DIM}${severity}${COLOR_RESET}"
      ;;
    *)
      printf '%s' "$severity"
      ;;
  esac
}

slugify() {
  local raw="$1"
  echo "$raw" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//'
}

highlight_message() {
  local message="$1"
  local keyword="$2"
  if [[ -z "$keyword" || -z "$COLOR_CYAN" ]]; then
    printf '%s' "$message"
    return
  fi
  local escaped
  escaped="$(printf '%s' "$keyword" | sed -E 's/[][(){}.^$*+?|\/]/\\&/g')"
  printf '%s' "$message" | sed -E "s/${escaped}/${COLOR_CYAN}&${COLOR_RESET}/g"
}

render_log_entries_pretty() {
  local entries_json="$1"
  local keyword="$2"

  local total
  total="$(echo "$entries_json" | jq 'length')"
  if [[ "$total" -eq 0 ]]; then
    echo "$(txt "Không có log phù hợp filter." "No logs matched the filter.")"
    return
  fi

  echo "total: $total"
  printf '%-20s  %-12s  %-30s  %s\n' \
    "timestamp" \
    "severity" \
    "source" \
    "$(txt "message" "message")"
  printf '%-20s  %-12s  %-30s  %s\n' \
    "--------------------" \
    "------------" \
    "------------------------------" \
    "------------------------------------------------------------"

  while IFS=$'\t' read -r ts sev source trace msg; do
    local source_short="$source"
    if [[ "${#source_short}" -gt 30 ]]; then
      source_short="${source_short:0:27}..."
    fi
    local sev_colored
    sev_colored="$(colorize_severity "$sev")"
    local enriched="$msg"
    if [[ -n "$trace" ]]; then
      enriched="${enriched} ${COLOR_DIM}(trace:${trace##*/})${COLOR_RESET}"
    fi
    enriched="$(highlight_message "$enriched" "$keyword")"

    local first=1
    while IFS= read -r msg_line; do
      if [[ "$first" -eq 1 ]]; then
        printf '%-20s  %-12b  %-30s  %s\n' "$ts" "$sev_colored" "$source_short" "$msg_line"
        first=0
      else
        printf '%-20s  %-12s  %-30s  %s\n' "" "" "" "$msg_line"
      fi
    done < <(printf '%s' "$enriched" | fold -s -w 90)
  done < <(
    echo "$entries_json" | jq -r '
      .[] | [
        (.timestamp // ""),
        (.severity // "DEFAULT"),
        (.resource.labels.function_name // .resource.labels.service_name // .logName // ""),
        (.trace // ""),
        (
          .textPayload
          // .jsonPayload.message
          // .jsonPayload.error
          // .protoPayload.status.message
          // (if .jsonPayload then (.jsonPayload | tostring) else "" end)
          // ""
          | gsub("[\\n\\r\\t]+"; " ")
          | .[0:280]
        )
      ] | @tsv
    '
  )
}

build_summary_json() {
  local entries_json="$1"
  echo "$entries_json" | jq -c '
    {
      total: length,
      bySeverity: (
        group_by(.severity // "DEFAULT")
        | map({severity: (.[0].severity // "DEFAULT"), count: length})
        | sort_by(-.count)
      ),
      topFunctions: (
        map(.resource.labels.function_name // .resource.labels.service_name // "unknown")
        | group_by(.)
        | map({name: .[0], count: length})
        | sort_by(-.count)
        | .[0:5]
      ),
      sampleTraces: (
        map(.trace // "")
        | map(select(length > 0))
        | unique
        | .[0:5]
      ),
      topMessages: (
        map(
          (
            .textPayload
            // .jsonPayload.message
            // .jsonPayload.error
            // .protoPayload.status.message
            // ""
          )
          | gsub("[\\n\\r\\t]+"; " ")
          | .[0:140]
        )
        | map(select(length > 0))
        | group_by(.)
        | map({message: .[0], count: length})
        | sort_by(-.count)
        | .[0:5]
      )
    }
  '
}

suggest_next_steps() {
  local entries_json="$1"
  local has_keyword="$2"
  local total
  total="$(echo "$entries_json" | jq 'length')"
  echo
  echo "$(txt "Gợi ý bước tiếp theo:" "Suggested next steps:")"

  if [[ "$total" -eq 0 ]]; then
    echo "1. $(txt "Tăng --since-minutes (vd: 180 hoặc 720)." "Increase --since-minutes (for example: 180 or 720).")"
    echo "2. $(txt "Hạ --severity về WARNING hoặc INFO." "Lower --severity to WARNING or INFO.")"
    echo "3. $(txt "Bỏ bớt điều kiện lọc (--function/--contains/ID)." "Relax filters (--function/--contains/ID fields).")"
    return
  fi

  local has_permission
  has_permission="$(echo "$entries_json" | jq -r '
    any(
      .[];
      (
        (
          .textPayload
          // .jsonPayload.message
          // .jsonPayload.error
          // .protoPayload.status.message
          // ""
        )
        | ascii_downcase
      ) as $m
      | ($m | contains("permission-denied") or contains("permission denied"))
    )'
  )"
  local has_timeout
  has_timeout="$(echo "$entries_json" | jq -r '
    any(
      .[];
      (
        (
          .textPayload
          // .jsonPayload.message
          // .jsonPayload.error
          // .protoPayload.status.message
          // ""
        )
        | ascii_downcase
      ) as $m
      | ($m | contains("timeout") or contains("deadline exceeded"))
    )'
  )"

  if [[ "$has_permission" == "true" ]]; then
    echo "1. $(txt "Kiểm tra Firestore Rules/IAM role cho actor gây lỗi permission-denied." "Check Firestore Rules/IAM roles for the actor causing permission-denied.")"
  fi
  if [[ "$has_timeout" == "true" ]]; then
    echo "2. $(txt "Kiểm tra cold start, network call ngoài và retry/backoff ở function bị timeout." "Check cold start, external network calls, and retry/backoff for timed-out functions.")"
  fi

  if [[ -n "$has_keyword" ]]; then
    echo "3. $(txt "Nếu còn nhiễu, thêm --function hoặc --trace để khoanh vùng." "If still noisy, add --function or --trace to narrow down.")"
  else
    echo "3. $(txt "Dùng --contains '<error-code|user-id|txn-id>' để thu hẹp logs." "Use --contains '<error-code|user-id|txn-id>' to narrow logs.")"
  fi
  echo "4. $(txt "Sau khi fix, chạy lại cùng filter để verify regression." "After fixing, rerun with the same filter to verify regression.")"
}

resolve_export_path() {
  local title="$1"
  local action_tag="$2"
  local path="$EXPORT_PATH"
  if [[ -z "$path" ]]; then
    printf '%s' ""
    return
  fi

  if [[ "$action_tag" == triage-* ]]; then
    local slug
    slug="$(slugify "$action_tag")"
    if [[ "$path" == *.json ]]; then
      printf '%s' "${path%.json}_${slug}.json"
    elif [[ "$path" == *.md ]]; then
      printf '%s' "${path%.md}_${slug}.md"
    else
      printf '%s' "${path}_${slug}.md"
    fi
    return
  fi
  printf '%s' "$path"
}

export_query_report() {
  local out_path="$1"
  local title="$2"
  local filter="$3"
  local entries_json="$4"
  local summary_json="$5"
  local action_tag="$6"

  if [[ -z "$out_path" ]]; then
    return
  fi

  mkdir -p "$(dirname "$out_path")"

  local report_json
  report_json="$(jq -n \
    --arg generatedAt "$(date -u +%FT%TZ)" \
    --arg projectId "$PROJECT_ID" \
    --arg lang "$APP_LANG" \
    --arg action "$action_tag" \
    --arg title "$title" \
    --arg filter "$filter" \
    --arg contains "$LOG_CONTAINS" \
    --arg function "$LOG_FUNCTION" \
    --arg trace "$LOG_TRACE" \
    --arg uid "$LOG_UID" \
    --arg phone "$LOG_PHONE" \
    --arg memberId "$LOG_MEMBER_ID" \
    --arg txnId "$LOG_TXN_ID" \
    --arg preset "$LOG_PRESET" \
    --argjson sinceMinutes "$LOG_SINCE_MINUTES" \
    --argjson limit "$LOG_LIMIT" \
    --arg severity "$LOG_SEVERITY" \
    --argjson summary "$summary_json" \
    --argjson entries "$entries_json" \
    '{
      generatedAt: $generatedAt,
      projectId: $projectId,
      language: $lang,
      action: $action,
      title: $title,
      filter: $filter,
      params: {
        preset: $preset,
        sinceMinutes: $sinceMinutes,
        limit: $limit,
        severity: $severity,
        contains: $contains,
        function: $function,
        trace: $trace,
        uid: $uid,
        phone: $phone,
        memberId: $memberId,
        txnId: $txnId
      },
      summary: $summary,
      entries: $entries
    }'
  )"

  if [[ "$out_path" == *.json ]]; then
    echo "$report_json" | jq '.' > "$out_path"
    echo "$(txt "Đã export report JSON:" "Exported JSON report:") $out_path"
    return
  fi

  {
    echo "# $(txt "Báo cáo log query" "Log query report")"
    echo
    echo "- $(txt "Thời gian" "Generated at"): $(date -u +%FT%TZ)"
    echo "- Project: $PROJECT_ID"
    echo "- Action: $action_tag"
    echo "- Title: $title"
    echo "- Filter: \`$filter\`"
    echo "- Params: preset=\`${LOG_PRESET:-none}\`, severity=\`$LOG_SEVERITY\`, since=\`${LOG_SINCE_MINUTES}m\`, limit=\`$LOG_LIMIT\`"
    echo
    echo "## $(txt "Tóm tắt" "Summary")"
    echo
    echo "$summary_json" | jq -r '
      "- total: \(.total)\n"
      + (
          if (.bySeverity | length) == 0 then "- bySeverity: none\n"
          else
            "- bySeverity:\n"
            + (.bySeverity[] | "  - \(.severity): \(.count)\n")
          end
        )
      + (
          if (.topFunctions | length) == 0 then "- topFunctions: none\n"
          else
            "- topFunctions:\n"
            + (.topFunctions[] | "  - \(.name): \(.count)\n")
          end
        )
      + (
          if (.sampleTraces | length) == 0 then "- sampleTraces: none\n"
          else
            "- sampleTraces:\n"
            + (.sampleTraces[] | "  - `\(.)`\n")
          end
        )
    '
    echo
    echo "## $(txt "Top log entries" "Top log entries")"
    echo
    echo "| timestamp | severity | source | message |"
    echo "|---|---|---|---|"
    echo "$entries_json" | jq -r '
      .[0:20][] |
      "| \(.timestamp // "") | \(.severity // "DEFAULT") | \(.resource.labels.function_name // .resource.labels.service_name // .logName // "") | " +
      (
        (
          .textPayload
          // .jsonPayload.message
          // .jsonPayload.error
          // .protoPayload.status.message
          // ""
        )
        | gsub("[\\n\\r\\t]+"; " ")
        | .[0:180]
      ) + " |"
    '
  } > "$out_path"
  echo "$(txt "Đã export report Markdown:" "Exported Markdown report:") $out_path"
}

record_query_history() {
  local action_tag="$1"
  local title="$2"
  local filter="$3"
  local summary_json="$4"
  local history_filter="$filter"
  local history_uid="$LOG_UID"
  local history_phone="$LOG_PHONE"
  local history_member_id="$LOG_MEMBER_ID"
  local history_txn_id="$LOG_TXN_ID"

  if is_truthy "$HISTORY_REDACT_SENSITIVE"; then
    history_filter='[REDACTED_SENSITIVE_FILTER]'
    history_uid="$(sanitize_history_sensitive_value "$LOG_UID")"
    history_phone="$(sanitize_history_sensitive_value "$LOG_PHONE")"
    history_member_id="$(sanitize_history_sensitive_value "$LOG_MEMBER_ID")"
    history_txn_id="$(sanitize_history_sensitive_value "$LOG_TXN_ID")"
  fi

  local record
  record="$(jq -cn \
    --arg timestamp "$(date -u +%FT%TZ)" \
    --arg projectId "$PROJECT_ID" \
    --arg lang "$APP_LANG" \
    --arg action "$action_tag" \
    --arg title "$title" \
    --arg filter "$history_filter" \
    --arg contains "$LOG_CONTAINS" \
    --arg function "$LOG_FUNCTION" \
    --arg trace "$LOG_TRACE" \
    --arg uid "$history_uid" \
    --arg phone "$history_phone" \
    --arg memberId "$history_member_id" \
    --arg txnId "$history_txn_id" \
    --arg preset "$LOG_PRESET" \
    --arg exportPath "$EXPORT_PATH" \
    --argjson sinceMinutes "$LOG_SINCE_MINUTES" \
    --argjson limit "$LOG_LIMIT" \
    --arg severity "$LOG_SEVERITY" \
    --argjson outputJson "$LOG_OUTPUT_JSON" \
    --argjson summary "$summary_json" \
    '{
      timestamp: $timestamp,
      projectId: $projectId,
      language: $lang,
      action: $action,
      title: $title,
      filter: $filter,
      params: {
        preset: $preset,
        sinceMinutes: $sinceMinutes,
        limit: $limit,
        severity: $severity,
        contains: $contains,
        function: $function,
        trace: $trace,
        uid: $uid,
        phone: $phone,
        memberId: $memberId,
        txnId: $txnId,
        outputJson: ($outputJson == 1),
        exportPath: $exportPath
      },
      summary: $summary
    }'
  )"

  local lock_dir="${HISTORY_FILE}.lock"
  local wait_count=0
  while ! mkdir "$lock_dir" >/dev/null 2>&1; do
    wait_count=$((wait_count + 1))
    if [[ "$wait_count" -gt 200 ]]; then
      echo "$(txt "Không lấy được lock history để ghi log query." "Could not acquire history lock to write query record.")" >&2
      return 1
    fi
    sleep 0.05
  done
  trap 'rmdir "$lock_dir" >/dev/null 2>&1 || true' RETURN

  echo "$record" > "$LAST_QUERY_FILE"
  echo "$record" >> "$HISTORY_FILE"
  rmdir "$lock_dir" >/dev/null 2>&1 || true
  trap - RETURN
}

load_last_query_defaults() {
  if [[ ! -f "$LAST_QUERY_FILE" ]]; then
    echo "$(txt "Chưa có lịch sử query để rerun." "No query history found to rerun.")" >&2
    exit 1
  fi
  local last
  last="$(cat "$LAST_QUERY_FILE")"

  if [[ -z "$PROJECT_ID" ]]; then
    PROJECT_ID="$(echo "$last" | jq -r '.projectId // ""')"
  fi
  if [[ -z "$NON_INTERACTIVE_ACTION" ]]; then
    NON_INTERACTIVE_ACTION="$(echo "$last" | jq -r '.action // ""')"
  fi
  if [[ "$LOG_SINCE_MINUTES" == "$DEFAULT_LOG_SINCE_MINUTES" ]]; then
    LOG_SINCE_MINUTES="$(echo "$last" | jq -r '.params.sinceMinutes // 60')"
  fi
  if [[ "$LOG_LIMIT" == "$DEFAULT_LOG_LIMIT" ]]; then
    LOG_LIMIT="$(echo "$last" | jq -r '.params.limit // 100')"
  fi
  if [[ "$LOG_SEVERITY" == "$DEFAULT_LOG_SEVERITY" ]]; then
    LOG_SEVERITY="$(echo "$last" | jq -r '.params.severity // "ERROR"')"
  fi
  if [[ -z "$LOG_CONTAINS" ]]; then
    LOG_CONTAINS="$(echo "$last" | jq -r '.params.contains // ""')"
  fi
  if [[ -z "$LOG_FUNCTION" ]]; then
    LOG_FUNCTION="$(echo "$last" | jq -r '.params.function // ""')"
  fi
  if [[ -z "$LOG_TRACE" ]]; then
    LOG_TRACE="$(echo "$last" | jq -r '.params.trace // ""')"
  fi
  if [[ -z "$LOG_UID" ]]; then
    LOG_UID="$(restore_history_sensitive_value "$(echo "$last" | jq -r '.params.uid // ""')")"
  fi
  if [[ -z "$LOG_PHONE" ]]; then
    LOG_PHONE="$(restore_history_sensitive_value "$(echo "$last" | jq -r '.params.phone // ""')")"
  fi
  if [[ -z "$LOG_MEMBER_ID" ]]; then
    LOG_MEMBER_ID="$(restore_history_sensitive_value "$(echo "$last" | jq -r '.params.memberId // ""')")"
  fi
  if [[ -z "$LOG_TXN_ID" ]]; then
    LOG_TXN_ID="$(restore_history_sensitive_value "$(echo "$last" | jq -r '.params.txnId // ""')")"
  fi
  if [[ -z "$LOG_PRESET" ]]; then
    LOG_PRESET="$(echo "$last" | jq -r '.params.preset // ""')"
  fi
  if [[ -z "$EXPORT_PATH" ]]; then
    EXPORT_PATH="$(echo "$last" | jq -r '.params.exportPath // ""')"
  fi
  if [[ "$LOG_OUTPUT_JSON" -eq 0 ]]; then
    local last_json
    last_json="$(echo "$last" | jq -r '.params.outputJson // false')"
    [[ "$last_json" == "true" ]] && LOG_OUTPUT_JSON=1
  fi
  case "$NON_INTERACTIVE_ACTION" in
    triage-*)
      NON_INTERACTIVE_ACTION="triage"
      ;;
    interactive|"")
      if [[ -n "$LOG_TRACE" ]]; then
        NON_INTERACTIVE_ACTION="logs-trace"
      elif [[ -n "$LOG_CONTAINS" ]]; then
        NON_INTERACTIVE_ACTION="logs-search"
      else
        NON_INTERACTIVE_ACTION="logs-errors"
      fi
      ;;
  esac
}

show_history() {
  ensure_history_store
  print_header "$(txt "Lịch sử query gần đây (10 bản ghi)" "Recent query history (last 10)")"
  if [[ ! -s "$HISTORY_FILE" ]]; then
    echo "$(txt "Chưa có lịch sử query." "No query history yet.")"
    return
  fi
  jq -s -r '
    if length == 0 then
      "No query history yet."
    else
      .[-10:][] | "\(.timestamp)\t\(.action)\t\(.title)\tproject=\(.projectId)\ttotal=\(.summary.total // 0)"
    end
  ' "$HISTORY_FILE"
}

apply_preset() {
  local preset="$1"
  LOG_PRESET="$preset"
  case "$preset" in
    payment-fail)
      [[ "$LOG_SINCE_MINUTES" == "$DEFAULT_LOG_SINCE_MINUTES" ]] && LOG_SINCE_MINUTES=180
      [[ "$LOG_SEVERITY" == "$DEFAULT_LOG_SEVERITY" ]] && LOG_SEVERITY="ERROR"
      [[ -z "$LOG_CONTAINS" ]] && LOG_CONTAINS="billing"
      ;;
    push-fail)
      [[ "$LOG_SINCE_MINUTES" == "$DEFAULT_LOG_SINCE_MINUTES" ]] && LOG_SINCE_MINUTES=120
      [[ "$LOG_SEVERITY" == "$DEFAULT_LOG_SEVERITY" ]] && LOG_SEVERITY="ERROR"
      [[ -z "$LOG_CONTAINS" ]] && LOG_CONTAINS="push"
      [[ -z "$LOG_FUNCTION" ]] && LOG_FUNCTION="sendPush"
      ;;
    auth-fail)
      [[ "$LOG_SINCE_MINUTES" == "$DEFAULT_LOG_SINCE_MINUTES" ]] && LOG_SINCE_MINUTES=120
      [[ "$LOG_SEVERITY" == "$DEFAULT_LOG_SEVERITY" ]] && LOG_SEVERITY="WARNING"
      [[ -z "$LOG_CONTAINS" ]] && LOG_CONTAINS="auth"
      ;;
    "")
      ;;
    *)
      echo "$(txt "Preset không hợp lệ:" "Invalid preset:") $preset" >&2
      echo "$(txt "Hỗ trợ: payment-fail | push-fail | auth-fail" "Supported presets: payment-fail | push-fail | auth-fail")" >&2
      exit 1
      ;;
  esac
}

query_logs() {
  local title="$1"
  local since_minutes="$2"
  local severity="$3"
  local contains="$4"
  local function_name="$5"
  local trace_id="$6"
  local page_size="$7"
  local as_json="${8:-0}"
  local action_tag="${9:-interactive}"

  if ! is_positive_int "$since_minutes"; then
    echo "$(txt "since-minutes phải là số nguyên dương." "since-minutes must be a positive integer.")" >&2
    return 1
  fi
  if ! is_positive_int "$page_size"; then
    echo "$(txt "limit phải là số nguyên dương." "limit must be a positive integer.")" >&2
    return 1
  fi

  severity="$(normalize_severity "$severity")"
  local filter
  filter="$(build_log_filter "$since_minutes" "$severity" "$contains" "$function_name" "$trace_id" "$LOG_UID" "$LOG_PHONE" "$LOG_MEMBER_ID" "$LOG_TXN_ID")"

  local entries_json
  entries_json="$(logging_query_entries "$filter" "$page_size")"
  local summary_json
  summary_json="$(build_summary_json "$entries_json")"

  record_query_history "$action_tag" "$title" "$filter" "$summary_json"

  if [[ "$as_json" -eq 1 ]]; then
    echo "$entries_json" | jq '.'
  else
    print_header "$title"
    echo "sinceMinutes: $since_minutes"
    echo "severity>=: $severity"
    [[ -n "$function_name" ]] && echo "function: $function_name"
    [[ -n "$contains" ]] && echo "contains: $contains"
    [[ -n "$trace_id" ]] && echo "trace: $trace_id"
    [[ -n "$LOG_UID" ]] && echo "uid: $LOG_UID"
    [[ -n "$LOG_PHONE" ]] && echo "phone: $LOG_PHONE"
    [[ -n "$LOG_MEMBER_ID" ]] && echo "memberId: $LOG_MEMBER_ID"
    [[ -n "$LOG_TXN_ID" ]] && echo "txnId: $LOG_TXN_ID"
    [[ -n "$LOG_PRESET" ]] && echo "preset: $LOG_PRESET"
    echo "limit: $page_size"
    echo "filter: $filter"
    render_log_entries_pretty "$entries_json" "$contains"
    suggest_next_steps "$entries_json" "$contains"
  fi

  local resolved_export
  resolved_export="$(resolve_export_path "$title" "$action_tag")"
  export_query_report "$resolved_export" "$title" "$filter" "$entries_json" "$summary_json" "$action_tag"
}

prompt_with_default() {
  local label="$1"
  local default_value="$2"
  local value=""
  read -r -p "$label [$default_value]: " value
  if [[ -z "$value" ]]; then
    printf '%s' "$default_value"
  else
    printf '%s' "$value"
  fi
}

prompt_optional_with_default() {
  local label="$1"
  local default_value="$2"
  local value=""
  if [[ -n "$default_value" ]]; then
    read -r -p "$label [$default_value]: " value
    if [[ -z "$value" ]]; then
      printf '%s' "$default_value"
    else
      printf '%s' "$value"
    fi
    return
  fi
  read -r -p "$label: " value
  printf '%s' "$value"
}

prompt_business_filters() {
  echo
  echo "$(txt "Bộ lọc business (để trống nếu không dùng):" "Business filters (leave blank to skip):")"
  LOG_UID="$(prompt_optional_with_default "uid" "$LOG_UID")"
  LOG_PHONE="$(prompt_optional_with_default "phone" "$LOG_PHONE")"
  LOG_MEMBER_ID="$(prompt_optional_with_default "memberId" "$LOG_MEMBER_ID")"
  LOG_TXN_ID="$(prompt_optional_with_default "txnId" "$LOG_TXN_ID")"
}

fetch_projects() {
  firebase projects:list --json | jq -r '.result[] | "\(.projectId)\t\(.displayName // .projectId)"'
}

select_project() {
  local lines=()
  local fetched_line=""
  while IFS= read -r fetched_line; do
    lines+=("$fetched_line")
  done < <(fetch_projects)
  if [[ "${#lines[@]}" -eq 0 ]]; then
    echo "$(txt "Không thấy project nào từ Firebase CLI." "No projects found from Firebase CLI.")" >&2
    exit 1
  fi

  local options=()
  local line
  for line in "${lines[@]}"; do
    local pid="${line%%$'\t'*}"
    local pname="${line#*$'\t'}"
    options+=("$pid ($pname)")
  done

  if [[ -n "$PROJECT_ID" ]]; then
    local matched=""
    for line in "${lines[@]}"; do
      local pid="${line%%$'\t'*}"
      if [[ "$pid" == "$PROJECT_ID" ]]; then
        matched="$line"
        break
      fi
    done
    if [[ -n "$matched" ]]; then
      local pname="${matched#*$'\t'}"
      echo "$(txt "Dùng project preset:" "Using preset project:") $PROJECT_ID ($pname)"
      return
    fi
  fi

  echo
  echo "$(txt "Chọn Firebase project:" "Select Firebase project:")"
  select choice in "${options[@]}"; do
    if [[ -n "${choice:-}" ]]; then
      PROJECT_ID="${choice%% *}"
      echo "$(txt "Đã chọn project:" "Selected project:") $PROJECT_ID"
      break
    fi
    echo "$(txt "Lựa chọn không hợp lệ, chọn lại." "Invalid selection, try again.")"
  done
}

firestore_collection_url() {
  local path="$1"
  local page_size="${2:-100}"
  printf 'https://firestore.googleapis.com/v1/projects/%s/databases/(default)/documents/%s?pageSize=%s' "$PROJECT_ID" "$path" "$page_size"
}

firestore_get_collection() {
  local path="$1"
  local page_size="${2:-100}"
  local url
  url="$(firestore_collection_url "$path" "$page_size")"
  curl -sS -H "Authorization: Bearer $ACCESS_TOKEN" "$url"
}

firestore_run_query() {
  local json_payload="$1"
  local url="https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents:runQuery"
  curl -sS \
    -H "Authorization: Bearer $ACCESS_TOKEN" \
    -H "Content-Type: application/json" \
    -X POST "$url" \
    --data "$json_payload"
}

print_header() {
  local title="$1"
  echo
  echo "============================================================"
  echo "$title"
  echo "Project: $PROJECT_ID"
  echo "============================================================"
}

show_users_summary() {
  print_header "Users summary (top 200)"
  firestore_get_collection "users" 200 | jq -r '
    (.documents // [])
    | map({
        uid: (.fields.uid.stringValue // ""),
        primaryRole: (.fields.primaryRole.stringValue // ""),
        accessMode: (.fields.accessMode.stringValue // ""),
        clanId: (.fields.clanId.stringValue // ""),
        memberId: (.fields.memberId.stringValue // ""),
        updatedAt: (.fields.updatedAt.timestampValue // "")
      })
    | if length == 0 then
        "Không có dữ liệu users."
      else
        ("total: \(length)") ,
        ("uid\trole\taccess\tclanId\tmemberId\tupdatedAt"),
        (.[] | "\(.uid)\t\(.primaryRole)\t\(.accessMode)\t\(.clanId)\t\(.memberId)\t\(.updatedAt)")
      end
  '
}

show_auth_phone_users() {
  print_header "Firebase Auth users có phoneNumber"
  local tmp
  tmp="$(mktemp /tmp/firebase-auth-users-XXXXXX.json)"
  firebase auth:export "$tmp" --format=json --project "$PROJECT_ID" >/dev/null
  jq -r '
    [.users[] | select(.phoneNumber != null)]
    | if length == 0 then
        "Không có user nào có phoneNumber."
      else
        ("total: \(length)"),
        ("uid\tphone\tlastSignedInAt\tcreatedAt"),
        (.[] | "\(.localId // "")\t\(.phoneNumber // "")\t\(.lastSignedInAt // "")\t\(.createdAt // "")")
      end
  ' "$tmp"
  rm -f "$tmp"
}

show_device_tokens() {
  print_header "Device tokens (collection-group: deviceTokens, top 500)"
  local payload
  payload='{
    "structuredQuery": {
      "from": [{"collectionId": "deviceTokens", "allDescendants": true}],
      "orderBy": [{"field": {"fieldPath": "updatedAt"}, "direction": "DESCENDING"}],
      "limit": 500
    }
  }'
  firestore_run_query "$payload" | jq -r '
    [.[] | select(.document != null) | .document]
    | map({
        uid: (.fields.uid.stringValue // ""),
        platform: (.fields.platform.stringValue // ""),
        accessMode: (.fields.accessMode.stringValue // ""),
        token: (.fields.token.stringValue // ""),
        updatedAt: (.fields.updatedAt.timestampValue // "")
      })
    | if length == 0 then
        "Không có device token nào."
      else
        ("total: \(length)"),
        ("uid\tplatform\taccessMode\ttokenPrefix\tupdatedAt"),
        (.[] | "\(.uid)\t\(.platform)\t\(.accessMode)\t\(.token[0:18])...\t\(.updatedAt)")
      end
  '
}

show_subscriptions() {
  print_header "Billing subscriptions (top 200)"
  firestore_get_collection "billing_subscriptions" 200 | jq -r '
    (.documents // [])
    | map({
        id: (.name | split("/") | last),
        ownerUid: (.fields.ownerUid.stringValue // ""),
        planCode: (.fields.planCode.stringValue // ""),
        status: (.fields.status.stringValue // ""),
        validUntil: (.fields.currentPeriodEnd.timestampValue // ""),
        updatedAt: (.fields.updatedAt.timestampValue // "")
      })
    | if length == 0 then
        "Không có dữ liệu billing_subscriptions."
      else
        ("total: \(length)"),
        ("id\townerUid\tplanCode\tstatus\tvalidUntil\tupdatedAt"),
        (.[] | "\(.id)\t\(.ownerUid)\t\(.planCode)\t\(.status)\t\(.validUntil)\t\(.updatedAt)")
      end
  '
}

show_pending_transactions() {
  print_header "Billing transactions đang pending/processing"
  local payload
  payload='{
    "structuredQuery": {
      "from": [{"collectionId": "billing_transactions"}],
      "orderBy": [{"field": {"fieldPath": "createdAt"}, "direction": "DESCENDING"}],
      "limit": 300
    }
  }'
  firestore_run_query "$payload" | jq -r '
    [.[] | select(.document != null) | .document]
    | map({
        id: (.name | split("/") | last),
        ownerUid: (.fields.ownerUid.stringValue // ""),
        paymentProvider: (.fields.paymentProvider.stringValue // ""),
        planCode: (.fields.planCode.stringValue // ""),
        status: (.fields.status.stringValue // ""),
        amountVnd: (.fields.amountVnd.integerValue // .fields.amountVnd.doubleValue // ""),
        createdAt: (.fields.createdAt.timestampValue // "")
      })
    | map(select(.status == "pending" or .status == "processing"))
    | if length == 0 then
        "Không có transaction pending/processing."
      else
        ("total: \(length)"),
        ("id\townerUid\tprovider\tplan\tstatus\tamountVnd\tcreatedAt"),
        (.[] | "\(.id)\t\(.ownerUid)\t\(.paymentProvider)\t\(.planCode)\t\(.status)\t\(.amountVnd)\t\(.createdAt)")
      end
  '
}

show_latest_transactions() {
  print_header "Billing transactions mới nhất (top 100)"
  local payload
  payload='{
    "structuredQuery": {
      "from": [{"collectionId": "billing_transactions"}],
      "orderBy": [{"field": {"fieldPath": "createdAt"}, "direction": "DESCENDING"}],
      "limit": 100
    }
  }'
  firestore_run_query "$payload" | jq -r '
    [.[] | select(.document != null) | .document]
    | map({
        id: (.name | split("/") | last),
        ownerUid: (.fields.ownerUid.stringValue // ""),
        paymentProvider: (.fields.paymentProvider.stringValue // ""),
        planCode: (.fields.planCode.stringValue // ""),
        status: (.fields.status.stringValue // ""),
        amountVnd: (.fields.amountVnd.integerValue // .fields.amountVnd.doubleValue // ""),
        createdAt: (.fields.createdAt.timestampValue // "")
      })
    | if length == 0 then
        "Không có transaction."
      else
        ("total: \(length)"),
        ("id\townerUid\tprovider\tplan\tstatus\tamountVnd\tcreatedAt"),
        (.[] | "\(.id)\t\(.ownerUid)\t\(.paymentProvider)\t\(.planCode)\t\(.status)\t\(.amountVnd)\t\(.createdAt)")
      end
  '
}

show_clans() {
  print_header "Danh sách clans (top 200)"
  firestore_get_collection "clans" 200 | jq -r '
    (.documents // [])
    | map({
        id: (.name | split("/") | last),
        name: (.fields.name.stringValue // .fields.displayName.stringValue // "(no-name)"),
        ownerUid: (.fields.ownerUid.stringValue // ""),
        updatedAt: (.fields.updatedAt.timestampValue // "")
      })
    | if length == 0 then
        "Không có clan nào."
      else
        ("total: \(length)"),
        ("id\tname\townerUid\tupdatedAt"),
        (.[] | "\(.id)\t\(.name)\t\(.ownerUid)\t\(.updatedAt)")
      end
  '
}

show_members_for_selected_clan() {
  print_header "Chọn clan để xem members"

  local raw
  raw="$(firestore_get_collection "clans" 200)"
  local clans=()
  local clan_line=""
  while IFS= read -r clan_line; do
    clans+=("$clan_line")
  done < <(echo "$raw" | jq -r '(.documents // [])[] | "\(.name | split("/") | last)\t\(.fields.name.stringValue // .fields.displayName.stringValue // "(no-name)")"')

  if [[ "${#clans[@]}" -eq 0 ]]; then
    echo "Không có clan để chọn."
    return
  fi

  local options=()
  local line
  for line in "${clans[@]}"; do
    local id="${line%%$'\t'*}"
    local cname="${line#*$'\t'}"
    options+=("$id - $cname")
  done

  local selected=""
  select selected in "${options[@]}"; do
    if [[ -n "${selected:-}" ]]; then
      break
    fi
    echo "Lựa chọn không hợp lệ, chọn lại."
  done

  local clan_id="${selected%% *}"

  local payload
  payload="$(cat <<JSON
{
  \"structuredQuery\": {
    \"from\": [{\"collectionId\": \"members\"}],
    \"where\": {
      \"fieldFilter\": {
        \"field\": {\"fieldPath\": \"clanId\"},
        \"op\": \"EQUAL\",
        \"value\": {\"stringValue\": \"${clan_id}\"}
      }
    },
    \"orderBy\": [{\"field\": {\"fieldPath\": \"displayName\"}, \"direction\": \"ASCENDING\"}],
    \"limit\": 500
  }
}
JSON
)"

  print_header "Members của clan: $clan_id"
  firestore_run_query "$payload" | jq -r '
    [.[] | select(.document != null) | .document]
    | map({
        id: (.name | split("/") | last),
        displayName: (.fields.displayName.stringValue // .fields.name.stringValue // ""),
        role: (.fields.role.stringValue // ""),
        branchId: (.fields.branchId.stringValue // ""),
        aliveStatus: (.fields.aliveStatus.stringValue // "")
      })
    | if length == 0 then
        "Không có member cho clan này."
      else
        ("total: \(length)"),
        ("id\tdisplayName\trole\tbranchId\taliveStatus"),
        (.[] | "\(.id)\t\(.displayName)\t\(.role)\t\(.branchId)\t\(.aliveStatus)")
      end
  '
}

show_recent_error_logs() {
  local since_minutes
  local limit
  local severity
  local function_name

  since_minutes="$(prompt_with_default "$(txt "Xem log trong bao nhiêu phút gần nhất" "Look back how many minutes")" "$LOG_SINCE_MINUTES")"
  limit="$(prompt_with_default "$(txt "Giới hạn số log trả về" "Maximum logs to return")" "$LOG_LIMIT")"
  severity="$(prompt_with_default "$(txt "Mức severity tối thiểu" "Minimum severity")" "$LOG_SEVERITY")"
  function_name="$(prompt_optional_with_default "$(txt "Lọc theo function name (để trống = tất cả)" "Filter by function name (blank = all)")" "$LOG_FUNCTION")"
  LOG_FUNCTION="$function_name"
  prompt_business_filters

  query_logs "$(txt "Cloud logs lỗi gần đây" "Recent error cloud logs")" "$since_minutes" "$severity" "" "$function_name" "" "$limit" "$LOG_OUTPUT_JSON" "logs-errors"
}

show_logs_by_keyword() {
  local keyword=""
  read -r -p "$(txt "Nhập từ khóa lỗi cần tìm (vd: permission-denied, timeout): " "Enter keyword to search (e.g. permission-denied, timeout): ")" keyword
  if [[ -z "$keyword" ]]; then
    echo "$(txt "Cần nhập từ khóa để query." "A keyword is required.")"
    return
  fi

  local since_minutes
  local limit
  local severity
  local function_name

  since_minutes="$(prompt_with_default "$(txt "Xem log trong bao nhiêu phút gần nhất" "Look back how many minutes")" "$LOG_SINCE_MINUTES")"
  limit="$(prompt_with_default "$(txt "Giới hạn số log trả về" "Maximum logs to return")" "$LOG_LIMIT")"
  severity="$(prompt_with_default "$(txt "Mức severity tối thiểu" "Minimum severity")" "$LOG_SEVERITY")"
  function_name="$(prompt_optional_with_default "$(txt "Lọc theo function name (để trống = tất cả)" "Filter by function name (blank = all)")" "$LOG_FUNCTION")"
  LOG_FUNCTION="$function_name"
  prompt_business_filters

  LOG_CONTAINS="$keyword"
  query_logs "$(txt "Cloud logs theo từ khóa" "Cloud logs by keyword")" "$since_minutes" "$severity" "$keyword" "$function_name" "" "$limit" "$LOG_OUTPUT_JSON" "logs-search"
}

show_logs_by_trace() {
  local trace_id=""
  read -r -p "$(txt "Nhập trace id hoặc request id: " "Enter trace id or request id: ")" trace_id
  if [[ -z "$trace_id" ]]; then
    echo "$(txt "Cần nhập trace/request id để query." "Trace/request id is required.")"
    return
  fi

  local since_minutes
  local limit
  local severity
  local function_name

  since_minutes="$(prompt_with_default "$(txt "Xem log trong bao nhiêu phút gần nhất" "Look back how many minutes")" "$LOG_SINCE_MINUTES")"
  limit="$(prompt_with_default "$(txt "Giới hạn số log trả về" "Maximum logs to return")" "$LOG_LIMIT")"
  severity="$(prompt_with_default "$(txt "Mức severity tối thiểu" "Minimum severity")" "$LOG_SEVERITY")"
  function_name="$(prompt_optional_with_default "$(txt "Lọc theo function name (để trống = tất cả)" "Filter by function name (blank = all)")" "$LOG_FUNCTION")"
  LOG_FUNCTION="$function_name"
  prompt_business_filters

  LOG_TRACE="$trace_id"
  query_logs "$(txt "Cloud logs theo trace/request id" "Cloud logs by trace/request id")" "$since_minutes" "$severity" "" "$function_name" "$trace_id" "$limit" "$LOG_OUTPUT_JSON" "logs-trace"
}

run_triage() {
  local since_minutes="$1"
  local limit="$2"
  local severity="$3"
  local contains="$4"
  local function_name="$5"

  query_logs "$(txt "Triage bước 1: lỗi gần đây" "Triage step 1: recent errors")" \
    "$since_minutes" "$severity" "" "$function_name" "" "$limit" "$LOG_OUTPUT_JSON" "triage-errors"

  if [[ -n "$contains" ]]; then
    query_logs "$(txt "Triage bước 2: lọc theo từ khóa" "Triage step 2: keyword filter")" \
      "$since_minutes" "$severity" "$contains" "$function_name" "" "$limit" "$LOG_OUTPUT_JSON" "triage-keyword"
  fi

  echo
  echo "$(txt "Triage hoàn tất. Nếu đã thấy trace id, chạy tiếp action logs-trace hoặc menu 'Cloud logs theo trace/request id'." "Triage complete. If you found a trace id, continue with logs-trace action or the trace menu option.")"
}

show_quick_triage() {
  local since_minutes
  local limit
  local severity
  local function_name
  local keyword

  since_minutes="$(prompt_with_default "$(txt "Xem log trong bao nhiêu phút gần nhất" "Look back how many minutes")" "$LOG_SINCE_MINUTES")"
  limit="$(prompt_with_default "$(txt "Giới hạn số log trả về" "Maximum logs to return")" "$LOG_LIMIT")"
  severity="$(prompt_with_default "$(txt "Mức severity tối thiểu" "Minimum severity")" "$LOG_SEVERITY")"
  function_name="$(prompt_optional_with_default "$(txt "Lọc theo function name (để trống = tất cả)" "Filter by function name (blank = all)")" "$LOG_FUNCTION")"
  keyword="$(prompt_optional_with_default "$(txt "Từ khóa lỗi (để trống nếu chưa có)" "Keyword (optional)")" "$LOG_CONTAINS")"

  LOG_FUNCTION="$function_name"
  LOG_CONTAINS="$keyword"
  prompt_business_filters
  run_triage "$since_minutes" "$limit" "$severity" "$keyword" "$function_name"
}

show_log_triage_playbook() {
  if [[ "${APP_LANG}" == "en" ]]; then
    print_header "Debug playbook and trade-offs"
    cat <<'PLAYBOOK'
1) Query recent errors first:
   - Use this when an incident just happened and root cause is unclear.
   - Start with "Recent error cloud logs" to collect stack traces and affected functions.
   - Pros: fastest situational awareness.
   - Cons: can be noisy in high traffic.

2) Search by keyword:
   - Use when you have clues (error code, message, uid, txn id).
   - Run "Cloud logs by keyword" to narrow down.
   - Pros: less noise, faster root-cause isolation.
   - Cons: depends on choosing the right keyword.

3) Drill down by trace/request id:
   - Use to reconstruct one request timeline end-to-end.
   - Run "Cloud logs by trace/request id".
   - Pros: most precise debugging path.
   - Cons: requires a trace/request id from step 1 or 2.

Recommended flow:
  recent errors -> keyword/function narrowing -> trace drill-down -> fix -> rerun same query for verification.
PLAYBOOK
    return
  fi

  print_header "Playbook debug khi có lỗi"
  cat <<'PLAYBOOK'
1) Query logs (bước đầu, nhanh):
   - Dùng khi mới nhận lỗi, chưa biết nguyên nhân.
   - Chạy "Cloud logs lỗi gần đây" để lấy stacktrace + function bị lỗi.
   - Ưu điểm: nhanh, nhìn toàn cảnh incident.
   - Nhược điểm: noise cao nếu traffic lớn.

2) Tìm logs theo từ khóa:
   - Dùng khi đã có manh mối (error code, message, user id, endpoint).
   - Chạy "Cloud logs theo từ khóa" để thu hẹp phạm vi.
   - Ưu điểm: giảm nhiễu, nhanh ra root-cause.
   - Nhược điểm: phụ thuộc từ khóa đúng.

3) Tìm theo trace/request id:
   - Dùng khi muốn dựng full timeline một request.
   - Chạy "Cloud logs theo trace/request id".
   - Ưu điểm: chính xác nhất để thấy chuỗi xử lý.
   - Nhược điểm: cần có trace/request id từ bước 1/2.

Luồng khuyến nghị:
  Query logs lỗi gần đây -> lọc theo keyword/function -> drill-down bằng trace id -> fix -> query lại để verify.
PLAYBOOK
}

run_non_interactive_action() {
  case "$NON_INTERACTIVE_ACTION" in
    logs-errors)
      query_logs \
        "$(txt "Cloud logs lỗi gần đây (non-interactive)" "Recent error cloud logs (non-interactive)")" \
        "$LOG_SINCE_MINUTES" \
        "$LOG_SEVERITY" \
        "" \
        "$LOG_FUNCTION" \
        "" \
        "$LOG_LIMIT" \
        "$LOG_OUTPUT_JSON" \
        "logs-errors"
      ;;
    logs-search)
      if [[ -z "$LOG_CONTAINS" ]]; then
        echo "$(txt "--action logs-search yêu cầu --contains '<keyword>'" "--action logs-search requires --contains '<keyword>'")" >&2
        exit 1
      fi
      query_logs \
        "$(txt "Cloud logs theo từ khóa (non-interactive)" "Cloud logs by keyword (non-interactive)")" \
        "$LOG_SINCE_MINUTES" \
        "$LOG_SEVERITY" \
        "$LOG_CONTAINS" \
        "$LOG_FUNCTION" \
        "" \
        "$LOG_LIMIT" \
        "$LOG_OUTPUT_JSON" \
        "logs-search"
      ;;
    logs-trace)
      if [[ -z "$LOG_TRACE" ]]; then
        echo "$(txt "--action logs-trace yêu cầu --trace '<trace-id|request-id>'" "--action logs-trace requires --trace '<trace-id|request-id>'")" >&2
        exit 1
      fi
      query_logs \
        "$(txt "Cloud logs theo trace/request id (non-interactive)" "Cloud logs by trace/request id (non-interactive)")" \
        "$LOG_SINCE_MINUTES" \
        "$LOG_SEVERITY" \
        "" \
        "$LOG_FUNCTION" \
        "$LOG_TRACE" \
        "$LOG_LIMIT" \
        "$LOG_OUTPUT_JSON" \
        "logs-trace"
      ;;
    triage)
      run_triage \
        "$LOG_SINCE_MINUTES" \
        "$LOG_LIMIT" \
        "$LOG_SEVERITY" \
        "$LOG_CONTAINS" \
        "$LOG_FUNCTION"
      ;;
    *)
      echo "$(txt "Action không hợp lệ:" "Invalid action:") $NON_INTERACTIVE_ACTION" >&2
      echo "$(txt "Hỗ trợ: logs-errors, logs-search, logs-trace, triage" "Supported: logs-errors, logs-search, logs-trace, triage")" >&2
      exit 1
      ;;
  esac
}

show_active_log_context() {
  print_header "$(txt "Bộ lọc log hiện tại" "Current log filter context")"
  echo "preset: ${LOG_PRESET:-none}"
  echo "sinceMinutes: $LOG_SINCE_MINUTES"
  echo "limit: $LOG_LIMIT"
  echo "severity>=: $LOG_SEVERITY"
  [[ -n "$LOG_CONTAINS" ]] && echo "contains: $LOG_CONTAINS"
  [[ -n "$LOG_FUNCTION" ]] && echo "function: $LOG_FUNCTION"
  [[ -n "$LOG_TRACE" ]] && echo "trace: $LOG_TRACE"
  [[ -n "$LOG_UID" ]] && echo "uid: $LOG_UID"
  [[ -n "$LOG_PHONE" ]] && echo "phone: $LOG_PHONE"
  [[ -n "$LOG_MEMBER_ID" ]] && echo "memberId: $LOG_MEMBER_ID"
  [[ -n "$LOG_TXN_ID" ]] && echo "txnId: $LOG_TXN_ID"
  [[ -n "$EXPORT_PATH" ]] && echo "export: $EXPORT_PATH"
}

select_log_preset_menu() {
  local options=("payment-fail" "push-fail" "auth-fail" "none")
  echo
  echo "$(txt "Chọn preset debug:" "Choose debug preset:")"
  select preset in "${options[@]}"; do
    case "$preset" in
      payment-fail|push-fail|auth-fail)
        LOG_PRESET=""
        LOG_CONTAINS=""
        LOG_FUNCTION=""
        LOG_TRACE=""
        LOG_UID=""
        LOG_PHONE=""
        LOG_MEMBER_ID=""
        LOG_TXN_ID=""
        LOG_SINCE_MINUTES="$DEFAULT_LOG_SINCE_MINUTES"
        LOG_LIMIT="$DEFAULT_LOG_LIMIT"
        LOG_SEVERITY="$DEFAULT_LOG_SEVERITY"
        apply_preset "$preset"
        echo "$(txt "Đã áp dụng preset:" "Applied preset:") $preset"
        break
        ;;
      none)
        LOG_PRESET=""
        echo "$(txt "Đã bỏ preset, giữ các filter hiện tại." "Preset cleared, keeping current filters.")"
        break
        ;;
      *)
        echo "$(txt "Lựa chọn không hợp lệ, chọn lại." "Invalid selection, try again.")"
        ;;
    esac
  done
}

show_menu() {
  echo
  echo "================ Firebase Query Console ================"
  echo "Current project: $PROJECT_ID"
  echo "Lang: $APP_LANG | Preset: ${LOG_PRESET:-none}"
  echo "========================================================"

  local opt_users opt_auth opt_tokens opt_subs opt_pending opt_latest
  local opt_clans opt_members opt_logs_recent opt_logs_keyword opt_logs_trace
  local opt_triage opt_playbook opt_history opt_rerun opt_preset opt_context
  local opt_change_project opt_exit

  opt_users="$(txt "Users summary" "Users summary")"
  opt_auth="$(txt "Auth users có số điện thoại" "Auth users with phone")"
  opt_tokens="$(txt "Device tokens" "Device tokens")"
  opt_subs="$(txt "Billing subscriptions" "Billing subscriptions")"
  opt_pending="$(txt "Billing pending transactions" "Billing pending transactions")"
  opt_latest="$(txt "Billing latest transactions" "Billing latest transactions")"
  opt_clans="$(txt "Danh sách clans" "List clans")"
  opt_members="$(txt "Members theo clan" "Members by clan")"
  opt_logs_recent="$(txt "Cloud logs lỗi gần đây" "Recent error cloud logs")"
  opt_logs_keyword="$(txt "Cloud logs theo từ khóa" "Cloud logs by keyword")"
  opt_logs_trace="$(txt "Cloud logs theo trace/request id" "Cloud logs by trace/request id")"
  opt_triage="$(txt "Quick triage lỗi (guided)" "Quick incident triage (guided)")"
  opt_playbook="$(txt "Playbook debug trade-off" "Debug trade-off playbook")"
  opt_history="$(txt "Lịch sử query gần đây" "Recent query history")"
  opt_rerun="$(txt "Chạy lại query gần nhất" "Rerun last query")"
  opt_preset="$(txt "Chọn preset debug" "Choose debug preset")"
  opt_context="$(txt "Xem bộ lọc log hiện tại" "Show current log filters")"
  opt_change_project="$(txt "Đổi project" "Change project")"
  opt_exit="$(txt "Thoát" "Exit")"

  local options=(
    "$opt_users"
    "$opt_auth"
    "$opt_tokens"
    "$opt_subs"
    "$opt_pending"
    "$opt_latest"
    "$opt_clans"
    "$opt_members"
    "$opt_logs_recent"
    "$opt_logs_keyword"
    "$opt_logs_trace"
    "$opt_triage"
    "$opt_playbook"
    "$opt_history"
    "$opt_rerun"
    "$opt_preset"
    "$opt_context"
    "$opt_change_project"
    "$opt_exit"
  )

  select opt in "${options[@]}"; do
    case "$opt" in
      "$opt_users")
        show_users_summary
        break
        ;;
      "$opt_auth")
        show_auth_phone_users
        break
        ;;
      "$opt_tokens")
        show_device_tokens
        break
        ;;
      "$opt_subs")
        show_subscriptions
        break
        ;;
      "$opt_pending")
        show_pending_transactions
        break
        ;;
      "$opt_latest")
        show_latest_transactions
        break
        ;;
      "$opt_clans")
        show_clans
        break
        ;;
      "$opt_members")
        show_members_for_selected_clan
        break
        ;;
      "$opt_logs_recent")
        show_recent_error_logs
        break
        ;;
      "$opt_logs_keyword")
        show_logs_by_keyword
        break
        ;;
      "$opt_logs_trace")
        show_logs_by_trace
        break
        ;;
      "$opt_triage")
        show_quick_triage
        break
        ;;
      "$opt_playbook")
        show_log_triage_playbook
        break
        ;;
      "$opt_history")
        show_history
        break
        ;;
      "$opt_rerun")
        NON_INTERACTIVE_ACTION=""
        load_last_query_defaults
        if [[ -z "$NON_INTERACTIVE_ACTION" ]]; then
          echo "$(txt "Không tìm thấy action trong lịch sử gần nhất." "No action found in last query history.")"
        else
          run_non_interactive_action
        fi
        break
        ;;
      "$opt_preset")
        select_log_preset_menu
        break
        ;;
      "$opt_context")
        show_active_log_context
        break
        ;;
      "$opt_change_project")
        PROJECT_ID=""
        select_project
        break
        ;;
      "$opt_exit")
        echo "Bye."
        exit 0
        ;;
      *)
        echo "$(txt "Lựa chọn không hợp lệ, chọn lại." "Invalid selection, try again.")"
        ;;
    esac
  done
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)
        usage
        exit 0
        ;;
      --project)
        if [[ -z "${2:-}" ]]; then
          echo "$(txt "--project cần giá trị project id." "--project requires a project id.")" >&2
          exit 1
        fi
        PROJECT_ID="${2:-}"
        shift 2
        ;;
      --action)
        if [[ -z "${2:-}" ]]; then
          echo "$(txt "--action cần giá trị." "--action requires a value.")" >&2
          exit 1
        fi
        NON_INTERACTIVE_ACTION="${2:-}"
        shift 2
        ;;
      --preset)
        if [[ -z "${2:-}" ]]; then
          echo "$(txt "--preset cần giá trị." "--preset requires a value.")" >&2
          exit 1
        fi
        apply_preset "${2:-}"
        shift 2
        ;;
      --since-minutes)
        if [[ -z "${2:-}" ]]; then
          echo "$(txt "--since-minutes cần giá trị." "--since-minutes requires a value.")" >&2
          exit 1
        fi
        LOG_SINCE_MINUTES="${2:-}"
        shift 2
        ;;
      --limit)
        if [[ -z "${2:-}" ]]; then
          echo "$(txt "--limit cần giá trị." "--limit requires a value.")" >&2
          exit 1
        fi
        LOG_LIMIT="${2:-}"
        shift 2
        ;;
      --severity)
        if [[ -z "${2:-}" ]]; then
          echo "$(txt "--severity cần giá trị." "--severity requires a value.")" >&2
          exit 1
        fi
        LOG_SEVERITY="${2:-}"
        shift 2
        ;;
      --contains)
        if [[ -z "${2:-}" ]]; then
          echo "$(txt "--contains cần giá trị." "--contains requires a value.")" >&2
          exit 1
        fi
        LOG_CONTAINS="${2:-}"
        shift 2
        ;;
      --function)
        if [[ -z "${2:-}" ]]; then
          echo "$(txt "--function cần giá trị." "--function requires a value.")" >&2
          exit 1
        fi
        LOG_FUNCTION="${2:-}"
        shift 2
        ;;
      --trace)
        if [[ -z "${2:-}" ]]; then
          echo "$(txt "--trace cần giá trị." "--trace requires a value.")" >&2
          exit 1
        fi
        LOG_TRACE="${2:-}"
        shift 2
        ;;
      --uid)
        if [[ -z "${2:-}" ]]; then
          echo "$(txt "--uid cần giá trị." "--uid requires a value.")" >&2
          exit 1
        fi
        LOG_UID="${2:-}"
        shift 2
        ;;
      --phone)
        if [[ -z "${2:-}" ]]; then
          echo "$(txt "--phone cần giá trị." "--phone requires a value.")" >&2
          exit 1
        fi
        LOG_PHONE="${2:-}"
        shift 2
        ;;
      --member-id)
        if [[ -z "${2:-}" ]]; then
          echo "$(txt "--member-id cần giá trị." "--member-id requires a value.")" >&2
          exit 1
        fi
        LOG_MEMBER_ID="${2:-}"
        shift 2
        ;;
      --txn-id)
        if [[ -z "${2:-}" ]]; then
          echo "$(txt "--txn-id cần giá trị." "--txn-id requires a value.")" >&2
          exit 1
        fi
        LOG_TXN_ID="${2:-}"
        shift 2
        ;;
      --export)
        if [[ -z "${2:-}" ]]; then
          echo "$(txt "--export cần giá trị." "--export requires a value.")" >&2
          exit 1
        fi
        EXPORT_PATH="${2:-}"
        shift 2
        ;;
      --lang)
        if [[ -z "${2:-}" ]]; then
          echo "$(txt "--lang cần giá trị." "--lang requires a value.")" >&2
          exit 1
        fi
        APP_LANG="${2:-}"
        shift 2
        ;;
      --rerun-last)
        RERUN_LAST=1
        shift
        ;;
      --json)
        LOG_OUTPUT_JSON=1
        shift
        ;;
      *)
        echo "$(txt "Tham số không hỗ trợ:" "Unsupported argument:") $1" >&2
        usage
        exit 1
        ;;
    esac
  done
}

usage() {
  cat <<USAGE
$SCRIPT_NAME

$(txt "Script query Firebase/Firestore bằng menu chọn số." "Firebase/Firestore query console with guided menu.")
$(txt "Không cần gõ câu lệnh query thủ công." "No manual query syntax needed.")

$(txt "Cách dùng:" "Usage:")
  ./scripts/firebase_query_console.sh
  ./scripts/firebase_query_console.sh --project my-project --action logs-errors --since-minutes 30 --severity ERROR --limit 50
  ./scripts/firebase_query_console.sh --project my-project --action logs-search --contains permission-denied --function sendPushNotification
  ./scripts/firebase_query_console.sh --project my-project --action logs-trace --trace 4f9c6a3b
  ./scripts/firebase_query_console.sh --project my-project --preset payment-fail --action triage --txn-id 7eWAt1bk...
  ./scripts/firebase_query_console.sh --rerun-last

$(txt "Tuỳ chọn env:" "Environment options:")
  FIREBASE_PROJECT_ID=<project-id>   # preset project khi mở script
  FQC_LANG=vi|en                     # default language (default: en)
  FQC_HISTORY_REDACT_SENSITIVE=true|false  # redact uid/phone/memberId/txnId in local query history (default: true)

$(txt "Tuỳ chọn CLI:" "CLI options:")
  --project <project-id>      # set project không cần chọn menu
  --action <name>             # chạy non-interactive rồi thoát
                             # logs-errors | logs-search | logs-trace | triage
  --preset <name>             # payment-fail | push-fail | auth-fail
  --since-minutes <n>         # mặc định: 60
  --limit <n>                 # mặc định: 100
  --severity <level>          # DEFAULT|DEBUG|INFO|NOTICE|WARNING|ERROR|CRITICAL|ALERT|EMERGENCY
  --contains <keyword>        # dùng cho logs-search
  --function <function-name>  # lọc theo function (gen1/gen2)
  --trace <trace-or-request>  # dùng cho logs-trace
  --uid <uid>                 # lọc theo user id
  --phone <phone>             # lọc theo số điện thoại
  --member-id <memberId>      # lọc theo member id
  --txn-id <txnId>            # lọc theo transaction id
  --export <path.(md|json)>   # export report
  --lang <vi|en>              # đổi ngôn ngữ
  --rerun-last                # chạy lại query gần nhất
  --json                      # output entries dạng JSON
USAGE
}

main() {
  parse_args "$@"
  normalize_language
  if is_truthy "$HISTORY_REDACT_SENSITIVE"; then
    HISTORY_REDACT_SENSITIVE=true
  else
    HISTORY_REDACT_SENSITIVE=false
  fi
  init_colors
  ensure_history_store

  if [[ "$RERUN_LAST" -eq 1 ]]; then
    load_last_query_defaults
  fi

  require_deps
  ensure_firebase_login
  load_access_token
  select_project

  if [[ -n "$NON_INTERACTIVE_ACTION" ]]; then
    run_non_interactive_action
    exit 0
  fi

  while true; do
    show_menu
  done
}

main "$@"
