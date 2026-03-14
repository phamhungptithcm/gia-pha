import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

import '../models/auth_entry_method.dart';
import '../models/auth_otp_request_result.dart';
import '../models/auth_session.dart';
import '../models/pending_otp_challenge.dart';
import '../models/resolved_child_access.dart';
import 'auth_gateway.dart';
import 'phone_number_formatter.dart';

class DebugAuthGateway implements AuthGateway {
  static const String _debugOtp = '123456';
  static const Duration _debugDelay = Duration(milliseconds: 450);

  static const Map<String, ResolvedChildAccess> _childDirectory = {
    'BEFAM-CHILD-001': ResolvedChildAccess(
      childIdentifier: 'BEFAM-CHILD-001',
      parentPhoneE164: '+84901234567',
      memberId: 'member_demo_child_001',
      displayName: 'Be Minh',
    ),
    'BEFAM-CHILD-002': ResolvedChildAccess(
      childIdentifier: 'BEFAM-CHILD-002',
      parentPhoneE164: '+84908886655',
      memberId: 'member_demo_child_002',
      displayName: 'Be Lan',
    ),
  };

  @override
  bool get isSandbox => true;

  @override
  Future<AuthOtpRequestResult> requestPhoneOtp(String phoneE164) async {
    await Future<void>.delayed(_debugDelay);
    return AuthOtpRequestResult.challenge(
      PendingOtpChallenge(
        loginMethod: AuthEntryMethod.phone,
        phoneE164: phoneE164,
        maskedDestination: PhoneNumberFormatter.mask(phoneE164),
        verificationId: 'debug-phone-$phoneE164',
        displayName: 'BeFam Member',
        debugOtpHint: _debugOtp,
      ),
    );
  }

  @override
  Future<AuthOtpRequestResult> requestChildOtp(String childIdentifier) async {
    await Future<void>.delayed(_debugDelay);
    final resolved = _childDirectory[childIdentifier];
    if (resolved == null) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'No demo child record matches that identifier.',
      );
    }

    return AuthOtpRequestResult.challenge(
      PendingOtpChallenge(
        loginMethod: AuthEntryMethod.child,
        phoneE164: resolved.parentPhoneE164,
        maskedDestination: PhoneNumberFormatter.mask(resolved.parentPhoneE164),
        verificationId: 'debug-child-${resolved.childIdentifier}',
        childIdentifier: resolved.childIdentifier,
        memberId: resolved.memberId,
        displayName: resolved.displayName,
        debugOtpHint: _debugOtp,
      ),
    );
  }

  @override
  Future<AuthOtpRequestResult> resendOtp(PendingOtpChallenge challenge) async {
    await Future<void>.delayed(_debugDelay);
    return AuthOtpRequestResult.challenge(
      challenge.copyWith(
        verificationId: '${challenge.verificationId}-resend',
        debugOtpHint: _debugOtp,
      ),
    );
  }

  @override
  Future<AuthSession> verifyOtp(
    PendingOtpChallenge challenge,
    String smsCode,
  ) async {
    await Future<void>.delayed(_debugDelay);
    if (smsCode != _debugOtp) {
      throw FirebaseAuthException(
        code: 'invalid-verification-code',
        message: 'The demo OTP for local testing is 123456.',
      );
    }

    return AuthSession(
      uid: 'debug:${challenge.phoneE164}',
      loginMethod: challenge.loginMethod,
      phoneE164: challenge.phoneE164,
      displayName: challenge.displayName ?? 'BeFam Member',
      childIdentifier: challenge.childIdentifier,
      memberId: challenge.memberId,
      isSandbox: true,
      signedInAtIso: DateTime.now().toIso8601String(),
    );
  }

  @override
  Future<void> signOut() async {}
}
