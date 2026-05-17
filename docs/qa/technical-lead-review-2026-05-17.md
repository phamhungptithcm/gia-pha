# Technical Lead Review - BeFam Production Readiness

Date: 2026-05-17
Branch: `hunpeolabs/ai-production-ux-pass`
Reviewed commit: `dd87d21` against `dd87d21^`
Scope: auth/session, app shell navigation, funds/event validation, docs/tests.

## Executive Summary

No P0/P1 blockers found in the reviewed diff. The changes pass targeted widget
tests and analyzer, and I did not find a direct clan-isolation or server-side
permission regression.

Production readiness is still conditional on resolving two P2 regressions around
shell navigation/AI destination handling and ad dismissal behavior. Both are
user-visible and tied to the shell tab change from billing to funds.

## Findings

### P0

None found.

### P1

None found.

### P2

#### P2-1: AI can render a Billing CTA that no longer navigates anywhere

- Files/lines:
  - `mobile/befam/lib/app/home/app_shell_page.dart:168`
  - `mobile/befam/lib/app/home/app_shell_page.dart:1017`
  - `mobile/befam/lib/app/home/app_shell_page.dart:1084`
  - `mobile/befam/lib/features/ai/services/ai_assist_service.dart:335`
  - `mobile/befam/lib/features/ai/services/ai_assist_service.dart:732`
  - `mobile/befam/lib/features/ai/presentation/app_assistant_launcher.dart:825`
- Issue: the shell destination list now uses `funds` at index 3, but assistant
  replies still accept/produce `billing` as a valid `suggestedDestination`.
  `_TranscriptBubble` renders the CTA, then `AppShellPage` tries to find
  `billing` inside the current shell destinations and silently does nothing.
- Impact: user-facing dead action in a high-trust billing/AI flow. This is not a
  clan data leak, but it breaks task completion and makes AI guidance look
  unreliable.
- Recommendation: either keep `billing` as an explicit routable assistant
  destination that pushes `BillingWorkspacePage`, or update AI destination
  contracts/tests to use `profile`/billing hub and add `funds` support.
- UI UX Manager review: required. Confirm whether billing should be a hidden
  route, profile sub-flow, notification-only route, or restored shell affordance.

#### P2-2: Closing the ad banner is no longer respected across tab navigation

- Files/lines:
  - `mobile/befam/lib/app/home/app_shell_page.dart:576`
  - `mobile/befam/lib/app/home/app_shell_page.dart:584`
  - `mobile/befam/lib/app/home/app_shell_page.dart:1148`
  - `mobile/befam/lib/app/home/app_shell_page.dart:1154`
- Issue: the close handler sets `_dismissAdBannerForSession = true`, but every
  destination change now resets it to `false`. The field name and previous
  behavior imply a session-level dismissal, but after this commit a user can
  close the banner, tap another tab, and see it return.
- Impact: regression in perceived quality and ad fatigue. This is especially
  sensitive because BeFam handles trust-heavy family workflows; repeated banner
  resurfacing can feel coercive.
- Recommendation: keep the dismissal sticky for the app-shell session unless a
  deliberate premium/billing entry point requires a reset. Add a widget test for
  close -> navigate -> banner remains dismissed.
- UI UX Manager review: required. Confirm intended ad reappearance policy by
  surface, especially for finance/events/family-tree tasks.

### P3

#### P3-1: Unlinked sessions now expose a Funds tab that leads to a locked surface

- Files/lines:
  - `mobile/befam/lib/app/home/app_shell_page.dart:179`
  - `mobile/befam/lib/app/home/app_shell_page.dart:195`
  - `mobile/befam/lib/app/home/app_shell_page.dart:1017`
  - `mobile/befam/lib/features/funds/presentation/fund_controller.dart:63`
  - `mobile/befam/lib/features/funds/presentation/fund_controller.dart:95`
- Issue: `_unlinkedDestinations` includes `funds`, but `FundController` denies
  finance access for these sessions and shows the locked state. The prior test
  asserted unlinked users could open personal billing from this tab; the new test
  only asserts discovery/create-clan pages are absent.
- Impact: no clan-isolation bug, but it is a product regression risk: unlinked
  users get a shell tab with no useful next step.
- Recommendation: for unlinked sessions, route index 3 to profile billing,
  genealogy discovery/join guidance, or remove/disable the tab until clan context
  exists.
- UI UX Manager review: required. Decide the intended unlinked shell information
  architecture.

