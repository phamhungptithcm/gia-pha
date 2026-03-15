# Family Clan App Documentation

Family Clan App (BeFam) is a mobile-first genealogy and clan operations
platform. This site is the working source of truth for product planning,
architecture, delivery, and implementation decisions across the repository.

## Start here

- Review the AI Build Master Doc for product baseline and long-range scope.
- Use the Product, Architecture, Mobile, and Backend sections for current
  implementation behavior.
- Track delivery through GitHub workflow, branching strategy, and CI/CD docs.
- Use the master docs section for deep planning references.

## Documentation tracks

- Product: vision, personas, stories, and roadmap
- Architecture: mobile, Firebase, and data model decisions
- Mobile: Flutter structure, navigation, state, and local development
- DevOps: branching, CI/CD, backlog workflow, and release automation
- Security and operations: privacy, monitoring, analytics, and rules

## Current bootstrap status

- Flutter app lives in `mobile/befam` with Vietnamese default localization
- Firebase configuration is connected to `be-fam-3ab23`
- production delivery uses protected `staging` (development) and `main`
  (release) branches
- Events now use a dual solar + lunar calendar workspace
- Funds, scholarship, notifications inbox, and profile workspace are integrated
  in the current app baseline
- new billing planning epic is tracked in GitHub issue
  [#213](https://github.com/phamhungptithcm/gia-pha/issues/213)
- release automation creates semver tags, friendly notes, Android APK, unsigned
  iOS archive, and GHCR images
- GitHub Pages publishes this documentation from `main`
