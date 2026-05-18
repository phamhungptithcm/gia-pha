# BeFam QA Report - Android Staging Device Pass

Date: 2026-05-17  
Reviewer role: QA Leader Agent  
Environment under test: **Staging only**  
Primary platform: **Android real device**  
Device: Pixel 7, serial `34171FDH20027M`, Android 16 / SDK 36  
App version/build: `1.0.0+1`, build SHA `9c365a1`

## QA Decision

QA status: **NOT APPROVED FOR PRODUCTION PUBLISH**.

The Android app now runs on the physical Pixel 7 and reaches the authenticated
AppShell with the existing staging session that the owner logged into before
this pass. The earlier "blocked before AppShell" condition is no longer true
for this device session.

QA is still not approving production because this pass did not complete the
full 106-case release matrix, did not rerun a fresh OTP login from a clean
session, did not prove store purchase/provider callbacks, and did not verify
signed release artifacts. No raw staging phone number, OTP, verification ID, or
profile-sensitive value is included in this report.

## Evidence Reviewed

| Evidence | Result | Notes |
| --- | --- | --- |
| Android target device | Pass | Pixel 7 serial `34171FDH20027M`, Android 16 / SDK 36. |
| Flutter analyze | Pass | `flutter analyze` returned `No issues found`. |
| Full Flutter tests | Pass | `flutter test --coverage --dart-define=BEFAM_ALLOW_BUNDLED_FIREBASE_OPTIONS=true`: `270` passed, `1` skipped. |
| Android staging debug build | Pass | `flutter build apk --debug --dart-define=BEFAM_ALLOW_BUNDLED_FIREBASE_OPTIONS=true --dart-define=BEFAM_OTP_PROVIDER=firebase --dart-define=BEFAM_ENABLE_APP_CHECK=true`. |
| Android install/launch | Pass | `adb install -r` succeeded; `mCurrentFocus` confirmed BeFam `MainActivity`. |
| Authenticated AppShell | Pass for existing session | Home, genealogy, events, package, profile, settings, funds, scholarship, and member screens were reachable after install/relaunch. |
| Post-fix real-device retest | Pass | Member phone lookup, event create validation/CTA order, fund required validation, and scholarship program validation were retested on Pixel 7. |
| Logcat sample | Pass with caveat | No fatal crash/ANR in sampled log. Google Mobile Ads SDK is outdated and ad surfaces remain visible on the current ad-supported plan. |
| Frame timing snapshot | Needs follow-up | `dumpsys gfxinfo`: 71 frames, 11 janky frames, p50 5 ms, p95 42 ms during a small debug/session sample. Not sufficient for final performance approval. |

Primary artifact folder:

`artifacts/qa/android-staging-real-device-2026-05-17/`

Key evidence files:

- `screens/35-member-phone-required-fixed.png`
- `ui/35-member-phone-required-fixed-summary.txt`
- `screens/39-event-form-bottom-cta-fixed.png`
- `ui/39-event-form-bottom-cta-fixed-summary.txt`
- `screens/40-event-required-error-fixed.png`
- `ui/40-event-required-error-fixed-summary.txt`
- `screens/48-home-post-rebuild.png`
- `screens/49-genealogy-post-rebuild.png`
- `screens/50-events-post-rebuild.png`
- `screens/53-package-steady-post-rebuild.png`
- `screens/54-profile-settings-post-rebuild.png`
- `screens/56-funds-post-rebuild.png`
- `screens/58-fund-required-error-post-rebuild.png`
- `screens/61-scholarship-post-rebuild.png`
- `screens/64-scholarship-program-required-post-rebuild.png`
- `logs/02-package-after-rebuild.txt`
- `logs/02-post-fix-retest-logcat.txt`
- `logs/02-gfxinfo-after-retest.txt`

Some local screenshots/UI trees contain staging user/profile data and must not
be uploaded to stores or shared publicly without redaction.

## Android Staging Coverage

| Area | Status | Evidence |
| --- | --- | --- |
| Home/AppShell | Pass | `48-home-post-rebuild` |
| Genealogy tree | Pass with onboarding overlay | `49-genealogy-post-rebuild` |
| Events/calendar | Pass | `50-events-post-rebuild` |
| Package/catalog | Pass for catalog display | `53-package-steady-post-rebuild` |
| Profile/settings | Pass | `52-profile-post-rebuild`, `54-profile-settings-post-rebuild` |
| Members | Pass after fix | `33`-`35` member captures |
| Funds | Pass for list and required validation | `56`-`58` fund captures |
| Scholarship | Pass for list and required validation | `61`-`64` scholarship captures |
| Store purchase | Not executed | Sandbox/provider proof missing |
| Fresh OTP login | Not re-executed | Existing authenticated staging session was preserved |
| Full 106-case release suite | Not complete | This was a focused real-device screen/form pass |

## Issues

### QA-ANDROID-001

- ID: `QA-ANDROID-001`
- Severity: `P1`
- Area: Member form validation
- Platform: Android real device
- Device model / OS version: Pixel 7 / Android 16
- Environment: Staging
- App build/version: `1.0.0+1`
- Steps to reproduce: Open Members, tap Add member, leave phone empty, tap
  `Tiếp tục`.
- Expected result: Stay on the phone lookup sheet and show a clear required
  error, or require the user to choose manual creation explicitly.
- Actual result before fix: Empty `Tiếp tục` could advance into manual creation.
- Fix: Empty phone now keeps the user on the lookup sheet and shows
  `Hãy nhập số điện thoại hoặc chọn Tạo mới thủ công.`
- Evidence: `screens/35-member-phone-required-fixed.png`,
  `ui/35-member-phone-required-fixed-summary.txt`
