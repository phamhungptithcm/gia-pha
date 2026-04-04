part of 'auth_experience.dart';

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
              colorScheme.secondaryContainer.withValues(alpha: 0.18),
              colorScheme.surfaceContainerLowest.withValues(alpha: 0.92),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: AppWorkspaceViewport(
            child: ListView(
              padding: appWorkspacePagePadding(context, top: 20, bottom: 32),
              children: [
                _AuthHero(
                  step: controller.step,
                  challenge: controller.pendingChallenge,
                  resolution: controller.pendingPhoneResolution,
                  verificationChallenge: controller.verificationChallenge,
                ),
                const SizedBox(height: 16),
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
                    hasAcceptedPrivacyPolicy:
                        controller.hasAcceptedPrivacyPolicy,
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
                    onSubmit: (value, countryIsoCode) {
                      return controller.submitPhoneNumber(
                        value,
                        countryIsoCode: countryIsoCode,
                      );
                    },
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
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              colorScheme.surface,
              colorScheme.secondaryContainer.withValues(alpha: 0.16),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: AppWorkspaceSurface(
                gradient: appWorkspaceHeroGradient(context),
                showAccentOrbs: true,
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
    final tokens = context.uiTokens;
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
      AuthStep.otp => l10n.pick(vi: 'Nhập mã OTP', en: 'Enter OTP'),
      AuthStep.memberSelection => l10n.pick(
        vi: 'Chọn hồ sơ phù hợp',
        en: 'Choose your profile',
      ),
      AuthStep.memberVerification => l10n.pick(
        vi: 'Xác nhận danh tính',
        en: 'Confirm your identity',
      ),
      _ => l10n.pick(
        vi: 'Chọn cách vào BeFam',
        en: 'Choose how to enter BeFam',
      ),
    };
    return AppWorkspaceSurface(
      padding: EdgeInsets.fromLTRB(
        tokens.spaceLg,
        tokens.spaceMd,
        tokens.spaceLg,
        tokens.spaceMd,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              _AuthHeroChip(
                icon: Icons.timeline,
                label: l10n.pick(
                  vi: 'Bước $current/$totalSteps',
                  en: 'Step $current/$totalSteps',
                ),
              ),
            ],
          ),
          SizedBox(height: tokens.spaceMd),
          Row(
            children: [
              for (var index = 0; index < totalSteps; index++) ...[
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    height: 7,
                    decoration: BoxDecoration(
                      color: index < current
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                if (index < totalSteps - 1) SizedBox(width: tokens.spaceSm),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _AuthHero extends StatelessWidget {
  const _AuthHero({
    required this.step,
    required this.challenge,
    required this.resolution,
    required this.verificationChallenge,
  });

  final AuthStep step;
  final PendingOtpChallenge? challenge;
  final PhoneIdentityResolution? resolution;
  final MemberIdentityVerificationChallenge? verificationChallenge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final tokens = context.uiTokens;
    final isLoginMethodSelection = step == AuthStep.loginMethodSelection;
    final isCompact = !isLoginMethodSelection;
    final showHeroIcon = !isLoginMethodSelection && step != AuthStep.otp;

    final title = switch (step) {
      AuthStep.loginMethodSelection => l10n.pick(
        vi: 'Vào BeFam để tiếp tục với gia đình bạn',
        en: 'Enter BeFam to stay close to your family',
      ),
      AuthStep.phoneNumber => l10n.pick(
        vi: 'Nhập số điện thoại của bạn',
        en: 'Enter your phone number',
      ),
      AuthStep.childIdentifier => l10n.pick(
        vi: 'Nhập mã dành cho bé',
        en: 'Enter the child access code',
      ),
      AuthStep.otp => l10n.pick(
        vi: 'Nhập mã xác nhận',
        en: 'Enter the verification code',
      ),
      AuthStep.memberSelection => l10n.pick(
        vi: 'Đây có phải là hồ sơ của bạn?',
        en: 'Is this your profile?',
      ),
      AuthStep.memberVerification => l10n.pick(
        vi: 'Xác nhận một vài thông tin',
        en: 'Confirm a few details',
      ),
    };
    final subtitle = switch (step) {
      AuthStep.loginMethodSelection => l10n.pick(
        vi: 'Xem gia phả, lịch họ và cập nhật từ người thân ở cùng một nơi.',
        en: 'See your family tree, family events, and updates from loved ones in one place.',
      ),
      AuthStep.phoneNumber => l10n.pick(
        vi: 'BeFam sẽ gửi mã OTP để xác nhận tài khoản của bạn.',
        en: 'BeFam will send an OTP to confirm your account.',
      ),
      AuthStep.childIdentifier => l10n.pick(
        vi: 'Dùng mã được người thân hoặc quản trị viên gửi cho tài khoản của bé.',
        en: 'Use the code shared for the child account by a family member or admin.',
      ),
      AuthStep.otp => '',
      AuthStep.memberSelection => '',
      AuthStep.memberVerification => l10n.pick(
        vi: 'Trả lời từng câu ngắn để chúng tôi xác nhận đúng hồ sơ của bạn.',
        en: 'Answer a few short questions so we can confirm the correct profile.',
      ),
    };

    final Widget? statusChip = switch (step) {
      AuthStep.otp => _AuthHeroChip(
        icon: Icons.sms_outlined,
        label: challenge?.provider == AuthOtpProvider.firebase
            ? l10n.pick(vi: 'Mã gửi qua SMS', en: 'SMS delivery')
            : l10n.pick(vi: 'Mã xác nhận nhanh', en: 'Fast verification'),
      ),
      AuthStep.memberSelection => null,
      AuthStep.memberVerification => _AuthHeroChip(
        icon: Icons.fact_check_outlined,
        label: l10n.pick(
          vi: 'Còn ${verificationChallenge?.remainingAttempts ?? 0}/${verificationChallenge?.maxAttempts ?? 0} lượt',
          en: '${verificationChallenge?.remainingAttempts ?? 0}/${verificationChallenge?.maxAttempts ?? 0} attempts left',
        ),
      ),
      _ => _AuthHeroChip(
        icon: Icons.shield_outlined,
        label: l10n.pick(vi: 'Đăng nhập an toàn', en: 'Secure sign-in'),
      ),
    };

    return AppWorkspaceSurface(
      gradient: appWorkspaceHeroGradient(context),
      showAccentOrbs: true,
      padding: EdgeInsets.all(tokens.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showHeroIcon) ...[
            Container(
              width: isCompact ? 42 : 48,
              height: isCompact ? 42 : 48,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(tokens.radiusMd),
              ),
              child: Icon(switch (step) {
                AuthStep.loginMethodSelection => Icons.login_rounded,
                AuthStep.phoneNumber => Icons.phone_iphone_rounded,
                AuthStep.childIdentifier => Icons.child_care_rounded,
                AuthStep.otp => Icons.password_rounded,
                AuthStep.memberSelection => Icons.badge_outlined,
                AuthStep.memberVerification => Icons.verified_user_outlined,
              }, color: theme.colorScheme.primary),
            ),
            SizedBox(height: isCompact ? tokens.spaceMd : tokens.spaceLg),
          ],
          Text(
            title,
            style:
                (isCompact
                        ? theme.textTheme.titleLarge
                        : theme.textTheme.headlineSmall)
                    ?.copyWith(fontWeight: FontWeight.w800, height: 1.12),
          ),
          if (subtitle.trim().isNotEmpty) ...[
            SizedBox(height: tokens.spaceSm),
            Text(
              subtitle,
              style: isCompact
                  ? theme.textTheme.bodyMedium
                  : theme.textTheme.bodyLarge,
            ),
          ],
          if (!isLoginMethodSelection && statusChip != null) ...[
            SizedBox(height: isCompact ? tokens.spaceMd : tokens.spaceLg),
            Wrap(
              spacing: tokens.spaceSm,
              runSpacing: tokens.spaceSm,
              children: [statusChip],
            ),
          ],
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
    final tokens = context.uiTokens;

    return Column(
      children: [
        AppWorkspaceSurface(
          showAccentOrbs: false,
          padding: EdgeInsets.all(tokens.spaceLg),
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
              SizedBox(height: tokens.spaceLg),
              _MethodActionButton(
                buttonKey: const Key('auth-method-phone-button'),
                title: l10n.pick(
                  vi: 'Dùng số điện thoại',
                  en: 'Use phone number',
                ),
                icon: Icons.phone_iphone,
                filled: true,
                onPressed: isBusy || !hasAcceptedPrivacyPolicy
                    ? null
                    : onPhoneSelected,
              ),
              SizedBox(height: tokens.spaceSm),
              _MethodActionButton(
                buttonKey: const Key('auth-method-child-button'),
                title: l10n.pick(
                  vi: 'Dùng mã dành cho bé',
                  en: 'Use child access code',
                ),
                icon: Icons.child_care,
                filled: false,
                onPressed: isBusy || !hasAcceptedPrivacyPolicy
                    ? null
                    : onChildSelected,
              ),
            ],
          ),
        ),
        SizedBox(height: tokens.spaceSm),
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
    required this.buttonKey,
    required this.title,
    required this.icon,
    required this.filled,
    required this.onPressed,
    this.subtitle,
  });

  final Key buttonKey;
  final String title;
  final String? subtitle;
  final IconData icon;
  final bool filled;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.uiTokens;
    final colorScheme = Theme.of(context).colorScheme;

    final buttonChild = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: filled
                ? colorScheme.onPrimary.withValues(alpha: 0.14)
                : colorScheme.primaryContainer.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(tokens.radiusMd),
          ),
          child: Icon(icon),
        ),
        SizedBox(width: tokens.spaceMd),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
              if (subtitle != null && subtitle!.isNotEmpty) ...[
                SizedBox(height: tokens.spaceXs),
                Text(subtitle!, maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ],
          ),
        ),
        SizedBox(width: tokens.spaceSm),
        const Icon(Icons.arrow_forward),
      ],
    );

    if (filled) {
      return SizedBox(
        width: double.infinity,
        child: FilledButton(
          key: buttonKey,
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            padding: EdgeInsets.symmetric(
              horizontal: tokens.spaceLg,
              vertical: tokens.spaceSm + 2,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(tokens.radiusMd),
            ),
          ),
          child: buttonChild,
        ),
      );
    }
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        key: buttonKey,
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.symmetric(
            horizontal: tokens.spaceLg,
            vertical: tokens.spaceSm + 2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(tokens.radiusMd),
          ),
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
    final tokens = context.uiTokens;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isAccepted = hasAcceptedPrivacyPolicy;

    return AppWorkspaceSurface(
      color: colorScheme.surface.withValues(alpha: 0.94),
      padding: EdgeInsets.all(tokens.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(tokens.radiusMd),
                ),
                child: Icon(
                  Icons.shield_outlined,
                  color: colorScheme.primary,
                  size: 18,
                ),
              ),
              SizedBox(width: tokens.spaceSm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.pick(
                        vi: 'Bảo vệ tài khoản của bạn',
                        en: 'Protect your account',
                      ),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              AppCompactTextButton(
                onPressed: onViewPrivacyPolicy,
                child: Text(l10n.pick(vi: 'Xem chính sách', en: 'View policy')),
              ),
            ],
          ),
          SizedBox(height: tokens.spaceMd),
          InkWell(
            borderRadius: BorderRadius.circular(tokens.radiusMd),
            onTap: isBusy ? null : () => onChanged(!isAccepted),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: EdgeInsets.symmetric(
                horizontal: tokens.spaceMd,
                vertical: tokens.spaceSm,
              ),
              decoration: BoxDecoration(
                color: isAccepted
                    ? colorScheme.primaryContainer.withValues(alpha: 0.5)
                    : colorScheme.surfaceContainerLowest.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(tokens.radiusMd),
                border: Border.all(
                  color: isAccepted
                      ? colorScheme.primary.withValues(alpha: 0.32)
                      : colorScheme.outlineVariant,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Checkbox(
                    key: const Key('auth-privacy-checkbox'),
                    value: isAccepted,
                    onChanged: isBusy
                        ? null
                        : (value) => onChanged(value ?? false),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  SizedBox(width: tokens.spaceXs),
                  Expanded(
                    child: Text(
                      isAccepted
                          ? l10n.pick(
                              vi: 'Bạn đã đồng ý với chính sách riêng tư.',
                              en: 'You agreed to the Privacy Policy.',
                            )
                          : l10n.pick(
                              vi: 'Tôi đồng ý với chính sách riêng tư của BeFam.',
                              en: 'I agree to BeFam’s Privacy Policy.',
                            ),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (isAccepted)
                    Icon(
                      Icons.check_circle_rounded,
                      color: colorScheme.primary,
                      size: 18,
                    ),
                ],
              ),
            ),
          ),
        ],
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
  final Future<void> Function(String value, String countryIsoCode) onSubmit;

  @override
  State<_PhoneLoginCard> createState() => _PhoneLoginCardState();
}

