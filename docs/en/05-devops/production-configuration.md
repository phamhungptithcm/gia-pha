# Production Configuration Setup

_Last reviewed: March 18, 2026_

This runbook explains how BeFam separates local and production runtime
configuration safely.

## Runtime Layers

1. GitHub Environment `production` (vars + secrets)
2. Firestore runtime overrides (`runtimeConfig/global`, non-secret only)
3. Flutter build-time defines (`--dart-define`)

## Supported OS Versions

Current production baseline:
- iOS: `15.0+`
- Android: `API 24+` (Android 7.0+)

Where this is enforced:
- iOS deployment target: `mobile/befam/ios/Podfile`
- Android min SDK: `mobile/befam/android/app/build.gradle.kts` (via `flutter.minSdkVersion`)

Important constraints from the current stack:
- Flutter `3.41.x` defaults to Android min SDK `24`.
- Firebase iOS plugins in use require iOS deployment target `15.0`.

If you need to support lower OS versions:
- run a dependency compatibility audit first
- pin/downgrade affected plugins (if available)
- re-test phone auth, Firebase messaging, billing, and print/export flows on real devices

## Required Keys

Required vars:
- `FIREBASE_PROJECT_ID`
- `FIREBASE_FUNCTIONS_REGION`
- `APP_TIMEZONE`
- `GOOGLE_PLAY_PACKAGE_NAME`
- `BILLING_IAP_PRODUCT_IDS_BASE`
- `BILLING_IAP_PRODUCT_IDS_PLUS`
- `BILLING_IAP_PRODUCT_IDS_PRO`

Required secrets:
- `FIREBASE_SERVICE_ACCOUNT`
- `BILLING_WEBHOOK_SECRET`
- `APPLE_SHARED_SECRET`

Optional secret:
- `CARD_WEBHOOK_SECRET`
- `VNPAY_TMNCODE` (legacy VNPay compatibility only)
- `VNPAY_HASH_SECRET` (legacy VNPay compatibility only)

## Key Release Checks

Before production deploy:
- verify required vars/secrets exist
- verify Apple + Google Play product IDs match published store subscriptions
- verify `BILLING_IAP_ALLOW_TEST_MOCK=false` in production
- if legacy VNPay path is still enabled, verify `VNPAY_RETURN_URL` and VNPay secrets
- keep manual settlement disabled unless explicitly needed

After deploy:
- verify runtime env file step succeeded
- verify runtime override sync succeeded
- run auth + billing smoke tests on real devices
