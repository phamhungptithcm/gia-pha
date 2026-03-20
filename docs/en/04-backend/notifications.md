# Notifications

_Last reviewed: March 19, 2026_

BeFam notifications are delivered through Firestore + FCM (primary channel),
with optional email fan-out through the Firebase `firestore-send-email`
extension.

## End-to-end flow

1. Authenticated app starts push service in `AppShellPage`.
2. Device token is registered through callable `registerDeviceToken`.
   - token sync runs on first bootstrap and whenever session context changes
     (member/clan/branch/access mode), even if the Firebase UID is unchanged
3. Fallback path writes token directly to `users/{uid}/deviceTokens`.
4. Backend triggers call `notifyMembers(...)`.
5. `notifyMembers` always writes `notifications` inbox docs.
6. Push delivery is routed by user preference + category setting, then sent via
   FCM multicast.
7. Optional email delivery is queued to Firestore `mail` (or configured email
   collection) for extension processing.
8. Invalid FCM tokens are cleaned up from Firestore token docs.

## Channel policy

- Push: default channel (free, primary).
- Email: optional free channel (via Firebase extension + SMTP provider).
- SMS: reserved for OTP authentication only. Non-OTP SMS notifications are
  disabled by default in runtime config.

## Supported targets

Current push target mapping:

- `event`
- `scholarship`
- `billing` (planned)
- `generic` (internal support type)

Mobile deep-link parser maps payload `target` values to:

- `NotificationTargetType.event`
- `NotificationTargetType.scholarship`
- `NotificationTargetType.billing` (planned)
- `NotificationTargetType.unknown`

## Trigger sources currently wired

- event creation (`onEventCreated`)
- scholarship review status changes (`onSubmissionReviewed`)

Planned trigger sources:

- subscription expiry reminders
- manual renewal due reminders
- payment success/failure status updates

## Read/update model

- users read notifications scoped by clan and member access
- members can mark their own notifications as read (`isRead` only)
- creation/deletion is server-controlled

## Preference model

- User preferences are stored at
  `users/{uid}/preferences/notifications`.
- Backend applies:
  - channel toggles (`pushEnabled`, `emailEnabled`)
  - category toggles (`eventReminders`, `scholarshipUpdates`,
    `fundTransactions`, `systemNotices`)
- Inbox document creation remains server-controlled for auditability and
  in-app history.

## Mobile inbox status

- notification inbox screen is available in shell flows
- inbox reads notification docs for active member with pagination
- users can mark their own notifications as read
- deep-link targets are resolved by payload (`event`, `scholarship`, `generic`)
