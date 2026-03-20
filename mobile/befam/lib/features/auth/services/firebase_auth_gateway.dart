import 'dart:async';
import 'dart:ui' as ui;

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
import '../models/auth_otp_verification_result.dart';
import '../models/auth_session.dart';
import '../models/member_identity_verification.dart';
import '../models/member_access_context.dart';
import '../models/pending_otp_challenge.dart';
import '../models/phone_identity_resolution.dart';
import '../models/resolved_child_access.dart';
import 'auth_gateway.dart';
import 'auth_trusted_device_store.dart';
import 'phone_number_formatter.dart';

class FirebaseAuthGateway implements AuthGateway {
  FirebaseAuthGateway({
    FirebaseAuth? auth,
    FirebaseFunctions? functions,
    FirebaseFirestore? firestore,
    AuthTrustedDeviceStore? trustedDeviceStore,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _functions =
           functions ??
           FirebaseFunctions.instanceFor(
             region: AppEnvironment.firebaseFunctionsRegion,
           ),
       _firestore = firestore ?? FirebaseFirestore.instance,
       _trustedDeviceStore =
           trustedDeviceStore ?? SharedPrefsAuthTrustedDeviceStore();

  final FirebaseAuth _auth;
  final FirebaseFunctions _functions;
  final FirebaseFirestore _firestore;
  final AuthTrustedDeviceStore _trustedDeviceStore;
  static bool _phoneAuthSettingsConfigured = false;
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
  Future<AuthOtpVerificationResult> verifyOtp(
    PendingOtpChallenge challenge,
    String smsCode, {
    String? languageCode,
  }) async {
    final serverResult = await _verifyOtpViaServer(
      challenge: challenge,
      smsCode: smsCode,
      languageCode: languageCode,
    );
    if (serverResult != null) {
      return serverResult;
    }

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
        return _handleVerifiedUser(
          user,
          loginMethod: challenge.loginMethod,
          phoneE164: challenge.phoneE164,
          childIdentifier: challenge.childIdentifier,
          memberId: challenge.memberId,
          displayName: challenge.displayName,
          languageCode: languageCode,
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

    return _handleVerifiedUser(
      user,
      loginMethod: challenge.loginMethod,
      phoneE164: challenge.phoneE164,
      childIdentifier: challenge.childIdentifier,
      memberId: challenge.memberId,
      displayName: challenge.displayName,
      languageCode: languageCode,
    );
  }

  @override
  Future<void> signOut() async {
    await _auth.signOut();
  }

  @override
  Future<AuthSession> createUnlinkedPhoneIdentity() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'No signed-in Firebase user is available.',
      );
    }
    final phoneE164 = _normalizePhoneOrNull(user.phoneNumber);
    if (phoneE164.isEmpty) {
      throw const AuthIssueException(AuthIssue(AuthIssueKey.userNotFound));
    }
    final deviceToken = await _trustedDeviceStore.readOrCreateDeviceToken();
    final callable = _functions.httpsCallable('createUnlinkedPhoneIdentity');
    try {
      final result = await callable.call(<String, dynamic>{
        'deviceToken': deviceToken,
      });
      final payload = (result.data is Map)
          ? (result.data as Map).map(
              (key, value) => MapEntry(key.toString(), value),
            )
          : const <String, dynamic>{};
      final contextMap = payload['context'];
      final context = MemberAccessContext.fromFunctionsData(contextMap);
      await _refreshSessionTokenBestEffort(user);
      final normalizedUserPhone = _normalizePhoneOrNull(user.phoneNumber);
      return AuthSession(
        uid: user.uid,
        loginMethod: AuthEntryMethod.phone,
        phoneE164: normalizedUserPhone.isEmpty
            ? phoneE164
            : normalizedUserPhone,
        displayName: context.displayName ?? user.displayName ?? 'BeFam Member',
        childIdentifier: null,
        memberId: context.memberId,
        clanId: context.clanId,
        branchId: context.branchId,
        primaryRole: context.primaryRole,
        accessMode: context.accessMode,
        linkedAuthUid: context.linkedAuthUid,
        isSandbox: false,
        signedInAtIso: DateTime.now().toIso8601String(),
      );
    } on FirebaseFunctionsException catch (error, stackTrace) {
      if (!_shouldUseClientFallback(error.code, message: error.message)) {
        rethrow;
      }
      AppLogger.warning(
        'createUnlinkedPhoneIdentity callable unavailable; using client fallback unlinked session.',
        error,
        stackTrace,
      );
      final fallbackNormalizedPhone = _normalizePhoneOrNull(user.phoneNumber);
      return _buildUnlinkedSessionWithBestEffortSync(
        user,
        phoneE164: fallbackNormalizedPhone.isEmpty
            ? phoneE164
            : fallbackNormalizedPhone,
      );
    }
  }

