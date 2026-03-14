import 'package:befam/app/bootstrap/firebase_setup_status.dart';
import 'package:befam/app/home/app_shell_page.dart';
import 'package:befam/features/auth/models/auth_entry_method.dart';
import 'package:befam/features/auth/models/auth_member_access_mode.dart';
import 'package:befam/features/auth/models/auth_session.dart';
import 'package:befam/features/clan/services/debug_clan_repository.dart';
import 'package:befam/features/member/services/debug_member_repository.dart';
import 'package:befam/features/notifications/services/notification_inbox_repository.dart';
import 'package:befam/features/notifications/services/push_notification_service.dart';
import 'package:befam/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  AuthSession buildSession() {
    return AuthSession(
      uid: 'debug:+84901234567',
      loginMethod: AuthEntryMethod.phone,
      phoneE164: '+84901234567',
      displayName: 'Nguyen Minh',
      memberId: 'member_demo_parent_001',
      clanId: 'clan_demo_001',
      branchId: 'branch_demo_001',
      primaryRole: 'CLAN_ADMIN',
      accessMode: AuthMemberAccessMode.claimed,
      linkedAuthUid: true,
      isSandbox: true,
      signedInAtIso: DateTime(2026, 3, 14).toIso8601String(),
    );
  }

  FirebaseSetupStatus buildReadyStatus() {
    return FirebaseSetupStatus.ready(
      projectId: 'be-fam-3ab23',
      storageBucket: 'be-fam-3ab23.firebasestorage.app',
      enabledServices: const ['Auth', 'Firestore', 'Functions', 'Messaging'],
      isCrashReportingEnabled: false,
    );
  }

  testWidgets('opens event destination page from opened-app deep link', (
    tester,
  ) async {
    final pushService = _ControllablePushNotificationService();

    await tester.pumpWidget(
      _ShellTestApp(
        child: AppShellPage(
          status: buildReadyStatus(),
          session: buildSession(),
          clanRepository: DebugClanRepository.seeded(),
          memberRepository: DebugMemberRepository.seeded(),
          notificationInboxRepository: _StaticNotificationInboxRepository(),
          pushNotificationService: pushService,
        ),
      ),
    );
    await tester.pumpAndSettle();

    pushService.emit(
      const NotificationDeepLink(
        targetType: NotificationTargetType.event,
        referenceId: 'event_demo_001',
        messageId: 'message_event_001',
        origin: NotificationMessageOrigin.openedApp,
        title: 'Event updated',
        body: 'The family event has a schedule update.',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('notification-target-event')), findsOneWidget);
    expect(find.text('event_demo_001'), findsOneWidget);
  });

  testWidgets('opens scholarship destination page from opened-app deep link', (
    tester,
  ) async {
    final pushService = _ControllablePushNotificationService();

    await tester.pumpWidget(
      _ShellTestApp(
        child: AppShellPage(
          status: buildReadyStatus(),
          session: buildSession(),
          clanRepository: DebugClanRepository.seeded(),
          memberRepository: DebugMemberRepository.seeded(),
          notificationInboxRepository: _StaticNotificationInboxRepository(),
          pushNotificationService: pushService,
        ),
      ),
    );
    await tester.pumpAndSettle();

    pushService.emit(
      const NotificationDeepLink(
        targetType: NotificationTargetType.scholarship,
        referenceId: 'submission_demo_001',
        messageId: 'message_scholarship_001',
        origin: NotificationMessageOrigin.openedApp,
        title: 'Scholarship reviewed',
        body: 'A scholarship decision has been published.',
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('notification-target-scholarship')),
      findsOneWidget,
    );
    expect(find.text('submission_demo_001'), findsOneWidget);
  });

  testWidgets(
    'renders notification settings placeholder toggles on Profile tab',
    (tester) async {
      await tester.pumpWidget(
        _ShellTestApp(
          child: AppShellPage(
            status: buildReadyStatus(),
            session: buildSession(),
            clanRepository: DebugClanRepository.seeded(),
            memberRepository: DebugMemberRepository.seeded(),
            notificationInboxRepository: _StaticNotificationInboxRepository(),
            pushNotificationService: _ControllablePushNotificationService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('notification-setting-event-updates')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('notification-setting-scholarship-updates')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('notification-setting-general-updates')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('notification-setting-quiet-hours')),
        findsOneWidget,
      );
    },
  );
}

class _ControllablePushNotificationService implements PushNotificationService {
  void Function(NotificationDeepLink deepLink)? _onDeepLink;

  @override
  Future<void> start({
    required AuthSession session,
    void Function(NotificationDeepLink deepLink)? onDeepLink,
  }) async {
    _onDeepLink = onDeepLink;
  }

  @override
  Future<void> stop() async {
    _onDeepLink = null;
  }

  void emit(NotificationDeepLink deepLink) {
    _onDeepLink?.call(deepLink);
  }
}

class _StaticNotificationInboxRepository
    implements NotificationInboxRepository {
  @override
  bool get isSandbox => true;

  @override
  Future<NotificationInboxPageResult> loadInboxPage({
    required AuthSession session,
    int limit = 20,
    NotificationInboxCursor? cursor,
  }) async {
    return const NotificationInboxPageResult(items: [], nextCursor: null);
  }

  @override
  Future<void> markAsRead({
    required AuthSession session,
    required String notificationId,
  }) async {}
}

class _ShellTestApp extends StatelessWidget {
  const _ShellTestApp({required this.child});

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
      home: child,
    );
  }
}
