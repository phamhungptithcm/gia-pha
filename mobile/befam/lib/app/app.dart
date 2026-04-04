import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

import '../core/services/app_locale_controller.dart';
import '../core/services/app_locale_store.dart';
import '../features/auth/presentation/auth_experience.dart';
import '../features/auth/services/auth_analytics_service.dart';
import '../features/auth/services/auth_gateway.dart';
import '../features/auth/services/clan_context_service.dart';
import '../features/auth/services/auth_session_store.dart';
import '../features/billing/services/billing_repository.dart';
import '../features/clan/services/clan_repository.dart';
import '../features/discovery/services/genealogy_discovery_repository.dart';
import '../features/events/services/event_repository.dart';
import '../features/funds/services/fund_repository.dart';
import '../features/genealogy/services/genealogy_read_repository.dart';
import '../features/member/services/member_repository.dart';
import '../features/notifications/services/push_notification_service.dart';
import '../features/profile/services/profile_notification_preferences_repository.dart';
import '../features/scholarship/services/scholarship_repository.dart';
import '../l10n/generated/app_localizations.dart';
import 'bootstrap/firebase_setup_status.dart';
import 'theme/app_theme.dart';
import 'web/web_marketing_pages.dart';

class BeFamApp extends StatefulWidget {
  static const defaultLocale = Locale('vi');

  const BeFamApp({
    super.key,
    required this.status,
    this.authGateway,
    this.authAnalyticsService,
    this.sessionStore,
    this.clanContextService,
    this.clanRepository,
    this.memberRepository,
    this.eventRepository,
    this.fundRepository,
    this.genealogyRepository,
    this.genealogyDiscoveryRepository,
    this.billingRepository,
    this.scholarshipRepository,
    this.pushNotificationService,
    this.profileNotificationPreferencesRepository,
    this.locale,
    this.localeStore,
    this.localeController,
  });

  final FirebaseSetupStatus status;
  final AuthGateway? authGateway;
  final AuthAnalyticsService? authAnalyticsService;
  final AuthSessionStore? sessionStore;
  final ClanContextService? clanContextService;
  final ClanRepository? clanRepository;
  final MemberRepository? memberRepository;
  final EventRepository? eventRepository;
  final FundRepository? fundRepository;
  final GenealogyReadRepository? genealogyRepository;
  final GenealogyDiscoveryRepository? genealogyDiscoveryRepository;
  final BillingRepository? billingRepository;
  final ScholarshipRepository? scholarshipRepository;
  final PushNotificationService? pushNotificationService;
  final ProfileNotificationPreferencesRepository?
  profileNotificationPreferencesRepository;
  final Locale? locale;
  final AppLocaleStore? localeStore;
  final AppLocaleController? localeController;

  @override
  State<BeFamApp> createState() => _BeFamAppState();
}

class _BeFamAppState extends State<BeFamApp> {
  late final AppLocaleController _localeController;
  late final bool _ownsLocaleController;
  GoRouter? _webRouter;

  @override
  void initState() {
    super.initState();
    _localeController =
        widget.localeController ??
        AppLocaleController(
          store: widget.localeStore,
          defaultLocale: BeFamApp.defaultLocale,
        );
    _ownsLocaleController = widget.localeController == null;
    _localeController.addListener(_handleLocaleChanged);
    unawaited(_localeController.load());
    if (kIsWeb) {
      _webRouter = _buildWebRouter();
    }
  }

  @override
  void dispose() {
    _webRouter?.dispose();
    _localeController.removeListener(_handleLocaleChanged);
    if (_ownsLocaleController) {
      _localeController.dispose();
    }
    super.dispose();
  }

  void _handleLocaleChanged() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final effectiveLocale = widget.locale ?? _localeController.locale;
    final authExperience = _buildAuthExperience();

    if (kIsWeb) {
      return MaterialApp.router(
        onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        locale: effectiveLocale,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        localeResolutionCallback: (deviceLocale, supportedLocales) {
          for (final supportedLocale in supportedLocales) {
            if (supportedLocale.languageCode == effectiveLocale.languageCode) {
              return supportedLocale;
            }
          }

          return BeFamApp.defaultLocale;
        },
        routerConfig: _webRouter!,
      );
    }

    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      locale: effectiveLocale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      localeResolutionCallback: (deviceLocale, supportedLocales) {
        for (final supportedLocale in supportedLocales) {
          if (supportedLocale.languageCode == effectiveLocale.languageCode) {
            return supportedLocale;
          }
        }

        return BeFamApp.defaultLocale;
      },
      home: authExperience,
    );
  }

  AuthExperience _buildAuthExperience() {
    return AuthExperience(
      status: widget.status,
      authGateway: widget.authGateway,
      authAnalyticsService: widget.authAnalyticsService,
      sessionStore: widget.sessionStore,
      clanContextService: widget.clanContextService,
      clanRepository: widget.clanRepository,
      memberRepository: widget.memberRepository,
      eventRepository: widget.eventRepository,
      fundRepository: widget.fundRepository,
      genealogyRepository: widget.genealogyRepository,
      genealogyDiscoveryRepository: widget.genealogyDiscoveryRepository,
      billingRepository: widget.billingRepository,
      scholarshipRepository: widget.scholarshipRepository,
      pushNotificationService: widget.pushNotificationService,
      profileNotificationPreferencesRepository:
          widget.profileNotificationPreferencesRepository,
      localeController: _localeController,
    );
  }

  GoRouter _buildWebRouter() {
    return GoRouter(
      initialLocation: '/',
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
          path: '/app',
          builder: (context, state) => _buildAuthExperience(),
        ),
      ],
      errorBuilder: (context, state) => const WebLandingPage(),
    );
  }
}
