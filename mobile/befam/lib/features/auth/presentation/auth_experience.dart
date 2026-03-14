import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/bootstrap/firebase_setup_status.dart';
import '../../../app/home/app_shell_page.dart';
import '../../../core/services/app_logger.dart';
import '../../../core/services/app_locale_controller.dart';
import '../../../l10n/l10n.dart';
import '../../clan/services/clan_repository.dart';
import '../../member/services/member_repository.dart';
import '../models/auth_entry_method.dart';
import '../models/pending_otp_challenge.dart';
import '../services/auth_analytics_service.dart';
import '../services/auth_gateway.dart';
import '../services/auth_gateway_factory.dart';
import '../services/auth_session_store.dart';
import 'auth_controller.dart';

class AuthExperience extends StatefulWidget {
  const AuthExperience({
    super.key,
    required this.status,
    this.authGateway,
    this.authAnalyticsService,
    this.sessionStore,
    this.clanRepository,
    this.memberRepository,
    this.localeController,
  });

  final FirebaseSetupStatus status;
  final AuthGateway? authGateway;
  final AuthAnalyticsService? authAnalyticsService;
  final AuthSessionStore? sessionStore;
  final ClanRepository? clanRepository;
  final MemberRepository? memberRepository;
  final AppLocaleController? localeController;

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
      analyticsService:
          widget.authAnalyticsService ?? createDefaultAuthAnalyticsService(),
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
            clanRepository:
                widget.clanRepository ?? createDefaultClanRepository(),
            memberRepository:
                widget.memberRepository ?? createDefaultMemberRepository(),
            localeController: widget.localeController,
            onLogoutRequested: _controller.logout,
          );
        }

        return _AuthScaffold(controller: _controller);
      },
    );
  }
}

