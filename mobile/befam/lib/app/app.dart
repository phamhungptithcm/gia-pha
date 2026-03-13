import 'package:flutter/material.dart';

import '../features/auth/presentation/auth_experience.dart';
import '../features/auth/services/auth_gateway.dart';
import '../features/auth/services/auth_session_store.dart';
import 'bootstrap/firebase_setup_status.dart';
import 'theme/app_theme.dart';

class BeFamApp extends StatelessWidget {
  const BeFamApp({
    super.key,
    required this.status,
    this.authGateway,
    this.sessionStore,
  });

  final FirebaseSetupStatus status;
  final AuthGateway? authGateway;
  final AuthSessionStore? sessionStore;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BeFam',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: AuthExperience(
        status: status,
        authGateway: authGateway,
        sessionStore: sessionStore,
      ),
    );
  }
}
