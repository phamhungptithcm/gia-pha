import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../features/auth/presentation/auth_experience.dart';
import '../features/auth/services/auth_gateway.dart';
import '../features/auth/services/auth_session_store.dart';
import '../l10n/generated/app_localizations.dart';
import 'bootstrap/firebase_setup_status.dart';
import 'theme/app_theme.dart';

class BeFamApp extends StatelessWidget {
  static const defaultLocale = Locale('vi');

  const BeFamApp({
    super.key,
    required this.status,
    this.authGateway,
    this.sessionStore,
    this.locale,
  });

  final FirebaseSetupStatus status;
  final AuthGateway? authGateway;
  final AuthSessionStore? sessionStore;
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
        sessionStore: sessionStore,
      ),
    );
  }
}
