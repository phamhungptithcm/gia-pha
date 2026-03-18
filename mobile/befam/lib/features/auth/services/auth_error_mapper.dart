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
      final normalizedMessage = message.toLowerCase();
      String normalizedReason = '';
      final details = error.details;
      if (details is Map) {
        final reasonValue = details['reason'];
        if (reasonValue is String) {
          normalizedReason = reasonValue.trim().toLowerCase();
        }
      }
      if (normalizedReason.isNotEmpty) {
        switch (normalizedReason) {
          case 'parent_verification_mismatch':
            return const AuthIssue(AuthIssueKey.parentVerificationMismatch);
          case 'member_verification_data_unavailable':
            return const AuthIssue(AuthIssueKey.memberVerificationDataUnavailable);
          case 'member_verification_locked':
          case 'member_verification_expired':
            return const AuthIssue(AuthIssueKey.memberVerificationLocked);
          case 'member_already_linked':
            return const AuthIssue(AuthIssueKey.memberAlreadyLinked);
          case 'member_inactive':
          case 'member_verification_forbidden':
            return const AuthIssue(AuthIssueKey.operationNotAllowed);
          case 'member_claim_conflict':
            return const AuthIssue(AuthIssueKey.memberClaimConflict);
        }
      }
      return switch (error.code) {
        'not-found' => const AuthIssue(AuthIssueKey.userNotFound),
        'already-exists' => const AuthIssue(AuthIssueKey.memberAlreadyLinked),
        'failed-precondition' when normalizedMessage.contains('parent phone') =>
          const AuthIssue(AuthIssueKey.parentVerificationMismatch),
        'failed-precondition'
            when normalizedMessage.contains(
              'verification data is not sufficient',
            ) =>
          const AuthIssue(AuthIssueKey.memberVerificationDataUnavailable),
        'failed-precondition'
            when normalizedMessage.contains('verification session has expired') =>
          const AuthIssue(AuthIssueKey.sessionExpired),
        'failed-precondition'
            when normalizedMessage.contains(
              'verification session is no longer active',
            ) =>
          const AuthIssue(AuthIssueKey.memberVerificationLocked),
        'failed-precondition'
            when normalizedMessage.contains('verification is temporarily locked') =>
          const AuthIssue(AuthIssueKey.memberVerificationLocked),
        'failed-precondition'
            when normalizedMessage.contains('inactive and cannot be linked') =>
          const AuthIssue(AuthIssueKey.operationNotAllowed),
        'failed-precondition'
            when normalizedMessage.contains(
              'cannot switch to create-new mode',
            ) =>
          const AuthIssue(AuthIssueKey.operationNotAllowed),
        'failed-precondition'
            when normalizedMessage.contains(
                  'child identifier is not fully linked',
                ) ||
                normalizedMessage.contains(
                  'child member record is not linked',
                ) =>
          const AuthIssue(AuthIssueKey.childAccessNotReady),
        'failed-precondition'
            when normalizedMessage.contains(
              'multiple member profiles share this phone',
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
