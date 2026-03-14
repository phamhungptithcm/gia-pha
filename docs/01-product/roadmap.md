# Roadmap

_Last reviewed: March 14, 2026_

## Delivery model

- `staging` is the integration branch for active development
- `main` is the protected production branch
- weekly automation proposes promotion PRs from `staging` to `main`

## Milestones

### M1: Foundation and production pipeline (completed)

- Flutter app scaffold renamed to `mobile/befam`
- Firebase bootstrap and project wiring to `be-fam-3ab23`
- CI checks across docs/functions/mobile
- release automation for semver tags, release notes, Android APK, iOS unsigned
  archive, and GHCR images

### M2: Core identity and family workspace (completed)

- phone + child OTP authentication
- claim-member-record and auth UID linking
- clan and member workspace delivery
- relationship commands and genealogy workspace with interactive tree

### M3: Production hardening and usability (active)

- large-text and overflow resilience
- simpler Vietnamese-first copy and clearer sectioning for forms
- searchable people pickers and human-readable profile/genealogy surfaces
- real Firebase connectivity replacing local-only mock assumptions

### M4: Events, notifications inbox, and engagement (next)

- event list/detail/create/edit screens
- reminder UX and notification inbox with read-state management
- deep-link completion from push notifications to destination screens

### M5: Funds and scholarship programs (planned)

- fund and transaction management
- scholarship program and review workflows
- stronger test coverage for financial and scholarship domain rules

### M6: Dual calendar and lunar events (planned)

- dual solar + lunar calendar rendering in month/day views
- lunar event creation with yearly recurrence resolution
- lunar holidays, regional calendar settings, and reminder scheduling

## Planning references

- [AI Build Master Doc](../AI_BUILD_MASTER_DOC.md)
- [AI Agent Tasks 150 Issues](../AI_AGENT_TASKS_150_ISSUES.md)
- [Dual Calendar Epic](./epic-dual-calendar-system.md)
- [GitHub Workflow](../05-devops/github-workflow.md)
