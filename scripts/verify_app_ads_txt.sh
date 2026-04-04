#!/usr/bin/env bash

set -euo pipefail

APP_ADS_PATH="${1:-mobile/befam/web/app-ads.txt}"

if [[ ! -f "$APP_ADS_PATH" ]]; then
  echo "::error::app-ads.txt not found at ${APP_ADS_PATH}."
  exit 1
fi

if ! grep -Eq '^[[:space:]]*google\.com,[[:space:]]*pub-[0-9A-Za-zxX-]+,[[:space:]]*DIRECT,[[:space:]]*f08c47fec0942fa0[[:space:]]*$' "$APP_ADS_PATH"; then
  echo "::error::app-ads.txt must include a valid google.com publisher line."
  exit 1
fi

if grep -Eiq 'pub-xxxxxxxxxxxxxxxx|replace the placeholder|replace-before-production' "$APP_ADS_PATH"; then
  echo "::error::app-ads.txt still contains placeholder content. Replace it with the real AdMob publisher ID before production."
  exit 1
fi

echo "Verified app-ads.txt at ${APP_ADS_PATH}"
