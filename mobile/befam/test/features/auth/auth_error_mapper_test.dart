import 'package:befam/features/auth/models/auth_issue.dart';
import 'package:befam/features/auth/services/auth_error_mapper.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

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
  });
}
