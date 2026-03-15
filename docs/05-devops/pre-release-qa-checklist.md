# Pre-Release QA Checklist

_Last reviewed: March 15, 2026_

Use this checklist for every release candidate before merge/promotion to `main`.

## Build and environment

- [ ] latest `staging` branch is pulled and release candidate commit is tagged
- [ ] Firebase project/environment values are correct for production release flow
- [ ] `flutter analyze` passes locally
- [ ] `flutter test` passes locally
- [ ] CI checks `ci-docs`, `ci-functions`, and `ci-mobile` are green

## Core user journeys

- [ ] authentication via phone flow works end-to-end
- [ ] home shortcuts navigate correctly
- [ ] clan, member, relationship, genealogy flows load and update as expected
- [ ] dual calendar create/edit/delete flows work for solar and lunar events
- [ ] notifications inbox and deep links open target content correctly
- [ ] profile edit and avatar upload work for allowed roles

## Accessibility pass (REL-RELEASE-001)

- [ ] all icon-only actions have a tooltip or accessible label
- [ ] loading states announce meaningful status text
- [ ] dynamic content areas are readable with large text scaling
- [ ] focus order is logical for major forms and dialogs
- [ ] color contrast is acceptable for key actions, chips, and status cards

## Empty/loading/error state audit (REL-RELEASE-002)

- [ ] each workspace has a non-blank loading state with user-facing message
- [ ] no-context states provide clear guidance instead of raw errors
- [ ] empty list states explain what to do next
- [ ] error states include retry path where recovery is possible
- [ ] fallback error UI renders when a widget tree crash occurs

## Performance and reliability

- [ ] cold start is acceptable on a low-end Android test device
- [ ] scrolling remains smooth in calendar/month grid and genealogy views
- [ ] no repeated severe `perf.*` warnings in debug verification runs
- [ ] Crashlytics and log signals are visible for injected failure scenarios

## Release documentation and assets

- [ ] [Store Assets Checklist](store-assets-checklist.md) is completed
- [ ] release notes include delivered stories and known limitations
- [ ] support/privacy links in docs and store listing are valid

## Sign-off

- [ ] QA sign-off recorded in release PR
- [ ] engineering sign-off recorded in release PR
- [ ] product sign-off recorded in release PR
