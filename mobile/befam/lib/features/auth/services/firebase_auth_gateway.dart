import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../../core/services/app_logger.dart';
import '../../../core/services/app_environment.dart';
import '../models/auth_issue.dart';
import '../models/auth_entry_method.dart';
import '../models/auth_member_access_mode.dart';
import '../models/auth_otp_request_result.dart';
import '../models/auth_session.dart';
import '../models/member_access_context.dart';
import '../models/pending_otp_challenge.dart';
import '../models/resolved_child_access.dart';
import 'auth_gateway.dart';
import 'phone_number_formatter.dart';

class FirebaseAuthGateway implements AuthGateway {
  FirebaseAuthGateway({
    FirebaseAuth? auth,
    FirebaseFunctions? functions,
    FirebaseFirestore? firestore,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _functions =
           functions ??
           FirebaseFunctions.instanceFor(
             region: AppEnvironment.firebaseFunctionsRegion,
           ),
       _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFunctions _functions;
  final FirebaseFirestore _firestore;
  static bool _debugPhoneAuthConfigured = false;
  final Map<String, ConfirmationResult> _webConfirmationResults =
      <String, ConfirmationResult>{};

  CollectionReference<Map<String, dynamic>> get _members =>
      _firestore.collection('members');

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  @override
  bool get isSandbox => false;

  @override
  Future<bool> canRestoreSession(AuthSession session) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null || currentUser.uid != session.uid) {
      return false;
    }

    try {
      await currentUser.getIdToken(false);
      return true;
    } catch (error, stackTrace) {
      AppLogger.warning(
        'Persisted auth session token refresh failed; restoring session is blocked.',
        error,
        stackTrace,
      );
      return false;
    }
  }

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
    if (kIsWeb) {
      final confirmationResult = _webConfirmationResults.remove(
        challenge.verificationId,
      );
      if (confirmationResult != null) {
        final userCredential = await confirmationResult.confirm(smsCode);
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
    }

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
    final requestTag =
        'firebase_otp_${DateTime.now().millisecondsSinceEpoch}_${loginMethod.name}';
    AppLogger.info(
      '[$requestTag] Preparing Firebase OTP request (method=${loginMethod.name}, phone=$phoneE164, forceResendingToken=${forceResendingToken ?? 'none'}).',
    );

    final debugSession = await _signInWithDebugProfileTokenIfAvailable(
      requestTag: requestTag,
      loginMethod: loginMethod,
      phoneE164: phoneE164,
      childIdentifier: childIdentifier,
      memberId: memberId,
      displayName: displayName,
      forceResendingToken: forceResendingToken,
    );
    if (debugSession != null) {
      return AuthOtpRequestResult.session(debugSession);
    }

    if (kIsWeb) {
      return _requestOtpOnWeb(
        requestTag: requestTag,
        loginMethod: loginMethod,
        phoneE164: phoneE164,
        childIdentifier: childIdentifier,
        memberId: memberId,
        displayName: displayName,
      );
    }

    await _configurePhoneAuthForDebugIfNeeded();
    _logPhoneAuthPreflight(requestTag);
    final completer = Completer<AuthOtpRequestResult>();

    try {
      AppLogger.info('[$requestTag] Calling FirebaseAuth.verifyPhoneNumber.');
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneE164,
        forceResendingToken: forceResendingToken,
        verificationCompleted: (credential) async {
          if (completer.isCompleted) {
            return;
          }

          AppLogger.info(
            '[$requestTag] verificationCompleted callback received.',
          );
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
          } catch (error, stackTrace) {
            AppLogger.error(
              '[$requestTag] Failed to complete auto verification.',
              error,
              stackTrace,
            );
            completer.completeError(error);
          }
        },
        verificationFailed: (error) {
          AppLogger.warning(
            '[$requestTag] verificationFailed callback.',
            error,
            StackTrace.current,
          );
          if (!completer.isCompleted) {
            completer.completeError(error);
          }
        },
        codeSent: (verificationId, resendToken) {
          AppLogger.info(
            '[$requestTag] codeSent callback (verificationId=$verificationId, resendToken=${resendToken ?? 'none'}).',
          );
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
          AppLogger.info(
            '[$requestTag] codeAutoRetrievalTimeout callback (verificationId=$verificationId).',
          );
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
      AppLogger.info(
        '[$requestTag] verifyPhoneNumber call returned to Dart layer.',
      );
    } catch (error, stackTrace) {
      AppLogger.error(
        '[$requestTag] verifyPhoneNumber threw before callbacks.',
        error,
        stackTrace,
      );
      rethrow;
    }

    return completer.future.timeout(
      const Duration(seconds: 60),
      onTimeout: () {
        AppLogger.warning(
          '[$requestTag] Phone auth request timed out for $phoneE164.',
        );
        throw FirebaseAuthException(
          code: 'session-expired',
          message: 'The verification session expired before the OTP arrived.',
        );
      },
    );
  }

