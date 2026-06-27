# Security Gate Audit - 2026-05-17

Repo: `gia-pha`
Branch reviewed: `hunpeolabs/ai-production-ux-pass`
Role: Security Lead

## Release Decision

Production release should be blocked until SG-01 through SG-05 are remediated
and covered by runtime rules/callable tests. The highest-risk pattern is that
server callables correctly model claimed-session governance, but Firestore and
Storage rules still permit privileged writes using role claims alone. That makes
child or stale-role sessions much more powerful than the product privacy model
allows.

## Method

- Reviewed the Graphify report before code navigation.
- Used `rg` across security docs, Firestore/Storage rules, Cloud Functions,
  mobile auth/billing/AI code, tests, and GitHub workflows.
- Reviewed security-sensitive docs under `docs/en/06-security`,
  `docs/en/04-backend`, `docs/en/05-devops`, and billing product docs.
- Ran targeted local checks:
  - `cd firebase/functions && npm test` - passed 30 contract tests.
  - `cd firebase/functions && npm run test:rules` - blocked locally because
    Firestore port `8080` and Storage port `9199` were already in use.

## Severity Summary

| ID | Severity | Area | Release blocker |
| --- | --- | --- | --- |
| SG-01 | Critical | Child access + role checks | Yes |
| SG-02 | Critical | Child identifier/OTP authorization | Yes |
| SG-03 | High | Firestore direct member/relationship writes | Yes |
| SG-04 | High | QA self-test callables | Yes |
| SG-05 | High | CI/CD rules gates | Yes |
| SG-06 | Medium | User entitlement doc shape | No, hardening before release |
| SG-07 | Medium | Self profile phone mutation | No, hardening before release |
| SG-08 | Medium | Trusted device storage | No, hardening before broad rollout |
| SG-09 | Medium | Storage upload payload policy | No, hardening before broad rollout |
| SG-10 | Medium | AI assistant data minimization | No, hardening before broad rollout |
| SG-11 | Medium | Billing/VNPay source-of-truth drift | No, product/security cleanup |
| SG-12 | Medium | Callable clan active-status checks | No, hardening before release |
| SG-13 | Low | OTP/client log sensitivity | No |

## Findings

### SG-01 - Child sessions can inherit privileged roles and pass rules guards

Severity: Critical
Release blocker: Yes

Locations:
- `firebase/functions/src/auth/callables.ts:4053` builds child context from the
  member record.
- `firebase/functions/src/auth/callables.ts:4075` preserves
  `member.primaryRole`.
- `firebase/functions/src/auth/callables.ts:723` applies that context with
  access mode `child`.
- `firebase/functions/src/auth/callables.ts:5048` writes `primaryRole` and
  `memberAccessMode` into custom claims.
- `firebase/firestore.rules:72`, `firebase/firestore.rules:101`,
  `firebase/firestore.rules:426`, `firebase/firestore.rules:454`,
  `firebase/firestore.rules:482`, and `firebase/firestore.rules:496` use role
  predicates for privileged writes without requiring
  `memberAccessModeClaim() == 'claimed'`.
- `firebase/storage.rules:52` and `firebase/storage.rules:95` allow admin
  storage writes by role without claimed-session enforcement.

Exploit path:
1. A child-login session resolves to a member whose `primaryRole` is
   `CLAN_ADMIN`, `CLAN_OWNER`, `BRANCH_ADMIN`, or similar.
2. `claimMemberRecord` applies custom claims with `memberAccessMode='child'`
   and the inherited privileged `primaryRole`.
3. Firestore and Storage rules treat the session as an admin because most role
   predicates do not require claimed access.
4. The child session can update clan settings, branches, members,
   relationships, events, and generic clan storage paths.

Recommended fix:
- Force child sessions to a non-privileged role, preferably `MEMBER`, in
  `buildResolvedChildContext` or `buildMemberSessionContext`.
- Update every privileged Firestore/Storage role helper to require a claimed
  session, except explicitly child-safe read paths.
- Add rules emulator tests for `memberAccessMode='child'` with admin-like
  `primaryRole` attempting member, relationship, event, clan, and storage
  writes.

### SG-02 - Child lookup falls back to raw member IDs without child/invite gate