  @override
  Future<MemberIdentityVerificationChallenge> startMemberIdentityVerification(
    String memberId, {
    String? languageCode,
  }) async {
    final normalizedMemberId = memberId.trim();
    if (normalizedMemberId.isEmpty) {
      throw const AuthIssueException(AuthIssue(AuthIssueKey.preparationFailed));
    }
    final deviceToken = await _trustedDeviceStore.readOrCreateDeviceToken();
    final callable = _functions.httpsCallable(
      'startMemberIdentityVerification',
    );
    final result = await callable.call(<String, dynamic>{
      'memberId': normalizedMemberId,
      'deviceToken': deviceToken,
      'languageCode': _normalizeLanguageCode(languageCode),
    });
    final payload = (result.data as Map).map(
      (key, value) => MapEntry(key.toString(), value),
    );
    return MemberIdentityVerificationChallenge.fromMap(payload);
  }

  @override
  Future<MemberIdentityVerificationResult> submitMemberIdentityVerification({
    required String verificationSessionId,
    required Map<String, String> answers,
  }) async {
    final callable = _functions.httpsCallable(
      'submitMemberIdentityVerification',
    );
    final result = await callable.call(<String, dynamic>{
      'verificationSessionId': verificationSessionId,
      'answers': answers,
    });
    final payload = (result.data is Map)
        ? (result.data as Map).map(
            (key, value) => MapEntry(key.toString(), value),
          )
        : const <String, dynamic>{};

    final passed = payload['passed'] == true;
    final contextPayload = payload['context'];
    AuthSession? session;
    if (passed && contextPayload is Map) {
      final user = _auth.currentUser;
      if (user == null) {
        throw FirebaseAuthException(
          code: 'user-not-found',
          message: 'No signed-in Firebase user is available.',
        );
      }
      final context = MemberAccessContext.fromFunctionsData(contextPayload);
      await _refreshSessionTokenBestEffort(user);
      final normalizedUserPhone = _normalizePhoneOrNull(user.phoneNumber);
      session = AuthSession(
        uid: user.uid,
        loginMethod: AuthEntryMethod.phone,
        phoneE164: normalizedUserPhone,
        displayName: context.displayName ?? user.displayName ?? 'BeFam Member',
        childIdentifier: null,
        memberId: context.memberId,
        clanId: context.clanId,
        branchId: context.branchId,
        primaryRole: context.primaryRole,
        accessMode: context.accessMode,
        linkedAuthUid: context.linkedAuthUid,
        isSandbox: false,
        signedInAtIso: DateTime.now().toIso8601String(),
      );
    }

    int parseInt(dynamic value, int fallback) {
      if (value is int) {
        return value;
      }
      if (value is num) {
        return value.toInt();
      }
      return fallback;
    }

    return MemberIdentityVerificationResult(
      passed: passed,
      locked: payload['locked'] == true,
      remainingAttempts: parseInt(payload['remainingAttempts'], 0),
      score: parseInt(payload['score'], 0),
      requiredCorrect: parseInt(payload['requiredCorrect'], 3),
      session: session,
    );
  }

