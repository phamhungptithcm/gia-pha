# Feature Spec

_Last reviewed: March 14, 2026_

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
| Push token registration | Live | Callable-first with Firestore fallback |
| Push delivery backend | Live | Notification docs + FCM multicast delivery |
| Event management UI | Partial | Home shell has Events tab placeholder |
| Notification inbox UI | Partial | Inbox list, mark-read, pagination, and event/scholarship deep-link placeholders are live; full destination modules are pending |
| Funds module | Planned | Backlog defined, not shipped in mobile UI yet |
| Scholarship UI module | Planned | Backend trigger path exists for review updates |

## Functional guardrails

- data isolation by `clanId` in Firestore and Storage rules
- role-based writes for sensitive actions (`CLAN_ADMIN`, `BRANCH_ADMIN`)
- child login access mode tracked as distinct session context
- immutable audit-style records for relationship and auth-link actions

## Technical compatibility

- mobile: Flutter, Android, iOS
- backend: Firebase Auth, Firestore, Storage, Functions v2, FCM
- CI/CD: GitHub Actions with protected `staging` and `main` delivery model
