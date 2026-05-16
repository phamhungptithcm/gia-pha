import 'package:befam/app/app.dart';
import 'package:befam/app/bootstrap/firebase_setup_status.dart';
import 'package:befam/app/theme/app_theme.dart';
import 'package:befam/core/widgets/app_motion.dart';
import 'package:befam/core/widgets/app_workspace_chrome.dart';
import 'package:befam/features/auth/presentation/auth_experience.dart';
import 'package:befam/features/auth/services/auth_analytics_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/features/auth/services/debug_auth_gateway.dart';
import '../../support/features/auth/services/debug_clan_context_service.dart';
import '../../support/features/clan/services/debug_clan_repository.dart';
import '../../support/features/member/services/debug_member_repository.dart';

void main() {
  final status = FirebaseSetupStatus.ready(
    projectId: 'be-fam-3ab23',
    storageBucket: 'be-fam-3ab23.firebasestorage.app',
    enabledServices: ['Auth', 'Firestore', 'Storage', 'Messaging'],
    isCrashReportingEnabled: false,
  );

  test('mobile theme uses BeFam scale transitions only', () {
    final transitions = AppTheme.light().pageTransitionsTheme.builders;

    expect(
      transitions[TargetPlatform.android],
      isA<BeFamPageTransitionsBuilder>(),
    );
    expect(transitions[TargetPlatform.iOS], isA<BeFamPageTransitionsBuilder>());
    expect(
      transitions[TargetPlatform.macOS],
      isA<BeFamPageTransitionsBuilder>(),
    );
  });

  testWidgets('mobile app gives every route the lineage backdrop shell', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      BeFamApp(
        status: status,
        authGateway: DebugAuthGateway(),
        authAnalyticsService: const NoopAuthAnalyticsService(),
        clanContextService: const DebugClanContextService(),
        clanRepository: DebugClanRepository.seeded(),
        memberRepository: DebugMemberRepository.seeded(),
        locale: const Locale('vi'),
      ),
    );
    await tester.pump();

    expect(find.byType(AppLineageBackdrop), findsWidgets);

    final authContext = tester.element(find.byType(AuthExperience));
    expect(Theme.of(authContext).scaffoldBackgroundColor, Colors.transparent);
  });
}
