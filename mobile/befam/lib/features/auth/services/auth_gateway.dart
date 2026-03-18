import '../models/auth_otp_verification_result.dart';
import '../models/member_identity_verification.dart';
import '../models/auth_otp_request_result.dart';
import '../models/auth_session.dart';
import '../models/pending_otp_challenge.dart';

abstract class AuthGateway {
  bool get isSandbox;

  Future<bool> canRestoreSession(AuthSession session);

  Future<AuthOtpRequestResult> requestPhoneOtp(String phoneE164);

  Future<AuthOtpRequestResult> requestChildOtp(String childIdentifier);

  Future<AuthOtpRequestResult> resendOtp(PendingOtpChallenge challenge);

  Future<AuthOtpVerificationResult> verifyOtp(
    PendingOtpChallenge challenge,
    String smsCode,
    {String? languageCode}
  );

  Future<AuthSession> createUnlinkedPhoneIdentity();

  Future<MemberIdentityVerificationChallenge> startMemberIdentityVerification(
    String memberId,
    {String? languageCode}
  );

  Future<MemberIdentityVerificationResult> submitMemberIdentityVerification({
    required String verificationSessionId,
    required Map<String, String> answers,
  });

  Future<void> signOut();
}