- Suggested fix: Done.
- Status: `Verified`
- Retest result: Passed on Pixel 7 after rebuild.

### QA-ANDROID-002

- ID: `QA-ANDROID-002`
- Severity: `P1`
- Area: Event create form validation and CTA order
- Platform: Android real device
- Device model / OS version: Pixel 7 / Android 16
- Environment: Staging
- App build/version: `1.0.0+1`
- Steps to reproduce: Open Events, tap Create event, leave title empty, scroll
  to the bottom, tap `Tiếp tục`.
- Expected result: Primary action is visible and first; app scrolls back to the
  invalid field and shows a required error.
- Actual result before fix: `Đóng` was the more visible bottom action while
  `Tiếp tục` was lower in the sheet; required markers were weaker.
- Fix: `Tiếp tục` now appears before `Đóng`; required labels and inline error
  are visible.
- Evidence: `screens/39-event-form-bottom-cta-fixed.png`,
  `screens/40-event-required-error-fixed.png`
- Suggested fix: Done.
- Status: `Verified`
- Retest result: Passed on Pixel 7 after rebuild.

### QA-ANDROID-003

- ID: `QA-ANDROID-003`
- Severity: `P2`
- Area: Funds form validation
- Platform: Android real device
- Device model / OS version: Pixel 7 / Android 16
- Environment: Staging
- App build/version: `1.0.0+1`
- Steps to reproduce: Open Funds, tap Add fund, leave name empty, tap
  `Tiếp tục`.
- Expected result: Form stays open and shows the missing fund name.
- Actual result: `Tên quỹ là bắt buộc.` is shown inline.
- Evidence: `screens/58-fund-required-error-post-rebuild.png`
- Suggested fix: None.
- Status: `Verified`
- Retest result: Passed.

### QA-ANDROID-004

- ID: `QA-ANDROID-004`
- Severity: `P2`
- Area: Scholarship program validation
- Platform: Android real device
- Device model / OS version: Pixel 7 / Android 16
- Environment: Staging
- App build/version: `1.0.0+1`
- Steps to reproduce: Open Scholarship, tap Add new, choose Add program, leave
  title empty, tap `Tiếp tục`.
- Expected result: Form stays open and shows the missing program title.
- Actual result: `Vui lòng nhập tiêu đề chương trình.` is shown inline.
- Evidence: `screens/64-scholarship-program-required-post-rebuild.png`
- Suggested fix: None.
- Status: `Verified`
- Retest result: Passed.

### QA-ANDROID-005

- ID: `QA-ANDROID-005`
- Severity: `P2`
- Area: Ads / store screenshot readiness
- Platform: Android real device
- Device model / OS version: Pixel 7 / Android 16
- Environment: Staging
- App build/version: `1.0.0+1`
- Steps to reproduce: Relaunch the authenticated app on the current package.
- Expected result: Store/release screenshots are clean, or captured with a
  no-ad account/package state.
- Actual result: A test ad banner appears on Home for the current ad-supported
  package state. Logcat also reports the Google Mobile Ads SDK can be updated.
- Evidence: `screens/31-post-install-current.png`,
  `screens/47-relaunch-after-back.png`, `logs/01-home-logcat.txt`
- Suggested fix: Use a no-ad/screenshot QA account for store captures, or gate
  ads off in screenshot builds. Plan a dependency update for `google_mobile_ads`.
- Status: `Deferred`
- Retest result: Not release-blocking for ad-supported plan behavior, but still
  blocks clean store screenshot capture.

### QA-ANDROID-006

- ID: `QA-ANDROID-006`
- Severity: `P2-critical`
- Area: Package purchase / store provider
- Platform: Android real device
- Device model / OS version: Pixel 7 / Android 16
- Environment: Staging
- App build/version: `1.0.0+1`
- Steps to reproduce: Open Package and attempt store purchase, restore,
  receipt validation, callback refresh, failure and pending states.
- Expected result: Store/provider flows are proven with sandbox evidence.
- Actual result: Package catalog displays correctly, but purchase/provider
  sandbox cases were not executed in this pass.
- Evidence: `screens/53-package-steady-post-rebuild.png`
- Suggested fix: Run App Store / Google Play sandbox cases after signed
  artifacts and store products are configured.
- Status: `Open / external evidence`
- Retest result: Not executed.

### QA-ANDROID-007

- ID: `QA-ANDROID-007`
- Severity: `P1`
- Area: Fresh OTP login gate
- Platform: Android real device
- Device model / OS version: Pixel 7 / Android 16
- Environment: Staging
- App build/version: `1.0.0+1`
- Steps to reproduce: Clear app session or install fresh, then complete phone
  OTP login with QA-only staging credentials supplied out of band.
- Expected result: OTP login reaches AppShell.
- Actual result: This pass used the already-authenticated device session and
  did not rerun the fresh OTP flow to avoid disrupting the owner's live session.
- Evidence: `48-home-post-rebuild` through `64-scholarship-program-required`
  prove authenticated session availability, not fresh login.
- Suggested fix: Schedule a clean-session OTP retest before production publish.
- Status: `Open`
- Retest result: Not executed in this pass.

## QA Sign-Off

- P0 open: `0`
- P1 open: `1` (`QA-ANDROID-007`)
- P2-critical open: `1` (`QA-ANDROID-006`)
- P2 deferred: `1` (`QA-ANDROID-005`)
- Real-device AppShell: **PASS**
- Focused screen/form retest: **PASS**
- Full release suite: **NOT COMPLETE**
- QA approval: **NOT APPROVED FOR PRODUCTION**

Production publish remains blocked until a fresh staging login is retested, the
full release matrix is completed, store/provider purchase flows are proven, and
signed release artifacts are generated.
