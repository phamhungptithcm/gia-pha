# BeFam UI/UX Manager Review - Mobile/Web Consistency

Date: 2026-05-17
Reviewer role: UI/UX Manager
Scope: Android QA screenshots/XML under `/tmp/befam-final-mobile-qa/android-device/0906660001/`, plus targeted Flutter UI code read-only review.

## Executive Summary

Overall direction is strong: BF logo is present in the signed-in shell, bottom nav is recognizable, typography is consistent, and required-field treatment is visually clear when it appears. The main gaps are not brand direction; they are state clarity and mobile task ergonomics.

Top fixes should focus on:

- loading states that can sit too long without next action
- required errors that do not appear consistently on first submit in the fund form
- onboarding/assistant overlays competing with core clan workflows
- reducing visual weight and copy density on mobile

## P0 Findings

No P0 blockers found from the provided screenshots/XML.

## P1 Findings

### P1-1: Event tab can remain on a full-screen loading state with no recovery action

Evidence:

- Screenshot: `/tmp/befam-final-mobile-qa/android-device/0906660001/17-events-tab.png`
- XML/summary: `/tmp/befam-final-mobile-qa/android-device/0906660001/17-events-tab.xml`
- Code: `/Users/hunpeo97/Desktop/Workspace/Coder/gia-pha/mobile/befam/lib/features/calendar/presentation/dual_calendar_workspace_page.dart:166`
- Code: `/Users/hunpeo97/Desktop/Workspace/Coder/gia-pha/mobile/befam/lib/core/widgets/app_feedback_states.dart:5`

Observed:

- The screen shows only skeleton lines, spinner, and copy: `Đang tải lịch song song...`.
- There is no retry, cached fallback, or explanation if loading takes more than a short moment.
- The bottom nav and FABs remain visible, so the app looks alive while the main content is stuck.

Why it matters:

- Calendar/events are a core clan workflow. A blank loader with no escape path weakens trust and makes QA look flaky.

Recommendation:

- Keep `AppLoadingState` only for the first short load.
- After about 2 seconds, switch copy to `Lịch đang đồng bộ. Bạn vẫn có thể tạo sự kiện mới.` and show a compact `Thử lại` action.
- After 8-10 seconds, replace full-screen loading with an error/empty state card using the same `RefreshIndicator` path and `controller.refreshAll`.
- If cached events exist, render stale content immediately with a small top banner `Đang cập nhật...` instead of blocking the whole screen.

### P1-2: Fund required validation is not visible on the first required-error attempts

Evidence:

- No visible inline error: `/tmp/befam-final-mobile-qa/android-device/0906660001/23-add-fund-required-error.png`
- Still no visible inline error after retap: `/tmp/befam-final-mobile-qa/android-device/0906660001/24-add-fund-required-error-retap.png`
- Inline error finally visible: `/tmp/befam-final-mobile-qa/android-device/0906660001/31-add-fund-inline-required.png`
- XML without error node: `/tmp/befam-final-mobile-qa/android-device/0906660001/23-add-fund-required-error.xml`
- XML with `Tên quỹ là bắt buộc.`: `/tmp/befam-final-mobile-qa/android-device/0906660001/31-add-fund-inline-required.xml`
- Code: `/Users/hunpeo97/Desktop/Workspace/Coder/gia-pha/mobile/befam/lib/features/funds/presentation/fund_workspace_page.dart:1819`
- Code: `/Users/hunpeo97/Desktop/Workspace/Coder/gia-pha/mobile/befam/lib/features/funds/presentation/fund_workspace_page.dart:2636`

Observed:

- The `Tên quỹ *` field is required, but the first captured error states do not show the inline error.
- The error appears only later, after additional interaction/refocus.
- This makes `Tiếp tục` feel unresponsive.

Why it matters:

- Fund creation is a governance/finance flow. Required/error feedback must be immediate and deterministic.

Recommendation:

- On `fund-editor-next-step-button`, force inline validation and focus/scroll the first invalid field in the same frame.
- Add a field key for `fund-name-input` and call `Scrollable.ensureVisible` after validation fails.
- Set the sheet form to `AutovalidateMode.onUserInteraction` after the first failed submit.
- Keep the snackbar only as secondary feedback; the inline error must appear on first tap.

