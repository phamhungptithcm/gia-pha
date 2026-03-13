import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/services/app_logger.dart';
import '../models/auth_entry_method.dart';
import '../models/auth_otp_request_result.dart';
import '../models/auth_session.dart';
import '../models/pending_otp_challenge.dart';
import '../services/auth_error_mapper.dart';
import '../services/auth_gateway.dart';
import '../services/auth_session_store.dart';
import '../services/child_identifier_formatter.dart';
import '../services/phone_number_formatter.dart';

enum AuthStep { loginMethodSelection, phoneNumber, childIdentifier, otp }

class AuthController extends ChangeNotifier {
  AuthController({
    required AuthGateway authGateway,
    required AuthSessionStore sessionStore,
  }) : _authGateway = authGateway,
       _sessionStore = sessionStore;

  final AuthGateway _authGateway;
  final AuthSessionStore _sessionStore;

  AuthStep step = AuthStep.loginMethodSelection;
  AuthSession? session;
  PendingOtpChallenge? pendingChallenge;
  String? errorMessage;
  bool isRestoring = true;
  bool isBusy = false;
  int resendCooldownSeconds = 0;

  Timer? _resendTimer;
  bool _initialized = false;
  bool _disposed = false;

  bool get isSandbox => _authGateway.isSandbox;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    _initialized = true;
    try {
      session = await _sessionStore.read();
      AppLogger.info(
        session == null
            ? 'No persisted auth session found.'
            : 'Restored persisted auth session for ${session!.uid}.',
      );
    } catch (error, stackTrace) {
      AppLogger.error('Failed to restore auth session.', error, stackTrace);
      errorMessage = 'We could not restore the last sign-in session.';
    } finally {
      isRestoring = false;
      _emit();
    }
  }

  void selectLoginMethod(AuthEntryMethod method) {
    _clearError();
    step = switch (method) {
      AuthEntryMethod.phone => AuthStep.phoneNumber,
      AuthEntryMethod.child => AuthStep.childIdentifier,
    };
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
    );
  }

  Future<void> submitChildIdentifier(String rawChildIdentifier) async {
    final normalized = ChildIdentifierFormatter.normalize(rawChildIdentifier);
    await _startOtpRequest(() => _authGateway.requestChildOtp(normalized));
  }

  Future<void> verifyOtp(String rawCode) async {
    final challenge = pendingChallenge;
    if (challenge == null) {
      errorMessage = 'Request an OTP before trying to verify it.';
      _emit();
      return;
    }

    final sanitized = rawCode.replaceAll(RegExp(r'[^0-9]'), '');
    if (!RegExp(r'^\d{6}$').hasMatch(sanitized)) {
      errorMessage = 'Enter the 6-digit OTP to continue.';
      _emit();
      return;
    }

    await _runBusy(() async {
      final newSession = await _authGateway.verifyOtp(challenge, sanitized);
      await _completeSignIn(newSession);
    });
  }

  Future<void> resendOtp() async {
    final challenge = pendingChallenge;
    if (challenge == null || resendCooldownSeconds > 0) {
      return;
    }

    await _startOtpRequest(() => _authGateway.resendOtp(challenge));
  }

  Future<void> logout() async {
    await _runBusy(() async {
      await _authGateway.signOut();
      await _sessionStore.clear();
      session = null;
      pendingChallenge = null;
      step = AuthStep.loginMethodSelection;
      _stopCooldown();
    });
  }

  Future<void> _startOtpRequest(
    Future<AuthOtpRequestResult> Function() action,
  ) async {
    await _runBusy(() async {
      final result = await action();
      await _applyOtpRequestResult(result);
    });
  }

  Future<void> _applyOtpRequestResult(AuthOtpRequestResult result) async {
    if (result.session case final AuthSession restoredSession) {
      await _completeSignIn(restoredSession);
      return;
    }

    if (result.challenge case final PendingOtpChallenge challenge) {
      pendingChallenge = challenge;
      step = AuthStep.otp;
      _startCooldown();
      _emit();
    }
  }

  Future<void> _completeSignIn(AuthSession newSession) async {
    session = newSession;
    pendingChallenge = null;
    errorMessage = null;
    await _sessionStore.write(newSession);
    _stopCooldown();
    AppLogger.info('Auth session established for ${newSession.uid}.');
    _emit();
  }

  Future<void> _runBusy(Future<void> Function() action) async {
    isBusy = true;
    errorMessage = null;
    _emit();

    try {
      await action();
    } catch (error, stackTrace) {
      AppLogger.error('Authentication flow failed.', error, stackTrace);
      errorMessage = AuthErrorMapper.messageFor(error);
      _emit();
    } finally {
      isBusy = false;
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
    errorMessage = null;
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
