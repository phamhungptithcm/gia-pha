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
        _ => const AuthIssue(AuthIssueKey.authUnavailable),
      };
    }

    return const AuthIssue(AuthIssueKey.preparationFailed);
  }
}
