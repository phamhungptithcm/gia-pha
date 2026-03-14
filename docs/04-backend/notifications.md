# Notifications

_Last reviewed: March 14, 2026_

BeFam notifications are delivered through Firestore + FCM with a mobile service
that supports both foreground and system-opened deep links.

## End-to-end flow

1. Authenticated app starts push service in `AppShellPage`.
2. Device token is registered through callable `registerDeviceToken`.
3. Fallback path writes token directly to `users/{uid}/deviceTokens`.
4. Backend triggers call `notifyMembers(...)`.
5. `notifyMembers` writes `notifications` docs and sends FCM multicast.
6. Invalid FCM tokens are cleaned up from Firestore token docs.

## Supported targets

Current push target mapping:

- `event`
- `scholarship`
- `generic` (internal support type)

Mobile deep-link parser maps payload `target` values to:

- `NotificationTargetType.event`
- `NotificationTargetType.scholarship`
- `NotificationTargetType.unknown`

## Trigger sources currently wired

- event creation (`onEventCreated`)
- scholarship review status changes (`onSubmissionReviewed`)

## Read/update model

- users read notifications scoped by clan and member access
- members can mark their own notifications as read (`isRead` only)
- creation/deletion is server-controlled

## Mobile inbox status

- notification inbox screen is available in the shell Events destination
- inbox currently reads most recent notification documents for the active member
- unread/read state is rendered in UI but write-back actions are tracked as a
  follow-up story

## Next delivery step

- add mark-as-read interaction
- complete deep-link destination navigation for event and scholarship targets
- add inbox pagination support
