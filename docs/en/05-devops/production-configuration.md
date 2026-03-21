# Production Configuration Setup

_Last reviewed: March 20, 2026_

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

Required vars (Functions runtime):
- `FIREBASE_PROJECT_ID`
- `FIREBASE_FUNCTIONS_REGION`
- `APP_TIMEZONE`
- `APP_RUNTIME_CONFIG_COLLECTION`
- `APP_RUNTIME_CONFIG_DOC_ID`
- `EXPIRE_INVITES_JOB_SCHEDULE`
- `EVENT_REMINDER_JOB_SCHEDULE`
- `EVENT_REMINDER_LOOKAHEAD_MINUTES`
- `EVENT_REMINDER_SCAN_LIMIT`
- `EVENT_REMINDER_GRACE_MINUTES`
- `BILLING_SUBSCRIPTION_REMINDER_JOB_SCHEDULE`
- `BILLING_PENDING_TIMEOUT_JOB_SCHEDULE`
- `BILLING_DELINQUENCY_JOB_SCHEDULE`
- `BILLING_CONTACT_NOTICE_JOB_SCHEDULE`
- `BILLING_PENDING_TIMEOUT_MINUTES`
- `BILLING_PENDING_TIMEOUT_LIMIT`
- `BILLING_DELINQUENCY_GRACE_DAYS`
- `BILLING_DELINQUENCY_LIMIT`
- `BILLING_DELINQUENCY_REMINDER_DAYS`
- `BILLING_CONTACT_NOTICE_BATCH_LIMIT`
- `BILLING_CONTACT_NOTICE_REQUIRE_ENDPOINTS`
- `BILLING_CONTACT_NOTICE_WEBHOOK_TIMEOUT_MS`
- `BILLING_CONTACT_NOTICE_WEBHOOK_MAX_RETRIES`
- `BILLING_CONTACT_NOTICE_WEBHOOK_BACKOFF_MS`
- `NOTIFICATION_PUSH_ENABLED`
- `NOTIFICATION_EMAIL_ENABLED`
- `NOTIFICATION_EMAIL_COLLECTION`
- `NOTIFICATION_DEFAULT_PUSH_ENABLED`
- `NOTIFICATION_DEFAULT_EMAIL_ENABLED`
- `NOTIFICATION_ALLOW_NON_OTP_SMS`
- `NOTIFICATION_EVENT_MAX_AUDIENCE`
- `BILLING_CONTACT_SMS_WEBHOOK_URL`
- `BILLING_CONTACT_EMAIL_WEBHOOK_URL`
- `CALLABLE_ENFORCE_APP_CHECK`
- `OTP_PROVIDER`
- `OTP_ALLOWED_DIAL_CODES`
- `OTP_TWILIO_VERIFY_SERVICE_SID`
- `OTP_TWILIO_TIMEOUT_MS`
- `OTP_TWILIO_MAX_RETRIES`
- `OTP_TWILIO_BACKOFF_MS`
- `GOOGLE_PLAY_PACKAGE_NAME`
- `BILLING_IAP_ALLOW_TEST_MOCK`
- `BILLING_IAP_APPLE_VERIFY_TIMEOUT_MS`
- `BILLING_IAP_APPLE_VERIFY_MAX_RETRIES`
- `BILLING_IAP_APPLE_VERIFY_BACKOFF_MS`
- `GOOGLE_IAP_RTDN_AUDIENCE`
- `GOOGLE_IAP_RTDN_SERVICE_ACCOUNT_EMAIL`
- `BILLING_PRICING_CACHE_MS`

IAP product IDs are loaded from Firestore collection `subscriptionPackages` (`storeProductIds.ios` and `storeProductIds.android`), not from environment variables.

Required secrets:
- `FIREBASE_SERVICE_ACCOUNT`
- `BILLING_WEBHOOK_SECRET`
- `APPLE_SHARED_SECRET`

Required when `OTP_PROVIDER=twilio`:
- `OTP_TWILIO_ACCOUNT_SID`
- `OTP_TWILIO_AUTH_TOKEN`
- `OTP_TWILIO_VERIFY_SERVICE_SID`

Optional secrets:
- `CARD_WEBHOOK_SECRET`
- `BILLING_CONTACT_NOTICE_WEBHOOK_TOKEN`
- `APPLE_IAP_WEBHOOK_BEARER_TOKEN`
- `GOOGLE_IAP_WEBHOOK_BEARER_TOKEN`

Mobile/Web build vars (GitHub vars, optional):
- `BEFAM_ALLOW_BUNDLED_FIREBASE_OPTIONS`
- `BEFAM_FIREBASE_*`
- `BEFAM_FIREBASE_FUNCTIONS_REGION`
- `BEFAM_DEFAULT_TIMEZONE`
- `BEFAM_INVALID_CHECKOUT_HOSTS`
- `BEFAM_ENABLE_APP_CHECK`
- `BEFAM_APP_CHECK_WEB_RECAPTCHA_SITE_KEY`
- `BEFAM_ALLOW_FIREBASE_PHONE_FALLBACK` (must stay `false` in production)
- `BEFAM_BILLING_PENDING_TIMEOUT_MINUTES`

## Key Release Checks

Before production deploy:
- verify required vars/secrets exist
- verify Apple + Google Play product IDs match published store subscriptions
- verify `BILLING_IAP_ALLOW_TEST_MOCK=false` in production
- verify `BILLING_ENABLE_LEGACY_CARD_FLOW=false` in production
- verify `CALLABLE_ENFORCE_APP_CHECK=true` in production
- keep manual settlement disabled unless explicitly needed

After deploy:
- verify runtime env file step succeeded
- verify runtime override sync succeeded
- run auth + billing smoke tests on real devices
