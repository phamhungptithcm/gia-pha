import '../../../core/services/runtime_mode.dart';
import '../../auth/models/auth_session.dart';
import '../models/notification_inbox_item.dart';
import 'debug_notification_inbox_repository.dart';
import 'firebase_notification_inbox_repository.dart';

abstract interface class NotificationInboxRepository {
  bool get isSandbox;

  Future<List<NotificationInboxItem>> loadInbox({
    required AuthSession session,
    int limit = 25,
  });
}

NotificationInboxRepository createDefaultNotificationInboxRepository() {
  if (RuntimeMode.shouldUseMockBackend) {
    return DebugNotificationInboxRepository();
  }

  return FirebaseNotificationInboxRepository();
}
