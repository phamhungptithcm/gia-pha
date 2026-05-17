# Product Owner Release Readiness Review - BeFam

Date: 2026-05-17  
Reviewer role: Product Owner reviewer  
Scope: mobile release readiness for genealogy, events/memorials, funds, profile, auth/privacy, member/clan governance, and production release controls.  
Decision: **NO-GO for production release until blocker evidence gaps are closed.**

## Evidence Reviewed

- Product and release docs:
  - `docs/en/01-product/product-overview.md`
  - `docs/en/01-product/feature-spec.md`
  - `docs/en/05-devops/pre-release-qa-checklist.md`
  - `docs/vi/05-devops/release-test-plan.md`
  - `docs/vi/05-devops/production-release-runbook.md`
  - `docs/en/06-security/privacy-model.md`
  - `docs/en/05-devops/production-configuration.md`
- Code/test inventory:
  - `mobile/befam/lib/features/**`
  - `mobile/befam/test/**`
  - `mobile/befam/integration_test/**`
  - `firebase/functions/src/**`
  - `firebase/functions/src/contract-tests/**`
- Graph context:
  - `graphify-out/GRAPH_REPORT.md` shows core communities around auth/session, genealogy, calendar/events, funds, scholarship, billing, notifications, and Firebase rules/functions.
- Manual Android QA evidence:
  - `/tmp/befam-final-mobile-qa/android-device/0906660001/`
  - 31 screenshot/XML/summary steps covering phone OTP, home, tree, events tab, funds tab, profile tab, and add-fund validation.

No filled release execution sheet or final QA report was found in the screenshot folder. The checked-in release execution template still contains `NOT_RUN` statuses.

## Product Readiness Summary

The visible app shell is coherent and aligned with BeFam's clan-operations positioning: privacy-gated auth, linked clan context, genealogy tree, dual-calendar surface, funds surface, and profile all render on Android. The strongest visible evidence is for login reachability, basic tab navigation, tree read-only rendering, funds list rendering, and required validation on create-fund.

The release is **not ready for production sign-off** because the evidence does not prove the high-trust workflows that BeFam must protect: billing/VNPay entitlement activation, cross-clan privacy, role-based governance, fund transaction ledger correctness, event creation/reminders, scholarship review, notification deep-links, and production environment gates.

## Findings

