import 'package:flutter_test/flutter_test.dart';

import 'package:befam/app/app.dart';

void main() {
  testWidgets('renders Firebase-ready setup state', (
    WidgetTester tester,
  ) async {
    final status = FirebaseSetupStatus.ready(
      projectId: 'be-fam-3ab23',
      storageBucket: 'be-fam-3ab23.firebasestorage.app',
      enabledServices: const ['Auth', 'Firestore', 'Storage', 'Messaging'],
    );

    await tester.pumpWidget(BeFamApp(status: status));

    expect(find.text('BeFam Firebase Ready'), findsOneWidget);
    expect(find.text('be-fam-3ab23'), findsOneWidget);
    expect(
      find.textContaining('Auth, Firestore, Storage, Messaging'),
      findsOneWidget,
    );
  });
}
