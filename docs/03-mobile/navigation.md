# Navigation

_Last reviewed: March 14, 2026_

## Entry flow

1. `main.dart` initializes Firebase and app bootstrap status.
2. `BeFamApp` opens `AuthExperience`.
3. On successful session restore or OTP verification, app transitions to
   `AppShellPage`.

## Auth navigation states

- login method selection
- phone number input
- child identifier input
- OTP verification with six-cell visual input and auto-submit on completion

## Shell destinations

Current bottom navigation destinations:

- Home
- Tree
- Events
- Profile

The Events tab now hosts the dual calendar workspace. Notification inbox and
target pages are reachable from deep-link and profile/settings entry points.
Profile is now a real workspace (not a placeholder).

## Notification-driven navigation

- push service listens to foreground and opened-app FCM events
- event-target and scholarship-target notifications switch users to the Events
  destination and open target placeholder pages
- message payloads are normalized into `NotificationDeepLink` objects

Planned addition:

- billing reminder deep-links to subscription management screen (Epic #213)

## UX goals for navigation

- low-friction auth onboarding
- readable hierarchy for older users
- predictable back behavior in forms and detail pages
