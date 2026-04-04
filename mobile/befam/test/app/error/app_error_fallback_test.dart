import 'package:befam/app/error/app_error_fallback.dart';
import 'package:befam/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders a friendly fallback card with recovery action', (
    tester,
  ) async {
    final details = FlutterErrorDetails(
      exception: StateError('Render failed'),
      stack: StackTrace.current,
    );

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(body: AppErrorFallback(details: details)),
      ),
    );

    expect(find.text('Something went wrong'), findsOneWidget);
    expect(
      find.textContaining('return to Home and continue using the app'),
      findsOneWidget,
    );
    expect(find.widgetWithText(FilledButton, 'Back to home'), findsOneWidget);
  });

  testWidgets('installAppErrorFallback registers AppErrorFallback builder', (
    tester,
  ) async {
    final previousBuilder = ErrorWidget.builder;

    installAppErrorFallback();

    final built = ErrorWidget.builder(
      FlutterErrorDetails(exception: Exception('boom')),
    );

    expect(built, isA<AppErrorFallback>());
    ErrorWidget.builder = previousBuilder;
  });
}
