import 'package:befam/app/app.dart';
import 'package:befam/app/bootstrap/firebase_setup_status.dart';
import 'package:befam/features/auth/services/auth_session_store.dart';
import 'package:befam/features/auth/services/debug_auth_gateway.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final status = FirebaseSetupStatus.ready(
    projectId: 'be-fam-3ab23',
    storageBucket: 'be-fam-3ab23.firebasestorage.app',
    enabledServices: const ['Auth', 'Firestore', 'Storage', 'Messaging'],
    isCrashReportingEnabled: false,
  );

  Future<void> pumpAuthApp(WidgetTester tester, {Locale? locale}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 2000);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      BeFamApp(
        status: status,
        authGateway: DebugAuthGateway(),
        sessionStore: InMemoryAuthSessionStore(),
        locale: locale,
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('supports Vietnamese as the primary locale', (tester) async {
    await pumpAuthApp(tester, locale: const Locale('vi'));

    expect(find.text('Tiếp tục bằng số điện thoại'), findsOneWidget);
    expect(find.text('Tiếp tục bằng mã trẻ em'), findsOneWidget);
    expect(find.textContaining('Môi trường thử nghiệm'), findsOneWidget);
  });

  testWidgets('supports English as the secondary locale', (tester) async {
    await pumpAuthApp(tester, locale: const Locale('en'));

    expect(find.text('Continue with phone'), findsOneWidget);
    expect(find.text('Continue with child ID'), findsOneWidget);
    expect(find.textContaining('Debug auth sandbox'), findsOneWidget);
  });

  testWidgets('completes debug phone login and opens dashboard', (
    tester,
  ) async {
    await pumpAuthApp(tester, locale: const Locale('vi'));

    await tester.tap(find.text('Dùng số điện thoại'));
    await tester.pumpAndSettle();

    final sendOtpButton = find.widgetWithText(FilledButton, 'Gửi OTP');
    await tester.tap(sendOtpButton);
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('otp-code-input')), '123456');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.textContaining('Chào mừng trở lại'), findsOneWidget);
    expect(find.text('Ngữ cảnh đã đăng nhập'), findsOneWidget);
    expect(find.text('Đăng nhập bằng điện thoại'), findsWidgets);
  });

  testWidgets('supports demo child identifier chips for easier local access', (
    tester,
  ) async {
    await pumpAuthApp(tester, locale: const Locale('vi'));

    await tester.tap(find.text('Dùng mã trẻ em'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('BEFAM-CHILD-002'));
    await tester.pump();

    final childField = tester.widget<TextField>(find.byType(TextField).first);
    expect(childField.controller?.text, 'BEFAM-CHILD-002');
  });
}
