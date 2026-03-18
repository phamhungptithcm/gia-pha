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
import '../models/member_identity_verification.dart';
import '../models/pending_otp_challenge.dart';
import '../models/phone_identity_resolution.dart';
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
                widget.clanRepository ??
                createDefaultClanRepository(session: session),
            memberRepository:
                widget.memberRepository ??
                createDefaultMemberRepository(session: session),
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
    controller.setPreferredLanguageCode(
      Localizations.localeOf(context).languageCode,
    );

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
              _AuthStepProgress(step: controller.step),
              const SizedBox(height: 16),
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
                  hasAcceptedPrivacyPolicy: controller.hasAcceptedPrivacyPolicy,
                  onPhoneSelected: () {
                    controller.selectLoginMethod(AuthEntryMethod.phone);
                  },
                  onChildSelected: () {
                    controller.selectLoginMethod(AuthEntryMethod.child);
                  },
                  onPrivacyConsentChanged: (accepted) {
                    unawaited(controller.setPrivacyPolicyAccepted(accepted));
                  },
                  onViewPrivacyPolicy: () => _showPrivacyPolicy(context),
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
                AuthStep.memberSelection => _MemberSelectionCard(
                  resolution: controller.pendingPhoneResolution,
                  isBusy: controller.isBusy,
                  onBack: controller.navigateBack,
                  onCreateNew: controller.chooseCreateNewIdentity,
                  onSelectMember: controller.chooseMemberCandidate,
                ),
                AuthStep.memberVerification => _MemberVerificationCard(
                  challenge: controller.verificationChallenge,
                  isBusy: controller.isBusy,
                  onBack: controller.navigateBack,
                  onSubmitAnswers: controller.submitMemberVerificationAnswers,
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

class _AuthStepProgress extends StatelessWidget {
  const _AuthStepProgress({required this.step});

  final AuthStep step;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final totalSteps = switch (step) {
      AuthStep.memberSelection || AuthStep.memberVerification => 3,
      _ => 2,
    };
    final current = switch (step) {
      AuthStep.loginMethodSelection ||
      AuthStep.phoneNumber ||
      AuthStep.childIdentifier => 1,
      AuthStep.otp || AuthStep.memberSelection => 2,
      AuthStep.memberVerification => 3,
    };
    final title = switch (step) {
      AuthStep.otp => l10n.pick(
        vi: 'Bước 2/2 · Xác thực OTP',
        en: 'Step 2/2 · Verify OTP',
      ),
      AuthStep.memberSelection => l10n.pick(
        vi: 'Bước 2/3 · Chọn hồ sơ',
        en: 'Step 2/3 · Choose profile',
      ),
      AuthStep.memberVerification => l10n.pick(
        vi: 'Bước 3/3 · Xác minh danh tính',
        en: 'Step 3/3 · Verify identity',
      ),
      _ => l10n.pick(
        vi: 'Bước 1/2 · Chọn cách đăng nhập',
        en: 'Step 1/2 · Choose sign-in method',
      ),
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.pick(
                vi: 'Mất khoảng 30 giây để hoàn tất.',
                en: 'This usually takes about 30 seconds.',
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              minHeight: 6,
              value: current / totalSteps,
              borderRadius: BorderRadius.circular(999),
            ),
          ],
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
            l10n.pick(
              vi: 'Chọn cách đăng nhập để vào đúng không gian gia phả.',
              en: 'Choose a sign-in method to open the right family workspace.',
            ),
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
    required this.hasAcceptedPrivacyPolicy,
    required this.onPhoneSelected,
    required this.onChildSelected,
    required this.onPrivacyConsentChanged,
    required this.onViewPrivacyPolicy,
  });

  final bool isBusy;
  final bool hasAcceptedPrivacyPolicy;
  final VoidCallback onPhoneSelected;
  final VoidCallback onChildSelected;
  final ValueChanged<bool> onPrivacyConsentChanged;
  final VoidCallback onViewPrivacyPolicy;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.pick(
                    vi: 'Chọn cách đăng nhập',
                    en: 'Choose your sign-in method',
                  ),
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.pick(
                    vi: 'Chúng tôi chỉ dùng dữ liệu để xác thực tài khoản.',
                    en: 'We only use account data for authentication.',
                  ),
                ),
                const SizedBox(height: 14),
                _MethodActionButton(
                  title: l10n.authMethodPhoneButton,
                  icon: Icons.phone_iphone,
                  filled: true,
                  onPressed: isBusy || !hasAcceptedPrivacyPolicy
                      ? null
                      : onPhoneSelected,
                ),
                const SizedBox(height: 10),
                _MethodActionButton(
                  title: l10n.authMethodChildButton,
                  icon: Icons.child_care,
                  filled: false,
                  onPressed: isBusy || !hasAcceptedPrivacyPolicy
                      ? null
                      : onChildSelected,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _PrivacyPolicyConsentCard(
          isBusy: isBusy,
          hasAcceptedPrivacyPolicy: hasAcceptedPrivacyPolicy,
          onChanged: onPrivacyConsentChanged,
          onViewPrivacyPolicy: onViewPrivacyPolicy,
        ),
      ],
    );
  }
}