  Future<AuthOtpVerificationResult> _handleVerifiedUser(
    User user, {
    required AuthEntryMethod loginMethod,
    required String phoneE164,
    required String? childIdentifier,
    required String? memberId,
    required String? displayName,
    String? languageCode,
  }) async {
    if (loginMethod == AuthEntryMethod.child) {
      final session = await _buildSession(
        user,
        loginMethod: loginMethod,
        phoneE164: phoneE164,
        childIdentifier: childIdentifier,
        memberId: memberId,
        displayName: displayName,
      );
      return AuthOtpVerificationResult.session(session);
    }

    final deviceToken = await _trustedDeviceStore.readOrCreateDeviceToken();
    final callable = _functions.httpsCallable('resolvePhoneIdentityAfterOtp');
    Map<String, dynamic> payload;
    try {
      final result = await callable.call(<String, dynamic>{
        'deviceToken': deviceToken,
        'languageCode': _normalizeLanguageCode(languageCode),
      });
      payload = (result.data is Map)
          ? (result.data as Map).map(
              (key, value) => MapEntry(key.toString(), value),
            )
          : const <String, dynamic>{};
    } on FirebaseFunctionsException catch (error, stackTrace) {
      if (!_shouldUseClientFallback(error.code, message: error.message)) {
        rethrow;
      }
      AppLogger.warning(
        'resolvePhoneIdentityAfterOtp callable unavailable; using compatibility fallback.',
        error,
        stackTrace,
      );
      final fallbackSession = await _resolvePhoneOtpCompatibilitySession(
        user,
        phoneE164: phoneE164,
        childIdentifier: childIdentifier,
        memberId: memberId,
        displayName: displayName,
      );
      return AuthOtpVerificationResult.session(fallbackSession);
    }
    final status = (payload['status'] as String?)?.trim().toLowerCase() ?? '';
    final contextPayload = payload['context'];
    if (status == 'resolved' && contextPayload is Map) {
      final context = MemberAccessContext.fromFunctionsData(contextPayload);
      await _refreshSessionTokenBestEffort(user);
      final normalizedUserPhone = _normalizePhoneOrNull(user.phoneNumber);
      final session = AuthSession(
        uid: user.uid,
        loginMethod: loginMethod,
        phoneE164: normalizedUserPhone.isEmpty
            ? phoneE164
            : normalizedUserPhone,
        displayName: context.displayName ?? user.displayName ?? 'BeFam Member',
        childIdentifier: childIdentifier,
        memberId: context.memberId ?? memberId,
        clanId: context.clanId,
        branchId: context.branchId,
        primaryRole: context.primaryRole,
        accessMode: context.accessMode,
        linkedAuthUid: context.linkedAuthUid,
        isSandbox: false,
        signedInAtIso: DateTime.now().toIso8601String(),
      );
      return AuthOtpVerificationResult.session(session);
    }

    final rawCandidates = payload['candidates'];
    final candidates = rawCandidates is List
        ? rawCandidates
              .whereType<Map>()
              .map(
                (entry) =>
                    entry.map((key, value) => MapEntry(key.toString(), value)),
              )
              .map(PhoneIdentityCandidate.fromMap)
              .where((candidate) => candidate.memberId.isNotEmpty)
              .toList(growable: false)
        : const <PhoneIdentityCandidate>[];
    final normalizedUserPhone = _normalizePhoneOrNull(user.phoneNumber);
    final resolution = PhoneIdentityResolution(
      status: status == 'create_new_only'
          ? PhoneIdentityResolutionStatus.createNewOnly
          : PhoneIdentityResolutionStatus.needsSelection,
      phoneE164: (payload['phoneE164'] as String?)?.trim().isNotEmpty == true
          ? (payload['phoneE164'] as String).trim()
          : (normalizedUserPhone.isEmpty ? phoneE164 : normalizedUserPhone),
      allowCreateNew: payload['allowCreateNew'] != false,
      candidates: candidates,
    );
    return AuthOtpVerificationResult.phoneResolution(resolution);
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
        'otp_${DateTime.now().millisecondsSinceEpoch}_${loginMethod.name}';
    AppLogger.info(
      '[$requestTag] Preparing OTP request (method=${loginMethod.name}, phone=$phoneE164, forceResendingToken=${forceResendingToken ?? 'none'}).',
    );

    final serverResult = await _requestOtpViaServer(
      requestTag: requestTag,
      loginMethod: loginMethod,
      phoneE164: phoneE164,
      childIdentifier: childIdentifier,
      memberId: memberId,
      displayName: displayName,
    );
    if (serverResult != null) {
      return serverResult;
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

    await _configurePhoneAuthSettings();
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
          if (loginMethod == AuthEntryMethod.phone) {
            AppLogger.info(
              '[$requestTag] Skipping auto-complete for phone login to preserve identity reconciliation flow.',
            );
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

  Future<AuthOtpRequestResult?> _requestOtpViaServer({
    required String requestTag,
    required AuthEntryMethod loginMethod,
    required String phoneE164,
    String? childIdentifier,
    String? memberId,
    String? displayName,
  }) async {
    final callable = _functions.httpsCallable('requestOtpChallenge');
    try {
      final payload = <String, dynamic>{
        'loginMethod': loginMethod.name,
        'languageCode': _preferredLanguageCode(),
      };
      if (loginMethod == AuthEntryMethod.child) {
        payload['childIdentifier'] = childIdentifier;
      } else {
        payload['phoneE164'] = phoneE164;
      }
      if ((memberId ?? '').trim().isNotEmpty) {
        payload['memberId'] = memberId!.trim();
      }
      if ((displayName ?? '').trim().isNotEmpty) {
        payload['displayName'] = displayName!.trim();
      }

      final result = await callable.call(payload);
      final data = (result.data is Map)
          ? (result.data as Map).map(
              (key, value) => MapEntry(key.toString(), value),
            )
          : const <String, dynamic>{};
      final verificationId =
          (data['verificationId'] as String?)?.trim() ?? '';
      if (verificationId.isEmpty) {
        throw FirebaseFunctionsException(
          code: 'internal',
          message: 'requestOtpChallenge did not return verificationId.',
        );
      }
      final maskedDestination =
          (data['maskedDestination'] as String?)?.trim().isNotEmpty == true
          ? (data['maskedDestination'] as String).trim()
          : PhoneNumberFormatter.mask(phoneE164);
      final resolvedPhone =
          (data['phoneE164'] as String?)?.trim().isNotEmpty == true
          ? (data['phoneE164'] as String).trim()
          : phoneE164;
      final resolvedChildIdentifier =
          (data['childIdentifier'] as String?)?.trim().isNotEmpty == true
          ? (data['childIdentifier'] as String).trim()
          : childIdentifier;
      final resolvedMemberId =
          (data['memberId'] as String?)?.trim().isNotEmpty == true
          ? (data['memberId'] as String).trim()
          : memberId;
      final resolvedDisplayName =
          (data['displayName'] as String?)?.trim().isNotEmpty == true
          ? (data['displayName'] as String).trim()
          : displayName;

      AppLogger.info(
        '[$requestTag] OTP challenge created by server provider.',
      );
      return AuthOtpRequestResult.challenge(
        PendingOtpChallenge(
          loginMethod: loginMethod,
          phoneE164: resolvedPhone,
          maskedDestination: maskedDestination,
          verificationId: verificationId,
          childIdentifier: resolvedChildIdentifier,
          memberId: resolvedMemberId,
          displayName: resolvedDisplayName,
        ),
      );
    } on FirebaseFunctionsException catch (error, stackTrace) {
      if (!_shouldUseClientFallback(error.code, message: error.message)) {
        rethrow;
      }
      AppLogger.warning(
        '[$requestTag] requestOtpChallenge callable unavailable; fallback to Firebase phone auth.',
        error,
        stackTrace,
      );
      return null;
    }
  }

  Future<AuthOtpVerificationResult?> _verifyOtpViaServer({
    required PendingOtpChallenge challenge,
    required String smsCode,
    String? languageCode,
  }) async {
    final callable = _functions.httpsCallable('verifyOtpChallenge');
    try {
      final result = await callable.call(<String, dynamic>{
        'verificationId': challenge.verificationId,
        'smsCode': smsCode,
        'languageCode': _normalizeLanguageCode(languageCode),
      });
      final payload = (result.data is Map)
          ? (result.data as Map).map(
              (key, value) => MapEntry(key.toString(), value),
            )
          : const <String, dynamic>{};
      final status = (payload['status'] as String?)?.trim().toLowerCase() ?? '';
      if (status != 'approved') {
        throw FirebaseFunctionsException(
          code: 'failed-precondition',
          message: 'verifyOtpChallenge returned non-approved status.',
        );
      }
      final customToken = (payload['customToken'] as String?)?.trim() ?? '';
      if (customToken.isEmpty) {
        throw FirebaseFunctionsException(
          code: 'internal',
          message: 'verifyOtpChallenge did not return customToken.',
        );
      }
      final phoneFromPayload =
          (payload['phoneE164'] as String?)?.trim().isNotEmpty == true
          ? (payload['phoneE164'] as String).trim()
          : challenge.phoneE164;
      final childIdentifier =
          (payload['childIdentifier'] as String?)?.trim().isNotEmpty == true
          ? (payload['childIdentifier'] as String).trim()
          : challenge.childIdentifier;
      final memberId = (payload['memberId'] as String?)?.trim().isNotEmpty == true
          ? (payload['memberId'] as String).trim()
          : challenge.memberId;
      final displayName =
          (payload['displayName'] as String?)?.trim().isNotEmpty == true
          ? (payload['displayName'] as String).trim()
          : challenge.displayName;

      final userCredential = await _auth.signInWithCustomToken(customToken);
      final user = userCredential.user;
      if (user == null) {
        throw FirebaseAuthException(
          code: 'user-not-found',
          message: 'Custom token sign-in did not return a user.',
        );
      }

      return _handleVerifiedUser(
        user,
        loginMethod: challenge.loginMethod,
        phoneE164: phoneFromPayload,
        childIdentifier: childIdentifier,
        memberId: memberId,
        displayName: displayName,
        languageCode: languageCode,
      );
    } on FirebaseFunctionsException catch (error, stackTrace) {
      if (!_shouldUseClientFallback(error.code, message: error.message)) {
        rethrow;
      }
      AppLogger.warning(
        'verifyOtpChallenge callable unavailable; fallback to Firebase phone auth.',
        error,
        stackTrace,
      );
      return null;
    }
  }

  String _preferredLanguageCode() {
    final languageCode = ui.PlatformDispatcher.instance.locale.languageCode
        .trim()
        .toLowerCase();
    return languageCode.startsWith('en') ? 'en' : 'vi';
  }

  String _normalizeLanguageCode(String? languageCode) {
    final normalized = languageCode?.trim().toLowerCase() ?? '';
    if (normalized.startsWith('en')) {
      return 'en';
    }
    if (normalized.startsWith('vi')) {
      return 'vi';
    }
    return _preferredLanguageCode();
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

  Future<void> _configurePhoneAuthSettings() async {
    if (_phoneAuthSettingsConfigured) {
      return;
    }
    _phoneAuthSettingsConfigured = true;
    try {
      await _auth.setSettings(appVerificationDisabledForTesting: false);
      AppLogger.info('Using live Firebase phone verification flow.');
    } catch (error, stackTrace) {
      AppLogger.warning(
        'Could not apply FirebaseAuth phone verification settings.',
        error,
        stackTrace,
      );
    }
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

      final context = MemberAccessContext.fromFunctionsData(result.data);
      await _refreshSessionTokenBestEffort(user);
      return context;
    } on FirebaseFunctionsException catch (error) {
      if (!_shouldUseClientFallback(error.code, message: error.message)) {
        rethrow;
      }

      AppLogger.warning(
        'claimMemberRecord callable unavailable; using client fallback claim flow.',
      );
      try {
        return await _claimMemberAccessWithoutFunctions(
          user,
          loginMethod: loginMethod,
          childIdentifier: childIdentifier,
          memberId: memberId,
        );
      } on FirebaseException catch (fallbackError, fallbackStackTrace) {
        AppLogger.warning(
          'Client fallback claim flow failed.',
          fallbackError,
          fallbackStackTrace,
        );
        if (_isFirestorePermissionFailure(fallbackError)) {
          final tokenContext = await _resolveContextFromTokenClaims(user);
          if (tokenContext != null &&
              tokenContext.accessMode != AuthMemberAccessMode.unlinked) {
            AppLogger.warning(
              'Fallback claim flow is blocked by Firestore rules; reusing linked context from refreshed token claims.',
            );
            return tokenContext;
          }
          if (loginMethod == AuthEntryMethod.phone) {
            AppLogger.warning(
              'Fallback claim flow is blocked by Firestore rules; returning an unlinked session context.',
            );
            return MemberAccessContext.unlinked(
              displayName: user.displayName ?? 'BeFam Member',
            );
          }
          throw error;
        }
        rethrow;
      }
    }
  }

  Future<void> _refreshSessionTokenBestEffort(User user) async {
    for (var attempt = 1; attempt <= 3; attempt += 1) {
      try {
        await user.getIdToken(true);
        return;
      } catch (error, stackTrace) {
        if (attempt == 3) {
          AppLogger.warning(
            'Could not refresh Firebase ID token after claimMemberRecord; continuing with the current token.',
            error,
            stackTrace,
          );
          return;
        }
        await Future<void>.delayed(Duration(milliseconds: 250 * attempt));
      }
    }
  }

  bool _isFirestorePermissionFailure(FirebaseException error) {
    final code = error.code.trim().toLowerCase();
    return code == 'permission-denied' ||
        code == 'permission_denied' ||
        code == 'failed-precondition' ||
        code == 'failed_precondition';
  }

  Future<MemberAccessContext> _claimMemberAccessWithoutFunctions(
    User user, {
    required AuthEntryMethod loginMethod,
    required String? childIdentifier,
    required String? memberId,
  }) async {
    final authPhone = _normalizePhoneOrNull(user.phoneNumber);
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
      await _writeUserSessionDocument(
        user.uid,
        context,
        normalizedPhone: authPhone,
      );
      return context;
    }

    final matchingMembers = await _loadMembersMatchingPhone(authPhone);

    if (matchingMembers.isEmpty) {
      final context = MemberAccessContext.unlinked(
        displayName: user.displayName ?? 'BeFam Member',
      );
      await _writeUserSessionDocument(
        user.uid,
        context,
        normalizedPhone: authPhone,
      );
      return context;
    }

    if (matchingMembers.length > 1) {
      final linkedToCurrent = matchingMembers.firstWhere(
        (doc) => (doc.data()['authUid'] as String?) == user.uid,
        orElse: () => matchingMembers.first,
      );
      if ((linkedToCurrent.data()['authUid'] as String?) != user.uid &&
          matchingMembers
              .where((doc) => (doc.data()['authUid'] as String?) == user.uid)
              .isEmpty) {
        throw const AuthIssueException(
          AuthIssue(AuthIssueKey.memberClaimConflict),
        );
      }
    }

    final selected = matchingMembers.firstWhere(
      (doc) => (doc.data()['authUid'] as String?) == user.uid,
      orElse: () => matchingMembers.first,
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
    await _writeUserSessionDocument(
      user.uid,
      context,
      normalizedPhone: authPhone,
    );
    return context;
  }

  String _normalizePhoneOrNull(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return '';
    }
    return PhoneNumberFormatter.tryParseE164(trimmed) ?? trimmed;
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  _loadMembersMatchingPhone(String phoneInput) async {
    final variants = PhoneNumberFormatter.lookupVariants(phoneInput);
    final byId = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};

    for (final variant in variants) {
      final snapshot = await _members
          .where('phoneE164', isEqualTo: variant)
          .limit(10)
          .get();
      for (final doc in snapshot.docs) {
        byId[doc.id] = doc;
      }
    }

    if (byId.isNotEmpty) {
      return byId.values.toList(growable: false);
    }

    final fallbackSnapshot = await _members.get();
    for (final doc in fallbackSnapshot.docs) {
      final memberPhone = (doc.data()['phoneE164'] as String?)?.trim();
      if (PhoneNumberFormatter.areEquivalent(memberPhone, phoneInput)) {
        byId[doc.id] = doc;
      }
    }

    return byId.values.toList(growable: false);
  }

  Future<void> _writeUserSessionDocument(
    String uid,
    MemberAccessContext context, {
    String? normalizedPhone,
  }) async {
    final now = FieldValue.serverTimestamp();
    final phone = _normalizePhoneOrNull(normalizedPhone);
    await _users.doc(uid).set({
      'uid': uid,
      'memberId': context.memberId ?? '',
      'clanId': context.clanId ?? '',
      'clanIds': context.clanId == null ? <String>[] : [context.clanId!],
      'branchId': context.branchId ?? '',
      'primaryRole': context.primaryRole ?? 'GUEST',
      'accessMode': context.accessMode.name,
      'linkedAuthUid': context.linkedAuthUid,
      if (phone.isNotEmpty) 'normalizedPhone': phone,
      'updatedAt': now,
      'createdAt': now,
    }, SetOptions(merge: true));
  }

  Future<AuthSession> _resolvePhoneOtpCompatibilitySession(
    User user, {
    required String phoneE164,
    required String? childIdentifier,
    required String? memberId,
    required String? displayName,
  }) async {
    try {
      return await _buildSession(
        user,
        loginMethod: AuthEntryMethod.phone,
        phoneE164: phoneE164,
        childIdentifier: childIdentifier,
        memberId: memberId,
        displayName: displayName,
      );
    } catch (error, stackTrace) {
      if (!_isRecoverablePhoneIdentityFailure(error)) {
        rethrow;
      }
      AppLogger.warning(
        'Phone identity reconciliation fallback could not auto-link a member; continuing with unlinked access.',
        error,
        stackTrace,
      );
      final tokenSession = await _buildSessionFromTokenClaims(
        user,
        loginMethod: AuthEntryMethod.phone,
        phoneE164: phoneE164,
        childIdentifier: childIdentifier,
        memberId: memberId,
        displayName: displayName,
      );
      if (tokenSession != null &&
          tokenSession.accessMode != AuthMemberAccessMode.unlinked) {
        AppLogger.warning(
          'Recovered linked phone session from refreshed token claims after fallback failure.',
        );
        return tokenSession;
      }
      final fallbackNormalizedPhone = _normalizePhoneOrNull(user.phoneNumber);
      return _buildUnlinkedSessionWithBestEffortSync(
        user,
        phoneE164: fallbackNormalizedPhone.isEmpty
            ? phoneE164
            : fallbackNormalizedPhone,
      );
    }
  }

  bool _isRecoverablePhoneIdentityFailure(Object error) {
    if (error is AuthIssueException) {
      return error.issue.key == AuthIssueKey.memberAlreadyLinked ||
          error.issue.key == AuthIssueKey.memberClaimConflict ||
          error.issue.key == AuthIssueKey.userNotFound ||
          error.issue.key == AuthIssueKey.operationNotAllowed ||
          error.issue.key == AuthIssueKey.authUnavailable;
    }
    if (error is FirebaseFunctionsException) {
      final code = error.code.trim().toLowerCase();
      return code == 'already-exists' ||
          code == 'already_exists' ||
          code == 'failed-precondition' ||
          code == 'failed_precondition' ||
          code == 'not-found' ||
          code == 'permission-denied' ||
          code == 'permission_denied' ||
          code == 'unavailable' ||
          code == 'unimplemented';
    }
    if (error is FirebaseException) {
      final code = error.code.trim().toLowerCase();
      return code == 'permission-denied' ||
          code == 'permission_denied' ||
          code == 'failed-precondition' ||
          code == 'failed_precondition' ||
          code == 'not-found' ||
          code == 'not_found';
    }
    if (error is FirebaseAuthException) {
      final code = error.code.trim().toLowerCase();
      return code == 'user-not-found' || code == 'operation-not-allowed';
    }
    return false;
  }

  Future<AuthSession> _buildUnlinkedSessionWithBestEffortSync(
    User user, {
    required String phoneE164,
  }) async {
    final normalizedPhone = _normalizePhoneOrNull(phoneE164);
    final context = MemberAccessContext.unlinked(
      displayName: user.displayName ?? 'BeFam Member',
    );
    try {
      await _writeUserSessionDocument(
        user.uid,
        context,
        normalizedPhone: normalizedPhone,
      );
    } catch (error, stackTrace) {
      AppLogger.warning(
        'Unable to persist unlinked user session document; continuing with local unlinked session.',
        error,
        stackTrace,
      );
    }
    return AuthSession(
      uid: user.uid,
      loginMethod: AuthEntryMethod.phone,
      phoneE164: normalizedPhone.isEmpty ? phoneE164 : normalizedPhone,
      displayName: context.displayName ?? 'BeFam Member',
      childIdentifier: null,
      memberId: null,
      clanId: null,
      branchId: null,
      primaryRole: 'GUEST',
      accessMode: AuthMemberAccessMode.unlinked,
      linkedAuthUid: false,
      isSandbox: false,
      signedInAtIso: DateTime.now().toIso8601String(),
    );
  }

  Future<AuthSession?> _buildSessionFromTokenClaims(
    User user, {
    required AuthEntryMethod loginMethod,
    required String phoneE164,
    required String? childIdentifier,
    required String? memberId,
    required String? displayName,
  }) async {
    final tokenContext = await _resolveContextFromTokenClaims(user);
    if (tokenContext == null) {
      return null;
    }
    final normalizedUserPhone = _normalizePhoneOrNull(user.phoneNumber);
    return AuthSession(
      uid: user.uid,
      loginMethod: loginMethod,
      phoneE164: normalizedUserPhone.isEmpty ? phoneE164 : normalizedUserPhone,
      displayName:
          tokenContext.displayName ??
          displayName ??
          user.displayName ??
          'BeFam Member',
      childIdentifier: childIdentifier,
      memberId: tokenContext.memberId ?? memberId,
      clanId: tokenContext.clanId,
      branchId: tokenContext.branchId,
      primaryRole: tokenContext.primaryRole,
      accessMode: tokenContext.accessMode,
      linkedAuthUid: tokenContext.linkedAuthUid,
      isSandbox: false,
      signedInAtIso: DateTime.now().toIso8601String(),
    );
  }

  Future<MemberAccessContext?> _resolveContextFromTokenClaims(User user) async {
    try {
      await _refreshSessionTokenBestEffort(user);
      final tokenResult = await user.getIdTokenResult();
      final claims = tokenResult.claims;
      if (claims == null || claims.isEmpty) {
        return null;
      }
      final memberId = _readNonEmptyString(claims['memberId']);
      final clanId = _readPreferredClanIdFromClaims(claims);
      final branchId = _readNonEmptyString(claims['branchId']);
      final primaryRole = _readNonEmptyString(claims['primaryRole']);
      final accessMode = _resolveAccessModeFromClaims(
        _readNonEmptyString(claims['memberAccessMode']) ??
            _readNonEmptyString(claims['accessMode']),
        memberId: memberId,
        clanId: clanId,
      );
      if (accessMode == AuthMemberAccessMode.unlinked) {
        return null;
      }
      if (memberId == null || clanId == null) {
        return null;
      }
      return MemberAccessContext(
        memberId: memberId,
        displayName: user.displayName,
        clanId: clanId,
        branchId: branchId,
        primaryRole: primaryRole,
        accessMode: accessMode,
        linkedAuthUid:
            claims['linkedAuthUid'] == true ||
            accessMode == AuthMemberAccessMode.claimed,
      );
    } catch (error, stackTrace) {
      AppLogger.warning(
        'Could not resolve linked context from token claims.',
        error,
        stackTrace,
      );
      return null;
    }
  }

  String? _readPreferredClanIdFromClaims(Map<String, dynamic> claims) {
    final activeClanId = _readNonEmptyString(claims['activeClanId']);
    if (activeClanId != null) {
      return activeClanId;
    }
    final clanId = _readNonEmptyString(claims['clanId']);
    if (clanId != null) {
      return clanId;
    }
    final rawClanIds = claims['clanIds'];
    if (rawClanIds is List) {
      for (final entry in rawClanIds) {
        final candidate = _readNonEmptyString(entry);
        if (candidate != null) {
          return candidate;
        }
      }
    }
    return null;
  }

  AuthMemberAccessMode _resolveAccessModeFromClaims(
    String? rawMode, {
    required String? memberId,
    required String? clanId,
  }) {
    final normalizedMode = rawMode?.trim().toLowerCase() ?? '';
    final hasLinkedContext = memberId != null && clanId != null;
    if (normalizedMode == 'child') {
      return hasLinkedContext
          ? AuthMemberAccessMode.child
          : AuthMemberAccessMode.unlinked;
    }
    if (normalizedMode == 'claimed') {
      return hasLinkedContext
          ? AuthMemberAccessMode.claimed
          : AuthMemberAccessMode.unlinked;
    }
    if (hasLinkedContext) {
      return AuthMemberAccessMode.claimed;
    }
    return AuthMemberAccessMode.unlinked;
  }

  String? _readNonEmptyString(dynamic value) {
    if (value is! String) {
      return null;
    }
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  bool _shouldUseClientFallback(String code, {String? message}) {
    if (code == 'not-found' ||
        code == 'unimplemented' ||
        code == 'unavailable') {
      return true;
    }
    if (code == 'failed-precondition' || code == 'unauthenticated') {
      if ((message ?? '').trim().isEmpty) {
        return true;
      }
    } else if (code != 'permission-denied') {
      return false;
    }
    final normalizedMessage = (message ?? '').toLowerCase();
    return normalizedMessage.contains('app check') ||
        normalizedMessage.contains('appcheck') ||
        normalizedMessage.contains('token') ||
        normalizedMessage.contains('auth') ||
        normalizedMessage.contains('credential') ||
        normalizedMessage.contains('precondition');
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
    final normalizedUserPhone = _normalizePhoneOrNull(user.phoneNumber);

    return AuthSession(
      uid: user.uid,
      loginMethod: loginMethod,
      phoneE164: normalizedUserPhone.isEmpty ? phoneE164 : normalizedUserPhone,
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
