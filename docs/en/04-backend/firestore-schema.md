# Firestore Schema

_Last reviewed: March 15, 2026_

This page summarizes the active Firestore model used by the mobile app and
Cloud Functions.

## Core collections

- `clans`: clan profile and aggregate metadata
- `branches`: branch hierarchy and branch leadership references
- `members`: canonical member profile, role, and denormalized relationship ids
- `relationships`: canonical relationship edges
- `invites`: phone and child-access invite records
- `users`: session access context for auth/rules fallback
- `notifications`: per-member notification inbox documents
- `events`, `funds`, `transactions`, `scholarshipPrograms`, `awardLevels`,
  `achievementSubmissions`, `auditLogs`

Billing collections (Epic #213):

- `subscriptions`: clan-level plan state (`FREE`, `BASE`, `PLUS`, `PRO`),
  member snapshot, price, ad entitlement, expiry, renew mode
- `subscriptionInvoices`: invoice summaries for each billing cycle
- `paymentTransactions`: gateway-level payment intent/settlement records
- `paymentWebhookEvents`: idempotency and callback verification tracking
- `billingSettings`: owner/admin renewal preferences and reminder settings
- `billingAuditLogs`: immutable billing action trace entries

## Member + relationship pattern

- truth source:
  - edges in `relationships`
- read optimization:
  - `members.parentIds`
  - `members.childrenIds`
  - `members.spouseIds`
- relationship callables maintain denormalized arrays transactionally

## Session and device token docs

- `users/{uid}` stores resolved access:
  - `memberId`, `clanId`, `clanIds`, `branchId`, `primaryRole`, `accessMode`
- `users/{uid}/deviceTokens/{token}` stores FCM routing metadata

## Query/index profile

Key indexes are maintained in `firebase/firestore.indexes.json`:

- members by clan + name
- members by clan + branch + name
- members by clan + generation
- relationships by clan + person + type
- events by clan/branch + start time
- notifications by member + created time and read state
- billing indexes by clan + subscription status/expiry and transaction
  chronology

## Reference

For full schema examples and expanded field contracts:

- [Firestore Production Schema](../../FIRESTORE_PRODUCTION_SCHEMA.md)