class _PhoneLoginCardState extends State<_PhoneLoginCard> {
  late final TextEditingController _controller;
  late String _selectedCountryIsoCode;
  bool _resolvedAutoCountry = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _selectedCountryIsoCode = PhoneNumberFormatter.defaultCountryIsoCode;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_resolvedAutoCountry) {
      return;
    }
    final locale = Localizations.localeOf(context);
    _selectedCountryIsoCode = PhoneNumberFormatter.autoCountryIsoFromRegion(
      locale.countryCode,
    );
    _resolvedAutoCountry = true;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _normalizePhoneInputForCountry() {
    final normalized = PhoneNumberFormatter.toNationalInput(
      _controller.text,
      defaultCountryIso: _selectedCountryIsoCode,
    );
    if (normalized == _controller.text.trim()) {
      return;
    }
    _controller
      ..text = normalized
      ..selection = TextSelection.collapsed(offset: normalized.length);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final phoneHint = PhoneNumberFormatter.nationalNumberHint(
      _selectedCountryIsoCode,
    );

    return _AuthFormCard(
      title: l10n.pick(
        vi: 'Nhập số điện thoại của bạn',
        en: 'Enter your phone number',
      ),
      isBusy: widget.isBusy,
      onBack: widget.onBack,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AutofillGroup(
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PhoneCountrySelectorField(
                      selectedIsoCode: _selectedCountryIsoCode,
                      enabled: !widget.isBusy,
                      onChanged: (value) {
                        setState(() {
                          _selectedCountryIsoCode = value;
                          _normalizePhoneInputForCountry();
                        });
                      },
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        key: const Key('auth-phone-input'),
                        controller: _controller,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.telephoneNumber],
                        enabled: !widget.isBusy,
                        decoration: InputDecoration(
                          labelText: l10n.authPhoneLabel,
                          hintText: phoneHint,
                        ),
                        onEditingComplete: _normalizePhoneInputForCountry,
                        onSubmitted: widget.isBusy
                            ? null
                            : (_) {
                                _normalizePhoneInputForCountry();
                                widget.onSubmit(
                                  _controller.text,
                                  _selectedCountryIsoCode,
                                );
                              },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _AuthInlineInfo(
            icon: Icons.sms_outlined,
            text: l10n.pick(
              vi: 'Mã xác nhận sẽ được gửi đến số bạn vừa nhập.',
              en: 'The verification code will be sent to this number.',
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const Key('auth-send-otp-button'),
              onPressed: widget.isBusy
                  ? null
                  : () {
                      _normalizePhoneInputForCountry();
                      widget.onSubmit(
                        _controller.text,
                        _selectedCountryIsoCode,
                      );
                    },
              child: _AuthBusyButtonChild(
                isBusy: widget.isBusy,
                idleIcon: Icons.send_outlined,
                label: widget.isBusy
                    ? l10n.pick(vi: 'Đang gửi mã OTP...', en: 'Sending OTP...')
                    : l10n.pick(vi: 'Nhận mã OTP', en: 'Get OTP code'),
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
      title: l10n.pick(
        vi: 'Nhập mã dành cho bé',
        en: 'Enter the child access code',
      ),
      description: l10n.pick(
        vi: 'Mã này thường được người thân hoặc quản trị viên gửi riêng cho tài khoản của bé.',
        en: 'This code is usually shared by a family member or an admin for the child account.',
      ),
      isBusy: widget.isBusy,
      onBack: widget.onBack,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            key: const Key('auth-child-code-input'),
            controller: _controller,
            enabled: !widget.isBusy,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: l10n.authChildLabel,
              hintText: l10n.authChildHint,
              prefixIcon: const Icon(Icons.badge_outlined),
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
              key: const Key('auth-child-continue-button'),
              onPressed: widget.isBusy
                  ? null
                  : () => widget.onSubmit(_controller.text),
              child: _AuthBusyButtonChild(
                isBusy: widget.isBusy,
                idleIcon: Icons.arrow_forward,
                label: widget.isBusy
                    ? l10n.pick(
                        vi: 'Đang kiểm tra mã...',
                        en: 'Checking the code...',
                      )
                    : l10n.pick(vi: 'Tiếp tục', en: 'Continue'),
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
      title: l10n.pick(
        vi: 'Nhập mã xác nhận',
        en: 'Enter the verification code',
      ),
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
            _AuthInlineInfo(
              icon: Icons.child_care_outlined,
              text: l10n.authOtpChildIdentifier(challenge.childIdentifier!),
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
                widget.isBusy
                    ? l10n.pick(
                        vi: 'Đang kiểm tra mã...',
                        en: 'Checking code...',
                      )
                    : l10n.pick(vi: 'Xác nhận mã', en: 'Confirm code'),
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
                    ? l10n.pick(
                        vi: 'Gửi lại sau ${widget.resendCooldownSeconds}s',
                        en: 'Resend in ${widget.resendCooldownSeconds}s',
                      )
                    : l10n.pick(vi: 'Gửi lại mã', en: 'Resend code'),
              ),
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
          vi: 'Không thể tải danh sách hồ sơ phù hợp. Vui lòng thử lại.',
          en: 'We could not load matching profiles. Please try again.',
        ),
        isBusy: isBusy,
        onBack: onBack,
        child: const SizedBox.shrink(),
      );
    }

    final candidates = currentResolution.candidates;
    return _AuthFormCard(
      title: l10n.pick(
        vi: 'Đây có phải là hồ sơ của bạn?',
        en: 'Is this your profile?',
      ),
      isBusy: isBusy,
      onBack: onBack,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (candidates.isNotEmpty) ...[
            for (final candidate in candidates) ...[
              AppWorkspaceSurface(
                color: Theme.of(
                  context,
                ).colorScheme.surfaceContainerLowest.withValues(alpha: 0.96),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .primaryContainer
                                .withValues(alpha: 0.62),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.person_outline),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                candidate.displayNameMasked,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (candidate.selectable)
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
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
                              : const Icon(Icons.check_circle_outline),
                          label: Text(
                            l10n.pick(
                              vi: 'Đúng, đây là tôi',
                              en: 'Yes, this is me',
                            ),
                          ),
                        ),
                      )
                    else
                      Text(
                        _blockedReasonLabel(context, candidate.blockedReason),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
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
                  l10n.pick(vi: 'Tạo hồ sơ mới', en: 'Create a new profile'),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _blockedReasonLabel(BuildContext context, String? reason) {
    final l10n = context.l10n;
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
  int _currentQuestionIndex = 0;

  @override
  void didUpdateWidget(covariant _MemberVerificationCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.challenge?.verificationSessionId !=
        widget.challenge?.verificationSessionId) {
      _answers.clear();
      _currentQuestionIndex = 0;
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

    if (challenge.questions.isEmpty) {
      return _AuthFormCard(
        title: l10n.pick(
          vi: 'Chưa có câu hỏi xác minh',
          en: 'No verification questions yet',
        ),
        description: l10n.pick(
          vi: 'Bạn có thể quay lại và chọn hồ sơ khác hoặc thử lại sau.',
          en: 'You can go back, choose another profile, or try again later.',
        ),
        isBusy: widget.isBusy,
        onBack: widget.onBack,
        child: const SizedBox.shrink(),
      );
    }

    final question = challenge.questions[_currentQuestionIndex];
    final currentAnswer = _answers[question.id];
    final isLastQuestion =
        _currentQuestionIndex == challenge.questions.length - 1;
    final allAnswered = challenge.questions.every(
      (item) => (_answers[item.id] ?? '').isNotEmpty,
    );

    return _AuthFormCard(
      title: l10n.pick(
        vi: 'Xác nhận một vài thông tin',
        en: 'Confirm a few details',
      ),
      description: l10n.pick(
        vi: 'Mỗi bước chỉ có một câu hỏi ngắn để bảo vệ tài khoản của bạn.',
        en: 'Each step shows one short question to keep your account safe.',
      ),
      isBusy: widget.isBusy,
      onBack: widget.onBack,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _AuthHeroChip(
                icon: Icons.timeline,
                label: l10n.pick(
                  vi: 'Câu ${_currentQuestionIndex + 1}/${challenge.questions.length}',
                  en: 'Question ${_currentQuestionIndex + 1}/${challenge.questions.length}',
                ),
              ),
              _AuthHeroChip(
                icon: Icons.fact_check_outlined,
                label: l10n.pick(
                  vi: 'Còn ${challenge.remainingAttempts}/${challenge.maxAttempts} lượt',
                  en: '${challenge.remainingAttempts}/${challenge.maxAttempts} attempts left',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          AppWorkspaceSurface(
            color: Theme.of(
              context,
            ).colorScheme.surfaceContainerLowest.withValues(alpha: 0.98),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _AuthHeroChip(
                  icon: Icons.help_outline,
                  label: _verificationCategoryLabel(context, question.category),
                ),
                const SizedBox(height: 14),
                Text(
                  question.prompt,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 16),
                for (final option in question.options) ...[
                  _VerificationOptionTile(
                    label: option.label,
                    selected: currentAnswer == option.id,
                    enabled: !widget.isBusy,
                    onTap: () {
                      setState(() {
                        _answers[question.id] = option.id;
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (_currentQuestionIndex > 0) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: widget.isBusy
                        ? null
                        : () {
                            setState(() {
                              _currentQuestionIndex -= 1;
                            });
                          },
                    icon: const Icon(Icons.arrow_back),
                    label: Text(l10n.pick(vi: 'Câu trước', en: 'Previous')),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: FilledButton.icon(
                  onPressed: widget.isBusy || currentAnswer == null
                      ? null
                      : () {
                          if (isLastQuestion) {
                            if (!allAnswered) {
                              return;
                            }
                            widget.onSubmitAnswers(
                              Map<String, String>.from(_answers),
                            );
                            return;
                          }
                          setState(() {
                            _currentQuestionIndex += 1;
                          });
                        },
                  icon: widget.isBusy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          isLastQuestion
                              ? Icons.verified_user_outlined
                              : Icons.arrow_forward,
                        ),
                  label: Text(
                    widget.isBusy
                        ? l10n.pick(vi: 'Đang xác minh...', en: 'Verifying...')
                        : isLastQuestion
                        ? l10n.pick(
                            vi: 'Xác minh và tiếp tục',
                            en: 'Verify and continue',
                          )
                        : l10n.pick(vi: 'Tiếp tục', en: 'Continue'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _verificationCategoryLabel(BuildContext context, String category) {
    final l10n = context.l10n;
    switch (category) {
      case 'family':
      case 'clan':
        return l10n.pick(vi: 'Thông tin gia đình', en: 'Family details');
      case 'contact':
        return l10n.pick(vi: 'Thông tin liên hệ', en: 'Contact details');
      default:
        return l10n.pick(vi: 'Thông tin cá nhân', en: 'Personal details');
    }
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
    required this.isBusy,
    required this.onBack,
    required this.child,
    this.description,
  });

  final String title;
  final String? description;
  final bool isBusy;
  final VoidCallback onBack;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.uiTokens;

    return AppWorkspaceSurface(
      showAccentOrbs: true,
      padding: EdgeInsets.all(tokens.spaceXl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OverflowBar(
            alignment: MainAxisAlignment.spaceBetween,
            overflowAlignment: OverflowBarAlignment.end,
            spacing: 12,
            overflowSpacing: 8,
            children: [
              AppCompactTextButton(
                onPressed: isBusy ? null : onBack,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.arrow_back, size: 18),
                    const SizedBox(width: 6),
                    Text(context.l10n.authBack),
                  ],
                ),
              ),
              _AuthHeroChip(
                icon: Icons.lock_outline,
                label: context.l10n.pick(vi: 'Bảo mật', en: 'Secure'),
              ),
            ],
          ),
          SizedBox(height: tokens.spaceSm),
          Text(
            title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              height: 1.14,
            ),
          ),
          if (description != null && description!.trim().isNotEmpty) ...[
            SizedBox(height: tokens.spaceSm),
            Text(description!, style: theme.textTheme.bodyLarge),
          ],
          SizedBox(height: tokens.spaceXl),
          child,
        ],
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

class _AuthHeroChip extends StatelessWidget {
  const _AuthHeroChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final tokens = context.uiTokens;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spaceMd,
        vertical: tokens.spaceSm,
      ),
      decoration: BoxDecoration(
        color: colorScheme.onSurface.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(tokens.radiusPill),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.88),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: colorScheme.primary),
          SizedBox(width: tokens.spaceXs),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _AuthInlineInfo extends StatelessWidget {
  const _AuthInlineInfo({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final tokens = context.uiTokens;

    return Container(
      padding: EdgeInsets.all(tokens.spaceMd),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(tokens.radiusMd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: colorScheme.primary),
          SizedBox(width: tokens.spaceSm),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

class _VerificationOptionTile extends StatelessWidget {
  const _VerificationOptionTile({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final tokens = context.uiTokens;

    return InkWell(
      borderRadius: BorderRadius.circular(tokens.radiusMd),
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: EdgeInsets.all(tokens.spaceMd),
        decoration: BoxDecoration(
          color: selected
              ? colorScheme.primaryContainer.withValues(alpha: 0.72)
              : colorScheme.surface,
          borderRadius: BorderRadius.circular(tokens.radiusMd),
          border: Border.all(
            color: selected
                ? colorScheme.primary
                : colorScheme.outlineVariant.withValues(alpha: 0.92),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? colorScheme.primary : colorScheme.outline,
            ),
          ],
        ),
      ),
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
