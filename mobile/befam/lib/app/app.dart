import 'package:flutter/material.dart';

import 'bootstrap/firebase_setup_status.dart';
import 'home/app_shell_page.dart';
import 'theme/app_theme.dart';

class BeFamApp extends StatelessWidget {
  const BeFamApp({super.key, required this.status});

  final FirebaseSetupStatus status;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BeFam',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: AppShellPage(status: status),
    );
  }
}
