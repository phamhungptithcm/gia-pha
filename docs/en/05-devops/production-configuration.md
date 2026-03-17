# Production Configuration Setup

_Last reviewed: March 17, 2026_

This runbook explains how BeFam separates local and production runtime
configuration safely.

## Runtime Layers

1. GitHub Environment `production` (vars + secrets)
2. Firestore runtime overrides (`runtimeConfig/global`, non-secret only)
3. Flutter build-time defines (`--dart-define`)

## Required Keys

Required vars:
- `FIREBASE_PROJECT_ID`
- `FIREBASE_FUNCTIONS_REGION`
- `APP_TIMEZONE`

Required secrets:
- `FIREBASE_SERVICE_ACCOUNT`
- `BILLING_WEBHOOK_SECRET`
- `VNPAY_TMNCODE`
- `VNPAY_HASH_SECRET`

Optional secret:
- `CARD_WEBHOOK_SECRET`

## Key Release Checks

Before production deploy:
- verify required vars/secrets exist
- verify VNPay config uses production values
- verify `VNPAY_RETURN_URL` is valid
- keep manual settlement disabled unless explicitly needed

After deploy:
- verify runtime env file step succeeded
- verify runtime override sync succeeded
- run auth + billing smoke tests on real devices
