# Data Model

_Last reviewed: March 14, 2026_

## Core entities

Primary Firestore collections:

- `clans`
- `branches`
- `members`
- `relationships`
- `events`
- `funds`
- `transactions`
- `scholarshipPrograms`
- `awardLevels`
- `achievementSubmissions`
- `notifications`
- `invites`
- `auditLogs`
- `users` and nested `users/{uid}/deviceTokens`

Planned billing collections for Epic #213:

- `subscriptions`
- `subscriptionInvoices`
- `paymentTransactions`
- `paymentWebhookEvents`
- `billingSettings`

## Relationship model

- canonical graph edges are stored in `relationships`
- denormalized arrays on `members` (`parentIds`, `childrenIds`, `spouseIds`)
  improve read performance for tree rendering and profile views
- relationship creation uses server-side validation for duplicate spouse edges
  and parent-child cycle prevention

## Identity and session model

- `members.authUid` links Firebase Auth accounts to member profiles
- `users/{uid}` stores resolved access context for rule fallback:
  - `memberId`
  - `clanId` and `clanIds`
  - `branchId`
  - `primaryRole`
  - `accessMode`
  - `linkedAuthUid`
- FCM tokens are stored under `users/{uid}/deviceTokens/{token}`

## Query/index strategy

- indexes prioritize clan-scoped reads, filtered member search, and chronology:
  - members by `clanId + normalizedFullName`
  - relationships by `clanId + personA/personB + type`
  - events by `clanId/branchId + startsAt`
  - notifications by `memberId + createdAt`

Planned billing index profile:

- subscriptions by `clanId + status + expiresAt`
- payment transactions by `clanId + createdAt`
- invoices by `clanId + periodStart/periodEnd`

## Schema references

- [Firestore Production Schema](../FIRESTORE_PRODUCTION_SCHEMA.md)
- [Backend Firestore Schema Guide](../04-backend/firestore-schema.md)
