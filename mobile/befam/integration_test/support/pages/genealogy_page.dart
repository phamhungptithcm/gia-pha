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
      await tapFinderSafely(
        tester,
        branchKey,
        reason: 'Không thể chuyển phạm vi sang chi hiện tại.',
        dismissKeyboardBeforeTap: false,
      );
    }

    final clanKey = find.byKey(const Key('genealogy-scope-clan'));
    if (clanKey.evaluate().isNotEmpty) {
      await tapFinderSafely(
        tester,
        clanKey,
        reason: 'Không thể chuyển phạm vi về cả họ.',
        dismissKeyboardBeforeTap: false,
      );
    }
  }

  Future<void> openMemberDetailFromNode(String memberId) async {
    final infoButton = find.byKey(Key('tree-node-info-$memberId'));
    await waitForFinder(
      tester,
      infoButton,
      reason: 'Không thấy nút info cho node $memberId.',
    );
    await tapFinderSafely(
      tester,
      infoButton,
      reason: 'Không thể bấm nút info cho node $memberId.',
      dismissKeyboardBeforeTap: false,
    );

    final openAction = find.byKey(
      const Key('genealogy-open-member-detail-action'),
    );
    if (openAction.evaluate().isNotEmpty) {
      await tapFinderSafely(
        tester,
        openAction,
        reason: 'Không thể bấm action mở chi tiết thành viên.',
        dismissKeyboardBeforeTap: false,
      );
    }
  }
}
