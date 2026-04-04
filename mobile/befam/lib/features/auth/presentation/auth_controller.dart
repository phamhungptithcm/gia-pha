import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/services/app_logger.dart';
import '../models/auth_entry_method.dart';
import '../models/auth_issue.dart';
import '../models/member_identity_verification.dart';
import '../models/auth_otp_request_result.dart';
import '../models/auth_session.dart';
import '../models/pending_otp_challenge.dart';
import '../models/phone_identity_resolution.dart';
import '../services/auth_analytics_service.dart';
import '../services/auth_error_mapper.dart';
import '../services/auth_gateway.dart';
import '../services/auth_privacy_policy_store.dart';
import '../services/auth_session_store.dart';
import '../services/child_identifier_formatter.dart';
import '../services/phone_number_formatter.dart';

enum AuthStep {
  loginMethodSelection,
  phoneNumber,
  childIdentifier,
  otp,
  memberSelection,
  memberVerification,
}

typedef AuthOtpAction = Future<AuthOtpRequestResult> Function();

class AuthController extends ChangeNotifier {
  AuthController({
    required AuthGateway authGateway,
    required AuthAnalyticsService analyticsService,
    required AuthSessionStore sessionStore,
    AuthPrivacyPolicyStore? privacyPolicyStore,
  }) : _authGateway = authGateway,
       _analyticsService = analyticsService,
       _sessionStore = sessionStore,
       _privacyPolicyStore =
           privacyPolicyStore ?? SharedPrefsAuthPrivacyPolicyStore();

  final AuthGateway _authGateway;
  final AuthAnalyticsService _analyticsService;
  final AuthSessionStore _sessionStore;
  final AuthPrivacyPolicyStore _privacyPolicyStore;

  AuthStep step = AuthStep.loginMethodSelection;
  AuthSession? session;
  PendingOtpChallenge? pendingChallenge;
  PhoneIdentityResolution? pendingPhoneResolution;
  MemberIdentityVerificationChallenge? verificationChallenge;
  AuthIssue? error;
  bool isRestoring = true;
  bool isBusy = false;
  bool hasAcceptedPrivacyPolicy = false;
  int resendCooldownSeconds = 0;

  Timer? _resendTimer;
  bool _initialized = false;
  bool _disposed = false;
  String _preferredLanguageCode = 'vi';

  bool get isSandbox => _authGateway.isSandbox;

