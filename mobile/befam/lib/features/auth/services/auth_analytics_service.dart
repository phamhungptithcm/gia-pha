import 'package:firebase_analytics/firebase_analytics.dart';

import '../../../core/services/analytics_event_names.dart';
import '../../../core/services/app_logger.dart';
import '../models/auth_entry_method.dart';
import '../models/auth_issue.dart';
import '../models/auth_member_access_mode.dart';
import '../models/auth_session.dart';

abstract class AuthAnalyticsService {
  Future<void> logLoginMethodSelected(
    AuthEntryMethod method, {
    required bool isSandbox,
  });

  Future<void> logOtpRequested(
    AuthEntryMethod method, {
    required bool isSandbox,
    required bool isResend,
  });

  Future<void> logChildContextResolved({
    required bool isSandbox,
    required String childIdentifier,
    required String? memberId,
  });

  Future<void> logSessionEstablished(AuthSession session);

  Future<void> logFailure({
    required String stage,
    required bool isSandbox,
    AuthEntryMethod? method,
    AuthIssue? issue,
  });

  Future<void> logLogout(AuthSession? session);
}

class NoopAuthAnalyticsService implements AuthAnalyticsService {
  const NoopAuthAnalyticsService();

  @override
  Future<void> logChildContextResolved({
    required bool isSandbox,
    required String childIdentifier,
    required String? memberId,
  }) async {}

  @override
  Future<void> logFailure({
    required String stage,
    required bool isSandbox,
    AuthEntryMethod? method,
    AuthIssue? issue,
  }) async {}

  @override
  Future<void> logLoginMethodSelected(
    AuthEntryMethod method, {
    required bool isSandbox,
  }) async {}

  @override
  Future<void> logLogout(AuthSession? session) async {}

  @override
  Future<void> logOtpRequested(
    AuthEntryMethod method, {
    required bool isSandbox,
    required bool isResend,
  }) async {}

  @override
  Future<void> logSessionEstablished(AuthSession session) async {}
}

class FirebaseAuthAnalyticsService implements AuthAnalyticsService {
  const FirebaseAuthAnalyticsService(this._analytics);

  final FirebaseAnalytics _analytics;

  @override
  Future<void> logLoginMethodSelected(
    AuthEntryMethod method, {
    required bool isSandbox,
  }) {
    return _logEvent(AnalyticsEventNames.authMethodSelected, {
      'method': method.name,
      'is_sandbox': isSandbox ? 1 : 0,
    });
  }

  @override
  Future<void> logOtpRequested(
    AuthEntryMethod method, {
    required bool isSandbox,
    required bool isResend,
  }) {
    return _logEvent(AnalyticsEventNames.authOtpRequested, {
      'method': method.name,
      'is_sandbox': isSandbox ? 1 : 0,
      'is_resend': isResend ? 1 : 0,
    });
  }

  @override
  Future<void> logChildContextResolved({
    required bool isSandbox,
    required String childIdentifier,
    required String? memberId,
  }) {
    return _logEvent(AnalyticsEventNames.authChildContextResolved, {
      'is_sandbox': isSandbox ? 1 : 0,
      'has_member_id': memberId == null ? 0 : 1,
      'child_identifier_length': childIdentifier.length,
    });
  }

  @override
  Future<void> logSessionEstablished(AuthSession session) async {
    await _analytics.setUserId(id: session.uid);
    await _analytics.setUserProperty(
      name: AnalyticsUserPropertyNames.authMethod,
      value: session.loginMethod.name,
    );
    await _analytics.setUserProperty(
      name: AnalyticsUserPropertyNames.memberAccessMode,
      value: session.accessMode.name,
    );

    await _logEvent(AnalyticsEventNames.authSessionEstablished, {
      'method': session.loginMethod.name,
      'access_mode': session.accessMode.name,
      'is_sandbox': session.isSandbox ? 1 : 0,
      'has_member_id': session.memberId == null ? 0 : 1,
      'linked_auth_uid': session.linkedAuthUid ? 1 : 0,
    });
  }

  @override
  Future<void> logFailure({
    required String stage,
    required bool isSandbox,
    AuthEntryMethod? method,
    AuthIssue? issue,
  }) {
    return _logEvent(AnalyticsEventNames.authFailure, {
      'stage': stage,
      'method': method?.name ?? 'unknown',
      'issue': issue?.key.name ?? 'unknown',
      'is_sandbox': isSandbox ? 1 : 0,
    });
  }

  @override
  Future<void> logLogout(AuthSession? session) async {
    await _logEvent(AnalyticsEventNames.authLogout, {
      'method': session?.loginMethod.name ?? 'unknown',
      'access_mode':
          session?.accessMode.name ?? AuthMemberAccessMode.unlinked.name,
      'has_member_id': session?.memberId == null ? 0 : 1,
    });
    await _analytics.setUserId(id: null);
  }

  Future<void> _logEvent(String name, Map<String, Object?> parameters) async {
    try {
      final sanitized = <String, Object>{};
      for (final entry in parameters.entries) {
        final value = entry.value;
        if (value != null) {
          sanitized[entry.key] = value;
        }
      }

      await _analytics.logEvent(name: name, parameters: sanitized);
    } catch (error, stackTrace) {
      AppLogger.warning(
        'Auth analytics event failed for $name.',
        error,
        stackTrace,
      );
    }
  }
}

AuthAnalyticsService createDefaultAuthAnalyticsService() {
  return FirebaseAuthAnalyticsService(FirebaseAnalytics.instance);
}
