# BeFam UI/UX Release Gate Review

Date: 2026-05-17  
Reviewer role: Senior UI/UX QA Agent  
Branch: `hunpeolabs/staging-ai-production-ux-pass-linear`  
Primary evidence: Android real device, Pixel 7, staging session

## Decision

UI/UX status: **PARTIAL APPROVAL / PRODUCTION NOT APPROVED**.

The new BeFam direction is visible on the authenticated Android app: lighter
surface, BF identity, compact navigation, calmer Vietnamese copy, consistent
bottom tabs, and focused task screens for family tree, events, package, funds,
scholarship, and profile. The two highest-impact form issues found in the
latest device pass were fixed and retested on Pixel 7.

Production UI/UX is still not final because the pass was not a full release
matrix, store purchase states were not reviewed, store screenshots still need a
clean no-ad/sanitized account, and a fresh login journey was not re-executed.

## Evidence Reviewed

| Surface | Result | Evidence |
| --- | --- | --- |
| Home | Pass with ad caveat | `screens/48-home-post-rebuild.png` |
| Genealogy | Pass with onboarding overlay | `screens/49-genealogy-post-rebuild.png` |
| Events | Pass | `screens/50-events-post-rebuild.png` |
| Package catalog | Pass for catalog display | `screens/53-package-steady-post-rebuild.png` |
| Profile/settings | Pass | `screens/52-profile-post-rebuild.png`, `screens/54-profile-settings-post-rebuild.png` |
| Members | Fixed / verified | `screens/35-member-phone-required-fixed.png` |
| Funds | Pass | `screens/56-funds-post-rebuild.png`, `screens/58-fund-required-error-post-rebuild.png` |
| Scholarship | Pass | `screens/61-scholarship-post-rebuild.png`, `screens/64-scholarship-program-required-post-rebuild.png` |
| Motion/transition comfort | Acceptable in focused pass | No harsh slide transition observed during tab/sheet sweep; full motion audit still pending. |
| Accessibility/semantics | Needs polish | Some semantic labels expose implementation wording, and profile evidence contains sensitive values that must be redacted for public use. |

Artifact folder:

`artifacts/qa/android-staging-real-device-2026-05-17/`

## Feedback

### UIUX-ANDROID-001

- ID: `UIUX-ANDROID-001`
- Severity: `P1`
- Screen/component: Member add lookup sheet
- Problem: Empty `Tiếp tục` could move users into the manual creation flow.
- Why it matters: Users can accidentally enter a different flow without knowing
  whether they should search by phone or create manually.
- Recommended fix: Keep users on the lookup sheet and show explicit required
  guidance.
- Evidence: `screens/35-member-phone-required-fixed.png`
- Status: `Verified`
- Retest result: Fixed on Pixel 7. The sheet now shows
  `Hãy nhập số điện thoại hoặc chọn Tạo mới thủ công.`

### UIUX-ANDROID-002

- ID: `UIUX-ANDROID-002`
- Severity: `P1`
- Screen/component: Event create sheet
- Problem: Bottom action hierarchy favored `Đóng`; primary `Tiếp tục` was less
  visible, and required fields needed clearer treatment.
- Why it matters: Creating events and memorial dates is a core clan workflow.
  Invalid submit must be easy to recover from.
- Recommended fix: Put primary `Tiếp tục` first, add required markers, and
  scroll/focus the invalid field.
- Evidence: `screens/39-event-form-bottom-cta-fixed.png`,
  `screens/40-event-required-error-fixed.png`
- Status: `Verified`
- Retest result: Fixed on Pixel 7.

### UIUX-ANDROID-003

- ID: `UIUX-ANDROID-003`
- Severity: `P2`
- Screen/component: Home / ad layer / store screenshots
- Problem: A test ad banner appears on Home after relaunch for the current
  ad-supported package state.
- Why it matters: It is expected for a plan with ads, but it is poor evidence
  for App Store / Play Store screenshots and can obscure lower content.
- Recommended fix: Capture store screenshots with a no-ad QA account or
  screenshot build. Update the Google Mobile Ads SDK in a dependency-hardening
  pass.
- Evidence: `screens/31-post-install-current.png`,
  `screens/47-relaunch-after-back.png`
- Status: `Deferred`
- Retest result: Not fixed in this pass.

### UIUX-ANDROID-004

- ID: `UIUX-ANDROID-004`
- Severity: `P2`
- Screen/component: Package / purchase states
- Problem: Package catalog is clear, but purchase, pending, failure, restore,
  receipt, and entitlement states were not reviewed visually.
- Why it matters: Package purchase is a high-trust payment workflow and must be
  visually distinct from `Quỹ họ`.
- Recommended fix: Run store sandbox flows and capture each state after signed
  artifacts are ready.
- Evidence: `screens/53-package-steady-post-rebuild.png`
- Status: `Open / external evidence`
- Retest result: Catalog only; provider states not executed.

### UIUX-ANDROID-005

- ID: `UIUX-ANDROID-005`
- Severity: `P2`
- Screen/component: Full mobile motion/performance
- Problem: Focused device usage felt usable, but the only fresh frame snapshot
  is a short debug sample with 15.49% janky frames.
- Why it matters: Final release needs profile/release-mode motion evidence on
  representative flows, not only debug-mode screenshots.
- Recommended fix: Capture profile/release frame data for home -> members,
  events create, funds create, scholarship create, and package catalog.
- Evidence: `logs/02-gfxinfo-after-retest.txt`
- Status: `Open`
- Retest result: Not complete.

## UI/UX Sign-Off

- Android post-login visual sweep: **partial pass**
- Critical form UX fixes: **verified**
- Store screenshot readiness: **not ready**
- Package purchase UI states: **not reviewed**
- Production UI/UX approval: **not final**
