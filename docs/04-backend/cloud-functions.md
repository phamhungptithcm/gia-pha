# Cloud Functions

_Last reviewed: March 16, 2026_

Functions are implemented in `firebase/functions` using Firebase Functions v2
and TypeScript.

## Runtime configuration

- Node.js: 20
- region: from env `APP_REGION` (default `asia-southeast1`)
- timezone for scheduled jobs: from env `APP_TIMEZONE` (default `Asia/Ho_Chi_Minh`)
- global options: `maxInstances = 10`
- centralized runtime env getters live in `src/config/runtime.ts`
- deploy pipeline writes function env values from GitHub `production` vars/secrets
- non-secret billing overrides are loaded from Firestore at `runtimeConfig/global`
  via `src/config/runtime-overrides.ts` with in-memory cache TTL `60s`
- runtime resolution order for billing config:
  - Firestore runtime override (`runtimeConfig/global`) when valid
  - environment variable value from deploy/runtime
  - code default fallback

## Exported functions inventory

### Auth callables

- `resolveChildLoginContext`
- `claimMemberRecord`
- `registerDeviceToken`
- `createInvite` (scaffolded; currently returns `unimplemented`)

### Genealogy callables and triggers

- `createParentChildRelationship`
- `createSpouseRelationship`
- `onRelationshipCreated`:
  - reconciles denormalized `members.parentIds` / `childrenIds` / `spouseIds`
    from canonical relationship edges
  - validates member/clan consistency before merge updates
- `onRelationshipDeleted`:
  - removes deleted canonical edge impacts from denormalized member arrays
  - keeps reconciliation idempotent for repeated deliveries

### Events and notifications

- `onEventCreated`:
  - resolves audience by clan/branch visibility
  - writes notification docs
  - sends FCM via `notifyMembers`
- `sendEventReminder` (scheduled tick scaffold in place)

### Scholarship and funds

- `onSubmissionReviewed`:
  - watches status transitions to approved/rejected
  - sends targeted push + notification doc updates
- `onTransactionCreated`:
  - derives signed transaction delta (donation/expense)
  - recomputes fund balance from ledger transactions and persists
    `funds.balanceMinor`

### Scheduled

- `expireInvitesJob`:
  - scans invites with `expiresAt <= now`
  - marks `pending` / `active` invites as `expired` in batches
  - logs scanned/expired counts per run

### Contract tests

- contract tests are implemented under `src/contract-tests/*`
- `npm test` compiles functions and runs Node test contracts from `lib/contract-tests/*.contract.test.js`

### Billing callables, webhooks, and jobs (Epic #213)

- `resolveBillingEntitlement`:
  - resolves clan plan and ad entitlement flags for client gating
- `loadBillingWorkspace`:
  - returns subscription status, settings, pricing tiers, transaction history,
    invoices, and billing audit logs for owner/admin UX
- `updateBillingPreferences`:
  - persists auto/manual renewal mode and reminder schedule
- `createSubscriptionCheckout`:
  - computes tier from current member count and creates transaction + invoice
    baseline for Card/VNPay
  - resolves checkout URL and pending-timeout policy from runtime config/env
- `completeCardCheckout` and `simulateVnpaySettlement`:
  - finalize payment settlement in callable-driven testing/dev flows
- `cardPaymentCallback` and `vnpayPaymentCallback`:
  - validate callback signatures
  - webhook secrets/signing keys are read from runtime env getters (no hard-coded key)
  - enforce idempotency via `paymentWebhookEvents`
  - apply subscription lifecycle updates and emit notification/audit records
- `billingSubscriptionReminderJob` (scheduled):
  - scans active/grace subscriptions nearing expiry
  - delivers renewal reminders to owner/admin audience
- `billingPendingTimeoutJob` (scheduled):
  - schedule is read from env (`BILLING_PENDING_TIMEOUT_JOB_SCHEDULE`)
  - timeout/limit use runtime override when available, else env defaults

### Auth runtime signer behavior

- debug token signer service account is now read from
  `DEBUG_TOKEN_SIGNER_SERVICE_ACCOUNT` in `src/auth/callables.ts`
- no project-specific signer account is hard-coded in source

## Supporting modules

- `notifications/push-delivery.ts` handles:
  - audience dedupe
  - notification document fan-out
  - chunked multicast push sends
  - invalid token cleanup
- shared utilities:
  - `shared/logger.ts`
  - `shared/errors.ts`
  - `shared/firestore.ts`

## Build and local commands

```bash
cd firebase/functions
npm ci
npm run build
```

Seed baseline demo data:

```bash
cd firebase/functions
npm run seed:demo
```