## P2 Findings

### P2-1: Onboarding coach marks are too heavy for task screens

Evidence:

- Home overlay: `/tmp/befam-final-mobile-qa/android-device/0906660001/14-after-otp-submit.png`
- Tree overlay: `/tmp/befam-final-mobile-qa/android-device/0906660001/16-tree-tab.png`
- XML: `/tmp/befam-final-mobile-qa/android-device/0906660001/16-tree-tab.xml`
- Code: `/Users/hunpeo97/Desktop/Workspace/Coder/gia-pha/mobile/befam/lib/app/home/app_shell_page.dart:233`

Observed:

- The dim layer covers most content and nav.
- The tree coach mark competes with the FAB, mini assistant launcher, nav item, and actual genealogy canvas.
- Copy is useful but long for a first-run overlay.

Recommendation:

- Reduce coach mark dim opacity to about 30-35%.
- Use a small anchored tooltip style for nav/FAB education, not a large modal card.
- Limit each coach mark to one title line and one short sentence.
- Never cover the selected bottom nav item or the primary task action being taught.
- Suppress coach marks while a screen is still loading or while a bottom sheet is open.

### P2-2: Assistant FAB competes with core actions on dense screens

Evidence:

- Funds: `/tmp/befam-final-mobile-qa/android-device/0906660001/21-funds-tab-fixed.png`
- Profile: `/tmp/befam-final-mobile-qa/android-device/0906660001/19-profile-tab.png`
- XML: `/tmp/befam-final-mobile-qa/android-device/0906660001/21-funds-tab-fixed.xml`
- Code: `/Users/hunpeo97/Desktop/Workspace/Coder/gia-pha/mobile/befam/lib/app/home/app_shell_page.dart:560`

Observed:

- The assistant launcher sits near transaction/FAB areas and overlaps the lower content region on funds/profile.
- On funds, there are two floating controls plus bottom nav; the left assistant bubble adds noise to a financial workflow.

Recommendation:

- Hide the assistant FAB on funds, create/edit fund sheets, and profile edit surfaces.
- Move assistant access into the overflow menu for finance/governance screens.
- If kept on dashboard only, reserve bottom padding equal to nav height + FAB height so it never covers content.
- Use assistant only in high-intent places such as profile quality check or event drafting, not as a persistent generic chat button.

### P2-3: Top app bar loading spinner has weak context

Evidence:

- Screenshot: `/tmp/befam-final-mobile-qa/android-device/0906660001/21-funds-tab-fixed.png`
- Code: `/Users/hunpeo97/Desktop/Workspace/Coder/gia-pha/mobile/befam/lib/app/home/app_shell_page.dart:1318`

Observed:

- A small spinner appears in the top-right app bar without visible label.
- It looks like a broken or still-loading icon next to the overflow menu.

Recommendation:

- If this is clan-context loading, use a tooltip/semantic label `Đang tải gia phả...`.
- If it lasts more than 1 second, show a compact top banner or snack-free inline state instead of a tiny anonymous spinner.
- If no action is blocked, remove the app-bar spinner and let the underlying screen show its own loading state.

### P2-4: Navigation label is inconsistent between `Gói` and `Quỹ`

Evidence:

- Summary shows `Gói Tab 4`: `/tmp/befam-final-mobile-qa/android-device/0906660001/07-home-after-notification-summary.txt`
- Later summaries show `Quỹ Tab 4`: `/tmp/befam-final-mobile-qa/android-device/0906660001/14-after-otp-submit-summary.txt`
- Code: `/Users/hunpeo97/Desktop/Workspace/Coder/gia-pha/mobile/befam/lib/app/home/app_shell_page.dart:1161`

Observed:

- The same destination appears as `Gói` in one captured state and `Quỹ` in later states.

Recommendation:

- Make tab 4 consistently `Quỹ` across linked/unlinked/loading states.
- If `Gói` means billing/package, move it into profile or overflow; do not reuse the funds tab slot.

## P3 Findings

### P3-1: Mobile visual style is polished but heavier than the requested "clean, ít chữ" direction

Evidence:

