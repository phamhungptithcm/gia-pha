import '../../auth/models/auth_session.dart';
import '../models/notification_inbox_item.dart';
import 'notification_inbox_repository.dart';

class DebugNotificationInboxRepository implements NotificationInboxRepository {
  @override
  bool get isSandbox => true;

  @override
  Future<List<NotificationInboxItem>> loadInbox({
    required AuthSession session,
    int limit = 25,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 140));

    final memberId = session.memberId?.trim() ?? '';
    final clanId = session.clanId?.trim() ?? '';
    if (memberId.isEmpty || clanId.isEmpty) {
      return const [];
    }

    final now = DateTime.now();
    final samples = [
      NotificationInboxItem(
        id: 'notif_demo_event_001',
        memberId: memberId,
        clanId: clanId,
        type: 'event_created',
        title: 'Ancestor remembrance ceremony added',
        body: 'The branch memorial event is scheduled for next Sunday.',
        isRead: false,
        createdAt: now.subtract(const Duration(minutes: 18)),
        target: NotificationInboxTarget.event,
        targetId: 'event_demo_001',
        data: const {'target': 'event', 'id': 'event_demo_001'},
      ),
      NotificationInboxItem(
        id: 'notif_demo_scholarship_001',
        memberId: memberId,
        clanId: clanId,
        type: 'scholarship_reviewed',
        title: 'Scholarship application reviewed',
        body: 'A scholarship submission now has a decision update.',
        isRead: false,
        createdAt: now.subtract(const Duration(hours: 3, minutes: 12)),
        target: NotificationInboxTarget.scholarship,
        targetId: 'submission_demo_001',
        data: const {'target': 'scholarship', 'id': 'submission_demo_001'},
      ),
      NotificationInboxItem(
        id: 'notif_demo_generic_001',
        memberId: memberId,
        clanId: clanId,
        type: 'generic',
        title: 'Family profile sync completed',
        body: 'Your latest profile changes are now visible to your clan.',
        isRead: true,
        createdAt: now.subtract(const Duration(days: 1, hours: 2)),
        target: NotificationInboxTarget.generic,
        targetId: null,
        data: const {'target': 'generic'},
      ),
    ];

    final effectiveLimit = limit.clamp(1, 100);
    return samples.take(effectiveLimit).toList(growable: false);
  }
}
