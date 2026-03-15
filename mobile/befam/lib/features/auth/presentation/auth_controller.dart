import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/services/app_logger.dart';
import '../../../core/services/runtime_mode.dart';
import '../models/auth_entry_method.dart';
import '../models/auth_issue.dart';
import '../models/auth_otp_request_result.dart';
import '../models/auth_session.dart';
import '../models/pending_otp_challenge.dart';
import '../services/auth_analytics_service.dart';
import '../services/auth_error_mapper.dart';
import '../services/auth_gateway.dart';
import '../services/auth_privacy_policy_store.dart';
import '../services/auth_session_store.dart';
import '../services/child_identifier_formatter.dart';
import '../services/phone_number_formatter.dart';

enum AuthStep { loginMethodSelection, phoneNumber, childIdentifier, otp }

typedef AuthOtpAction = Future<AuthOtpRequestResult> Function();

class AuthController extends ChangeNotifier {
  static const String _localBypassPhoneE164 = String.fromEnvironment(
    'BEFAM_LOCAL_BYPASS_PHONE',
    defaultValue: '+84901234567',
  );

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
  AuthIssue? error;
  bool isRestoring = true;
  bool isBusy = false;
  bool hasAcceptedPrivacyPolicy = false;
  int resendCooldownSeconds = 0;

  Timer? _resendTimer;
  bool _initialized = false;
  bool _disposed = false;

  bool get isSandbox => _authGateway.isSandbox;
  bool get canUseLocalBypass =>
      _authGateway.isSandbox && RuntimeMode.shouldBypassPhoneOtp;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    _initialized = true;
    try {
      hasAcceptedPrivacyPolicy = await _privacyPolicyStore.readAccepted();
      final restoredSession = await _sessionStore.read();
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
    }
  }

  Future<void> submitPhoneNumber(String rawPhoneNumber) async {
    final parsedPhone = PhoneNumberFormatter.parse(rawPhoneNumber);
    await _startOtpRequest(
      () => _authGateway.requestPhoneOtp(parsedPhone.e164),
      method: AuthEntryMethod.phone,
      source: 'phone_input',
    );
  }

  Future<void> signInWithLocalBypass() async {
    await signInWithLocalBypassPhone(_localBypassPhoneE164);
  }

  Future<void> signInWithLocalBypassPhone(String phoneE164) async {
    if (!canUseLocalBypass || isBusy) {
      return;
    }
    if (!_ensurePrivacyPolicyAccepted()) {
      return;
    }

    _clearError();
    unawaited(
      _analyticsService.logLoginMethodSelected(
        AuthEntryMethod.phone,
        isSandbox: isSandbox,
      ),
    );

    await _startOtpRequest(
      () => _authGateway.requestPhoneOtp(phoneE164.trim()),
      method: AuthEntryMethod.phone,
      source: 'local_bypass',
    );

    final challenge = pendingChallenge;
    if (session != null || challenge == null) {
      return;
    }

    final otpHint = challenge.debugOtpHint;
    if (otpHint == null || !RegExp(r'^\d{6}$').hasMatch(otpHint)) {
      error = const AuthIssue(AuthIssueKey.preparationFailed);
      _emit();
      return;
    }

    await verifyOtp(otpHint);
  }

  Future<void> requestOtpForScenarioPhone(
    String phoneE164, {
    String? autoVerifyCode,
  }) async {
    if (isBusy) {
      return;
    }
    if (!_ensurePrivacyPolicyAccepted()) {
      return;
    }

    final normalizedPhone = phoneE164.trim();
    AppLogger.info(
      'Scenario OTP request started for $normalizedPhone (autoCode=${autoVerifyCode != null && autoVerifyCode.trim().isNotEmpty}).',
    );
    if (normalizedPhone.isEmpty) {
      error = const AuthIssue(AuthIssueKey.phoneRequired);
      _emit();
      return;
    }

    _clearError();
    unawaited(
      _analyticsService.logLoginMethodSelected(
        AuthEntryMethod.phone,
        isSandbox: isSandbox,
      ),
    );

    await _startOtpRequest(
      () => _authGateway.requestPhoneOtp(normalizedPhone),
      method: AuthEntryMethod.phone,
      source: 'sandbox_profile',
    );

    final challenge = pendingChallenge;
    if (session != null || challenge == null) {
      return;
    }

    final sanitizedAutoCode = autoVerifyCode
        ?.replaceAll(RegExp(r'[^0-9]'), '')
        .trim();
    if (sanitizedAutoCode != null &&
        RegExp(r'^\d{6}$').hasMatch(sanitizedAutoCode)) {
      AppLogger.info(
        'Scenario OTP auto-verify is enabled for $normalizedPhone.',
      );
      await verifyOtp(sanitizedAutoCode);
      return;
    }

    if (canUseLocalBypass) {
      final otpHint = challenge.debugOtpHint;
      if (otpHint != null && RegExp(r'^\d{6}$').hasMatch(otpHint)) {
        AppLogger.info(
          'Scenario OTP fallback using debug hint for $normalizedPhone.',
        );
        await verifyOtp(otpHint);
      }
    }
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
        final newSession = await _authGateway.verifyOtp(challenge, sanitized);
        await _completeSignIn(newSession);
      },
      method: challenge.loginMethod,
      operation: 'verify_otp',
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
        '[$flowId] OTP challenge received (method=${challenge.loginMethod.name}, phone=${challenge.phoneE164}, verificationId=${challenge.verificationId}, hasDebugHint=${challenge.debugOtpHint != null}, source=$source).',
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
