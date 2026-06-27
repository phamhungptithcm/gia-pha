# BeFam Website QA Report

Date: 2026-05-18
Reviewer role: QA Leader Agent
Environment under test: Staging only
Primary platform: Website/browser
Native Android/iOS scope: Not tested in this website-only workflow

## QA Decision

QA status: **NOT APPROVED FOR PRODUCTION RELEASE**.

The website build, public routes, Firebase Hosting SPA rewrites, security
headers, and responsive public pages now pass the browser smoke gates. The app
entry page reaches the phone sign-in form and starts Firebase phone auth.

Production release is still blocked because the required staging login could
not be completed end-to-end in automated browser QA. Firebase reCAPTCHA opened
an image challenge during the live phone sign-in attempt. The staging phone and
OTP values are intentionally redacted from this report.

## Evidence Reviewed

| Evidence | Result | Notes |
| --- | --- | --- |
| Flutter analyze | Pass | `flutter analyze` returned `No issues found`. |
| Web marketing tests | Pass | 8 tests passed. |
| Optional web live smoke compile gate | Pass/skipped | Test compiles and is skipped unless live defines are supplied. |
| Web release build | Pass | `flutter build web --release --no-wasm-dry-run` succeeded. |
| Firebase Hosting emulator | Pass | `http://127.0.0.1:5002` served the current web build. |
| SPA route rewrites | Pass | `/`, `/app`, `/about-us`, `/befam-info`, `/privacy`, `/terms`, `/account-deletion`, `/manifest.json` all returned `200`. |
| Security headers | Pass | CSP, `X-Content-Type-Options`, `X-Frame-Options`, `Referrer-Policy`, and `Permissions-Policy` present. |
| Responsive screenshots | Pass | Desktop, tablet, mobile screenshots captured. |
| Console/network smoke | Pass with caveat | No app console errors or required failed requests. Headless Chromium emitted WebGL GPU stall warnings; GA beacon aborts were non-functional analytics noise. |
| Staging login | Blocked | Phone flow reached Firebase reCAPTCHA image challenge; automation stopped before OTP verification. |

Primary artifact folder:

`artifacts/qa/web-staging-release-2026-05-18/`

Key evidence files:

- `screens/web-home-after-csp-1440x900.png`
- `screens/web-home-tablet-after-csp-834x1112.png`
- `screens/web-home-mobile-after-csp-390x844.png`
- `screens/web-app-after-csp-1440x900.png`
- `screens/web-app-coordinate-checkbox.png`
- `logs/web-app-after-csp-console.txt`
- `logs/web-live-login-coordinate-run.txt`

## Functional Coverage

| Area | Status | Evidence |
| --- | --- | --- |
| Landing page | Verified | Desktop/tablet/mobile screenshots; no console errors. |
| Public navigation | Verified | Web tests and screenshots. |
| About / story pages | Verified | `200` route smoke and screenshots. |
| Privacy / terms / account deletion | Verified | `200` route smoke and screenshots. |
| App entry route | Verified to auth method step | `/app` rendered BeFam auth surface. |
| Privacy consent gate | Verified | Coordinate browser run toggled consent and enabled phone login. |
| Phone login form | Verified to reCAPTCHA | Phone form opened and submitted to Firebase auth. |
| OTP verification / AppShell | Blocked | reCAPTCHA challenge required human/test bypass. |

## Issues

### WEB-QA-001

- ID: `WEB-QA-001`
- Severity: `P1`
- Area: Website footer layout
- Platform: Website
- Browser/viewport: Chromium, desktop/tablet/mobile
- Environment: Staging emulator
- App build/version/commit: current working tree, 2026-05-18
- Steps to reproduce: Open landing page and scroll near footer.
- Expected result: Footer stays compact and does not cover main content.
- Actual result before fix: Fixed footer could overlap content and consume too much vertical space.
- Evidence: `screens/web-home-after-csp-1440x900.png`
- Suggested fix: Use normal-flow/sticky footer spacing instead of fixed overlay.
- Status: `Verified`
- Retest result: Footer no longer overlaps route content.

### WEB-QA-002

- ID: `WEB-QA-002`
- Severity: `P1`
- Area: Website security headers
- Platform: Website
- Browser/viewport: Hosting emulator / HTTP header smoke
- Environment: Staging emulator
- App build/version/commit: current working tree, 2026-05-18
- Steps to reproduce: Request `/` from Firebase Hosting emulator.
- Expected result: Security headers present without blocking Flutter web runtime.
- Actual result before fix: Headers were incomplete, then initial CSP blocked Flutter assets on deep routes.
- Evidence: `logs/web-app-after-csp-console.txt`
- Suggested fix: Add CSP and standard hardening headers, allow required Flutter/Firebase/Google origins.
- Status: `Verified`
- Retest result: Headers present; route screenshots render without console errors.

### WEB-QA-003

- ID: `WEB-QA-003`
- Severity: `P1`
- Area: SPA routing / deep links
- Platform: Website
- Browser/viewport: Firebase Hosting emulator
- Environment: Staging emulator
- App build/version/commit: current working tree, 2026-05-18
- Steps to reproduce: Open direct routes `/app`, `/privacy`, `/terms`, `/account-deletion`.
- Expected result: Each route returns `200` and renders the intended page.
- Actual result before fix: Simple static server testing produced false blank-route results; release needed Firebase Hosting rewrite proof.
- Evidence: route smoke output in final release report.
- Suggested fix: Verify using Firebase Hosting emulator and preserve SPA rewrite config.
- Status: `Verified`
- Retest result: All required routes returned `200`.

### WEB-QA-004

- ID: `WEB-QA-004`
- Severity: `P2`
- Area: Metadata / SEO
- Platform: Website
- Browser/viewport: Build artifact scan
- Environment: Staging build, production metadata target
- App build/version/commit: current working tree, 2026-05-18
- Steps to reproduce: Inspect generated `index.html`, `robots.txt`, and `sitemap.xml`.
- Expected result: Public metadata uses production web base URL and no localhost URLs.
- Actual result before fix: Generated metadata previously used local base values.
- Evidence: metadata scan returned no localhost matches in web/build outputs.
- Suggested fix: Re-render metadata with production base URL.
- Status: `Verified`
- Retest result: No localhost/callback/webhook strings found in generated web metadata.

### WEB-QA-005

- ID: `WEB-QA-005`
- Severity: `P1`
- Area: Staging login / Firebase phone auth
- Platform: Website
- Browser/viewport: Chromium 1440x900
- Environment: Staging emulator with staging Firebase config
- App build/version/commit: current working tree, 2026-05-18
- Steps to reproduce: Open `/app`, accept privacy policy, choose phone sign-in, submit the redacted staging phone, continue to OTP.
- Expected result: Staging login completes with the redacted OTP and reaches AppShell.
- Actual result: Firebase reCAPTCHA image challenge appeared and required human interaction, so OTP verification/AppShell was not proven.
- Evidence: `logs/web-live-login-coordinate-run.txt`; sensitive screenshot was deleted after local inspection.
- Suggested fix: Provide a browser-verifiable test bypass such as authorized test phone in Firebase Auth, reCAPTCHA test mode/allowlist for staging QA, or a manual QA checkpoint with screenshot redaction.
- Status: `Open`
- Retest result: Not passed. This remains the production release blocker.
