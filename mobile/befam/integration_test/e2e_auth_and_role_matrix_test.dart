import 'package:befam/app/home/app_shell_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/e2e_scenarios.dart';
import 'support/e2e_test_harness.dart';
import 'support/pages/auth_page.dart';
import 'support/pages/shell_page.dart';
import 'support/release_suite_registry.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final allCaseIds = automatedReleaseCases.map((entry) => entry.testCaseId).toSet();

  group('Release Suite · Auth + Role Matrix', () {
    testWidgets('[AUTH-001][P0] phone OTP flow + privacy gate + role matrix', (
      tester,
    ) async {
      expect(allCaseIds, contains('AUTH-001'));
      final context = await pumpE2EApp(tester, locale: const Locale('vi'));
      final authPage = AuthPageObject(tester);

      await authPage.verifyPrivacyGateBlocksLoginUntilAccepted();
      await authPage.loginByPhone(clanLeaderExistingGenealogy.phoneInput);

      final shellPage = ShellPageObject(tester);
      await shellPage.expectLoaded();
      shellPage.expectScenario(clanLeaderExistingGenealogy);
      await captureScreenshotSafe(binding, 'e2e-auth-001-clan-leader');

      assertNoUnhandledFailures(tester, crashGuard: context.crashGuard);
    });

    testWidgets('[AUTH-003][P0] child-code OTP flow goes to shell', (
      tester,
    ) async {
      expect(allCaseIds, contains('AUTH-003'));
      final context = await pumpE2EApp(tester, locale: const Locale('vi'));
      final authPage = AuthPageObject(tester);

      await authPage.loginByChildCode('BEFAM-CHILD-001');

      await waitFor(
        tester,
        reason: 'Luồng child-code không vào AppShell.',
        condition: () => find.byType(AppShellPage).evaluate().isNotEmpty,
      );
      await captureScreenshotSafe(binding, 'e2e-auth-003-child-code');
      assertNoUnhandledFailures(tester, crashGuard: context.crashGuard);
    });

    testWidgets(
      '[AUTH-009][CTX-003][P0] unlinked user is stable and routed to discovery',
      (tester) async {
        expect(allCaseIds, containsAll(<String>['AUTH-009', 'CTX-003']));
        final context = await pumpE2EApp(tester, locale: const Locale('vi'));
        final authPage = AuthPageObject(tester);
        final shellPage = ShellPageObject(tester);

        await authPage.loginByPhone(unlinkedUser.phoneInput);
        await shellPage.expectLoaded();
        shellPage.expectScenario(unlinkedUser);

        await shellPage.expectUnlinkedTreeDiscovery();
        await captureScreenshotSafe(binding, 'e2e-auth-009-unlinked-discovery');

        assertNoUnhandledFailures(tester, crashGuard: context.crashGuard);
      },
    );

    testWidgets(
      '[AUTH-001][P0] validate all 6 debug scenarios map to expected session context',
      (tester) async {
        final scenarioErrors = <String>[];
        for (final scenario in allDebugLoginScenarios) {
          final context = await pumpE2EApp(tester, locale: const Locale('vi'));
          final authPage = AuthPageObject(tester);
          final shellPage = ShellPageObject(tester);

          try {
            await authPage.loginByPhone(scenario.phoneInput);
            await shellPage.expectLoaded();
            shellPage.expectScenario(scenario);
            await captureScreenshotSafe(
              binding,
              'e2e-scenario-${scenario.code.toLowerCase()}',
            );
          } catch (error) {
            scenarioErrors.add('${scenario.code}: $error');
          }

          assertNoUnhandledFailures(tester, crashGuard: context.crashGuard);
        }

        expect(
          scenarioErrors,
          isEmpty,
          reason: 'Một hoặc nhiều scenario login thất bại: $scenarioErrors',
        );
      },
    );
  });
}
