import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

import '../models/auth_entry_method.dart';
import '../models/auth_member_access_mode.dart';
import '../models/auth_otp_request_result.dart';
import '../models/auth_session.dart';
import '../models/member_access_context.dart';
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
      clanId: 'clan_demo_001',
      branchId: 'branch_demo_001',
      primaryRole: 'MEMBER',
    ),
    'BEFAM-CHILD-002': ResolvedChildAccess(
      childIdentifier: 'BEFAM-CHILD-002',
      parentPhoneE164: '+84908886655',
      memberId: 'member_demo_child_002',
      displayName: 'Be Lan',
      clanId: 'clan_demo_001',
      branchId: 'branch_demo_002',
      primaryRole: 'MEMBER',
    ),
  };

  static const Map<String, MemberAccessContext> _phoneDirectory = {
    '+84901234567': MemberAccessContext(
      memberId: 'member_demo_parent_001',
      displayName: 'Nguyen Minh',
      clanId: 'clan_demo_001',
      branchId: 'branch_demo_001',
      primaryRole: 'CLAN_ADMIN',
      accessMode: AuthMemberAccessMode.claimed,
      linkedAuthUid: true,
    ),
    '+84908886655': MemberAccessContext(
      memberId: 'member_demo_parent_002',
      displayName: 'Tran Lan',
      clanId: 'clan_demo_001',
      branchId: 'branch_demo_002',
      primaryRole: 'BRANCH_ADMIN',
      accessMode: AuthMemberAccessMode.claimed,
      linkedAuthUid: true,
    ),
  };

  @override
  bool get isSandbox => true;

  @override
  Future<bool> canRestoreSession(AuthSession session) async {
    return session.isSandbox;
  }

  @override
  Future<AuthOtpRequestResult> requestPhoneOtp(String phoneE164) async {
    await Future<void>.delayed(_debugDelay);
    final memberAccess = _phoneDirectory[phoneE164];
    return AuthOtpRequestResult.challenge(
      PendingOtpChallenge(
        loginMethod: AuthEntryMethod.phone,
        phoneE164: phoneE164,
        maskedDestination: PhoneNumberFormatter.mask(phoneE164),
        verificationId: 'debug-phone-$phoneE164',
        memberId: memberAccess?.memberId,
        displayName: memberAccess?.displayName ?? 'BeFam Member',
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
      displayName:
          _memberAccessFor(challenge).displayName ??
          challenge.displayName ??
          'BeFam Member',
      childIdentifier: challenge.childIdentifier,
      memberId: _memberAccessFor(challenge).memberId ?? challenge.memberId,
      clanId: _memberAccessFor(challenge).clanId,
      branchId: _memberAccessFor(challenge).branchId,
      primaryRole: _memberAccessFor(challenge).primaryRole,
      accessMode: _memberAccessFor(challenge).accessMode,
      linkedAuthUid: _memberAccessFor(challenge).linkedAuthUid,
      isSandbox: true,
      signedInAtIso: DateTime.now().toIso8601String(),
    );
  }

  @override
  Future<void> signOut() async {}

  MemberAccessContext _memberAccessFor(PendingOtpChallenge challenge) {
    if (challenge.loginMethod == AuthEntryMethod.child) {
      final resolved = _childDirectory[challenge.childIdentifier];
      return MemberAccessContext(
        memberId: resolved?.memberId ?? challenge.memberId,
        displayName: resolved?.displayName ?? challenge.displayName,
        clanId: resolved?.clanId,
        branchId: resolved?.branchId,
        primaryRole: resolved?.primaryRole,
        accessMode: AuthMemberAccessMode.child,
        linkedAuthUid: false,
      );
    }

    return _phoneDirectory[challenge.phoneE164] ??
        MemberAccessContext.unlinked(displayName: challenge.displayName);
  }
}
