# Firebase Architecture

_Last reviewed: March 16, 2026_

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

Billing runtime is active:

- payment gateway integration (card + VNPay) mediated by Cloud Functions
- subscription lifecycle and invoice state stored in Firestore
- runtime billing overrides loaded from Firestore `runtimeConfig/global`

## Access model

- identity context is carried by custom claims (`clanIds`, `memberId`,
  `branchId`, `primaryRole`, `memberAccessMode`)
- mobile session document is mirrored to `users/{uid}`
- Firestore/Storage rules validate clan scope and role-based writes

## Current backend module map

```text
firebase/functions/src/
  auth/callables.ts
  billing/callables.ts
  billing/webhooks.ts
  billing/subscription-reminders.ts
  billing/store.ts
  config/runtime.ts
  config/runtime-overrides.ts
  genealogy/callables.ts
  genealogy/relationship-triggers.ts
  events/event-triggers.ts
  scholarship/submission-triggers.ts
  funds/transaction-triggers.ts
  notifications/push-delivery.ts
  scheduled/jobs.ts
```
```

## Delivery architecture

- `deploy-firebase.yml` builds functions and deploys rules/indexes/storage/functions
  from `main`
- `deploy-firebase.yml` also writes `firebase/functions/.env.<projectId>` and syncs
  non-secret runtime billing overrides to Firestore `runtimeConfig/global`
- `release-main.yml` handles release tagging, notes, mobile artifacts, and GHCR
  image publishing
- `branch-ci.yml` enforces docs/functions/mobile health on protected branches
