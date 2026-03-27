import 'auth_entry_method.dart';

enum AuthOtpProvider { firebase, twilio }

class PendingOtpChallenge {
  const PendingOtpChallenge({
    required this.loginMethod,
    required this.phoneE164,
    required this.maskedDestination,
    required this.verificationId,
    this.provider = AuthOtpProvider.twilio,
    this.childIdentifier,
    this.memberId,
    this.displayName,
    this.resendToken,
  });

  final AuthEntryMethod loginMethod;
  final String phoneE164;
  final String maskedDestination;
  final String verificationId;
  final AuthOtpProvider provider;
  final String? childIdentifier;
  final String? memberId;
  final String? displayName;
  final int? resendToken;

  PendingOtpChallenge copyWith({
    AuthEntryMethod? loginMethod,
    String? phoneE164,
    String? maskedDestination,
    String? verificationId,
    AuthOtpProvider? provider,
    String? childIdentifier,
    String? memberId,
    String? displayName,
    int? resendToken,
  }) {
    return PendingOtpChallenge(
      loginMethod: loginMethod ?? this.loginMethod,
      phoneE164: phoneE164 ?? this.phoneE164,
      maskedDestination: maskedDestination ?? this.maskedDestination,
      verificationId: verificationId ?? this.verificationId,
      provider: provider ?? this.provider,
      childIdentifier: childIdentifier ?? this.childIdentifier,
      memberId: memberId ?? this.memberId,
      displayName: displayName ?? this.displayName,
      resendToken: resendToken ?? this.resendToken,
    );
  }
}
