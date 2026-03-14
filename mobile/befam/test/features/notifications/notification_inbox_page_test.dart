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
      displayName: 'Nguyen Minh',
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

  testWidgets('renders notification rows from repository data', (tester) async {
    final repository = _FakeNotificationInboxRepository(
      items: [
        NotificationInboxItem(
          id: 'notif_001',
          memberId: 'member_demo_parent_001',
          clanId: 'clan_demo_001',
          type: 'event_created',
          title: 'Ancestor remembrance ceremony added',
          body: 'The branch memorial event is scheduled for next Sunday.',
          isRead: false,
          createdAt: DateTime(2026, 3, 14, 10, 30),
          target: NotificationInboxTarget.event,
          targetId: 'event_demo_001',
          data: const {'target': 'event', 'id': 'event_demo_001'},
        ),
        NotificationInboxItem(
          id: 'notif_002',
          memberId: 'member_demo_parent_001',
          clanId: 'clan_demo_001',
          type: 'generic',
          title: 'Family profile sync completed',
          body: 'Your latest profile changes are now visible to your clan.',
          isRead: true,
          createdAt: DateTime(2026, 3, 13, 19, 15),
          target: NotificationInboxTarget.generic,
          targetId: null,
          data: const {'target': 'generic'},
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
    expect(find.byKey(const Key('notification-row-notif_002')), findsOneWidget);
    expect(find.text('2 unread'), findsNothing);
    expect(find.text('1 unread'), findsOneWidget);
    expect(find.text('Unread'), findsOneWidget);
    expect(find.text('Read'), findsOneWidget);
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
  _FakeNotificationInboxRepository({required this.items});

  final List<NotificationInboxItem> items;

  @override
  bool get isSandbox => true;

  @override
  Future<List<NotificationInboxItem>> loadInbox({
    required AuthSession session,
    int limit = 25,
  }) async {
    return items.take(limit).toList(growable: false);
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