Severity: Critical
Release blocker: Yes

Locations:
- `docs/en/04-backend/authentication.md:15` documents member fallback by id.
- `firebase/functions/src/auth/callables.ts:3937` resolves child login context.
- `firebase/functions/src/auth/callables.ts:3979` falls back to
  `members.doc(childIdentifier)`.
- `firebase/functions/src/auth/callables.ts:3981` only requires the member to
  have `phoneE164`.
- `firebase/functions/src/auth/callables.ts:450` returns `memberId` and
  `displayName` before OTP approval.
- `firebase/functions/src/auth/callables.ts:718` checks verified phone against
  the resolved parent phone, but the fallback uses the member's own phone as
  the parent phone.

Exploit path:
1. An attacker obtains or guesses a member document ID.
2. The unauthenticated child lookup/request path resolves the member directly
   if that record has `phoneE164`, without requiring an active child-access
   invite, minor status, guardian relationship, or child-access flag.
3. OTP is sent to the member phone and the server returns `memberId` and
   `displayName`.
4. Anyone controlling that phone can enter the app as a `child` session for
   that profile, and SG-01 can elevate the impact if the member has a
   privileged role.

Recommended fix:
- Remove raw `members/{id}` fallback from child login, or restrict it to
  explicit active child-access invite records.
- Require active child invite, member status checks, and guardian/parent phone
  ownership before sending OTP.
- Do not return `memberId` or `displayName` until after OTP verification.
- Add negative tests for adult/admin member IDs and inactive invite/member
  records.

### SG-03 - Direct Firestore writes bypass callable audit and relationship integrity

Severity: High
Release blocker: Yes

Locations:
- `firebase/firestore.rules:454` allows member updates.
- `firebase/firestore.rules:457` allows clan settings admins and branch-scoped
  managers to update member documents with minimal immutable-field checks.
- `firebase/firestore.rules:482` allows direct relationship create/update.
- `firebase/functions/src/genealogy/callables.ts:75` performs cycle detection
  in the callable path.
- `firebase/functions/src/genealogy/callables.ts:315` requires claimed-session
  relationship permission in the callable path.
- `firebase/functions/src/governance/callables.ts:45` and
  `firebase/functions/src/governance/callables.ts:124` assign governance roles
  through a claimed callable with role assignment and audit logs.

Exploit path:
1. A compromised or over-permitted admin session writes directly to
   `/members/{memberId}`.
2. The rules allow changes beyond profile fields, including high-trust fields
   such as role, auth linkage, or relationship arrays, as long as `clanId`
   stays unchanged.
3. The same actor can write `/relationships/{relationshipId}` directly,
   bypassing callable cycle detection and reconciliation.
4. Audit logs, governance role assignment records, and relationship integrity
   protections are skipped.

Recommended fix:
- Make high-trust member fields server-only: `primaryRole`, `authUid`,
  `claimedAt`, relationship arrays, branch reassignment, billing/governance
  status, and review status.
- Route role, auth-link, and relationship mutations through Cloud Functions.
- Add rule diffs/allowlists for admin member edits that are truly direct-client
  safe.
- Add rules emulator tests proving direct relationship writes and direct
  role/auth/relationship-array member mutations fail.

### SG-04 - QA self-test callables are deployed without App Check or prod gate

Severity: High
Release blocker: Yes

Locations:
- `firebase/functions/src/auth/callables.ts:299` defines normal callable App
  Check options.
- `firebase/functions/src/auth/callables.ts:303` defines
  `SELF_TEST_NOTIFICATION_CALLABLE_OPTIONS` with `enforceAppCheck: false`.
- `firebase/functions/src/auth/callables.ts:2049` explicitly skips App Check
  for QA/debug.
- `firebase/functions/src/auth/callables.ts:2204` exports
  `sendSelfTestEventReminder` with the no-App-Check options.
- `firebase/functions/src/auth/callables.ts:2258` creates an event document.
- `firebase/functions/src/auth/callables.ts:2298` triggers reminder dispatch.

Exploit path:
1. Any authenticated user can call these functions from a script without App
   Check.
2. The event reminder self-test path can write scheduled events and trigger
   reminder runs.
