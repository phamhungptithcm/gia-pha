import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../e2e_test_harness.dart';

class AuthPageObject {
  const AuthPageObject(this.tester);

  final WidgetTester tester;

  Future<void> verifyPrivacyGateBlocksLoginUntilAccepted() async {
    final phoneButton = find.widgetWithText(FilledButton, 'Dùng số điện thoại');
    final childButton = find.widgetWithText(OutlinedButton, 'Dùng mã trẻ em');
    await waitForFinder(
      tester,
      phoneButton,
      reason: 'Không thấy nút đăng nhập số điện thoại.',
    );
    await waitForFinder(
      tester,
      childButton,
      reason: 'Không thấy nút đăng nhập mã trẻ em.',
    );

    expect(tester.widget<FilledButton>(phoneButton).enabled, isFalse);
    expect(tester.widget<OutlinedButton>(childButton).enabled, isFalse);
  }

  Future<void> loginByPhone(String phoneInput) async {
    await loginWithPhone(tester, phoneInput: phoneInput);
  }

  Future<void> loginByChildCode(String childCode) async {
    await loginWithChildCode(tester, childCode: childCode);
  }
}