  Future<AuthOtpRequestResult> _requestOtpOnWeb({
    required String requestTag,
    required AuthEntryMethod loginMethod,
    required String phoneE164,
    String? childIdentifier,
    String? memberId,
    String? displayName,
  }) async {
    AppLogger.info('[$requestTag] Calling FirebaseAuth.signInWithPhoneNumber.');
    final confirmationResult = await _auth.signInWithPhoneNumber(phoneE164);
    final verificationId = confirmationResult.verificationId.trim();
    if (verificationId.isEmpty) {
      throw FirebaseAuthException(
        code: 'session-expired',
        message:
            'The verification session expired before the OTP challenge was created.',
      );
    }
    _webConfirmationResults[verificationId] = confirmationResult;
    while (_webConfirmationResults.length > 20) {
      final oldestKey = _webConfirmationResults.keys.first;
      _webConfirmationResults.remove(oldestKey);
    }

    AppLogger.info(
      '[$requestTag] Web OTP challenge created (verificationId=$verificationId).',
    );

    return AuthOtpRequestResult.challenge(
      PendingOtpChallenge(
        loginMethod: loginMethod,
        phoneE164: phoneE164,
        maskedDestination: PhoneNumberFormatter.mask(phoneE164),
        verificationId: verificationId,
        childIdentifier: childIdentifier,
        memberId: memberId,
        displayName: displayName,
      ),
    );
  }

  Future<void> _configurePhoneAuthForDebugIfNeeded() async {
    if (!kDebugMode || _debugPhoneAuthConfigured) {
      return;
    }
    _debugPhoneAuthConfigured = true;
    try {
      await _auth.setSettings(appVerificationDisabledForTesting: true);
      AppLogger.info(
        'Enabled FirebaseAuth test phone verification for debug mode.',
      );
    } catch (error, stackTrace) {
      AppLogger.warning(
        'Could not enable FirebaseAuth test phone verification in debug.',
        error,
        stackTrace,
      );
    }
  }

  void _logPhoneAuthPreflight(String requestTag) {
    if (!kDebugMode || kIsWeb) {
      return;
    }
    final app = _auth.app;
    final googleAppId = app.options.appId;
    final expectedIosCallbackScheme = 'app-${googleAppId.replaceAll(':', '-')}';
    AppLogger.info(
      '[$requestTag] PhoneAuth preflight (platform=${defaultTargetPlatform.name}, firebaseApp=${app.name}, iosBundleId=${app.options.iosBundleId}, googleAppId=$googleAppId, expectedIosCallbackScheme=$expectedIosCallbackScheme, debugPhoneAuthConfigured=$_debugPhoneAuthConfigured).',
    );
  }

