import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/services/app_locale_controller.dart';
import '../core/services/app_locale_store.dart';
import '../features/auth/presentation/auth_experience.dart';
import '../features/auth/services/auth_analytics_service.dart';
import '../features/auth/services/auth_gateway.dart';
import '../features/auth/services/auth_session_store.dart';
import '../features/clan/services/clan_repository.dart';
import '../features/member/services/member_repository.dart';
import '../l10n/generated/app_localizations.dart';
import 'bootstrap/firebase_setup_status.dart';
import 'theme/app_theme.dart';

class BeFamApp extends StatefulWidget {
  static const defaultLocale = Locale('vi');

  const BeFamApp({
    super.key,
    required this.status,
    this.authGateway,
    this.authAnalyticsService,
    this.sessionStore,
    this.clanRepository,
    this.memberRepository,
    this.locale,
    this.localeStore,
    this.localeController,
  });

  final FirebaseSetupStatus status;
  final AuthGateway? authGateway;
  final AuthAnalyticsService? authAnalyticsService;
  final AuthSessionStore? sessionStore;
  final ClanRepository? clanRepository;
  final MemberRepository? memberRepository;
  final Locale? locale;
  final AppLocaleStore? localeStore;
  final AppLocaleController? localeController;

  @override
  State<BeFamApp> createState() => _BeFamAppState();
}

class _BeFamAppState extends State<BeFamApp> {
  late final AppLocaleController _localeController;
  late final bool _ownsLocaleController;

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
  }

  @override
  void dispose() {
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
      home: AuthExperience(
        status: widget.status,
        authGateway: widget.authGateway,
        authAnalyticsService: widget.authAnalyticsService,
        sessionStore: widget.sessionStore,
        clanRepository: widget.clanRepository,
        memberRepository: widget.memberRepository,
        localeController: _localeController,
      ),
    );
  }
}
