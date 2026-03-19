# State Management

_Last reviewed: March 14, 2026_

## Current approach

The app currently uses controller-driven `ChangeNotifier` state management with
feature repositories.

## Pattern in practice

- controller class owns async actions, state flags, and error surface
- repository interface abstracts Firebase runtime integration
- UI pages bind via `AnimatedBuilder` and do not mutate backend directly

## Examples

- `AuthController`: auth step machine, OTP flow, session restore/logout
- `MemberController`: list/search/filter, save/edit, avatar upload
- `ClanController`: clan and branch workspace loading + persistence

## Search and derived state

- member filtering uses `MemberSearchProvider`
- search analytics hooks run through `MemberSearchAnalyticsService`
- controller revisions prevent stale async search results from overriding newer
  state

## Caching and session persistence

- auth session is persisted with `AuthSessionStore` (shared preferences)
- genealogy read segments can be cached locally via
  `GenealogySegmentCache.shared()`
- Firebase session context is synced into `users/{uid}` docs for rule fallback

## Runtime backend behavior

- runtime app flows use Firebase services by default
- test-only fixtures/mocks are kept inside test layers