  Future<AuthSession?> _signInWithDebugProfileTokenIfAvailable({
    required String requestTag,
    required AuthEntryMethod loginMethod,
    required String phoneE164,
    required String? childIdentifier,
    required String? memberId,
    required String? displayName,
    required int? forceResendingToken,
  }) async {
    if (!kDebugMode ||
        loginMethod != AuthEntryMethod.phone ||
        forceResendingToken != null) {
      return null;
    }

    try {
      final callable = _functions.httpsCallable('issueDebugProfileCustomToken');
      final result = await callable.call(<String, dynamic>{
        'phoneE164': phoneE164,
      });
      final payload = (result.data as Map).map(
        (key, value) => MapEntry(key.toString(), value),
      );
      final customToken = (payload['customToken'] as String?)?.trim() ?? '';
      if (customToken.isEmpty) {
        AppLogger.warning(
          '[$requestTag] Debug profile token callable returned an empty token.',
        );
        return null;
      }

      final resolvedMemberId = (payload['memberId'] as String?)?.trim();
      final resolvedDisplayName = (payload['displayName'] as String?)?.trim();
      AppLogger.info(
        '[$requestTag] Using debug profile custom token sign-in for $phoneE164.',
      );

      final userCredential = await _auth.signInWithCustomToken(customToken);
      final user = userCredential.user;
      if (user == null) {
        throw FirebaseAuthException(
          code: 'unknown',
          message: 'Firebase did not return a signed-in user for debug token.',
        );
      }

      return _buildSession(
        user,
        loginMethod: loginMethod,
        phoneE164: phoneE164,
        childIdentifier: childIdentifier,
        memberId: (resolvedMemberId?.isNotEmpty ?? false)
            ? resolvedMemberId
            : memberId,
        displayName: (resolvedDisplayName?.isNotEmpty ?? false)
            ? resolvedDisplayName
            : displayName,
      );
    } on FirebaseFunctionsException catch (error, stackTrace) {
      if (_isExpectedDebugBypassMiss(error.code)) {
        AppLogger.info(
          '[$requestTag] Debug profile token bypass not available (${error.code}). Falling back to phone OTP flow.',
        );
        return null;
      }
      AppLogger.warning(
        '[$requestTag] Debug profile token bypass failed unexpectedly.',
        error,
        stackTrace,
      );
      rethrow;
    }
  }

  bool _isExpectedDebugBypassMiss(String code) {
    return code == 'not-found' ||
        code == 'permission-denied' ||
        code == 'unimplemented' ||
        code == 'failed-precondition';
  }

  Future<ResolvedChildAccess> _resolveChildAccess(
    String childIdentifier,
  ) async {
    try {
      final callable = _functions.httpsCallable('resolveChildLoginContext');
      final result = await callable.call(<String, dynamic>{
        'childIdentifier': childIdentifier,
      });
      final payload = (result.data as Map).map(
        (key, value) => MapEntry(key.toString(), value),
      );

      return ResolvedChildAccess(
        childIdentifier:
            payload['childIdentifier'] as String? ?? childIdentifier,
        parentPhoneE164: payload['parentPhoneE164'] as String,
        memberId: payload['memberId'] as String?,
        displayName: payload['displayName'] as String?,
        clanId: payload['clanId'] as String?,
        branchId: payload['branchId'] as String?,
        primaryRole: payload['primaryRole'] as String?,
      );
    } on FirebaseFunctionsException {
      rethrow;
    }
  }

  Future<MemberAccessContext> _claimMemberAccess(
    User user, {
    required AuthEntryMethod loginMethod,
    required String? childIdentifier,
    required String? memberId,
  }) async {
    try {
      final callable = _functions.httpsCallable('claimMemberRecord');
      final result = await callable.call(<String, dynamic>{
        'loginMethod': loginMethod.name,
        'childIdentifier': childIdentifier,
        'memberId': memberId,
      });

      await user.getIdToken(true);
      return MemberAccessContext.fromFunctionsData(result.data);
    } on FirebaseFunctionsException catch (error) {
      if (!_shouldUseClientFallback(error.code)) {
        rethrow;
      }

      AppLogger.warning(
        'claimMemberRecord callable unavailable; using client fallback claim flow.',
      );
      return _claimMemberAccessWithoutFunctions(
        user,
        loginMethod: loginMethod,
        childIdentifier: childIdentifier,
        memberId: memberId,
      );
    }
  }

