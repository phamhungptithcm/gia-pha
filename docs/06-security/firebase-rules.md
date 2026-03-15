# Firebase Rules

_Last reviewed: March 15, 2026_

## Firestore rules highlights

Rules are defined in `firebase/firestore.rules` and enforce:

- authenticated access only
- clan-scoped reads by claims or `users/{uid}` fallback context
- role-aware writes for `clans`, `branches`, `members`, and `relationships`
- self-profile update guardrails using allowed-field diff checks
- server-only writes for critical collections (`transactions`, `auditLogs`,
  `memberSearchIndex`)

Billing rule model (Epic #213):

- `subscriptions`, `paymentTransactions`, `subscriptionInvoices`, and
  `paymentWebhookEvents` are server-written only
- billing reads are limited to clan owner/admin roles in the same `clanId`
- webhook-event docs are non-readable to regular clients
- `billingAuditLogs` are read-only for clan billing admin roles and
  server-written only

### Key helpers

- `hasClanAccess(clanId)`
- `primaryRole()`
- `branchIdClaim()`
- `isClanSettingsAdmin()`
- `isBranchScopedMemberManager(...)`
- `safeProfileUpdate()`

## Storage rules highlights

Rules are defined in `firebase/storage.rules` and enforce:

- clan-scoped reads
- avatar upload path:
  - `clans/{clanId}/members/{memberId}/avatar/{fileName}`
  - write allowed for clan admins or the owning member
  - image-only content type and 10 MB max size
- submission uploads:
  - `submissions/{clanId}/{memberId}/{fileName}`
  - member-owned writes with 20 MB max size

## Operational guidance

- keep rules and indexes versioned with feature changes
- deploy rules/indexes through CI from protected branches
- validate new role fields in both claims and `users/{uid}` fallback docs
- keep `docs/06-security/firebase-rules.md` aligned using
  `scripts/validate_rules_documentation.py` in CI
- include billing collections in emulator/rules test matrix before rollout
