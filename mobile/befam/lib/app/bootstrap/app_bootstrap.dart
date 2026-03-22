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
          final options = _resolveFirebaseOptions();
          await Firebase.initializeApp(options: options);
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
          final fallbackIdentity = _resolveFallbackIdentity();

          return AppBootstrapResult(
            status: FirebaseSetupStatus.failed(
              projectId: fallbackIdentity.projectId,
              storageBucket: fallbackIdentity.storageBucket,
              errorMessage: error.toString(),
            ),
            crashReportingService: const CrashReportingService.disabled(),
          );
        }
      },
    );
  }

  static FirebaseOptions _resolveFirebaseOptions() {
    final optionsFromEnvironment = _resolveFirebaseOptionsFromEnvironment();
    if (optionsFromEnvironment != null) {
      AppLogger.info(
        'Firebase options loaded from BEFAM_FIREBASE_* dart-defines.',
      );
      return optionsFromEnvironment;
    }

    if (AppEnvironment.allowBundledFirebaseOptions) {
      AppLogger.warning(
        'Using bundled Firebase options because BEFAM_ALLOW_BUNDLED_FIREBASE_OPTIONS=true.',
      );
      return DefaultFirebaseOptions.currentPlatform;
    }

    throw StateError(
      'Firebase is not configured. Provide BEFAM_FIREBASE_* dart-defines '
      'or set BEFAM_ALLOW_BUNDLED_FIREBASE_OPTIONS=true for local/testing builds.',
    );
  }

  static FirebaseOptions? _resolveFirebaseOptionsFromEnvironment() {
    final projectId = AppEnvironment.firebaseProjectId.trim();
    if (projectId.isEmpty) {
      return null;
    }

    final storageBucket = AppEnvironment.firebaseStorageBucket.trim();

    if (kIsWeb) {
      final apiKey = AppEnvironment.firebaseWebApiKey.trim();
      final appId = AppEnvironment.firebaseWebAppId.trim();
      final messagingSenderId = AppEnvironment.firebaseWebMessagingSenderId
          .trim();
      if (apiKey.isEmpty || appId.isEmpty || messagingSenderId.isEmpty) {
        return null;
      }

      final authDomain = AppEnvironment.firebaseWebAuthDomain.trim();
      final measurementId = AppEnvironment.firebaseWebMeasurementId.trim();
      return FirebaseOptions(
        apiKey: apiKey,
        appId: appId,
        messagingSenderId: messagingSenderId,
        projectId: projectId,
        storageBucket: storageBucket.isEmpty ? null : storageBucket,
        authDomain: authDomain.isEmpty ? null : authDomain,
        measurementId: measurementId.isEmpty ? null : measurementId,
      );
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        final apiKey = AppEnvironment.firebaseAndroidApiKey.trim();
        final appId = AppEnvironment.firebaseAndroidAppId.trim();
        final messagingSenderId = AppEnvironment
            .firebaseAndroidMessagingSenderId
            .trim();
        if (apiKey.isEmpty || appId.isEmpty || messagingSenderId.isEmpty) {
          return null;
        }
        return FirebaseOptions(
          apiKey: apiKey,
          appId: appId,
          messagingSenderId: messagingSenderId,
          projectId: projectId,
          storageBucket: storageBucket.isEmpty ? null : storageBucket,
        );
      case TargetPlatform.iOS:
        final apiKey = AppEnvironment.firebaseIosApiKey.trim();
        final appId = AppEnvironment.firebaseIosAppId.trim();
        final messagingSenderId = AppEnvironment.firebaseIosMessagingSenderId
            .trim();
        if (apiKey.isEmpty || appId.isEmpty || messagingSenderId.isEmpty) {
          return null;
        }
        final bundleId = AppEnvironment.firebaseIosBundleId.trim();
        return FirebaseOptions(
          apiKey: apiKey,
          appId: appId,
          messagingSenderId: messagingSenderId,
          projectId: projectId,
          storageBucket: storageBucket.isEmpty ? null : storageBucket,
          iosBundleId: bundleId.isEmpty ? null : bundleId,
        );
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        return null;
    }
  }

  static ({String projectId, String storageBucket}) _resolveFallbackIdentity() {
    final projectId = AppEnvironment.firebaseProjectId.trim();
    final storageBucket = AppEnvironment.firebaseStorageBucket.trim();
    if (projectId.isNotEmpty) {
      return (projectId: projectId, storageBucket: storageBucket);
    }

    if (AppEnvironment.allowBundledFirebaseOptions) {
      try {
        final options = DefaultFirebaseOptions.currentPlatform;
        return (
          projectId: options.projectId,
          storageBucket: options.storageBucket ?? '',
        );
      } catch (_) {
        // Ignore and return a neutral placeholder below.
      }
    }

    return (projectId: 'unconfigured', storageBucket: '');
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

    try {
      await FirebaseAppCheck.instance.activate(
        providerAndroid: kReleaseMode
            ? const AndroidPlayIntegrityProvider()
            : const AndroidDebugProvider(),
        providerApple: kReleaseMode
            ? const AppleAppAttestWithDeviceCheckFallbackProvider()
            : const AppleDebugProvider(),
      ).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          AppLogger.warning('Firebase App Check activation timed out. Continuing without App Check.');
        },
      );
      AppLogger.info(
        'Firebase App Check activated (${kReleaseMode ? 'production' : 'non-production'} provider).',
      );
    } catch (error, stackTrace) {
      AppLogger.warning('Firebase App Check activation failed.', error, stackTrace);
      // Do NOT rethrow — App Check failure should not crash the app.
    }
  }
}
