import 'package:befam/features/auth/models/auth_entry_method.dart';
import 'package:befam/features/auth/models/auth_issue.dart';
import 'package:befam/features/auth/models/auth_member_access_mode.dart';
import 'package:befam/features/auth/models/auth_otp_request_result.dart';
import 'package:befam/features/auth/models/auth_session.dart';
import 'package:befam/features/auth/models/pending_otp_challenge.dart';
import 'package:befam/features/auth/presentation/auth_controller.dart';
import 'package:befam/features/auth/services/auth_analytics_service.dart';
import 'package:befam/features/auth/services/auth_gateway.dart';
import 'package:befam/features/auth/services/auth_privacy_policy_store.dart';
import 'package:befam/features/auth/services/auth_session_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AuthController phone login', () {
    test('submits phone number then verifies OTP successfully', () async {
      final gateway = _FakeAuthGateway();
      final controller = AuthController(
        authGateway: gateway,
        analyticsService: const NoopAuthAnalyticsService(),
        sessionStore: InMemoryAuthSessionStore(),
        privacyPolicyStore: InMemoryAuthPrivacyPolicyStore(accepted: true),
      );
      await controller.initialize();

      await controller.submitPhoneNumber('+84901234567');
      await controller.verifyOtp('123456');

      expect(gateway.requestPhoneOtpCount, 1);
      expect(gateway.verifyOtpCount, 1);
      expect(gateway.lastVerifiedCode, '123456');
      expect(controller.session, isNotNull);
      expect(controller.error, isNull);
    });

    test('rejects empty phone and does not request OTP', () async {
      final gateway = _FakeAuthGateway();
      final controller = AuthController(
        authGateway: gateway,
        analyticsService: const NoopAuthAnalyticsService(),
        sessionStore: InMemoryAuthSessionStore(),
        privacyPolicyStore: InMemoryAuthPrivacyPolicyStore(accepted: true),
      );
      await controller.initialize();

      await controller.submitPhoneNumber('   ');

      expect(gateway.requestPhoneOtpCount, 0);
      expect(controller.error?.key, AuthIssueKey.phoneRequired);
      expect(controller.session, isNull);
    });

    test('normalizes local phone format before requesting OTP', () async {
      final gateway = _FakeAuthGateway(isSandbox: false);
      final controller = AuthController(
        authGateway: gateway,
        analyticsService: const NoopAuthAnalyticsService(),
        sessionStore: InMemoryAuthSessionStore(),
        privacyPolicyStore: InMemoryAuthPrivacyPolicyStore(accepted: true),
      );
      await controller.initialize();

      await controller.submitPhoneNumber('0901234567');

      expect(gateway.requestPhoneOtpCount, 1);
      expect(gateway.lastRequestedPhoneE164, '+84901234567');
      expect(gateway.verifyOtpCount, 0);
      expect(controller.step, AuthStep.otp);
      expect(controller.session, isNull);
      expect(controller.error, isNull);
    });
  });
}

class _FakeAuthGateway implements AuthGateway {
  _FakeAuthGateway({this.isSandbox = true});

  int requestPhoneOtpCount = 0;
  int verifyOtpCount = 0;
  String? lastVerifiedCode;
  String? lastRequestedPhoneE164;

  @override
  final bool isSandbox;

  @override
  Future<bool> canRestoreSession(AuthSession session) async => false;

  @override
  Future<AuthOtpRequestResult> requestPhoneOtp(String phoneE164) async {
    requestPhoneOtpCount += 1;
    lastRequestedPhoneE164 = phoneE164;
    return AuthOtpRequestResult.challenge(
      PendingOtpChallenge(
        loginMethod: AuthEntryMethod.phone,
        phoneE164: phoneE164,
        maskedDestination: '+84******567',
        verificationId: 'fake-verification',
        debugOtpHint: '123456',
      ),
    );
  }

  @override
  Future<AuthOtpRequestResult> requestChildOtp(String childIdentifier) async {
    throw UnimplementedError();
  }

  @override
  Future<AuthOtpRequestResult> resendOtp(PendingOtpChallenge challenge) async {
    return AuthOtpRequestResult.challenge(challenge);
  }

  @override
  Future<AuthSession> verifyOtp(
    PendingOtpChallenge challenge,
    String smsCode,
  ) async {
    verifyOtpCount += 1;
    lastVerifiedCode = smsCode;
    return AuthSession(
      uid: 'debug:${challenge.phoneE164}',
      loginMethod: challenge.loginMethod,
      phoneE164: challenge.phoneE164,
      displayName: 'Người dùng thử nghiệm',
      memberId: 'member_demo_parent_001',
      clanId: 'clan_demo_001',
      branchId: 'branch_demo_001',
      primaryRole: 'CLAN_ADMIN',
      accessMode: AuthMemberAccessMode.claimed,
      linkedAuthUid: true,
      isSandbox: true,
      signedInAtIso: DateTime(2026, 3, 15).toIso8601String(),
    );
  }

  @override
  Future<void> signOut() async {}
}
