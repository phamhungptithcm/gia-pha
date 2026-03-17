# Tiered Subscription and Payments Epic

_Last reviewed: March 17, 2026_

Source issue: [#213](https://github.com/phamhungptithcm/gia-pha/issues/213)

## Goal

Deliver a reliable annual subscription system based on clan member count with
clear entitlement behavior and secure payment confirmation.

## Pricing (Annual, VAT included)

- `<= 10` members: Free
- `11 - 200`: Base, 49,000 VND/year
- `201 - 700`: Plus, 89,000 VND/year
- `701+`: Pro, 119,000 VND/year

## Scope

- tiered pricing engine and validation
- subscription status and lifecycle handling
- VNPay-first checkout flow for user-facing payment journey
- webhook/callback validation and idempotent processing
- reminders, history, and audit traces

## Current Product Behavior

- backend creates checkout order before app opens payment URL
- plan activates only after confirmed successful payment
- pending or failed/canceled payment does not grant upgraded plan
- user-facing payment states are explicit and actionable

## Story Map

- BILL-001 pricing engine
- BILL-002 lifecycle model
- BILL-003 billing workspace UI
- BILL-004 VNPay checkout integration
- BILL-005 webhook/callback validation
- BILL-006 renewal preferences
- BILL-007 reminder scheduler
- BILL-008 entitlement gating
- BILL-009 payment history and invoices
- BILL-010 audit logs
- BILL-011 test coverage
