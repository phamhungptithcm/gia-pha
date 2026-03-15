# Cloud Functions

_Last reviewed: March 15, 2026_

Functions are implemented in `firebase/functions` using Firebase Functions v2
and TypeScript.

## Runtime configuration

- Node.js: 20
- region: `asia-southeast1`
- timezone for scheduled jobs: `Asia/Ho_Chi_Minh`
- global options: `maxInstances = 10`

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

### Planned billing callables and triggers (Epic #213)

- `createSubscriptionCheckout`:
  - validates clan owner/admin permission
  - computes plan from `member_count` (`FREE`, `BASE`, `PLUS`, `PRO`)
  - initializes card/VNPay checkout with VAT-included amount
- `handleVnpayWebhook`:
  - validates gateway signature and replay/idempotency constraints
  - commits transaction + subscription updates atomically
- `handleCardWebhook`:
  - verifies provider signature and payment status transition
  - writes invoice/transaction/audit records
- `sendSubscriptionRenewalReminders` (scheduled):
  - finds upcoming expiry windows
  - emits notification docs and push payloads to owner/admin audience
- `resolvePlanEntitlements`:
  - derives ad entitlement from active plan
  - returns client-safe flags (`showAds`, `adFree`, `planCode`, `expiresAt`)

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
