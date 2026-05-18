# BeFam Dev Fix Log

Date: 2026-05-17  
Role: Dev Lead Agent  
Scope: Android staging real-device QA fixes and release-loop report update

No raw staging phone number, OTP, verification ID, or profile-sensitive value is
recorded in this log.

## Fixes Completed In This Pass

### DEV-001 - Member Phone Lookup Required Error

- Issue: Empty `Tiếp tục` on the member phone lookup sheet could advance into
  manual creation.
- Files changed:
  - `mobile/befam/lib/features/member/presentation/member_workspace_page.dart`
  - `mobile/befam/test/widget_test.dart`
- Fix: `_MemberPhoneLookupSheetState._submit` now validates the phone field and
  keeps manual creation behind the explicit `Tạo mới thủ công` action.
- Test added: `member phone lookup requires a phone before continue`.
- Verification:
  - Targeted widget test passed.
  - Full Flutter test suite passed.
  - Pixel 7 retest passed with inline error.

### DEV-002 - Event Create CTA Order And Required Validation

- Issue: Event create sheet had weaker required treatment and the visible bottom
  action order made `Đóng` more prominent than `Tiếp tục`.
- Files changed:
  - `mobile/befam/lib/features/calendar/presentation/dual_calendar_workspace_page.dart`
  - `mobile/befam/test/features/events/event_widget_test.dart`
- Fix: Added required markers for title/memorial subject and placed the primary
  `Tiếp tục` action before secondary `Đóng`.
- Test updated: Event create validation test now asserts required labels/errors.
- Verification:
  - Targeted event widget tests passed.
  - Full Flutter test suite passed.
  - Pixel 7 retest passed with bottom CTA order and required error.

## Commands Run

```bash
npx gitnexus impact --repo gia-pha _MemberPhoneLookupSheetState --direction upstream
npx gitnexus impact --repo gia-pha _MemberEditorSheetState --direction upstream
npx gitnexus impact --repo gia-pha _EventEditorSheetState --direction upstream
dart format mobile/befam/lib/features/member/presentation/member_workspace_page.dart mobile/befam/lib/features/calendar/presentation/dual_calendar_workspace_page.dart mobile/befam/test/widget_test.dart mobile/befam/test/features/events/event_widget_test.dart
```

```bash
cd mobile/befam
flutter test test/widget_test.dart --name "member phone lookup requires a phone before continue|member add form blocks next step until required fields pass" --dart-define=BEFAM_ALLOW_BUNDLED_FIREBASE_OPTIONS=true
flutter test test/features/events/event_widget_test.dart --name "validates required title in unified create form|creates a new event from the create form" --dart-define=BEFAM_ALLOW_BUNDLED_FIREBASE_OPTIONS=true
flutter analyze
flutter test --coverage --dart-define=BEFAM_ALLOW_BUNDLED_FIREBASE_OPTIONS=true
flutter build apk --debug --dart-define=BEFAM_ALLOW_BUNDLED_FIREBASE_OPTIONS=true --dart-define=BEFAM_OTP_PROVIDER=firebase --dart-define=BEFAM_ENABLE_APP_CHECK=true
```

```bash
adb -s 34171FDH20027M install -r build/app/outputs/flutter-apk/app-debug.apk
adb -s 34171FDH20027M shell monkey -p com.familyclanapp.befam 1
adb -s 34171FDH20027M exec-out screencap -p
adb -s 34171FDH20027M exec-out uiautomator dump /dev/tty
adb -s 34171FDH20027M shell dumpsys gfxinfo com.familyclanapp.befam
```

## Verification Results

| Gate | Result |
| --- | --- |
| GitNexus impact lookups | Targets not indexed; impacted count `0`, risk `UNKNOWN`. |
| Dart format | Pass |
| Targeted member tests | Pass |
| Targeted event tests | Pass |
| Flutter analyze | Pass |
| Full Flutter tests | Pass, `270` passed / `1` skipped |
| Android debug APK build | Pass |
| Android install/launch on Pixel 7 | Pass |
| Member phone required retest | Pass |
| Event required/CTA retest | Pass |
| Funds required validation retest | Pass |
| Scholarship required validation retest | Pass |

## Open Items Not Fixed In Code

| ID | Status | Reason |
| --- | --- | --- |
| `QA-ANDROID-006` | Open / external | Store purchase/provider states require sandbox products, signed artifacts, and backend callback evidence. |
| `QA-ANDROID-007` | Open | Fresh clean-session OTP login was not rerun in this pass; existing authenticated session was preserved for screen testing. |
| `UIUX-ANDROID-003` | Deferred | Current plan shows ads; clean store screenshots require no-ad account/build or ad gating. |
| `UIUX-ANDROID-005` | Open | Full profile/release-mode performance pass is still needed. |

## Dev Lead Decision

The two code issues found in this pass are fixed and verified. Production
release remains blocked by external/provider evidence and incomplete full-matrix
QA, not by these two source fixes.
