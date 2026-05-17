# Production Configuration Setup

_Last reviewed: March 22, 2026_

This runbook explains how BeFam separates local and production runtime
configuration safely.

## Runtime Layers

1. GitHub Environment `production` (vars + secrets)
2. Firestore runtime overrides (`runtimeConfig/global`, non-secret only)
3. Flutter build-time defines (`--dart-define`)

## Staging Deployment Scope

`staging` deploy pipeline is sandbox-only and deploys only:
- Firebase resources in staging project (`firestore:rules`, `firestore:indexes`, `storage`, `functions`)
- Web hosting bundle
- Android release AAB + iOS signed IPA artifacts
- Optional staged mobile publish: Android `internal/closed` track and iOS `TestFlight`

`staging` must **never** publish to production mobile channels.
Use `STAGING_MOBILE_PUBLISH_ENABLED=true` to enable staged mobile publish.

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
- `FIRESTORE_DATABASE_ID` (`(default)` for staging, `befam` for production in current setup)
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
- `AI_ASSIST_ENABLED`
- `AI_ASSIST_MODEL`
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

Required deploy secrets (OIDC + billing):
- `GCP_WORKLOAD_IDENTITY_PROVIDER`
- `GCP_SERVICE_ACCOUNT_EMAIL`
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

Required when `AI_ASSIST_ENABLED=true`:
- `GOOGLE_GENAI_API_KEY`

Required release signing secrets:
- `ANDROID_RELEASE_KEYSTORE_BASE64`
- `ANDROID_RELEASE_KEYSTORE_PASSWORD`
- `ANDROID_RELEASE_KEY_ALIAS`
- `ANDROID_RELEASE_KEY_PASSWORD`
- `IOS_P12_BASE64`
- `IOS_P12_PASSWORD`
- `IOS_PROVISIONING_PROFILE_BASE64`
- `IOS_TEAM_ID`

Required for staged mobile publish (if enabled):
- `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` (or fallback `FIREBASE_SERVICE_ACCOUNT`)
- `APP_STORE_CONNECT_ISSUER_ID`
- `APP_STORE_CONNECT_API_KEY_ID`
- `APP_STORE_CONNECT_API_PRIVATE_KEY`

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

## Gemini Key Setup via GitHub Secrets

Where to create the key:
- open [Google AI Studio](https://aistudio.google.com/app/apikey)
- pick the Google project used for BeFam
- create a Gemini Developer API key
- copy the value immediately after creation

Where to store it:
- go to GitHub repository `Settings` -> `Environments` -> `production`
- add an environment secret named `GOOGLE_GENAI_API_KEY`
- if staging AI is enabled, add the same secret name under the `staging` environment too

Where to store non-sensitive AI config:
- add GitHub environment var `AI_ASSIST_ENABLED=true`
- add GitHub environment var `AI_ASSIST_MODEL=gemini-2.5-flash-lite`

Production deploy flow after setup:
1. `CD - Deploy Firebase (Production)` reads `GOOGLE_GENAI_API_KEY` from the GitHub Environment secret
2. the workflow syncs that value into Firebase Functions Secret Manager with `firebase functions:secrets:set`
3. AI Functions bind the secret at runtime and do not write the key into repo-tracked config or production `.env` files

Equivalent CLI commands for manual verification:

```bash
cd firebase/functions
firebase functions:secrets:set GOOGLE_GENAI_API_KEY
firebase functions:secrets:access GOOGLE_GENAI_API_KEY
```

Operational guidance:
- use a GitHub **environment secret**, not a shared repository secret, for production
- rotate the key by updating the GitHub secret and re-running the deploy workflow
- do not place `GOOGLE_GENAI_API_KEY` inside production `.env.<project>` files

## Key Release Checks

Before production deploy:
- verify required vars/secrets exist
- verify production Firestore database matches `FIRESTORE_DATABASE_ID` (current production value: `befam`)
- verify staging Firestore database stays `(default)` and staging project id stays `be-fam-3ab23`
- verify Apple + Google Play product IDs match published store subscriptions
- verify `BILLING_IAP_ALLOW_TEST_MOCK=false` in production
- verify `BILLING_ENABLE_LEGACY_CARD_FLOW=false` in production
- verify `CALLABLE_ENFORCE_APP_CHECK=true` in production
- if `AI_ASSIST_ENABLED=true`, verify `GOOGLE_GENAI_API_KEY` exists in the `production` GitHub Environment secrets
- verify branch protection is enabled on `staging` and `main` with required checks
- rotate any leaked secret immediately (especially `APPLE_SHARED_SECRET`) before release
- keep manual settlement disabled unless explicitly needed
- verify `subscriptionPackages` has active `FREE/BASE/PLUS/PRO` (preflight blocks release if missing)

After deploy:
- verify runtime env file step succeeded
- verify the `GOOGLE_GENAI_API_KEY` secret sync step succeeded
- verify runtime override sync succeeded
- verify subscription package catalog sync succeeded
- run auth + billing smoke tests on real devices

## Code-owned Firestore baseline

Production and staging deployments now sync `subscriptionPackages` from:

- `firebase/functions/config/subscription-packages.catalog.json`

Sync/check command:

```bash
cd firebase/functions
npm ci
FIREBASE_PROJECT_ID=<project-id> npm run config:subscription-packages:check
FIREBASE_PROJECT_ID=<project-id> npm run config:subscription-packages:sync
```
