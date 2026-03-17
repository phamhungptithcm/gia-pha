# UI Design

_Last reviewed: March 15, 2026_

## Design direction

BeFam uses a warm light theme with strong contrast and large rounded surfaces
to keep the app approachable for both younger and older users.

## Theme and visual language

- custom Material 3 color scheme in `app/theme/app_theme.dart`
- primary tones: deep blue with cream/beige support surfaces
- cards and sections use clear spacing and high readability over dense layouts

## UX improvements now reflected in app

- default locale is Vietnamese with full English fallback
- OTP input uses six visual cells in a single horizontal row and auto-submits
  when six digits are entered
- long forms are split into clearer sections with sticky action placement
- member and genealogy screens prioritize human-readable copy and relationships
- dual calendar card, month grid, and day tile layouts are tuned for large text
  and lower-end devices

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
