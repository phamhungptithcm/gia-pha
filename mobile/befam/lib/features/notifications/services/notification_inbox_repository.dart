import '../../auth/models/auth_session.dart';
import '../models/notification_inbox_item.dart';
import 'firebase_notification_inbox_repository.dart';

class NotificationInboxCursor {
  const NotificationInboxCursor({
    required this.createdAt,
    required this.documentId,
  });

  final DateTime createdAt;
  final String documentId;
}

class NotificationInboxPageResult {
  const NotificationInboxPageResult({
    required this.items,
    required this.nextCursor,
  });

  final List<NotificationInboxItem> items;
  final NotificationInboxCursor? nextCursor;

  bool get hasMore => nextCursor != null;
}

abstract interface class NotificationInboxRepository {
  bool get isSandbox;

  Future<NotificationInboxPageResult> loadInboxPage({
    required AuthSession session,
    int limit = 20,
    NotificationInboxCursor? cursor,
  });

  Future<void> markAsRead({
    required AuthSession session,
    required String notificationId,
  });
}

NotificationInboxRepository createDefaultNotificationInboxRepository({
  AuthSession? session,
}) {
  return FirebaseNotificationInboxRepository();
}
