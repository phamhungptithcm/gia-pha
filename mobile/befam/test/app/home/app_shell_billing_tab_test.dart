import 'package:befam/app/bootstrap/firebase_setup_status.dart';
import 'package:befam/app/home/app_shell_page.dart';
import 'package:befam/features/auth/models/auth_entry_method.dart';
import 'package:befam/features/auth/models/auth_member_access_mode.dart';
import 'package:befam/features/auth/models/auth_session.dart';
import 'package:befam/features/clan/services/debug_clan_repository.dart';
import 'package:befam/features/member/services/debug_member_repository.dart';
import 'package:befam/features/notifications/services/push_notification_service.dart';
import 'package:befam/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
      displayName: 'Nguyen Minh',
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
      displayName: 'Guest User',
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
      await tester.pumpAndSettle();

      final destinations = tester
          .widgetList<NavigationDestination>(find.byType(NavigationDestination))
          .toList(growable: false);

      expect(destinations.length, 5);
      expect(destinations[3].label, 'Billing');
      expect(destinations[4].label, 'Profile');
    },
  );

  testWidgets('unlinked shell still shows billing tab and CTA actions', (
    tester,
  ) async {
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
    await tester.pumpAndSettle();

    final destinations = tester
        .widgetList<NavigationDestination>(find.byType(NavigationDestination))
        .toList(growable: false);
    expect(destinations.length, 4);
    expect(destinations[3].label, 'Billing');
    expect(find.text('Profile'), findsNothing);

    await tester.tap(find.text('Billing'));
    await tester.pumpAndSettle();

    expect(find.text('Discover genealogies'), findsOneWidget);
    expect(find.text('Create clan workspace'), findsOneWidget);
  });
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
