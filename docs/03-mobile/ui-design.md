# UI Design

_Last reviewed: March 14, 2026_

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

## Content style

- concise, direct wording for critical actions
- status and guidance shown inline where needed
- debug-only visual noise removed from production-facing screens

Planned billing UX principles:

- transparent tier/price display with VAT-included wording
- always-visible subscription expiry for clan owner/admin users
- clear payment-mode control (auto-renew vs manual)
- non-technical error messages for failed checkout/callback states
