import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/bootstrap/firebase_setup_status.dart';
import '../../../app/home/app_shell_page.dart';
import '../../../core/services/app_logger.dart';
import '../models/auth_entry_method.dart';
import '../models/pending_otp_challenge.dart';
import '../services/auth_gateway.dart';
import '../services/auth_gateway_factory.dart';
import '../services/auth_session_store.dart';
import 'auth_controller.dart';

class AuthExperience extends StatefulWidget {
  const AuthExperience({
    super.key,
    required this.status,
    this.authGateway,
    this.sessionStore,
  });

  final FirebaseSetupStatus status;
  final AuthGateway? authGateway;
  final AuthSessionStore? sessionStore;

  @override
  State<AuthExperience> createState() => _AuthExperienceState();
}

class _AuthExperienceState extends State<AuthExperience> {
  late final AuthController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AuthController(
      authGateway: widget.authGateway ?? createDefaultAuthGateway(),
      sessionStore: widget.sessionStore ?? SharedPrefsAuthSessionStore(),
    );
    unawaited(_controller.initialize());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        if (_controller.isRestoring) {
          return _AuthLoadingPage(status: widget.status);
        }

        final session = _controller.session;
        if (session != null) {
          return AppShellPage(
            status: widget.status,
            session: session,
            onLogoutRequested: _controller.logout,
          );
        }

        return _AuthScaffold(status: widget.status, controller: _controller);
      },
    );
  }
}

class _AuthScaffold extends StatelessWidget {
  const _AuthScaffold({required this.status, required this.controller});

  final FirebaseSetupStatus status;
  final AuthController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              colorScheme.surface,
              colorScheme.secondary.withValues(alpha: 0.18),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: [
              _AuthHero(status: status, isSandbox: controller.isSandbox),
              const SizedBox(height: 20),
              if (controller.errorMessage case final String message) ...[
                _AuthMessageCard(
                  title: 'Sign-in needs attention',
                  message: message,
                  icon: Icons.error_outline,
                  tone: colorScheme.errorContainer,
                ),
                const SizedBox(height: 16),
              ],
              switch (controller.step) {
                AuthStep.loginMethodSelection => _LoginMethodSelectionCard(
                  status: status,
                  isSandbox: controller.isSandbox,
                  onPhoneSelected: () {
                    controller.selectLoginMethod(AuthEntryMethod.phone);
                  },
                  onChildSelected: () {
                    controller.selectLoginMethod(AuthEntryMethod.child);
                  },
                ),
                AuthStep.phoneNumber => _PhoneLoginCard(
                  isSandbox: controller.isSandbox,
                  isBusy: controller.isBusy,
                  onBack: controller.navigateBack,
                  onSubmit: controller.submitPhoneNumber,
                ),
                AuthStep.childIdentifier => _ChildIdentifierCard(
                  isSandbox: controller.isSandbox,
                  isBusy: controller.isBusy,
                  onBack: controller.navigateBack,
                  onSubmit: controller.submitChildIdentifier,
                ),
                AuthStep.otp => _OtpVerificationCard(
                  challenge: controller.pendingChallenge,
                  isBusy: controller.isBusy,
                  resendCooldownSeconds: controller.resendCooldownSeconds,
                  onBack: controller.navigateBack,
                  onVerify: controller.verifyOtp,
                  onResend: controller.resendOtp,
                ),
              },
            ],
          ),
        ),
      ),
    );
  }
}

class _AuthLoadingPage extends StatelessWidget {
  const _AuthLoadingPage({required this.status});

