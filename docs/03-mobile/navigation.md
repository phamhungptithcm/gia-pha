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

The Events and Profile tabs are currently placeholder workspaces while the tree
and member/clan workflows are production-focused.

## Notification-driven navigation

- push service listens to foreground and opened-app FCM events
- event-target notifications can switch users to the Events destination
- message payloads are normalized into `NotificationDeepLink` objects

## UX goals for navigation

- low-friction auth onboarding
- readable hierarchy for older users
- predictable back behavior in forms and detail pages
