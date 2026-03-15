# Product Overview

_Last reviewed: March 15, 2026_

BeFam is a mobile-first genealogy and clan operations platform for Vietnamese
families. The product helps clans manage members, relationships, events,
scholarships, notifications, and fund workflows in one secure Firebase-backed
system.

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
- events delivered via dual calendar workspace (solar + lunar, recurrence,
  reminders, regional settings)
- funds workspace and transaction flow baseline
- scholarship workspace and review flow baseline
- notification inbox and deep-link destination placeholders
- profile workspace with user-facing settings entry points
- Firebase Cloud Messaging registration on mobile and server-side push delivery
- annual subscription billing (Free/Base/Plus/Pro) with Card + VNPay checkout
- billing status UI with expiry, payment mode, reminders, history, invoices,
  and audit trail

In progress / partially delivered:

- notification settings persistence and non-placeholder deep-link destinations
  are still being expanded

Planned next modules:

- deeper analytics and destination-specific notification deep-link screens

## Supported platforms and language

- Flutter mobile app in `mobile/befam`
- Android and iOS local development
- default locale: Vietnamese (`vi`)
- secondary locale: English (`en`)

## Source of truth documents

- [AI Build Master Doc](../AI_BUILD_MASTER_DOC.md)
- [AI Agent Tasks 150 Issues](../AI_AGENT_TASKS_150_ISSUES.md)
- [Feature Spec](feature-spec.md)
- [Subscription Billing Epic](epic-tiered-subscription-payments.md)
- [Roadmap](roadmap.md)
