import 'package:befam/app/home/app_shell_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../e2e_scenarios.dart';
import '../e2e_test_harness.dart';

class ShellPageObject {
  const ShellPageObject(this.tester);

  final WidgetTester tester;

  Finder get shellFinder => find.byType(AppShellPage);

  Future<void> expectLoaded() async {
    await waitFor(
      tester,
      condition: () => shellFinder.evaluate().isNotEmpty,
      reason: 'Không thấy AppShellPage sau đăng nhập.',
    );
    expect(shellFinder, findsOneWidget);
  }

  void expectScenario(E2ELoginScenario scenario) {
    expectScenarioContext(tester, scenario);
  }

  Future<void> openTreeTab() async {
    await tapBottomNavigationByIcons(
      tester,
      icons: const [
        Icons.account_tree_outlined,
        Icons.travel_explore_outlined,
        Icons.account_tree,
        Icons.travel_explore,
      ],
      fallbackLabel: 'Gia phả',
    );
  }

  Future<void> openEventsTab() async {
    await tapBottomNavigationByIcons(
      tester,
      icons: const [Icons.event_outlined, Icons.event],
      fallbackLabel: 'Sự kiện',
    );
  }

  Future<void> openBillingTab() async {
    await tapBottomNavigationByIcons(
      tester,
      icons: const [Icons.workspace_premium_outlined, Icons.workspace_premium],
      fallbackLabel: 'Gói',
    );
  }

  Future<void> openProfileTab() async {
    await tapBottomNavigationByIcons(
      tester,
      icons: const [Icons.person_outline, Icons.person],
      fallbackLabel: 'Hồ sơ',
    );
  }

  Future<void> openHomeTab() async {
    await tapBottomNavigationByIcons(
      tester,
      icons: const [Icons.space_dashboard_outlined, Icons.space_dashboard],
      fallbackLabel: 'Trang chủ',
    );
  }

  Future<void> openMembersFromShortcut() async {
    await openShortcut(tester, 'shortcut-members');
  }

  Future<void> expectUnlinkedTreeDiscovery() async {
    bool isDiscoveryVisible() {
      final discoveryKey = find.byKey(const ValueKey<String>('tree-discovery'));
      if (discoveryKey.evaluate().isNotEmpty) {
        return true;
      }
      return find.text('Khám phá gia phả').evaluate().isNotEmpty ||
          find.text('Genealogy discovery').evaluate().isNotEmpty;
    }

    await openTreeTab();
    await tester.pump(const Duration(milliseconds: 200));
    if (isDiscoveryVisible()) {
      return;
    }

    await openHomeTab();
    await openShortcut(tester, 'shortcut-tree');
    await waitFor(
      tester,
      reason: 'User unlinked không vào trang discovery.',
      condition: isDiscoveryVisible,
    );
  }

  Future<void> emitPushDeepLinkToEvent({
    required void Function({
      required String? referenceId,
      String? messageId,
      String? title,
      String? body,
    })
    emit,
  }) async {
    emit(
      referenceId: 'event_demo_001',
      messageId: 'notif_e2e_001',
      title: 'Nhắc sự kiện',
      body: 'Sự kiện giỗ kỵ sắp tới',
    );
    await safePumpAndSettle(tester);
  }
}
