# Dev Lead Billing/Funds/Security Triage - BeFam

Date: 2026-05-17
Branch: `hunpeolabs/ai-production-ux-pass`
Role: Dev Lead triage
Scope: read-only code review plus existing QA report synthesis for billing,
funds, and security blockers. No implementation files were edited.

## Inputs Reviewed

- `docs/qa/android-production-qa-2026-05-17.md`
- `docs/qa/technical-lead-review-2026-05-17.md`
- `docs/qa/ui-ux-manager-review-2026-05-17.md`
- `docs/qa/product-owner-review-2026-05-17.md`
- `docs/qa/dev-lead-release-issue-triage-2026-05-17.md`
- `docs/qa/dev-lead-post-fix-validation-2026-05-17.md`
- Billing code under `mobile/befam/lib/features/billing` and
  `firebase/functions/src/billing`
- Funds code under `mobile/befam/lib/features/funds` and
  `firebase/functions/src/funds`
- Security rules and tests under `firebase/firestore.rules`,
  `firebase/storage.rules`, and `firebase/functions/src/*rules*`

## Tooling Notes

- `graphify-out/GRAPH_REPORT.md` was reviewed first. Relevant graph hubs are
  auth/session, billing, funds, AI, notifications, and Firebase services.
- `npx gitnexus status` reports the `gia-pha` index is up to date at commit
  `4c214bd`.
- GitNexus impact checks run:
  - `loadBillingWorkspace`: LOW, 0 indexed upstream dependents.
  - `verifyInAppPurchase`: LOW, 0 indexed upstream dependents.
  - `recordFundTransaction`: LOW, 0 indexed upstream dependents.
  - `recalculateFundBalanceFromTransaction`: LOW, direct dependent
    `firebase/functions/src/funds/transaction-triggers.ts`, indirect export
    through `firebase/functions/src/index.ts`.
- Manual risk is higher than GitNexus output because billing, funds, and rules
  are payment/security critical paths.

## Executive Decision

Production remains **NO-GO** for billing/funds/security.

The mobile UX defects from the first QA pass are reported as fixed and
rechecked in `dev-lead-post-fix-validation-2026-05-17.md`. The remaining
blockers are now release-contract and high-trust evidence blockers, with one
finance client-side correctness risk still worth fixing before final RC if
Product expects concurrent treasurer workflows.

## Top Blockers

| ID | Priority | Area | Decision | Owner |
| --- | --- | --- | --- | --- |
| BSEC-001 | P0 | Billing product contract | Release evidence asks for VNPay, but current backend is IAP-only. Product must decide whether VNPay is still in scope or release docs/test cases must be changed to IAP. | Product Owner + Technical Lead |
| BSEC-002 | P1 | Billing entitlement evidence | No staged/provider proof that success activates entitlement and pending/failed/expired purchase does not. | Technical Lead |
| BSEC-003 | P1 | Security/rules evidence | Cross-clan isolation, billing read restrictions, server-only transaction writes, and Storage deny cases are not evidenced for the exact RC. | Technical Lead |
| BSEC-004 | P1 | Funds ledger evidence | Fund create, donation, expense, balance recalculation, treasurer assignment, member denial, and backend balance proof remain unevidenced. | Technical Lead + Product Owner |
| BSEC-005 | P2 | Funds stale balance UX | Client expense validation can reject a valid expense using the sheet-open balance before backend rechecks current balance. | Technical Lead |

## Billing Triage

### BSEC-001: VNPay vs IAP-only release contract mismatch

Current code indicates payments are now store-IAP based:

- `firebase/functions/src/billing/webhooks.ts:1` says card payment webhooks were
  removed and payments are processed exclusively through Apple/Google IAP.
- `firebase/functions/src/billing/callables.ts:421` exports
  `verifyInAppPurchase`, which verifies store purchases and applies entitlement.
- `mobile/befam/lib/features/billing/services/store_iap_gateway.dart:35`
  implements the client store checkout gateway.
- `docs/en/04-backend/cloud-functions.md:86` through `:94` still describe
  `createSubscriptionCheckout`, `simulateVnpaySettlement`, `cardPaymentCallback`,
  and `vnpayPaymentCallback`.

Likely fix scope depends on Product decision:

