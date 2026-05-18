# BeFam Technical Lead Release Gate Review

Date: 2026-05-17  
Reviewer role: Technical Lead Agent  
Scope: Current diff after Android staging QA fixes, real-device evidence, and
release report updates

No raw staging phone number, OTP, verification ID, or profile-sensitive value is
recorded in this review.

## Decision

Technical source quality: **APPROVED FOR STAGING RC CONTINUATION**  
Production release readiness: **NOT READY**

The two latest source fixes are narrowly scoped, covered by widget tests, and
verified on the attached Pixel 7. They follow the existing Flutter
feature/controller/widget-test patterns and do not loosen clan, role, billing,
or privacy boundaries.

Production remains blocked by incomplete full release QA, missing clean-session
OTP retest, missing store/provider purchase proof, missing signed release
artifact proof, and incomplete profile/release-mode performance evidence.

## Findings

### TLR-ANDROID-001

- Finding ID: `TLR-ANDROID-001`
- Severity: `P1`
- File/line: `mobile/befam/lib/features/member/presentation/member_workspace_page.dart`
- Problem: Empty member phone lookup submit could route users into a different
  flow.
- Risk: Data-entry confusion in a sensitive member-management workflow.
- Required change: Validate empty phone and require explicit manual creation.
- Status: `Fixed`

### TLR-ANDROID-002

- Finding ID: `TLR-ANDROID-002`
- Severity: `P1`
- File/line: `mobile/befam/lib/features/calendar/presentation/dual_calendar_workspace_page.dart`
- Problem: Event create bottom actions and required fields made the primary
  next step less clear.
- Risk: High-friction event/memorial creation and failed invalid-submit
  recovery.
- Required change: Primary CTA first, required markers visible, invalid submit
  returns to the missing field.
- Status: `Fixed`

### TLR-ANDROID-003

- Finding ID: `TLR-ANDROID-003`
- Severity: `P2-critical`
- File/line: Billing/store provider surfaces and release configuration
- Problem: Package catalog is visible, but purchase, restore, receipt,
  callback, failure, and entitlement flows are not proven.
- Risk: Payment activation or entitlement errors could ship untested.
- Required change: Run App Store / Google Play sandbox/provider cases on signed
  artifacts.
- Status: `Open`

### TLR-ANDROID-004

- Finding ID: `TLR-ANDROID-004`
- Severity: `P1`
- File/line: Auth/session release gate
- Problem: This pass preserved the existing authenticated session and did not
  rerun a fresh phone OTP login from a clean install/session.
- Risk: Production cannot claim the complete first-run auth gate from this pass.
- Required change: Run clean-session staging OTP login with sanitized evidence
  before production approval.
- Status: `Open`

### TLR-ANDROID-005

- Finding ID: `TLR-ANDROID-005`
- Severity: `P2`
- File/line: Android performance/release profiling
- Problem: Fresh `gfxinfo` sample was taken on debug build and is too small for
  final performance approval.
- Risk: Debug frame data may overstate jank and does not prove release-mode
  smoothness.
- Required change: Capture profile/release-mode frame data for main flows.
- Status: `Open`

### TLR-ANDROID-006

- Finding ID: `TLR-ANDROID-006`
- Severity: `P2`
- File/line: Store screenshot pipeline
- Problem: Current ad-supported account shows test ad banner on Home.
- Risk: Store screenshots can look unpolished or expose test ad inventory.
- Required change: Use no-ad screenshot account/build or gate ads off for store
  capture; update Google Mobile Ads SDK in a dependency-hardening pass.
- Status: `Deferred`

## Verification

| Gate | Result |
| --- | --- |
| Impact analysis | Ran for touched private Flutter state classes; GitNexus returned no indexed symbols, impacted count `0`, risk `UNKNOWN`. |
| Formatting | Pass |
| Flutter analyze | Pass |
| Targeted member tests | Pass |
| Targeted event tests | Pass |
| Full Flutter tests | Pass, `270` passed / `1` skipped |
| Android APK build/install/launch | Pass on Pixel 7 |
| Real-device member/event retest | Pass |
| Real-device funds/scholarship validation spot-check | Pass |

## Technical Lead Approval

Source quality for the latest fixes: **Approved**.  
Production release: **Not approved** until open release gates are closed and
retested.
