import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../e2e_test_harness.dart';

class ProfilePageObject {
  const ProfilePageObject(this.tester);

  final WidgetTester tester;

  Future<void> switchLanguageToEnglish() async {
    await _tapLanguageOption(
      primaryFinder: find.byKey(const Key('profile-language-option-en')),
      labels: const ['Tiếng Anh', 'English'],
      reason: 'Không thấy hoặc không thể chọn ngôn ngữ Tiếng Anh/English.',
    );
  }

  Future<void> switchLanguageToVietnamese() async {
    await _tapLanguageOption(
      primaryFinder: find.byKey(const Key('profile-language-option-vi')),
      labels: const ['Tiếng Việt', 'Vietnamese'],
      reason: 'Không thấy hoặc không thể chọn ngôn ngữ Tiếng Việt.',
    );
  }

  Future<void> expectEnglishApplied() async {
    await waitFor(
      tester,
      maxFrames: 1200,
      reason: 'Ngôn ngữ chưa chuyển sang English.',
      condition: () =>
          find.text('English').evaluate().isNotEmpty ||
          find.text('Profile').evaluate().isNotEmpty ||
          find.text('Notification settings').evaluate().isNotEmpty,
    );
  }

  Future<void> togglePushNotificationSetting() async {
    final pushToggle = find.byKey(
      const Key('notification-setting-push-enabled'),
    );
    await revealFinder(tester, pushToggle);
    await waitForFinder(
      tester,
      pushToggle,
      reason: 'Không thấy toggle cài đặt push notification.',
    );
    await tapFinderSafely(
      tester,
      pushToggle,
      reason: 'Không thể bật/tắt push notification.',
      dismissKeyboardBeforeTap: false,
    );
  }

  Future<void> expectNotificationSettingsVisible() async {
    final notificationSettingFinder = find.byKey(
      const Key('notification-setting-event-updates'),
    );
    await revealFinder(tester, notificationSettingFinder);
    await waitFor(
      tester,
      reason: 'Không thấy block cài đặt thông báo trong hồ sơ.',
      condition: () =>
          notificationSettingFinder.evaluate().isNotEmpty &&
          notificationSettingFinder.hitTestable().evaluate().isNotEmpty,
    );
  }

  Future<void> _tapLanguageOption({
    required Finder primaryFinder,
    required List<String> labels,
    required String reason,
  }) async {
    Finder? findCandidate() {
      if (primaryFinder.evaluate().isNotEmpty) {
        return primaryFinder;
      }
      for (final label in labels) {
        final candidate = find.text(label);
        if (candidate.evaluate().isNotEmpty) {
          return candidate;
        }
      }
      return null;
    }

    final scrollables = find.byType(Scrollable);
    const downDrag = Offset(0, 260);
    const upDrag = Offset(0, -260);
    for (var attempt = 0; attempt < 14; attempt += 1) {
      final candidate = findCandidate();
      if (candidate != null) {
        await tapFinderSafely(
          tester,
          candidate,
          reason: reason,
          dismissKeyboardBeforeTap: false,
        );
        return;
      }

      if (scrollables.evaluate().isNotEmpty) {
        final delta = attempt < 8 ? downDrag : upDrag;
        await tester.drag(scrollables.first, delta);
      }
      await tester.pump(const Duration(milliseconds: 140));
    }

    fail(reason);
  }
}
