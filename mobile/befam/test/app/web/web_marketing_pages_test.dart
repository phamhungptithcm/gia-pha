import 'package:befam/app/web/web_marketing_pages.dart';
import 'package:befam/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  Future<void> pumpWebRouter(
    WidgetTester tester, {
    required String initialLocation,
    Size viewportSize = const Size(1280, 1800),
  }) async {
    tester.view.devicePixelRatio = 1;
    await tester.binding.setSurfaceSize(viewportSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final router = GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(path: '/', builder: (context, state) => const WebLandingPage()),
        GoRoute(
          path: '/about-us',
          builder: (context, state) => const WebAboutUsPage(),
        ),
        GoRoute(
          path: '/befam-info',
          builder: (context, state) => const WebBeFamInfoPage(),
        ),
      ],
      errorBuilder: (context, state) => const WebLandingPage(),
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MaterialApp.router(
        locale: const Locale('vi'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('routes to web pages correctly', (tester) async {
    await pumpWebRouter(tester, initialLocation: '/');
    expect(find.byType(WebLandingPage), findsOneWidget);

    await pumpWebRouter(tester, initialLocation: '/about-us');
    expect(find.byType(WebAboutUsPage), findsOneWidget);

    await pumpWebRouter(tester, initialLocation: '/befam-info');
    expect(find.byType(WebBeFamInfoPage), findsOneWidget);
  });

  testWidgets('navigates from landing CTA to about page', (tester) async {
    await pumpWebRouter(tester, initialLocation: '/');

    await tester.tap(find.byType(OutlinedButton).first);
    await tester.pumpAndSettle();

    expect(find.byType(WebAboutUsPage), findsOneWidget);
  });

  testWidgets('shows compact navigation on narrow width', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('vi'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const MediaQuery(
          data: MediaQueryData(size: Size(640, 1800)),
          child: WebLandingPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byWidgetPredicate((widget) => widget is PopupMenuButton),
      findsOneWidget,
    );
  });
}
