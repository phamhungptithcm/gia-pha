# Tiered Subscription + Payments Epic

_Last reviewed: March 14, 2026_

Source tracking issue: [#213](https://github.com/phamhungptithcm/gia-pha/issues/213)

## Goal

Implement annual subscription pricing based on family-tree member count, with
checkout via Card and VNPay, including subscription lifecycle, reminders, and
access control.

## Pricing rules (annual, VAT included)

- `< 30` members: free
- `30 - 200`: 29,000 VND/year
- `201 - 400`: 59,000 VND/year
- `401 - 700`: 79,000 VND/year
- `701 - 1200`: 89,000 VND/year
- `1201 - 2000`: 119,000 VND/year
- `2001+`: 199,000 VND/year

## Scope

- pricing engine by `member_count`
- subscription status UI (plan, expiry date, payment mode)
- checkout integration: card and VNPay
- payment callback/webhook validation and processing
- activation, renewal, expiry, and access gating
- auto-renew and manual-renew setup
- reminder delivery before expiry and renewal due date
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

## Child stories

- BILL-001: Member-count pricing engine
- BILL-002: Subscription model and lifecycle states
- BILL-003: Subscription screen UI
- BILL-004: Card checkout integration
- BILL-005: VNPay checkout integration
- BILL-006: Callback/webhook validation and processing
- BILL-007: Auto-renew/manual-renew preference management
- BILL-008: Renewal/expiry reminder scheduler + notifications
- BILL-009: Feature gating by subscription state
- BILL-010: Payment history and invoice basics
- BILL-011: Billing audit logs and traceability
- BILL-012: Billing test suite
