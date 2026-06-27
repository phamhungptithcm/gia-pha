import 'package:befam/app/home/app_shell_page.dart';
import 'package:befam/main.dart' as app;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'web_live_smoke_base_href_stub.dart'
    if (dart.library.html) 'web_live_smoke_base_href_web.dart';

const bool runLiveWebSmoke = bool.fromEnvironment(
  'BEFAM_E2E_RUN_LIVE',
  defaultValue: false,
);
const String liveTestPhone = String.fromEnvironment('BEFAM_E2E_TEST_PHONE');
const String liveTestOtp = String.fromEnvironment('BEFAM_E2E_TEST_OTP');

void main() {
  testWidgets(
    'Website live smoke: landing to OTP login reaches app shell',
    (tester) async {
      if (liveTestPhone.trim().isEmpty || liveTestOtp.trim().isEmpty) {
        fail(
          'Missing live web smoke phone/OTP dart-defines. '
          'Use staging-only QA values; do not commit them.',
        );
      }

      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1200, 900);
      tester.binding.platformDispatcher.textScaleFactorTestValue = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(
        tester.binding.platformDispatcher.clearTextScaleFactorTestValue,
      );

      ensureWebTestBaseHref();
      if (_hasPreloadedFlutterTestFirebaseApp()) {
        markTestSkipped(
          'Flutter web test runner preloads a synthetic Firebase app. '
          'Run this flow against a served staging build with browser automation.',
        );
        return;
      }

      await app.main();
      await _safePumpAndSettle(tester);

      await _enterAppFromLandingIfNeeded(tester);
      await _acceptPrivacyPolicy(tester);
      await _loginByPhone(tester);

      await _waitFor(
        tester,
        reason: 'Live web smoke did not reach AppShell after OTP verify.',
        condition: () => find.byType(AppShellPage).evaluate().isNotEmpty,
      );
      expect(find.byType(AppShellPage), findsOneWidget);
    },
    skip: !runLiveWebSmoke,
  );
}

bool _hasPreloadedFlutterTestFirebaseApp() {
  return Firebase.apps.any((app) => app.options.projectId == '123');
}

Future<void> _enterAppFromLandingIfNeeded(WidgetTester tester) async {
  final phoneButton = find.byKey(const Key('auth-method-phone-button'));
  if (phoneButton.evaluate().isNotEmpty) {
    return;
  }

  final openAppButton = find.byKey(const Key('web-marketing-top-open-app'));
  await _waitForFinder(
    tester,
    openAppButton,
    reason: 'Website landing did not render the app entry CTA.',
  );
  await tester.tap(openAppButton.first);
  await _safePumpAndSettle(tester);
  await _waitForFinder(
    tester,
    phoneButton,
    reason: 'The app entry route did not render the auth method selector.',
  );
}

Future<void> _acceptPrivacyPolicy(WidgetTester tester) async {
  final checkboxFinder = find.byKey(const Key('auth-privacy-checkbox'));
  await _waitForFinder(
    tester,
    checkboxFinder,
    reason: 'Privacy policy consent checkbox is missing.',
  );

  final checkbox = tester.widget<Checkbox>(checkboxFinder.first);
  if (checkbox.value == true) {
    return;
  }

  await tester.ensureVisible(checkboxFinder.first);
  await tester.tap(checkboxFinder.first);
  await _safePumpAndSettle(tester);
  await _waitFor(
    tester,
    reason: 'Privacy policy consent did not unlock the phone login option.',
    condition: () {
      final phoneButton = find.byKey(const Key('auth-method-phone-button'));
      return phoneButton.evaluate().isNotEmpty &&
          _isFinderEnabledButton(tester, phoneButton);
    },
  );
}

Future<void> _loginByPhone(WidgetTester tester) async {
  final phoneMethodFinder = find.byKey(const Key('auth-method-phone-button'));
  await _waitFor(
    tester,
    reason: 'Phone login option stayed disabled.',
    condition: () => _isFinderEnabledButton(tester, phoneMethodFinder),
  );
  await tester.tap(phoneMethodFinder.first);
  await _safePumpAndSettle(tester);

  final phoneInputFinder = find.byKey(const Key('auth-phone-input'));
  await _waitForFinder(
    tester,
    phoneInputFinder,
    reason: 'Phone input field is missing.',
  );
  await tester.enterText(phoneInputFinder.first, liveTestPhone);
  await _safePumpAndSettle(tester);
  await _dismissKeyboard(tester);

  final sendOtpButton = find.byKey(const Key('auth-send-otp-button'));
  await _waitFor(
    tester,
    reason: 'Send OTP button did not become available.',
    condition: () =>
        _isOtpOrShellVisible(tester) ||
        _isFinderEnabledButton(tester, sendOtpButton),
  );
  if (!_isOtpOrShellVisible(tester)) {
    await tester.ensureVisible(sendOtpButton.first);
    await tester.tap(sendOtpButton.first);
    await _safePumpAndSettle(tester);
  }

  final otpInputFinder = find.byKey(const Key('otp-code-input'));
  await _waitFor(
    tester,
    reason: 'OTP screen did not appear after requesting OTP.',
    condition: () =>
        _isOtpOrShellVisible(tester) || otpInputFinder.evaluate().isNotEmpty,
  );
  if (otpInputFinder.evaluate().isNotEmpty) {
    await tester.enterText(otpInputFinder.first, liveTestOtp);
    await tester.pump(const Duration(milliseconds: 700));
    await _safePumpAndSettle(tester);
  }
}

Future<void> _safePumpAndSettle(WidgetTester tester) async {
  try {
    await tester.pumpAndSettle(const Duration(milliseconds: 16));
    return;
  } catch (error) {
    if (!error.toString().contains('pumpAndSettle timed out')) {
      rethrow;
    }
  }
  for (var frame = 0; frame < 300; frame += 1) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Future<void> _waitForFinder(
  WidgetTester tester,
  Finder finder, {
  required String reason,
}) async {
  await _waitFor(
    tester,
    reason: reason,
    condition: () => finder.evaluate().isNotEmpty,
  );
}

Future<void> _waitFor(
  WidgetTester tester, {
  required bool Function() condition,
  required String reason,
  int maxFrames = 500,
}) async {
  for (var frame = 0; frame < maxFrames; frame += 1) {
    if (condition()) {
      return;
    }
    await tester.pump(const Duration(milliseconds: 16));
  }
  expect(condition(), isTrue, reason: reason);
}

Future<void> _dismissKeyboard(WidgetTester tester) async {
  FocusManager.instance.primaryFocus?.unfocus();
  try {
    tester.testTextInput.hide();
  } catch (_) {
    // Web browser runs may not have a platform text input channel attached.
  }
  await tester.pump(const Duration(milliseconds: 120));
}

bool _isOtpOrShellVisible(WidgetTester tester) {
  return find.byKey(const Key('otp-code-input')).evaluate().isNotEmpty ||
      find.byType(AppShellPage).evaluate().isNotEmpty;
}

bool _isFinderEnabledButton(WidgetTester tester, Finder finder) {
  if (finder.evaluate().isEmpty) {
    return false;
  }
  final widget = tester.widget(finder.first);
  return switch (widget) {
    FilledButton(:final onPressed) => onPressed != null,
    OutlinedButton(:final onPressed) => onPressed != null,
    ElevatedButton(:final onPressed) => onPressed != null,
    TextButton(:final onPressed) => onPressed != null,
    _ => true,
  };
}
