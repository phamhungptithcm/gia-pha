# User Stories

_Last reviewed: March 14, 2026_

This page summarizes the highest-priority user stories already reflected in the
codebase and release workflow.

## Authentication and onboarding

- As a parent, I can sign in with my phone number and verify by OTP so I can
  access my family workspace.
- As a child user, I can sign in using a child identifier and parent OTP flow.
- As a pre-created member, I can claim my existing member profile to link my
  Firebase account safely.

## Clan and member management

- As a clan admin, I can create and update clan and branch records.
- As a branch admin, I can create members in my branch and manage profiles
  without editing other branches.
- As a member, I can update my own profile and upload an avatar.
- As a user, I can search, filter, and open member details quickly.

## Relationship and genealogy

- As an admin, I can create parent-child and spouse relationships with
  server-side validation.
- As a user, I can view an interactive genealogy tree, zoom/pan, and inspect
  member details in context.

## Notifications and release quality

- As a signed-in user, my device FCM token is registered for push delivery.
- As a member, I receive notification payloads for event and scholarship
  updates when server triggers run.
- As a maintainer, I can rely on CI checks and release automation to publish a
  production release from `main`.

## Billing and subscription (planned epic)

- As a clan owner/admin, I can see my current subscription, expiry date, and
  payment mode in one place.
- As a clan owner/admin, I can purchase an annual subscription with card or
  VNPay based on member-count pricing tiers.
- As a clan owner/admin, I can choose auto-renew or manual renewal.
- As a clan owner/admin, I receive renewal reminders before expiration.
- As a clan owner/admin, I can review payment history and references for audit
  and support.
- As a system, I validate callback signatures and reject tampered payment
  callbacks.

## Canonical backlog reference

For full epic/story coverage and acceptance mapping, use:

- [AI Agent Tasks 150 Issues](../AI_AGENT_TASKS_150_ISSUES.md)
- [GitHub Backlog Process](../05-devops/github-backlog.md)
- [Subscription Billing Epic](./epic-tiered-subscription-payments.md)
