# Analytics

_Last reviewed: March 15, 2026_

## Current analytics surface

BeFam uses Firebase Analytics instrumentation for authentication and member
search journeys. Event and property identifiers are centralized in:

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
- production-mode paths emit events through Firebase Analytics
- push and notification delivery outcomes are logged in backend function logs

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
