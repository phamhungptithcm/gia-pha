# BeFam Android Production Readiness QA - 2026-05-17

## Summary

- Status: **Conditional pass / not production-ready until P1/P2 issues are triaged**.
- Tester role: QA Leader, mobile production readiness.
- Scope: Android device QA only. No source code changes were made.
- Device: Pixel 7, serial `34171FDH20027M`, Android 16.
- Package: `com.familyclanapp.befam`.
- Auth: phone `0906660001`, OTP/MFA `220197`.
- App state: `adb shell pm clear com.familyclanapp.befam` before test, then login from clean state.
- Evidence folder: `/tmp/befam-subagent-qa/android-production-qa-2026-05-17/`.
- Crash check: `/tmp/befam-subagent-qa/android-production-qa-2026-05-17/logcat_crash.txt` has 0 lines. No app crash observed.
- Note: device clock during execution was `Sat May 16 2026 CDT`; calendar correctly marked May 16 as "hôm nay" while this report file follows the requested May 17 QA name.

## Test Matrix

| Area | Cases covered | Result | Evidence |
| --- | --- | --- | --- |
| Auth / privacy / OTP | Clean launch, privacy gate, disabled login buttons before consent, privacy policy bottom sheet, phone empty validation, phone entry, OTP empty validation, OTP success login, double-tap submit attempts | Pass with UX issue BFQA-004 | `001`-`013` screenshots/XML |
| Home | Post-login home, onboarding coachmark 3 steps, home refresh double tap, empty upcoming events state, shortcuts visible | Pass | `016`-`020` |
| Bottom nav | Home, Gia phả, Sự kiện, Quỹ, Hồ sơ tab selection and selected state | Pass | `019`, `021`, `034`, `046`, `059` |
| Clan / tree | Clan management post-login, branch cards, genealogy tree load, zoom/reset/export controls visible, FAB menu, member list, member create precheck/manual form validation | Pass with layout issue BFQA-005 | `013`-`015`, `021`-`033` |
| Events / calendar / reminders | Solar/lunar toggle, month grid, day selection, selected-day detail, upcoming reminders empty state, event form, repeat/yearly switch visible, location permission request | Pass with issue BFQA-002 | `034`-`045` |
| Funds / fund forms / transaction forms | Funds overview, balances, fund list, dashboard/summary scroll, add fund form validation, fund detail, donation form validation, expense form validation | Pass with blocking issue BFQA-001 | `046`-`058` |
| Profile / settings | Profile data, contact/social actions visible, edit profile sheet, AI profile check block, save button visible, top overflow menu, settings row tap | Pass with issues BFQA-003, BFQA-005, BFQA-006 | `059`-`067` |
| Floating buttons | Genealogy add menu, profile AI FAB, events/funds AI FABs visible, event/fund action FABs | Mixed, see BFQA-001 and BFQA-006 | `025`, `034`, `046`, `066` |
| Permission dialog | Native Android location permission surfaced from "Vị trí của tôi"; denial returns to app | Pass with follow-on issue BFQA-001 | `044`, `045`, `049` |
| Error/loading/double tap prevention | Empty field validation on phone, OTP, member, fund, transaction forms; home refresh double tap; OTP submit double tap | Pass with issues BFQA-002, BFQA-004 | `006`, `011`, `020`, `030`, `041`, `052`, `056`, `058` |

## Issues

### BFQA-001 - P1 High - Location permission snackbar intercepts Funds FAB and opens Android App Info

- Screen: Quỹ tab after denying location permission from event form.
- Steps:
  1. Open Sự kiện tab.
  2. Open create event form.
  3. Tap `Vị trí của tôi`.
  4. Deny native Android location permission.
  5. Navigate to Quỹ tab.
  6. Tap the `Thêm quỹ` FAB while snackbar `Bạn chưa cấp quyền vị trí cho ứng dụng.` is visible.
- Expected: `Thêm quỹ` opens the fund creation form, or the snackbar does not overlap/block the FAB.
- Actual: tap is handled by snackbar action `Mở cài đặt`; Android App Info opens instead of the fund form.
- Evidence:
  - `/tmp/befam-subagent-qa/android-production-qa-2026-05-17/046_tab_funds.png`
  - `/tmp/befam-subagent-qa/android-production-qa-2026-05-17/049_add_fund_form.png`
  - `/tmp/befam-subagent-qa/android-production-qa-2026-05-17/049_add_fund_form.xml`
  - `/tmp/befam-subagent-qa/android-production-qa-2026-05-17/050_return_from_app_settings.png`
