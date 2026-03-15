import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../../core/services/app_logger.dart';
import '../../core/services/crash_reporting_service.dart';
import '../../core/services/firebase_services.dart';
import '../../core/services/performance_measurement_logger.dart';
import '../../firebase_options.dart';
import 'firebase_setup_status.dart';

class AppBootstrapResult {
  const AppBootstrapResult({
    required this.status,
    required this.crashReportingService,
  });

  final FirebaseSetupStatus status;
  final CrashReportingService crashReportingService;
}

class AppBootstrap {
  const AppBootstrap._();

  static final PerformanceMeasurementLogger _performanceLogger =
      PerformanceMeasurementLogger(
        defaultSlowThreshold: const Duration(milliseconds: 2500),
      );

  static Future<AppBootstrapResult> initialize() async {
    return _performanceLogger.measureAsync(
      metric: 'bootstrap.firebase_initialize',
      dimensions: {'release_mode': kReleaseMode ? 1 : 0},
      action: () async {
        AppLogger.info('Starting BeFam bootstrap.');

        try {
          await Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform,
          );

          final crashReportingService = await CrashReportingService.create(
            enableCrashlytics: kReleaseMode,
          );

          final status = FirebaseSetupStatus.ready(
            projectId: Firebase.app().options.projectId,
            storageBucket: Firebase.app().options.storageBucket ?? '',
            enabledServices: FirebaseServices.enabledServiceLabels,
            isCrashReportingEnabled: crashReportingService.isEnabled,
          );

          AppLogger.info('Firebase bootstrap ready for ${status.projectId}.');

          return AppBootstrapResult(
            status: status,
            crashReportingService: crashReportingService,
          );
        } catch (error, stackTrace) {
          AppLogger.error('Firebase bootstrap failed.', error, stackTrace);

          return AppBootstrapResult(
            status: FirebaseSetupStatus.failed(
              projectId: DefaultFirebaseOptions.currentPlatform.projectId,
              storageBucket:
                  DefaultFirebaseOptions.currentPlatform.storageBucket ?? '',
              errorMessage: error.toString(),
            ),
            crashReportingService: const CrashReportingService.disabled(),
          );
        }
      },
    );
  }
}
