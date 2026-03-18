import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:befam/features/auth/models/auth_issue.dart';
import 'package:befam/features/auth/services/auth_error_mapper.dart';

void main() {
  group('AuthErrorMapper', () {
    test('maps unauthorized web domain errors', () {
      final issue = AuthErrorMapper.map(
        FirebaseAuthException(code: 'unauthorized-domain'),
      );

      expect(issue.key, AuthIssueKey.webDomainNotAuthorized);
    });

    test('maps app-not-authorized to web domain error', () {
      final issue = AuthErrorMapper.map(
        FirebaseAuthException(code: 'app-not-authorized'),
      );

      expect(issue.key, AuthIssueKey.webDomainNotAuthorized);
    });

    test('maps recaptcha failures', () {
      final issue = AuthErrorMapper.map(
        FirebaseAuthException(code: 'captcha-check-failed'),
      );

      expect(issue.key, AuthIssueKey.recaptchaVerificationFailed);
    });

    test('maps web context cancelled into recaptcha failure', () {
      final issue = AuthErrorMapper.map(
        FirebaseAuthException(code: 'web-context-cancelled'),
      );

      expect(issue.key, AuthIssueKey.recaptchaVerificationFailed);
    });

    test('maps firebase functions invalid argument to preparation failed', () {
      final issue = AuthErrorMapper.map(
        FirebaseFunctionsException(
          code: 'invalid-argument',
          message: 'invalid payload',
        ),
      );

      expect(issue.key, AuthIssueKey.preparationFailed);
    });

    test('maps firebase permission denied to operation not allowed', () {
      final issue = AuthErrorMapper.map(
        FirebaseException(
          plugin: 'cloud_firestore',
          code: 'permission-denied',
          message: 'Missing or insufficient permissions.',
        ),
      );

      expect(issue.key, AuthIssueKey.operationNotAllowed);
    });

    test('maps unknown error to preparation failed', () {
      final issue = AuthErrorMapper.map(StateError('boom'));

      expect(issue.key, AuthIssueKey.preparationFailed);
    });
  });
}
