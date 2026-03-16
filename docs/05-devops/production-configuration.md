# Production Configuration Setup

_Last reviewed: March 16, 2026_

This guide centralizes all runtime configuration changes introduced for local vs
production separation.

## Why this changed

Configuration that can differ between local and production is now managed in:

- GitHub Environment `production` (`vars` + `secrets`)
- Firestore runtime document `runtimeConfig/global` (non-secret overrides)
- Flutter build-time `--dart-define` (mobile runtime constants)

Hard-coded values were removed from billing/auth runtime paths where possible.

## Implemented configuration refactor coverage

The following implementation changes are now in place and documented:

- centralized Functions runtime getters:
  `firebase/functions/src/config/runtime.ts`
- Firestore runtime override loader with `60s` cache:
  `firebase/functions/src/config/runtime-overrides.ts`
- billing checkout URL and timeout config resolved from runtime override/env:
  `firebase/functions/src/billing/callables.ts`
- webhook signature secrets resolved via env getter helpers:
  `firebase/functions/src/billing/webhooks.ts`
- scheduler uses env schedule + runtime override timeout/limit:
  `firebase/functions/src/scheduled/jobs.ts`
- auth debug signer service account no longer hard-coded:
  `firebase/functions/src/auth/callables.ts`
- deploy workflow writes `.env.<projectId>` and syncs Firestore runtime config:
  `.github/workflows/deploy-firebase.yml`
- runtime config sync script:
  `firebase/functions/scripts/upsert-runtime-config.mjs`
- mobile compile-time environment constants:
  `mobile/befam/lib/core/services/app_environment.dart`
- release workflow injects mobile `--dart-define` values:
  `.github/workflows/release-main.yml`

## Configuration layers

1. GitHub `production` Environment
- source of truth for deploy-time env values and secrets
- injected into Functions deploy as `firebase/functions/.env.<projectId>`

2. Firestore runtime overrides (`runtimeConfig/global`)
- non-secret values only
- synced by deploy workflow using `firebase/functions/scripts/upsert-runtime-config.mjs`
- can be updated without code changes

3. Flutter `--dart-define`
- mobile Functions region and timezone defaults
- checkout host guard list

## Configuration matrix (local vs production)

| Key | Type | Local/default | Production release action |
| --- | --- | --- | --- |
| `FIREBASE_PROJECT_ID` | var | local Firebase project id | set to production Firebase project id |
| `FIREBASE_FUNCTIONS_REGION` | var | `asia-southeast1` | keep production region used by deployed Functions |
| `APP_TIMEZONE` | var | `Asia/Ho_Chi_Minh` | set org timezone for scheduled/billing logic |
| `FIREBASE_SERVICE_ACCOUNT` | secret | local ADC/emulator | use production deploy service account JSON |
| `BILLING_WEBHOOK_SECRET` | secret | test/dev secret | rotate and set production-strength secret |
| `VNPAY_TMNCODE` | secret | sandbox code | switch to production TMNCODE from VNPay |
| `VNPAY_HASH_SECRET` | secret | sandbox hash secret | switch to production hash secret from VNPay |
| `CARD_WEBHOOK_SECRET` | optional secret | fallback to billing webhook | set only if card provider webhook differs |
| `BILLING_VNPAY_GATEWAY_BASE_URL` | optional var | `https://sandbox.vnpayment.vn/paymentv2/vpcpay.html` | switch to production VNPay gateway URL |
| `VNPAY_RETURN_URL` | optional var | empty/example | set to production return/callback URL |
| `BILLING_VNPAY_FALLBACK_URL` | optional var | empty/example | set to production fallback page/deep link |
| `BILLING_CARD_CHECKOUT_URL_BASE` | optional var | empty/example | keep empty if card checkout disabled |
| `BILLING_VNPAY_IP_ADDRESS` | optional var | `127.0.0.1` | set server egress IP if required by VNPay |
| `BILLING_VNPAY_LOCALE` | optional var | `vn` | set locale required by VNPay integration |
| `BILLING_PENDING_TIMEOUT_MINUTES` | optional var | `20` | tune pending-payment timeout policy |
| `BILLING_PENDING_TIMEOUT_LIMIT` | optional var | `800` | tune batch processing limit for timeout job |
| `BILLING_ALLOW_MANUAL_SETTLEMENT` | optional var | `false` | keep `false` in production, enable only for internal ops emergencies |
| `DEBUG_TOKEN_SIGNER_SERVICE_ACCOUNT` | optional var | empty | keep empty in production unless explicitly needed |
| `APP_RUNTIME_CONFIG_COLLECTION` | optional var | `runtimeConfig` | change only if you migrate document path |
| `APP_RUNTIME_CONFIG_DOC_ID` | optional var | `global` | change only if you migrate document id |
| `BEFAM_INVALID_CHECKOUT_HOSTS` | optional var | `example.com` | set deny-list hosts for mobile release builds |

## Required values

Required `vars`:

- `FIREBASE_PROJECT_ID`
- `FIREBASE_FUNCTIONS_REGION`
- `APP_TIMEZONE`

Required `secrets`:

- `FIREBASE_SERVICE_ACCOUNT`
- `BILLING_WEBHOOK_SECRET`
- `VNPAY_TMNCODE`
- `VNPAY_HASH_SECRET`

