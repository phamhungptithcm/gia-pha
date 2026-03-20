import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../core/services/app_locale_controller.dart';
import '../../../core/widgets/app_async_action.dart';
import '../../../core/widgets/app_feedback_states.dart';
import '../../../core/widgets/address_autocomplete_field.dart';
import '../../../core/widgets/address_action_tools.dart';
import '../../../core/widgets/member_phone_action.dart';
import '../../../core/widgets/social_link_actions.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../l10n/l10n.dart';
import '../../auth/models/auth_session.dart';
import '../../auth/services/auth_session_store.dart';
import '../../auth/services/phone_number_formatter.dart';
import '../../auth/widgets/phone_country_selector_field.dart';
import '../../billing/presentation/billing_workspace_page.dart';
import '../../billing/services/billing_repository.dart';
import '../../member/models/member_profile.dart';
import '../../member/models/member_social_links.dart';
import '../../member/services/member_avatar_picker.dart';
import '../../member/services/member_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/profile_notification_preferences_repository.dart';
import '../models/profile_draft.dart';
import 'profile_controller.dart';

class ProfileWorkspacePage extends StatefulWidget {
  const ProfileWorkspacePage({
    super.key,
    required this.session,
    required this.memberRepository,
    this.avatarPicker,
    this.notificationPreferencesRepository,
    this.localeController,
    this.billingRepository,
    this.onBillingStateChanged,
    this.onLogoutRequested,
    this.onSessionUpdated,
    this.showAppBar = false,
  });

  final AuthSession session;
  final MemberRepository memberRepository;
  final MemberAvatarPicker? avatarPicker;
  final ProfileNotificationPreferencesRepository?
  notificationPreferencesRepository;
  final AppLocaleController? localeController;
  final BillingRepository? billingRepository;
  final VoidCallback? onBillingStateChanged;
  final Future<void> Function()? onLogoutRequested;
  final ValueChanged<AuthSession>? onSessionUpdated;
  final bool showAppBar;

  @override
  State<ProfileWorkspacePage> createState() => _ProfileWorkspacePageState();
}

class _ProfileWorkspacePageState extends State<ProfileWorkspacePage> {
  late final ProfileController _controller;
  late final MemberAvatarPicker _avatarPicker;
  late final AppLocaleController _localeController;
  late final SharedPrefsAuthSessionStore _sessionStore;
  late final _UnlinkedProfileDraftStore _unlinkedProfileStore;
  late final bool _ownsLocaleController;
  ProfileDraft? _unlinkedDraft;
  bool _isSavingUnlinkedProfile = false;

  @override
  void initState() {
    super.initState();
    _controller = ProfileController(
      memberRepository: widget.memberRepository,
      session: widget.session,
      notificationPreferencesRepository:
          widget.notificationPreferencesRepository,
    );
    _avatarPicker = widget.avatarPicker ?? createDefaultMemberAvatarPicker();
    _localeController = widget.localeController ?? AppLocaleController();
    _sessionStore = SharedPrefsAuthSessionStore();
    _unlinkedProfileStore = const _UnlinkedProfileDraftStore();
    _ownsLocaleController = widget.localeController == null;
    unawaited(_localeController.load());
    unawaited(_controller.initialize());
    unawaited(_loadUnlinkedDraft());
  }

