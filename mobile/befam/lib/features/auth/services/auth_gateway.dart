import '../models/auth_otp_request_result.dart';
import '../models/pending_otp_challenge.dart';
import '../models/auth_session.dart';

abstract class AuthGateway {
  bool get isSandbox;

  Future<AuthOtpRequestResult> requestPhoneOtp(String phoneE164);

  Future<AuthOtpRequestResult> requestChildOtp(String childIdentifier);

  Future<AuthOtpRequestResult> resendOtp(PendingOtpChallenge challenge);

  Future<AuthSession> verifyOtp(PendingOtpChallenge challenge, String smsCode);

  Future<void> signOut();
}
