# BeFam Android QA Full Pass - 2026-05-17

## Executive Summary

- Release recommendation: **NO-GO**.
- Role: QA Leader.
- Scope: mobile/web release readiness coverage, Android physical-device execution where available, report-only change.
- Repo: `/Users/hunpeo97/Desktop/Workspace/Coder/gia-pha`.
- Branch: `hunpeolabs/ai-production-ux-pass`.
- Build SHA tested: `4c214bd`.
- App version: `1.0.0+1`.
- Android device: Pixel 7, serial `34171FDH20027M`, Android 16 API 36.
- Evidence folder: `/tmp/befam-android-qa-full-pass-2026-05-17`.
- GitNexus note: MCP tools were not exposed in this Codex session, so no `gitnexus_impact` or `gitnexus_detect_changes` was available. No source symbols were edited.

Primary blocker: both debug and live Android E2E smoke fail before the OTP screen/AppShell transition. This blocks real-device validation of home/tree/events/funds/profile/billing, billing/subscription checkout, role-gated actions, child access, and clan isolation UX.

## Commands Run

| Command | Result | Evidence |
| --- | --- | --- |
| `adb devices` | PASS: Android device `34171FDH20027M` detected. | terminal output |
| `flutter devices` | PASS: Pixel 7 detected as Android target. | terminal output |
| `BEFAM_E2E_ANDROID_DEVICE=34171FDH20027M BEFAM_E2E_FAST_MODE=true BEFAM_E2E_ANDROID_MAX_ATTEMPTS=1 ./scripts/run_mobile_e2e.sh debug android smoke` | FAIL: `AUTH-001` and `TREE-001` failed at OTP transition. | `/tmp/befam-android-qa-full-pass-2026-05-17/e2e-debug-android-smoke-machine.jsonl` |
| `flutter test integration_test/e2e_smoke_ci_test.dart -d 34171FDH20027M ... BEFAM_USE_MOCK_AUTH=true BEFAM_MOCK_AUTH_OTP=<staging-otp-redacted> ... --machine` | FAIL: same OTP transition failure with mock auth defines. | terminal output, screenshot/XML evidence |
| `BEFAM_E2E_ANDROID_DEVICE=34171FDH20027M BEFAM_E2E_TEST_PHONE=<staging-phone-redacted> BEFAM_E2E_TEST_OTP=<staging-otp-redacted> BEFAM_E2E_FAST_MODE=true BEFAM_E2E_ANDROID_MAX_ATTEMPTS=1 BEFAM_E2E_SKIP_DEP_PREP=true ./scripts/run_mobile_e2e.sh live android smoke` | FAIL: same OTP transition failure using provided phone/MFA. Test harness then hung in cleanup and was terminated. | `/tmp/befam-android-qa-full-pass-2026-05-17/e2e-live-android-smoke-machine.jsonl` |
| `flutter test test/features/billing test/features/funds test/features/security test/app/home/app_shell_billing_tab_test.dart test/app/web/web_marketing_pages_test.dart test/core/widgets/app_form_controls_test.dart` | PASS: 51 host-side tests passed. | terminal output |

## Execution Result

| Area | Status | Notes |
| --- | --- | --- |
| Android auth OTP smoke | **FAIL** | App did not transition to OTP screen or AppShell after sending OTP. |
| Provided credential path `<staging-phone-redacted>` / `<staging-otp-redacted>` | **FAIL** | Live smoke reproduced same OTP transition failure. |
| Android tree smoke | **BLOCKED/FAIL** | `TREE-001` failed because auth never reached AppShell. |
| Android billing workspace smoke | **BLOCKED** | Live smoke includes billing workspace, but auth failure blocked it. |
| Android navigation home/tree/events/funds/profile/billing | **BLOCKED** | Could not reach authenticated shell on this pass. |
| Android forms/double-tap/loading validation | **BLOCKED** | Device pass blocked before shell/forms; host-side targeted form tests passed. |
| Android security-visible gates | **BLOCKED** | No device validation for clan isolation, role gates, or child read-only access. |
| Host-side billing/funds/security/web regression tests | **PASS** | 51 tests passed, including billing, funds, security, bottom nav, web pages, form controls. |