Optional `vars`:

- `APP_RUNTIME_CONFIG_COLLECTION`
- `APP_RUNTIME_CONFIG_DOC_ID`
- `BILLING_PENDING_TIMEOUT_MINUTES`
- `BILLING_PENDING_TIMEOUT_LIMIT`
- `BILLING_ALLOW_MANUAL_SETTLEMENT`
- `BILLING_CARD_CHECKOUT_URL_BASE`
- `BILLING_VNPAY_FALLBACK_URL`
- `BILLING_VNPAY_GATEWAY_BASE_URL`
- `VNPAY_RETURN_URL`
- `BILLING_VNPAY_IP_ADDRESS`
- `BILLING_VNPAY_LOCALE`
- `DEBUG_TOKEN_SIGNER_SERVICE_ACCOUNT`
- `BEFAM_INVALID_CHECKOUT_HOSTS`

Optional `secret`:

- `CARD_WEBHOOK_SECRET`

## Setup (recommended via script)

1. Prepare env file:

```bash
cp scripts/github-production.env.example /tmp/github-production.env
```

2. Fill real values in `/tmp/github-production.env` (especially secrets).

3. Apply configuration:

```bash
set -a
source /tmp/github-production.env
set +a
./scripts/setup_github_production_config.sh --repo phamhungptithcm/gia-pha --env production
```

## Manual setup (GitHub UI)

- Go to `Settings -> Environments -> production`
- Add/update required `vars` and `secrets`
- Keep optional keys empty unless needed by your release strategy

## Firestore runtime override schema

Path:

```text
runtimeConfig/global
```

Suggested document shape:

```json
{
  "billing": {
    "cardCheckoutUrlBase": "https://...",
    "vnpayFallbackUrl": "https://...",
    "vnpayGatewayBaseUrl": "https://sandbox.vnpayment.vn/paymentv2/vpcpay.html",
    "vnpayReturnUrl": "https://...",
    "vnpayIpAddress": "127.0.0.1",
    "vnpayLocale": "vn",
    "pendingTimeoutMinutes": 20,
    "pendingTimeoutLimit": 800
  },
  "updatedBy": "ops@company",
  "updatedAt": "serverTimestamp"
}
```

Notes:

- do not store secrets in Firestore runtime config
- secrets must stay in GitHub Environment secrets

## Release checklist (configuration-focused)

Before production release:

- verify required vars/secrets exist in GitHub `production`
- verify VNPay keys are production keys (not sandbox) when going live
- verify `BILLING_VNPAY_GATEWAY_BASE_URL` is production endpoint (not `sandbox`)
- verify `VNPAY_RETURN_URL` and `BILLING_VNPAY_FALLBACK_URL` point to production routes
- verify `BILLING_WEBHOOK_SECRET`/`CARD_WEBHOOK_SECRET` are rotated and stored only in secrets
- verify `BILLING_ALLOW_MANUAL_SETTLEMENT=false` for production
- verify card checkout behavior:
  - if card payment is disabled, keep `BILLING_CARD_CHECKOUT_URL_BASE` empty
  - if enabled later, set provider checkout URL base
- verify mobile release inputs:
  - `APP_TIMEZONE` is correct for scheduler and display defaults
  - `BEFAM_INVALID_CHECKOUT_HOSTS` deny-list is intentionally set

After deploy:

- confirm deploy workflow created `.env.<projectId>` successfully in CI logs
- confirm runtime config sync step succeeded
- run a billing checkout smoke test in app
- verify webhook callback can mark transaction as succeeded

## Quick verification commands

List current production vars:

```bash
gh variable list --env production --repo phamhungptithcm/gia-pha | sort
```

List current production secrets (names only):

```bash
gh secret list --env production --repo phamhungptithcm/gia-pha | sort
```

Check missing required keys quickly:

```bash
required_vars=(FIREBASE_PROJECT_ID FIREBASE_FUNCTIONS_REGION APP_TIMEZONE)
required_secrets=(FIREBASE_SERVICE_ACCOUNT BILLING_WEBHOOK_SECRET VNPAY_TMNCODE VNPAY_HASH_SECRET)

current_vars=$(gh variable list --env production --repo phamhungptithcm/gia-pha | awk '{print $1}')
current_secrets=$(gh secret list --env production --repo phamhungptithcm/gia-pha | awk '{print $1}')

for key in "${required_vars[@]}"; do
  echo "$current_vars" | grep -qx "$key" || echo "Missing var: $key"
done
for key in "${required_secrets[@]}"; do
  echo "$current_secrets" | grep -qx "$key" || echo "Missing secret: $key"
done
```

## Where config is consumed in code

- Functions env/runtime constants:
  `firebase/functions/src/config/runtime.ts`
- Firestore runtime overrides:
  `firebase/functions/src/config/runtime-overrides.ts`
- Billing checkout URL + timeout reads:
  `firebase/functions/src/billing/callables.ts`
- Webhook secret reads:
  `firebase/functions/src/billing/webhooks.ts`
- Scheduler timeout/schedule reads:
  `firebase/functions/src/scheduled/jobs.ts`
- Auth debug signer service account:
  `firebase/functions/src/auth/callables.ts`
- Mobile build-time env:
  `mobile/befam/lib/core/services/app_environment.dart`