#### P3-2: Funds screen AI uses generic helper copy and does not recognize `funds` as a destination

- Files/lines:
  - `mobile/befam/lib/app/home/app_shell_page.dart:1067`
  - `mobile/befam/lib/features/ai/services/ai_assist_service.dart:679`
  - `mobile/befam/lib/features/ai/services/ai_assist_service.dart:710`
  - `mobile/befam/lib/features/ai/services/ai_assist_service.dart:732`
  - `mobile/befam/lib/features/ai/presentation/app_assistant_launcher.dart:1390`
- Issue: the assistant is enabled on the funds tab, but the AI service and
  launcher configuration do not have funds-specific fallback answers, quick
  replies, icon mapping, or default destination handling. The default prompts
  still point users toward finding relatives rather than fund workflows.
- Impact: bounded AI quality issue. It does not expose additional data, but it
  violates BeFam's AI guardrail that AI should be task-specific and embedded in
  the active workflow.
- Recommendation: either add a funds-specific assistant config with conservative
  finance wording, or suppress the assistant on funds until finance-safe guidance
  is designed and tested.
- UI UX Manager review: required. Also route to AI/product review because this
  is a finance-adjacent advisory surface.

#### P3-3: Client-side expense balance validation can block a valid transaction on stale balance

- Files/lines:
  - `mobile/befam/lib/features/funds/presentation/fund_workspace_page.dart:1443`
  - `mobile/befam/lib/features/funds/presentation/fund_workspace_page.dart:2975`
  - `mobile/befam/lib/features/funds/services/firebase_fund_repository.dart:296`
  - `mobile/befam/lib/features/funds/services/fund_transaction_validation.dart:52`
- Issue: the sheet captures `fund.balanceMinor` when opened and blocks expenses
  above that captured value before calling the repository. In a multi-admin clan,
  a concurrent donation or correction can make the backend balance higher while
  the open sheet still blocks the expense.
- Impact: no overspend security regression because the backend/callable remains
  authoritative, but this can cause false client-side rejection in finance ops.
- Recommendation: keep the friendly warning, but allow submit after refresh or
  re-resolve the fund balance before blocking. Add a repository/controller test
  for stale client balance vs callable authority if this flow supports concurrent
  treasurers.

## Security, Privacy, Clan Isolation

- No direct P0/P1 security or privacy regression found in the diff.
- Funds access remains controller-gated through `GovernanceRoleMatrix` and
  repository/callable paths still depend on the active `AuthSession` clan context.
- Unlinked users are denied funds access, which preserves clan isolation but
  creates the P3 UX dead-end above.
- Remote debug login profiles remain gated by `!kReleaseMode`,
  `BEFAM_USE_MOCK_AUTH`, and `BEFAM_USE_REMOTE_DEBUG_LOGIN_PROFILES`; profiles
  must also be `isActive: true` and `isTestUser: true`.
- AI changes reviewed here do not appear to increase sensitive payload scope, but
  the funds tab should not ship with generic AI guidance for a finance-adjacent
  workflow without explicit product/UX approval.

## Performance Risk

- No analyzer issues found.
- Targeted tests emitted normal local perf logs; no slow-path failure observed.
- Potential performance/regression watch item: funds workspace loads both funds
  and treasurer dashboard when opened from the shell. This was not introduced as
  a failure in this commit, but keep an eye on first-open latency as funds moves
  into primary navigation.

## Docs And Tests

- Docs correctly describe the new
  `BEFAM_USE_REMOTE_DEBUG_LOGIN_PROFILES=true` opt-in.
- Tests added coverage for fund/event validation and the funds shell tab.
- Missing test coverage:
  - assistant suggested `billing` destination after billing tab removal;
  - ad banner dismissal after tab navigation;
  - unlinked funds tab intended state;
  - funds-specific assistant copy/CTA behavior.

## Verification Run

From `mobile/befam`:

```bash
flutter test test/app/home/app_shell_billing_tab_test.dart test/features/events/event_widget_test.dart test/features/funds/fund_form_validation_widget_test.dart
flutter analyze
```

Results:

- Targeted widget tests: passed.
- `flutter analyze`: passed, no issues.

From repo root:

```bash
git diff --check dd87d21^ dd87d21
```

Result: passed.

Graphify note: read `graphify-out/GRAPH_REPORT.md` before reviewing
architecture-sensitive areas. GitNexus MCP tools were not exposed in this Codex
session; no source symbols were edited.

