# BeFam Website Final Release Report

Date: 2026-05-18
Release orchestrator: Codex
Scope: Website/browser only
QA environment: Staging only
Production target: Firebase Hosting / `befam.co`

## Release Readiness

Release readiness: **NOT READY**

The website build, public pages, route rewrites, security headers, responsive
screenshots, metadata, and CI/CD release gates are in a much better state.
However, the release definition of done requires successful staging login and
post-login browser coverage. The live browser run reached Firebase reCAPTCHA,
which presented an image challenge and blocked automated OTP completion.

Do not enable production Twilio or publish this website as fully production
ready until the login blocker is resolved and retested.

## Website URL Tested

- Local Firebase Hosting emulator: `http://127.0.0.1:5002`
- Production metadata target generated for: `https://befam.co`
- Production deployment itself was not modified in this workflow.

## Browsers / Viewports Tested

| Browser | Viewport | Result |
| --- | --- | --- |
| Chromium | 1440x900 desktop | Pass for public routes and `/app` auth entry. |
| Chromium | 834x1112 tablet | Pass for public landing layout. |
| Chromium | 390x844 mobile | Pass for public landing layout. |

## Fixed Issues

| ID | Summary | Status |
| --- | --- | --- |
| `WEB-QA-001` | Footer overlap and oversized fixed footer behavior. | Verified |
| `WEB-QA-002` | Missing/incomplete security headers and CSP. | Verified |
| `WEB-QA-003` | Deep-link route proof through Firebase Hosting rewrites. | Verified |
| `WEB-QA-004` | Public metadata generated with local URLs. | Verified |
| `WEB-UIUX-002` | Tablet nav collapsed too early. | Verified |
| `WEB-UIUX-003` | Mobile hero felt too cramped. | Verified |
| `WEB-UIUX-004` | CTA wording was inconsistent. | Verified |
| `TL-WEB-002` | App Check site key not enforced in production config gate. | Fixed |
| `TL-WEB-003` | Production hosting deploy lacked route/header smoke checks. | Fixed |
| `TL-WEB-004` | Firebase bootstrap did not handle matching pre-initialized app. | Fixed |
| `TL-WEB-005` | Web FCM background handler registration was not guarded. | Fixed |

## Commands Run

```bash
npx gitnexus impact --repo gia-pha AppBootstrap.initialize --direction upstream
npx gitnexus impact --repo gia-pha initialize --direction upstream
npx gitnexus impact --repo gia-pha configurePushBackgroundHandler --direction upstream
jq empty firebase.json
bash -n scripts/audit_github_environment.sh scripts/render_web_metadata.sh
ruby -e 'require "yaml"; %w[.github/workflows/release-main.yml .github/workflows/deploy-staging.yml .github/workflows/deploy-web-hosting.yml].each { |f| YAML.load_file(f); puts "OK #{f}" }'
BEFAM_WEB_BASE_URL=https://befam.co ./scripts/render_web_metadata.sh
```

```bash
cd mobile/befam
dart format lib/app/bootstrap/app_bootstrap.dart lib/features/notifications/services/push_notification_service.dart test/app/web/web_live_smoke_gate_test.dart test/app/web/web_live_smoke_base_href_stub.dart test/app/web/web_live_smoke_base_href_web.dart
flutter analyze
flutter test test/app/web/web_marketing_pages_test.dart --dart-define=BEFAM_ALLOW_BUNDLED_FIREBASE_OPTIONS=true
flutter test --platform=chrome test/app/web/web_live_smoke_gate_test.dart --dart-define=BEFAM_E2E_RUN_LIVE=false
flutter build web --release --no-wasm-dry-run --dart-define=BEFAM_ALLOW_BUNDLED_FIREBASE_OPTIONS=true --dart-define=BEFAM_OTP_PROVIDER=firebase --dart-define=BEFAM_FIREBASE_FUNCTIONS_REGION=asia-southeast1 --dart-define=BEFAM_DEFAULT_TIMEZONE=Asia/Ho_Chi_Minh
uv run --with-requirements requirements-docs.txt mkdocs build --strict
```

```bash
firebase emulators:start --only hosting --project be-fam-3ab23 --config firebase.json
curl route smoke for /, /app, /about-us, /befam-info, /privacy, /terms, /account-deletion, /manifest.json
curl header smoke for CSP, X-Content-Type-Options, X-Frame-Options, Referrer-Policy, Permissions-Policy
Playwright/Chromium screenshots and console/network smoke for desktop, tablet, mobile, public routes, and /app
Coordinate browser auth attempt with redacted staging phone/OTP; blocked at Firebase reCAPTCHA image challenge
```

## Verification Results

| Gate | Result |
| --- | --- |
| Flutter analyze | Pass |
| Web marketing widget tests | Pass, 8 tests |
| Optional live web smoke compile gate | Pass/skipped by default |
| Flutter web release build | Pass |
| MkDocs strict build | Pass via `uv run --with-requirements requirements-docs.txt mkdocs build --strict` |
| Firebase Hosting emulator route rewrites | Pass |
| Security headers | Pass |
| Responsive screenshots | Pass |
| Console errors / required failed requests | Pass |
| Staging login with redacted test phone/OTP | Blocked by Firebase reCAPTCHA |
| Post-login website QA | Not executed |

## Reports

- `docs/qa/QA_REPORT.md`
- `docs/qa/UI_UX_REVIEW.md`
- `docs/qa/DEV_FIX_LOG.md`
- `docs/qa/TECH_LEAD_REVIEW.md`
- `docs/qa/UI_UX_APPROVAL.md`
- `docs/qa/PRODUCT_REVIEW.md`
- `docs/qa/FINAL_RELEASE_REPORT.md`

## Deferred / Open Items

| ID | Severity | Status | Release-safe reason |
| --- | --- | --- | --- |
| `WEB-QA-005` | P1 | Open | Not release-safe. Required staging login was blocked by Firebase reCAPTCHA image challenge. |
| `PO-WEB-002` | P2 | Open | Not release-safe until login works; authenticated screens could not be reviewed. |

## Role Decisions

| Role | Decision |
| --- | --- |
| QA Leader | Public website pass; production not approved due login blocker. |
| Senior UI/UX QA | Public UI approved; authenticated UI not approved. |
| Dev Lead | Code/config fixes complete for discovered website issues. |
| Technical Lead | Code/config conditionally approved; auth proof blocker remains. |
| UI/UX Manager | Partial approval only. |
| Product Owner | Not ready for real-user production release. |

## Final Decision

Do **not** enable production Twilio or mark the website production-ready yet.
Resolve the reCAPTCHA/login verification path, complete a redacted post-login
website QA pass, then rerun QA, Technical Lead, UI/UX Manager, and Product Owner
sign-off.