  final FirebaseSetupStatus status;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: colorScheme.primary),
                    const SizedBox(height: 20),
                    Text(
                      'Preparing your BeFam session',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      status.isReady
                          ? 'Firebase is ready. Restoring the last auth state now.'
                          : 'Bootstrap is still checking local Firebase readiness.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthHero extends StatelessWidget {
  const _AuthHero({required this.status, required this.isSandbox});

  final FirebaseSetupStatus status;
  final bool isSandbox;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colorScheme.primary, colorScheme.primaryContainer],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _HeroChip(
                label: status.isReady ? 'Firebase ready' : 'Bootstrap pending',
                icon: status.isReady ? Icons.check_circle : Icons.pending,
              ),
              _HeroChip(
                label: isSandbox ? 'Debug auth sandbox' : 'Live Firebase auth',
                icon: isSandbox ? Icons.science_outlined : Icons.verified_user,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'Authentication is the next BeFam milestone.',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: colorScheme.onPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            isSandbox
                ? 'Local builds use a safe OTP sandbox so we can test phone and child access flows without waiting on real SMS infrastructure. Use OTP 123456 for the demo flow.'
                : 'This build uses the live Firebase authentication path for phone verification and session restore.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colorScheme.onPrimary.withValues(alpha: 0.92),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Chip(
      avatar: Icon(icon, size: 18, color: colorScheme.onPrimaryContainer),
      label: Text(label),
      backgroundColor: colorScheme.secondaryContainer,
      side: BorderSide.none,
    );
  }
}

class _AuthMessageCard extends StatelessWidget {
  const _AuthMessageCard({
    required this.title,
    required this.message,
    required this.icon,
    required this.tone,
  });

  final String title;
  final String message;
  final IconData icon;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: tone,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(message),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoginMethodSelectionCard extends StatelessWidget {
  const _LoginMethodSelectionCard({
    required this.status,
    required this.isSandbox,
    required this.onPhoneSelected,
    required this.onChildSelected,
  });

  final FirebaseSetupStatus status;
  final bool isSandbox;
  final VoidCallback onPhoneSelected;
  final VoidCallback onChildSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _MethodCard(
          title: 'Continue with phone',
          description:
              'Use your own phone number to request an OTP and restore your BeFam identity.',
          icon: Icons.phone_iphone,
          buttonLabel: 'Use phone number',
          onPressed: onPhoneSelected,
        ),
        const SizedBox(height: 16),
        _MethodCard(
          title: 'Continue with child ID',
          description:
              'Start from a child identifier, resolve the linked parent phone, and verify access with OTP.',
          icon: Icons.child_care,
          buttonLabel: 'Use child identifier',
          onPressed: onChildSelected,
        ),
        const SizedBox(height: 16),
        _AuthMessageCard(
          title: 'Current bootstrap note',
          message: status.isReady
              ? isSandbox
                    ? 'Firebase is ready and the debug auth sandbox is active for local UI testing.'
                    : 'Firebase is ready and the app will attempt live phone authentication.'
              : 'Firebase startup still needs attention, so sign-in should stay in the sandbox until cloud setup is stable.',
          icon: Icons.info_outline,
          tone: Theme.of(context).colorScheme.surfaceContainerHighest,
        ),
      ],
    );
  }
}

