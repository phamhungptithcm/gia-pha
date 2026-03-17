# Feature Spec

_Last reviewed: March 17, 2026_

## Feature Status Matrix

| Area | Status | Current behavior |
| --- | --- | --- |
| Auth (phone OTP) | Live | Firebase phone auth with session restore and claim flow |
| Auth (child access) | Live | Child identifier + parent phone verification path |
| Member claim and role context | Live | Session claims sync to Firestore user context |
| Clan workspace | Live | Clan and branch create/update with role checks |
| Member workspace | Live | Member CRUD, search/filter, avatar upload |
| Relationship management | Live | Parent-child and spouse mutation with guardrails |
| Genealogy read workspace | Live | Tree read model and contextual detail |
| Dual calendar events | Live | Solar/lunar scheduling and reminders |
| Funds workspace | Live | Fund list/detail/create + donation/expense + running balance |
| Scholarship workspace | Live | Program, award levels, submissions, review baseline |
| Discovery + join request | Live | Public search + structured request submission |
| Profile and settings | Live (baseline) | Profile shell, edit profile, notification preference placeholders, logout confirmation |
| Notification inbox | Live (baseline) | Inbox list/read-state and destination placeholders |
| Billing plans | Live | Tier model by member count with entitlement rules |
| Billing checkout UX | Live | VNPay-first 3-step flow (Select -> Confirm -> Pay) |
| Billing payment states | Live | Success / Pending settlement / Failed or canceled |
| Billing activation policy | Live | New plan activates only after confirmed successful payment |

## Billing Rules (Current)

### User-facing behavior
- If the current plan is still valid, users can upgrade to a higher tier.
- Renewal of the same tier is offered only near expiry.
- Downgrade is blocked if current member count exceeds target tier limits.

### System guarantees
- Checkout order is created on backend before opening payment URL.
- Pending or failed payments do not activate upgraded entitlement.
- The active plan card reflects only truly active entitlement.

### Payment channels
- Mobile UX is VNPay-first for checkout.
- Card callback compatibility remains in backend processing paths.
