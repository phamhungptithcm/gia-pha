import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../e2e_test_harness.dart';

class GenealogyPageObject {
  const GenealogyPageObject(this.tester);

  final WidgetTester tester;

  Future<void> expectTreeLoaded() async {
    await waitForFinder(
      tester,
      find.byKey(const Key('genealogy-landing-card')),
      reason: 'Không thấy landing card của cây gia phả.',
    );
  }

  Future<void> switchScopeToBranchAndBack() async {
    final branchKey = find.byKey(const Key('genealogy-scope-branch'));
    if (branchKey.evaluate().isNotEmpty) {
      await tester.tap(branchKey.first);
      await safePumpAndSettle(tester);
    }

    final clanKey = find.byKey(const Key('genealogy-scope-clan'));
    if (clanKey.evaluate().isNotEmpty) {
      await tester.tap(clanKey.first);
      await safePumpAndSettle(tester);
    }
  }

  Future<void> openMemberDetailFromNode(String memberId) async {
    final infoButton = find.byKey(Key('tree-node-info-$memberId'));
    await waitForFinder(
      tester,
      infoButton,
      reason: 'Không thấy nút info cho node $memberId.',
    );
    await tester.ensureVisible(infoButton);
    await tester.tap(infoButton);
    await safePumpAndSettle(tester);

    final openAction = find.byKey(
      const Key('genealogy-open-member-detail-action'),
    );
    await waitForFinder(
      tester,
      openAction,
      reason: 'Không thấy action mở chi tiết thành viên.',
    );
    await tester.tap(openAction);
    await safePumpAndSettle(tester);
  }
}
