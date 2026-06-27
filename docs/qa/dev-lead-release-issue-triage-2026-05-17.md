# Dev Lead Release Issue Triage - BeFam

Date: 2026-05-17
Role: Dev Lead release pass
Scope: triage snapshot plus post-fix validation.
Inputs:

- `docs/qa/android-production-qa-2026-05-17.md`
- `docs/qa/technical-lead-review-2026-05-17.md`
- `docs/qa/ui-ux-manager-review-2026-05-17.md`
- `docs/qa/product-owner-review-2026-05-17.md`

## Post-Fix Validation Update

This file was first written as a triage snapshot. The implementation pass after
that snapshot is summarized in
`docs/qa/dev-lead-post-fix-validation-2026-05-17.md`.

Current validation result:

- `flutter analyze`: pass.
- `flutter test`: pass.
- Targeted Profile/notification regression tests: pass.
- Pixel 7 Android recheck captured pass evidence for BFQA-001, BFQA-002,
  BFQA-003, and BFQA-004 under `/tmp/befam-postfix-android-2026-05-17/`.

Mobile code now addresses the code-level QA items for permission snackbar
interception, event required-field validation, profile settings access, auth IME
padding, bottom sheet safe-area padding, profile/funds assistant FAB scope,
billing assistant routing, ad dismissal persistence, funds AI destination
handling, calendar long-load recovery, and funds first-submit validation.

Production release remains **NO-GO** until Product Owner release evidence is
complete for billing/VNPay, auth/governance, security rules, funds ledger,
events/reminders, scholarship, notifications, production config, CI state, and
final sign-off.

## Current Code Status Notes

Current worktree contains in-progress Flutter changes by another agent:

- `mobile/befam/lib/app/home/app_shell_page.dart`
- `mobile/befam/lib/core/widgets/app_feedback_states.dart`
- `mobile/befam/lib/features/ai/services/ai_assist_service.dart`
- `mobile/befam/lib/features/calendar/presentation/dual_calendar_workspace_page.dart`

This triage treats those uncommitted changes as "current code" for fix-status
classification. I did not edit or revert any code.

Status legend:

- **Addressed in current code; needs verification**: code now appears to cover
  the issue, but QA must recapture/re-run.
- **Partially addressed; needs dev follow-up**: current code reduces the issue
  but does not satisfy the release expectation.
- **Needs dev action**: no adequate current-code fix found.
- **Needs release evidence/action**: not primarily a code fix; release evidence,
  QA execution, Product approval, or operational proof is missing.

## Executive Decision

**Release readiness: NO-GO for production promotion.**

The current code appears to address several UX regressions from the technical and
UI reviews, but Product Owner P0/P1 release evidence blockers remain open. BeFam
cannot be promoted until the high-trust suites are evidenced: billing/VNPay,
security rules and cross-clan isolation, governance/auth variants, funds ledger,
events/reminders, scholarship, notifications, production config, and final
sign-off.

## P0 Issues

| ID | Source | Area | Issue | Fix status | Required next action |
| --- | --- | --- | --- | --- | --- |
| PO-P0-01 | Product Owner | Release evidence | Production exit criteria are not met; no completed execution report/sign-off found for the current RC. | **Needs release evidence/action** | Complete execution sheet/report with P0/P1 statuses, evidence links, defect IDs, CI state, and Product/QA/Engineering sign-off. |

## P1 Issues

