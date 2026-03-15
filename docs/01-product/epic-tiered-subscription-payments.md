# Tiered Subscription + Payments Epic

_Last reviewed: March 15, 2026_

Source tracking issue: [#213](https://github.com/phamhungptithcm/gia-pha/issues/213)
Implementation status: baseline delivered in `codex/epic-213-tiered-subscription-payments`

## Goal

Implement annual subscription pricing based on family-tree member count using
Free/Base/Plus/Pro plans, with checkout via Card and VNPay, plus subscription
lifecycle, reminders, ad entitlements, and access control.

## Pricing rules (annual, VAT included)

- `<= 10` members: Free
- `11 - 200`: Base, 49,000 VND/year
- `201 - 700`: Plus, 89,000 VND/year
- `701+`: Pro, 119,000 VND/year

## Ads entitlement policy

- Free and Base plans show ads
- Plus and Pro plans are ad-free
- ads are blocked on sensitive flows (auth, checkout, payment result, and
  privacy/consent surfaces)

## Scope

- pricing engine by `member_count`
- subscription status UI (plan, expiry date, payment mode, ad entitlement)
- checkout integration: card and VNPay
- payment callback/webhook validation and processing
- activation, renewal, expiry, and access gating
- auto-renew and manual-renew setup
- reminder delivery before expiry and renewal due date
- ad entitlement resolution and placement gating by plan
- payment history, invoice basics, and billing audit logs

## Subscription visibility

Clan owner/admin users can always view:

- current subscription status
- expiry date
- auto-renew/manual mode
- next payment due information (if applicable)

## Acceptance summary

1. Correct tier mapping with non-overlapping boundaries.
2. VAT included in displayed and charged amount.
3. Successful purchase via card and VNPay.
4. Immediate activation/extension after successful payment.
5. Expiry date visible to clan owner/admin users.
6. User-controlled auto-renew/manual-renew mode.
7. Reminder notifications before expiry/renewal due date.
8. Correct failed/expired handling in UI and permissions.
9. Secure VNPay callback signature verification.
10. Complete transaction metadata with gateway references.
11. Free/Base users see configured ads; Plus/Pro users do not.
12. No ads are shown in auth, checkout, payment-result, and privacy flows.

## Child stories

- BILL-001: Member-count pricing engine
- BILL-002: Subscription model and lifecycle states
- BILL-003: Subscription screen UI
- BILL-004: Card checkout integration
- BILL-005: VNPay checkout integration
- BILL-006: Callback/webhook validation and processing
- BILL-007: Auto-renew/manual-renew preference management
- BILL-008: Renewal/expiry reminder scheduler + notifications
- BILL-009: Feature + ad gating by subscription state
- BILL-010: Payment history and invoice basics
- BILL-011: Billing audit logs and traceability
- BILL-012: Billing test suite
