import 'package:befam/app/home/app_shell_page.dart';
import 'package:befam/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/e2e_test_harness.dart';
import 'support/pages/shell_page.dart';

const bool runLiveFirebase = bool.fromEnvironment(
  'BEFAM_E2E_RUN_LIVE',
  defaultValue: false,
);
const String liveTestPhone = String.fromEnvironment('BEFAM_E2E_TEST_PHONE');
const String liveTestOtp = String.fromEnvironment('BEFAM_E2E_TEST_OTP');

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Live smoke gate: OTP login + tree workspace + billing workspace',
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

      await loginWithPhone(
        tester,
        phoneInput: liveTestPhone,
        otpCode: liveTestOtp,
      );
      await waitFor(
        tester,
        condition: () => find.byType(AppShellPage).evaluate().isNotEmpty,
        reason: 'Live smoke gate did not reach AppShell after OTP verify.',
      );
      expect(find.byType(AppShellPage), findsOneWidget);

      final shellPage = ShellPageObject(tester);

      await shellPage.openTreeTab();
      await waitFor(
        tester,
        condition: () =>
            find
                .byKey(const Key('genealogy-landing-card'))
                .evaluate()
                .isNotEmpty ||
            find
                .byKey(const ValueKey<String>('tree-discovery'))
                .evaluate()
                .isNotEmpty,
        reason: 'Tree workspace did not render landing/discovery content.',
      );

      await shellPage.openBillingTab();
      await waitFor(
        tester,
        condition: () =>
            find
                .byKey(const Key('billing-plan-selector'))
                .evaluate()
                .isNotEmpty ||
            find
                .byKey(const Key('billing-open-checkout-button'))
                .evaluate()
                .isNotEmpty ||
            find
                .byKey(const Key('billing-payment-history-section'))
                .evaluate()
                .isNotEmpty,
        reason: 'Billing workspace did not load expected key elements.',
      );

      await captureScreenshotSafe(binding, 'e2e-live-smoke-gate');
      assertNoUnhandledFailures(tester, crashGuard: crashGuard);
    },
    skip: !runLiveFirebase,
  );
}
