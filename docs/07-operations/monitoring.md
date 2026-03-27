# Monitoring

_Last reviewed: March 26, 2026_

## Application monitoring

- app startup and runtime events are logged through `AppLogger`
- global error capture routes:
  - `FlutterError.onError`
  - `PlatformDispatcher.instance.onError`
  - zone-level uncaught handler
- widget-build failures now render a user-friendly fallback screen through
  `ErrorWidget.builder` (`app/error/app_error_fallback.dart`)
- Crashlytics collection is enabled only for release builds

## Performance measurement logging

`PerformanceMeasurementLogger` now provides consistent duration logs with
slow-path warnings.

Current instrumented metrics:

- `perf.bootstrap.firebase_initialize`
- `perf.member_search.query`
- `perf.genealogy.tree_scene_build`

Operational notes:

- each log includes `elapsed_ms` and structured dimensions
- warning logs are emitted when `elapsed` meets/exceeds the metric threshold
- thresholds are currently tuned per flow in code

## Backend monitoring

- Cloud Functions use structured logging helpers in `shared/logger.ts`
- trigger/callable logs include ids and clan context where available
- push delivery reports sent/failed/invalid token counts
- join-request callables emit `traceId` and notification-delivery status fields
  (`reviewerNotification*`, `applicantNotification*`) for easier triage

Billing monitoring (Epic #213):

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

Quality gate additions:

- Functions dead-code gate via `tsc --noUnusedLocals --noUnusedParameters`
- Mobile strict static-analysis gate via
  `dart analyze --fatal-infos --fatal-warnings`
- Mobile coverage gate via `flutter test --coverage` + threshold check

## Runbook basics

When release issues appear:

1. check GitHub Actions workflow run details
2. verify Firebase deploy credentials and project variables
3. confirm app build artifact outputs (Android AAB and iOS IPA)
4. review function logs for trigger/callable failures
5. inspect mobile logs for `perf.*` warnings to identify regressions
6. verify fallback UI occurrence and Crashlytics traces for render failures
7. for billing incidents: verify gateway callback signature logs and
   transaction idempotency records
