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
  }) {
    final callback = _onDeepLink;
    if (callback == null) {
      return;
    }
    callback(
      NotificationDeepLink(
        targetType: targetType,
        referenceId: referenceId,
        messageId: messageId,
        origin: origin,
        title: title,
        body: body,
      ),
    );
  }
}
