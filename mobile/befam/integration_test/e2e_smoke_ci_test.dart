import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/e2e_scenarios.dart';
import 'support/e2e_test_harness.dart';
import 'support/pages/auth_page.dart';
import 'support/pages/genealogy_page.dart';
import 'support/pages/shell_page.dart';
import 'support/release_suite_registry.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final allCaseIds = automatedReleaseCases
      .map((entry) => entry.testCaseId)
      .toSet();

  group('CI Smoke · Auth + Tree', () {
    testWidgets(
      '[AUTH-001][P0] phone OTP flow reaches shell in stable context',
      (tester) async {
        expect(allCaseIds, contains('AUTH-001'));
        final context = await pumpE2EApp(tester, locale: const Locale('vi'));
        final authPage = AuthPageObject(tester);
        final shellPage = ShellPageObject(tester);

        await authPage.loginByPhone(clanLeaderExistingGenealogy.phoneInput);
        await shellPage.expectLoaded();
        shellPage.expectScenario(clanLeaderExistingGenealogy);

        await captureScreenshotSafe(binding, 'e2e-smoke-auth-001');
        assertNoUnhandledFailures(tester, crashGuard: context.crashGuard);
      },
    );

    testWidgets(
      '[TREE-001][P0] linked user can open genealogy workspace',
      (tester) async {
        expect(allCaseIds, contains('TREE-001'));
        final context = await pumpE2EApp(tester, locale: const Locale('vi'));
        final authPage = AuthPageObject(tester);
        final shellPage = ShellPageObject(tester);
        final genealogyPage = GenealogyPageObject(tester);

        await authPage.loginByPhone(clanLeaderExistingGenealogy.phoneInput);
        await shellPage.expectLoaded();
        await shellPage.openTreeTab();
        await genealogyPage.expectTreeLoaded();

        await captureScreenshotSafe(binding, 'e2e-smoke-tree-001');
        assertNoUnhandledFailures(tester, crashGuard: context.crashGuard);
      },
    );
  });
}