| ID | Source | Area | Issue | Fix status | Required next action |
| --- | --- | --- | --- | --- | --- |
| BFQA-001 | Android QA | Permission UX / Funds | Location permission snackbar can intercept Funds FAB and open Android App Info after permission denial. | **Needs dev action** | Move permission failure out of cross-tab snackbar interception path, shorten/scope snackbar, or use inline event-form error. Re-run denial -> Funds FAB flow. |
| UIUX-P1-1 | UI/UX Manager | Events loading | Event tab can remain full-screen loading with no recovery action. | **Addressed in current code; needs verification** | Current code adds 2-second recovery copy, hides skeleton, and exposes `Thử lại`. QA must verify long-load behavior and decide whether 8-10s error/cached fallback is still required. |
| UIUX-P1-2 | UI/UX Manager | Funds validation | Fund required validation is not visible on first required-error attempts. | **Partially addressed; needs dev follow-up** | Current form has `fund-name-input` and validator, but no clear `Scrollable.ensureVisible`/post-failed-submit autovalidate behavior was found. Implement deterministic first-tap inline error/focus, then recapture XML. |
| PO-P1-01 | Product Owner | Billing/VNPay | Billing workspace, checkout states, callbacks, and entitlement activation are not evidenced. | **Needs release evidence/action** | Run BILL-001 through BILL-012 with staged/provider callback evidence and entitlement proof. |
| PO-P1-02 | Product Owner | Auth/privacy/governance | Child login, member claim, multi-clan switch, stale/unlinked session, trusted device, and role permissions are not evidenced. | **Needs release evidence/action** | Complete AUTH/CTX cases with before/after evidence. |
| PO-P1-03 | Product Owner | Security/privacy | Cross-clan isolation, server-only writes, role-scoped reads/writes, Storage deny cases are not proven. | **Needs release evidence/action** | Attach rules/emulator or staging proof for all P0 security/rules cases. |
| PO-P1-04 | Product Owner | Funds ledger | Funds list/validation visible, but create success, donation/expense, balance recalculation, treasurer assignment, member denial are not evidenced. | **Needs release evidence/action** | Run full funds suite with Firestore/backend balance evidence. |
| PO-P1-05 | Product Owner | Events/reminders | Event creation/editing, lunar recurrence, reminder dispatch, audience permissions, clan switch isolation are not evidenced. | **Needs release evidence/action** | Run EVT cases and recapture stable loaded calendar/event detail screens. |
| PO-P1-06 | Product Owner | Scholarship | Scholarship workflow has no release evidence. | **Needs release evidence/action** | Run SCH-001 through SCH-010 or explicitly defer/hide scholarship with Product approval. |
| PO-P1-07 | Product Owner | Notifications | Push token registration, inbox state, deep-links, foreground/background behavior, invalid-token cleanup are not evidenced. | **Needs release evidence/action** | Complete notification smoke with backend-triggered push and device evidence. |

## P2 Issues

| ID | Source | Area | Issue | Fix status | Required next action |
| --- | --- | --- | --- | --- | --- |
| BFQA-002 | Android QA | Event form validation | Event create form gives no visible validation when required fields are empty. | **Partially addressed; needs dev follow-up** | Current code shows snackbars for missing title/memorial recipient but does not provide inline errors or auto-scroll to the invalid field. Add deterministic field-level feedback or verify snackbar UX is accepted. |
| BFQA-003 | Android QA | Profile settings | `Mở cài đặt` row did not navigate. | **Addressed in current code; needs verification** | Current profile tile calls `_openSettings`. Re-run profile settings tap and overflow reachability. |
| BFQA-004 | Android QA | Auth keyboard | Phone OTP submit button is nearly clipped while keyboard is open. | **Partially addressed; needs verification/dev follow-up** | Current phone input supports IME done submit, but no explicit IME-safe pinned CTA/bottom-inset fix was confirmed. Re-run on Pixel 7; fix layout if button remains clipped. |
| TL-P2-1 | Technical Lead | AI / Billing CTA | Assistant can render Billing CTA that no longer navigates. | **Addressed in current code; needs verification** | Current shell routes `billing` assistant destination to `BillingWorkspacePage`; AI service also accepts `funds`. Add/confirm widget coverage. |
| TL-P2-2 | Technical Lead | Ads | Closing ad banner is no longer respected across tab navigation. | **Addressed in current code; needs verification** | Current `_selectDestination` no longer resets `_dismissAdBannerForSession`. Add/confirm close -> navigate -> still dismissed test. |
| UIUX-P2-1 | UI/UX Manager | Onboarding | Coach marks are too heavy for task screens. | **Needs dev action** | Reduce overlay weight/copy, suppress while loading/sheets are open, and recapture tree/home without blocked primary actions. |
| UIUX-P2-2 | UI/UX Manager | Assistant FAB | Assistant FAB competes with core actions on funds/profile. | **Addressed in current code; needs verification** | Current shell only allows persistent assistant on tree/events, removing it from funds/profile. Re-run funds/profile screenshots. |
| UIUX-P2-3 | UI/UX Manager | App bar loading | Top app bar spinner has weak context. | **Needs dev action** | Add semantic/tooltip context, replace long spinner with inline status, or remove if non-blocking. |
| UIUX-P2-4 | UI/UX Manager | Navigation label | Tab label inconsistent between `Gói` and `Quỹ`. | **Addressed in current code; needs verification** | Current shell destinations use `funds` for linked/unlinked index 3. Recapture startup/unlinked/linked labels. |
| PO-P2-01 | Product Owner | Visual QA evidence | Some screenshots are loading/overlay/intermediate states. | **Needs release evidence/action** | Recapture final steady-state screens after overlays are dismissed and loading completes. |
| PO-P2-02 | Product Owner | Permission UX | Notification permission appears with native English copy in an otherwise Vietnamese flow. | **Needs Product/UX action** | Decide whether to add Vietnamese rationale before system prompt or document current timing as acceptable. |

## P3 Issues