class _AuthScaffold extends StatelessWidget {
  const _AuthScaffold({required this.controller});
  final AuthController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = context.l10n;

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
              const _AuthHero(),
              const SizedBox(height: 20),
              if (controller.error case final issue?) ...[
                _AuthMessageCard(
                  title: l10n.authSignInNeedsAttention,
                  message: l10n.authIssueMessage(issue),
                  icon: Icons.error_outline,
                  tone: colorScheme.errorContainer,
                ),
                const SizedBox(height: 16),
              ],
              switch (controller.step) {
                AuthStep.loginMethodSelection => _LoginMethodSelectionCard(
                  isBusy: controller.isBusy,
                  showLocalBypass: controller.canUseLocalBypass,
                  onPhoneSelected: () {
                    controller.selectLoginMethod(AuthEntryMethod.phone);
                  },
                  onChildSelected: () {
                    controller.selectLoginMethod(AuthEntryMethod.child);
                  },
                  onLocalBypassSelected: controller.signInWithLocalBypass,
                ),
                AuthStep.phoneNumber => _PhoneLoginCard(
                  isBusy: controller.isBusy,
                  onBack: controller.navigateBack,
                  onSubmit: controller.submitPhoneNumber,
                ),
                AuthStep.childIdentifier => _ChildIdentifierCard(
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
    final l10n = context.l10n;

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
                      l10n.authLoadingTitle,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      status.isReady
                          ? l10n.authLoadingReadyDescription
                          : l10n.authLoadingPendingDescription,
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
  const _AuthHero();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = context.l10n;

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
          Text(
            l10n.authHeroTitle,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: colorScheme.onPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.authHeroLiveDescription,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colorScheme.onPrimary.withValues(alpha: 0.92),
            ),
          ),
        ],
      ),
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
    required this.isBusy,
    required this.showLocalBypass,
    required this.onPhoneSelected,
    required this.onChildSelected,
    required this.onLocalBypassSelected,
  });

  final bool isBusy;
  final bool showLocalBypass;
  final VoidCallback onPhoneSelected;
  final VoidCallback onChildSelected;
  final Future<void> Function() onLocalBypassSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Column(
      children: [
        const _QuickBenefitsCard(),
        if (showLocalBypass) ...[
          const SizedBox(height: 16),
          _MethodCard(
            title: l10n.authSandboxChip,
            description: l10n.authPhoneHelperSandbox,
            icon: Icons.bolt_rounded,
            buttonLabel: l10n.authContinueNow,
            onPressed: isBusy
                ? null
                : () {
                    unawaited(onLocalBypassSelected());
                  },
          ),
        ],
        const SizedBox(height: 16),
        _MethodCard(
          title: l10n.authMethodPhoneTitle,
          description: l10n.authMethodPhoneDescription,
          icon: Icons.phone_iphone,
          buttonLabel: l10n.authMethodPhoneButton,
          onPressed: onPhoneSelected,
        ),
        const SizedBox(height: 16),
        _MethodCard(
          title: l10n.authMethodChildTitle,
          description: l10n.authMethodChildDescription,
          icon: Icons.child_care,
          buttonLabel: l10n.authMethodChildButton,
          onPressed: onChildSelected,
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
  final VoidCallback? onPressed;

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
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onPressed,
                icon: const Icon(Icons.arrow_forward),
                label: Text(buttonLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhoneLoginCard extends StatefulWidget {
  const _PhoneLoginCard({
    required this.isBusy,
    required this.onBack,
    required this.onSubmit,
  });

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
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return _AuthFormCard(
      title: l10n.authPhoneTitle,
      description: l10n.authPhoneDescription,
      onBack: widget.onBack,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AutofillGroup(
            child: TextField(
              controller: _controller,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.telephoneNumber],
              enabled: !widget.isBusy,
              decoration: InputDecoration(
                labelText: l10n.authPhoneLabel,
                hintText: l10n.authPhoneHint,
                prefixIcon: const Icon(Icons.phone_iphone),
                helperText: l10n.authPhoneHelperLive,
              ),
              onSubmitted: widget.isBusy
                  ? null
                  : (value) => widget.onSubmit(value),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: widget.isBusy
                  ? null
                  : () => widget.onSubmit(_controller.text),
              child: Text(
                widget.isBusy ? l10n.authSendingOtp : l10n.authSendOtp,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChildIdentifierCard extends StatefulWidget {
  const _ChildIdentifierCard({
    required this.isBusy,
    required this.onBack,
    required this.onSubmit,
  });

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
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return _AuthFormCard(
      title: l10n.authChildTitle,
      description: l10n.authChildDescription,
      onBack: widget.onBack,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            enabled: !widget.isBusy,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: l10n.authChildLabel,
              hintText: l10n.authChildHint,
              prefixIcon: const Icon(Icons.badge_outlined),
              helperText: l10n.authChildHelper,
            ),
            textCapitalization: TextCapitalization.characters,
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
              child: Text(
                widget.isBusy
                    ? l10n.authResolvingParentPhone
                    : l10n.authContinue,
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
  late final FocusNode _focusNode;
  String _lastSubmittedCode = '';

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();
    _controller.addListener(_refresh);
    _focusNode.addListener(_refresh);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void didUpdateWidget(covariant _OtpVerificationCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final currentVerificationId = widget.challenge?.verificationId;
    final previousVerificationId = oldWidget.challenge?.verificationId;

    if (currentVerificationId != previousVerificationId) {
      _controller.clear();
      _lastSubmittedCode = '';
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _focusNode.requestFocus();
        }
      });
    } else if (oldWidget.isBusy && !widget.isBusy) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _focusNode.requestFocus();
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_refresh);
    _focusNode.removeListener(_refresh);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _submitCode(String value) async {
    final sanitized = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (sanitized.length != 6 || widget.isBusy) {
      return;
    }

    _lastSubmittedCode = sanitized;
    await widget.onVerify(sanitized);
  }

  void _handleCodeChanged(String value) {
    final sanitized = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (sanitized != value) {
      _controller.value = TextEditingValue(
        text: sanitized,
        selection: TextSelection.collapsed(offset: sanitized.length),
      );
      return;
    }

    if (sanitized.length < 6) {
      _lastSubmittedCode = '';
      return;
    }

    if (!widget.isBusy && sanitized != _lastSubmittedCode) {
      unawaited(_submitCode(sanitized));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final challenge = widget.challenge;
    if (challenge == null) {
      AppLogger.warning('OTP screen rendered without a pending challenge.');
      return _AuthFormCard(
        title: l10n.authOtpMissingTitle,
        description: l10n.authOtpMissingDescription,
        onBack: widget.onBack,
        child: const SizedBox.shrink(),
      );
    }

    return _AuthFormCard(
      title: l10n.authOtpTitle,
      description: l10n.authOtpDescription(challenge.maskedDestination),
      onBack: widget.onBack,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _OtpCodeField(
            controller: _controller,
            focusNode: _focusNode,
            enabled: !widget.isBusy,
            onChanged: _handleCodeChanged,
            onSubmitted: _submitCode,
          ),
          if (challenge.loginMethod == AuthEntryMethod.child &&
              challenge.childIdentifier != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  const Icon(Icons.child_care_outlined),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l10n.authOtpChildIdentifier(challenge.childIdentifier!),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: widget.isBusy || _controller.text.length < 6
                  ? null
                  : () => _submitCode(_controller.text),
              icon: Icon(
                widget.isBusy ? Icons.more_horiz : Icons.arrow_forward,
              ),
              label: Text(
                widget.isBusy ? l10n.authVerifyingOtp : l10n.authContinueNow,
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
                    ? l10n.authResendIn(widget.resendCooldownSeconds)
                    : l10n.authResendOtp,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OtpCodeField extends StatelessWidget {
  const _OtpCodeField({
    required this.controller,
    required this.focusNode,
    required this.enabled,
    required this.onChanged,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    final code = controller.text;
    final focusedIndex = code.length >= 6 ? 5 : code.length;
    final l10n = context.l10n;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? focusNode.requestFocus : null,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final spacing = constraints.maxWidth < 320 ? 6.0 : 8.0;
          final rawTileWidth =
              (constraints.maxWidth - (spacing * 5)).clamp(
                0.0,
                double.infinity,
              ) /
              6;
          final tileHeight = (rawTileWidth * 1.28).clamp(44.0, 58.0).toDouble();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: tileHeight,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    ExcludeSemantics(
                      child: Row(
                        children: [
                          for (var index = 0; index < 6; index++) ...[
                            Expanded(
                              child: _OtpDigitTile(
                                digit: index < code.length ? code[index] : '',
                                height: tileHeight,
                                isActive:
                                    focusNode.hasFocus && focusedIndex == index,
                                isFilled: index < code.length,
                                enabled: enabled,
                              ),
                            ),
                            if (index < 5) SizedBox(width: spacing),
                          ],
                        ],
                      ),
                    ),
                    Positioned.fill(
                      child: IgnorePointer(
                        ignoring: !enabled,
                        child: Opacity(
                          opacity: 0.02,
                          child: TextField(
                            key: const Key('otp-code-input'),
                            controller: controller,
                            focusNode: focusNode,
                            enabled: enabled,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.done,
                            autofillHints: const [AutofillHints.oneTimeCode],
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(6),
                            ],
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                              isCollapsed: true,
                            ),
                            cursorColor: Colors.transparent,
                            showCursor: false,
                            style: const TextStyle(color: Colors.transparent),
                            onChanged: onChanged,
                            onSubmitted: onSubmitted,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.authOtpHelpText,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _OtpDigitTile extends StatelessWidget {
  const _OtpDigitTile({
    required this.digit,
    required this.height,
    required this.isActive,
    required this.isFilled,
    required this.enabled,
  });

  final String digit;
  final double height;
  final bool isActive;
  final bool isFilled;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final borderColor = isActive
        ? colorScheme.primary
        : isFilled
        ? colorScheme.outline
        : colorScheme.outlineVariant;
    final backgroundColor = isActive
        ? colorScheme.primaryContainer
        : isFilled
        ? colorScheme.surfaceContainerHighest
        : colorScheme.surface;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: enabled
            ? backgroundColor
            : colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor, width: isActive ? 2 : 1.2),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: colorScheme.primary.withValues(alpha: 0.18),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: Text(
        digit,
        style: theme.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w800,
          color: enabled
              ? colorScheme.onSurface
              : colorScheme.onSurface.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}

class _QuickBenefitsCard extends StatelessWidget {
  const _QuickBenefitsCard();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.authQuickBenefitsTitle,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.authQuickBenefitsDescription,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _BenefitChip(
                  icon: Icons.sms_outlined,
                  label: l10n.authQuickBenefitAutoContinue,
                ),
                _BenefitChip(
                  icon: Icons.family_restroom_outlined,
                  label: l10n.authQuickBenefitMultipleAccess,
                ),
                _BenefitChip(
                  icon: Icons.verified_user_outlined,
                  label: l10n.authQuickBenefitLive,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BenefitChip extends StatelessWidget {
  const _BenefitChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            OverflowBar(
              alignment: MainAxisAlignment.spaceBetween,
              overflowAlignment: OverflowBarAlignment.end,
              spacing: 12,
              overflowSpacing: 8,
              children: [
                TextButton.icon(
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back),
                  label: Text(context.l10n.authBack),
                ),
                Icon(Icons.lock_outline, color: colorScheme.primary),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Text(description, style: theme.textTheme.bodyLarge),
            const SizedBox(height: 24),
            child,
          ],
        ),
      ),
    );
  }
}
