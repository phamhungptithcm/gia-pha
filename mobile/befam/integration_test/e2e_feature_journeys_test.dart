import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/e2e_scenarios.dart';
import 'support/e2e_test_harness.dart';
import 'support/pages/auth_page.dart';
import 'support/pages/calendar_page.dart';
import 'support/pages/genealogy_page.dart';
import 'support/pages/member_page.dart';
import 'support/pages/notification_page.dart';
import 'support/pages/profile_page.dart';
import 'support/pages/shell_page.dart';
import 'support/release_suite_registry.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final allCaseIds = automatedReleaseCases
      .map((entry) => entry.testCaseId)
      .toSet();

  group('Release Suite · Genealogy + Members + Calendar + Profile', () {
    testWidgets(
      '[TREE-001][RULE-001][P0] genealogy tree load, scope, node navigation',
      (tester) async {
        expect(allCaseIds, containsAll(<String>['TREE-001', 'RULE-001']));
        final context = await pumpE2EApp(tester, locale: const Locale('vi'));
        final authPage = AuthPageObject(tester);
        final shellPage = ShellPageObject(tester);
        final genealogyPage = GenealogyPageObject(tester);

        await authPage.loginByPhone(clanLeaderExistingGenealogy.phoneInput);
        await shellPage.expectLoaded();
        await shellPage.openTreeTab();
        await genealogyPage.expectTreeLoaded();
        await genealogyPage.switchScopeToBranchAndBack();
        await genealogyPage.openMemberDetailFromNode('member_demo_parent_001');
        await waitForFinder(
          tester,
          find.textContaining('Nguyễn Minh'),
          reason: 'Không mở được chi tiết thành viên từ node gia phả.',
        );

        await captureScreenshotSafe(binding, 'e2e-tree-001-member-detail');
        assertNoUnhandledFailures(tester, crashGuard: context.crashGuard);
      },
    );

    testWidgets('[MEM-001][P0] add member flow with sibling-order hint', (
      tester,
    ) async {
      expect(allCaseIds, contains('MEM-001'));
      final context = await pumpE2EApp(tester, locale: const Locale('vi'));
      final authPage = AuthPageObject(tester);
      final shellPage = ShellPageObject(tester);
      final memberPage = MemberPageObject(tester);
      final memberName =
          'E2E Thành viên ${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

      await authPage.loginByPhone(clanLeaderExistingGenealogy.phoneInput);
      await shellPage.expectLoaded();
      await shellPage.openMembersFromShortcut();
      await memberPage.expectWorkspaceLoaded();
      await memberPage.startAddMemberFlowManual();
      await memberPage.addMemberWithParent(
        fullName: memberName,
        fatherMemberId: 'member_demo_parent_001',
      );
      await memberPage.expectMemberName(memberName);

      await captureScreenshotSafe(binding, 'e2e-member-001-create-member');
      assertNoUnhandledFailures(tester, crashGuard: context.crashGuard);
    });

    testWidgets('[EVT-002][P0] create lunar memorial event with details', (
      tester,
    ) async {
      expect(allCaseIds, contains('EVT-002'));
      final context = await pumpE2EApp(tester, locale: const Locale('vi'));
      final authPage = AuthPageObject(tester);
      final shellPage = ShellPageObject(tester);
      final calendarPage = CalendarPageObject(tester);
      final title =
          'E2E Giỗ kỵ ${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';

      await authPage.loginByPhone(clanLeaderExistingGenealogy.phoneInput);
      await shellPage.expectLoaded();
      await shellPage.openEventsTab();
      await calendarPage.expectCalendarLoaded();
      await calendarPage.createMemorialEvent(title: title);

      await captureScreenshotSafe(binding, 'e2e-calendar-evt-002-memorial');
      assertNoUnhandledFailures(tester, crashGuard: context.crashGuard);
    });

    testWidgets(
      '[CTX-007][NOTIF-003][P1] profile language persistence + notification inbox deep-link',
      (tester) async {
        expect(allCaseIds, containsAll(<String>['CTX-007', 'NOTIF-003']));
        final context = await pumpE2EApp(tester, locale: const Locale('vi'));
        final authPage = AuthPageObject(tester);
        final shellPage = ShellPageObject(tester);
        final profilePage = ProfilePageObject(tester);
        final notificationPage = NotificationPageObject(tester);

        await authPage.loginByPhone(clanLeaderExistingGenealogy.phoneInput);
        await shellPage.expectLoaded();
        await shellPage.openProfileTab();

        await profilePage.expectNotificationSettingsVisible();
        await profilePage.togglePushNotificationSetting();
        await profilePage.switchLanguageToEnglish();
        await profilePage.expectEnglishApplied();

        await shellPage.openHomeTab();
        await shellPage.openProfileTab();
        await profilePage.expectEnglishApplied();

        final shellSession = extractShellSession(tester);
        await notificationPage.openInbox(shellSession);
        await notificationPage.openFirstNotification();
        await notificationPage.expectEventDeepLinkTargetVisible();

        await captureScreenshotSafe(binding, 'e2e-profile-ctx-007-notif-003');
        assertNoUnhandledFailures(tester, crashGuard: context.crashGuard);
      },
    );
  });
}
