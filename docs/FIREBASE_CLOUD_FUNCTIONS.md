# FIREBASE CLOUD FUNCTIONS
## Backend Logic Specification

This document defines the backend behavior for Cloud Functions.

> Implementation note (March 14, 2026): this document captures target behavior.
> The currently shipped implementation is summarized in
> `docs/en/04-backend/cloud-functions.md`.

## 1. Goals

Cloud Functions are responsible for:
- enforcing cross-document consistency
- sending notifications
- computing derived values
- maintaining audit logs
- handling scheduled jobs

## 2. Runtime and Structure

Use Firebase Functions v2 with TypeScript.

Suggested structure:

```text
firebase/functions/src/
  index.ts
  config/
  shared/
    logger.ts
    errors.ts
    firestore.ts
  auth/
  genealogy/
  events/
  funds/
  scholarship/
  invites/
  notifications/
  scheduled/
```

## 3. Core Function Categories

### 3.1 Relationship Functions

#### onRelationshipCreated
Trigger: Firestore create on `relationships/{relationshipId}`

Responsibilities:
- validate relationship type
- prevent invalid cycles for parent-child
- update denormalized fields on both members
- write audit log
- optionally recompute generation hints

#### onRelationshipDeleted
Responsibilities:
- remove corresponding IDs from denormalized arrays
- write audit log

#### reconcileMemberRelationshipFields
Callable or internal helper.
Responsibilities:
- read canonical edges for impacted members
- rebuild `parentIds`, `childrenIds`, `spouseIds`
- write normalized member state

### 3.2 Event Functions

#### onEventCreated
Trigger: Firestore create on `events/{eventId}`

Responsibilities:
- compute notification audience
- enqueue or send event-created notification
- create reminder schedule records if used

#### onEventUpdated
Responsibilities:
- notify affected users when schedule or location changes
- refresh reminder jobs if relevant

#### sendEventReminder
Scheduled function or triggered by schedule records.
Responsibilities:
- send reminders for upcoming events based on offsets

### 3.3 Fund Functions

#### onTransactionCreated
Trigger: Firestore create on `transactions/{transactionId}`

Responsibilities:
- validate transaction payload
- recalculate fund balance using atomic strategy
- write audit log
- optionally notify admins or donor

#### onTransactionDeletedOrReversed
Responsibilities:
- restore or recalculate balance
- preserve immutable audit trail

### 3.4 Scholarship Functions

#### onSubmissionCreated
Responsibilities:
- notify reviewers or clan admins
- validate submission program state

#### onSubmissionReviewed
Responsibilities:
- notify submitter of approval or rejection
- create award record if system adds one in later phase

### 3.5 Invite and Identity Functions

#### createInvite
Callable function.
Responsibilities:
- create invite with expiration
- enforce role-based permission

#### claimMemberRecord
Callable function.
Responsibilities:
- validate auth context
- match invite or phone
- set `authUid` on member
- mark invite consumed
- audit log

#### resolveChildLoginContext
Callable function or secure read helper.
Responsibilities:
- map child identifier to parent phone/member
- return minimal safe information

### 3.6 Notification Functions

#### registerDeviceToken
Callable or client write with secure rules.
Responsibilities:
- upsert token metadata

#### sendNotificationBatch
Internal helper:
- chunk FCM sends
- retry transient errors
- delete invalid tokens

### 3.7 Scheduled Jobs

#### expireInvitesJob
Runs daily or hourly.
Responsibilities:
- mark expired invites

#### recurringMemorialMaterializationJob
Runs daily.
Responsibilities:
- create or ensure yearly memorial event instances if recurrence model requires materialization

#### cleanupOldNotificationArtifactsJob
Optional cleanup for old logs or transient docs

## 4. Consistency Rules

### Relationship consistency
- canonical source = `relationships`
- denormalized member arrays must be reconciled from canonical edges
- never rely only on client-side array mutation for truth

### Fund balance consistency
Options:
1. increment/decrement using transaction type
2. periodic recalc from ledger

Recommended:
- do atomic adjustment on write
- keep admin repair function for full recompute

### Notification consistency
- function should be idempotent
- use dedupe keys when necessary for reminders

## 5. Security Expectations

- never trust client role claims without verification
- derive role from Firestore membership/admin records or custom claims
- validate clan scope for every callable
- reject unauthorized writes with clear error codes

## 6. Error Handling

Use structured errors:
- `invalid-argument`
- `permission-denied`
- `not-found`
- `failed-precondition`
- `internal`

All functions should log:
- function name
- actor uid if available
- clanId if applicable
- entity ids
- failure reason

## 7. Pseudocode Examples

### 7.1 onRelationshipCreated

```text
onCreate(relationship):
  validate type
  load memberA and memberB
  ensure same clan
  if type == parent_child:
    ensure no cycle
  update denormalized arrays for impacted members
  write audit log
```

### 7.2 onTransactionCreated

```text
onCreate(transaction):
  validate fund exists and same clan
  delta = amount if donation else -amount
  transactionally update fund.balanceMinor += delta
  write audit log
```

### 7.3 onSubmissionReviewed

```text
onUpdate(submission):
  if status changed to approved or rejected:
    create notification for submitter
    send push message
```

## 8. Function Inventory

Recommended first implementation list:
- `onRelationshipCreated`
- `onRelationshipDeleted`
- `onEventCreated`
- `onTransactionCreated`
- `onSubmissionReviewed`
- `createInvite`
- `claimMemberRecord`
- `registerDeviceToken`
- `expireInvitesJob`
- `sendEventReminder`

## 9. Testing Strategy

### Unit tests
- validation helpers
- cycle detection
- fund balance delta logic
- audience resolution logic

### Emulator integration tests
- create relationship -> member arrays updated
- create event -> notification docs written
- create transaction -> fund balance updated
- review scholarship -> notification sent

## 10. Deployment Rules

- separate dev and prod Firebase projects
- enforce CI test pass before deploy
- use function-level deployment when possible during development
- protect production deploy with manual approval

## 11. Observability

- use structured logger
- report errors to Cloud Logging / Crashlytics integration where applicable
- track notification send success / failure rate
- expose admin repair scripts for data reconciliation
