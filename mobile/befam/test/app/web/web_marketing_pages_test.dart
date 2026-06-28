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
        GoRoute(
          path: '/privacy',
          builder: (context, state) => const WebPrivacyPolicyPage(),
        ),
        GoRoute(
          path: '/terms',
          builder: (context, state) => const WebTermsPage(),
        ),
        GoRoute(
          path: '/child-safety-standards',
          builder: (context, state) => const WebChildSafetyStandardsPage(),
        ),
        GoRoute(
          path: '/account-deletion',
          builder: (context, state) => const WebAccountDeletionPage(),
        ),
        GoRoute(
          path: '/app',
          builder: (context, state) => const _WebAppEntrySmokePage(),
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

    await pumpWebRouter(tester, initialLocation: '/privacy');
    expect(find.byType(WebPrivacyPolicyPage), findsOneWidget);

    await pumpWebRouter(tester, initialLocation: '/terms');
    expect(find.byType(WebTermsPage), findsOneWidget);

    await pumpWebRouter(tester, initialLocation: '/child-safety-standards');
    expect(find.byType(WebChildSafetyStandardsPage), findsOneWidget);
    expect(find.textContaining('CSAE'), findsWidgets);

    await pumpWebRouter(tester, initialLocation: '/account-deletion');
    expect(find.byType(WebAccountDeletionPage), findsOneWidget);
  });

  testWidgets('public nav stays marketing-only before app entry', (
    tester,
  ) async {
    await pumpWebRouter(tester, initialLocation: '/');

    expect(find.text('TRANG CHỦ'), findsOneWidget);
    expect(find.text('CÂU CHUYỆN'), findsOneWidget);
    expect(find.text('VỀ CHÚNG TÔI'), findsWidgets);
    expect(find.text('GIA PHẢ'), findsNothing);
    expect(find.text('GIỖ LỄ'), findsNothing);
    expect(find.text('QUỸ HỌ'), findsNothing);
    expect(find.text('GÓI DỊCH VỤ'), findsNothing);
    expect(find.text('BẢO MẬT'), findsNothing);

    await tester.tap(find.text('CÂU CHUYỆN'));
    await tester.pumpAndSettle();

    expect(find.byType(WebAboutUsPage), findsOneWidget);
    expect(find.byKey(const Key('web-app-entry-smoke')), findsNothing);

    await tester.tap(find.text('VỀ CHÚNG TÔI'));
    await tester.pumpAndSettle();

    expect(find.byType(WebBeFamInfoPage), findsOneWidget);
    expect(find.byKey(const Key('web-app-entry-smoke')), findsNothing);
  });

  testWidgets('landing primary CTA opens app entry instead of marketing loop', (
    tester,
  ) async {
    await pumpWebRouter(tester, initialLocation: '/');

    await tester.tap(find.text('Mở ứng dụng').first);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('web-app-entry-smoke')), findsOneWidget);
    expect(find.byType(WebLandingPage), findsNothing);
  });

  testWidgets('keeps public marketing content and footer store links visible', (
    tester,
  ) async {
    await pumpWebRouter(tester, initialLocation: '/');

    expect(find.text('Quỹ họ'), findsWidgets);
    expect(find.text('Gói dịch vụ'), findsWidgets);
    expect(find.text('Mua và nâng cấp trong app.'), findsOneWidget);
    expect(find.text('iOS'), findsOneWidget);
    expect(find.text('Android'), findsOneWidget);
    expect(find.text('Quỹ và quyền dùng'), findsNothing);

    await pumpWebRouter(tester, initialLocation: '/befam-info');

    expect(find.text('VỀ CHÚNG TÔI'), findsWidgets);
    expect(
      find.text('BeFam được làm cho những dòng họ cần rõ người, rõ việc.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('web-app-entry-smoke')), findsNothing);
  });

  testWidgets('landing primary CTA opens app entry instead of marketing loop', (
    tester,
  ) async {
    await pumpWebRouter(tester, initialLocation: '/');

    await tester.tap(find.text('Mở ứng dụng').first);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('web-app-entry-smoke')), findsOneWidget);
    expect(find.byType(WebLandingPage), findsNothing);
  });

  testWidgets('separates clan funds from service plans across web pages', (
    tester,
  ) async {
    await pumpWebRouter(tester, initialLocation: '/');

    expect(find.text('Quỹ họ'), findsWidgets);
    expect(find.text('Gói dịch vụ'), findsWidgets);
    expect(find.text('Mua và nâng cấp trong app.'), findsOneWidget);
    expect(find.text('Quỹ và quyền dùng'), findsNothing);

    await pumpWebRouter(tester, initialLocation: '/befam-info');

    expect(find.text('Quỹ họ'), findsWidgets);
    expect(find.text('Gói dịch vụ'), findsNothing);
    expect(find.text('Quỹ và quyền dùng'), findsNothing);
    expect(find.text('Dành cho ban điều hành họ tộc'), findsOneWidget);
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

  testWidgets('keeps mobile header branded with a clear app CTA', (
    tester,
  ) async {
    await pumpWebRouter(
      tester,
      initialLocation: '/',
      viewportSize: const Size(390, 844),
    );

    expect(find.byKey(const Key('web-marketing-brand-name')), findsOneWidget);
    expect(find.byKey(const Key('web-marketing-top-open-app')), findsOneWidget);
    expect(
      find.byWidgetPredicate((widget) => widget is PopupMenuButton),
      findsNothing,
    );
  });
}

class _WebAppEntrySmokePage extends StatelessWidget {
  const _WebAppEntrySmokePage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('App entry', key: Key('web-app-entry-smoke'))),
    );
  }
}
