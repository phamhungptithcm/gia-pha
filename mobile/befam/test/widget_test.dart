import 'package:befam/app/app.dart';
import 'package:befam/app/bootstrap/firebase_setup_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders project bootstrap dashboard', (tester) async {
    final status = FirebaseSetupStatus.ready(
      projectId: 'be-fam-3ab23',
      storageBucket: 'be-fam-3ab23.firebasestorage.app',
      enabledServices: const ['Auth', 'Firestore', 'Storage', 'Messaging'],
      isCrashReportingEnabled: false,
    );

    await tester.pumpWidget(BeFamApp(status: status));
    await tester.pumpAndSettle();

    expect(
      find.text('BeFam project bootstrap is ready for feature delivery.'),
      findsOneWidget,
    );
    expect(find.text('Priority workspaces'), findsOneWidget);
    expect(find.text('Family Tree'), findsOneWidget);
    expect(find.text('Members'), findsOneWidget);
    expect(find.text('Firebase ready'), findsOneWidget);
  });
}