  Future<MemberAccessContext> _claimMemberAccessWithoutFunctions(
    User user, {
    required AuthEntryMethod loginMethod,
    required String? childIdentifier,
    required String? memberId,
  }) async {
    final authPhone = (user.phoneNumber ?? '').trim();
    if (authPhone.isEmpty) {
      throw const AuthIssueException(AuthIssue(AuthIssueKey.userNotFound));
    }

    if (loginMethod == AuthEntryMethod.child) {
      final resolvedMemberId = memberId?.trim();
      if (resolvedMemberId == null || resolvedMemberId.isEmpty) {
        throw const AuthIssueException(
          AuthIssue(AuthIssueKey.childAccessNotReady),
        );
      }

      final memberSnapshot = await _members.doc(resolvedMemberId).get();
      final data = memberSnapshot.data();
      if (!memberSnapshot.exists || data == null) {
        throw const AuthIssueException(AuthIssue(AuthIssueKey.userNotFound));
      }

      final context = MemberAccessContext(
        memberId: memberSnapshot.id,
        displayName: _pickDisplayName(data),
        clanId: data['clanId'] as String?,
        branchId: data['branchId'] as String?,
        primaryRole: data['primaryRole'] as String? ?? 'MEMBER',
        accessMode: AuthMemberAccessMode.child,
        linkedAuthUid: false,
      );
      await _writeUserSessionDocument(user.uid, context);
      return context;
    }

    final matchingMembers = await _members
        .where('phoneE164', isEqualTo: authPhone)
        .limit(3)
        .get();

    if (matchingMembers.docs.isEmpty) {
      final context = MemberAccessContext.unlinked(
        displayName: user.displayName ?? 'BeFam Member',
      );
      await _writeUserSessionDocument(user.uid, context);
      return context;
    }

    if (matchingMembers.docs.length > 1) {
      final linkedToCurrent = matchingMembers.docs.firstWhere(
        (doc) => (doc.data()['authUid'] as String?) == user.uid,
        orElse: () => matchingMembers.docs.first,
      );
      if ((linkedToCurrent.data()['authUid'] as String?) != user.uid &&
          matchingMembers.docs
              .where((doc) => (doc.data()['authUid'] as String?) == user.uid)
              .isEmpty) {
        throw const AuthIssueException(
          AuthIssue(AuthIssueKey.memberClaimConflict),
        );
      }
    }

    final selected = matchingMembers.docs.firstWhere(
      (doc) => (doc.data()['authUid'] as String?) == user.uid,
      orElse: () => matchingMembers.docs.first,
    );
    final selectedData = selected.data();
    final existingAuthUid = (selectedData['authUid'] as String?)?.trim();
    if (existingAuthUid != null &&
        existingAuthUid.isNotEmpty &&
        existingAuthUid != user.uid) {
      throw const AuthIssueException(
        AuthIssue(AuthIssueKey.memberAlreadyLinked),
      );
    }

    final now = FieldValue.serverTimestamp();
    await selected.reference.set({
      'authUid': user.uid,
      'claimedAt': now,
      'updatedAt': now,
      'updatedBy': user.uid,
    }, SetOptions(merge: true));

    final context = MemberAccessContext(
      memberId: selected.id,
      displayName: _pickDisplayName(selectedData),
      clanId: selectedData['clanId'] as String?,
      branchId: selectedData['branchId'] as String?,
      primaryRole: selectedData['primaryRole'] as String? ?? 'MEMBER',
      accessMode: AuthMemberAccessMode.claimed,
      linkedAuthUid: true,
    );
    await _writeUserSessionDocument(user.uid, context);
    return context;
  }

  Future<void> _writeUserSessionDocument(
    String uid,
    MemberAccessContext context,
  ) async {
    final now = FieldValue.serverTimestamp();
    await _users.doc(uid).set({
      'uid': uid,
      'memberId': context.memberId ?? '',
      'clanId': context.clanId ?? '',
      'clanIds': context.clanId == null ? <String>[] : [context.clanId!],
      'branchId': context.branchId ?? '',
      'primaryRole': context.primaryRole ?? 'GUEST',
      'accessMode': context.accessMode.name,
      'linkedAuthUid': context.linkedAuthUid,
      'updatedAt': now,
      'createdAt': now,
    }, SetOptions(merge: true));
  }

  bool _shouldUseClientFallback(String code) {
    return code == 'not-found' ||
        code == 'unimplemented' ||
        code == 'unavailable';
  }

  String _pickDisplayName(Map<String, dynamic> data) {
    final fullName = (data['fullName'] as String?)?.trim() ?? '';
    if (fullName.isNotEmpty) {
      return fullName;
    }
    final nickName = (data['nickName'] as String?)?.trim() ?? '';
    if (nickName.isNotEmpty) {
      return nickName;
    }
    return 'BeFam Member';
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
