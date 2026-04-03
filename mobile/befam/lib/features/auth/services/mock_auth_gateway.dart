import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/auth_entry_method.dart';
import '../models/auth_member_access_mode.dart';
import '../models/auth_otp_request_result.dart';
import '../models/auth_otp_verification_result.dart';
import '../models/auth_session.dart';
import '../models/member_access_context.dart';
import '../models/member_identity_verification.dart';
import '../models/pending_otp_challenge.dart';
import '../models/resolved_child_access.dart';
import 'auth_gateway.dart';
import 'phone_number_formatter.dart';

class MockAuthGateway implements AuthGateway {
  MockAuthGateway({FirebaseFirestore? firestore}) : _firestore = firestore;

  static const String _debugOtp = '123456';
  static const Duration _debugDelay = Duration(milliseconds: 450);
  final FirebaseFirestore? _firestore;

  static const Map<String, ResolvedChildAccess> _childDirectory = {
    'BEFAM-CHILD-001': ResolvedChildAccess(
      childIdentifier: 'BEFAM-CHILD-001',
      maskedDestination: '*** *** 4567',
      memberId: 'member_demo_child_001',
      displayName: 'Be Minh',
      clanId: 'clan_demo_001',
      branchId: 'branch_demo_001',
      primaryRole: 'MEMBER',
    ),
    'BEFAM-CHILD-002': ResolvedChildAccess(
      childIdentifier: 'BEFAM-CHILD-002',
      maskedDestination: '*** *** 6655',
      memberId: 'member_demo_child_002',
      displayName: 'Be Lan',
      clanId: 'clan_demo_001',
      branchId: 'branch_demo_002',
      primaryRole: 'MEMBER',
    ),
  };

  static const Map<String, MemberAccessContext> _phoneDirectory = {
    '+84909990001': MemberAccessContext(
      memberId: null,
      displayName: 'Truong toc chua tao gia pha',
      clanId: 'clan_onboarding_001',
      branchId: null,
      primaryRole: 'CLAN_ADMIN',
      accessMode: AuthMemberAccessMode.claimed,
      linkedAuthUid: true,
    ),
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
      displayName: 'Tran Van Long',
      clanId: 'clan_demo_001',
      branchId: 'branch_demo_002',
      primaryRole: 'BRANCH_ADMIN',
      accessMode: AuthMemberAccessMode.claimed,
      linkedAuthUid: true,
    ),
    '+84907770011': MemberAccessContext(
      memberId: 'member_demo_elder_001',
      displayName: 'Ong Bao',
      clanId: 'clan_demo_001',
      branchId: 'branch_demo_002',
      primaryRole: 'MEMBER',
      accessMode: AuthMemberAccessMode.claimed,
      linkedAuthUid: true,
    ),
    '+84906660022': MemberAccessContext(
      memberId: null,
      displayName: 'Khach moi',
      clanId: null,
      branchId: null,
      primaryRole: 'GUEST',
      accessMode: AuthMemberAccessMode.unlinked,
      linkedAuthUid: false,
    ),
    '+84905550033': MemberAccessContext(
      memberId: null,
      displayName: 'Truong chi chua gan gia pha',
      clanId: null,
      branchId: null,
      primaryRole: 'BRANCH_ADMIN',
      accessMode: AuthMemberAccessMode.unlinked,
      linkedAuthUid: false,
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
    final normalizedPhone =
        PhoneNumberFormatter.tryParseE164(phoneE164) ?? phoneE164.trim();
    final memberAccess = await _memberAccessForPhone(normalizedPhone);
    return AuthOtpRequestResult.challenge(
      PendingOtpChallenge(
        loginMethod: AuthEntryMethod.phone,
        phoneE164: normalizedPhone,
        maskedDestination: PhoneNumberFormatter.mask(normalizedPhone),
        verificationId: 'debug-phone-$normalizedPhone',
        memberId: memberAccess.memberId,
        displayName: memberAccess.displayName ?? 'Thanh vien BeFam',
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
        message: 'Khong tim thay ho so tre em khop voi ma da nhap.',
      );
    }

    return AuthOtpRequestResult.challenge(
      PendingOtpChallenge(
        loginMethod: AuthEntryMethod.child,
        phoneE164: '',
        maskedDestination: resolved.maskedDestination,
        verificationId: 'debug-child-${resolved.childIdentifier}',
        childIdentifier: resolved.childIdentifier,
        memberId: resolved.memberId,
        displayName: resolved.displayName,
      ),
    );
  }

