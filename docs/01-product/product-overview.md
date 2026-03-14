# Product Overview

_Last reviewed: March 14, 2026_

BeFam is a mobile-first genealogy and clan operations platform for Vietnamese
families. The product helps clans manage members, relationships, events,
scholarships, and notifications in one secure Firebase-backed system.

## Product goals

- preserve family history and relationships in a usable digital format
- reduce coordination overhead across clan admins, branch admins, and members
- make day-to-day interactions simple for both younger and older users
- keep clan data private, role-scoped, and auditable

## Current implementation status

Delivered in the current app baseline:

- OTP authentication with phone login and child-identifier login
- member claim flow with Firebase session/custom-claim sync
- clan workspace and branch management flows
- member profile workspace with search, filters, and avatar upload
- relationship mutation commands (parent-child and spouse) with permissions
- genealogy read model with zoom/pan tree view, lazy expansion depth controls,
  and human-readable member detail sheet
- Firebase Cloud Messaging registration on mobile and server-side push delivery

In progress / partially delivered:

- events and profile tabs currently use interim workspace placeholders in
  mobile navigation while backend event notifications are already wired
- notification inbox UI is planned, while push delivery plumbing is active

Planned next modules:

- funds and scholarship full UI flows
- richer event management screens and reminder UX
- profile/settings completion

## Supported platforms and language

- Flutter mobile app in `mobile/befam`
- Android and iOS local development
- default locale: Vietnamese (`vi`)
- secondary locale: English (`en`)

## Source of truth documents

- [AI Build Master Doc](../AI_BUILD_MASTER_DOC.md)
- [AI Agent Tasks 150 Issues](../AI_AGENT_TASKS_150_ISSUES.md)
- [Feature Spec](feature-spec.md)
- [Roadmap](roadmap.md)
