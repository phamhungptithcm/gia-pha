#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
WEB_DIR="${ROOT_DIR}/mobile/befam/web"

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/render_web_metadata.sh [base_url]

Resolution order for base_url:
  1) CLI arg
  2) BEFAM_WEB_BASE_URL
  3) https://<BEFAM_FIREBASE_PROJECT_ID>.web.app
  4) https://<FIREBASE_PROJECT_ID>.web.app

Examples:
  ./scripts/render_web_metadata.sh https://befam.vn
  BEFAM_WEB_BASE_URL=https://staging.befam.vn ./scripts/render_web_metadata.sh
USAGE
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

base_url="${1:-${BEFAM_WEB_BASE_URL:-}}"
if [[ -z "$base_url" && -n "${BEFAM_FIREBASE_PROJECT_ID:-}" ]]; then
  base_url="https://${BEFAM_FIREBASE_PROJECT_ID}.web.app"
fi
if [[ -z "$base_url" && -n "${FIREBASE_PROJECT_ID:-}" ]]; then
  base_url="https://${FIREBASE_PROJECT_ID}.web.app"
fi

if [[ -z "$base_url" ]]; then
  base_url="http://localhost"
  echo "BEFAM_WEB_BASE_URL is not set; defaulting web metadata base URL to ${base_url}." >&2
fi

if [[ ! "$base_url" =~ ^https?:// ]]; then
  base_url="https://${base_url}"
fi
base_url="${base_url%/}"

render_file() {
  local template_path="$1"
  local output_path="$2"
  if [[ ! -f "$template_path" ]]; then
    echo "Template not found: $template_path" >&2
    exit 1
  fi
  sed "s|__BEFAM_WEB_BASE_URL__|${base_url}|g" "$template_path" > "$output_path"
}

render_file "${WEB_DIR}/index.template.html" "${WEB_DIR}/index.html"
render_file "${WEB_DIR}/robots.template.txt" "${WEB_DIR}/robots.txt"
render_file "${WEB_DIR}/sitemap.template.xml" "${WEB_DIR}/sitemap.xml"

echo "Rendered web metadata with BEFAM_WEB_BASE_URL=${base_url}"