## Defects

### BFQA-FULL-001 - P0 Blocker - Android OTP request does not transition to OTP screen or AppShell

- Area: Auth, release smoke, login.
- Severity: P0 Blocker.
- Affected cases: `AUTH-001`, `TREE-001`, live smoke gate.
- Environment: Pixel 7 Android 16 API 36, debug APK, Firebase project `be-fam-3ab23` in live smoke.
- Expected: after privacy consent, phone entry, and send OTP, app transitions to `otp-code-input` or authenticated `AppShellPage`.
- Actual: test waits until timeout and fails with `Không chuyển tới màn OTP hoặc AppShell sau khi gửi OTP.`
- Reproduction:
  1. Connect Pixel 7 `34171FDH20027M`.
  2. Run debug smoke command above.
  3. Observe failure in `loginWithPhone` at `integration_test/support/e2e_test_harness.dart:461`.
  4. Repeat with live command using phone `<staging-phone-redacted>` and OTP/MFA `<staging-otp-redacted>`.
- Evidence:
  - `/tmp/befam-android-qa-full-pass-2026-05-17/e2e-debug-android-smoke-machine.jsonl`
  - `/tmp/befam-android-qa-full-pass-2026-05-17/e2e-live-android-smoke-machine.jsonl`
  - `/tmp/befam-android-qa-full-pass-2026-05-17/auth-otp-transition-failure.png`
  - `/tmp/befam-android-qa-full-pass-2026-05-17/auth-otp-transition-failure-ui.xml`
  - `/tmp/befam-android-qa-full-pass-2026-05-17/live-auth-otp-transition-failure.png`
  - `/tmp/befam-android-qa-full-pass-2026-05-17/live-auth-otp-transition-failure-ui.xml`

### BFQA-FULL-002 - P0 Blocker - Billing/subscription release readiness cannot be signed off on Android

- Area: Billing, subscription, purchase readiness.
- Severity: P0 Blocker.
- Expected: verify Billing/Goi independently from Funds/Quy: plan display, entitlement, checkout, pending/success/fail states, role access, callback refresh, and non-billing role denial.
- Actual: Android live smoke never reached the billing workspace because auth failed first. No device evidence exists from this pass for Billing/VNPay/IAP subscription readiness.
- Reproduction:
  1. Run live Android smoke with provided phone/OTP command.
  2. Observe auth failure before tree or billing workspace steps.
- Evidence:
  - `/tmp/befam-android-qa-full-pass-2026-05-17/e2e-live-android-smoke-machine.jsonl`

### BFQA-FULL-003 - P1 High - Release automation coverage is too thin for high-trust workflows

- Area: Release test automation.
- Severity: P1 High.
- Expected: P0/P1 release workflows have runnable automation or explicit manual evidence: auth variants, clan isolation, billing, funds ledger, role gates, child read-only, events, notifications, profile, and web.
- Actual: release catalog has 106 cases, but only 10 automated release IDs are registered. Billing/Funds distinction and Billing/VNPay cases are present in the manual catalog but not automated in the registry.
- Evidence:
  - `mobile/befam/integration_test/support/release_case_catalog.dart`
  - `mobile/befam/integration_test/support/release_suite_registry.dart`
  - `/tmp/befam-android-qa-full-pass-2026-05-17/e2e-report-debug-android-smoke.md`

## Release Coverage Cases

The full release catalog contains 106 cases and should remain the sign-off baseline:

