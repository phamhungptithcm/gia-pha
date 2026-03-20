import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../../core/services/app_logger.dart';
import '../../../core/services/firebase_services.dart';
import '../../auth/models/auth_session.dart';

enum NotificationTargetType { event, scholarship, billing, unknown }

enum NotificationMessageOrigin { foreground, openedApp, launchedFromTerminated }

class NotificationDeepLink {
  const NotificationDeepLink({
    required this.targetType,
    required this.referenceId,
    required this.messageId,
    required this.origin,
    this.title,
    this.body,
  });

  final NotificationTargetType targetType;
  final String? referenceId;
  final String? messageId;
  final NotificationMessageOrigin origin;
  final String? title;
  final String? body;

  bool get openedFromSystemNotification {
    return origin != NotificationMessageOrigin.foreground;
  }

  factory NotificationDeepLink.fromRemoteMessage(
    RemoteMessage message, {
    required NotificationMessageOrigin origin,
  }) {
    final targetRaw = (message.data['target'] as String? ?? '')
        .trim()
        .toLowerCase();
    final targetType = switch (targetRaw) {
      'event' => NotificationTargetType.event,
      'scholarship' => NotificationTargetType.scholarship,
      'billing' => NotificationTargetType.billing,
      _ => NotificationTargetType.unknown,
    };
    return NotificationDeepLink(
      targetType: targetType,
      referenceId: message.data['id'] as String?,
      messageId: message.messageId,
      origin: origin,
      title: message.notification?.title,
      body: message.notification?.body,
    );
  }
}

abstract interface class PushNotificationService {
  Future<void> start({
    required AuthSession session,
    void Function(NotificationDeepLink deepLink)? onDeepLink,
  });

  Future<void> stop();
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  AppLogger.info(
    'FCM background message received: ${message.messageId ?? 'unknown'}',
  );
}

void configurePushBackgroundHandler() {
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
}

class _TokenRegistrationContext {
  const _TokenRegistrationContext({
    required this.uid,
    required this.memberId,
    required this.clanId,
    required this.branchId,
    required this.primaryRole,
    required this.accessMode,
  });

  factory _TokenRegistrationContext.fromSession(AuthSession session) {
    return _TokenRegistrationContext(
      uid: session.uid,
      memberId: session.memberId?.trim() ?? '',
      clanId: session.clanId?.trim() ?? '',
      branchId: session.branchId?.trim() ?? '',
      primaryRole: session.primaryRole?.trim() ?? '',
      accessMode: session.accessMode.name,
    );
  }

  final String uid;
  final String memberId;
  final String clanId;
  final String branchId;
  final String primaryRole;
  final String accessMode;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is _TokenRegistrationContext &&
        other.uid == uid &&
        other.memberId == memberId &&
        other.clanId == clanId &&
        other.branchId == branchId &&
        other.primaryRole == primaryRole &&
        other.accessMode == accessMode;
  }

  @override
  int get hashCode {
    return Object.hash(
      uid,
      memberId,
      clanId,
      branchId,
      primaryRole,
      accessMode,
    );
  }
}

class FirebasePushNotificationService implements PushNotificationService {
  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  _TokenRegistrationContext? _activeRegistrationContext;
  bool _tokenCallableMissing = false;