- Owner suggestion: Mobile UX/platform. Move snackbar above FAB/bottom nav, shorten duration, or use scoped inline permission error inside the event form.

### BFQA-002 - P2 Medium - Event create form gives no visible validation when continuing with required fields empty

- Screen: Tạo sự kiện sheet.
- Steps:
  1. Open Sự kiện tab.
  2. Tap `Tạo sự kiện`.
  3. Scroll to bottom of the form.
  4. Tap `Tiếp tục` with title/person fields empty.
  5. Scroll back to the top to check validation.
- Expected: required fields show inline errors and/or sheet auto-scrolls to the first missing required field.
- Actual: no visible error appeared in the current viewport or after scrolling back to the top; user gets no clear next action.
- Evidence:
  - `/tmp/befam-subagent-qa/android-production-qa-2026-05-17/038_event_create_form.png`
  - `/tmp/befam-subagent-qa/android-production-qa-2026-05-17/040_event_form_after_extra_scroll.png`
  - `/tmp/befam-subagent-qa/android-production-qa-2026-05-17/041_event_required_validation.png`
  - `/tmp/befam-subagent-qa/android-production-qa-2026-05-17/042_event_validation_top_check.png`
- Owner suggestion: Events/mobile. Add form validation for title and memorial person, disable continue until required fields are valid, or auto-scroll to first invalid field.

### BFQA-003 - P2 Medium - Profile settings row advertises "Mở cài đặt" but does not navigate

- Screen: Hồ sơ tab.
- Steps:
  1. Open Hồ sơ tab.
  2. Tap the `Tùy chọn Mở cài đặt Ngôn ngữ: Tiếng Việt` row.
  3. Tap left/center of the row to avoid the AI FAB.
  4. Open top overflow menu as alternate path.
- Expected: settings screen opens, or the row is not shown as a clickable settings entry.
- Actual: row remains no-op. Top overflow menu only shows clan switch/logout; settings is not reachable from this visible entry.
- Evidence:
  - `/tmp/befam-subagent-qa/android-production-qa-2026-05-17/059_tab_profile.png`
  - `/tmp/befam-subagent-qa/android-production-qa-2026-05-17/063_settings_or_profile_option_tap.png`
  - `/tmp/befam-subagent-qa/android-production-qa-2026-05-17/064_top_options_menu.png`
  - `/tmp/befam-subagent-qa/android-production-qa-2026-05-17/067_profile_settings_left_tap.png`
- Owner suggestion: Profile/settings. Wire the row to settings, expose settings in overflow, or remove clickable semantics until implemented.

### BFQA-004 - P2 Medium - Phone OTP submit button is nearly clipped while keyboard is open

- Screen: phone login.
- Steps:
  1. From clean auth screen, accept privacy.
  2. Open phone login.
  3. Enter `0906660001`.
  4. Attempt to tap `Nhận mã OTP` without dismissing keyboard.
- Expected: submit button remains comfortably tappable above keyboard or keyboard action submits.
- Actual: UI tree shows `Nhận mã OTP` compressed to bounds `[113,1441][513,1447]` in the visible scroll area while keyboard is open; taps did not advance until keyboard was dismissed.
- Evidence:
  - `/tmp/befam-subagent-qa/android-production-qa-2026-05-17/007_phone_entered.png`
  - `/tmp/befam-subagent-qa/android-production-qa-2026-05-17/008_otp_screen_after_double_tap.xml`
  - `/tmp/befam-subagent-qa/android-production-qa-2026-05-17/009_phone_keyboard_dismissed.png`
- Owner suggestion: Auth/mobile. Add bottom padding for IME, keep primary action pinned above keyboard, or support IME done action.

### BFQA-005 - P3 Low - Some modal sheet primary actions are clipped by the bottom edge

- Screen: member manual form and profile edit sheet.
- Steps:
  1. Open Gia phả > Add FAB > `Thêm thành viên` > `Tạo mới thủ công`.
  2. Observe `Tiếp tục`.
  3. Open Hồ sơ > `Chỉnh sửa`.
  4. Scroll to bottom and observe `Lưu hồ sơ`.
