import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../e2e_test_harness.dart';

class AuthPageObject {
  const AuthPageObject(this.tester);

  final WidgetTester tester;

  Future<void> verifyPrivacyGateBlocksLoginUntilAccepted() async {
    final phoneButton = find.byKey(const Key('auth-method-phone-button'));
    final childButton = find.byKey(const Key('auth-method-child-button'));
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

    final phoneWidget = tester.widget(phoneButton.first);
    final childWidget = tester.widget(childButton.first);
    expect(
      phoneWidget is FilledButton && phoneWidget.onPressed == null,
      isTrue,
      reason: 'Nút số điện thoại phải bị khóa khi chưa đồng ý chính sách.',
    );
    expect(
      childWidget is OutlinedButton && childWidget.onPressed == null,
      isTrue,
      reason: 'Nút mã trẻ em phải bị khóa khi chưa đồng ý chính sách.',
    );
  }

  Future<void> loginByPhone(String phoneInput) async {
    await loginWithPhone(tester, phoneInput: phoneInput);
  }

  Future<void> loginByChildCode(String childCode) async {
    await loginWithChildCode(tester, childCode: childCode);
  }
}
