# Pre-Release QA Checklist

_Last reviewed: March 17, 2026_

## Build and Environment

- [ ] release candidate is up to date
- [ ] production vars/secrets are verified
- [ ] `flutter analyze` passes
- [ ] `flutter test` passes
- [ ] Functions tests/build pass
- [ ] required CI checks are green

## Core Journeys

- [ ] phone OTP login works end-to-end
- [ ] clan/member/relationship/genealogy flows are stable
- [ ] dual calendar event flows work (solar + lunar)
- [ ] fund and transaction workflows produce expected balances
- [ ] scholarship submission/review flow works
- [ ] profile edit and avatar update work

## Billing Validation

- [ ] active plan card reflects truly active entitlement only
- [ ] upgrade/renew constraints are correct
- [ ] VNPay 3-step flow is understandable
- [ ] payment outcome states are clear
- [ ] pending/failed payments do not activate upgraded plan

## Release Sign-Off

- [ ] QA sign-off
- [ ] engineering sign-off
- [ ] product sign-off
