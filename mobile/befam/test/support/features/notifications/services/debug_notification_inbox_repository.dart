import 'package:befam/features/auth/models/auth_session.dart';
import 'package:befam/features/notifications/models/notification_inbox_item.dart';
import 'package:befam/features/notifications/services/notification_inbox_repository.dart';

class DebugNotificationInboxRepository implements NotificationInboxRepository {
  DebugNotificationInboxRepository({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  final Map<String, List<NotificationInboxItem>> _samplesByMember = {};

  @override
  bool get isSandbox => true;

  @override
  Future<NotificationInboxPageResult> loadInboxPage({
    required AuthSession session,
    int limit = 20,
    NotificationInboxCursor? cursor,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 140));

    final memberId = session.memberId?.trim() ?? '';
    final clanId = session.clanId?.trim() ?? '';
    if (memberId.isEmpty || clanId.isEmpty) {
      return const NotificationInboxPageResult(items: [], nextCursor: null);
    }

    final sampleKey = '$clanId::$memberId';
    final samples = _samplesByMember.putIfAbsent(
      sampleKey,
      () => _buildSampleItems(memberId: memberId, clanId: clanId),
    );

    final sorted = samples.toList()..sort(_compareInboxItemDesc);
    final filtered = cursor == null
        ? sorted
        : sorted.where((item) => _isItemAfterCursor(item, cursor));

    final pageSize = limit.clamp(1, 100);
    final pageItems = filtered.take(pageSize + 1).toList(growable: false);
    final hasMore = pageItems.length > pageSize;
    final visibleItems = hasMore
        ? pageItems.take(pageSize).toList(growable: false)
        : pageItems;
    final nextCursor = hasMore
        ? NotificationInboxCursor(
            createdAt: visibleItems.last.createdAt,
            documentId: visibleItems.last.id,
          )
        : null;

    return NotificationInboxPageResult(
      items: visibleItems,
      nextCursor: nextCursor,
    );
  }

  int _compareInboxItemDesc(
    NotificationInboxItem left,
    NotificationInboxItem right,
  ) {
    final byTime = right.createdAt.compareTo(left.createdAt);
    if (byTime != 0) {
      return byTime;
    }
    return right.id.compareTo(left.id);
  }

  bool _isItemAfterCursor(
    NotificationInboxItem item,
    NotificationInboxCursor cursor,
  ) {
    final cursorTime = cursor.createdAt;
    if (item.createdAt.isBefore(cursorTime)) {
      return true;
    }
    if (item.createdAt.isAfter(cursorTime)) {
      return false;
    }
    return item.id.compareTo(cursor.documentId) < 0;
  }

  @override
  Future<void> markAsRead({
    required AuthSession session,
    required String notificationId,
  }) async {
    final memberId = session.memberId?.trim() ?? '';
    final clanId = session.clanId?.trim() ?? '';
    final normalizedId = notificationId.trim();
    if (memberId.isEmpty || clanId.isEmpty || normalizedId.isEmpty) {
      return;
    }

    final sampleKey = '$clanId::$memberId';
    final samples = _samplesByMember[sampleKey];
    if (samples == null) {
      return;
    }

    final index = samples.indexWhere((item) => item.id == normalizedId);
    if (index < 0 || samples[index].isRead) {
      return;
    }

    samples[index] = samples[index].copyWith(isRead: true);
  }

  List<NotificationInboxItem> _buildSampleItems({
    required String memberId,
    required String clanId,
  }) {
    final now = _clock();
    return [
      NotificationInboxItem(
        id: 'notif_demo_event_001',
        memberId: memberId,
        clanId: clanId,
        type: 'event_created',
        title: 'Đã thêm lịch lễ tưởng niệm',
        body: 'Sự kiện lễ giỗ của chi đã được lên lịch vào Chủ nhật tới.',
        isRead: false,
        createdAt: now.subtract(const Duration(minutes: 18)),
        target: NotificationInboxTarget.event,
        targetId: 'event_demo_memorial_001',
        data: const {'target': 'event', 'id': 'event_demo_memorial_001'},
      ),
      NotificationInboxItem(
        id: 'notif_demo_scholarship_001',
        memberId: memberId,
        clanId: clanId,
        type: 'scholarship_reviewed',
        title: 'Hồ sơ học bổng đã được duyệt',
        body: 'Một hồ sơ học bổng vừa được cập nhật kết quả xét duyệt.',
        isRead: false,
        createdAt: now.subtract(const Duration(hours: 3, minutes: 12)),
        target: NotificationInboxTarget.scholarship,
        targetId: 'sub_demo_001',
        data: const {
          'target': 'scholarship',
          'id': 'sub_demo_001',
          'submissionId': 'sub_demo_001',
        },
      ),
      NotificationInboxItem(
        id: 'notif_demo_generic_001',
        memberId: memberId,
        clanId: clanId,
        type: 'generic',
        title: 'Đồng bộ hồ sơ gia đình hoàn tất',
        body: 'Các thay đổi hồ sơ mới nhất của bạn đã hiển thị trong gia phả.',
        isRead: true,
        createdAt: now.subtract(const Duration(hours: 8)),
        target: NotificationInboxTarget.generic,
        targetId: null,
        data: const {'target': 'generic'},
      ),
      NotificationInboxItem(
        id: 'notif_demo_event_002',
        memberId: memberId,
        clanId: clanId,
        type: 'event_reminder',
        title: 'Nhắc sự kiện đã sẵn sàng',
        body: 'Thông báo nhắc sự kiện gia đình sẽ được gửi vào tối nay.',
        isRead: false,
        createdAt: now.subtract(const Duration(hours: 20)),
        target: NotificationInboxTarget.event,
        targetId: 'event_demo_gathering_001',
        data: const {'target': 'event', 'id': 'event_demo_gathering_001'},
      ),
      NotificationInboxItem(
        id: 'notif_demo_scholarship_002',
        memberId: memberId,
        clanId: clanId,
        type: 'scholarship_reviewed',
        title: 'Đã có ghi chú phản hồi học bổng',
        body: 'Hồ sơ học bổng hiện đã có ghi chú từ hội đồng xét duyệt.',
        isRead: true,
        createdAt: now.subtract(const Duration(days: 1, hours: 3)),
        target: NotificationInboxTarget.scholarship,
        targetId: 'sub_demo_002',
        data: const {
          'target': 'scholarship',
          'id': 'sub_demo_002',
          'submissionId': 'sub_demo_002',
        },
      ),
      NotificationInboxItem(
        id: 'notif_demo_generic_002',
        memberId: memberId,
        clanId: clanId,
        type: 'generic',
        title: 'Thông tin chi đã được cập nhật',
        body:
            'Một thông tin của chi đã thay đổi và được đồng bộ cho mọi người.',
        isRead: true,
        createdAt: now.subtract(const Duration(days: 2, hours: 1)),
        target: NotificationInboxTarget.generic,
        targetId: null,
        data: const {'target': 'generic'},
      ),
      NotificationInboxItem(
        id: 'notif_demo_event_003',
        memberId: memberId,
        clanId: clanId,
        type: 'event_created',
        title: 'Lịch lễ tưởng niệm đã cập nhật',
        body:
            'Buổi họp mặt tưởng niệm hằng tháng đã có ngày mới được xác nhận.',
        isRead: false,
        createdAt: now.subtract(const Duration(days: 2, hours: 6)),
        target: NotificationInboxTarget.event,
        targetId: 'event_demo_gathering_001',
        data: const {'target': 'event', 'id': 'event_demo_gathering_001'},
      ),
    ];
  }
}
