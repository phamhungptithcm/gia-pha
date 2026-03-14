import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';

import 'app_logger.dart';

class CrashReportingService {
  const CrashReportingService._({required this.isEnabled});

  const CrashReportingService.disabled() : this._(isEnabled: false);

  final bool isEnabled;

  static Future<CrashReportingService> create({
    required bool enableCrashlytics,
  }) async {
    if (!enableCrashlytics) {
      AppLogger.info(
        'Crashlytics collection is disabled outside release builds.',
      );
      return const CrashReportingService.disabled();
    }

    try {
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
      AppLogger.info('Crashlytics collection enabled.');
      return const CrashReportingService._(isEnabled: true);
    } catch (error, stackTrace) {
      AppLogger.warning(
        'Crashlytics setup failed. Falling back to local logging only.',
        error,
        stackTrace,
      );
      return const CrashReportingService.disabled();
    }
  }

  Future<void> recordFlutterError(FlutterErrorDetails details) async {
    AppLogger.error(
      'Flutter framework error.',
      details.exception,
      details.stack,
    );

    if (!isEnabled) {
      return;
    }

    await FirebaseCrashlytics.instance.recordFlutterFatalError(details);
  }

  Future<void> recordError(
    Object error,
    StackTrace stackTrace, {
    required String reason,
    bool fatal = false,
  }) async {
    AppLogger.error(reason, error, stackTrace);

    if (!isEnabled) {
      return;
    }

    await FirebaseCrashlytics.instance.recordError(
      error,
      stackTrace,
      reason: reason,
      fatal: fatal,
    );
  }
}