| ID | Priority | Release impact | Area | Finding | Evidence | Required resolution |
| --- | --- | --- | --- | --- | --- | --- |
| PO-P0-01 | P0 | Blocker | Release evidence | Production exit criteria are not met. The release plan requires 100% P0 pass, >=95% P1 pass, green CI, and Product/QA/Engineering sign-off, but no completed execution report was found. The repo catalog has 106 release cases, including 61 P0; only 10 are mapped as automated cases. | `docs/vi/05-devops/release-test-plan.md`, `docs/vi/05-devops/release-test-execution-template.csv`, `mobile/befam/test/release/release_catalog_contract_test.dart`, screenshot folder has no report. | Provide completed execution sheet/report with statuses, evidence links, defect IDs, and explicit sign-off. |
| PO-P1-01 | P1 | Blocker under release policy | Billing/VNPay | Billing is marked live and release notes emphasize billing, but the Android QA evidence does not open the billing workspace, VNPay checkout, pending/failed/success states, or entitlement activation. Money and access rights cannot ship on assumption. | Product spec says billing/VNPay is live; release notes mention billing; screenshot evidence only shows `Quỹ`, not `Gói`/billing. | Run BILL-001 through BILL-012, including real/staged provider callbacks or controlled backend evidence, and verify pending/failed payments do not activate plans. |
| PO-P1-02 | P1 | Blocker under release policy | Auth/privacy/governance | Phone OTP happy path is visible, but child login, member claim, multi-clan switch, stale/unlinked session behavior, trusted device behavior, and role-dependent permissions are not evidenced in the manual QA set. | Screens `01`-`15` show privacy gate, OTP, notification permission, and home; no child/multi-clan/role test report found. | Complete AUTH-003/004/005/006/008/009/010 and CTX-001/002/005/006 with before/after evidence. |
| PO-P1-03 | P1 | Blocker under release policy | Security/privacy | Cross-clan isolation, safe self-profile updates, branch-scoped writes, server-only transaction writes, notification write protection, billing read restrictions, and Storage upload deny cases are not proven by current evidence. These are explicit hard requirements in the privacy model. | `docs/en/06-security/privacy-model.md`; release plan RULE-001 through RULE-012; no rules result report found. | Attach rules/emulator or staging proof for all P0 security/rules cases before production sign-off. |
| PO-P1-04 | P1 | Blocker under release policy | Funds | Funds list and create-fund validation are visible, but production-critical ledger behavior is not evidenced: create fund success, donation/expense transaction creation, balance recalculation, treasurer assignment, member denial, and server-only transaction write denial. | Screens `21`, `22`, `31`; `FUND-001` through `FUND-009` remain unreported. | Run the full funds suite, especially FUND-001/002/003/008, with Firestore/backend balance evidence. |
| PO-P1-05 | P1 | Blocker under release policy | Events/memorials | Calendar display is present, including solar/lunar labels, but event creation/editing, lunar annual memorial recurrence, reminder dispatch, audience permissions, and clan switch isolation are not evidenced. | `17-events-tab-summary.txt` shows calendar cells; screenshot `17-events-tab.png` captured a loading state. | Run EVT-001/002/004/007/008 and recapture a stable loaded calendar/event detail screen. |
| PO-P1-06 | P1 | Blocker under release policy | Scholarship | Scholarship is a live product capability and part of clan operations, but no Android screenshot or QA report covers program creation, award levels, submission, reviewer decision, audit log, disbursement, or notification. | Product docs and test plan include scholarship; no `/tmp/.../scholarship` evidence found. | Run SCH-001 through SCH-010 or explicitly defer/hide scholarship from production scope. |
| PO-P1-07 | P1 | Blocker under release policy | Notifications | Android system notification permission prompt appears after OTP, but there is no evidence for token registration, inbox pagination/read state, event/scholarship/billing deep-links, foreground/background behavior, or invalid token cleanup. | Screens `06`, `13`, `20`; release plan NOTIF-001 through NOTIF-008. | Complete notification smoke on a real device with backend-triggered push and inbox/deep-link evidence. |
| PO-P2-01 | P2 | Non-blocker if recaptured | Visual QA evidence | Some screenshots are not final-state evidence: the event screenshot shows a loading spinner while XML summary shows a loaded calendar; tree screenshot is partly blocked by onboarding; earlier funds evidence showed overlapping quick-action buttons before a later fixed capture. | `16-tree-tab.png`, `17-events-tab.png`, `18-funds-tab-summary.txt`, `21-funds-tab-fixed.png`. | Recapture final steady-state screens after overlays are dismissed and loading has completed. |
| PO-P2-02 | P2 | Non-blocker | Permission UX | Notification permission is requested immediately after OTP via native English copy. The app is otherwise Vietnamese. This is not a correctness blocker, but it may reduce opt-in clarity for Vietnamese users. | `06-after-otp-summary.txt`, `13-otp-entered-summary.txt`. | Consider an in-app Vietnamese rationale before the system prompt, or document why the current timing is acceptable. |
| PO-P3-01 | P3 | Non-blocker | Traceability | The screenshot folder is useful but lacks an index tying each image to release test case IDs and expected/actual outcomes. | `/tmp/befam-final-mobile-qa/android-device/0906660001/` contains step files only. | Add a short QA index/report mapping evidence files to AUTH/CTX/TREE/EVT/FUND/PRO/etc. cases. |

## Workflow Assessment

### Auth and Privacy

Visible pass evidence:

- Privacy consent gates login choices.
- Phone form validates required input.
- OTP flow reaches the linked clan shell.
- Home displays linked clan context after login.

Remaining gaps:

