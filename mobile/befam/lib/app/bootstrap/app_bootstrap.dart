import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

import '../../core/services/app_logger.dart';
import '../../core/services/app_environment.dart';
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
          await _activateAppCheck();

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
          final fallbackOptions = _resolveFallbackOptions();

          return AppBootstrapResult(
            status: FirebaseSetupStatus.failed(
              projectId: fallbackOptions.projectId,
              storageBucket: fallbackOptions.storageBucket ?? '',
              errorMessage: error.toString(),
            ),
            crashReportingService: const CrashReportingService.disabled(),
          );
        }
      },
    );
  }

  static FirebaseOptions _resolveFallbackOptions() {
    try {
      return DefaultFirebaseOptions.currentPlatform;
    } catch (_) {
      return DefaultFirebaseOptions.android;
    }
  }

  static Future<void> _activateAppCheck() async {
    if (!AppEnvironment.enableAppCheck) {
      AppLogger.info(
        'Firebase App Check is disabled by BEFAM_ENABLE_APP_CHECK.',
      );
      return;
    }

    if (kIsWeb) {
      final siteKey = AppEnvironment.appCheckWebRecaptchaSiteKey.trim();
      if (siteKey.isEmpty) {
        AppLogger.warning(
          'Firebase App Check was skipped on web because BEFAM_APP_CHECK_WEB_RECAPTCHA_SITE_KEY is empty.',
        );
        return;
      }
      await FirebaseAppCheck.instance.activate(
        providerWeb: ReCaptchaV3Provider(siteKey),
      );
      AppLogger.info('Firebase App Check activated for web.');
      return;
    }

    await FirebaseAppCheck.instance.activate(
      providerAndroid: kReleaseMode
          ? const AndroidPlayIntegrityProvider()
          : const AndroidDebugProvider(),
      providerApple: kReleaseMode
          ? const AppleAppAttestWithDeviceCheckFallbackProvider()
          : const AppleDebugProvider(),
    );
    AppLogger.info(
      'Firebase App Check activated (${kReleaseMode ? 'production' : 'debug'} provider).',
    );
  }
}