  @override
  Future<AuthOtpRequestResult> resendOtp(PendingOtpChallenge challenge) async {
    await Future<void>.delayed(_debugDelay);
    return AuthOtpRequestResult.challenge(
      challenge.copyWith(verificationId: '${challenge.verificationId}-resend'),
    );
  }

  @override
  Future<AuthOtpVerificationResult> verifyOtp(
    PendingOtpChallenge challenge,
    String smsCode, {
    String? languageCode,
  }) async {
    await Future<void>.delayed(_debugDelay);
    if (smsCode != _debugOtp) {
      throw FirebaseAuthException(
        code: 'invalid-verification-code',
        message: 'Ma OTP thu nghiem cho moi truong local la 123456.',
      );
    }

    final memberAccess = await _memberAccessFor(challenge);
    final session = AuthSession(
      uid: 'debug:${challenge.phoneE164}',
      loginMethod: challenge.loginMethod,
      phoneE164: challenge.phoneE164,
      displayName:
          memberAccess.displayName ??
          challenge.displayName ??
          'Thanh vien BeFam',
      childIdentifier: challenge.childIdentifier,
      memberId: memberAccess.memberId ?? challenge.memberId,
      clanId: memberAccess.clanId,
      branchId: memberAccess.branchId,
      primaryRole: memberAccess.primaryRole,
      accessMode: memberAccess.accessMode,
      linkedAuthUid: memberAccess.linkedAuthUid,
      isSandbox: true,
      signedInAtIso: DateTime.now().toIso8601String(),
    );
    return AuthOtpVerificationResult.session(session);
  }

  @override
  Future<AuthSession> createUnlinkedPhoneIdentity() async {
    await Future<void>.delayed(_debugDelay);
    return AuthSession(
      uid: 'debug:unlinked',
      loginMethod: AuthEntryMethod.phone,
      phoneE164: '+84900000000',
      displayName: 'Khach moi',
      memberId: null,
      clanId: null,
      branchId: null,
      primaryRole: 'GUEST',
      accessMode: AuthMemberAccessMode.unlinked,
      linkedAuthUid: false,
      isSandbox: true,
      signedInAtIso: DateTime.now().toIso8601String(),
    );
  }

  @override
  Future<MemberIdentityVerificationChallenge> startMemberIdentityVerification(
    String memberId, {
    String? languageCode,
  }) async {
    await Future<void>.delayed(_debugDelay);
    final useEnglish = (languageCode ?? '').trim().toLowerCase().startsWith(
      'en',
    );
    return MemberIdentityVerificationChallenge(
      verificationSessionId: 'debug-verification-$memberId',
      memberId: memberId,
      maxAttempts: 3,
      remainingAttempts: 3,
      questions: [
        MemberVerificationQuestion(
          id: 'debug-q1',
          category: 'personal',
          prompt: useEnglish
              ? 'What is the gender listed on this profile?'
              : 'Gioi tinh trong ho so nay la gi?',
          options: [
            MemberVerificationOption(
              id: 'a',
              label: useEnglish ? 'Male' : 'Nam',
            ),
            MemberVerificationOption(
              id: 'b',
              label: useEnglish ? 'Female' : 'Nu',
            ),
            MemberVerificationOption(
              id: 'c',
              label: useEnglish ? 'Other' : 'Khac',
            ),
          ],
        ),
        MemberVerificationQuestion(
          id: 'debug-q2',
          category: 'clan',
          prompt: useEnglish
              ? 'Which clan does this profile belong to?'
              : 'Ho so nay thuoc dong toc nao?',
          options: [
            MemberVerificationOption(
              id: 'a',
              label: useEnglish ? 'BeFam Clan' : 'Ho BeFam',
            ),
            MemberVerificationOption(
              id: 'b',
              label: useEnglish ? 'Nguyen Clan' : 'Ho Nguyen',
            ),
            MemberVerificationOption(
              id: 'c',
              label: useEnglish ? 'Tran Clan' : 'Ho Tran',
            ),
          ],
        ),
        MemberVerificationQuestion(
          id: 'debug-q3',
          category: 'personal',
          prompt: useEnglish
              ? 'Which month/year of birth is the closest match?'
              : 'Thang/nam sinh gan dung la gi?',
          options: [
            const MemberVerificationOption(id: 'a', label: '02/1988'),
            const MemberVerificationOption(id: 'b', label: '03/1988'),
            const MemberVerificationOption(id: 'c', label: '02/1989'),
          ],
        ),
      ],
    );
  }

