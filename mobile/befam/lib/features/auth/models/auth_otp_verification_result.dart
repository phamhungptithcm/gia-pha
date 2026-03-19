import 'auth_session.dart';
import 'phone_identity_resolution.dart';

class AuthOtpVerificationResult {
  const AuthOtpVerificationResult._({
    this.session,
    this.phoneResolution,
  });

  const AuthOtpVerificationResult.session(AuthSession session)
      : this._(session: session);

  const AuthOtpVerificationResult.phoneResolution(
    PhoneIdentityResolution phoneResolution,
  ) : this._(phoneResolution: phoneResolution);

  final AuthSession? session;
  final PhoneIdentityResolution? phoneResolution;
}

