import 'package:befam/core/widgets/app_feedback_states.dart';
import 'package:befam/core/widgets/app_loading_skeletons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('AppLoadingState shows message and spinner', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: AppLoadingState(message: 'Loading workspace...')),
      ),
    );

    expect(find.text('Loading workspace...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('AppLoadingState can show retry action without skeleton', (
    tester,
  ) async {
    var retryCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppLoadingState(
            message: 'Still syncing...',
            showSkeleton: false,
            actionLabel: 'Retry',
            onAction: () => retryCount += 1,
          ),
        ),
      ),
    );

    expect(find.text('Still syncing...'), findsOneWidget);
    expect(find.byType(AppSkeletonBox), findsNothing);
    expect(find.text('Retry'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    expect(retryCount, 1);
  });

  testWidgets('AppSkeletonBox respects reduced motion', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Scaffold(body: AppSkeletonBox(height: 24)),
        ),
      ),
    );

    expect(find.byType(AppSkeletonBox), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AppSkeletonBox),
        matching: find.byType(AnimatedBuilder),
      ),
      findsNothing,
    );
  });

  testWidgets('AppInlineProgressIndicator exposes semantic label', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppInlineProgressIndicator(semanticLabel: 'Loading more items'),
        ),
      ),
    );

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label == 'Loading more items',
      ),
      findsOneWidget,
    );
  });
}