  @override
  Future<MemberIdentityVerificationResult> submitMemberIdentityVerification({
    required String verificationSessionId,
    required Map<String, String> answers,
  }) async {
    await Future<void>.delayed(_debugDelay);
    final passed =
        answers['debug-q1'] == 'a' &&
        answers['debug-q2'] == 'a' &&
        answers['debug-q3'] == 'a';
    if (!passed) {
      return const MemberIdentityVerificationResult(
        passed: false,
        locked: false,
        remainingAttempts: 2,
        score: 0,
        requiredCorrect: 3,
      );
    }

    return MemberIdentityVerificationResult(
      passed: true,
      locked: false,
      remainingAttempts: 2,
      score: 3,
      requiredCorrect: 3,
      session: AuthSession(
        uid: 'debug:verified',
        loginMethod: AuthEntryMethod.phone,
        phoneE164: '+84901234567',
        displayName: 'Nguyen Minh',
        memberId: 'member_demo_parent_001',
        clanId: 'clan_demo_001',
        branchId: 'branch_demo_001',
        primaryRole: 'CLAN_ADMIN',
        accessMode: AuthMemberAccessMode.claimed,
        linkedAuthUid: true,
        isSandbox: true,
        signedInAtIso: DateTime.now().toIso8601String(),
      ),
    );
  }

  @override
  Future<void> signOut() async {}

  Future<MemberAccessContext> _memberAccessFor(
    PendingOtpChallenge challenge,
  ) async {
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

    return _memberAccessForPhone(challenge.phoneE164, challenge.displayName);
  }

  Future<MemberAccessContext> _memberAccessForPhone(
    String phoneE164, [
    String? fallbackDisplayName,
  ]) async {
    final remote = await _loadRemoteProfile(phoneE164);
    if (remote != null) {
      return remote;
    }
    for (final entry in _phoneDirectory.entries) {
      if (PhoneNumberFormatter.areEquivalent(entry.key, phoneE164)) {
        return entry.value;
      }
    }
    return MemberAccessContext(
      memberId: null,
      displayName: fallbackDisplayName,
      clanId: null,
      branchId: null,
      primaryRole: 'GUEST',
      accessMode: AuthMemberAccessMode.unlinked,
      linkedAuthUid: false,
    );
  }

  Future<MemberAccessContext?> _loadRemoteProfile(String phoneE164) async {
    if (_firestore == null) {
      return null;
    }

    try {
      final profiles = _firestore.collection('debug_login_profiles');
      final variants = PhoneNumberFormatter.lookupVariants(phoneE164);
      Map<String, dynamic>? data;
      for (final variant in variants) {
        final snapshot = await profiles.doc(variant).get();
        final candidate = snapshot.data();
        if (candidate == null) {
          continue;
        }
        data = candidate;
        break;
      }
      if (data == null ||
          data['isActive'] == false ||
          data['isTestUser'] != true) {
        return null;
      }

      final rawMode = (data['accessMode'] as String?)?.trim().toLowerCase();
      final accessMode = switch (rawMode) {
        'claimed' => AuthMemberAccessMode.claimed,
        'child' => AuthMemberAccessMode.child,
        _ => AuthMemberAccessMode.unlinked,
      };

      return MemberAccessContext(
        memberId: (data['memberId'] as String?)?.trim().isEmpty == true
            ? null
            : (data['memberId'] as String?),
        displayName: (data['displayName'] as String?)?.trim(),
        clanId: (data['clanId'] as String?)?.trim().isEmpty == true
            ? null
            : (data['clanId'] as String?),
        branchId: (data['branchId'] as String?)?.trim().isEmpty == true
            ? null
            : (data['branchId'] as String?),
        primaryRole: (data['primaryRole'] as String?)?.trim().isEmpty == true
            ? null
            : (data['primaryRole'] as String?),
        accessMode: accessMode,
        linkedAuthUid: data['linkedAuthUid'] == true,
      );
    } catch (_) {
      return null;
    }
  }
}
