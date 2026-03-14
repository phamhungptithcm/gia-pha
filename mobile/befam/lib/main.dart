import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import 'app/app.dart';
import 'app/bootstrap/app_bootstrap.dart';
import 'core/services/crash_reporting_service.dart';

Future<void> main() async {
  var crashReportingService = const CrashReportingService.disabled();

  await runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        unawaited(crashReportingService.recordFlutterError(details));
      };

      PlatformDispatcher.instance.onError = (error, stackTrace) {
        unawaited(
          crashReportingService.recordError(
            error,
            stackTrace,
            reason: 'Platform dispatcher error',
            fatal: true,
          ),
        );
        return true;
      };

      final bootstrap = await AppBootstrap.initialize();
      crashReportingService = bootstrap.crashReportingService;
      runApp(BeFamApp(status: bootstrap.status));
    },
    (error, stackTrace) async {
      await crashReportingService.recordError(
        error,
        stackTrace,
        reason: 'Uncaught zone error',
        fatal: true,
      );
    },
  );
}
