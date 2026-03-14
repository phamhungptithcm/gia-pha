# FLUTTER IMPLEMENTATION PLAN
## Family Clan App

This document provides the implementation plan for AI agents building the Flutter app.

> Implementation note (March 14, 2026): this plan is the architectural
> baseline. Current delivered structure and behavior are documented in
> `docs/03-mobile/*` and `docs/02-architecture/mobile-architecture.md`.

## 1. App Architecture

Use a feature-first Clean Architecture style.

```text
mobile/befam/
  lib/
    app/
      app.dart
      bootstrap.dart
      router/
      theme/
    core/
      constants/
      errors/
      services/
      utils/
      widgets/
    features/
      auth/
      clan/
      genealogy/
      members/
      events/
      funds/
      scholarship/
      notifications/
      profile/
    shared/
      models/
      enums/
      extensions/
  test/
  integration_test/
```

## 2. Recommended Packages

Core:
- `flutter_riverpod`
- `go_router`
- `freezed_annotation`
- `json_annotation`
- `firebase_core`
- `firebase_auth`
- `cloud_firestore`
- `firebase_storage`
- `firebase_messaging`
- `firebase_crashlytics`
- `intl`
- `logger`
- `collection`

UI / Utility:
- `cached_network_image`
- `flutter_svg`
- `image_picker`
- `uuid`
- `equatable` optional if not using freezed

Dev dependencies:
- `build_runner`
- `freezed`
- `json_serializable`
- `flutter_lints`
- `mocktail`

Tree rendering:
- start with a graph/tree package only if it supports large custom layout
- otherwise implement custom painter + viewport virtualization

## 3. Architectural Rules

- widgets must stay dumb where possible
- state lives in Riverpod notifiers/providers
- repository interfaces exist in domain or feature boundary
- firebase implementation stays in data layer
- map Firebase exceptions to typed app exceptions
- screens call use-case-like controller methods, not raw services

## 4. Theme and UX

Color palette:
- `#30364F`
- `#ACBAC4`
- `#E1D9BC`
- `#F0F0DB`

Rules:
- large touch targets
- readable typography
- bottom navigation or home-dashboard shortcuts for main modules
- minimal form complexity
- Vietnamese-first text but structure should support localization later

## 5. Navigation Map

Routes:

```text
/splash
/login
/login/otp
/login/child
/home
/clan/:clanId
/tree
/member/:memberId
/events
/events/:eventId
/funds
/funds/:fundId
/scholarship
/scholarship/:programId
/notifications
/profile
/settings
```

Use GoRouter with:
- auth redirect
- clan context guard
- deep-link friendly event and member routes

## 6. Feature Breakdown

### 6.1 Auth Feature

Files:
```text
features/auth/
  data/
    auth_repository_impl.dart
    auth_remote_data_source.dart
  domain/
    auth_repository.dart
    entities/
  presentation/
    controllers/
    screens/
    widgets/
```

Core screens:
- splash
- login method selection
- phone login
- OTP verification
- child identifier flow

Controller responsibilities:
- request OTP
- verify OTP
- resolve claim flow
- load initial member context

### 6.2 Clan Feature

Capabilities:
- create clan
- edit clan
- create branch
- assign leader / vice leader
- list branches

### 6.3 Members Feature

Capabilities:
- view member profile
- edit own profile
- add member
- claim member record
- search members

### 6.4 Genealogy Feature

Capabilities:
- load tree root entry points
- render ancestry / descendants
- connect parent-child
- connect spouse
- inspect member relations

Key technical rule:
- do not render the entire clan as a fully expanded canvas by default
- default to branch-first or root-first view
- expand lazily

### 6.5 Events Feature

Capabilities:
- event list
- event detail
- create event
- edit event
- reminders
- event filtering

### 6.6 Funds Feature

Capabilities:
- list funds
- fund detail
- donations
- expenses
- transaction history
- balance summary

### 6.7 Scholarship Feature

Capabilities:
- list programs
- view award levels
- submit achievement
- review submissions
- approve / reject

### 6.8 Notifications Feature

Capabilities:
- notification inbox
- mark read
- deep-link to target object

## 7. State Management Pattern

Use Riverpod Notifier / AsyncNotifier.

Pattern:
- `Screen` observes provider
- `Controller` performs actions
- `Repository` abstracts data source
- `Model` maps Firestore payloads
- `State` uses Freezed unions for loading/success/error if needed

Example provider naming:
- `authControllerProvider`
- `memberProfileProvider(memberId)`
- `clanBranchesProvider(clanId)`
- `treeViewProvider(treeQuery)`

## 8. Error Handling

Create `AppException` hierarchy:
- `NetworkException`
- `PermissionDeniedException`
- `ValidationException`
- `NotFoundException`
- `AuthenticationException`
- `UnknownAppException`

All repository methods return either:
- domain data or throw typed exception
- optionally use result wrappers if team prefers functional style

## 9. Logging and Analytics

- use `logger` for debug/dev logs
- use Crashlytics for production crash/error capture
- instrument analytics for critical flows:
  - login success
  - tree opened
  - member searched
  - event created
  - donation recorded
  - scholarship submitted

## 10. Testing Strategy

### Unit tests
- repositories
- controllers
- pure genealogy algorithms
- validation helpers

### Widget tests
- login flow widgets
- member profile form
- event creation form
- fund transaction list

### Integration tests
- auth happy path
- tree load for medium dataset
- create event
- submit achievement

Minimum quality bar:
- critical domain logic tested
- no new feature merged without at least controller/repository tests

## 11. Performance Guidelines

- paginate long lists
- use `select` or granular providers where appropriate
- memoize computed tree data
- avoid rebuilding entire canvases
- cache avatars and static profile images
- prefer incremental fetch for descendants/ancestors

## 12. Accessibility and Localization

- text scaling should not break primary flows
- support screen readers for primary forms
- avoid icon-only critical actions
- prepare all strings for localization wrapper, even if MVP is Vietnamese-only

## 13. Suggested Sprint Order

1. bootstrap app
2. auth + routing
3. clan context + member profile
4. genealogy backend read + member search
5. tree view MVP
6. events + notifications
7. funds
8. scholarship
9. polish + analytics + error hardening

## 14. Definition of Done for AI Agents

A feature is done when:
- screen implemented
- providers/controllers implemented
- repository integrated
- Firestore paths and payloads documented
- loading/error states covered
- tests added
- docs updated
