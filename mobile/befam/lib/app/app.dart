import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../features/auth/presentation/auth_experience.dart';
import '../features/auth/services/auth_analytics_service.dart';
import '../features/auth/services/auth_gateway.dart';
import '../features/auth/services/auth_session_store.dart';
import '../features/clan/services/clan_repository.dart';
import '../features/member/services/member_repository.dart';
import '../l10n/generated/app_localizations.dart';
import 'bootstrap/firebase_setup_status.dart';
import 'theme/app_theme.dart';

class BeFamApp extends StatelessWidget {
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
  });

  final FirebaseSetupStatus status;
  final AuthGateway? authGateway;
  final AuthAnalyticsService? authAnalyticsService;
  final AuthSessionStore? sessionStore;
  final ClanRepository? clanRepository;
  final MemberRepository? memberRepository;
  final Locale? locale;

  @override
  Widget build(BuildContext context) {
    final effectiveLocale = locale ?? defaultLocale;

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

        return defaultLocale;
      },
      home: AuthExperience(
        status: status,
        authGateway: authGateway,
        authAnalyticsService: authAnalyticsService,
        sessionStore: sessionStore,
        clanRepository: clanRepository,
        memberRepository: memberRepository,
      ),
    );
  }
}
