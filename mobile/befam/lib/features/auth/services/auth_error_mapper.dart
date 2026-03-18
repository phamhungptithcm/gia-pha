import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/auth_issue.dart';

class AuthErrorMapper {
  const AuthErrorMapper._();

  static AuthIssue map(Object error) {
    if (error is AuthIssueException) {
      return error.issue;
    }

    if (error is FirebaseAuthException) {
      return switch (error.code) {
        'invalid-phone-number' => const AuthIssue(
          AuthIssueKey.invalidPhoneNumber,
        ),
        'invalid-verification-code' => const AuthIssue(
          AuthIssueKey.invalidVerificationCode,
        ),
        'session-expired' => const AuthIssue(AuthIssueKey.sessionExpired),
        'network-request-failed' => const AuthIssue(
          AuthIssueKey.networkRequestFailed,
        ),
        'too-many-requests' => const AuthIssue(AuthIssueKey.tooManyRequests),
        'quota-exceeded' => const AuthIssue(AuthIssueKey.quotaExceeded),
        'user-not-found' => const AuthIssue(AuthIssueKey.userNotFound),
        'operation-not-allowed' => const AuthIssue(
          AuthIssueKey.operationNotAllowed,
        ),
        'app-not-authorized' || 'unauthorized-domain' => const AuthIssue(
          AuthIssueKey.webDomainNotAuthorized,
        ),
        'captcha-check-failed' ||
        'missing-app-credential' ||
        'invalid-app-credential' ||
        'web-context-cancelled' ||
        'web-context-canceled' => const AuthIssue(
          AuthIssueKey.recaptchaVerificationFailed,
        ),
        _ => const AuthIssue(AuthIssueKey.authUnavailable),
      };
    }

    if (error is FirebaseFunctionsException) {
      final message = error.message ?? '';
      return switch (error.code) {
        'not-found' => const AuthIssue(AuthIssueKey.userNotFound),
        'already-exists' => const AuthIssue(AuthIssueKey.memberAlreadyLinked),
        'failed-precondition' when message.contains('parent phone') =>
          const AuthIssue(AuthIssueKey.parentVerificationMismatch),
        'failed-precondition'
            when message.contains('child identifier is not fully linked') ||
                message.contains('child member record is not linked') =>
          const AuthIssue(AuthIssueKey.childAccessNotReady),
        'failed-precondition'
            when message.contains(
              'Multiple member profiles share this phone',
            ) =>
          const AuthIssue(AuthIssueKey.memberClaimConflict),
        'invalid-argument' => const AuthIssue(AuthIssueKey.preparationFailed),
        'permission-denied' => const AuthIssue(
          AuthIssueKey.operationNotAllowed,
        ),
        _ => const AuthIssue(AuthIssueKey.authUnavailable),
      };
    }

    if (error is FirebaseException) {
      final normalizedCode = error.code.trim().toLowerCase();
      return switch (normalizedCode) {
        'permission-denied' || 'permission_denied' => const AuthIssue(
          AuthIssueKey.operationNotAllowed,
        ),
        'unavailable' || 'network-request-failed' => const AuthIssue(
          AuthIssueKey.networkRequestFailed,
        ),
        'failed-precondition' ||
        'failed_precondition' => const AuthIssue(AuthIssueKey.authUnavailable),
        _ => const AuthIssue(AuthIssueKey.authUnavailable),
      };
    }

    return const AuthIssue(AuthIssueKey.preparationFailed);
  }
}
