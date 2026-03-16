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
    defaultValue: 'example.com',
  );

  static final Set<String> invalidCheckoutHosts = invalidCheckoutHostsRaw
      .split(',')
      .map((token) => token.trim().toLowerCase())
      .where((token) => token.isNotEmpty)
      .toSet();
}
