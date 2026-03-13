import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/services/app_logger.dart';
import '../models/auth_entry_method.dart';
import '../models/auth_otp_request_result.dart';
import '../models/auth_session.dart';
import '../models/pending_otp_challenge.dart';
import '../models/resolved_child_access.dart';
import 'auth_gateway.dart';
import 'phone_number_formatter.dart';

class FirebaseAuthGateway implements AuthGateway {
  FirebaseAuthGateway({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  @override
  bool get isSandbox => false;

  @override
  Future<AuthOtpRequestResult> requestPhoneOtp(String phoneE164) {
    return _requestOtp(
      loginMethod: AuthEntryMethod.phone,
      phoneE164: phoneE164,
    );
  }

  @override
  Future<AuthOtpRequestResult> requestChildOtp(String childIdentifier) async {
    final resolved = await _resolveChildAccess(childIdentifier);
    return _requestOtp(
      loginMethod: AuthEntryMethod.child,
      phoneE164: resolved.parentPhoneE164,
      childIdentifier: resolved.childIdentifier,
      memberId: resolved.memberId,
      displayName: resolved.displayName,
    );
  }

  @override
  Future<AuthOtpRequestResult> resendOtp(PendingOtpChallenge challenge) {
    return _requestOtp(
      loginMethod: challenge.loginMethod,
      phoneE164: challenge.phoneE164,
      childIdentifier: challenge.childIdentifier,
      memberId: challenge.memberId,
      displayName: challenge.displayName,
      forceResendingToken: challenge.resendToken,
    );
  }

  @override
  Future<AuthSession> verifyOtp(
    PendingOtpChallenge challenge,
    String smsCode,
  ) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: challenge.verificationId,
      smsCode: smsCode,
    );
    final userCredential = await _auth.signInWithCredential(credential);
    final user = userCredential.user;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'unknown',
        message: 'Firebase did not return a signed-in user.',
      );
    }

    return _buildSession(
      user,
      loginMethod: challenge.loginMethod,
      phoneE164: challenge.phoneE164,
      childIdentifier: challenge.childIdentifier,
      memberId: challenge.memberId,
      displayName: challenge.displayName,
    );
  }

  @override
  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<AuthOtpRequestResult> _requestOtp({
    required AuthEntryMethod loginMethod,
    required String phoneE164,
    String? childIdentifier,
    String? memberId,
    String? displayName,
    int? forceResendingToken,
  }) async {
    final completer = Completer<AuthOtpRequestResult>();

    await _auth.verifyPhoneNumber(
      phoneNumber: phoneE164,
      forceResendingToken: forceResendingToken,
      verificationCompleted: (credential) async {
        if (completer.isCompleted) {
          return;
        }

        try {
          final userCredential = await _auth.signInWithCredential(credential);
          final user = userCredential.user;
          if (user == null) {
            completer.completeError(
              FirebaseAuthException(
                code: 'unknown',
                message: 'Firebase did not return a signed-in user.',
              ),
            );
            return;
          }

          completer.complete(
            AuthOtpRequestResult.session(
              _buildSession(
                user,
                loginMethod: loginMethod,
                phoneE164: phoneE164,
                childIdentifier: childIdentifier,
                memberId: memberId,
                displayName: displayName,
              ),
            ),
          );
        } catch (error) {
          completer.completeError(error);
        }
      },
      verificationFailed: (error) {
        if (!completer.isCompleted) {
          completer.completeError(error);
        }
      },
      codeSent: (verificationId, resendToken) {
        if (!completer.isCompleted) {
          completer.complete(
            AuthOtpRequestResult.challenge(
              PendingOtpChallenge(
                loginMethod: loginMethod,
                phoneE164: phoneE164,
                maskedDestination: PhoneNumberFormatter.mask(phoneE164),
                verificationId: verificationId,
                childIdentifier: childIdentifier,
                memberId: memberId,
                displayName: displayName,
                resendToken: resendToken,
              ),
            ),
          );
        }
      },
      codeAutoRetrievalTimeout: (verificationId) {
        if (!completer.isCompleted) {
          completer.complete(
            AuthOtpRequestResult.challenge(
              PendingOtpChallenge(
                loginMethod: loginMethod,
                phoneE164: phoneE164,
                maskedDestination: PhoneNumberFormatter.mask(phoneE164),
                verificationId: verificationId,
                childIdentifier: childIdentifier,
                memberId: memberId,
                displayName: displayName,
                resendToken: forceResendingToken,
              ),
            ),
          );
        }
      },
    );

    return completer.future.timeout(
      const Duration(seconds: 60),
      onTimeout: () {
        AppLogger.warning('Phone auth request timed out for $phoneE164.');
        throw FirebaseAuthException(
          code: 'session-expired',
          message: 'The verification session expired before the OTP arrived.',
        );
      },
    );
  }

  Future<ResolvedChildAccess> _resolveChildAccess(
    String childIdentifier,
  ) async {
    final inviteSnapshot = await _firestore
        .collection('invites')
        .where('childIdentifier', isEqualTo: childIdentifier)
        .limit(1)
        .get();

    if (inviteSnapshot.docs.isNotEmpty) {
      final invite = inviteSnapshot.docs.first.data();
      final phoneE164 = invite['phoneE164'] as String?;
      final memberId = invite['memberId'] as String?;
      if (phoneE164 == null || phoneE164.isEmpty) {
        throw FirebaseAuthException(
          code: 'user-not-found',
          message: 'This child identifier is not linked to a parent phone yet.',
        );
      }

      return ResolvedChildAccess(
        childIdentifier: childIdentifier,
        parentPhoneE164: phoneE164,
        memberId: memberId,
        displayName: await _loadMemberDisplayName(memberId),
      );
    }

    final memberSnapshot = await _firestore
        .collection('members')
        .doc(childIdentifier)
        .get();

    if (memberSnapshot.exists) {
      final member = memberSnapshot.data();
      final phoneE164 = member?['phoneE164'] as String?;
      if (phoneE164 != null && phoneE164.isNotEmpty) {
        return ResolvedChildAccess(
          childIdentifier: childIdentifier,
          parentPhoneE164: phoneE164,
          memberId: memberSnapshot.id,
          displayName: member?['fullName'] as String?,
        );
      }
    }

    throw FirebaseAuthException(
      code: 'user-not-found',
      message: 'No child record matches that identifier yet.',
    );
  }

  Future<String?> _loadMemberDisplayName(String? memberId) async {
    if (memberId == null || memberId.isEmpty) {
      return null;
    }

    final memberSnapshot = await _firestore
        .collection('members')
        .doc(memberId)
        .get();
    if (!memberSnapshot.exists) {
      return null;
    }

    final member = memberSnapshot.data();
    return member?['fullName'] as String?;
  }

  AuthSession _buildSession(
    User user, {
    required AuthEntryMethod loginMethod,
    required String phoneE164,
    String? childIdentifier,
    String? memberId,
    String? displayName,
  }) {
    return AuthSession(
      uid: user.uid,
      loginMethod: loginMethod,
      phoneE164: user.phoneNumber ?? phoneE164,
      displayName: displayName ?? user.displayName ?? 'BeFam Member',
      childIdentifier: childIdentifier,
      memberId: memberId,
      isSandbox: false,
      signedInAtIso: DateTime.now().toIso8601String(),
    );
  }
}
