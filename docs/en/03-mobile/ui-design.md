# UI Design

_Last reviewed: May 16, 2026_

## Design direction

BeFam uses a light lineage workspace style: bright surfaces, clear borders,
strong readable text, BeFam blue emphasis, and small trust signals. The product
should feel like a calm clan operations tool, not a generic social feed.

`DESIGN.md` is the canonical design contract for BeFam and now follows the
Google Labs `design.md` format: YAML design tokens first, then product guidance.
When changing UI, motion, form behavior, or release-facing copy, update that
file first and validate it with:

```bash
./scripts/lint_design_md.sh
```

## Theme and visual language

- custom Material 3 color scheme in `app/theme/app_theme.dart`
- primary tones: BeFam blue, green trust states, white workspace surfaces, and
  subtle blue-gray borders
- cards and sections use clear spacing and high readability over dense layouts
- avoid decorative gradients, blobs, staged entrance effects, and heavy
  marketing composition inside the app shell
- keep web, iOS, and Android aligned to the same `DESIGN.md` colors,
  typography, spacing, shape, component, and motion contracts

## UX improvements now reflected in app

- default locale is Vietnamese with full English fallback
- OTP input uses six visual cells in a single horizontal row and auto-submits
  when six digits are entered
- long forms are split into clearer sections with sticky action placement
- member and genealogy screens prioritize human-readable copy and relationships
- dual calendar card, month grid, and day tile layouts are tuned for large text
  and lower-end devices
- required form fields now use a shared label/field decoration pattern
- async buttons show press feedback, loading progress, and repeat-tap protection

## Forms, timers, and actions

- Required fields must be visibly marked and must show an inline error before
  the user can move forward.
- Multi-step editors validate the current step before navigation. This applies
  to auth, clan, branch, member, event, fund, and scholarship flows.
- Error copy is short and specific: tell the user which field to fix, not a
  generic failure state.
- Timers such as OTP resend cooldowns use a compact progress indicator and
  remaining time.
- Async buttons use `AppActionButton` or `AppAsyncAction` so the button gives
  immediate feedback, shows progress when a request is in flight, and blocks
  double submits.
- Screen transitions use BeFam's scale-only transition. Do not use slide or fade
  as a default tap response.

## Accessibility and resilience

- large text compatibility and overflow hardening
- generous tap targets and legible heading hierarchy
- reduced cognitive load in home/auth copy
- icon-only actions include explicit tooltips on core workspace screens
- workspace loading states include readable progress messaging and live-region
  semantics via `core/widgets/app_feedback_states.dart`
- calendar day tiles provide richer semantic labels for solar/lunar context and
  event counts

## Empty/loading/error audit baseline

- all major workspaces now render explicit loading states instead of spinner-only
  placeholders
- no-context and empty states provide user-facing guidance in each module
- retry actions are available on recoverable error states
- runtime widget crashes show a fallback card UI instead of a broken frame

## Form validation test matrix

Run these targeted checks when touching form, timer, action, or navigation
motion behavior:

```bash
cd mobile/befam
flutter analyze
flutter test test/core/widgets/app_form_controls_test.dart
flutter test test/widget_test.dart --name "auth phone form|auth child and OTP|clan editor shows|branch editor shows|member add form blocks|filters parent candidates"
flutter test test/features/events/event_widget_test.dart --name "edit form shows required title error before moving on"
flutter test test/features/funds/fund_form_validation_widget_test.dart
flutter test test/features/scholarship/scholarship_flow_widget_test.dart --name "create forms surface required errors before continuing"
```

## Content style

- concise, direct wording for critical actions
- status and guidance shown inline where needed
- debug-only visual noise removed from production-facing screens

Planned billing UX principles:

- transparent plan/price display with VAT-included wording
- always-visible subscription expiry for clan owner/admin users
- clear payment-mode control (auto-renew vs manual)
- visible ad entitlement label by plan (Free/Base: ads, Plus/Pro: ad-free)
- ad placements must be non-intrusive and excluded from sensitive flows
- non-technical error messages for failed checkout/callback states
