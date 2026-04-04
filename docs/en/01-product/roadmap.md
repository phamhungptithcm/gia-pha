# Roadmap

_Last reviewed: April 2, 2026_

## Delivery Model

- `staging`: integration branch for active implementation
- `main`: protected production branch
- push-driven release-promotion PR from `staging` to `main`

## Milestones

### M1 - Foundation and release pipeline (Completed)
- Flutter + Firebase bootstrap
- docs pipeline and quality checks
- branch CI and release automation baseline

### M2 - Identity and clan core (Completed)
- phone OTP + child-access login
- member claim and session linking
- clan/member/relationship/genealogy baseline

### M3 - Events and engagement baseline (Completed)
- dual calendar (solar + lunar)
- event create/edit/delete and reminders
- notification inbox baseline

### M4 - Funds and scholarship baseline (Completed)
- fund profiles and transaction workflows
- running balance and validation baseline
- scholarship submissions and review baseline

### M5 - Billing and subscription lifecycle (Completed baseline)
- tiered plans
- VNPay-first checkout flow
- payment state handling and reminder logic

### M6 - Profile and settings baseline (Completed)
- profile screen and edit flow
- settings shell and placeholders
- logout confirmation and profile image test coverage

### M7 - UX hardening and release quality (Active)
- copy refinement for clarity
- reduction of payment/onboarding ambiguity
- accessibility and large-text resilience

### M8 - Scale and operations excellence (Planned)
- deeper analytics and monitoring visibility
- richer destination-specific notification navigation
- large-clan performance and scalability optimization