class _MethodActionButton extends StatelessWidget {
  const _MethodActionButton({
    required this.title,
    required this.icon,
    required this.filled,
    required this.onPressed,
  });

  final String title;
  final IconData icon;
  final bool filled;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final buttonChild = Row(
      children: [
        Icon(icon),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
        ),
        const Icon(Icons.arrow_forward),
      ],
    );

    if (filled) {
      return SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          child: buttonChild,
        ),
      );
    }
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        child: buttonChild,
      ),
    );
  }
}

class _PrivacyPolicyConsentCard extends StatelessWidget {
  const _PrivacyPolicyConsentCard({
    required this.isBusy,
    required this.hasAcceptedPrivacyPolicy,
    required this.onChanged,
    required this.onViewPrivacyPolicy,
  });

  final bool isBusy;
  final bool hasAcceptedPrivacyPolicy;
  final ValueChanged<bool> onChanged;
  final VoidCallback onViewPrivacyPolicy;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: isBusy ? null : () => onChanged(!hasAcceptedPrivacyPolicy),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Checkbox(
                value: hasAcceptedPrivacyPolicy,
                onChanged: isBusy ? null : (value) => onChanged(value ?? false),
              ),
              Expanded(
                child: Text(
                  l10n.pick(
                    vi: 'Tôi đồng ý chính sách quyền riêng tư.',
                    en: 'I agree to the privacy policy.',
                  ),
                ),
              ),
              TextButton(
                onPressed: onViewPrivacyPolicy,
                child: Text(l10n.pick(vi: 'Xem chính sách', en: 'View policy')),
              ),
              Tooltip(
                message: l10n.pick(
                  vi: 'Chúng tôi chỉ dùng dữ liệu để xác thực tài khoản.',
                  en: 'We only use account data for authentication.',
                ),
                child: const Icon(Icons.info_outline, size: 18),
              ),
            ],
          ),
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
      isBusy: widget.isBusy,
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
              child: _AuthBusyButtonChild(
                isBusy: widget.isBusy,
                idleIcon: Icons.send_outlined,
                label: widget.isBusy ? l10n.authSendingOtp : l10n.authSendOtp,
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
      isBusy: widget.isBusy,
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
              child: _AuthBusyButtonChild(
                isBusy: widget.isBusy,
                idleIcon: Icons.arrow_forward,
                label: widget.isBusy
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
        isBusy: widget.isBusy,
        onBack: widget.onBack,
        child: const SizedBox.shrink(),
      );
    }

    return _AuthFormCard(
      title: l10n.authOtpTitle,
      description: l10n.authOtpDescription(challenge.maskedDestination),
      isBusy: widget.isBusy,
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
              icon: widget.isBusy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.arrow_forward),
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
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      l10n.pick(
                        vi: 'Bạn cần hỗ trợ? Vui lòng liên hệ quản trị gia phả hoặc CSKH BeFam.',
                        en: 'Need help? Please contact your clan admin or BeFam support.',
                      ),
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.support_agent_outlined),
              label: Text(l10n.pick(vi: 'Tôi cần hỗ trợ', en: 'I need help')),
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberSelectionCard extends StatelessWidget {
  const _MemberSelectionCard({
    required this.resolution,
    required this.isBusy,
    required this.onBack,
    required this.onCreateNew,
    required this.onSelectMember,
  });

  final PhoneIdentityResolution? resolution;
  final bool isBusy;
  final VoidCallback onBack;
  final Future<void> Function() onCreateNew;
  final Future<void> Function(String memberId) onSelectMember;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final currentResolution = resolution;
    if (currentResolution == null) {
      return _AuthFormCard(
        title: l10n.pick(
          vi: 'Không có dữ liệu đối soát',
          en: 'No match data found',
        ),
        description: l10n.pick(
          vi: 'Không thể tải danh sách hồ sơ phù hợp. Vui lòng quay lại và thử OTP lại.',
          en: 'We could not load candidate profiles. Please go back and retry OTP.',
        ),
        isBusy: isBusy,
        onBack: onBack,
        child: const SizedBox.shrink(),
      );
    }

    final candidates = currentResolution.candidates;
    return _AuthFormCard(
      title: l10n.pick(
        vi: 'Chọn hồ sơ hoặc tạo mới',
        en: 'Choose a profile or create a new one',
      ),
      description: l10n.pick(
        vi: 'Để bảo vệ dữ liệu, BeFam không liên kết tự động chỉ dựa vào OTP. Hãy chọn hồ sơ phù hợp hoặc tạo mới nếu chưa có hồ sơ của bạn.',
        en: 'For privacy, BeFam does not auto-link based on OTP alone. Choose your profile, or create a new account if none matches.',
      ),
      isBusy: isBusy,
      onBack: onBack,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (candidates.isNotEmpty) ...[
            for (final candidate in candidates) ...[
              Card(
                color: Theme.of(context).colorScheme.surfaceContainerLowest,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        candidate.displayNameMasked,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      if (candidate.clanLabel != null)
                        Text(
                          l10n.pick(
                            vi: 'Dòng tộc: ${candidate.clanLabel}',
                            en: 'Clan: ${candidate.clanLabel}',
                          ),
                        ),
                      Text(
                        l10n.pick(
                          vi: 'Mã hồ sơ: ...${_lastProfileRef(candidate.memberId)}',
                          en: 'Profile ref: ...${_lastProfileRef(candidate.memberId)}',
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (candidate.selectable)
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: isBusy
                                ? null
                                : () => onSelectMember(candidate.memberId),
                            icon: isBusy
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.link),
                            label: Text(
                              l10n.pick(
                                vi: 'Liên kết với hồ sơ này',
                                en: 'Link this profile',
                              ),
                            ),
                          ),
                        )
                      else
                        Text(
                          _blockedReasonLabel(l10n, candidate.blockedReason),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.error,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ] else
            Text(
              l10n.pick(
                vi: currentResolution.allowCreateNew
                    ? 'Chưa tìm thấy hồ sơ phù hợp với số điện thoại này.'
                    : 'Bạn cần liên hệ hỗ trợ để xác minh thủ công cho tài khoản này.',
                en: currentResolution.allowCreateNew
                    ? 'No existing profile matches this phone number.'
                    : 'Please contact support for a manual verification of this account.',
              ),
            ),
          if (currentResolution.allowCreateNew) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: isBusy ? null : onCreateNew,
                icon: isBusy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.person_add_alt_1),
                label: Text(
                  l10n.pick(
                    vi: 'Tạo mới hoàn toàn',
                    en: 'Create as a new account',
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _blockedReasonLabel(dynamic l10n, String? reason) {
    switch (reason) {
      case 'member_linked_other_account':
        return l10n.pick(
          vi: 'Hồ sơ này đã được liên kết với tài khoản khác.',
          en: 'This profile is already linked to another account.',
        );
      case 'member_inactive':
        return l10n.pick(
          vi: 'Hồ sơ này đang ở trạng thái không hoạt động.',
          en: 'This profile is currently inactive.',
        );
      default:
        return l10n.pick(
          vi: 'Hồ sơ này hiện chưa thể liên kết.',
          en: 'This profile cannot be linked right now.',
        );
    }
  }

  String _lastProfileRef(String memberId) {
    final normalized = memberId.trim();
    if (normalized.length <= 6) {
      return normalized;
    }
    return normalized.substring(normalized.length - 6);
  }
}

class _MemberVerificationCard extends StatefulWidget {
  const _MemberVerificationCard({
    required this.challenge,
    required this.isBusy,
    required this.onBack,
    required this.onSubmitAnswers,
  });

  final MemberIdentityVerificationChallenge? challenge;
  final bool isBusy;
  final VoidCallback onBack;
  final Future<void> Function(Map<String, String> answers) onSubmitAnswers;

  @override
  State<_MemberVerificationCard> createState() =>
      _MemberVerificationCardState();
}

class _MemberVerificationCardState extends State<_MemberVerificationCard> {
  final Map<String, String> _answers = <String, String>{};

  @override
  void didUpdateWidget(covariant _MemberVerificationCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.challenge?.verificationSessionId !=
        widget.challenge?.verificationSessionId) {
      _answers.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final challenge = widget.challenge;
    if (challenge == null) {
      return _AuthFormCard(
        title: l10n.pick(
          vi: 'Thiếu dữ liệu xác minh',
          en: 'Missing verification data',
        ),
        description: l10n.pick(
          vi: 'Không thể tải bộ câu hỏi xác minh. Vui lòng quay lại và chọn lại hồ sơ.',
          en: 'We could not load verification questions. Please go back and pick a profile again.',
        ),
        isBusy: widget.isBusy,
        onBack: widget.onBack,
        child: const SizedBox.shrink(),
      );
    }

    final allAnswered = challenge.questions.every(
      (question) => (_answers[question.id] ?? '').isNotEmpty,
    );

    return _AuthFormCard(
      title: l10n.pick(
        vi: 'Xác minh trước khi liên kết',
        en: 'Verify before linking',
      ),
      description: l10n.pick(
        vi: 'Trả lời nhanh các câu hỏi để xác nhận đúng hồ sơ. Chúng tôi chỉ lưu kết quả chấm, không hiển thị đáp án đúng/sai cụ thể.',
        en: 'Answer a few quick questions to confirm this profile. We only store pass/fail results.',
      ),
      isBusy: widget.isBusy,
      onBack: widget.onBack,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.pick(
              vi: 'Số lần còn lại: ${challenge.remainingAttempts}/${challenge.maxAttempts}',
              en: 'Attempts left: ${challenge.remainingAttempts}/${challenge.maxAttempts}',
            ),
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          for (final question in challenge.questions) ...[
            Card(
              color: Theme.of(context).colorScheme.surfaceContainerLowest,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      question.prompt,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    RadioGroup<String>(
                      groupValue: _answers[question.id],
                      onChanged: (value) {
                        if (widget.isBusy || value == null) {
                          return;
                        }
                        setState(() {
                          _answers[question.id] = value;
                        });
                      },
                      child: Column(
                        children: [
                          for (final option in question.options)
                            RadioListTile<String>(
                              value: option.id,
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text(option.label),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: widget.isBusy || !allAnswered
                  ? null
                  : () => widget.onSubmitAnswers(
                      Map<String, String>.from(_answers),
                    ),
              icon: widget.isBusy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.verified_user),
              label: Text(
                widget.isBusy
                    ? l10n.pick(vi: 'Đang xác minh...', en: 'Verifying...')
                    : l10n.pick(
                        vi: 'Xác minh và liên kết',
                        en: 'Verify and link',
                      ),
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
          final tileHeight = (rawTileWidth * 1.28).clamp(52.0, 66.0).toDouble();

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
                l10n.pick(
                  vi: 'Mã 6 số có thể tự điền từ SMS hoặc dán trực tiếp.',
                  en: 'Your 6-digit code supports SMS autofill and paste.',
                ),
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

class _AuthFormCard extends StatelessWidget {
  const _AuthFormCard({
    required this.title,
    required this.description,
    required this.isBusy,
    required this.onBack,
    required this.child,
  });

  final String title;
  final String description;
  final bool isBusy;
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
                  onPressed: isBusy ? null : onBack,
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

class _AuthBusyButtonChild extends StatelessWidget {
  const _AuthBusyButtonChild({
    required this.isBusy,
    required this.idleIcon,
    required this.label,
  });

  final bool isBusy;
  final IconData idleIcon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isBusy)
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else
          Icon(idleIcon),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
          ),
        ),
      ],
    );
  }
}

void _showPrivacyPolicy(BuildContext context) {
  final l10n = context.l10n;
  final theme = Theme.of(context);
  final colorScheme = theme.colorScheme;
  showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      return Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer.withValues(
                        alpha: 0.7,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.privacy_tip_outlined,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l10n.pick(
                        vi: 'Chính sách quyền riêng tư',
                        en: 'Privacy Policy',
                      ),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _PolicyInfoTile(
                icon: Icons.lock_outline,
                text: l10n.pick(
                  vi: 'BeFam chỉ sử dụng số điện thoại hoặc mã định danh trẻ em để xác thực và liên kết hồ sơ thành viên.',
                  en: 'BeFam uses phone number or child identifier only for authentication and profile linking.',
                ),
              ),
              const SizedBox(height: 10),
              _PolicyInfoTile(
                icon: Icons.admin_panel_settings_outlined,
                text: l10n.pick(
                  vi: 'Dữ liệu gia phả được giới hạn theo quyền họ tộc/chi. Không có quyền thì không thể xem dòng tộc khác.',
                  en: 'Genealogy data is restricted by clan/branch permissions. No permission, no cross-clan access.',
                ),
              ),
              const SizedBox(height: 10),
              _PolicyInfoTile(
                icon: Icons.check_circle_outline,
                text: l10n.pick(
                  vi: 'Khi tiếp tục đăng nhập, bạn xác nhận đã đọc và đồng ý với việc xử lý dữ liệu theo chính sách này.',
                  en: 'By continuing sign-in, you confirm that you have read and accepted this policy.',
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.pick(vi: 'Đã hiểu', en: 'Understood')),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _PolicyInfoTile extends StatelessWidget {
  const _PolicyInfoTile({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
