import 'dart:async';

import 'package:befam/app/theme/app_theme.dart';
import 'package:befam/core/widgets/app_async_action.dart';
import 'package:befam/core/widgets/app_form_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget testApp(Widget child) {
    return MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: child),
    );
  }

  testWidgets('required field label renders a clear required marker', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        Center(
          child: TextFormField(
            decoration: InputDecoration(
              label: AppRequiredFieldLabel('Tên gia phả'),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Tên gia phả'), findsOneWidget);
    expect(find.byKey(AppRequiredFieldLabel.markerKey), findsOneWidget);
  });

  testWidgets('async action shows loading bar and blocks repeat taps', (
    tester,
  ) async {
    final completer = Completer<void>();
    var submitCount = 0;

    await tester.pumpWidget(
      testApp(
        Center(
          child: AppAsyncAction(
            onPressed: () {
              submitCount += 1;
              return completer.future;
            },
            builder: (context, onPressed, isLoading) {
              return FilledButton(
                key: const Key('submit-button'),
                onPressed: onPressed,
                child: Text(isLoading ? 'Đang lưu' : 'Lưu'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('submit-button')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('submit-button')));
    await tester.pump();

    expect(submitCount, 1);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text('Đang lưu'), findsOneWidget);

    completer.complete();
    await tester.pumpAndSettle();

    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.text('Lưu'), findsOneWidget);
  });
}