- If VNPay is still required for this release: likely backend work in
  `firebase/functions/src/billing/callables.ts`,
  `firebase/functions/src/billing/store.ts`, `firebase/functions/src/billing/webhooks.ts`,
  runtime config, mobile checkout UI, contract tests, and release docs. Risk:
  **CRITICAL**.
- If IAP replaces VNPay for this release: update release checklist/docs/case IDs
  from VNPay to Apple/Google IAP and collect store-provider evidence. Risk:
  **HIGH** because it changes release acceptance wording, but code scope is docs
  plus QA evidence.

### BSEC-002: Entitlement activation evidence missing

Likely files/symbols if a code issue appears during evidence run:

- `firebase/functions/src/billing/callables.ts:421`
  `verifyInAppPurchase`
- `firebase/functions/src/billing/iap-verification.ts:107`
  `verifyInAppStorePurchase`
- `firebase/functions/src/billing/subscription-lifecycle.ts:72`
  `buildEntitlement`
- `firebase/functions/src/billing/store.ts` payment transaction, invoice,
  subscription, audit log helpers
- `mobile/befam/lib/features/billing/presentation/billing_controller.dart:164`
  `verifyInAppPurchase`
- `mobile/befam/lib/features/billing/services/firebase_billing_repository.dart:99`
  `verifyInAppPurchase`
- `mobile/befam/lib/features/billing/presentation/billing_workspace_page.dart:204`
  checkout action path

Risk: **CRITICAL** for production because this controls paid access,
subscription status, ad entitlement, audit log, and billing notification state.

Required tests/evidence:

- `cd firebase/functions && npm run build && npm test`
- Billing contract tests plus targeted IAP product mapping and inactive/expired
  purchase cases.
- `cd mobile/befam && flutter test test/features/billing/billing_workspace_page_test.dart test/features/billing/billing_repository_test.dart`
- Staged Apple/Google purchase success, canceled, failed, expired, replay, and
  product-plan mismatch evidence.
- Firestore evidence for `subscriptions`, `paymentTransactions`,
  `subscriptionInvoices`, `billingAuditLogs`, user entitlement snapshot, and
  app UI refresh after purchase.

## Funds Triage

### BSEC-004: Funds ledger evidence missing

Current server-side transaction path is the right ownership boundary:

- `firebase/functions/src/funds/callables.ts:34` `recordFundTransaction`
  requires claimed session and finance manager role.
- `firebase/functions/src/funds/callables.ts:80` enforces clan access from the
  fund record before writing.
- `firebase/functions/src/funds/callables.ts:96` blocks expenses over current
  backend balance.
- `firebase/firestore.rules:520` denies all client writes to `transactions`.

Likely files/symbols if evidence fails:

- `firebase/functions/src/funds/callables.ts:34` `recordFundTransaction`
- `firebase/functions/src/funds/fund-balance-recalculation.ts:40`
  `recalculateFundBalanceFromTransaction`
- `firebase/functions/src/funds/transaction-triggers.ts`
- `mobile/befam/lib/features/funds/services/firebase_fund_repository.dart:123`
  `saveFund`
- `mobile/befam/lib/features/funds/services/firebase_fund_repository.dart:264`
  `recordTransaction`
- `mobile/befam/lib/features/funds/presentation/fund_controller.dart:225`
  `saveFund`
- `mobile/befam/lib/features/funds/presentation/fund_controller.dart`
  `recordTransaction`
- `mobile/befam/lib/features/funds/presentation/fund_workspace_page.dart:1423`
  `_openTransactionEditor`

Risk: **HIGH/CRITICAL**. Fund balances are clan finance records; false ledger,
wrong treasurer scope, or client-write bypass would be release-blocking.

Required tests/evidence:

- `cd firebase/functions && npm test`
- Add or run emulator proof for member denied writes to `funds` and
  `transactions`.
- `cd mobile/befam && flutter test test/features/funds/fund_repository_test.dart test/features/funds/fund_transaction_validation_test.dart test/features/funds/fund_form_validation_widget_test.dart test/features/funds/treasurer_dashboard_repository_test.dart`
- Manual/staging evidence for create fund, assign treasurer, donation, expense,
  over-balance denial, balance recalculation, ledger ordering, and cross-clan
  denial.

### BSEC-005: Stale client-side expense balance

