import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../e2e_test_harness.dart';

class MemberPageObject {
  const MemberPageObject(this.tester);

  final WidgetTester tester;

  Future<void> expectWorkspaceLoaded() async {
    await waitForFinder(
      tester,
      find.byKey(const Key('member-add-fab')),
      reason: 'Không tìm thấy FAB thêm thành viên.',
    );
  }

  Future<void> startAddMemberFlowManual() async {
    await tester.tap(find.byKey(const Key('member-add-fab')));
    await safePumpAndSettle(tester);

    final skipManualButton = find.byKey(const Key('member-phone-lookup-skip'));
    if (skipManualButton.evaluate().isNotEmpty) {
      await tester.tap(skipManualButton);
      await safePumpAndSettle(tester);
    }
  }

  Future<void> addMemberWithParent({
    required String fullName,
    required String fatherMemberId,
  }) async {
    await waitForFinder(
      tester,
      find.byKey(const Key('member-full-name-input')),
      reason: 'Không thấy form nhập thành viên.',
    );
    await tester.enterText(find.byKey(const Key('member-full-name-input')), fullName);
    await safePumpAndSettle(tester);

    await tapText(tester, 'Tiếp tục');

    final parentPicker = find.byKey(const Key('member-parent-picker-button'));
    await waitForFinder(
      tester,
      parentPicker,
      reason: 'Không thấy nút chọn cha/mẹ.',
    );
    await tester.tap(parentPicker);
    await safePumpAndSettle(tester);

    final fatherOption = find.byKey(
      Key('member-parent-picker-father-$fatherMemberId'),
    );
    await waitForFinder(
      tester,
      fatherOption,
      reason: 'Không thấy ứng viên cha $fatherMemberId.',
    );
    await tester.tap(fatherOption);
    await safePumpAndSettle(tester);

    await tester.tap(find.byKey(const Key('member-parent-picker-done')));
    await safePumpAndSettle(tester);

    await tapText(tester, 'Tiếp tục');

    await waitForFinder(
      tester,
      find.byKey(const Key('member-save-button')),
      reason: 'Không thấy nút lưu thành viên.',
    );
    await tester.tap(find.byKey(const Key('member-save-button')));
    await safePumpAndSettle(tester);
  }

  Future<void> expectMemberName(String fullName) async {
    await waitForFinder(
      tester,
      find.text(fullName),
      reason: 'Không thấy tên thành viên "$fullName" sau khi lưu.',
    );
  }

  Future<void> expectSiblingOrderHintVisible() async {
    await waitForFinder(
      tester,
      find.byKey(const Key('member-sibling-order-auto-input')),
      reason: 'Không thấy nhãn thứ tự anh/chị/em tự động.',
    );
  }
}
