import 'package:befam/app/home/app_shell_page.dart';
import 'package:befam/main.dart' as app;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/e2e_test_harness.dart';

const bool runLiveFirebase = bool.fromEnvironment(
  'BEFAM_E2E_RUN_LIVE',
  defaultValue: false,
);
const String liveTestPhone = String.fromEnvironment('BEFAM_E2E_TEST_PHONE');
const String liveTestOtp = String.fromEnvironment('BEFAM_E2E_TEST_OTP');

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'E2E live Firebase: phone OTP login + security sanity query denial',
    (tester) async {
      if (liveTestPhone.trim().isEmpty || liveTestOtp.trim().isEmpty) {
        fail(
          'Missing BEFAM_E2E_TEST_PHONE/BEFAM_E2E_TEST_OTP. '
          'Provide both with --dart-define when BEFAM_E2E_RUN_LIVE=true.',
        );
      }

      final crashGuard = E2ECrashGuard.install(tester.binding);
      addTearDown(crashGuard.dispose);

      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1200, 2000);
      tester.binding.platformDispatcher.textScaleFactorTestValue = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(
        tester.binding.platformDispatcher.clearTextScaleFactorTestValue,
      );

      await app.main();
      await safePumpAndSettle(tester);

      await acceptPrivacyPolicy(tester);
      await tapText(tester, 'Dùng số điện thoại');
      await tester.enterText(find.byType(TextField).first, liveTestPhone);
      await safePumpAndSettle(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Gửi OTP'));

      await waitForFinder(
        tester,
        find.byKey(const Key('otp-code-input')),
        reason: 'Live flow không tới màn OTP.',
      );
      await tester.enterText(find.byKey(const Key('otp-code-input')), liveTestOtp);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      await safePumpAndSettle(tester);

      await waitFor(
        tester,
        condition: () => find.byType(AppShellPage).evaluate().isNotEmpty,
        reason: 'Live flow verify OTP xong nhưng không vào AppShell.',
      );
      expect(find.byType(AppShellPage), findsOneWidget);

      final shell = tester.widget<AppShellPage>(find.byType(AppShellPage));
      final activeClanId = shell.session.clanId?.trim() ?? '';
      expect(activeClanId, isNotEmpty);

      Object? securityError;
      try {
        await FirebaseFirestore.instance
            .collection('members')
            .where('clanId', isNotEqualTo: activeClanId)
            .limit(1)
            .get();
      } catch (error) {
        securityError = error;
      }

      expect(
        securityError,
        isNotNull,
        reason: 'Cross-clan read query phải bị từ chối bởi rules.',
      );
      if (securityError is FirebaseException) {
        expect(
          <String>{'permission-denied', 'failed-precondition'},
          contains(securityError.code),
        );
      }

      await captureScreenshotSafe(binding, 'e2e-live-firebase-shell');
      assertNoUnhandledFailures(tester, crashGuard: crashGuard);
    },
    skip: !runLiveFirebase,
  );
}
