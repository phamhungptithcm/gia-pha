import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
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
                  showSandboxProfiles: kDebugMode,
                  enableAutoBypass: controller.canUseLocalBypass,
                  hasAcceptedPrivacyPolicy: controller.hasAcceptedPrivacyPolicy,
                  onPhoneSelected: () {
                    controller.selectLoginMethod(AuthEntryMethod.phone);
                  },
                  onChildSelected: () {
                    controller.selectLoginMethod(AuthEntryMethod.child);
                  },
                  onSandboxProfileSelected: (phoneE164, autoOtpCode) {
                    if (controller.canUseLocalBypass) {
                      return controller.signInWithLocalBypassPhone(phoneE164);
                    }
                    return controller.requestOtpForScenarioPhone(
                      phoneE164,
                      autoVerifyCode: autoOtpCode,
                    );
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
            l10n.pick(
              vi: 'Đăng nhập bằng số điện thoại hoặc mã trẻ em để vào đúng không gian gia phả và tiếp tục ngay sau khi xác minh OTP.',
              en: 'Sign in with phone or child ID to enter the correct genealogy workspace and continue right after OTP verification.',
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
    required this.showSandboxProfiles,
    required this.enableAutoBypass,
    required this.hasAcceptedPrivacyPolicy,
    required this.onPhoneSelected,
    required this.onChildSelected,
    required this.onSandboxProfileSelected,
    required this.onPrivacyConsentChanged,
    required this.onViewPrivacyPolicy,
  });

  final bool isBusy;
  final bool showSandboxProfiles;
  final bool enableAutoBypass;
  final bool hasAcceptedPrivacyPolicy;
  final VoidCallback onPhoneSelected;
  final VoidCallback onChildSelected;
  final Future<void> Function(String phoneE164, String? autoOtpCode)
  onSandboxProfileSelected;
  final ValueChanged<bool> onPrivacyConsentChanged;
  final VoidCallback onViewPrivacyPolicy;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Column(
      children: [
        const _QuickBenefitsCard(),
        const SizedBox(height: 16),
        _PrivacyPolicyConsentCard(
          isBusy: isBusy,
          hasAcceptedPrivacyPolicy: hasAcceptedPrivacyPolicy,
          onChanged: onPrivacyConsentChanged,
          onViewPrivacyPolicy: onViewPrivacyPolicy,
        ),
        const SizedBox(height: 16),
        _MethodCard(
          title: l10n.authMethodPhoneTitle,
          description: l10n.authMethodPhoneDescription,
          icon: Icons.phone_iphone,
          buttonLabel: l10n.authMethodPhoneButton,
          onPressed: isBusy || !hasAcceptedPrivacyPolicy
              ? null
              : onPhoneSelected,
        ),
        const SizedBox(height: 16),
        _MethodCard(
          title: l10n.authMethodChildTitle,
          description: l10n.authMethodChildDescription,
          icon: Icons.child_care,
          buttonLabel: l10n.authMethodChildButton,
          onPressed: isBusy || !hasAcceptedPrivacyPolicy
              ? null
              : onChildSelected,
        ),
        if (showSandboxProfiles) ...[
          const SizedBox(height: 16),
          _SandboxEnvironmentCard(
            isBusy: isBusy,
            hasAcceptedPrivacyPolicy: hasAcceptedPrivacyPolicy,
            title: l10n.authSandboxChip,
            description: enableAutoBypass
                ? l10n.authPhoneHelperSandbox
                : l10n.pick(
                    vi: 'Dùng profile thử nghiệm từ Firebase thật. Chạm vào một profile để gửi OTP thật theo số đã cấu hình.',
                    en: 'Use live Firebase test profiles. Tap a profile to request a real OTP for that configured phone.',
                  ),
            onSelected: onSandboxProfileSelected,
          ),
        ],
      ],
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: isBusy ? null : () => onChanged(!hasAcceptedPrivacyPolicy),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer.withValues(
                        alpha: 0.65,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      hasAcceptedPrivacyPolicy
                          ? Icons.verified_user_outlined
                          : Icons.shield_outlined,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l10n.pick(
                        vi: 'Tôi đã đọc và đồng ý với Chính sách quyền riêng tư của BeFam.',
                        en: 'I have read and agree to BeFam Privacy Policy.',
                      ),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Checkbox(
                    value: hasAcceptedPrivacyPolicy,
                    onChanged: isBusy
                        ? null
                        : (value) => onChanged(value ?? false),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                l10n.pick(
                  vi: 'BeFam chỉ dùng dữ liệu đăng nhập để xác thực và bảo vệ quyền truy cập dữ liệu gia phả đúng phạm vi.',
                  en: 'BeFam uses sign-in data only for authentication and to protect scoped genealogy access.',
                ),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: onViewPrivacyPolicy,
                icon: const Icon(Icons.policy_outlined),
                label: Text(
                  l10n.pick(
                    vi: 'Xem Chính sách quyền riêng tư',
                    en: 'View Privacy Policy',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SandboxLoginPreset {
  const _SandboxLoginPreset({
    required this.scenarioKey,
    required this.phoneE164,
    required this.title,
    required this.description,
    required this.icon,
    this.autoOtpCode,
  });

  final String scenarioKey;
  final String phoneE164;
  final String title;
  final String description;
  final IconData icon;
  final String? autoOtpCode;
}

class _RemoteSandboxProfile {
  const _RemoteSandboxProfile({
    required this.scenarioKey,
    required this.phoneE164,
    required this.title,
    required this.description,
    required this.isActive,
    required this.sortOrder,
    this.autoOtpCode,
  });

  final String scenarioKey;
  final String phoneE164;
  final String title;
  final String description;
  final bool isActive;
  final int sortOrder;
  final String? autoOtpCode;

  factory _RemoteSandboxProfile.fromPayload(Map<String, dynamic> data) {
    final phone = (data['phoneE164'] as String? ?? '').trim();
    final scenarioKey = (data['scenarioKey'] as String? ?? phone).trim();
    final title = (data['title'] as String? ?? scenarioKey).trim();
    final description = (data['description'] as String? ?? phone).trim();
    final sortOrder = (data['sortOrder'] as num?)?.toInt() ?? 9999;
    final rawOtpCode =
        ((data['autoOtpCode'] ?? data['debugOtpCode']) as String?)
            ?.replaceAll(RegExp(r'[^0-9]'), '')
            .trim();
    final autoOtpCode = rawOtpCode != null && rawOtpCode.length == 6
        ? rawOtpCode
        : null;

    return _RemoteSandboxProfile(
      scenarioKey: scenarioKey.isEmpty ? phone : scenarioKey,
      phoneE164: phone,
      title: title.isEmpty ? scenarioKey : title,
      description: description.isEmpty ? phone : description,
      isActive: data['isActive'] != false,
      sortOrder: sortOrder,
      autoOtpCode: autoOtpCode,
    );
  }
}

class _SandboxEnvironmentCard extends StatefulWidget {
  const _SandboxEnvironmentCard({
    required this.isBusy,
    required this.hasAcceptedPrivacyPolicy,
    required this.title,
    required this.description,
    required this.onSelected,
  });

  final bool isBusy;
  final bool hasAcceptedPrivacyPolicy;
  final String title;
  final String description;
  final Future<void> Function(String phoneE164, String? autoOtpCode) onSelected;

  @override
  State<_SandboxEnvironmentCard> createState() =>
      _SandboxEnvironmentCardState();
}

class _SandboxEnvironmentCardState extends State<_SandboxEnvironmentCard> {
  static const Map<String, IconData> _scenarioIcons = {
    'clan_admin_existing': Icons.admin_panel_settings_outlined,
    'branch_admin_existing': Icons.account_tree_outlined,
    'member_existing': Icons.person_outline,
    'user_unlinked': Icons.person_add_alt_1_outlined,
    'branch_admin_unlinked': Icons.gpp_maybe_outlined,
    'clan_admin_uninitialized': Icons.rocket_launch_outlined,
  };

  late Future<List<_RemoteSandboxProfile>> _remoteProfilesFuture;
  String? _activeScenarioKey;

  @override
  void initState() {
    super.initState();
    _remoteProfilesFuture = _loadRemoteProfiles();
  }

  void _reloadRemoteProfiles() {
    setState(() {
      _remoteProfilesFuture = _loadRemoteProfiles();
    });
  }

  Future<List<_RemoteSandboxProfile>> _loadRemoteProfiles() async {
    try {
      if (Firebase.apps.isEmpty) {
        AppLogger.warning(
          'Firebase is not initialized; skip loading debug login profiles.',
        );
        return const [];
      }
      final callable = FirebaseFunctions.instanceFor(
        region: 'asia-southeast1',
      ).httpsCallable('listDebugLoginProfiles');
      final response = await callable
          .call(<String, dynamic>{})
          .timeout(const Duration(seconds: 8));
      final payload = response.data;
      if (payload is! Map) {
        AppLogger.warning(
          'Debug login profile callable returned unexpected payload type.',
        );
        return const [];
      }
      final entries = payload['profiles'];
      if (entries is! List) {
        AppLogger.warning(
          'Debug login profile callable payload has no profiles array.',
        );
        return const [];
      }
      final profiles =
          entries
              .whereType<Map>()
              .map(
                (entry) => _RemoteSandboxProfile.fromPayload(
                  entry.map((key, value) => MapEntry(key.toString(), value)),
                ),
              )
              .where(
                (profile) => profile.isActive && profile.phoneE164.isNotEmpty,
              )
              .toList(growable: false)
            ..sort((left, right) => left.sortOrder.compareTo(right.sortOrder));
      AppLogger.info(
        'Loaded ${profiles.length} debug login profiles from Firebase.',
      );
      return profiles;
    } catch (error, stackTrace) {
      AppLogger.warning(
        'Failed to load debug login profiles from Firebase.',
        error,
        stackTrace,
      );
      return const [];
    }
  }

  List<_SandboxLoginPreset> _resolvedPresets(
    List<_RemoteSandboxProfile> remote,
  ) {
    if (remote.isEmpty) {
      return const [];
    }

    return remote
        .map(
          (profile) => _SandboxLoginPreset(
            scenarioKey: profile.scenarioKey,
            phoneE164: profile.phoneE164,
            title: profile.title,
            description: profile.description,
            icon:
                _scenarioIcons[profile.scenarioKey] ??
                Icons.person_pin_circle_outlined,
            autoOtpCode: profile.autoOtpCode,
          ),
        )
        .toList(growable: false);
  }

  Future<void> _onPresetTap(_SandboxLoginPreset preset) async {
    if (_activeScenarioKey != null || widget.isBusy) {
      return;
    }

    setState(() {
      _activeScenarioKey = preset.scenarioKey;
    });

    try {
      await widget.onSelected(preset.phoneE164, preset.autoOtpCode);
    } catch (error, stackTrace) {
      AppLogger.error('Sandbox profile sign-in failed.', error, stackTrace);
    } finally {
      if (mounted) {
        setState(() {
          _activeScenarioKey = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = context.l10n;

    return FutureBuilder<List<_RemoteSandboxProfile>>(
      future: _remoteProfilesFuture,
      builder: (context, snapshot) {
        final presets = _resolvedPresets(snapshot.data ?? const []);
        final isLoading = snapshot.connectionState == ConnectionState.waiting;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: colorScheme.primaryContainer,
                  child: const Icon(Icons.bolt_rounded),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(widget.description, style: theme.textTheme.bodyLarge),
                if (isLoading) ...[
                  const SizedBox(height: 14),
                  const LinearProgressIndicator(minHeight: 3),
                ],
                const SizedBox(height: 16),
                if (presets.isEmpty && !isLoading) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colorScheme.outlineVariant),
                    ),
                    child: Text(
                      l10n.pick(
                        vi: 'Chưa có profile thử nghiệm trong Firebase. Hãy seed collection debug_login_profiles để tiếp tục.',
                        en: 'No sandbox profiles found in Firebase. Seed debug_login_profiles to continue.',
                      ),
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: _reloadRemoteProfiles,
                      icon: const Icon(Icons.refresh_rounded),
                      label: Text(
                        l10n.pick(vi: 'Tải lại profile', en: 'Reload profiles'),
                      ),
                    ),
                  ),
                ] else ...[
                  for (var index = 0; index < presets.length; index++) ...[
                    _SandboxPresetTile(
                      preset: presets[index],
                      enabled:
                          widget.hasAcceptedPrivacyPolicy &&
                          !widget.isBusy &&
                          _activeScenarioKey == null,
                      isSubmitting:
                          _activeScenarioKey == presets[index].scenarioKey,
                      onTap: () => unawaited(_onPresetTap(presets[index])),
                    ),
                    if (index < presets.length - 1) const SizedBox(height: 10),
                  ],
                ],
                const SizedBox(height: 12),
                Text(
                  l10n.pick(
                    vi: 'Danh sách thử nghiệm được tải trực tiếp từ Firebase.',
                    en: 'Sandbox profiles are loaded directly from Firebase.',
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SandboxPresetTile extends StatelessWidget {
  const _SandboxPresetTile({
    required this.preset,
    required this.enabled,
    required this.isSubmitting,
    required this.onTap,
  });

  final _SandboxLoginPreset preset;
  final bool enabled;
  final bool isSubmitting;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: enabled
            ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.6)
            : colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              preset.icon,
              size: 20,
              color: enabled
                  ? colorScheme.primary
                  : colorScheme.onSurface.withValues(alpha: 0.4),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    preset.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(preset.description, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.tonal(
              onPressed: enabled ? onTap : null,
              child: isSubmitting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(context.l10n.authContinueNow),
            ),
          ],
        ),
      ),
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
                  label: l10n.pick(
                    vi: 'Xác thực OTP bảo mật',
                    en: 'Secure OTP verification',
                  ),
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
