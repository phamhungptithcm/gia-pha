import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/services/app_logger.dart';
import '../models/auth_entry_method.dart';
import '../models/auth_otp_request_result.dart';
import '../models/auth_session.dart';
import '../models/member_access_context.dart';
import '../models/pending_otp_challenge.dart';
import '../models/resolved_child_access.dart';
import 'auth_gateway.dart';
import 'phone_number_formatter.dart';

class FirebaseAuthGateway implements AuthGateway {
  FirebaseAuthGateway({FirebaseAuth? auth, FirebaseFunctions? functions})
    : _auth = auth ?? FirebaseAuth.instance,
      _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'asia-southeast1');

  final FirebaseAuth _auth;
  final FirebaseFunctions _functions;

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
              await _buildSession(
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
    final callable = _functions.httpsCallable('resolveChildLoginContext');
    final result = await callable.call(<String, dynamic>{
      'childIdentifier': childIdentifier,
    });
    final payload = (result.data as Map).map(
      (key, value) => MapEntry(key.toString(), value),
    );

    return ResolvedChildAccess(
      childIdentifier: payload['childIdentifier'] as String? ?? childIdentifier,
      parentPhoneE164: payload['parentPhoneE164'] as String,
      memberId: payload['memberId'] as String?,
      displayName: payload['displayName'] as String?,
      clanId: payload['clanId'] as String?,
      branchId: payload['branchId'] as String?,
      primaryRole: payload['primaryRole'] as String?,
    );
  }

  Future<MemberAccessContext> _claimMemberAccess(
    User user, {
    required AuthEntryMethod loginMethod,
    required String? childIdentifier,
    required String? memberId,
  }) async {
    final callable = _functions.httpsCallable('claimMemberRecord');
    final result = await callable.call(<String, dynamic>{
      'loginMethod': loginMethod.name,
      'childIdentifier': childIdentifier,
      'memberId': memberId,
    });

    await user.getIdToken(true);
    return MemberAccessContext.fromFunctionsData(result.data);
  }

  Future<AuthSession> _buildSession(
    User user, {
    required AuthEntryMethod loginMethod,
    required String phoneE164,
    String? childIdentifier,
    String? memberId,
    String? displayName,
  }) async {
    final memberAccess = await _claimMemberAccess(
      user,
      loginMethod: loginMethod,
      childIdentifier: childIdentifier,
      memberId: memberId,
    );

    return AuthSession(
      uid: user.uid,
      loginMethod: loginMethod,
      phoneE164: user.phoneNumber ?? phoneE164,
      displayName:
          memberAccess.displayName ??
          displayName ??
          user.displayName ??
          'BeFam Member',
      childIdentifier: childIdentifier,
      memberId: memberAccess.memberId ?? memberId,
      clanId: memberAccess.clanId,
      branchId: memberAccess.branchId,
      primaryRole: memberAccess.primaryRole,
      accessMode: memberAccess.accessMode,
      linkedAuthUid: memberAccess.linkedAuthUid,
      isSandbox: false,
      signedInAtIso: DateTime.now().toIso8601String(),
    );
  }
}