  @override
  void didUpdateWidget(covariant ProfileWorkspacePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session.uid != widget.session.uid) {
      unawaited(_loadUnlinkedDraft());
    }
  }

  @override
  void dispose() {
    if (_ownsLocaleController) {
      _localeController.dispose();
    }
    _controller.dispose();
    super.dispose();
  }

  Future<void> _openEditor(MemberProfile profile) async {
    final l10n = context.l10n;
    final didSave = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _ProfileEditorSheet(
          initialDraft: ProfileDraft.fromMember(profile),
          isSaving: _controller.isSavingProfile,
          onSubmit: _controller.saveProfile,
        );
      },
    );

    if (didSave == true && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.profileUpdateSuccess)));
    }
  }

  ProfileDraft _fallbackUnlinkedDraft(AuthSession session) {
    return ProfileDraft(
      fullName: session.displayName.trim(),
      nickName: '',
      phoneInput: session.phoneE164.trim(),
      email: '',
      addressText: '',
      jobTitle: '',
      bio: '',
      facebook: '',
      zalo: '',
      linkedin: '',
    );
  }

  Future<void> _loadUnlinkedDraft() async {
    final draft = await _unlinkedProfileStore.read(
      sessionUid: widget.session.uid,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _unlinkedDraft = draft;
    });
  }

  Future<void> _openUnlinkedEditor() async {
    final l10n = context.l10n;
    final didSave = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _ProfileEditorSheet(
          initialDraft:
              _unlinkedDraft ?? _fallbackUnlinkedDraft(widget.session),
          isSaving: _isSavingUnlinkedProfile,
          onSubmit: _saveUnlinkedProfileDraft,
        );
      },
    );

    if (didSave == true && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.profileUpdateSuccess)));
    }
  }

  Future<MemberRepositoryErrorCode?> _saveUnlinkedProfileDraft(
    ProfileDraft draft,
  ) async {
    if (_isSavingUnlinkedProfile) {
      return MemberRepositoryErrorCode.permissionDenied;
    }
    setState(() {
      _isSavingUnlinkedProfile = true;
    });

    try {
      final fullName = _trimOrFallback(
        draft.fullName,
        widget.session.displayName,
      );
      final phoneInput = _trimOrFallback(
        draft.phoneInput,
        widget.session.phoneE164,
      );
      final normalizedPhoneInput =
          PhoneNumberFormatter.tryParseE164(
            phoneInput,
            defaultCountryIso: PhoneNumberFormatter.inferCountryOption(
              widget.session.phoneE164,
            ).isoCode,
          ) ??
          phoneInput;
      final normalizedDraft = ProfileDraft(
        fullName: fullName,
        nickName: draft.nickName.trim(),
        phoneInput: normalizedPhoneInput,
        email: draft.email.trim(),
        addressText: draft.addressText.trim(),
        jobTitle: draft.jobTitle.trim(),
        bio: draft.bio.trim(),
        facebook: draft.facebook.trim(),
        zalo: draft.zalo.trim(),
        linkedin: draft.linkedin.trim(),
      );
      await _unlinkedProfileStore.write(
        sessionUid: widget.session.uid,
        draft: normalizedDraft,
      );
      final updatedSession = widget.session.copyWith(
        displayName: fullName,
        phoneE164: normalizedPhoneInput,
      );
      await _sessionStore.write(updatedSession);
      widget.onSessionUpdated?.call(updatedSession);
      if (!mounted) {
        return null;
      }
      setState(() {
        _unlinkedDraft = normalizedDraft;
      });
      return null;
    } catch (_) {
      return MemberRepositoryErrorCode.permissionDenied;
    } finally {
      if (mounted) {
        setState(() {
          _isSavingUnlinkedProfile = false;
        });
      } else {
        _isSavingUnlinkedProfile = false;
      }
    }
  }

  MemberProfile _buildUnlinkedFallbackProfile({
    required AuthSession session,
    required ProfileDraft draft,
    required AppLocalizations l10n,
  }) {
    final fullName = _normalizeUnlinkedFullName(
      draftValue: draft.fullName,
      fallbackValue: session.displayName,
      l10n: l10n,
    );
    final phone = _displayOrFallback(
      draft.phoneInput,
      fallback: session.phoneE164,
    );
    final normalizedRole = (session.primaryRole ?? '').trim().toUpperCase();
    return MemberProfile(
      id: 'unlinked_${session.uid}',
      clanId: '',
      branchId: '',
      fullName: fullName,
      normalizedFullName: fullName.toLowerCase().trim(),
      nickName: draft.nickName.trim(),
      gender: null,
      birthDate: null,
      deathDate: null,
      phoneE164: phone.isEmpty ? null : phone,
      email: _blankToNull(draft.email),
      addressText: _blankToNull(draft.addressText),
      jobTitle: _blankToNull(draft.jobTitle),
      avatarUrl: null,
      bio: _blankToNull(draft.bio),
      socialLinks: const MemberSocialLinks(),
      parentIds: const [],
      childrenIds: const [],
      spouseIds: const [],
      siblingOrder: null,
      generation: 1,
      primaryRole: normalizedRole.isEmpty ? 'MEMBER' : normalizedRole,
      status: 'active',
      isMinor: false,
      authUid: session.uid,
    );
  }

  Future<void> _handleAvatarUpload() async {
    final l10n = context.l10n;
    final picked = await _avatarPicker.pickAvatar();
    if (picked == null || !mounted) {
      return;
    }

    final error = await _controller.uploadAvatar(
      bytes: picked.bytes,
      fileName: picked.fileName,
      contentType: picked.contentType,
    );

    if (!mounted) {
      return;
    }

    if (error == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.memberAvatarUploadSuccess)));
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(_memberErrorMessage(l10n, error))));
  }

  Future<void> _openAvatarActions(MemberProfile profile) async {
    final l10n = context.l10n;
    final action = await showModalBottomSheet<_AvatarAction>(
      context: context,
      useSafeArea: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.image_outlined),
                title: Text(
                  l10n.pick(vi: 'Xem ảnh hiện tại', en: 'View current photo'),
                ),
                onTap: () => Navigator.of(context).pop(_AvatarAction.view),
              ),
              ListTile(
                leading: const Icon(Icons.file_upload_outlined),
                title: Text(
                  l10n.pick(vi: 'Tải ảnh mới', en: 'Upload new photo'),
                ),
                onTap: () => Navigator.of(context).pop(_AvatarAction.upload),
              ),
            ],
          ),
        );
      },
    );

    if (!mounted || action == null) {
      return;
    }

    if (action == _AvatarAction.upload) {
      await _handleAvatarUpload();
      return;
    }

    if (!profile.hasAvatar) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.pick(
              vi: 'Hiện chưa có ảnh đại diện.',
              en: 'No current profile photo yet.',
            ),
          ),
        ),
      );
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.all(20),
          clipBehavior: Clip.antiAlias,
          child: AspectRatio(
            aspectRatio: 1,
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: Image.network(profile.avatarUrl!, fit: BoxFit.cover),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) {
          return _SettingsScreenShell(
            controller: _controller,
            session: widget.session,
            localeController: _localeController,
            billingRepository: widget.billingRepository,
            onBillingStateChanged: widget.onBillingStateChanged,
            onLogoutRequested: widget.onLogoutRequested,
          );
        },
      ),
    );
  }

  Future<void> _confirmLogout() async {
    if (widget.onLogoutRequested == null) {
      return;
    }

    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.profileLogoutDialogTitle),
          content: Text(l10n.profileLogoutDialogDescription),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.profileCancelAction),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.shellLogout),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      await widget.onLogoutRequested?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_controller, _localeController]),
      builder: (context, _) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        final l10n = context.l10n;
        final selectedLanguageCode = _localeController.locale.languageCode;
        final unlinkedDraft =
            _unlinkedDraft ?? _fallbackUnlinkedDraft(widget.session);
        final usesFallbackProfile =
            !_controller.hasMemberContext && _controller.profile == null;
        final displayProfile =
            _controller.profile ??
            (usesFallbackProfile
                ? _buildUnlinkedFallbackProfile(
                    session: widget.session,
                    draft: unlinkedDraft,
                    l10n: l10n,
                  )
                : null);

        return Scaffold(
          appBar: widget.showAppBar
              ? AppBar(
                  title: Text(l10n.shellProfileTitle),
                  actions: [
                    IconButton(
                      tooltip: l10n.profileRefreshAction,
                      onPressed: _controller.isLoading
                          ? null
                          : _controller.refresh,
                      icon: const Icon(Icons.refresh),
                    ),
                    IconButton(
                      tooltip: l10n.profileOpenSettingsAction,
                      onPressed: _openSettings,
                      icon: const Icon(Icons.settings_outlined),
                    ),
                  ],
                )
              : null,
          body: SafeArea(
            child: _controller.isLoading
                ? AppLoadingState(
                    message: l10n.pick(
                      vi: 'Đang tải hồ sơ...',
                      en: 'Loading profile...',
                    ),
                  )
                : displayProfile == null
                ? _ProfileEmptyState(
                    icon: Icons.person_search_outlined,
                    title: l10n.memberNotFoundTitle,
                    description: l10n.memberNotFoundDescription,
                    actionLabel: l10n.notificationInboxRetryAction,
                    onAction: _controller.refresh,
                  )
                : RefreshIndicator(
                    onRefresh: _controller.refresh,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                      children: [
                        if (!widget.showAppBar) ...[
                          Align(
                            alignment: Alignment.centerRight,
                            child: Wrap(
                              spacing: 8,
                              children: [
                                IconButton(
                                  tooltip: l10n.profileRefreshAction,
                                  onPressed: _controller.isLoading
                                      ? null
                                      : _controller.refresh,
                                  icon: const Icon(Icons.refresh),
                                ),
                                IconButton(
                                  tooltip: l10n.profileOpenSettingsAction,
                                  onPressed: _openSettings,
                                  icon: const Icon(Icons.settings_outlined),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        _ProfileHeroCard(
                          profile: displayProfile,
                          roleLabel: l10n.roleLabel(displayProfile.primaryRole),
                          onEditProfile: usesFallbackProfile
                              ? _openUnlinkedEditor
                              : () => _openEditor(displayProfile),
                          onAvatarTap:
                              usesFallbackProfile ||
                                  _controller.isUploadingAvatar
                              ? null
                              : () => _openAvatarActions(displayProfile),
                          isUploadingAvatar: usesFallbackProfile
                              ? _isSavingUnlinkedProfile
                              : _controller.isUploadingAvatar,
                          showAvatarActionBadge: !usesFallbackProfile,
                        ),
                        const SizedBox(height: 20),
                        if (_controller.errorMessage != null) ...[
                          _ProfileInfoCard(
                            icon: Icons.error_outline,
                            title: l10n.profileUpdateErrorTitle,
                            description: _friendlyProfileErrorMessage(
                              _controller.errorMessage!,
                              l10n,
                            ),
                            tone: colorScheme.errorContainer,
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: _controller.refresh,
                              icon: const Icon(Icons.refresh),
                              label: Text(l10n.profileRefreshAction),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                        _ProfileSectionCard(
                          title: l10n.profileDetailsSectionTitle,
                          child: Column(
                            children: [
                              _ProfileDetailRow(
                                label: l10n.memberFullNameLabel,
                                value: displayProfile.fullName,
                              ),
                              _ProfileDetailRow(
                                label: l10n.memberNicknameLabel,
                                value: _blankIfMissing(displayProfile.nickName),
                              ),
                              _ProfileDetailRow(
                                label: l10n.memberPhoneLabel,
                                value: _blankIfMissing(
                                  displayProfile.phoneE164,
                                ),
                                trailing: MemberPhoneActionIconButton(
                                  phoneNumber: displayProfile.phoneE164 ?? '',
                                  contactName: displayProfile.displayName,
                                ),
                              ),
                              _ProfileDetailRow(
                                label: l10n.memberEmailLabel,
                                value: _blankIfMissing(displayProfile.email),
                              ),
                              _ProfileDetailRow(
                                label: l10n.memberJobTitleLabel,
                                value: _blankIfMissing(displayProfile.jobTitle),
                              ),
                              _ProfileDetailRow(
                                label: l10n.memberAddressLabel,
                                value: _blankIfMissing(
                                  displayProfile.addressText,
                                ),
                                trailing: AddressDirectionIconButton(
                                  address: displayProfile.addressText ?? '',
                                  label: displayProfile.displayName,
                                ),
                              ),
                              _ProfileDetailRow(
                                label: l10n.memberBioLabel,
                                value: _blankIfMissing(displayProfile.bio),
                                isLast: true,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        _ProfileSectionCard(
                          title: l10n.memberSocialLinksTitle,
                          child: displayProfile.socialLinks.isEmpty
                              ? Text(
                                  l10n.memberSocialLinksEmptyDescription,
                                  style: theme.textTheme.bodyMedium,
                                )
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      l10n.pick(
                                        vi: 'Bấm vào biểu tượng để mở ứng dụng mạng xã hội hoặc trình duyệt.',
                                        en: 'Tap an icon to open the social app or browser.',
                                      ),
                                      style: theme.textTheme.bodyMedium,
                                    ),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: [
                                        if (displayProfile
                                                .socialLinks
                                                .facebook !=
                                            null)
                                          SocialLinkActionIconButton(
                                            platform: SocialPlatform.facebook,
                                            rawValue: displayProfile
                                                .socialLinks
                                                .facebook!,
                                          ),
                                        if (displayProfile.socialLinks.zalo !=
                                            null)
                                          SocialLinkActionIconButton(
                                            platform: SocialPlatform.zalo,
                                            rawValue: displayProfile
                                                .socialLinks
                                                .zalo!,
                                          ),
                                        if (displayProfile
                                                .socialLinks
                                                .linkedin !=
                                            null)
                                          SocialLinkActionIconButton(
                                            platform: SocialPlatform.linkedin,
                                            rawValue: displayProfile
                                                .socialLinks
                                                .linkedin!,
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                        ),
                        const SizedBox(height: 20),
                        _ProfileSectionCard(
                          title: l10n.profileLanguageSectionTitle,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.profileLanguageSectionDescription,
                                style: theme.textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 10),
                              SegmentedButton<String>(
                                showSelectedIcon: true,
                                segments: [
                                  ButtonSegment<String>(
                                    value: 'vi',
                                    label: Text(l10n.profileLanguageVietnamese),
                                  ),
                                  ButtonSegment<String>(
                                    value: 'en',
                                    label: Text(l10n.profileLanguageEnglish),
                                  ),
                                ],
                                selected: {selectedLanguageCode},
                                onSelectionChanged: (selected) {
                                  if (selected.isEmpty) {
                                    return;
                                  }
                                  unawaited(
                                    _localeController.updateLanguageCode(
                                      selected.first,
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 8),
                              Text(
                                selectedLanguageCode == 'vi'
                                    ? l10n.profileLanguageVietnameseSubtitle
                                    : l10n.profileLanguageEnglishSubtitle,
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        _ProfileSectionCard(
                          title: l10n.notificationSettingsTitle,
                          child: _NotificationSettingsPanel(
                            controller: _controller,
                          ),
                        ),
                        const SizedBox(height: 20),
                        if (widget.onLogoutRequested != null)
                          _ProfileSectionCard(
                            title: l10n.profileAccountSectionTitle,
                            child: OutlinedButton.icon(
                              onPressed: _confirmLogout,
                              icon: const Icon(Icons.logout),
                              label: Text(l10n.shellLogout),
                            ),
                          ),
                      ],
                    ),
                  ),
          ),
        );
      },
    );
  }
}

class _SettingsScreenShell extends StatelessWidget {
  const _SettingsScreenShell({
    required this.controller,
    required this.session,
    required this.localeController,
    this.billingRepository,
    this.onBillingStateChanged,
    required this.onLogoutRequested,
  });

  final ProfileController controller;
  final AuthSession session;
  final AppLocaleController localeController;
  final BillingRepository? billingRepository;
  final VoidCallback? onBillingStateChanged;
  final Future<void> Function()? onLogoutRequested;

  Future<void> _confirmLogout(BuildContext context) async {
    if (onLogoutRequested == null) {
      return;
    }

    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.profileLogoutDialogTitle),
          content: Text(l10n.profileSettingsLogoutDescription),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.profileCancelAction),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.shellLogout),
            ),
          ],
        );
      },
    );

    if (confirmed == true && context.mounted) {
      await onLogoutRequested?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return AnimatedBuilder(
      animation: Listenable.merge([controller, localeController]),
      builder: (context, _) {
        final selectedLanguageCode = localeController.locale.languageCode;
        return Scaffold(
          appBar: AppBar(title: Text(l10n.profileSettingsTitle)),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                _ProfileSectionCard(
                  title: l10n.profileSettingsOverviewTitle,
                  child: Text(
                    l10n.profileSettingsOverviewDescription,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(height: 20),
                _ProfileSectionCard(
                  title: l10n.profileLanguageSectionTitle,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.profileLanguageSectionDescription,
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 10),
                      SegmentedButton<String>(
                        showSelectedIcon: true,
                        segments: [
                          ButtonSegment<String>(
                            value: 'vi',
                            label: Text(l10n.profileLanguageVietnamese),
                          ),
                          ButtonSegment<String>(
                            value: 'en',
                            label: Text(l10n.profileLanguageEnglish),
                          ),
                        ],
                        selected: {selectedLanguageCode},
                        onSelectionChanged: (selected) {
                          if (selected.isEmpty) {
                            return;
                          }
                          unawaited(
                            localeController.updateLanguageCode(selected.first),
                          );
                        },
                      ),
                      const SizedBox(height: 10),
                      Text(
                        selectedLanguageCode == 'vi'
                            ? l10n.profileLanguageVietnameseSubtitle
                            : l10n.profileLanguageEnglishSubtitle,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _ProfileSectionCard(
                  title: l10n.notificationSettingsTitle,
                  child: _NotificationSettingsPanel(controller: controller),
                ),
                const SizedBox(height: 20),
                _ProfileSectionCard(
                  title: l10n.pick(
                    vi: 'Gói dịch vụ & thanh toán',
                    en: 'Subscription & billing',
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.pick(
                          vi: 'Xem trạng thái gói, ngày hết hạn, chế độ thanh toán tự động/thủ công và lịch sử giao dịch.',
                          en: 'View your current plan, expiry date, payment mode, and transaction history.',
                        ),
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 10),
                      AppAsyncAction(
                        onPressed: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (context) => BillingWorkspacePage(
                                session: session,
                                repository: billingRepository,
                              ),
                            ),
                          );
                          onBillingStateChanged?.call();
                        },
                        builder: (context, onPressed, isLoading) {
                          return FilledButton.tonal(
                            onPressed: onPressed,
                            child: AppStableLoadingChild(
                              isLoading: isLoading,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.workspace_premium_outlined),
                                  const SizedBox(width: 8),
                                  Text(
                                    l10n.pick(
                                      vi: 'Mở quản lý gói',
                                      en: 'Open billing workspace',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                if (onLogoutRequested != null) ...[
                  const SizedBox(height: 20),
                  _ProfileSectionCard(
                    title: l10n.profileSessionSectionTitle,
                    child: OutlinedButton.icon(
                      onPressed: () => _confirmLogout(context),
                      icon: const Icon(Icons.logout),
                      label: Text(l10n.shellLogout),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _NotificationSettingsPanel extends StatelessWidget {
  const _NotificationSettingsPanel({required this.controller});

  final ProfileController controller;

  @override
  Widget build(BuildContext context) {
    final prefs = controller.notificationPreferences;
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final isSaving = controller.isSavingNotificationPreferences;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.notificationSettingsDescription,
          style: theme.textTheme.bodyMedium,
        ),
        if (isSaving) ...[
          const SizedBox(height: 10),
          const LinearProgressIndicator(minHeight: 2),
        ],
        const SizedBox(height: 8),
        SwitchListTile.adaptive(
          key: const Key('notification-setting-push-enabled'),
          value: prefs.pushEnabled,
          onChanged: isSaving
              ? null
              : (value) {
                  unawaited(controller.updatePushEnabledPreference(value));
                },
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.notificationSettingsPushChannel),
        ),
        SwitchListTile.adaptive(
          key: const Key('notification-setting-email-enabled'),
          value: prefs.emailEnabled,
          onChanged: isSaving
              ? null
              : (value) {
                  unawaited(controller.updateEmailEnabledPreference(value));
                },
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.notificationSettingsEmailChannel),
        ),
        SwitchListTile.adaptive(
          key: const Key('notification-setting-event-updates'),
          value: prefs.eventReminders,
          onChanged: isSaving
              ? null
              : (value) {
                  unawaited(controller.updateEventRemindersPreference(value));
                },
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.notificationSettingsEventUpdates),
        ),
        SwitchListTile.adaptive(
          key: const Key('notification-setting-scholarship-updates'),
          value: prefs.scholarshipUpdates,
          onChanged: isSaving
              ? null
              : (value) {
                  unawaited(
                    controller.updateScholarshipUpdatesPreference(value),
                  );
                },
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.notificationSettingsScholarshipUpdates),
        ),
        SwitchListTile.adaptive(
          key: const Key('notification-setting-fund-transactions'),
          value: prefs.fundTransactions,
          onChanged: isSaving
              ? null
              : (value) {
                  unawaited(controller.updateFundTransactionsPreference(value));
                },
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.profileNotificationFundAlerts),
        ),
        SwitchListTile.adaptive(
          key: const Key('notification-setting-general-updates'),
          value: prefs.systemNotices,
          onChanged: isSaving
              ? null
              : (value) {
                  unawaited(controller.updateSystemNoticesPreference(value));
                },
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.notificationSettingsGeneralUpdates),
        ),
        SwitchListTile.adaptive(
          key: const Key('notification-setting-quiet-hours'),
          value: prefs.quietHoursEnabled,
          onChanged: isSaving
              ? null
              : (value) {
                  unawaited(controller.updateQuietHoursPreference(value));
                },
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.notificationSettingsQuietHours),
        ),
        const SizedBox(height: 6),
        Text(
          l10n.notificationSettingsSmsOtpOnlyNote,
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _ProfileHeroCard extends StatelessWidget {
  const _ProfileHeroCard({
    required this.profile,
    required this.roleLabel,
    required this.onEditProfile,
    this.onAvatarTap,
    this.isUploadingAvatar = false,
    this.showAvatarActionBadge = true,
  });

  final MemberProfile profile;
  final String roleLabel;
  final VoidCallback onEditProfile;
  final VoidCallback? onAvatarTap;
  final bool isUploadingAvatar;
  final bool showAvatarActionBadge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = context.l10n;
    final resolvedSubtitle = l10n.pick(
      vi: 'Bạn có thể cập nhật hồ sơ bất kỳ lúc nào.',
      en: 'You can update your profile anytime.',
    );

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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onAvatarTap,
            customBorder: const CircleBorder(),
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircleAvatar(
                  radius: 38,
                  backgroundColor: colorScheme.surface,
                  foregroundColor: colorScheme.onSurface,
                  backgroundImage: profile.hasAvatar
                      ? NetworkImage(profile.avatarUrl!)
                      : null,
                  child: profile.hasAvatar
                      ? null
                      : Text(
                          profile.initials,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
                if (showAvatarActionBadge)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: colorScheme.surface,
                          width: 1.4,
                        ),
                      ),
                      child: Icon(
                        Icons.photo_camera_outlined,
                        size: 14,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                if (isUploadingAvatar)
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: colorScheme.surface.withValues(alpha: 0.65),
                      shape: BoxShape.circle,
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(22),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        profile.fullName,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: colorScheme.onPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: l10n.memberEditAction,
                      onPressed: onEditProfile,
                      icon: const Icon(Icons.edit_outlined),
                      color: colorScheme.onPrimary,
                      style: IconButton.styleFrom(
                        backgroundColor: colorScheme.onPrimary.withValues(
                          alpha: 0.12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  roleLabel,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onPrimary.withValues(alpha: 0.9),
                  ),
                ),
                Text(
                  resolvedSubtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onPrimary.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _AvatarAction { view, upload }

class _ProfileEditorSheet extends StatefulWidget {
  const _ProfileEditorSheet({
    required this.initialDraft,
    required this.isSaving,
    required this.onSubmit,
  });

  final ProfileDraft initialDraft;
  final bool isSaving;
  final Future<MemberRepositoryErrorCode?> Function(ProfileDraft draft)
  onSubmit;

  @override
  State<_ProfileEditorSheet> createState() => _ProfileEditorSheetState();
}

class _ProfileEditorSheetState extends State<_ProfileEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _fullNameController;
  late final TextEditingController _nickNameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _addressController;
  late final TextEditingController _jobTitleController;
  late final TextEditingController _bioController;
  late final TextEditingController _facebookController;
  late final TextEditingController _zaloController;
  late final TextEditingController _linkedinController;
  late String _phoneCountryIsoCode;
  bool _resolvedAutoPhoneCountry = false;

  MemberRepositoryErrorCode? _submitError;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController(
      text: widget.initialDraft.fullName,
    );
    _nickNameController = TextEditingController(
      text: widget.initialDraft.nickName,
    );
    _phoneCountryIsoCode = PhoneNumberFormatter.inferCountryOption(
      widget.initialDraft.phoneInput,
    ).isoCode;
    _phoneController = TextEditingController(
      text: PhoneNumberFormatter.toNationalInput(
        widget.initialDraft.phoneInput,
        defaultCountryIso: _phoneCountryIsoCode,
      ),
    );
    _emailController = TextEditingController(text: widget.initialDraft.email);
    _addressController = TextEditingController(
      text: widget.initialDraft.addressText,
    );
    _jobTitleController = TextEditingController(
      text: widget.initialDraft.jobTitle,
    );
    _bioController = TextEditingController(text: widget.initialDraft.bio);
    _facebookController = TextEditingController(
      text: widget.initialDraft.facebook,
    );
    _zaloController = TextEditingController(text: widget.initialDraft.zalo);
    _linkedinController = TextEditingController(
      text: widget.initialDraft.linkedin,
    );
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _nickNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _jobTitleController.dispose();
    _bioController.dispose();
    _facebookController.dispose();
    _zaloController.dispose();
    _linkedinController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_resolvedAutoPhoneCountry || _phoneController.text.trim().isNotEmpty) {
      return;
    }
    final locale = Localizations.localeOf(context);
    _phoneCountryIsoCode = PhoneNumberFormatter.autoCountryIsoFromRegion(
      locale.countryCode,
    );
    _resolvedAutoPhoneCountry = true;
  }

  void _normalizePhoneInputForCountry() {
    final normalized = PhoneNumberFormatter.toNationalInput(
      _phoneController.text,
      defaultCountryIso: _phoneCountryIsoCode,
    );
    if (normalized == _phoneController.text.trim()) {
      return;
    }
    _phoneController
      ..text = normalized
      ..selection = TextSelection.collapsed(offset: normalized.length);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });

    _normalizePhoneInputForCountry();
    final trimmedPhone = _phoneController.text.trim();
    final normalizedPhone = trimmedPhone.isEmpty
        ? ''
        : PhoneNumberFormatter.parse(
            trimmedPhone,
            defaultCountryIso: _phoneCountryIsoCode,
          ).e164;

    final error = await widget.onSubmit(
      ProfileDraft(
        fullName: _fullNameController.text.trim(),
        nickName: _nickNameController.text.trim(),
        phoneInput: normalizedPhone,
        email: _emailController.text.trim(),
        addressText: _addressController.text.trim(),
        jobTitle: _jobTitleController.text.trim(),
        bio: _bioController.text.trim(),
        facebook:
            normalizeSocialLinkForStorage(
              SocialPlatform.facebook,
              _facebookController.text,
            ) ??
            '',
        zalo:
            normalizeSocialLinkForStorage(
              SocialPlatform.zalo,
              _zaloController.text,
            ) ??
            '',
        linkedin:
            normalizeSocialLinkForStorage(
              SocialPlatform.linkedin,
              _linkedinController.text,
            ) ??
            '',
      ),
    );

    if (!mounted) {
      return;
    }

    if (error == null) {
      Navigator.of(context).pop(true);
      return;
    }

    setState(() {
      _isSubmitting = false;
      _submitError = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.viewInsetsOf(context);
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final phoneHint = PhoneNumberFormatter.nationalNumberHint(
      _phoneCountryIsoCode,
    );

    return Padding(
      padding: EdgeInsets.only(bottom: insets.bottom),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  l10n.profileEditSheetTitle,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  l10n.profileEditSheetDescription,
                  style: theme.textTheme.bodyMedium,
                ),
                if (_submitError != null) ...[
                  const SizedBox(height: 16),
                  _ProfileInfoCard(
                    icon: Icons.error_outline,
                    title: l10n.profileSaveErrorTitle,
                    description: _memberErrorMessage(l10n, _submitError!),
                    tone: theme.colorScheme.errorContainer,
                  ),
                ],
                const SizedBox(height: 18),
                TextFormField(
                  controller: _fullNameController,
                  decoration: InputDecoration(
                    labelText: l10n.memberFullNameLabel,
                  ),
                  validator: (value) {
                    return value == null || value.trim().isEmpty
                        ? l10n.memberValidationNameRequired
                        : null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _nickNameController,
                  decoration: InputDecoration(
                    labelText: l10n.memberNicknameLabel,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PhoneCountrySelectorField(
                      selectedIsoCode: _phoneCountryIsoCode,
                      enabled: !_isSubmitting,
                      onChanged: (value) {
                        setState(() {
                          _phoneCountryIsoCode = value;
                          _normalizePhoneInputForCountry();
                        });
                      },
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _phoneController,
                        decoration: InputDecoration(
                          labelText: l10n.memberPhoneLabel,
                          hintText: phoneHint,
                        ),
                        keyboardType: TextInputType.phone,
                        onEditingComplete: _normalizePhoneInputForCountry,
                        validator: (value) {
                          final trimmed = value?.trim() ?? '';
                          if (trimmed.isEmpty) {
                            return null;
                          }
                          try {
                            PhoneNumberFormatter.parse(
                              trimmed,
                              defaultCountryIso: _phoneCountryIsoCode,
                            );
                            return null;
                          } catch (_) {
                            return l10n.memberValidationPhoneInvalid;
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _emailController,
                  decoration: InputDecoration(labelText: l10n.memberEmailLabel),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _jobTitleController,
                  decoration: InputDecoration(
                    labelText: l10n.memberJobTitleLabel,
                  ),
                ),
                const SizedBox(height: 14),
                AddressAutocompleteField(
                  controller: _addressController,
                  maxLines: 2,
                  labelText: l10n.memberAddressLabel,
                  hintText: l10n.pick(
                    vi: 'Số nhà, đường, phường/xã, quận/huyện...',
                    en: 'Street, ward, district...',
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _bioController,
                  maxLines: 3,
                  decoration: InputDecoration(labelText: l10n.memberBioLabel),
                ),
                const SizedBox(height: 14),
                Text(
                  l10n.pick(
                    vi: 'Nhập tên tài khoản hoặc liên kết. Bấm biểu tượng bên phải để mở app/web và liên kết nhanh.',
                    en: 'Enter a username or link. Tap the right icon to open app/web for quick linking.',
                  ),
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _facebookController,
                  decoration: InputDecoration(
                    labelText: l10n.profileFacebookUrlLabel,
                    hintText: l10n.pick(
                      vi: 'Tên tài khoản hoặc URL',
                      en: 'Username or profile URL',
                    ),
                    prefixIcon: const Icon(Icons.facebook),
                    suffixIcon: SocialLinkFieldConnectButton(
                      platform: SocialPlatform.facebook,
                      controller: _facebookController,
                    ),
                  ),
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _zaloController,
                  decoration: InputDecoration(
                    labelText: l10n.profileZaloUrlLabel,
                    hintText: l10n.pick(
                      vi: 'Tên tài khoản hoặc URL',
                      en: 'Username or profile URL',
                    ),
                    prefixIcon: const Icon(Icons.forum_outlined),
                    suffixIcon: SocialLinkFieldConnectButton(
                      platform: SocialPlatform.zalo,
                      controller: _zaloController,
                    ),
                  ),
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _linkedinController,
                  decoration: InputDecoration(
                    labelText: l10n.profileLinkedinUrlLabel,
                    hintText: l10n.pick(
                      vi: 'Tên tài khoản hoặc URL',
                      en: 'Username or profile URL',
                    ),
                    prefixIcon: const Icon(Icons.work_outline),
                    suffixIcon: SocialLinkFieldConnectButton(
                      platform: SocialPlatform.linkedin,
                      controller: _linkedinController,
                    ),
                  ),
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: (_isSubmitting || widget.isSaving)
                        ? null
                        : _submit,
                    icon: (_isSubmitting || widget.isSaving)
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(
                      (_isSubmitting || widget.isSaving)
                          ? l10n.profileSavingAction
                          : l10n.memberSaveAction,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileSectionCard extends StatelessWidget {
  const _ProfileSectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _ProfileDetailRow extends StatelessWidget {
  const _ProfileDetailRow({
    required this.label,
    required this.value,
    this.isLast = false,
    this.trailing,
  });

  final String label;
  final String value;
  final bool isLast;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
                if (trailing != null) ...[
                  const SizedBox(width: 8),
                  Align(alignment: Alignment.centerRight, child: trailing!),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileInfoCard extends StatelessWidget {
  const _ProfileInfoCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.tone,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: tone,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon),
            const SizedBox(width: 12),
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
                  const SizedBox(height: 6),
                  Text(description),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _displayOrFallback(String value, {String? fallback}) {
  final trimmed = value.trim();
  if (trimmed.isNotEmpty) {
    return trimmed;
  }
  final fallbackTrimmed = (fallback ?? '').trim();
  if (fallbackTrimmed.isNotEmpty) {
    return fallbackTrimmed;
  }
  return '';
}

String _blankIfMissing(String? value) {
  return (value ?? '').trim();
}

String? _blankToNull(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  return trimmed;
}

String _normalizeUnlinkedFullName({
  required String draftValue,
  required String fallbackValue,
  required AppLocalizations l10n,
}) {
  final draft = draftValue.trim();
  if (draft.isNotEmpty && !_looksLikeUnlinkedPlaceholder(draft)) {
    return draft;
  }
  final fallback = fallbackValue.trim();
  if (fallback.isNotEmpty && !_looksLikeUnlinkedPlaceholder(fallback)) {
    return fallback;
  }
  return l10n.pick(vi: 'Chưa Có Tên', en: 'No Name Yet');
}

bool _looksLikeUnlinkedPlaceholder(String value) {
  final normalized = value.toLowerCase();
  return normalized.contains('chưa vào gia phả') ||
      normalized.contains('chưa liên kết') ||
      normalized.contains('not linked') ||
      normalized.contains('unlinked');
}

class _UnlinkedProfileDraftStore {
  const _UnlinkedProfileDraftStore();

  static const String _draftKeyPrefix = 'befam.profile.unlinkedDraft';

  Future<ProfileDraft?> read({required String sessionUid}) async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_keyForUid(sessionUid));
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    try {
      final payload = jsonDecode(raw) as Map<String, dynamic>;
      return ProfileDraft(
        fullName: _asText(payload['fullName']),
        nickName: _asText(payload['nickName']),
        phoneInput: _asText(payload['phoneInput']),
        email: _asText(payload['email']),
        addressText: _asText(payload['addressText']),
        jobTitle: _asText(payload['jobTitle']),
        bio: _asText(payload['bio']),
        facebook: _asText(payload['facebook']),
        zalo: _asText(payload['zalo']),
        linkedin: _asText(payload['linkedin']),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> write({
    required String sessionUid,
    required ProfileDraft draft,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _keyForUid(sessionUid),
      jsonEncode({
        'fullName': draft.fullName,
        'nickName': draft.nickName,
        'phoneInput': draft.phoneInput,
        'email': draft.email,
        'addressText': draft.addressText,
        'jobTitle': draft.jobTitle,
        'bio': draft.bio,
        'facebook': draft.facebook,
        'zalo': draft.zalo,
        'linkedin': draft.linkedin,
      }),
    );
  }

  String _keyForUid(String sessionUid) {
    final normalized = sessionUid.trim();
    return '$_draftKeyPrefix.${normalized.isEmpty ? 'unknown' : normalized}';
  }
}

String _asText(Object? value) {
  return value is String ? value : '';
}

class _ProfileEmptyState extends StatelessWidget {
  const _ProfileEmptyState({
    required this.icon,
    required this.title,
    required this.description,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String description;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(icon, size: 30),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(description, textAlign: TextAlign.center),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 12),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

String _friendlyProfileErrorMessage(String raw, AppLocalizations l10n) {
  final normalized = raw.trim().toLowerCase();
  if (normalized.isEmpty) {
    return l10n.pick(
      vi: 'Không thể tải hồ sơ lúc này. Vui lòng thử lại.',
      en: 'Could not load profile right now. Please try again.',
    );
  }
  if (normalized.contains('permission_denied') ||
      normalized.contains('permission denied')) {
    return l10n.pick(
      vi: 'Bạn chưa có quyền cập nhật hồ sơ này.',
      en: 'You do not have permission to update this profile.',
    );
  }
  if (normalized.contains('network') ||
      normalized.contains('unavailable') ||
      normalized.contains('timeout') ||
      normalized.contains('deadline')) {
    return l10n.pick(
      vi: 'Kết nối đang gián đoạn. Vui lòng kiểm tra mạng rồi thử lại.',
      en: 'Connection is unstable. Please check your network and try again.',
    );
  }
  return l10n.pick(
    vi: 'Cập nhật hồ sơ chưa thành công. Vui lòng thử lại sau.',
    en: 'Profile update failed. Please try again later.',
  );
}

String _memberErrorMessage(
  AppLocalizations l10n,
  MemberRepositoryErrorCode code,
) {
  return switch (code) {
    MemberRepositoryErrorCode.duplicatePhone => l10n.memberDuplicatePhoneError,
    MemberRepositoryErrorCode.planLimitExceeded =>
      l10n.memberPlanLimitExceededError,
    MemberRepositoryErrorCode.permissionDenied =>
      l10n.memberPermissionDeniedError,
    MemberRepositoryErrorCode.memberNotFound => l10n.memberNotFoundDescription,
    MemberRepositoryErrorCode.avatarUploadFailed =>
      l10n.memberAvatarUploadError,
  };
}

String _trimOrFallback(String value, String fallback) {
  final trimmed = value.trim();
  if (trimmed.isNotEmpty) {
    return trimmed;
  }
  return fallback.trim();
}
