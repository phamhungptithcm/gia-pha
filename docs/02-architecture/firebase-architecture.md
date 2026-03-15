# Firebase Architecture

_Last reviewed: March 14, 2026_

## Project and regions

- project id: `be-fam-3ab23`
- Firestore default database location: `asia-southeast1`
- Cloud Functions region constant: `asia-southeast1`
- scheduler timezone constant: `Asia/Ho_Chi_Minh`

## Firebase services in use

- Firebase Auth (phone OTP sign-in)
- Cloud Firestore (primary domain store)
- Firebase Storage (avatars and submission assets)
- Cloud Functions for Firebase v2 (callables, triggers, schedules)
- Firebase Cloud Messaging (token registration and push delivery)
- Firebase Analytics and Crashlytics on mobile

Planned for billing epic:

- payment gateway integration (card + VNPay) mediated by Cloud Functions
- subscription lifecycle and invoice state stored in Firestore

## Access model

- identity context is carried by custom claims (`clanIds`, `memberId`,
  `branchId`, `primaryRole`, `memberAccessMode`)
- mobile session document is mirrored to `users/{uid}`
- Firestore/Storage rules validate clan scope and role-based writes

## Current backend module map

```text
firebase/functions/src/
  auth/callables.ts
  genealogy/callables.ts
  genealogy/relationship-triggers.ts
  events/event-triggers.ts
  scholarship/submission-triggers.ts
  funds/transaction-triggers.ts
  notifications/push-delivery.ts
  scheduled/jobs.ts

Planned additions:

```text
  billing/checkout-callables.ts
  billing/payment-webhooks.ts
  billing/subscription-jobs.ts
```
```

## Delivery architecture

- `deploy-firebase.yml` builds functions and deploys rules/indexes/storage/functions
  from `main`
- `release-main.yml` handles release tagging, notes, mobile artifacts, and GHCR
  image publishing
- `branch-ci.yml` enforces docs/functions/mobile health on protected branches
