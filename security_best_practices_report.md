# Security Best Practices Review

Date: 2026-03-14  
Scope: Flutter mobile app (`mobile/befam`), Firebase rules, Firebase Cloud Functions, GitHub Actions workflows

## Executive Summary

The project has a solid foundation (role-aware Firestore rules, callable auth workflows, and CI checks), but there are several important hardening gaps that could expose user data in production.  
Top priorities are:

1. Protect pre-auth child lookup from enumeration/abuse.
2. Enforce Firebase App Check across callable endpoints.
3. Tighten scholarship evidence read permissions (currently clan-wide).
4. Remove sensitive data from logs.

No hardcoded Firebase Admin private keys were found in repository files reviewed.

## Critical / High Findings

### SEC-001 (High): Unauthenticated child-identifier lookup leaks account context and enables enumeration
- Location:
  - `firebase/functions/src/auth/callables.ts:65-82`
  - `firebase/functions/src/auth/callables.ts:435-444`
- Evidence:
  - `resolveChildLoginContext` is callable without `requireAuth`.
  - Returned payload includes `memberId`, `clanId`, `branchId`, `primaryRole`, and masked parent destination.
- Impact:
  - Attackers can brute-force child identifiers and map existing family records and clan structure.
  - Increases risk of targeted social engineering and privacy leakage.
- Fix:
  - Add abuse controls for pre-auth endpoint: App Check + challenge token (for example reCAPTCHA Enterprise) + server-side throttling/rate limits.
  - Return minimal data before OTP verification (prefer only a generic success/failure and masked destination).

### SEC-002 (High): No App Check enforcement on callables; abuse from non-genuine clients is possible
- Location:
  - `firebase/functions/src/auth/callables.ts:65`, `:85`, `:99`, `:207`
  - `firebase/functions/src/genealogy/callables.ts:39`, `:155`
  - `mobile/befam/lib/app/bootstrap/app_bootstrap.dart:27-33` (Firebase initialized, but App Check not activated)
- Evidence:
  - `onCall` handlers only specify `region`; no `enforceAppCheck`.
  - Mobile bootstrap has no App Check activation path.
- Impact:
  - Automated scripted clients can call endpoints directly, increasing OTP abuse, token spam, and mutation abuse attempts.
- Fix:
  - Enforce App Check for authenticated mutation endpoints first (`claimMemberRecord`, relationship callables, `registerDeviceToken`).
  - Add `firebase_app_check` in app bootstrap and configure Android/iOS providers.
  - Keep extra anti-automation for pre-auth flows.

### SEC-003 (High): Scholarship submissions and evidence files are readable by all clan members
- Location:
  - `firebase/firestore.rules:285-299`
  - `firebase/storage.rules:74-80`
- Evidence:
  - Firestore: `achievementSubmissions` read allowed by `hasClanAccess(resource.data.clanId)`.
  - Storage: `/submissions/{clanId}/{memberId}/{fileName}` read allowed by `hasClanAccess(clanId)`.
- Impact:
  - Sensitive student documents can be accessed by any clan member, not only owner/reviewer/admin.
- Fix:
  - Restrict reads to:
    - owner (`resource.data.memberId == memberIdClaim()`), and
    - explicit reviewer/admin roles.
  - Keep list-level visibility separate from full file access if needed for UX.

## Medium Findings

### SEC-004 (Medium): Sensitive operational data is written to logs
- Location:
  - `firebase/functions/src/auth/callables.ts:88-91`
  - `firebase/functions/src/auth/callables.ts:164-167`
  - `firebase/functions/src/notifications/push-delivery.ts:178-181`
- Evidence:
  - Full `request.data` logged in `createInvite`.
  - `phoneE164` logged on no-match in claim flow.
  - Raw FCM token logged during cleanup failure.
- Impact:
  - PII and routing tokens may leak via log access or downstream log exports.
- Fix:
  - Redact/hash sensitive fields before logging.
  - Never log full request payloads in auth endpoints.

### SEC-005 (Medium): Auth session and privacy consent are stored in plain SharedPreferences
- Location:
  - `mobile/befam/lib/features/auth/services/auth_session_store.dart:20-33`
  - `mobile/befam/lib/features/auth/services/auth_privacy_policy_store.dart:14-21`
- Evidence:
  - Session JSON and privacy consent booleans are persisted in standard local prefs.
- Impact:
  - On compromised devices or insecure backups, session metadata and identifiers may be exposed.
- Fix:
  - Move session persistence to secure storage (Keychain/Keystore via `flutter_secure_storage`).
  - Store only minimal data needed to restore UX.

### SEC-006 (Medium): Build-flag configuration can enable OTP bypass/mock auth in release if misconfigured
- Location:
  - `mobile/befam/lib/core/services/runtime_mode.dart:20-35`
  - `mobile/befam/lib/features/auth/services/auth_gateway_factory.dart:6-11`
  - `mobile/befam/lib/features/auth/services/debug_auth_gateway.dart:16`
- Evidence:
  - `shouldUseMockBackend` becomes true when `shouldBypassPhoneOtp` is true.
  - Bypass mode is controlled by compile-time flags and can switch to `DebugAuthGateway`.
- Impact:
  - A misconfigured release build could accidentally ship with debug OTP pathway.
- Fix:
  - Enforce hard block in release builds (`if (kReleaseMode) bypass=false; mock=false`).
  - Add CI guard to fail builds when bypass/mock flags are enabled for release workflows.

## Low Findings

### SEC-007 (Low): GitHub Actions hardening can be improved
- Location:
  - `.github/workflows/release-main.yml:9-11`
  - `.github/workflows/release-main.yml:29`, `:37`, `:78`, `:92`, `:95`, `:101`, etc.
- Evidence:
  - Global workflow permissions grant write scopes for all jobs.
  - Actions are pinned to major tags (not immutable commit SHAs).
- Impact:
  - Increased blast radius if any workflow step is compromised.
- Fix:
  - Scope permissions per job (principle of least privilege).
  - Pin third-party actions to commit SHAs.

### SEC-008 (Low): Dependency audit shows low-severity transitive issues
- Location:
  - `firebase/functions/package-lock.json`
- Evidence:
  - `npm audit --omit=dev` reports 9 low vulnerabilities (transitive chain via Firebase dependencies).
- Impact:
  - Low immediate risk, but should be tracked.
- Fix:
  - Add scheduled dependency updates and periodic audit triage.

## Recommended Hardening Plan (Priority Order)

1. Implement App Check end-to-end and enforce it on callables.
2. Redesign pre-auth child lookup response and add anti-enumeration rate limits.
3. Tighten scholarship file/read permissions (Firestore + Storage) to owner/reviewer/admin only.
4. Add log redaction utility and remove sensitive fields from all auth/notification logs.
5. Move session persistence to secure storage and reduce stored data surface.
6. Add release-time guardrails to prevent debug/mock auth in production artifacts.
7. Harden GitHub workflows (job-level permissions, SHA pinning).
