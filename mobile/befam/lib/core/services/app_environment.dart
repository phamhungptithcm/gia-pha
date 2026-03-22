import 'package:flutter/foundation.dart';

class AppEnvironment {
  const AppEnvironment._();

  static const bool allowBundledFirebaseOptions = bool.fromEnvironment(
    'BEFAM_ALLOW_BUNDLED_FIREBASE_OPTIONS',
    defaultValue: false,
  );

  static const String firebaseProjectId = String.fromEnvironment(
    'BEFAM_FIREBASE_PROJECT_ID',
    defaultValue: '',
  );

  static const String firebaseStorageBucket = String.fromEnvironment(
    'BEFAM_FIREBASE_STORAGE_BUCKET',
    defaultValue: '',
  );

  static const String firebaseAndroidApiKey = String.fromEnvironment(
    'BEFAM_FIREBASE_ANDROID_API_KEY',
    defaultValue: '',
  );

  static const String firebaseAndroidAppId = String.fromEnvironment(
    'BEFAM_FIREBASE_ANDROID_APP_ID',
    defaultValue: '',
  );

  static const String firebaseAndroidMessagingSenderId = String.fromEnvironment(
    'BEFAM_FIREBASE_ANDROID_MESSAGING_SENDER_ID',
    defaultValue: '',
  );

  static const String firebaseIosApiKey = String.fromEnvironment(
    'BEFAM_FIREBASE_IOS_API_KEY',
    defaultValue: '',
  );

  static const String firebaseIosAppId = String.fromEnvironment(
    'BEFAM_FIREBASE_IOS_APP_ID',
    defaultValue: '',
  );

  static const String firebaseIosMessagingSenderId = String.fromEnvironment(
    'BEFAM_FIREBASE_IOS_MESSAGING_SENDER_ID',
    defaultValue: '',
  );

  static const String firebaseIosBundleId = String.fromEnvironment(
    'BEFAM_FIREBASE_IOS_BUNDLE_ID',
    defaultValue: '',
  );

  static const String firebaseWebApiKey = String.fromEnvironment(
    'BEFAM_FIREBASE_WEB_API_KEY',
    defaultValue: '',
  );

  static const String firebaseWebAppId = String.fromEnvironment(
    'BEFAM_FIREBASE_WEB_APP_ID',
    defaultValue: '',
  );

  static const String firebaseWebMessagingSenderId = String.fromEnvironment(
    'BEFAM_FIREBASE_WEB_MESSAGING_SENDER_ID',
    defaultValue: '',
  );

  static const String firebaseWebAuthDomain = String.fromEnvironment(
    'BEFAM_FIREBASE_WEB_AUTH_DOMAIN',
    defaultValue: '',
  );

  static const String firebaseWebMeasurementId = String.fromEnvironment(
    'BEFAM_FIREBASE_WEB_MEASUREMENT_ID',
    defaultValue: '',
  );

  static const String firebaseFunctionsRegion = String.fromEnvironment(
    'BEFAM_FIREBASE_FUNCTIONS_REGION',
    defaultValue: 'asia-southeast1',
  );

  static const String defaultTimezone = String.fromEnvironment(
    'BEFAM_DEFAULT_TIMEZONE',
    defaultValue: 'Asia/Ho_Chi_Minh',
  );

  static const String invalidCheckoutHostsRaw = String.fromEnvironment(
    'BEFAM_INVALID_CHECKOUT_HOSTS',
    defaultValue: 'example.com',
  );

  static final Set<String> invalidCheckoutHosts = invalidCheckoutHostsRaw
      .split(',')
      .map((token) => token.trim().toLowerCase())
      .where((token) => token.isNotEmpty)
      .toSet();

  static const bool enableAppCheck = bool.fromEnvironment(
    'BEFAM_ENABLE_APP_CHECK',
    defaultValue: true,
  );

  static const bool allowFirebasePhoneAuthFallback =
      !kReleaseMode &&
      bool.fromEnvironment(
        'BEFAM_ALLOW_FIREBASE_PHONE_FALLBACK',
        defaultValue: false,
      );

  static const String appCheckWebRecaptchaSiteKey = String.fromEnvironment(
    'BEFAM_APP_CHECK_WEB_RECAPTCHA_SITE_KEY',
    defaultValue: '',
  );

  static const int billingPendingTimeoutMinutes = int.fromEnvironment(
    'BEFAM_BILLING_PENDING_TIMEOUT_MINUTES',
    defaultValue: 20,
  );

  static const String iosAppStoreUrl = String.fromEnvironment(
    'BEFAM_IOS_APP_STORE_URL',
    defaultValue: '',
  );

  static const String androidPlayStoreUrl = String.fromEnvironment(
    'BEFAM_ANDROID_PLAY_STORE_URL',
    defaultValue: '',
  );
}
