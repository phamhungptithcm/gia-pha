import 'dart:async';

import 'package:befam/features/auth/models/auth_session.dart';
import 'package:befam/features/notifications/services/push_notification_service.dart';

class FakePushNotificationService implements PushNotificationService {
  AuthSession? _session;
  void Function(NotificationDeepLink deepLink)? _onDeepLink;

  @override
  Future<void> start({
    required AuthSession session,
    void Function(NotificationDeepLink deepLink)? onDeepLink,
  }) async {
    _session = session;
    _onDeepLink = onDeepLink;
  }

  @override
  Future<void> stop() async {
    _session = null;
    _onDeepLink = null;
  }

  bool get hasStarted => _session != null;

  void emit({
    required NotificationTargetType targetType,
    NotificationMessageOrigin origin = NotificationMessageOrigin.openedApp,
    String? referenceId,
    String? messageId,
    String? title,
    String? body,
    String? rawTarget,
    Map<String, String>? dataPayload,
    String? type,
  }) {
    final callback = _onDeepLink;
    if (callback == null) {
      return;
    }
    final resolvedRawTarget = rawTarget ?? _rawTargetForType(targetType);
    final resolvedPayload = <String, String>{
      'target': resolvedRawTarget,
      if (referenceId != null && referenceId.isNotEmpty) 'id': referenceId,
      if (type != null && type.isNotEmpty) 'type': type,
      ...?dataPayload,
    };
    callback(
      NotificationDeepLink(
        targetType: targetType,
        referenceId: referenceId,
        messageId: messageId,
        origin: origin,
        rawTarget: resolvedRawTarget,
        dataPayload: resolvedPayload,
        title: title,
        body: body,
        type: type,
      ),
    );
  }

  String _rawTargetForType(NotificationTargetType targetType) {
    return switch (targetType) {
      NotificationTargetType.event => 'event',
      NotificationTargetType.scholarship => 'scholarship',
      NotificationTargetType.billing => 'billing',
      NotificationTargetType.authRefresh => 'auth_refresh',
      NotificationTargetType.unknown => 'generic',
    };
  }
}
