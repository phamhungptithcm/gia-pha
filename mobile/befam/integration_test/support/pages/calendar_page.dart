import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../e2e_test_harness.dart';

class CalendarPageObject {
  const CalendarPageObject(this.tester);

  final WidgetTester tester;

  Future<void> expectCalendarLoaded() async {
    await waitForFinder(
      tester,
      find.byKey(const Key('calendar-add-event-button')),
      reason: 'Không thấy nút tạo sự kiện ở lịch.',
    );
  }

  Future<void> createMemorialEvent({
    required String title,
    String primaryMemorialMember = 'Lê Thành Công',
  }) async {
    await tapFinderSafely(
      tester,
      find.byKey(const Key('calendar-add-event-button')),
      reason: 'Không thể bấm nút tạo sự kiện.',
    );

    await waitForFinder(
      tester,
      find.byKey(const Key('calendar-event-title-field')),
      reason: 'Không thấy form tạo sự kiện.',
    );
    await tester.enterText(
      find.byKey(const Key('calendar-event-title-field')),
      title,
    );
    await safePumpAndSettle(tester);

    await _ensureMemorialEventType();

    final memorialButton = find.text('Giỗ của ai');
    if (memorialButton.evaluate().isNotEmpty) {
      await tapFinderSafely(
        tester,
        memorialButton,
        reason: 'Không thể mở bộ chọn người được tưởng niệm.',
      );

      final memorialMemberFinder = find.text(primaryMemorialMember);
      if (memorialMemberFinder.evaluate().isNotEmpty) {
        await tapFinderSafely(
          tester,
          memorialMemberFinder,
          reason: 'Không thể chọn thành viên giỗ kỵ "$primaryMemorialMember".',
          dismissKeyboardBeforeTap: false,
        );
      } else {
        final fallbackMemberOption = find.byType(CheckboxListTile);
        await waitForFinder(
          tester,
          fallbackMemberOption,
          reason:
              'Không thấy thành viên giỗ kỵ "$primaryMemorialMember" và cũng không có lựa chọn thay thế.',
        );
        await tapFinderSafely(
          tester,
          fallbackMemberOption,
          reason: 'Không thể chọn thành viên giỗ kỵ thay thế.',
          dismissKeyboardBeforeTap: false,
        );
      }

      await tapText(tester, 'Xong');
    }

    await tapFinderSafely(
      tester,
      find.byKey(const Key('calendar-event-continue-button')),
      reason: 'Không thể sang bước tiếp theo của form sự kiện.',
    );

    await waitForFinder(
      tester,
      find.byKey(const Key('calendar-event-save-button')),
      reason: 'Không thấy bước lưu sự kiện.',
    );
    await tapFinderSafely(
      tester,
      find.byKey(const Key('calendar-event-save-button')),
      reason: 'Không thể bấm nút lưu sự kiện.',
    );

    await safePumpAndSettle(tester);
  }

  Future<void> _ensureMemorialEventType() async {
    final memorialButton = find.text('Giỗ của ai');
    if (memorialButton.evaluate().isNotEmpty) {
      return;
    }

    final dropdown = find.byWidgetPredicate((widget) {
      if (widget is! DropdownButtonFormField) {
        return false;
      }
      final key = widget.key;
      return key is Key &&
          key.toString().contains('calendar-event-type-dropdown-');
    });
    if (dropdown.evaluate().isEmpty) {
      return;
    }

    await tapFinderSafely(
      tester,
      dropdown,
      reason: 'Không thể mở dropdown loại sự kiện.',
    );

    final memorialOption = find.textContaining('Giỗ');
    if (memorialOption.evaluate().isNotEmpty) {
      await tapFinderSafely(
        tester,
        memorialOption,
        reason: 'Không thể chọn loại sự kiện giỗ.',
        dismissKeyboardBeforeTap: false,
      );
      return;
    }

    final memorialOptionEn = find.textContaining('Memorial');
    if (memorialOptionEn.evaluate().isNotEmpty) {
      await tapFinderSafely(
        tester,
        memorialOptionEn,
        reason: 'Không thể chọn loại sự kiện memorial.',
        dismissKeyboardBeforeTap: false,
      );
    }
  }
}
