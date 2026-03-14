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

## Canonical backlog reference

For full epic/story coverage and acceptance mapping, use:

- [AI Agent Tasks 150 Issues](../AI_AGENT_TASKS_150_ISSUES.md)
- [GitHub Backlog Process](../05-devops/github-backlog.md)