| Suite | Case IDs | Device status this pass |
| --- | --- | --- |
| Auth, Session, Identity | `AUTH-001` to `AUTH-010` | `AUTH-001` failed; others blocked/not run. |
| Clan Context & App Navigation | `CTX-001` to `CTX-008` | Blocked by auth. |
| Member, Relationship, Genealogy | `MEM-001` to `MEM-005`, `REL-001` to `REL-003`, `TREE-001` to `TREE-004` | `TREE-001` failed due auth; others blocked/not run. |
| Events & Dual Calendar | `EVT-001` to `EVT-008` | Blocked by auth. |
| Notifications | `NOTIF-001` to `NOTIF-008` | Blocked by auth. |
| Funds | `FUND-001` to `FUND-009` | Blocked by auth; host-side funds tests passed. |
| Scholarship | `SCH-001` to `SCH-010` | Blocked by auth. |
| Billing & VNPay | `BILL-001` to `BILL-012` | Blocked by auth; host-side billing tests passed only. |
| Profile, Localization, Nearby Relatives | `PRO-001` to `PRO-009` | Blocked by auth. |
| Security/Rules | `RULE-001` to `RULE-012` | Blocked on device; host-side security tests passed only. |
| Non-functional & Reliability | `NFR-001` to `NFR-008` | Blocked beyond startup/auth smoke. |

Additional web readiness cases to keep in the release sheet:

| ID | Priority | Test case | Expected |
| --- | --- | --- | --- |
| `WEB-001` | P1 | Landing page CTA navigation | CTA routes to intended page without broken route/state. |
| `WEB-002` | P1 | Narrow-width marketing navigation | Compact web navigation is usable and not clipped. |
| `WEB-003` | P1 | Auth/product handoff copy | Web copy does not imply Funds equals Billing/Subscription. |
| `WEB-004` | P2 | Localization/terminology sweep | Vietnamese/English terminology stays consistent: `Quy` for funds, `Goi/Subscription` for billing. |
| `WEB-005` | P2 | SEO/static build smoke | Static docs/web build has no broken route or asset failure. |

## Focus Areas From Request

| Focus | Coverage expectation | Result |
| --- | --- | --- |
| Billing/Subscription, not Funds | Run `BILL-001` to `BILL-012`; verify package plan, entitlement, checkout, pending/success/failure, role access; do not treat `FUND-*` as billing evidence. | **Blocked on Android**. Host billing tests passed. |
| Funds/Quy | Run `FUND-001` to `FUND-009`; verify ledger, transaction validation, treasurer, member denial, clan switch. | **Blocked on Android**. Host funds tests passed. |
| Auth OTP phone `<staging-phone-redacted>`, MFA `<staging-otp-redacted>` | Live Android smoke with provided values. | **Failed** at OTP transition. |
| Navigation | Verify Home, Tree, Events, Funds, Profile, Billing workspace/deep-link. | **Blocked** after auth failure. |
| Required validation | Phone, OTP, member, event, fund, transaction, billing contact forms. | **Blocked on Android**; host form controls/funds tests passed. |
| Double-tap/loading prevention | OTP send/verify, checkout, save forms, refresh, ledger transaction submit. | **Blocked on Android**; not signed off. |
| Clan isolation UX | Switch clan, stale/deep page, cross-clan data visibility, active clan header. | **Blocked**; rules/security host tests are not sufficient for release sign-off. |
| Role-gated actions | Clan admin, branch admin, member, treasurer, billing admin, reviewer. | **Blocked**. |
| Child access read-only | Child-code login, parent OTP, read-only profile/tree restrictions. | **Blocked**. |

## Host-Side Regression Signal

Passed command:

```bash
flutter test test/features/billing test/features/funds test/features/security test/app/home/app_shell_billing_tab_test.dart test/app/web/web_marketing_pages_test.dart test/core/widgets/app_form_controls_test.dart
```

Result: **51 tests passed**.

This is useful regression evidence, but it does not replace Android release sign-off because the physical-device flow fails before authenticated shell navigation.

## Open Release Exit Criteria

- Fix `BFQA-FULL-001` and rerun Android debug/live smoke.
- Rerun `AUTH-001`, `AUTH-003`, `AUTH-005`, `AUTH-009`, `AUTH-010` with device evidence.
- Run `BILL-001` to `BILL-012` separately from Funds and attach checkout/callback/entitlement evidence.
- Run `FUND-001` to `FUND-009` and attach ledger/balance/role-denial evidence.
- Run clan isolation and role-gate cases with explicit admin/member/child sessions.
- Run web cases `WEB-001` to `WEB-005` and attach route/build evidence.
- Attach final release execution sheet with pass/fail/blocker statuses and defect IDs.
