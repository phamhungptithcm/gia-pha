# Technical Lead Billing/Security Review - 2026-05-17

Branch: `hunpeolabs/ai-production-ux-pass`

Scope: navigation/billing/funds separation, security-sensitive guards,
maintainability, and tests. No production code was changed in this review.

Tooling notes:

- CodeRabbit CLI was installed, but agent review could not run because
  authentication required browser login.
- GitNexus index status: up to date for commit `4c214bd`. CLI query/context
  had limited results because local FTS initialization attempted writes against
  a read-only database, so source review and graphify were used for final
  file/line validation.
- Targeted Flutter tests passed:
  `flutter test test/app/home/app_shell_billing_tab_test.dart test/features/notifications/notification_shell_deep_link_test.dart test/features/billing/billing_workspace_page_test.dart`

## Direct Answers

### Da thay `Goi` thanh `Quy` o dau?

- Main shell bottom navigation changed destination index 3 from billing to
  funds in both linked and unlinked destination lists:
  `mobile/befam/lib/app/home/app_shell_page.dart:168` and
  `mobile/befam/lib/app/home/app_shell_page.dart:196`.
- The shell page at index 3 now renders `FundWorkspacePage`, not
  `BillingWorkspacePage`:
  `mobile/befam/lib/app/home/app_shell_page.dart:1024`.
- Localized shell labels/titles now include `funds => Quỹ/Quỹ họ`, while
  `billing => Gói/Gói dịch vụ` remains as a non-tab route:
  `mobile/befam/lib/l10n/l10n.dart:91`.
- Tests assert the visible nav order is `Funds`, then `Profile`:
  `mobile/befam/test/app/home/app_shell_billing_tab_test.dart:92` and
  `mobile/befam/test/app/home/app_shell_billing_tab_test.dart:165`.

### Mua goi hien reachable tu dau?

- Primary path: `Profile` -> section `Gói của bạn` -> button
  `Đổi hoặc nâng cấp` opens `BillingWorkspacePage`:
  `mobile/befam/lib/features/profile/presentation/profile_workspace_page.dart:1234`,
  `mobile/befam/lib/features/profile/presentation/profile_workspace_page.dart:1439`,
  and `mobile/befam/lib/features/profile/presentation/profile_workspace_page.dart:1709`.
- Billing notification deep links push `BillingWorkspacePage` directly:
  `mobile/befam/lib/app/home/app_shell_page.dart:372` and
  `mobile/befam/lib/app/home/app_shell_page.dart:471`.
- AI assistant suggested destination `billing` can push `BillingWorkspacePage`
  from allowed AI screens:
  `mobile/befam/lib/app/home/app_shell_page.dart:1073`,
  `mobile/befam/lib/app/home/app_shell_page.dart:1091`, and
  `mobile/befam/lib/features/ai/presentation/app_assistant_launcher.dart:443`.
- Actual checkout button is inside `BillingWorkspacePage` and only attempts
  store checkout on iOS/Android non-sandbox/non-web sessions:
  `mobile/befam/lib/features/billing/presentation/billing_workspace_page.dart:101`,
  `mobile/befam/lib/features/billing/presentation/billing_workspace_page.dart:711`,
  and `mobile/befam/lib/features/billing/presentation/billing_workspace_page.dart:743`.

### Co regression khong?

No direct shell navigation regression was found for the requested `Gói` ->
`Quỹ` tab separation: targeted tests pass and the bottom nav no longer exposes
Billing as a tab.

There are blocking billing/security regressions or current-code risks that
should be fixed before production billing rollout. The top blocker is that the
real Firebase billing repository always sends `ownerUid`, causing callable
scope resolution to choose personal billing scope before clan scope. Existing
debug tests use clan scope and do not catch this production-path mismatch.

## Findings

### P0 - Real Firebase billing calls default to personal scope, not clan scope

Files/lines:

- `mobile/befam/lib/features/billing/services/firebase_billing_repository.dart:132`
- `firebase/functions/src/billing/callables.ts:87`
- `firebase/functions/src/billing/callables.ts:96`
- `mobile/befam/test/support/features/billing/services/debug_billing_repository.dart:671`

Impact:

The real client `_scopePayload` always sends `ownerUid: session.uid`. Server
scope resolution returns `user_scope__<uid>` when `ownerUid == uid` before it
checks `clanId`. For a normal clan session, load workspace, resolve
entitlement, preferences, and IAP verification can target personal billing
instead of the active clan subscription. The debug repository does the opposite
and returns `session.clanId` when present, so current widget tests can pass while
production callable traffic is scoped differently.

Recommended fix:

- Change Firebase client payload to send `clanId: session.clanId` for claimed
  clan sessions and only send owner/personal scope for no-clan personal billing.
- Add a repository-level test/fake callable assertion for `_scopePayload`.
- Add a callable contract test proving claimed clan sessions resolve the active
  clan scope and no-clan sessions resolve `user_scope__<uid>`.

Tests needed:

- `flutter test test/features/billing/billing_repository_test.dart`
- Add targeted Firebase repository payload test.
- `cd firebase/functions && npm test -- --runInBand billing`

### P1 - Billing owner mutation guard exists but is not enforced

Files/lines:

