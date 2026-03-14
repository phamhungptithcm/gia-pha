import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../features/auth/presentation/auth_experience.dart';
import '../features/auth/services/auth_gateway.dart';
import '../features/auth/services/auth_session_store.dart';
import '../l10n/generated/app_localizations.dart';
import 'bootstrap/firebase_setup_status.dart';
import 'theme/app_theme.dart';

class BeFamApp extends StatelessWidget {
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
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      localeResolutionCallback: (deviceLocale, supportedLocales) {
        if (locale != null) {
          return locale;
        }

        if (deviceLocale == null) {
          return const Locale('vi');
        }

        for (final supportedLocale in supportedLocales) {
          if (supportedLocale.languageCode == deviceLocale.languageCode) {
            return supportedLocale;
          }
        }

        return const Locale('vi');
      },
      home: AuthExperience(
        status: status,
        authGateway: authGateway,
        sessionStore: sessionStore,
      ),
    );
  }
}
