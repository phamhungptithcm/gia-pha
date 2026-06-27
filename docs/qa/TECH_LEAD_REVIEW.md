# BeFam Website Technical Lead Review

Date: 2026-05-18
Reviewer role: Technical Lead Agent
Scope: Website/browser release readiness

## Decision

Technical status: **CONDITIONALLY APPROVED FOR PUBLIC WEBSITE / NOT APPROVED FOR FULL PRODUCTION RELEASE**.

The code/config changes improve web release safety: security headers, CSP,
metadata generation, deployment smoke checks, App Check environment gates, and
web bootstrap resilience are all in place and verified locally.

Full production release is blocked by missing successful staging login evidence.

## Findings

### TL-WEB-001

- Finding ID: `TL-WEB-001`
- Severity: `P1`
- File/line: `firebase.json`
- Problem: Hosting security headers were missing/incomplete for production web.
- Risk: Clickjacking, MIME sniffing, weak referrer posture, and accidental broad browser permissions.
- Required change: Add CSP, frame, content-type, referrer, and permissions policies.
- Status: `Fixed`

### TL-WEB-002

- Finding ID: `TL-WEB-002`
- Severity: `P1`
- File/line: `.github/workflows/release-main.yml`, `scripts/audit_github_environment.sh`
- Problem: Production web config allowed App Check enforcement without requiring a web reCAPTCHA site key.
- Risk: A production build could ship with App Check intended but not usable on web.
- Required change: Make `BEFAM_APP_CHECK_WEB_RECAPTCHA_SITE_KEY` required when App Check is enabled.
- Status: `Fixed`

### TL-WEB-003

- Finding ID: `TL-WEB-003`
- Severity: `P1`
- File/line: `.github/workflows/deploy-web-hosting.yml`
- Problem: Hosting deploy lacked post-deploy route/header smoke gates.
- Risk: Broken SPA rewrites or missing headers could reach production unnoticed.
- Required change: Smoke `/`, `/app`, legal routes, manifest, and required headers after deploy.
- Status: `Fixed`

### TL-WEB-004

- Finding ID: `TL-WEB-004`
- Severity: `P2`
- File/line: `mobile/befam/lib/app/bootstrap/app_bootstrap.dart`
- Problem: Bootstrap failed if a matching Firebase app had already been initialized.
- Risk: Browser/test runner reuse could show a failure state even when Firebase config is otherwise valid.
- Required change: Reuse existing Firebase app only when it matches the expected project; fail closed on mismatch.
- Status: `Fixed`

### TL-WEB-005

- Finding ID: `TL-WEB-005`
- Severity: `P2`
- File/line: `mobile/befam/lib/features/notifications/services/push_notification_service.dart`
- Problem: Web runtime attempted to register a native-style FCM background handler.
- Risk: Browser/test failures from unsupported messaging callback handling.
- Required change: No-op background handler registration on web and rely on service worker.
- Status: `Fixed`

### TL-WEB-006

- Finding ID: `TL-WEB-006`
- Severity: `P1`
- File/line: Staging Firebase Auth / QA environment
- Problem: Required staging phone login could not pass reCAPTCHA automation.
- Risk: Authenticated website release cannot be approved without verified login and post-login flow evidence.
- Required change: Complete manual redacted QA or configure a staging-only QA bypass/allowlist that preserves production controls.
- Status: `Open`

## Verification

- Static/config syntax: Passed.
- Flutter analyze: Passed.
- Web widget tests: Passed.
- Web build: Passed.
- Hosting emulator route/header smoke: Passed.
- Browser route screenshots: Passed.
- Live staging login: Blocked by reCAPTCHA image challenge.