class _MethodCard extends StatelessWidget {
  const _MethodCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.buttonLabel,
    required this.onPressed,
  });

  final String title;
  final String description;
  final IconData icon;
  final String buttonLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: colorScheme.primaryContainer,
              child: Icon(icon),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Text(description, style: theme.textTheme.bodyLarge),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onPressed,
              icon: const Icon(Icons.arrow_forward),
              label: Text(buttonLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhoneLoginCard extends StatefulWidget {
  const _PhoneLoginCard({
    required this.isSandbox,
    required this.isBusy,
    required this.onBack,
    required this.onSubmit,
  });

  final bool isSandbox;
  final bool isBusy;
  final VoidCallback onBack;
  final Future<void> Function(String value) onSubmit;

  @override
  State<_PhoneLoginCard> createState() => _PhoneLoginCardState();
}

class _PhoneLoginCardState extends State<_PhoneLoginCard> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.isSandbox ? '0901234567' : '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _AuthFormCard(
      title: 'Phone verification',
      description:
          'Enter a phone number in local Vietnamese format or full E.164 format. BeFam will request an OTP from this number.',
      onBack: widget.onBack,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            keyboardType: TextInputType.phone,
            enabled: !widget.isBusy,
            decoration: const InputDecoration(
              labelText: 'Phone number',
              hintText: '0901234567 or +84901234567',
            ),
            onSubmitted: widget.isBusy
                ? null
                : (value) => widget.onSubmit(value),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: widget.isBusy
                  ? null
                  : () => widget.onSubmit(_controller.text),
              child: Text(widget.isBusy ? 'Sending OTP...' : 'Send OTP'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChildIdentifierCard extends StatefulWidget {
  const _ChildIdentifierCard({
    required this.isSandbox,
    required this.isBusy,
    required this.onBack,
    required this.onSubmit,
  });

  final bool isSandbox;
  final bool isBusy;
  final VoidCallback onBack;
  final Future<void> Function(String value) onSubmit;

  @override
  State<_ChildIdentifierCard> createState() => _ChildIdentifierCardState();
}

class _ChildIdentifierCardState extends State<_ChildIdentifierCard> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.isSandbox ? 'BEFAM-CHILD-001' : '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _AuthFormCard(
      title: 'Child access',
      description:
          'Enter the family child identifier. BeFam will resolve the linked parent phone and request OTP verification there.',
      onBack: widget.onBack,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            enabled: !widget.isBusy,
            decoration: const InputDecoration(
              labelText: 'Child identifier',
              hintText: 'BEFAM-CHILD-001',
            ),
            textCapitalization: TextCapitalization.characters,
            onSubmitted: widget.isBusy
                ? null
                : (value) => widget.onSubmit(value),
          ),
          const SizedBox(height: 12),
          if (widget.isSandbox)
            Text(
              'Demo identifiers for local testing: BEFAM-CHILD-001 and BEFAM-CHILD-002.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: widget.isBusy
                  ? null
                  : () => widget.onSubmit(_controller.text),
              child: Text(
                widget.isBusy ? 'Resolving parent phone...' : 'Continue',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OtpVerificationCard extends StatefulWidget {
  const _OtpVerificationCard({
    required this.challenge,
    required this.isBusy,
    required this.resendCooldownSeconds,
    required this.onBack,
    required this.onVerify,
    required this.onResend,
  });

  final PendingOtpChallenge? challenge;
  final bool isBusy;
  final int resendCooldownSeconds;
  final VoidCallback onBack;
  final Future<void> Function(String value) onVerify;
  final Future<void> Function() onResend;

  @override
  State<_OtpVerificationCard> createState() => _OtpVerificationCardState();
}

class _OtpVerificationCardState extends State<_OtpVerificationCard> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final challenge = widget.challenge;
    if (challenge == null) {
      AppLogger.warning('OTP screen rendered without a pending challenge.');
      return _AuthFormCard(
        title: 'OTP verification',
        description: 'Request a new code before trying to verify access.',
        onBack: widget.onBack,
        child: const SizedBox.shrink(),
      );
    }

    return _AuthFormCard(
      title: 'Verify the OTP',
      description:
          'Enter the 6-digit code sent to ${challenge.maskedDestination}.',
      onBack: widget.onBack,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            enabled: !widget.isBusy,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'OTP code',
              hintText: challenge.debugOtpHint ?? 'Enter 6 digits',
            ),
            onSubmitted: widget.isBusy
                ? null
                : (value) => widget.onVerify(value),
          ),
          if (challenge.debugOtpHint case final String hint) ...[
            const SizedBox(height: 12),
            Text(
              'Debug sandbox OTP: $hint',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
          if (challenge.loginMethod == AuthEntryMethod.child &&
              challenge.childIdentifier != null) ...[
            const SizedBox(height: 12),
            Text(
              'Child identifier: ${challenge.childIdentifier}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: widget.isBusy
                  ? null
                  : () => widget.onVerify(_controller.text),
              child: Text(
                widget.isBusy ? 'Verifying OTP...' : 'Verify and continue',
              ),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: widget.isBusy || widget.resendCooldownSeconds > 0
                  ? null
                  : widget.onResend,
              icon: const Icon(Icons.refresh),
              label: Text(
                widget.resendCooldownSeconds > 0
                    ? 'Resend in ${widget.resendCooldownSeconds}s'
                    : 'Resend OTP',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthFormCard extends StatelessWidget {
  const _AuthFormCard({
    required this.title,
    required this.description,
    required this.onBack,
    required this.child,
  });

  final String title;
  final String description;
  final VoidCallback onBack;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextButton.icon(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back'),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Text(description, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 24),
            child,
          ],
        ),
      ),
    );
  }
}
