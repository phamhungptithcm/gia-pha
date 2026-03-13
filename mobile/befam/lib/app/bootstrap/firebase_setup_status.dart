class FirebaseSetupStatus {
  const FirebaseSetupStatus._({
    required this.isReady,
    required this.projectId,
    required this.storageBucket,
    required this.enabledServices,
    required this.isCrashReportingEnabled,
    this.errorMessage,
  });

  factory FirebaseSetupStatus.ready({
    required String projectId,
    required String storageBucket,
    required List<String> enabledServices,
    required bool isCrashReportingEnabled,
  }) {
    return FirebaseSetupStatus._(
      isReady: true,
      projectId: projectId,
      storageBucket: storageBucket,
      enabledServices: enabledServices,
      isCrashReportingEnabled: isCrashReportingEnabled,
    );
  }

  factory FirebaseSetupStatus.failed({
    required String projectId,
    required String storageBucket,
    required String errorMessage,
  }) {
    return FirebaseSetupStatus._(
      isReady: false,
      projectId: projectId,
      storageBucket: storageBucket,
      enabledServices: const [],
      isCrashReportingEnabled: false,
      errorMessage: errorMessage,
    );
  }

  final bool isReady;
  final String projectId;
  final String storageBucket;
  final List<String> enabledServices;
  final bool isCrashReportingEnabled;
  final String? errorMessage;
}
