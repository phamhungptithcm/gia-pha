# BeFam Website Dev Fix Log

Date: 2026-05-18
Owner role: Dev Lead Agent
Scope: Website/browser release pass

## Fix Summary

| Issue | Status | Fix |
| --- | --- | --- |
| `WEB-QA-001` / `WEB-UIUX-001` | Fixed | Reworked static web footer from fixed overlay to compact page-flow/sticky behavior. |
| `WEB-UIUX-002` | Fixed | Adjusted tablet breakpoint so primary navigation stays visible longer. |
| `WEB-UIUX-003` | Fixed | Tuned mobile hero width and font size for better readability. |
| `WEB-UIUX-004` | Fixed | Normalized app entry CTA wording. |
| `WEB-QA-002` | Fixed | Added Firebase Hosting security headers and CSP allowances required by Flutter/Firebase web. |
| `WEB-QA-003` | Fixed/verified | Verified SPA rewrites through Firebase Hosting emulator instead of a plain static server. |
| `WEB-QA-004` | Fixed | Re-rendered public web metadata with production base URL. |
| `WEB-QA-005` | Open | Browser QA reached Firebase reCAPTCHA; needs human/test-bypass verification before production approval. |

## Files Changed

- `mobile/befam/web/index.template.html`
- `mobile/befam/web/index.html`
- `mobile/befam/web/robots.txt`
- `mobile/befam/web/sitemap.xml`
- `mobile/befam/lib/app/bootstrap/app_bootstrap.dart`
- `mobile/befam/lib/features/notifications/services/push_notification_service.dart`
- `mobile/befam/test/app/web/web_live_smoke_gate_test.dart`
- `mobile/befam/test/app/web/web_live_smoke_base_href_stub.dart`
- `mobile/befam/test/app/web/web_live_smoke_base_href_web.dart`
- `firebase.json`
- `.github/workflows/release-main.yml`
- `.github/workflows/deploy-staging.yml`
- `.github/workflows/deploy-web-hosting.yml`
- `scripts/audit_github_environment.sh`

## Implementation Notes

- Firebase bootstrap now reuses an already initialized default app only when the existing project matches the expected project. A mismatched project still fails closed.
- Web push background handler registration now no-ops on web because background handling belongs to the service worker.
- Production release workflows now require safer web config gates, including App Check site key when App Check is enabled.
- Web hosting deploy workflow now includes production route and header smoke checks.
- The optional live web smoke test is gated by dart-defines and avoids committing QA credentials.

## Verification Run

```bash
jq empty firebase.json
bash -n scripts/audit_github_environment.sh scripts/render_web_metadata.sh
ruby -e 'require "yaml"; %w[.github/workflows/release-main.yml .github/workflows/deploy-staging.yml .github/workflows/deploy-web-hosting.yml].each { |f| YAML.load_file(f); puts "OK #{f}" }'
```

```bash
cd mobile/befam
flutter analyze
flutter test test/app/web/web_marketing_pages_test.dart --dart-define=BEFAM_ALLOW_BUNDLED_FIREBASE_OPTIONS=true
flutter test --platform=chrome test/app/web/web_live_smoke_gate_test.dart --dart-define=BEFAM_E2E_RUN_LIVE=false
flutter build web --release --no-wasm-dry-run --dart-define=BEFAM_ALLOW_BUNDLED_FIREBASE_OPTIONS=true --dart-define=BEFAM_OTP_PROVIDER=firebase --dart-define=BEFAM_FIREBASE_FUNCTIONS_REGION=asia-southeast1 --dart-define=BEFAM_DEFAULT_TIMEZONE=Asia/Ho_Chi_Minh
uv run --with-requirements requirements-docs.txt mkdocs build --strict
```

## Remaining Blocker

`WEB-QA-005` remains open. The app reached Firebase reCAPTCHA in a real
browser, but the image challenge prevents automated OTP completion without a
human/manual QA step or staging test bypass.
