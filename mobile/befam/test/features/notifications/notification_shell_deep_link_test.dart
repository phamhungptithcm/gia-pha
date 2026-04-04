import 'package:befam/app/bootstrap/firebase_setup_status.dart';
import 'package:befam/app/home/app_shell_page.dart';
import 'package:befam/features/auth/models/auth_entry_method.dart';
import 'package:befam/features/auth/models/auth_member_access_mode.dart';
import 'package:befam/features/auth/models/auth_session.dart';
import 'package:befam/features/billing/presentation/billing_workspace_page.dart';
import 'package:befam/features/profile/presentation/profile_workspace_page.dart';
import '../../support/features/clan/services/debug_clan_repository.dart';
import '../../support/features/events/services/debug_event_repository.dart';
import '../../support/features/member/services/debug_member_repository.dart';
import '../../support/features/profile/services/debug_profile_notification_preferences_repository.dart';
import '../../support/features/scholarship/services/debug_scholarship_repository.dart';
import 'package:befam/features/notifications/services/push_notification_service.dart';
import 'package:befam/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  void configureMobileViewport(WidgetTester tester) {
    const logicalSize = Size(430, 932);
    final dpr = tester.view.devicePixelRatio;
    tester.view.physicalSize = Size(
      logicalSize.width * dpr,
      logicalSize.height * dpr,
    );
    addTearDown(tester.view.resetPhysicalSize);
  }

  Future<void> pumpUi(WidgetTester tester, {int frames = 24}) async {
    for (var index = 0; index < frames; index += 1) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  AuthSession buildSession() {
    return AuthSession(
      uid: 'debug:+84901234567',
      loginMethod: AuthEntryMethod.phone,
      phoneE164: '+84901234567',
      displayName: 'Nguyễn Minh',
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
    configureMobileViewport(tester);
    final pushService = _ControllablePushNotificationService();

    await tester.pumpWidget(
      _ShellTestApp(
        child: AppShellPage(
          status: buildReadyStatus(),
          session: buildSession(),
          clanRepository: DebugClanRepository.seeded(),
          memberRepository: DebugMemberRepository.seeded(),
          eventRepository: DebugEventRepository.shared(),
          scholarshipRepository: DebugScholarshipRepository.shared(),
          pushNotificationService: pushService,
        ),
      ),
    );
    await pumpUi(tester);

    pushService.emit(
      const NotificationDeepLink(
        targetType: NotificationTargetType.event,
        referenceId: 'event_demo_memorial_001',
        messageId: 'message_event_001',
        origin: NotificationMessageOrigin.openedApp,
        title: 'Event updated',
        body: 'The family event has a schedule update.',
      ),
    );
    await pumpUi(tester, frames: 36);

    expect(
      find.byKey(const Key('event-detail-page-event_demo_memorial_001')),
      findsOneWidget,
    );
    expect(find.text('Giỗ cụ tổ mùa xuân'), findsOneWidget);
  });

  testWidgets('opens scholarship destination page from opened-app deep link', (
    tester,
  ) async {
    configureMobileViewport(tester);
    final pushService = _ControllablePushNotificationService();

    await tester.pumpWidget(
      _ShellTestApp(
        child: AppShellPage(
          status: buildReadyStatus(),
          session: buildSession(),
          clanRepository: DebugClanRepository.seeded(),
          memberRepository: DebugMemberRepository.seeded(),
          eventRepository: DebugEventRepository.shared(),
          scholarshipRepository: DebugScholarshipRepository.shared(),
          pushNotificationService: pushService,
        ),
      ),
    );
    await pumpUi(tester);

    pushService.emit(
      const NotificationDeepLink(
        targetType: NotificationTargetType.scholarship,
        referenceId: 'sub_demo_001',
        messageId: 'message_scholarship_001',
        origin: NotificationMessageOrigin.openedApp,
        title: 'Scholarship reviewed',
        body: 'A scholarship decision has been published.',
      ),
    );
    await pumpUi(tester, frames: 36);

    expect(
      find.byKey(const Key('scholarship-program-detail-page-sp_demo_2026')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('scholarship-detail-submission-sub_demo_001')),
      findsOneWidget,
    );
  });

  testWidgets('opens billing tab from opened-app deep link', (tester) async {
    configureMobileViewport(tester);
    final pushService = _ControllablePushNotificationService();

    await tester.pumpWidget(
      _ShellTestApp(
        child: AppShellPage(
          status: buildReadyStatus(),
          session: buildSession(),
          clanRepository: DebugClanRepository.seeded(),
          memberRepository: DebugMemberRepository.seeded(),
          eventRepository: DebugEventRepository.shared(),
          scholarshipRepository: DebugScholarshipRepository.shared(),
          pushNotificationService: pushService,
        ),
      ),
    );
    await pumpUi(tester);

    pushService.emit(
      const NotificationDeepLink(
        targetType: NotificationTargetType.billing,
        referenceId: 'txn_demo_001',
        messageId: 'message_billing_001',
        origin: NotificationMessageOrigin.openedApp,
        title: 'Payment status updated',
        body: 'Open billing to review your subscription status.',
      ),
    );
    await pumpUi(tester, frames: 36);

    expect(find.byType(BillingWorkspacePage), findsOneWidget);
    expect(find.byKey(const Key('notification-target-billing')), findsNothing);
  });

  testWidgets('renders notification settings toggles on profile workspace', (
    tester,
  ) async {
    configureMobileViewport(tester);
    await tester.pumpWidget(
      _ShellTestApp(
        child: ProfileWorkspacePage(
          session: buildSession(),
          memberRepository: DebugMemberRepository.seeded(),
          notificationPreferencesRepository:
              DebugProfileNotificationPreferencesRepository.shared(),
          showAppBar: true,
        ),
      ),
    );
    await pumpUi(tester, frames: 120);
    await tester.tap(find.byTooltip('Open settings'));
    await pumpUi(tester, frames: 36);

    expect(find.text('Memorials and events'), findsOneWidget);
    expect(find.text('Scholarships'), findsOneWidget);
    expect(find.text('Family updates'), findsOneWidget);
    expect(find.text('Quiet hours'), findsOneWidget);
  });
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
