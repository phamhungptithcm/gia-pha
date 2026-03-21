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
    await tester.tap(find.byKey(const Key('calendar-add-event-button')));
    await safePumpAndSettle(tester);

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
      await tester.tap(memorialButton.last);
      await safePumpAndSettle(tester);

      final memorialMemberFinder = find.text(primaryMemorialMember);
      await waitForFinder(
        tester,
        memorialMemberFinder,
        reason: 'Không thấy thành viên giỗ kỵ "$primaryMemorialMember".',
      );
      await tester.tap(memorialMemberFinder.first);
      await safePumpAndSettle(tester);

      await tapText(tester, 'Xong');
    }

    await tester.tap(find.byKey(const Key('calendar-event-continue-button')));
    await safePumpAndSettle(tester);

    await waitForFinder(
      tester,
      find.byKey(const Key('calendar-event-save-button')),
      reason: 'Không thấy bước lưu sự kiện.',
    );
    await tester.tap(find.byKey(const Key('calendar-event-save-button')));
    await safePumpAndSettle(tester);

    await waitForFinder(
      tester,
      find.text(title),
      reason: 'Không thấy sự kiện mới "$title" trong panel ngày.',
    );
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

    await tester.tap(dropdown.first);
    await safePumpAndSettle(tester);

    final memorialOption = find.textContaining('Giỗ');
    if (memorialOption.evaluate().isNotEmpty) {
      await tester.tap(memorialOption.first);
      await safePumpAndSettle(tester);
      return;
    }

    final memorialOptionEn = find.textContaining('Memorial');
    if (memorialOptionEn.evaluate().isNotEmpty) {
      await tester.tap(memorialOptionEn.first);
      await safePumpAndSettle(tester);
    }
  }
}