  @override
  Future<void> start({
    required AuthSession session,
    void Function(NotificationDeepLink deepLink)? onDeepLink,
  }) async {
    final registrationContext = _TokenRegistrationContext.fromSession(session);
    if (_activeRegistrationContext == registrationContext) {
      return;
    }

    await stop();
    _activeRegistrationContext = registrationContext;

    try {
      final messaging = FirebaseServices.messaging;
      await messaging.setAutoInitEnabled(true);
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: true,
      );
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      final token = await messaging.getToken();
      if (token != null && token.trim().isNotEmpty) {
        await _registerToken(session, token.trim());
      }

      _tokenSubscription = messaging.onTokenRefresh.listen((token) {
        final trimmed = token.trim();
        if (trimmed.isEmpty) {
          return;
        }
        unawaited(_registerToken(session, trimmed));
      });

      _foregroundSubscription = FirebaseMessaging.onMessage.listen((message) {
        final deepLink = NotificationDeepLink.fromRemoteMessage(
          message,
          origin: NotificationMessageOrigin.foreground,
        );
        onDeepLink?.call(deepLink);
        AppLogger.info(
          'FCM foreground message received: ${deepLink.messageId ?? 'unknown'}',
        );
      });

      _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen((
        message,
      ) {
        final deepLink = NotificationDeepLink.fromRemoteMessage(
          message,
          origin: NotificationMessageOrigin.openedApp,
        );
        onDeepLink?.call(deepLink);
      });

      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        final deepLink = NotificationDeepLink.fromRemoteMessage(
          initialMessage,
          origin: NotificationMessageOrigin.launchedFromTerminated,
        );
        onDeepLink?.call(deepLink);
      }
    } catch (error, stackTrace) {
      AppLogger.warning(
        'Push notification bootstrap failed.',
        error,
        stackTrace,
      );
    }
  }

  @override
  Future<void> stop() async {
    await _tokenSubscription?.cancel();
    await _foregroundSubscription?.cancel();
    await _openedSubscription?.cancel();
    _tokenSubscription = null;
    _foregroundSubscription = null;
    _openedSubscription = null;
    _activeRegistrationContext = null;
  }

  Future<void> _registerToken(AuthSession session, String token) async {
    if (_tokenCallableMissing) {
      await _registerTokenWithFirestore(session, token);
      return;
    }

    try {
      final callable = FirebaseServices.functions.httpsCallable(
        'registerDeviceToken',
      );
      await callable.call(<String, dynamic>{
        'token': token,
        'platform': defaultTargetPlatform.name,
        'memberId': session.memberId,
        'clanId': session.clanId,
        'branchId': session.branchId,
        'accessMode': session.accessMode.name,
      });
    } on FirebaseFunctionsException catch (error, stackTrace) {
      if (_shouldUseFirestoreFallback(error.code)) {
        _tokenCallableMissing = true;
        AppLogger.warning(
          'registerDeviceToken callable is unavailable. Falling back to direct Firestore token sync.',
        );
        await _registerTokenWithFirestore(session, token);
        return;
      }
      AppLogger.warning(
        'Could not register FCM token via callable (${error.code}).',
        error,
        stackTrace,
      );
    } catch (error, stackTrace) {
      AppLogger.warning('Could not register FCM token.', error, stackTrace);
    }
  }

  Future<void> _registerTokenWithFirestore(
    AuthSession session,
    String token,
  ) async {
    try {
      final normalizedRole = (session.primaryRole ?? '').trim();
      await FirebaseServices.firestore
          .collection('users')
          .doc(session.uid)
          .collection('deviceTokens')
          .doc(token)
          .set({
            'token': token,
            'uid': session.uid,
            'platform': defaultTargetPlatform.name,
            'memberId': session.memberId ?? '',
            'clanId': session.clanId ?? '',
            'branchId': session.branchId ?? '',
            'primaryRole': normalizedRole.isEmpty ? 'GUEST' : normalizedRole,
            'accessMode': session.accessMode.name,
            'updatedAt': FieldValue.serverTimestamp(),
            'createdAt': FieldValue.serverTimestamp(),
            'lastSeenAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
    } catch (error, stackTrace) {
      AppLogger.warning(
        'Could not register FCM token via Firestore fallback.',
        error,
        stackTrace,
      );
    }
  }

  bool _shouldUseFirestoreFallback(String code) {
    return code == 'not-found' ||
        code == 'unavailable' ||
        code == 'unimplemented';
  }
}

PushNotificationService createDefaultPushNotificationService({
  AuthSession? session,
}) {
  return FirebasePushNotificationService();
}
