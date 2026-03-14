# Authentication

_Last reviewed: March 14, 2026_

BeFam authentication combines Firebase phone OTP with clan-specific member
resolution and role context syncing.

## Supported login modes

- phone OTP login (`AuthEntryMethod.phone`)
- child identifier login via parent OTP (`AuthEntryMethod.child`)

## Cloud Function callables

### `resolveChildLoginContext`

- input: `childIdentifier`
- resolves parent phone + member/clan/branch context
- prefers active `invites` records, with member fallback by id

### `claimMemberRecord`

- input includes `loginMethod` and optional `childIdentifier`/`memberId`
- validates OTP-backed identity against member/invite records
- links `members/{memberId}.authUid` where appropriate
- applies custom claims:
  - `clanIds`
  - `memberId`
  - `branchId`
  - `primaryRole`
  - `memberAccessMode`
- writes audit logs for claim/session actions

### `registerDeviceToken`

- upserts FCM token metadata under `users/{uid}/deviceTokens/{token}`
- includes platform and resolved session context for push targeting

## Mobile gateway behavior

- primary path uses Firebase Auth + callable functions
- fallback path exists for temporary callable unavailability:
  - local child mapping fallback for known demo identifiers
  - Firestore-based claim/session sync fallback
- `RuntimeMode` still supports explicit mock mode for tests

## Session persistence

- session is stored locally using `AuthSessionStore`
- app restore checks token validity with Firebase Auth
- `FirebaseSessionAccessSync` keeps `users/{uid}` doc aligned with session

## Security notes

- child login requires verified parent phone to match resolved context
- duplicate phone claims are rejected with conflict errors
- rule fallback supports either auth token claims or `users/{uid}` context
