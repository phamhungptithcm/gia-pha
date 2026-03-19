# Mobile Architecture

_Last reviewed: March 15, 2026_

## App layout

The mobile app lives in `mobile/befam` and uses a feature-first structure:

```text
lib/
  app/            # shell, theme, bootstrap, home dashboard
  core/           # firebase services, logging, crash reporting
  features/       # auth, clan, member, relationship, genealogy, calendar, funds, scholarship, notifications, profile
  l10n/           # vi/en ARB files and generated localization classes
```

## State and control flow

- `AuthController` orchestrates auth steps and session persistence
- feature controllers (for example `MemberController`) use `ChangeNotifier`
  with repository abstractions
- repositories use Firebase-backed implementations in runtime flows

## Runtime strategy

- runtime app flow is Firebase-first (auth, callables, Firestore-backed data)
- test suites can still use dedicated test doubles/fixtures
- app bootstrap returns Firebase readiness metadata used by shell UX/tooltips

## Navigation shell

- root entry starts in auth experience
- signed-in users land in `AppShellPage` with destinations:
  - Home
  - Tree
  - Events (dual calendar workspace)
  - Profile (workspace)
- push deep-link handler can redirect users to relevant destination context
- notification inbox and target pages are accessible through profile/events
  surfaces

## Quality and accessibility direction

- Vietnamese-first copy and large-text friendly layout tuning
- six-digit OTP interaction with auto-submit behavior on complete input
- clearer long-form sections and search-first people interactions
- responsive cards and list patterns optimized for both older and younger users
- calendar and profile surfaces tuned for text scaling and overflow resilience

## Planned mobile addition

- subscription management and checkout UX (card + VNPay) for clan owner/admin
  users (Epic #213)
- plan-based ad entitlement rendering (show ads on Free/Base, suppress ads on
  Plus/Pro)