- Login: `/tmp/befam-final-mobile-qa/android-device/0906660001/01-login-start.png`
- Phone form: `/tmp/befam-final-mobile-qa/android-device/0906660001/02-phone-form.png`
- Home: `/tmp/befam-final-mobile-qa/android-device/0906660001/15-home-linked.png`
- Code: `/Users/hunpeo97/Desktop/Workspace/Coder/gia-pha/mobile/befam/lib/core/widgets/app_workspace_chrome.dart:35`
- Code: `/Users/hunpeo97/Desktop/Workspace/Coder/gia-pha/mobile/befam/lib/core/widgets/app_workspace_chrome.dart:101`

Observed:

- The lineage grid works as a brand motif but appears behind nearly every card/form.
- Large headings and large card radii make screens feel more like an onboarding poster than a daily operations tool.

Recommendation:

- Keep the BF logo and grid as the brand signature, but reduce grid opacity on form-heavy screens.
- Use the current large type only for top-level page titles; use tighter section headings inside cards/sheets.
- On auth, remove repeated titles such as `Chọn cách vào BeFam` appearing in both step card and form card.
- Keep most cards at 20-24 px top padding and avoid extra empty vertical space above primary forms.

### P3-2: Fund list is readable but bottom content is clipped by floating/nav layers

Evidence:

- Screenshot: `/tmp/befam-final-mobile-qa/android-device/0906660001/21-funds-tab-fixed.png`
- XML: `/tmp/befam-final-mobile-qa/android-device/0906660001/21-funds-tab-fixed.xml`
- Code: `/Users/hunpeo97/Desktop/Workspace/Coder/gia-pha/mobile/befam/lib/features/funds/presentation/fund_workspace_page.dart:2211`

Observed:

- The second fund card continues under the assistant/add FAB area and bottom nav.
- The page is usable, but scanning balances and status chips at the bottom is visually interrupted.

Recommendation:

- Increase bottom list padding on funds to at least `NavigationBar height + 96`.
- Prefer one primary floating action on the right; move secondary assistant access out of the floating layer.
- Keep fund cards fully visible before the nav starts.

### P3-3: Motion posture is mostly safe, but loading animation density should be reduced

Evidence:

- Motion code: `/Users/hunpeo97/Desktop/Workspace/Coder/gia-pha/mobile/befam/lib/core/widgets/app_motion.dart:3`
- Loading code: `/Users/hunpeo97/Desktop/Workspace/Coder/gia-pha/mobile/befam/lib/core/widgets/app_feedback_states.dart:46`
- Screenshot: `/tmp/befam-final-mobile-qa/android-device/0906660001/17-events-tab.png`

Observed:

- Page entrance/stagger animations are effectively disabled, which is good for comfort.
- Loading states combine skeleton shimmer plus spinner. On a long load this becomes visually busy.

Recommendation:

- Keep either skeleton or spinner, not both, after the first second.
- Respect `MediaQuery.disableAnimations` in skeleton shimmer as well as page transitions.
- Prefer static skeleton + concise status text for long-running loads.

## Positive Notes

- BF logo is visually distinct and consistently reinforces BeFam identity in the signed-in shell.
- Bottom navigation uses recognizable icons and selected-state emphasis.
- Required fields use `*` and inline red styling when validation appears.
- Form buttons have clear primary/secondary distinction.
- Motion is restrained; no major distracting transition was observed in the captured states.

## Suggested Implementation Order

1. Fix fund form first-submit required error and focus behavior.
2. Add timeout/retry/cached fallback behavior to calendar loading.
3. Reduce or defer onboarding overlays on dense task screens.
4. Move assistant out of persistent FAB placement on finance/governance screens.
5. Normalize tab 4 label to `Quỹ`.
6. Lighten grid/type density on auth and bottom-sheet forms.

## Verification To Run After Fixes

- Re-run Android screenshots for phone required, OTP loading, home, tree, events, funds, profile, and add-fund validation.
- Confirm XML contains the required error node immediately after first invalid `Tiếp tục`.
- Confirm events screen exits loading or shows retry by 8-10 seconds.
- Confirm assistant/onboarding controls do not overlap bottom nav, FABs, or bottom sheet actions.