3. In production this creates a spam/abuse surface and weakens the app integrity
   boundary that other callable paths enforce.

Recommended fix:
- Disable these callables in production behind an explicit
  `ENABLE_QA_SELF_TESTS=false` runtime flag.
- Require App Check and a QA/admin-only role for any remaining callable.
- Separate debug/QA deployment from production exports if possible.

### SG-05 - CI runs contract tests but not rules emulator tests before release/deploy

Severity: High
Release blocker: Yes

Locations:
- `firebase/functions/package.json:21` defines `npm test` as contract tests.
- `firebase/functions/package.json:23` defines `npm run test:rules`, but it is
  a separate command.
- `.github/workflows/branch-ci.yml:78` runs only `npm test`.
- `.github/workflows/release-main.yml:167` runs only `npm test`.
- `.github/workflows/deploy-firebase.yml:127` builds Functions, then deploys
  rules at `.github/workflows/deploy-firebase.yml:522`.
- `docs/en/06-security/firebase-rules.md:54` says billing collections should be
  included in the emulator/rules matrix before rollout.

Exploit path:
1. A rules regression can pass branch CI and main release gates because
   `npm test` does not execute the runtime Firestore/Storage emulator tests.
2. The production deploy workflow builds Functions and deploys Firestore/Storage
   rules without running `npm run test:rules`.
3. Security regressions in rules can reach production even when local emulator
   tests would catch them.

Recommended fix:
- Add `npm run test:rules` to branch CI, main release quality gates, and the
  Firebase production deploy workflow before `firebase deploy`.
- Keep contract tests, but do not treat regex-based rules contracts as a
  substitute for emulator authorization tests.
- Add explicit tests for SG-01 through SG-03.

### SG-06 - User profile create allows arbitrary subscription/entitlements maps

Severity: Medium
Release blocker: No, but fix before release hardening

Locations:
- `firebase/firestore.rules:179` defines `validUserProfileWrite`.
- `firebase/firestore.rules:195` and `firebase/firestore.rules:196` allow
  `subscription` and `entitlements` keys.
- `firebase/firestore.rules:269` freezes `normalizedPhone`, `subscription`, and
  `entitlements` only when `resource != null`.
- `firebase/functions/src/rules-tests/firebase-rules-emulator.rules.test.ts:157`
  tests updates against an existing user document, not first create.

Exploit path:
1. A user whose `/users/{uid}` document does not exist yet can create it with
   arbitrary `subscription` and `entitlements` maps that match the loose schema.
2. Server billing state remains authoritative, but any client or future feature
   that trusts `/users/{uid}.entitlements` can be tricked into showing premium
   or ad-free behavior.

Recommended fix:
- Make `subscription` and `entitlements` server-only on both create and update,
  or require exact null/absent values on client writes.
- Add a rules emulator test where a first-time user create attempts to seed
  premium entitlements.

### SG-07 - Self profile updates can change verified phone fields directly

Severity: Medium
Release blocker: No, but fix before release hardening

Locations:
- `firebase/firestore.rules:155` defines `safeProfileUpdate`.
- `firebase/firestore.rules:162` includes `phoneE164` in self-editable fields.
- `firebase/firestore.rules:470` allows self member updates through
  `safeProfileUpdate`.
- `firebase/functions/src/auth/callables.ts:4132` and surrounding phone claim
  flow rely on member phone data when resolving claims.

Exploit path:
1. A claimed member updates their own `members/{memberId}.phoneE164` directly.
2. The new phone value has not been verified through OTP.
3. Future phone-lookup, member-claim, or trusted-device flows can be influenced
   by profile data that no longer reflects verified ownership.

Recommended fix:
- Move phone changes to a verified callable that requires OTP confirmation
  before writing `phoneE164`.
- Keep display/contact fields editable, but separate verified login phone from
  profile contact phone if product needs both.

### SG-08 - Trusted device token is long-lived and stored outside secure storage

Severity: Medium
Release blocker: No, but fix before broad rollout

Locations:
- `mobile/befam/lib/features/auth/services/auth_trusted_device_store.dart:4`
  uses `shared_preferences`.
- `mobile/befam/lib/features/auth/services/auth_trusted_device_store.dart:14`
  stores the device token under `auth_trusted_device_token`.
