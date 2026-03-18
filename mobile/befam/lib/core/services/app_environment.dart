class AppEnvironment {
  const AppEnvironment._();

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
    defaultValue: 'example.com,checkout-debug.befam.local',
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

  static const String appCheckWebRecaptchaSiteKey = String.fromEnvironment(
    'BEFAM_APP_CHECK_WEB_RECAPTCHA_SITE_KEY',
    defaultValue: '',
  );

  static const int billingPendingTimeoutMinutes = int.fromEnvironment(
    'BEFAM_BILLING_PENDING_TIMEOUT_MINUTES',
    defaultValue: 20,
  );
}
