import 'auth_session.dart';
import 'pending_otp_challenge.dart';

class AuthOtpRequestResult {
  const AuthOtpRequestResult._({this.challenge, this.session});

  const AuthOtpRequestResult.challenge(PendingOtpChallenge challenge)
    : this._(challenge: challenge);

  const AuthOtpRequestResult.session(AuthSession session)
    : this._(session: session);

  final PendingOtpChallenge? challenge;
  final AuthSession? session;
}
