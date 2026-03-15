import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/services/app_locale_controller.dart';
import '../../../core/widgets/app_feedback_states.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../l10n/l10n.dart';
import '../../auth/models/auth_session.dart';
import '../../member/models/member_profile.dart';
import '../../member/services/member_avatar_picker.dart';
import '../../member/services/member_repository.dart';
import '../models/profile_draft.dart';
import 'profile_controller.dart';

class ProfileWorkspacePage extends StatefulWidget {
  const ProfileWorkspacePage({
    super.key,
    required this.session,
    required this.memberRepository,
    this.avatarPicker,
    this.localeController,
    this.onLogoutRequested,
  });

  final AuthSession session;
  final MemberRepository memberRepository;
  final MemberAvatarPicker? avatarPicker;
  final AppLocaleController? localeController;
  final Future<void> Function()? onLogoutRequested;

  @override
  State<ProfileWorkspacePage> createState() => _ProfileWorkspacePageState();
}

class _ProfileWorkspacePageState extends State<ProfileWorkspacePage> {
  late final ProfileController _controller;
  late final MemberAvatarPicker _avatarPicker;
  late final AppLocaleController _localeController;
  late final bool _ownsLocaleController;

  @override
  void initState() {
    super.initState();
    _controller = ProfileController(
      memberRepository: widget.memberRepository,
      session: widget.session,
    );
    _avatarPicker = widget.avatarPicker ?? createDefaultMemberAvatarPicker();
    _localeController = widget.localeController ?? AppLocaleController();
    _ownsLocaleController = widget.localeController == null;
    unawaited(_localeController.load());
    unawaited(_controller.initialize());
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
            localeController: _localeController,
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
      animation: _controller,
      builder: (context, _) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        final l10n = context.l10n;

        return Scaffold(
          appBar: AppBar(
            title: Text(l10n.shellProfileTitle),
            actions: [
              IconButton(
                tooltip: l10n.profileRefreshAction,
                onPressed: _controller.isLoading ? null : _controller.refresh,
                icon: const Icon(Icons.refresh),
              ),
              IconButton(
                tooltip: l10n.profileOpenSettingsAction,
                onPressed: _openSettings,
                icon: const Icon(Icons.settings_outlined),
              ),
            ],
          ),
          body: SafeArea(
            child: _controller.isLoading
                ? AppLoadingState(
                    message: l10n.pick(
                      vi: 'Đang tải hồ sơ...',
                      en: 'Loading profile...',
                    ),
                  )
                : !_controller.hasMemberContext
                ? _ProfileEmptyState(
                    icon: Icons.lock_outline,
                    title: l10n.profileNoContextTitle,
                    description: l10n.profileNoContextDescription,
                  )
                : _controller.profile == null
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
                        _ProfileHeroCard(
                          profile: _controller.profile!,
                          roleLabel: l10n.roleLabel(
                            _controller.profile!.primaryRole,
                          ),
                          onEditProfile: () =>
                              _openEditor(_controller.profile!),
                          onAvatarTap: _controller.isUploadingAvatar
                              ? null
                              : () => _openAvatarActions(_controller.profile!),
                          isUploadingAvatar: _controller.isUploadingAvatar,
                        ),
                        const SizedBox(height: 20),
                        if (_controller.errorMessage != null) ...[
                          _ProfileInfoCard(
                            icon: Icons.error_outline,
                            title: l10n.profileUpdateErrorTitle,
                            description: _controller.errorMessage!,
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
                                value: _controller.profile!.fullName,
                              ),
                              _ProfileDetailRow(
                                label: l10n.memberNicknameLabel,
                                value:
                                    _controller.profile!.nickName.trim().isEmpty
                                    ? l10n.memberFieldUnset
                                    : _controller.profile!.nickName,
                              ),
                              _ProfileDetailRow(
                                label: l10n.memberPhoneLabel,
                                value:
                                    _controller.profile!.phoneE164 ??
                                    l10n.memberFieldUnset,
                              ),
                              _ProfileDetailRow(
                                label: l10n.memberEmailLabel,
                                value:
                                    _controller.profile!.email ??
                                    l10n.memberFieldUnset,
                              ),
                              _ProfileDetailRow(
                                label: l10n.memberJobTitleLabel,
                                value:
                                    _controller.profile!.jobTitle ??
                                    l10n.memberFieldUnset,
                              ),
                              _ProfileDetailRow(
                                label: l10n.memberAddressLabel,
                                value:
                                    _controller.profile!.addressText ??
                                    l10n.memberFieldUnset,
                              ),
                              _ProfileDetailRow(
                                label: l10n.memberBioLabel,
                                value:
                                    _controller.profile!.bio ??
                                    l10n.memberFieldUnset,
                                isLast: true,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        _ProfileSectionCard(
                          title: l10n.notificationSettingsTitle,
                          child: _NotificationPlaceholderPanel(
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
    required this.localeController,
    required this.onLogoutRequested,
  });

  final ProfileController controller;
  final AppLocaleController localeController;
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
                  child: _NotificationPlaceholderPanel(controller: controller),
                ),
                const SizedBox(height: 20),
                _ProfileSectionCard(
                  title: l10n.profileSecuritySectionTitle,
                  child: _ProfileEmptyState(
                    icon: Icons.security_outlined,
                    title: l10n.profileSecurityPlaceholderTitle,
                    description: l10n.profileSecurityPlaceholderDescription,
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

class _NotificationPlaceholderPanel extends StatelessWidget {
  const _NotificationPlaceholderPanel({required this.controller});

  final ProfileController controller;

  @override
  Widget build(BuildContext context) {
    final prefs = controller.notificationPreferences;
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.notificationSettingsDescription,
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 8),
        SwitchListTile.adaptive(
          key: const Key('notification-setting-event-updates'),
          value: prefs.eventReminders,
          onChanged: controller.updateEventRemindersPreference,
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.notificationSettingsEventUpdates),
          subtitle: Text(l10n.notificationSettingsPlaceholderNote),
        ),
        SwitchListTile.adaptive(
          key: const Key('notification-setting-scholarship-updates'),
          value: prefs.scholarshipUpdates,
          onChanged: controller.updateScholarshipUpdatesPreference,
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.notificationSettingsScholarshipUpdates),
          subtitle: Text(l10n.notificationSettingsPlaceholderNote),
        ),
        SwitchListTile.adaptive(
          value: prefs.fundTransactions,
          onChanged: controller.updateFundTransactionsPreference,
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.profileNotificationFundAlerts),
          subtitle: Text(l10n.notificationSettingsPlaceholderNote),
        ),
        SwitchListTile.adaptive(
          key: const Key('notification-setting-general-updates'),
          value: prefs.systemNotices,
          onChanged: controller.updateSystemNoticesPreference,
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.notificationSettingsGeneralUpdates),
          subtitle: Text(l10n.notificationSettingsPlaceholderNote),
        ),
        SwitchListTile.adaptive(
          key: const Key('notification-setting-quiet-hours'),
          value: false,
          onChanged: null,
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.notificationSettingsQuietHours),
          subtitle: Text(l10n.notificationSettingsPlaceholderNote),
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
  });

  final MemberProfile profile;
  final String roleLabel;
  final VoidCallback onEditProfile;
  final VoidCallback? onAvatarTap;
  final bool isUploadingAvatar;

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
                  l10n.pick(
                    vi: 'Chạm ảnh để xem hoặc đổi ảnh đại diện',
                    en: 'Tap avatar to view or upload a new profile photo',
                  ),
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
    _phoneController = TextEditingController(
      text: widget.initialDraft.phoneInput,
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });

