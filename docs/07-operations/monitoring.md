# Monitoring

_Last reviewed: March 14, 2026_

## Application monitoring

- app startup and runtime events are logged through `AppLogger`
- global error capture routes:
  - `FlutterError.onError`
  - `PlatformDispatcher.instance.onError`
  - zone-level uncaught handler
- Crashlytics collection is enabled only for release builds

## Backend monitoring

- Cloud Functions use structured logging helpers in `shared/logger.ts`
- trigger/callable logs include ids and clan context where available
- push delivery reports sent/failed/invalid token counts

Planned billing monitoring (Epic #213):

- checkout initialization success/failure rate
- webhook signature validation failures
- payment success/failure/pending transition counts
- duplicate webhook/idempotency conflict counters
- subscription expiry reminder delivery success rate

## CI as operational guardrail

Required checks for protected branches:

- `ci-docs`
- `ci-functions`
- `ci-mobile`

These checks validate docs build, functions compile, Flutter analyze/test, and
release-image build viability.

## Runbook basics

When release issues appear:

1. check GitHub Actions workflow run details
2. verify Firebase deploy credentials and project variables
3. confirm app build artifact outputs (APK and iOS archive)
4. review function logs for trigger/callable failures
5. for billing incidents: verify gateway callback signature logs and
   transaction idempotency records
