# Analytics

_Last reviewed: April 2, 2026_

## Current analytics surface

BeFam uses Firebase Analytics instrumentation for authentication, member
search, genealogy discovery join-request funnels, and onboarding journeys.
Event and property identifiers are
centralized in:

- `mobile/befam/lib/core/services/analytics_event_names.dart`

## Event constants in use

### Auth analytics events

Tracked from `AuthAnalyticsService`:

- `auth_method_selected`
- `auth_otp_requested`
- `auth_child_context_resolved`
- `auth_session_established`
- `auth_failure`
- `auth_logout`

### Member search analytics events

Tracked from `MemberSearchAnalyticsService`:

- `member_search_submit`
- `member_search_failed`
- `member_search_filters_updated`
- `member_search_retry`
- `member_search_open_result`

### Genealogy discovery analytics events

Tracked from `GenealogyDiscoveryAnalyticsService`:

- `genealogy_discovery_search_submitted`
- `genealogy_discovery_search_failed`
- `genealogy_my_join_requests_opened`
- `genealogy_join_request_sheet_opened`
- `genealogy_join_request_sheet_dismissed`
- `genealogy_join_request_duplicate_blocked`
- `genealogy_join_request_submitted`
- `genealogy_join_request_submit_failed`
- `genealogy_join_request_canceled`
- `genealogy_join_request_cancel_failed`
- `genealogy_join_request_review_submitted`
- `genealogy_join_request_review_failed`

### Onboarding analytics events

Tracked from `OnboardingAnalyticsService`:

- `onboarding_started`
- `onboarding_step_viewed`
- `onboarding_completed`
- `onboarding_skipped`
- `onboarding_interrupted`
- `onboarding_anchor_missing`

### User properties

- `auth_method`
- `member_access_mode`

## Instrumentation rules

- new analytics events must be added to `AnalyticsEventNames` before use
- user properties must be added to `AnalyticsUserPropertyNames`
- event names use lowercase snake_case
- debug-only flows may use noop analytics service implementations

## Current operational behavior

- member search analytics default to noop in debug mode
- genealogy discovery analytics default to noop when Firebase is not bootstrapped
- onboarding analytics default to noop when Firebase is not bootstrapped
- production-mode paths emit events through Firebase Analytics
- push and notification delivery outcomes are logged in backend function logs

## Onboarding funnel operations

- flow definitions can be seeded from:
  - `mobile/befam/config/onboarding/sample_onboarding_flows.json`
- rollout gates are documented in:
  - `mobile/befam/config/onboarding/README.md`
- BigQuery validation query lives at:
  - `mobile/befam/config/onboarding/onboarding_funnel_bigquery.sql`

Recommended dashboard cuts:

- flow starts by `flow_id`
- completion rate by `flow_id` and `flow_version`
- drop-off by `step_index`
- `anchor_missing` count by `route_id`
- skip vs interrupted ratio per flow

## Join-request funnel operations

- discovery funnel covers:
  - search
  - join-request sheet open and dismiss
  - submit success and failure
  - user-side cancellation
  - reviewer approval and rejection
- my request queue health can be segmented with:
  - `genealogy_my_join_requests_opened`
  - `genealogy_join_request_canceled`
  - `genealogy_join_request_cancel_failed`
- review throughput can be segmented with:
  - `genealogy_join_request_review_submitted`
  - `genealogy_join_request_review_failed`

## Next analytics opportunities

- instrument genealogy interaction depth and focus actions
- add conversion funnel metrics for tiered subscription checkout:
  - `subscription_screen_view`
  - `subscription_plan_viewed` (free/base/plus/pro)
  - `subscription_mode_changed` (auto/manual)
  - `checkout_started` (card/vnpay)
  - `checkout_completed`
  - `checkout_failed`
  - `ad_impression_served` (free/base only)
  - `ad_suppressed_by_plan` (plus/pro)
  - `renewal_reminder_opened`
- align dashboard definitions with release and adoption KPIs
