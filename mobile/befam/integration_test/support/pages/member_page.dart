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
    await tapFinderSafely(
      tester,
      find.byKey(const Key('member-add-fab')),
      reason: 'Không thể bấm FAB thêm thành viên.',
    );

    final skipManualButton = find.byKey(const Key('member-phone-lookup-skip'));
    if (skipManualButton.evaluate().isNotEmpty) {
      await tapFinderSafely(
        tester,
        skipManualButton,
        reason: 'Không thể bấm nút bỏ qua tra cứu điện thoại.',
      );
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
    await tester.enterText(
      find.byKey(const Key('member-full-name-input')),
      fullName,
    );
    await safePumpAndSettle(tester);

    await tapText(tester, 'Tiếp tục');

    final parentPicker = find.byKey(const Key('member-parent-picker-button'));
    await waitForFinder(
      tester,
      parentPicker,
      reason: 'Không thấy nút chọn cha/mẹ.',
    );
    await tapFinderSafely(
      tester,
      parentPicker,
      reason: 'Không thể mở bộ chọn cha/mẹ.',
    );

    final fatherOption = find.byKey(
      Key('member-parent-picker-father-$fatherMemberId'),
    );
    final anyFatherOption = find.byWidgetPredicate((widget) {
      final key = widget.key;
      return key is ValueKey<String> &&
          key.value.startsWith('member-parent-picker-father-');
    });

    final pickedFatherOption = await waitForFinderOrOtpOrShell(tester, <Finder>[
      fatherOption,
      anyFatherOption,
    ], reason: 'Không thấy danh sách ứng viên cha trong bộ chọn.');
    if (pickedFatherOption == null) {
      fail('Bộ chọn cha/mẹ đóng trước khi chọn được ứng viên cha.');
    }

    await tapFinderSafely(
      tester,
      pickedFatherOption,
      reason: 'Không thể chọn ứng viên cha $fatherMemberId.',
      dismissKeyboardBeforeTap: false,
    );

    await tapFinderSafely(
      tester,
      find.byKey(const Key('member-parent-picker-done')),
      reason: 'Không thể xác nhận bộ chọn cha/mẹ.',
      dismissKeyboardBeforeTap: false,
    );

    await waitForFinder(
      tester,
      find.byKey(const Key('member-sibling-order-auto-input')),
      reason: 'Không thấy nhãn thứ tự anh/chị/em tự động.',
    );

    await tapText(tester, 'Tiếp tục');

    await waitForFinder(
      tester,
      find.byKey(const Key('member-save-button')),
      reason: 'Không thấy nút lưu thành viên.',
    );
    await tapFinderSafely(
      tester,
      find.byKey(const Key('member-save-button')),
      reason: 'Không thể bấm nút lưu thành viên.',
    );
  }

  Future<void> expectMemberName(String fullName) async {
    final searchInput = find.byKey(const Key('members-search-input'));
    if (searchInput.evaluate().isNotEmpty) {
      await revealFinder(tester, searchInput);
      await tester.enterText(searchInput.first, fullName);
      await safePumpAndSettle(tester);
      await dismissKeyboardIfVisible(tester);
    }
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