  void setPreferredLanguageCode(String languageCode) {
    final normalized = languageCode.trim().toLowerCase();
    _preferredLanguageCode = normalized.startsWith('en') ? 'en' : 'vi';
  }

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    _initialized = true;
    try {
      final restoredState = await Future.wait<Object?>([
        _privacyPolicyStore.readAccepted(),
        _sessionStore.read(),
      ]);
      hasAcceptedPrivacyPolicy = restoredState[0] as bool;
      final restoredSession = restoredState[1] as AuthSession?;
      if (restoredSession != null &&
          restoredSession.isSandbox != _authGateway.isSandbox) {
        AppLogger.warning(
          'Discarding persisted auth session from an incompatible auth mode.',
        );
        await _sessionStore.clear();
        session = null;
      } else if (restoredSession != null &&
          !(await _authGateway.canRestoreSession(restoredSession))) {
        AppLogger.warning(
          'Discarding persisted auth session because Firebase authentication is no longer valid.',
        );
        await _sessionStore.clear();
        session = null;
        try {
          await _authGateway.signOut();
        } catch (_) {}
      } else {
        session = restoredSession;
      }
      AppLogger.info(
        session == null
            ? 'No persisted auth session found.'
            : 'Restored persisted auth session for ${session!.uid}.',
      );
    } catch (error, stackTrace) {
      AppLogger.error('Failed to restore auth session.', error, stackTrace);
      this.error = const AuthIssue(AuthIssueKey.restoreSessionFailed);
    } finally {
      isRestoring = false;
      _emit();
    }
  }

  void selectLoginMethod(AuthEntryMethod method) {
    if (!_ensurePrivacyPolicyAccepted()) {
      return;
    }
    _clearError();
    pendingPhoneResolution = null;
    verificationChallenge = null;
    step = switch (method) {
      AuthEntryMethod.phone => AuthStep.phoneNumber,
      AuthEntryMethod.child => AuthStep.childIdentifier,
    };
    unawaited(
      _analyticsService.logLoginMethodSelected(method, isSandbox: isSandbox),
    );
    _emit();
  }

  void navigateBack() {
    _clearError();

    switch (step) {
      case AuthStep.loginMethodSelection:
        return;
      case AuthStep.phoneNumber:
        step = AuthStep.loginMethodSelection;
        _emit();
        return;
      case AuthStep.childIdentifier:
        step = AuthStep.loginMethodSelection;
        _emit();
        return;
      case AuthStep.otp:
        final challenge = pendingChallenge;
        step = challenge?.loginMethod == AuthEntryMethod.child
            ? AuthStep.childIdentifier
            : AuthStep.phoneNumber;
        pendingChallenge = null;
        _stopCooldown();
        _emit();
        return;
      case AuthStep.memberSelection:
        step = AuthStep.phoneNumber;
        pendingPhoneResolution = null;
        verificationChallenge = null;
        _emit();
        return;
      case AuthStep.memberVerification:
        step = AuthStep.memberSelection;
        verificationChallenge = null;
        _emit();
        return;
    }
  }

  Future<void> submitPhoneNumber(
    String rawPhoneNumber, {
    String? countryIsoCode,
  }) async {
    late final String normalizedPhone;
    try {
      normalizedPhone = PhoneNumberFormatter.parse(
        rawPhoneNumber,
        defaultCountryIso: countryIsoCode,
      ).e164;
    } catch (error) {
      this.error = AuthErrorMapper.map(error);
      _emit();
      return;
    }
    await _startOtpRequest(
      () => _authGateway.requestPhoneOtp(normalizedPhone),
      method: AuthEntryMethod.phone,
      source: 'phone_input',
    );
  }

  Future<void> submitChildIdentifier(String rawChildIdentifier) async {
    final normalized = ChildIdentifierFormatter.normalize(rawChildIdentifier);
    await _startOtpRequest(
      () => _authGateway.requestChildOtp(normalized),
      method: AuthEntryMethod.child,
      source: 'child_identifier',
    );
  }

  Future<void> verifyOtp(String rawCode) async {
    final challenge = pendingChallenge;
    if (challenge == null) {
      error = const AuthIssue(AuthIssueKey.requestOtpBeforeVerify);
      _emit();
      return;
    }

    final sanitized = rawCode.replaceAll(RegExp(r'[^0-9]'), '');
    if (!RegExp(r'^\d{6}$').hasMatch(sanitized)) {
      error = const AuthIssue(AuthIssueKey.otpMustBeSixDigits);
      _emit();
      return;
    }
    AppLogger.info(
      'OTP verification started (method=${challenge.loginMethod.name}, phone=${challenge.phoneE164}, verificationId=${challenge.verificationId}).',
    );

    await _runBusy(
      () async {
        final newSession = await _authGateway.verifyOtp(
          challenge,
          sanitized,
          languageCode: _preferredLanguageCode,
        );
        if (newSession.session case final AuthSession sessionResult?) {
          await _completeSignIn(sessionResult);
          return;
        }

        final resolution = newSession.phoneResolution;
        if (resolution == null) {
          throw const AuthIssueException(
            AuthIssue(AuthIssueKey.preparationFailed),
          );
        }
        final shouldCreateUnlinkedIdentity =
            resolution.allowCreateNew &&
            (resolution.status == PhoneIdentityResolutionStatus.createNewOnly ||
                !resolution.candidates.any(
                  (candidate) => candidate.selectable,
                ));
        if (shouldCreateUnlinkedIdentity) {
          pendingChallenge = null;
          pendingPhoneResolution = resolution;
          verificationChallenge = null;
          step = AuthStep.memberSelection;
          _stopCooldown();
          _emit();
          final createdSession = await _authGateway
              .createUnlinkedPhoneIdentity();
          await _completeSignIn(createdSession);
          return;
        }
        pendingChallenge = null;
        pendingPhoneResolution = resolution;
        verificationChallenge = null;
        step = AuthStep.memberSelection;
        _stopCooldown();
        _emit();
      },
      method: challenge.loginMethod,
      operation: 'verify_otp',
    );
  }

  Future<void> chooseCreateNewIdentity() async {
    await _runBusy(
      () async {
        final createdSession = await _authGateway.createUnlinkedPhoneIdentity();
        await _completeSignIn(createdSession);
      },
      method: AuthEntryMethod.phone,
      operation: 'create_unlinked_identity',
    );
  }

  Future<void> chooseMemberCandidate(String memberId) async {
    final normalizedMemberId = memberId.trim();
    if (normalizedMemberId.isEmpty) {
      error = const AuthIssue(AuthIssueKey.preparationFailed);
      _emit();
      return;
    }
    await _runBusy(
      () async {
        final challenge = await _authGateway.startMemberIdentityVerification(
          normalizedMemberId,
          languageCode: _preferredLanguageCode,
        );
        verificationChallenge = challenge;
        step = AuthStep.memberVerification;
        _emit();
      },
      method: AuthEntryMethod.phone,
      operation: 'start_member_identity_verification',
    );
  }

  Future<void> submitMemberVerificationAnswers(
    Map<String, String> answers,
  ) async {
    final challenge = verificationChallenge;
    if (challenge == null) {
      error = const AuthIssue(AuthIssueKey.preparationFailed);
      _emit();
      return;
    }
    await _runBusy(
      () async {
        final result = await _authGateway.submitMemberIdentityVerification(
          verificationSessionId: challenge.verificationSessionId,
          answers: answers,
        );
        if (result.passed && result.session != null) {
          await _completeSignIn(result.session!);
          return;
        }
        verificationChallenge = MemberIdentityVerificationChallenge(
          verificationSessionId: challenge.verificationSessionId,
          memberId: challenge.memberId,
          maxAttempts: challenge.maxAttempts,
          remainingAttempts: result.remainingAttempts
              .clamp(0, challenge.maxAttempts)
              .toInt(),
          questions: challenge.questions,
        );
        error = result.locked
            ? const AuthIssue(AuthIssueKey.memberVerificationLocked)
            : const AuthIssue(AuthIssueKey.memberVerificationFailed);
        _emit();
      },
      method: AuthEntryMethod.phone,
      operation: 'submit_member_identity_verification',
    );
  }

  Future<void> resendOtp() async {
    final challenge = pendingChallenge;
    if (challenge == null || resendCooldownSeconds > 0) {
      return;
    }

    await _startOtpRequest(
      () => _authGateway.resendOtp(challenge),
      method: challenge.loginMethod,
      isResend: true,
      source: 'resend',
    );
  }

  Future<void> logout() async {
    await _runBusy(() async {
      await _authGateway.signOut();
      await _analyticsService.logLogout(session);
      await _sessionStore.clear();
      session = null;
      pendingChallenge = null;
      pendingPhoneResolution = null;
      verificationChallenge = null;
      step = AuthStep.loginMethodSelection;
      _stopCooldown();
    }, operation: 'logout');
  }

  Future<void> setPrivacyPolicyAccepted(bool accepted) async {
    hasAcceptedPrivacyPolicy = accepted;
    _emit();
    await _privacyPolicyStore.writeAccepted(accepted);
  }

  Future<void> _startOtpRequest(
    AuthOtpAction action, {
    required AuthEntryMethod method,
    bool isResend = false,
    required String source,
  }) async {
    final flowId =
        'otp_${DateTime.now().millisecondsSinceEpoch}_${method.name}_${isResend ? 'resend' : 'send'}';
    AppLogger.info(
      '[$flowId] Starting OTP request flow (method=${method.name}, resend=$isResend, source=$source, step=${step.name}, sandbox=$isSandbox).',
    );
    await _runBusy(
      () async {
        pendingPhoneResolution = null;
        verificationChallenge = null;
        final result = await action();
        AppLogger.info('[$flowId] OTP request returned from gateway.');
        await _applyOtpRequestResult(result, flowId: flowId, source: source);
        await _analyticsService.logOtpRequested(
          method,
          isSandbox: isSandbox,
          isResend: isResend,
        );
      },
      method: method,
      operation: flowId,
    );
  }

  Future<void> _applyOtpRequestResult(
    AuthOtpRequestResult result, {
    required String flowId,
    required String source,
  }) async {
    if (result.session case final AuthSession restoredSession) {
      AppLogger.info(
        '[$flowId] OTP request resolved directly to session for ${restoredSession.uid} (source=$source).',
      );
      await _completeSignIn(restoredSession);
      return;
    }

    if (result.challenge case final PendingOtpChallenge challenge) {
      AppLogger.info(
        '[$flowId] OTP challenge received (method=${challenge.loginMethod.name}, phone=${challenge.phoneE164}, verificationId=${challenge.verificationId}, source=$source).',
      );
      pendingChallenge = challenge;
      step = AuthStep.otp;
      _startCooldown();
      if (challenge.loginMethod == AuthEntryMethod.child &&
          challenge.childIdentifier != null) {
        unawaited(
          _analyticsService.logChildContextResolved(
            isSandbox: isSandbox,
            childIdentifier: challenge.childIdentifier!,
            memberId: challenge.memberId,
          ),
        );
      }
      _emit();
    }
  }

  Future<void> _completeSignIn(AuthSession newSession) async {
    session = newSession;
    pendingChallenge = null;
    pendingPhoneResolution = null;
    verificationChallenge = null;
    error = null;
    await _sessionStore.write(newSession);
    _stopCooldown();
    AppLogger.info('Auth session established for ${newSession.uid}.');
    await _analyticsService.logSessionEstablished(newSession);
    _emit();
  }

  Future<void> _runBusy(
    Future<void> Function() action, {
    AuthEntryMethod? method,
    String operation = 'auth_flow',
  }) async {
    final stopwatch = Stopwatch()..start();
    AppLogger.info(
      '[$operation] Busy state entered (step=${step.name}, method=${method?.name ?? 'n/a'}).',
    );
    isBusy = true;
    error = null;
    _emit();

    try {
      await action();
      AppLogger.info('[$operation] Completed successfully.');
    } catch (error, stackTrace) {
      AppLogger.error(
        '[$operation] Authentication flow failed (step=${step.name}, method=${method?.name ?? 'n/a'}).',
        error,
        stackTrace,
      );
      this.error = AuthErrorMapper.map(error);
      await _analyticsService.logFailure(
        stage: step.name,
        isSandbox: isSandbox,
        method: method,
        issue: this.error,
      );
      _emit();
    } finally {
      isBusy = false;
      stopwatch.stop();
      AppLogger.info(
        '[$operation] Busy state exited after ${stopwatch.elapsedMilliseconds}ms.',
      );
      _emit();
    }
  }

  void _startCooldown() {
    _stopCooldown();
    resendCooldownSeconds = 30;
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (resendCooldownSeconds <= 1) {
        resendCooldownSeconds = 0;
        timer.cancel();
      } else {
        resendCooldownSeconds -= 1;
      }
      _emit();
    });
  }

  void _stopCooldown() {
    _resendTimer?.cancel();
    _resendTimer = null;
    resendCooldownSeconds = 0;
  }

  void _clearError() {
    error = null;
  }

  bool _ensurePrivacyPolicyAccepted() {
    if (hasAcceptedPrivacyPolicy) {
      return true;
    }
    AppLogger.warning(
      'Auth action blocked because privacy policy is not accepted yet.',
    );
    error = const AuthIssue(AuthIssueKey.privacyPolicyRequired);
    _emit();
    return false;
  }

  void _emit() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _stopCooldown();
    super.dispose();
  }
}