- Child login, claim flow, multi-clan switching, unlinked states, stale sessions, and trusted-device handling are not evidenced.
- Notification permission behavior is visible but not tied to token registration or push delivery.

### Genealogy and Clan Context

Visible pass evidence:

- Linked clan tree renders a large test dataset: 68 members and 5 branches.
- Tree controls for zoom, reset, export/print, and contextual quick action are present.
- The shell reflects a named clan context, not only an ID.

Remaining gaps:

- Relationship mutations, invalid-cycle prevention, branch-scoped write permission, member creation/edit, and multi-clan data isolation are not evidenced.
- Onboarding overlay should be dismissed for final tree release evidence.

### Events and Memorials

Visible pass evidence:

- Events tab exposes a dual-calendar workspace and lunar day labels in XML summary.
- Memorial-list and create-event entry points are present.

Remaining gaps:

- No event creation/edit/delete proof.
- No annual lunar memorial recurrence proof.
- No reminder or audience notification proof.
- The screenshot itself captured loading, so stable-state visual evidence should be refreshed.

### Funds

Visible pass evidence:

- Funds workspace shows fund list, selected fund, balances, status chips, edit buttons, and create action.
- Create-fund form shows required validation for fund name.

Remaining gaps:

- No successful fund creation proof.
- No income/expense transaction proof.
- No balance recalculation/ledger proof.
- No treasurer picker/role grant proof.
- No member-denied write proof.

### Profile

Visible pass evidence:

- Linked member profile renders identity, contact fields, address actions, social links, settings, and language display.

Remaining gaps:

- No edit-save evidence.
- No avatar upload evidence.
- No allowed-field/denied-field privacy proof.
- No unlinked profile empty-state proof.

### Billing and Production Readiness

Visible pass evidence:

- Code and docs include billing workspace, entitlement, IAP/VNPay-oriented lifecycle, and backend callables.

Remaining gaps:

- No mobile QA evidence for billing screen or checkout.
- No evidence of production secrets/env audit.
- No evidence of `subscriptionPackages` production catalog verification.
- No proof that App Check, pending timeout jobs, webhook signatures, and entitlement activation are configured for production.

## Acceptance Criteria for Production Release

Production release can be accepted only after all of the following are true:

1. Release execution report is completed for the current RC, with every P0 case marked PASS or explicitly deferred with Product approval and feature gating.
2. 61/61 P0 cases pass from the release catalog; P1 pass rate is >=95%; no open Sev-1/Sev-2 defects remain.
3. `flutter analyze`, `flutter test`, Functions build/test, Firebase rules tests, and required CI checks are green for the exact release commit.
4. Android and iOS real-device smoke tests cover OTP, child login, push notification background/deep-link, create genealogy/branch/member, events/memorial recurrence, funds transactions, scholarship review, billing/VNPay, and legal pages.
5. Billing acceptance passes: plan card reflects only active entitlement, upgrade/renew/downgrade constraints work, VNPay success/pending/failed states are correct, and failed/pending payments do not activate upgraded access.
6. Security acceptance passes: cross-clan reads/writes are denied, branch admin scope is enforced, server-only collections cannot be written by clients, notification mark-read is recipient-only, billing records are role-scoped, and Storage deny cases are verified.
7. Production config acceptance passes: GitHub production/staging environment audit succeeds, App Check is enforced, production Firebase database/config values are correct, signing secrets exist, `subscriptionPackages` contains active `FREE/BASE/PLUS/PRO`, and `app-ads.txt` has no placeholder.
8. Final QA evidence includes screenshots/videos/logs mapped to test case IDs, plus Product, QA, and Engineering sign-off.

## Go/No-Go Recommendation

**No-Go** for production promotion on the evidence currently available.

Recommended next action is not code work; it is release evidence closure:

- Fill the release execution sheet for the current RC.
- Run the missing high-trust suites: billing, rules/security, governance, funds ledger, scholarship, notifications, and event reminders.
- Recapture stable final-state screenshots after onboarding/loading overlays are cleared.
- Re-review once the execution report shows all P0 pass and the production runbook checks have evidence.
