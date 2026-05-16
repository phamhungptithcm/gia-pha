# BeFam Release Test Cases

_Last updated: May 16, 2026_

This file is the runnable release gate for BeFam. The longer Vietnamese manual
suite remains in `docs/vi/05-devops/release-test-plan.md`; this file is the
short operator checklist for local, CI, staging, and production promotion.

## Entry Criteria

- Work is based on the latest `staging`.
- No unreviewed local secrets are staged.
- GitHub `staging` and `production` environments pass the audit script.
- No critical/high dependency vulnerabilities remain without a documented,
  accepted exception.
- `main` and `staging` branch protection require the release checks listed
  below.

## Local Automated Gate

Run from repo root:

```bash
python3 scripts/validate_rules_documentation.py
./scripts/lint_design_md.sh
./.venv/bin/mkdocs build --strict
```

Run Functions checks:

```bash
cd firebase/functions
npm ci
npm audit --audit-level=high
npm run build
npm test
```

Run mobile checks:

```bash
cd mobile/befam
flutter pub get
flutter gen-l10n
flutter analyze
flutter test --dart-define=BEFAM_ALLOW_BUNDLED_FIREBASE_OPTIONS=true
```

Run UI/motion/performance checks:

```bash
./scripts/run_performance_benchmarks.sh
```

Expected artifacts:

- `mobile/befam/artifacts/performance/performance-report.md`
- `mobile/befam/artifacts/performance/genealogy-benchmark.log`
- `mobile/befam/artifacts/performance/flutter-profile-build.log`
- `mobile/befam/artifacts/performance/lighthouse-web-release.json`

The report must show Lighthouse results, genealogy benchmark timings, and a
Flutter profile-mode result or an explicit device availability gap. Firebase
Performance custom traces must be checked after staging/profile sessions for
workspace refreshes and `befam_frames_batch_p95`.

Run focused form/action regression checks when a release touches input fields,
timers, async buttons, or navigation motion:

```bash
cd mobile/befam
flutter test test/core/widgets/app_form_controls_test.dart
flutter test test/widget_test.dart --name "auth phone form|auth child and OTP|clan editor shows|branch editor shows|member add form blocks|filters parent candidates"
flutter test test/features/events/event_widget_test.dart --name "edit form shows required title error before moving on"
flutter test test/features/funds/fund_form_validation_widget_test.dart
flutter test test/features/scholarship/scholarship_flow_widget_test.dart --name "create forms surface required errors before continuing"
```

Run environment audits:

```bash
./scripts/audit_github_environment.sh --repo phamhungptithcm/gia-pha --env staging --strict
./scripts/audit_github_environment.sh --repo phamhungptithcm/gia-pha --env production --strict
```

## Required CI Checks

These checks must be required on `staging` and `main` before release:

- CI - Docs Validation and Build
- CI - Functions Build and Test
- CI - Mobile Build and Test
- Security - Dependency Review
- Security - Trivy Filesystem Scan
- Security - Gitleaks Secret Scan
- Security - Trivy Container Image Scan
- E2E - Android Test Run
- E2E - iOS Test Run

No required release check may be implemented as a permanent echo/skip step.

## P0 Manual Smoke Suite

| ID | Area | Steps | Expected result |
| --- | --- | --- | --- |
| AUTH-P0-01 | Phone OTP | Login with a production-like test phone, enter valid OTP, reopen app. | Session restores to the correct user and active clan. |
| AUTH-P0-02 | Child access | Login with child identifier and guardian OTP. | Child session is read-only where required and clan-scoped. |
| CTX-P0-01 | Multi-clan | Switch between two clans from Home, Tree, Events, Billing, Profile. | Every workspace shows only active clan data. |
| TREE-P0-01 | Genealogy | Open Tree, search member, focus result, open detail. | Tree responds smoothly, no layout overflow, correct profile opens. |
| REL-P0-01 | Relationship | Create valid parent-child relation, then attempt invalid cycle. | Valid write succeeds; invalid write is blocked. |
| EVT-P0-01 | Events | Create solar event and lunar memorial reminder. | Events persist with correct timezone and recurrence metadata. |
| NOTIF-P0-01 | Push | Register device token, send event reminder, tap push. | Notification deep-links to the correct event detail. |
| FUND-P0-01 | Funds | Create fund transaction as treasurer/admin. | Ledger and balance update consistently. |
| FUND-P0-02 | Funds rules | Attempt direct client write to server-only transaction path. | Firestore rules deny the write. |
| SCH-P0-01 | Scholarship | Submit evidence as member, review as council/admin. | Storage and review permissions are correct. |
| BILL-P0-01 | Billing | Load plan, verify entitlement, start store checkout test flow. | Plan and provider state are consistent; no raw payment details are stored. |
| ADS-P0-01 | Ads consent | Fresh install, open privacy choices, configure consent. | Consent state is saved and ads respect eligibility. |
| PROFILE-P0-01 | Account deletion | Submit account deletion request from Profile. | Request is stored once, status is visible, repeated submit is blocked. |
| WEB-P0-01 | Web legal | Open `https://befam.co/privacy`, `/terms`, `/account-deletion`, `/app-ads.txt`. | All return 200 and correct production content. |

## P1 Manual UX and Resilience Suite

| ID | Area | Steps | Expected result |
| --- | --- | --- | --- |
| UX-P1-01 | Mobile widths | Run auth, home, tree, event, billing on small and large devices. | No clipped text, overflows, or nested-card clutter. |
| UX-P1-02 | Localization | Switch EN/VI and revisit all primary tabs. | No hard-coded mismatched copy on release-critical flows. |
| UX-P1-03 | Form required states | Try to continue/save empty required fields in auth, clan, branch, member, event, fund, scholarship. | Required fields are visibly marked and block progress with inline errors. |
| UX-P1-04 | Async button feedback | Tap save/send/upload/link buttons repeatedly during a simulated slow request. | Button shows press feedback/loading progress and accepts only one in-flight action. |
| UX-P1-05 | Timers and motion | Trigger OTP resend cooldown and move between release-critical screens. | Timer has progress + remaining time; navigation uses stable scale-only motion without slide/fade. |
| PERF-P1-01 | Startup | Cold start on normal network and warm cache. | First useful shell or stable placeholder appears under one second after bootstrap. |
| PERF-P1-02 | Tab switch | Switch Home/Tree/Events/Billing/Profile repeatedly. | Cached tab switch stays under 300ms perceived latency. |
| OFFLINE-P1-01 | Offline | Open app offline after a successful login. | Cached or friendly offline state appears; app does not crash. |
| RECOVERY-P1-01 | Provider failure | Simulate AI/billing/push service unavailable. | UI shows safe retry/fallback without exposing raw internal errors. |

## Release Exit Criteria

- All P0 cases pass.
- P1 failures have explicit owner and accepted release risk.
- `flutter test`, Functions tests, docs build, rules validation, and environment
  audits pass.
- GitHub release artifacts are downloaded and smoke-tested before store upload.
- Firebase Hosting and Functions production deploys are run manually from the
  approved immutable release tag.