    final error = await widget.onSubmit(
      ProfileDraft(
        fullName: _fullNameController.text.trim(),
        nickName: _nickNameController.text.trim(),
        phoneInput: _phoneController.text.trim(),
        email: _emailController.text.trim(),
        addressText: _addressController.text.trim(),
        jobTitle: _jobTitleController.text.trim(),
        bio: _bioController.text.trim(),
        facebook: _facebookController.text.trim(),
        zalo: _zaloController.text.trim(),
        linkedin: _linkedinController.text.trim(),
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
                TextFormField(
                  controller: _phoneController,
                  decoration: InputDecoration(labelText: l10n.memberPhoneLabel),
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
                TextFormField(
                  controller: _addressController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: l10n.memberAddressLabel,
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _bioController,
                  maxLines: 3,
                  decoration: InputDecoration(labelText: l10n.memberBioLabel),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _facebookController,
                  decoration: InputDecoration(
                    labelText: l10n.profileFacebookUrlLabel,
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _zaloController,
                  decoration: InputDecoration(
                    labelText: l10n.profileZaloUrlLabel,
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _linkedinController,
                  decoration: InputDecoration(
                    labelText: l10n.profileLinkedinUrlLabel,
                  ),
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
  });

  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
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

String _memberErrorMessage(
  AppLocalizations l10n,
  MemberRepositoryErrorCode code,
) {
  return switch (code) {
    MemberRepositoryErrorCode.duplicatePhone => l10n.memberDuplicatePhoneError,
    MemberRepositoryErrorCode.permissionDenied =>
      l10n.memberPermissionDeniedError,
    MemberRepositoryErrorCode.memberNotFound => l10n.memberNotFoundDescription,
    MemberRepositoryErrorCode.avatarUploadFailed =>
      l10n.memberAvatarUploadError,
  };
}
