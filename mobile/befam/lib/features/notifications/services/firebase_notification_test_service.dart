import 'package:cloud_functions/cloud_functions.dart';

import '../../../core/services/firebase_services.dart';
import '../../auth/models/auth_session.dart';
import 'notification_test_service.dart';

class FirebaseNotificationTestService implements NotificationTestService {
  FirebaseNotificationTestService({FirebaseFunctions? functions})
    : _functions = functions ?? FirebaseServices.functions;

  final FirebaseFunctions _functions;

  @override
  bool get isSandbox => false;

  @override
  Future<NotificationTestResult> sendSelfTest({
    required AuthSession session,
    required String title,
    required String body,
    int delaySeconds = 8,
  }) async {
    try {
      final callable = _functions.httpsCallable('sendSelfTestNotification');
      final response = await callable.call(<String, dynamic>{
        'memberId': session.memberId,
        'clanId': session.clanId,
        'title': title,
        'body': body,
        'delaySeconds': delaySeconds,
      });
      final payload = switch (response.data) {
        Map<Object?, Object?> value => value,
        _ => const <Object?, Object?>{},
      };
      return NotificationTestResult(
        tokenCount: _readInt(payload['tokenCount']),
        sentCount: _readInt(payload['sentCount']),
        delaySeconds: _readInt(
          payload['delaySeconds'],
          fallback: delaySeconds.clamp(0, 30),
        ),
        notificationId: _readString(payload['notificationId']),
      );
    } on FirebaseFunctionsException catch (error) {
      throw NotificationTestServiceException(
        _mapErrorCode(error.code),
        error.message,
      );
    } catch (error) {
      throw NotificationTestServiceException(
        NotificationTestServiceErrorCode.unknown,
        '$error',
      );
    }
  }

  @override
  Future<NotificationTestResult> sendEventReminderSelfTest({
    required AuthSession session,
    required String title,
    required String body,
    int delaySeconds = 8,
  }) async {
    try {
      final callable = _functions.httpsCallable('sendSelfTestEventReminder');
      final response = await callable.call(<String, dynamic>{
        'memberId': session.memberId,
        'clanId': session.clanId,
        'title': title,
        'body': body,
        'delaySeconds': delaySeconds,
      });
      final payload = switch (response.data) {
        Map<Object?, Object?> value => value,
        _ => const <Object?, Object?>{},
      };
      return NotificationTestResult(
        tokenCount: _readInt(payload['tokenCount']),
        sentCount: _readInt(payload['sentCount']),
        delaySeconds: _readInt(
          payload['delaySeconds'],
          fallback: delaySeconds.clamp(0, 30),
        ),
        referenceId: _readString(payload['eventId']),
      );
    } on FirebaseFunctionsException catch (error) {
      throw NotificationTestServiceException(
        _mapErrorCode(error.code),
        error.message,
      );
    } catch (error) {
      throw NotificationTestServiceException(
        NotificationTestServiceErrorCode.unknown,
        '$error',
      );
    }
  }

  NotificationTestServiceErrorCode _mapErrorCode(String code) {
    return switch (code) {
      'unauthenticated' => NotificationTestServiceErrorCode.unauthenticated,
      'permission-denied' => NotificationTestServiceErrorCode.permissionDenied,
      'failed-precondition' =>
        NotificationTestServiceErrorCode.failedPrecondition,
      'unavailable' => NotificationTestServiceErrorCode.unavailable,
      _ => NotificationTestServiceErrorCode.unknown,
    };
  }
}

int _readInt(Object? value, {int fallback = 0}) {
  return switch (value) {
    int current => current,
    num current => current.toInt(),
    String current => int.tryParse(current) ?? fallback,
    _ => fallback,
  };
}

String? _readString(Object? value) {
  return switch (value) {
    String current when current.trim().isNotEmpty => current.trim(),
    _ => null,
  };
}