The sheet receives `currentBalanceMinor: fund.balanceMinor` at
`fund_workspace_page.dart:1443`, then `_validateAmount` blocks expense amounts
over that captured value at `fund_workspace_page.dart:3014`. Backend
`recordFundTransaction` still rechecks current balance, so this is not an
overspend security issue. It can block a valid transaction after a concurrent
donation or correction.

Likely fix scope:

- Prefer remove hard client block and submit to backend, or refresh/re-resolve
  the fund before blocking.
- Keep friendly warning copy, but backend remains authoritative.
- Add a widget/controller test for stale displayed balance vs backend-accepted
  balance.

Risk: **MEDIUM** for single-admin clans, **HIGH** if Product expects concurrent
treasurers before launch.

## Security/Rules Triage

Current rule posture looks directionally correct:

- `firebase/firestore.rules:21` `hasClanAccess` gates clan data by token clan IDs
  plus active clan status.
- `firebase/firestore.rules:95` `canReadBillingDoc` requires claimed member
  access, clan access, and billing admin role.
- `firebase/firestore.rules:508` protects `funds` reads/writes by finance role.
- `firebase/firestore.rules:520` makes `transactions` server-only for writes.
- `firebase/firestore.rules:643` through `:669` make billing collections
  read-scoped and write-denied to clients.
- `firebase/storage.rules:137` default-denies unmatched paths.

Evidence gap:

- Existing tests cover important hardening patterns, but PO release criteria need
  exact-RC proof for cross-clan read/write denial, role-scoped reads/writes,
  billing restrictions, notification recipient-only updates, Storage deny cases,
  and server-only financial writes.

Likely files/symbols if rules evidence fails:

- `firebase/firestore.rules`
- `firebase/storage.rules`
- `firebase/functions/src/rules-tests/firebase-rules-emulator.rules.test.ts`
- `firebase/functions/src/contract-tests/firebase-rules-hardening.contract.test.ts`
- Shared permission helpers in `firebase/functions/src/shared/permissions.ts`
- Mobile session sync in `mobile/befam/lib/core/services/firebase_session_access_sync.dart`

Risk: **CRITICAL**. Any cross-clan leak, client financial write, or billing doc
write bypass is a production stop.

Required tests/evidence:

- Run Firebase rules emulator tests against the exact RC.
- Add explicit emulator assertions if missing for:
  - non-finance member cannot read `funds` or `transactions`;
  - any client cannot create/update `transactions`;
  - billing admin can read own-clan billing docs only;
  - member cannot read another clan billing docs;
  - generic Storage path denies unknown/oversized/no-content-type writes;
  - scholarship evidence paths preserve reviewer/member boundaries.

## Review Checklist

### Technical Lead

- Confirm whether billing release is IAP-only or must restore VNPay/Card paths.
- Verify `verifyInAppPurchase` success, replay, failed, expired, and product
  mismatch behavior with provider-backed evidence.
- Verify billing audit trail and entitlement snapshots update atomically enough
  for UI refresh and ad gating.
- Run rules emulator security suite and attach logs to the release evidence.
- Decide whether to fix stale client-side funds balance before RC.
- Confirm Functions build/test, Flutter analyze/test, and CI are green for the
  exact release commit.

### Product Owner

- Decide release acceptance language: VNPay required, IAP accepted, or billing
  deferred/feature-gated.
- Sign off on which billing flows are in production scope: plan view, upgrade,
  renewal, cancellation/failed purchase, entitlement refresh, reminders.
- Require evidence links for BILL, FUND, RULE, AUTH/CTX, NOTIF, and SCH cases
  before production GO.
- If scholarship or VNPay are deferred, approve explicit feature gating and
  release-note wording.

### UI/UX Manager

- Review billing checkout states for Vietnamese copy, pending/failed/canceled
  clarity, and no promise of activation before provider confirmation.
- Review funds ledger flows for deterministic validation, stale-balance wording,
  treasurer assignment clarity, and no floating controls blocking finance tasks.
- Verify final screenshots are steady-state, with onboarding/loading overlays
  dismissed and evidence mapped to case IDs.

## Final Triage

No implementation change should start until BSEC-001 is resolved. If Product
keeps VNPay as a release blocker, this becomes a critical backend/mobile billing
implementation effort. If Product accepts IAP-only, the next work is evidence
closure plus focused hardening tests for billing, rules, and funds ledger.