- `mobile/befam/lib/features/auth/services/auth_trusted_device_store.dart:25`
  creates a random bearer-like token.
- `firebase/functions/src/auth/callables.ts:287` sets a 90-day trusted-device
  TTL.
- `firebase/functions/src/auth/callables.ts:4476` persists the trusted device.

Exploit path:
1. Malware, backup restore, rooted-device access, or Flutter web local storage
   exposure extracts the token.
2. The token can satisfy trusted-device checks until expiry or revocation.

Recommended fix:
- Store the token in platform secure storage: Keychain on iOS, Android Keystore
  backed storage on Android, and a separate web strategy if trusted device is
  supported on web.
- Bind the token to device/app integrity signals where available.
- Shorten TTL or require step-up auth before high-trust operations.

### SG-09 - Storage accepts broad content types for clan documents and evidence

Severity: Medium
Release blocker: No, but harden before broad rollout

Locations:
- `firebase/storage.rules:72` checks only size and non-empty content type.
- `firebase/storage.rules:95` allows generic clan path writes for admins.
- `firebase/storage.rules:111` allows scholarship evidence writes by member.
- `firebase/functions/src/contract-tests/firebase-rules-hardening.contract.test.ts:49`
  only validates that payload-shape checks exist, not MIME allowlists or scan
  state.

Exploit path:
1. An admin uploads arbitrary HTML, SVG, scriptable PDF, or malware-like content
   to generic clan storage paths.
2. A member uploads arbitrary evidence content under scholarship paths.
3. If the app later previews or serves these files, the project has stored-XSS,
   malware, and unsafe-file rendering risk.

Recommended fix:
- Restrict content types per path, not just "non-empty content type".
- Add upload metadata for scan status and quarantine unscanned files.
- Avoid in-app rendering of active content types; serve downloads with safe
  content disposition where possible.

### SG-10 - AI assistant allows child sessions and sends sensitive member context

Severity: Medium
Release blocker: No, but harden before broad rollout

Locations:
- `firebase/functions/src/ai/callables.ts:140` includes member match fields
  such as full name, nickname, branch, generation, birth/death date, job title,
  and relationship counts.
- `firebase/functions/src/ai/callables.ts:456` sends app and search context to
  the model prompt.
- `firebase/functions/src/ai/callables.ts:468` sends
  `SEARCH_CONTEXT_JSON`.
- `firebase/functions/src/ai/callables.ts:1872` allows both `claimed` and
  `child` sessions to use the assistant.
- `mobile/befam/lib/features/ai/services/app_assistant_context_service.dart:250`
  sends up to five member matches.
- `mobile/befam/lib/features/ai/services/app_assistant_context_service.dart:256`
  through `:269` include full name, nickname, birth/death date, and job title.

Exploit path:
1. A child session or lower-trust user asks genealogy questions.
2. The client builds member match context with personally sensitive genealogy
   fields.
3. The callable forwards that bounded but still sensitive context to the model
   provider.

Recommended fix:
- Require `memberAccessMode='claimed'` for assistant member search context, or
  introduce a child-safe assistant mode with no member details.
- Reduce fields sent to the model: prefer display labels, coarse age ranges,
  and relationship labels over exact birth/death dates and job titles.
- Add telemetry for model fallback, throttling, and redaction path usage.

### SG-11 - Billing/VNPay documentation and built artifacts no longer match source

Severity: Medium
Release blocker: No, but product/security cleanup required

Locations:
- `docs/en/01-product/epic-tiered-subscription-payments.md:23` says the payment
  journey is VNPay-first.
- `docs/en/04-backend/cloud-functions.md:90` documents
  `simulateVnpaySettlement` and VNPay callbacks.
- `firebase/functions/src/billing/webhooks.ts:1` says card payment webhooks are
  removed and payments are exclusively IAP.
- `firebase/functions/lib/billing/vnpay.js` and
  `firebase/functions/lib/billing/vnpay.js.map` are still present as built
  artifacts.
- `mobile/befam/lib/features/billing/services/firebase_billing_repository.dart:132`
  sends `ownerUid` by default for billing scope.
- `firebase/functions/src/billing/callables.ts:87` gives `ownerUid` precedence
  over clan scope when `ownerUid == uid`.

