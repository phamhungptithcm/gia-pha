# Feature Spec

_Last reviewed: March 15, 2026_

## Feature status matrix

| Area | Current status | Notes |
| --- | --- | --- |
| Auth (phone OTP) | Live | Firebase phone auth with session persistence |
| Auth (child login) | Live | `resolveChildLoginContext` and parent OTP path |
| Member claim + auth UID link | Live | `claimMemberRecord` and user session sync |
| Clan workspace | Live | Clan/branch create/edit and role-aware access |
| Member profiles | Live | Add/edit profile, avatar upload, social links |
| Member search | Live | Query + branch/generation filters + analytics |
| Relationship commands | Live | Parent-child/spouse callables with cycle/duplicate checks |
| Genealogy read model | Live | Clan/branch scopes, root selection, graph helpers |
| Genealogy UI | Live | Tree nodes/connectors, zoom/pan, center/focus, detail sheet |
| Dual calendar workspace | Live | Solar + lunar tiles, regional settings, reminder offsets |
| Event management UX | Live | Event create/edit/delete in dual calendar context |
| Funds module | Live | Fund profiles, transactions, permissions, and validations |
| Scholarship module | Live | Program/award/submission/review baseline |
| Profile workspace | Live | Profile shell is in navigation with settings extension points |
| Push token registration | Live | Callable-first with Firestore fallback |
| Push delivery backend | Live | Notification docs + FCM multicast delivery |
| Notification inbox UI | Partial | Inbox list, mark-read, pagination, and destination placeholders are live; full destination screens are pending |
| Subscription + billing | Live | Epic [#213](https://github.com/phamhungptithcm/gia-pha/issues/213) implemented (Free/Base/Plus/Pro, Card/VNPay, reminders, history, audit logs) |

## Functional guardrails

- data isolation by `clanId` in Firestore and Storage rules
- role-based writes for sensitive actions (`CLAN_ADMIN`, `BRANCH_ADMIN`)
- child login access mode tracked as distinct session context
- immutable audit-style records for relationship and auth-link actions
- billing guardrails include signed gateway callbacks, webhook idempotency,
  server-only webhook event writes, and owner/admin billing workspace visibility

## Technical compatibility

- mobile: Flutter, Android, iOS
- backend: Firebase Auth, Firestore, Storage, Functions v2, FCM
- billing: Free/Base/Plus/Pro plan engine, card + VNPay checkout, reminder
  scheduling, and server-side callback validation
- CI/CD: GitHub Actions with protected `staging` and `main` delivery model
