import 'package:befam/app/bootstrap/firebase_setup_status.dart';
import 'package:befam/app/home/app_shell_page.dart';
import 'package:befam/features/auth/models/auth_entry_method.dart';
import 'package:befam/features/auth/models/auth_member_access_mode.dart';
import 'package:befam/features/auth/models/auth_session.dart';
import '../../support/features/clan/services/debug_clan_repository.dart';
import '../../support/features/member/services/debug_member_repository.dart';
import 'package:befam/features/notifications/services/push_notification_service.dart';
import 'package:befam/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpUi(WidgetTester tester, {int frames = 24}) async {
    for (var index = 0; index < frames; index += 1) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  void setMobileViewport(WidgetTester tester) {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(740, 932);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });
  }

  FirebaseSetupStatus buildReadyStatus() {
    return FirebaseSetupStatus.ready(
      projectId: 'be-fam-3ab23',
      storageBucket: 'be-fam-3ab23.firebasestorage.app',
      enabledServices: const ['Auth', 'Firestore', 'Functions', 'Messaging'],
      isCrashReportingEnabled: false,
    );
  }

  AuthSession buildLinkedSession() {
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
      signedInAtIso: DateTime(2026, 3, 15).toIso8601String(),
    );
  }

  AuthSession buildUnlinkedSession() {
    return AuthSession(
      uid: 'debug:+84909990000',
      loginMethod: AuthEntryMethod.phone,
      phoneE164: '+84909990000',
      displayName: 'Khách vãng lai',
      memberId: null,
      clanId: null,
      branchId: null,
      primaryRole: 'MEMBER',
      accessMode: AuthMemberAccessMode.unlinked,
      linkedAuthUid: true,
      isSandbox: true,
      signedInAtIso: DateTime(2026, 3, 15).toIso8601String(),
    );
  }

  testWidgets(
    'linked shell exposes billing before profile in bottom navigation',
    (tester) async {
      setMobileViewport(tester);
      await tester.pumpWidget(
        _ShellTestApp(
          child: AppShellPage(
            status: buildReadyStatus(),
            session: buildLinkedSession(),
            clanRepository: DebugClanRepository.seeded(),
            memberRepository: DebugMemberRepository.seeded(),
            pushNotificationService: _NoopPushNotificationService(),
          ),
        ),
      );
      await pumpUi(tester);

      final destinations = tester
          .widgetList<NavigationDestination>(find.byType(NavigationDestination))
          .toList(growable: false);

      expect(destinations.length, 5);
      expect(destinations[3].label, 'Billing');
      expect(destinations[4].label, 'Profile');
    },
  );

  testWidgets('ad banner auto hides after 10 seconds', (tester) async {
    setMobileViewport(tester);
    await tester.pumpWidget(
      _ShellTestApp(
        child: AppShellPage(
          status: buildReadyStatus(),
          session: buildLinkedSession(),
          clanRepository: DebugClanRepository.seeded(),
          memberRepository: DebugMemberRepository.seeded(),
          pushNotificationService: _NoopPushNotificationService(),
        ),
      ),
    );
    await pumpUi(tester);

    expect(find.text('Free/Base plans show light ads.'), findsOneWidget);

    await tester.pump(const Duration(seconds: 11));
    await pumpUi(tester);

    expect(find.text('Free/Base plans show light ads.'), findsNothing);
  });

  testWidgets(
    'unlinked shell opens personal billing workspace in billing tab',
    (tester) async {
      setMobileViewport(tester);
      await tester.pumpWidget(
        _ShellTestApp(
          child: AppShellPage(
            status: buildReadyStatus(),
            session: buildUnlinkedSession(),
            clanRepository: DebugClanRepository.seeded(),
            memberRepository: DebugMemberRepository.seeded(),
            pushNotificationService: _NoopPushNotificationService(),
          ),
        ),
      );
      await pumpUi(tester);

      final destinations = tester
          .widgetList<NavigationDestination>(find.byType(NavigationDestination))
          .toList(growable: false);
      expect(destinations.length, 5);
      expect(destinations[3].label, 'Billing');
      expect(destinations[4].label, 'Profile');

      await tester.tap(find.text('Billing'));
      await pumpUi(tester, frames: 36);

      expect(find.text('Subscription & billing'), findsOneWidget);
      expect(find.text('Discover genealogies'), findsNothing);
      expect(find.text('Create clan workspace'), findsNothing);
    },
  );
}

class _NoopPushNotificationService implements PushNotificationService {
  @override
  Future<void> start({
    required AuthSession session,
    void Function(NotificationDeepLink deepLink)? onDeepLink,
  }) async {}

  @override
  Future<void> stop() async {}
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