Exploit path:
1. Security, QA, and product teams validate different payment models: docs say
   VNPay/card, source says IAP, and built output still contains VNPay code.
2. Release reviewers may miss required IAP webhook checks or mistakenly expect
   VNPay signature coverage.
3. Billing scope behavior can be misread as clan-level entitlement while the
   mobile payload defaults to personal owner scope.

Recommended fix:
- Remove stale compiled artifacts from source control or ensure `lib/` is never
  reviewed/deployed as an authoritative source.
- Update product/backend docs to the current IAP-only model, or restore and test
  VNPay if that remains a requirement.
- Document whether entitlement is personal owner scope or clan scope, and add
  tests for the intended scope behavior.

### SG-12 - Shared callable clan access does not verify active clan status

Severity: Medium
Release blocker: No, but harden before release

Locations:
- `firebase/functions/src/shared/permissions.ts:62` checks only that the token
  contains the requested clan ID.
- `firebase/firestore.rules:27` and surrounding helpers enforce active clan
  status for Firestore reads/writes through rules-side access checks.
- `firebase/functions/src/auth/callables.ts:5037` embeds clan status into
  custom claims when session claims are applied.

Exploit path:
1. A user holds a token that still contains a clan ID after the clan becomes
   inactive, suspended, or billing-locked.
2. Callable code that uses only `ensureClanAccess` can proceed even though
   Firestore rules would reject direct client access.
3. Sensitive server writes may occur during an inactive/billing-locked state
   unless each callable performs its own metadata check.

Recommended fix:
- Add a shared `ensureActiveClanAccess` helper that loads clan metadata or
  verifies a fresh active-status claim.
- Apply it to mutation callables for funds, governance, relationships,
  scholarship, billing operations, events, and member management.

### SG-13 - OTP challenge logs expose phone number and verification ID

Severity: Low
Release blocker: No

Locations:
- `mobile/befam/lib/features/auth/presentation/auth_controller.dart:218` logs
  OTP verification start.
- `mobile/befam/lib/features/auth/presentation/auth_controller.dart:219` logs
  raw phone and `verificationId`.
- `mobile/befam/lib/features/auth/presentation/auth_controller.dart:417` logs
  received OTP challenge with raw phone and `verificationId`.

Exploit path:
1. Production device logs, crash logs, or support captures include raw phone and
   OTP verification ID.
2. The verification ID is not the OTP code, but it is still an authentication
   artifact and should not be exposed in routine logs.

Recommended fix:
- Mask phone numbers in mobile logs.
- Omit `verificationId`, or log only a hash/prefix intended for debugging.
- Ensure production logging drops auth artifacts by default.

## Positive Controls Observed

- Production Firebase deploy requires OIDC and validates production project ID
  before deploy (`.github/workflows/deploy-firebase.yml:61`).
- Production deploy blocks `OTP_PROVIDER` values other than `twilio`
  (`.github/workflows/deploy-firebase.yml:360`).
- Production deploy blocks `BILLING_IAP_ALLOW_TEST_MOCK=true`
  (`.github/workflows/deploy-firebase.yml:386`).
- Production deploy blocks `CALLABLE_ENFORCE_APP_CHECK=false`
  (`.github/workflows/deploy-firebase.yml:392`).
- Main release preflight also validates `CALLABLE_ENFORCE_APP_CHECK=true`
  (`.github/workflows/release-main.yml:407`).
- Store purchase verification only allows mock purchases when
  `BILLING_IAP_ALLOW_TEST_MOCK` is enabled
  (`firebase/functions/src/billing/iap-verification.ts:115`).
- Google IAP RTDN webhook rejects unauthorized requests
  (`firebase/functions/src/billing/iap-webhooks.ts:213`).
- AI contract tests verify profile and event payload minimization for those
  specific features.

## Verification Notes

- `npm test` passed locally for Functions contract tests.
- `npm run test:rules` could not complete locally because the emulator ports
  were already occupied. This local blocker does not change SG-05: CI and
  release workflows should run `npm run test:rules` in clean runners.
- `mkdocs build --strict` could not run locally because `mkdocs` is not
  installed in the active shell/Python environment.
- No code files were edited during this audit.