- `firebase/functions/src/billing/callables.ts:141`
- `firebase/functions/src/billing/callables.ts:177`
- `firebase/functions/src/billing/callables.ts:366`
- `firebase/functions/src/billing/callables.ts:421`
- `mobile/befam/lib/features/billing/presentation/billing_controller.dart:50`
- `mobile/befam/lib/features/billing/presentation/billing_workspace_page.dart:462`
- `mobile/befam/lib/features/billing/models/billing_workspace_snapshot.dart:133`

Impact:

`requireOwnerMutationAccess` is implemented but never passed by
`updateBillingPreferences` or `verifyInAppPurchase`. If a caller supplies a
clan scope, any `BILLING_ADMIN_ROLES` member can mutate billing preferences or
attach an IAP payment to the clan owner scope. The client also treats any
non-empty uid as `canMutateBilling`, ignoring `scope.viewerIsOwner`.

Recommended fix:

- Decide the product rule explicitly: clan owner only, or named billing admins.
- If owner-only, pass `requireOwnerMutationAccess: true` for billing mutation
  callables and gate client checkout/preference writes on
  `workspace.scope.viewerIsOwner`.
- If billing admins may mutate, remove owner-only copy and dead guard to avoid a
  misleading security model.

Tests needed:

- Callable tests: clan owner can update/verify, branch admin/non-owner billing
  admin is denied if owner-only.
- Flutter test: non-owner workspace shows view-only plan state and no checkout
  button.

### P2 - Notification fallback copy still points users to a removed `Gói` tab

Files/lines:

- `mobile/befam/lib/features/notifications/presentation/notification_target_page.dart:39`
- `mobile/befam/test/features/notifications/notification_shell_deep_link_test.dart:186`

Impact:

The main opened-app deep link correctly pushes `BillingWorkspacePage`, but the
generic notification target page still says "Mở mục Gói" / "Open Billing".
The test name also says "opens billing tab" even though the implementation now
opens a pushed page. This is not a runtime blocker, but it creates stale UX and
test intent after the navigation separation.

Recommended fix:

- Change fallback copy to "Mở trang gói từ Hồ sơ" or "Open plan details".
- Rename the test to "opens billing workspace from opened-app deep link".

Tests needed:

- `flutter test test/features/notifications/notification_shell_deep_link_test.dart`

### P2 - Shell premium-intent analytics no longer fires for reachable billing paths

Files/lines:

- `mobile/befam/lib/features/ads/services/ad_controller.dart:177`
- `mobile/befam/lib/features/ads/services/ad_controller.dart:192`
- `mobile/befam/lib/app/home/app_shell_page.dart:471`
- `mobile/befam/lib/features/profile/presentation/profile_workspace_page.dart:1709`

Impact:

`AdController.recordNavigationTransition` marks premium intent only when a shell
tab transition lands on screen id `billing`. Since billing is no longer a shell
destination, profile/notification/AI routes to billing do not record this
conversion signal. This can distort premium intent and ad suppression metrics.

Recommended fix:

- Emit premium intent when pushing `BillingWorkspacePage` from profile,
  notification, or AI destination, or move the signal into
  `BillingWorkspacePage` initialization with source metadata.

Tests needed:

- Add analytics/ad-controller unit or widget test for profile -> billing route.

### P3 - Billing shell embedding props are now dead maintainability surface

Files/lines:

- `mobile/befam/lib/features/billing/presentation/billing_workspace_page.dart:27`
- `mobile/befam/lib/features/billing/presentation/billing_workspace_page.dart:30`
- `mobile/befam/lib/features/billing/presentation/billing_workspace_page.dart:85`
- `mobile/befam/lib/app/home/app_shell_page.dart:1024`

Impact:

`embeddedInShell` and `onPricingQuickActionChanged` remain in
`BillingWorkspacePage`, but shell no longer embeds billing. This increases
stateful registration complexity and leaves an app-bar quick-action pathway that
no longer has a shell consumer.

Recommended fix:

- Remove shell-only billing embedding API if no upcoming shell billing tab is
  planned.
- Keep the local app-bar pricing action for pushed billing pages.

Tests needed:

- `flutter test test/features/billing/billing_workspace_page_test.dart`

## Security Guard Assessment

- Funds client gating is aligned with finance roles:
  `FundController.canViewFunds` and `canManageFunds` use
  `GovernanceRoleMatrix` at
  `mobile/befam/lib/features/funds/presentation/fund_controller.dart:63`.
- Funds write path is server-side guarded by claimed session, finance manager
  roles, clan access, active fund state, and balance checks:
  `firebase/functions/src/funds/callables.ts:37`,
  `firebase/functions/src/funds/callables.ts:39`,
  `firebase/functions/src/funds/callables.ts:80`, and
  `firebase/functions/src/funds/callables.ts:96`.
- Firestore rules keep fund transaction writes server-only and billing writes
  server-only:
  `firebase/firestore.rules:508`, `firebase/firestore.rules:520`,
  `firebase/firestore.rules:643`, and `firebase/firestore.rules:653`.
- Billing mutation guard needs tightening as noted in P1.

## Release Recommendation

Do not ship production billing purchase UX until P0 and P1 are resolved or
explicitly accepted as product decisions. The `Gói` -> `Quỹ` navigation split is
functionally in place, but production billing scope and mutation ownership need
hardening before real payments are exposed.
