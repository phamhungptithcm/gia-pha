import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../e2e_test_harness.dart';

class ProfilePageObject {
  const ProfilePageObject(this.tester);

  final WidgetTester tester;

  Future<void> switchLanguageToEnglish() async {
    await waitForFinder(
      tester,
      find.text('Tiếng Anh'),
      reason: 'Không thấy lựa chọn ngôn ngữ Tiếng Anh.',
    );
    await tester.tap(find.text('Tiếng Anh').last);
    await safePumpAndSettle(tester);
  }

  Future<void> switchLanguageToVietnamese() async {
    await waitForFinder(
      tester,
      find.text('Tiếng Việt'),
      reason: 'Không thấy lựa chọn ngôn ngữ Tiếng Việt.',
    );
    await tester.tap(find.text('Tiếng Việt').last);
    await safePumpAndSettle(tester);
  }

  Future<void> expectEnglishApplied() async {
    await waitForFinder(
      tester,
      find.text('Profile'),
      reason: 'Ngôn ngữ chưa chuyển sang English.',
    );
  }

  Future<void> togglePushNotificationSetting() async {
    final pushToggle = find.byKey(
      const Key('notification-setting-push-enabled'),
    );
    await waitForFinder(
      tester,
      pushToggle,
      reason: 'Không thấy toggle cài đặt push notification.',
    );
    await tester.tap(pushToggle);
    await safePumpAndSettle(tester);
  }

  Future<void> expectNotificationSettingsVisible() async {
    await waitForFinder(
      tester,
      find.byKey(const Key('notification-setting-event-updates')),
      reason: 'Không thấy block cài đặt thông báo trong hồ sơ.',
    );
  }
}
