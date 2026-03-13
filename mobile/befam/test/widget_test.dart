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

  Future<void> pumpAuthApp(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 2000);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      BeFamApp(
        status: status,
        authGateway: DebugAuthGateway(),
        sessionStore: InMemoryAuthSessionStore(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows authentication entry options first', (tester) async {
    await pumpAuthApp(tester);

    expect(find.text('Continue with phone'), findsOneWidget);
    expect(find.text('Continue with child ID'), findsOneWidget);
    expect(find.textContaining('Debug auth sandbox'), findsOneWidget);
  });

  testWidgets('completes debug phone login and opens dashboard', (
    tester,
  ) async {
    await pumpAuthApp(tester);

    await tester.tap(find.text('Use phone number'));
    await tester.pumpAndSettle();

    final sendOtpButton = find.widgetWithText(FilledButton, 'Send OTP');
    await tester.tap(sendOtpButton);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '123456');
    final verifyButton = find.widgetWithText(
      FilledButton,
      'Verify and continue',
    );
    await tester.tap(verifyButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.textContaining('Welcome back'), findsOneWidget);
    expect(find.text('Signed-in context'), findsOneWidget);
    expect(find.text('Phone login'), findsWidgets);
  });
}
