import '../../auth/models/auth_session.dart';
import 'firebase_notification_test_service.dart';

enum NotificationTestServiceErrorCode {
  unauthenticated,
  permissionDenied,
  failedPrecondition,
  unavailable,
  unknown,
}

class NotificationTestServiceException implements Exception {
  const NotificationTestServiceException(this.code, [this.message]);

  final NotificationTestServiceErrorCode code;
  final String? message;

  @override
  String toString() => message ?? code.name;
}

class NotificationTestResult {
  const NotificationTestResult({
    required this.tokenCount,
    required this.sentCount,
    required this.delaySeconds,
    this.notificationId,
    this.referenceId,
  });

  final int tokenCount;
  final int sentCount;
  final int delaySeconds;
  final String? notificationId;
  final String? referenceId;
}

abstract interface class NotificationTestService {
  bool get isSandbox;

  Future<NotificationTestResult> sendSelfTest({
    required AuthSession session,
    required String title,
    required String body,
    int delaySeconds = 8,
  });

  Future<NotificationTestResult> sendEventReminderSelfTest({
    required AuthSession session,
    required String title,
    required String body,
    int delaySeconds = 8,
  });
}

NotificationTestService createDefaultNotificationTestService({
  AuthSession? session,
}) {
  return FirebaseNotificationTestService();
}