| ID | Source | Area | Issue | Fix status | Required next action |
| --- | --- | --- | --- | --- | --- |
| BFQA-005 | Android QA | Bottom sheets | Some modal sheet primary actions are clipped at bottom edge. | **Needs dev action or QA recheck after current layout work** | Sheets use view-inset padding, but Android QA found clipped CTAs. Re-run member/profile/fund sheets; add safe-area bottom padding if still clipped. |
| BFQA-006 | Android QA | AI / Profile | Profile AI FAB opens freeform chat surface. | **Addressed in current code; needs verification** | Current shell hides persistent assistant on profile. Confirm profile quality check remains bounded and no generic FAB appears. |
| TL-P3-1 | Technical Lead | Unlinked IA | Unlinked sessions expose Funds tab that leads to locked surface. | **Needs Product/dev action** | Decide unlinked index-3 destination: profile billing, join/create guidance, disabled tab, or remove until clan context exists. |
| TL-P3-2 | Technical Lead | Funds AI copy | Funds AI used generic helper copy and did not recognize `funds`. | **Addressed/mitigated in current code; needs verification** | Current AI service adds funds fallback/quick replies/destination, and shell hides persistent assistant on funds. Verify any remaining funds AI entry points are finance-safe. |
| TL-P3-3 | Technical Lead | Funds stale balance | Client-side expense validation can block valid transaction if balance is stale. | **Needs dev action** | Re-resolve balance before blocking or allow refresh/submit path while backend remains authoritative. |
| UIUX-P3-1 | UI/UX Manager | Visual density | Mobile style is polished but heavier than "clean, ít chữ" direction. | **Needs design/product action; non-blocking** | Defer to design polish pass unless Product marks as release-blocking. |
| UIUX-P3-2 | UI/UX Manager | Funds bottom padding | Fund list bottom content clipped by floating/nav layers. | **Addressed in current code; needs verification** | Current funds list bottom padding is `120 + safe area` for managers, and assistant is hidden on funds. Recapture fund list bottom. |
| UIUX-P3-3 | UI/UX Manager | Loading motion | Loading animation density should be reduced. | **Partially addressed; non-blocking** | Calendar recovery can hide skeleton after 2 seconds; broader `AppLoadingState` uses skeleton + spinner by default. Consider later polish. |
| PO-P3-01 | Product Owner | Traceability | Screenshot folder lacks test-case index mapping evidence to expected/actual outcomes. | **Needs release evidence/action** | Add QA evidence index mapping screenshots/logs to release case IDs. |

## Consolidated Fix Status

Likely addressed in current code, pending verification:

- Billing assistant CTA now routes to billing workspace.
- Ad banner dismissal appears sticky across tab navigation.
- Calendar loading now exposes recovery copy and retry after 2 seconds.
- Profile settings row is wired to settings.
- Persistent assistant FAB is hidden on funds/profile.
- Funds destination is recognized in AI service.
- Funds list bottom padding is improved.
- Shell tab 4 is consistently modeled as `funds`.

Still requiring dev/product action before release candidate sign-off:

- Onboarding overlay weight and task interference, if Product keeps it in the
  release scope.
- App-bar loading spinner context, if Product marks it blocking.
- Unlinked session funds-tab information architecture.
- Stale balance handling in expense creation.
- Final screenshot sweep for bottom-sheet safe-area behavior on the exact RC.

Still requiring release evidence/action before production:

- Completed release execution sheet and sign-off.
- Billing/VNPay entitlement suite.
- Auth/governance/multi-clan suite.
- Security rules/cross-clan/storage deny proof.
- Funds ledger and treasurer workflow evidence.
- Events/reminders/lunar recurrence evidence.
- Scholarship workflow evidence or explicit deferral.
- Notifications token/inbox/deep-link evidence.
- Stable final screenshots mapped to release case IDs.
- Production config and CI proof for the exact release commit.

## Verification Required After Agent Fixes

Minimum targeted verification before production release sign-off:

1. Complete the Product Owner release evidence suites for billing/VNPay,
   auth/governance, security rules, funds ledger, events/reminders,
   scholarship, notifications, CI, and production config.
2. Recapture funds/profile/tree/events steady-state screenshots with overlays
   dismissed and loading completed.
3. Product Owner release evidence checklist rerun against the exact RC commit.

## Final Readiness Conclusion

Current code movement is trending in the right direction for the UX regressions,
but **the release remains NO-GO**. The blocker is no longer only individual
mobile polish defects; it is the absence of complete evidence for BeFam's
high-trust production workflows and security boundaries.

Next release-pass gate: all P0 evidence closed, all P1 release-policy blockers
passed or explicitly deferred with Product approval and feature gating, and the
remaining P2/P3 mobile issues either verified fixed or accepted as non-blocking
with owner sign-off.
