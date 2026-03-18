#!/usr/bin/env bash

set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
PROJECT_ID="${FIREBASE_PROJECT_ID:-}"
ACCESS_TOKEN=""

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

ensure_firebase_login() {
  if ! firebase projects:list --json >/dev/null 2>&1; then
    echo "Firebase CLI chưa đăng nhập hoặc token hết hạn." >&2
    echo "Hãy chạy: firebase login --reauth" >&2
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
    echo "Không lấy được Firebase access token từ firebase-tools config." >&2
    echo "Hãy chạy: firebase login --reauth" >&2
    exit 1
  fi
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
    echo "Không thấy project nào từ Firebase CLI." >&2
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
      echo "Using project from FIREBASE_PROJECT_ID: $PROJECT_ID ($pname)"
      return
    fi
  fi

  echo
  echo "Chọn Firebase project:"
  select choice in "${options[@]}"; do
    if [[ -n "${choice:-}" ]]; then
      PROJECT_ID="${choice%% *}"
      echo "Đã chọn project: $PROJECT_ID"
      break
    fi
    echo "Lựa chọn không hợp lệ, chọn lại."
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

show_menu() {
  echo
  echo "================ Firebase Query Console ================"
  echo "Current project: $PROJECT_ID"
  echo "========================================================"

  local options=(
    "Users summary"
    "Auth users có số điện thoại"
    "Device tokens"
    "Billing subscriptions"
    "Billing pending transactions"
    "Billing latest transactions"
    "Danh sách clans"
    "Members theo clan"
    "Đổi project"
    "Thoát"
  )

  select opt in "${options[@]}"; do
    case "$opt" in
      "Users summary")
        show_users_summary
        break
        ;;
      "Auth users có số điện thoại")
        show_auth_phone_users
        break
        ;;
      "Device tokens")
        show_device_tokens
        break
        ;;
      "Billing subscriptions")
        show_subscriptions
        break
        ;;
      "Billing pending transactions")
        show_pending_transactions
        break
        ;;
      "Billing latest transactions")
        show_latest_transactions
        break
        ;;
      "Danh sách clans")
        show_clans
        break
        ;;
      "Members theo clan")
        show_members_for_selected_clan
        break
        ;;
      "Đổi project")
        PROJECT_ID=""
        select_project
        break
        ;;
      "Thoát")
        echo "Bye."
        exit 0
        ;;
      *)
        echo "Lựa chọn không hợp lệ, chọn lại."
        ;;
    esac
  done
}

usage() {
  cat <<USAGE
$SCRIPT_NAME

Script query Firebase/Firestore bằng menu chọn số.
Không cần gõ câu lệnh query thủ công.

Cách dùng:
  ./scripts/firebase_query_console.sh

Tuỳ chọn env:
  FIREBASE_PROJECT_ID=<project-id>   # preset project khi mở script
USAGE
}

main() {
  if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
  fi

  require_deps
  ensure_firebase_login
  load_access_token
  select_project

  while true; do
    show_menu
  done
}

main "$@"
