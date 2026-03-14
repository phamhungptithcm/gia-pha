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
- inbox reads notification documents for the active member with incremental
  pagination
- users can mark their notifications as read from inbox actions
- event and scholarship notifications open dedicated mobile deep-link
  destination placeholders
- notification settings toggles are available as profile-level placeholders

## Next delivery step

- replace target placeholder pages with full event and scholarship detail
  destinations
- persist notification preference toggles to backend user settings