- Expected: primary actions have full height and safe-area padding on Pixel 7.
- Actual: actions are partially clipped at bottom edge in UI XML, e.g. member `Tiếp tục` bounds `[97,2349][405,2400]`, profile `Lưu hồ sơ` bounds `[97,2343][983,2400]`.
- Evidence:
  - `/tmp/befam-subagent-qa/android-production-qa-2026-05-17/029_member_manual_form.png`
  - `/tmp/befam-subagent-qa/android-production-qa-2026-05-17/030_member_manual_required_validation.png`
  - `/tmp/befam-subagent-qa/android-production-qa-2026-05-17/061_profile_edit_bottom.png`
- Owner suggestion: Mobile UI. Add modal bottom safe-area padding and ensure CTA height is fully visible before release.

### BFQA-006 - P3 Low - AI FAB opens a freeform chat surface from Profile

- Screen: Hồ sơ tab floating AI button.
- Steps:
  1. Open Hồ sơ tab.
  2. Tap `Mở trợ lý chat cho hồ sơ`.
- Expected: AI remains bounded to a high-intent workflow with explicit apply/review actions, per BeFam AI guardrails.
- Actual: a chat-like sheet opens with free text input and prompt suggestions. It is contextual, but still presents as a generic assistant surface.
- Evidence:
  - `/tmp/befam-subagent-qa/android-production-qa-2026-05-17/066_profile_ai_chat_second_tap.png`
  - `/tmp/befam-subagent-qa/android-production-qa-2026-05-17/066_profile_ai_chat_second_tap.xml`
- Owner suggestion: Product/AI. Reconfirm product direction. Prefer embedded task-specific checks like the profile quality checker over persistent freeform chat FABs.

## Passed Criteria And Evidence

- Auth privacy gate passed: login methods were not clickable until privacy was accepted.
  Evidence: `001_launch_clean.*`, `002_phone_disabled_tap.*`, `004_privacy_checked.*`.
- OTP login passed: empty OTP validation appeared and valid OTP opened the app.
  Evidence: `010_otp_screen.*`, `011_otp_empty_submit.*`, `013_after_otp_submit.*`.
- Home and bottom nav passed: all five tabs are present with selected semantics and no crash.
  Evidence: `019_home_ready.*`, `021_tab_genealogy.*`, `034_tab_events.*`, `046_tab_funds.*`, `059_tab_profile.*`.
- Genealogy tree passed basic load: tree shows 68 members, 5 branches, zoom/reset/export controls, and add FAB menu.
  Evidence: `021_tab_genealogy.*`, `023_genealogy_ready.*`, `025_genealogy_add_fab_menu.*`.
- Member add validation passed for required fields.
  Evidence: `027_member_add_form_or_sheet.*`, `030_member_manual_required_validation.*`.
- Calendar and reminders passed basic display: solar/lunar toggle works, selected day detail and upcoming reminders section render.
  Evidence: `035_events_lunar_toggle.png`, `037_events_day_detail_scrolled.*`.
- Native permission dialog passed: Android precise/approximate location dialog appeared and denial returned to app.
  Evidence: `044_location_permission_after_request.*`, `045_location_permission_denied_response.*`.
- Fund validation passed: add fund empty name validation appears; donation/expense empty amount validation appears.
  Evidence: `052_add_fund_required_validation.*`, `056_transaction_donation_validation.*`, `058_transaction_expense_validation.*`.
- Profile edit sheet passed basic load with existing data.
  Evidence: `060_profile_edit_form.*`, `061_profile_edit_bottom.*`.
- Stability passed for this exploratory run: no `FATAL EXCEPTION` in crash buffer.
  Evidence: `/tmp/befam-subagent-qa/android-production-qa-2026-05-17/logcat_crash.txt`.

## Commands / Evidence Notes

- Device/app reset: `adb -s 34171FDH20027M shell pm clear com.familyclanapp.befam`.
- Launch: `adb -s 34171FDH20027M shell am start -n com.familyclanapp.befam/.MainActivity`.
- Evidence capture pattern: `adb exec-out screencap -p`, `adb exec-out uiautomator dump /dev/tty`, then `ui_tree_summarize.py`.
- Logcat saved:
  - `/tmp/befam-subagent-qa/android-production-qa-2026-05-17/logcat_full.txt`
  - `/tmp/befam-subagent-qa/android-production-qa-2026-05-17/logcat_crash.txt`

## Production Readiness Recommendation

Do not ship as final production-ready until BFQA-001, BFQA-002, BFQA-003, and BFQA-004 are triaged. BFQA-001 directly blocks the fund creation path after a realistic permission-denial flow. BFQA-002 and BFQA-003 affect user task completion in core clan operations. BFQA-004 affects the first-run login funnel.
