import 'package:befam/features/auth/models/auth_entry_method.dart';
import 'package:befam/features/auth/models/auth_member_access_mode.dart';
import 'package:befam/features/auth/models/auth_session.dart';
import 'package:befam/features/notifications/models/notification_inbox_item.dart';
import 'package:befam/features/notifications/presentation/notification_inbox_page.dart';
import 'package:befam/features/notifications/services/notification_inbox_repository.dart';
import 'package:befam/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  AuthSession buildSession({
    String? memberId = 'member_demo_parent_001',
    String? clanId = 'clan_demo_001',
  }) {
    return AuthSession(
      uid: 'debug:+84901234567',
      loginMethod: AuthEntryMethod.phone,
      phoneE164: '+84901234567',
      displayName: 'Nguyễn Minh',
      memberId: memberId,
      clanId: clanId,
      branchId: 'branch_demo_001',
      primaryRole: 'CLAN_ADMIN',
      accessMode: AuthMemberAccessMode.claimed,
      linkedAuthUid: true,
      isSandbox: true,
      signedInAtIso: DateTime(2026, 3, 14).toIso8601String(),
    );
  }

  NotificationInboxItem buildItem({
    required String id,
    required DateTime createdAt,
    required bool isRead,
    NotificationInboxTarget target = NotificationInboxTarget.generic,
    String? targetId,
  }) {
    return NotificationInboxItem(
      id: id,
      memberId: 'member_demo_parent_001',
      clanId: 'clan_demo_001',
      type: target == NotificationInboxTarget.event
          ? 'event_created'
          : target == NotificationInboxTarget.scholarship
          ? 'scholarship_reviewed'
          : 'generic',
      title: 'Title $id',
      body: 'Body $id',
      isRead: isRead,
      createdAt: createdAt,
      target: target,
      targetId: targetId,
      data: targetId == null
          ? const {'target': 'generic'}
          : {
              'target': target == NotificationInboxTarget.event
                  ? 'event'
                  : 'scholarship',
              'id': targetId,
            },
    );
  }

  testWidgets('renders first page and loads more notifications', (
    tester,
  ) async {
    final now = DateTime(2026, 3, 14, 12);
    final repository = _FakeNotificationInboxRepository(
      items: [
        buildItem(id: 'notif_001', createdAt: now, isRead: false),
        buildItem(
          id: 'notif_002',
          createdAt: now.subtract(const Duration(minutes: 2)),
          isRead: true,
        ),
        buildItem(
          id: 'notif_003',
          createdAt: now.subtract(const Duration(minutes: 4)),
          isRead: false,
        ),
        buildItem(
          id: 'notif_004',
          createdAt: now.subtract(const Duration(minutes: 6)),
          isRead: true,
        ),
        buildItem(
          id: 'notif_005',
          createdAt: now.subtract(const Duration(minutes: 8)),
          isRead: true,
        ),
        buildItem(
          id: 'notif_006',
          createdAt: now.subtract(const Duration(minutes: 10)),
          isRead: true,
        ),
      ],
    );

    await tester.pumpWidget(
      _TestApp(
        child: NotificationInboxPage(
          session: buildSession(),
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('notification-row-notif_001')), findsOneWidget);
    expect(find.byKey(const Key('notification-row-notif_004')), findsOneWidget);
    expect(find.byKey(const Key('notification-row-notif_005')), findsNothing);

    final loadMoreButton = find.byKey(const Key('notification-load-more'));
    await tester.ensureVisible(loadMoreButton);
    await tester.pumpAndSettle();
    await tester.tap(loadMoreButton);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('notification-row-notif_005')), findsOneWidget);
    expect(find.byKey(const Key('notification-row-notif_006')), findsOneWidget);
    expect(find.text('No more notifications.'), findsOneWidget);
  });

  testWidgets('marks an unread notification as read', (tester) async {
    final repository = _FakeNotificationInboxRepository(
      items: [
        buildItem(
          id: 'notif_001',
          createdAt: DateTime(2026, 3, 14, 12),
          isRead: false,
        ),
      ],
    );

    await tester.pumpWidget(
      _TestApp(
        child: NotificationInboxPage(
          session: buildSession(),
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('notification-mark-read-notif_001')));
    await tester.pumpAndSettle();

    expect(repository.markedReadIds, contains('notif_001'));
    expect(
      find.byKey(const Key('notification-mark-read-notif_001')),
      findsNothing,
    );
    expect(find.text('All caught up'), findsOneWidget);
  });

  testWidgets('opens deep-link target and marks unread item as read', (
    tester,
  ) async {
    final repository = _FakeNotificationInboxRepository(
      items: [
        buildItem(
          id: 'notif_event_001',
          createdAt: DateTime(2026, 3, 14, 12),
          isRead: false,
          target: NotificationInboxTarget.event,
          targetId: 'event_demo_001',
        ),
      ],
    );
    final openedIds = <String>[];

    await tester.pumpWidget(
      _TestApp(
        child: NotificationInboxPage(
          session: buildSession(),
          repository: repository,
          onOpenTarget: (item) {
            openedIds.add(item.id);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const Key('notification-open-notif_event_001')),
    );
    await tester.pumpAndSettle();

    expect(openedIds, ['notif_event_001']);
    expect(repository.markedReadIds, contains('notif_event_001'));
  });

  testWidgets('shows no-context state when member context is missing', (
    tester,
  ) async {
    final repository = _FakeNotificationInboxRepository(items: const []);

    await tester.pumpWidget(
      _TestApp(
        child: NotificationInboxPage(
          session: buildSession(memberId: null, clanId: null),
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Notification inbox unavailable'), findsOneWidget);
    expect(find.text('No notifications yet'), findsNothing);
  });
}

class _FakeNotificationInboxRepository implements NotificationInboxRepository {
  _FakeNotificationInboxRepository({required List<NotificationInboxItem> items})
    : _items = items.toList(growable: true);

  final List<NotificationInboxItem> _items;
  final List<String> markedReadIds = <String>[];

  @override
  bool get isSandbox => true;

  @override
  Future<NotificationInboxPageResult> loadInboxPage({
    required AuthSession session,
    int limit = 20,
    NotificationInboxCursor? cursor,
  }) async {
    final sorted = _items.toList(growable: false)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final cursorTime = cursor?.createdAt;

    final filtered = cursorTime == null
        ? sorted
        : sorted.where((item) => item.createdAt.isBefore(cursorTime));
    final pageItems = filtered.take(limit + 1).toList(growable: false);
    final hasMore = pageItems.length > limit;
    final visibleItems = hasMore
        ? pageItems.take(limit).toList(growable: false)
        : pageItems;

    return NotificationInboxPageResult(
      items: visibleItems,
      nextCursor: hasMore
          ? NotificationInboxCursor(createdAt: visibleItems.last.createdAt)
          : null,
    );
  }

  @override
  Future<void> markAsRead({
    required AuthSession session,
    required String notificationId,
  }) async {
    markedReadIds.add(notificationId);
    final index = _items.indexWhere((item) => item.id == notificationId);
    if (index >= 0) {
      _items[index] = _items[index].copyWith(isRead: true);
    }
  }
}

class _TestApp extends StatelessWidget {
  const _TestApp({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(body: child),
    );
  }
}
