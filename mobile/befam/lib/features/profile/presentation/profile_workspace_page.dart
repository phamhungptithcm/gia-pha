import 'dart:async';

import 'package:flutter/material.dart';

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
    this.onLogoutRequested,
  });

  final AuthSession session;
  final MemberRepository memberRepository;
  final MemberAvatarPicker? avatarPicker;
  final Future<void> Function()? onLogoutRequested;

  @override
  State<ProfileWorkspacePage> createState() => _ProfileWorkspacePageState();
}

class _ProfileWorkspacePageState extends State<ProfileWorkspacePage> {
  late final ProfileController _controller;
  late final MemberAvatarPicker _avatarPicker;

  @override
  void initState() {
    super.initState();
    _controller = ProfileController(
      memberRepository: widget.memberRepository,
      session: widget.session,
    );
    _avatarPicker = widget.avatarPicker ?? createDefaultMemberAvatarPicker();
    unawaited(_controller.initialize());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _openEditor(MemberProfile profile) async {
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully.')),
      );
    }
  }

  Future<void> _handleAvatarUpload() async {
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
      ).showSnackBar(const SnackBar(content: Text('Profile image updated.')));
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(_memberErrorMessage(error))));
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) {
          return _SettingsScreenShell(
            controller: _controller,
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

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Log out?'),
          content: const Text(
            'You can sign back in at any time with your linked account.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Log out'),
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
            title: const Text('Profile'),
            actions: [
              IconButton(
                tooltip: 'Refresh profile',
                onPressed: _controller.isLoading ? null : _controller.refresh,
                icon: const Icon(Icons.refresh),
              ),
              IconButton(
                tooltip: 'Open settings',
                onPressed: _openSettings,
                icon: const Icon(Icons.settings_outlined),
              ),
            ],
          ),
          body: SafeArea(
            child: _controller.isLoading
                ? const Center(child: CircularProgressIndicator())
                : !_controller.hasMemberContext
                ? const _ProfileEmptyState(
                    icon: Icons.lock_outline,
                    title: 'Missing member context',
                    description:
                        'Link your account to a member profile before managing settings.',
                  )
                : _controller.profile == null
                ? _ProfileEmptyState(
                    icon: Icons.person_search_outlined,
                    title: 'Profile record not found',
                    description:
                        'We could not resolve your member profile from the current clan scope.',
                    actionLabel: 'Retry',
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
                          onUpdatePhoto: _controller.isUploadingAvatar
                              ? null
                              : _handleAvatarUpload,
                        ),
                        const SizedBox(height: 20),
                        if (_controller.errorMessage != null) ...[
                          _ProfileInfoCard(
                            icon: Icons.error_outline,
                            title: 'Could not update profile',
                            description: _controller.errorMessage!,
                            tone: colorScheme.errorContainer,
                          ),
                          const SizedBox(height: 20),
                        ],
                        _ProfileSectionCard(
                          title: 'Profile details',
                          actionLabel: 'Edit',
                          onAction: () => _openEditor(_controller.profile!),
                          child: Column(
                            children: [
                              _ProfileDetailRow(
                                label: 'Full name',
                                value: _controller.profile!.fullName,
                              ),
                              _ProfileDetailRow(
                                label: 'Nickname',
                                value:
                                    _controller.profile!.nickName.trim().isEmpty
                                    ? 'Not set'
                                    : _controller.profile!.nickName,
                              ),
                              _ProfileDetailRow(
                                label: 'Phone',
                                value:
                                    _controller.profile!.phoneE164 ?? 'Not set',
                              ),
                              _ProfileDetailRow(
                                label: 'Email',
                                value: _controller.profile!.email ?? 'Not set',
                              ),
                              _ProfileDetailRow(
                                label: 'Job title',
                                value:
                                    _controller.profile!.jobTitle ?? 'Not set',
                              ),
                              _ProfileDetailRow(
                                label: 'Address',
                                value:
                                    _controller.profile!.addressText ??
                                    'Not set',
                              ),
                              _ProfileDetailRow(
                                label: 'Bio',
                                value: _controller.profile!.bio ?? 'Not set',
                                isLast: true,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        _ProfileSectionCard(
                          title: 'Notification preferences',
                          child: _NotificationPlaceholderPanel(
                            controller: _controller,
                          ),
                        ),
                        const SizedBox(height: 20),
                        if (widget.onLogoutRequested != null)
                          _ProfileSectionCard(
                            title: 'Account',
                            child: OutlinedButton.icon(
                              onPressed: _confirmLogout,
                              icon: const Icon(Icons.logout),
                              label: const Text('Log out'),
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
    required this.onLogoutRequested,
  });

  final ProfileController controller;
  final Future<void> Function()? onLogoutRequested;

  Future<void> _confirmLogout(BuildContext context) async {
    if (onLogoutRequested == null) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Log out?'),
          content: const Text(
            'This confirmation prevents accidental sign out while managing settings.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Log out'),
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

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('Settings')),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                _ProfileSectionCard(
                  title: 'Settings shell',
                  child: Text(
                    'This shell groups account and preference settings for later expansion.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(height: 20),
                _ProfileSectionCard(
                  title: 'Notification preference placeholders',
                  child: _NotificationPlaceholderPanel(controller: controller),
                ),
                const SizedBox(height: 20),
                _ProfileSectionCard(
                  title: 'Privacy and security',
                  child: const _ProfileEmptyState(
                    icon: Icons.security_outlined,
                    title: 'Security settings placeholder',
                    description:
                        'Passwordless auth and session security options will be connected in a later story.',
                  ),
                ),
                if (onLogoutRequested != null) ...[
                  const SizedBox(height: 20),
                  _ProfileSectionCard(
                    title: 'Session',
                    child: OutlinedButton.icon(
                      onPressed: () => _confirmLogout(context),
                      icon: const Icon(Icons.logout),
                      label: const Text('Log out'),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Preference toggles are placeholders for now. They update local state in this session.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 8),
        SwitchListTile.adaptive(
          key: const Key('notification-setting-event-updates'),
          value: prefs.eventReminders,
          onChanged: controller.updateEventRemindersPreference,
          contentPadding: EdgeInsets.zero,
          title: const Text('Event reminders'),
          subtitle: const Text('Placeholder only'),
        ),
        SwitchListTile.adaptive(
          key: const Key('notification-setting-scholarship-updates'),
          value: prefs.scholarshipUpdates,
          onChanged: controller.updateScholarshipUpdatesPreference,
          contentPadding: EdgeInsets.zero,
          title: const Text('Scholarship updates'),
          subtitle: const Text('Placeholder only'),
        ),
        SwitchListTile.adaptive(
          value: prefs.fundTransactions,
          onChanged: controller.updateFundTransactionsPreference,
          contentPadding: EdgeInsets.zero,
          title: const Text('Fund transaction alerts'),
          subtitle: const Text('Placeholder only'),
        ),
        SwitchListTile.adaptive(
          key: const Key('notification-setting-general-updates'),
          value: prefs.systemNotices,
          onChanged: controller.updateSystemNoticesPreference,
          contentPadding: EdgeInsets.zero,
          title: const Text('System notices'),
          subtitle: const Text('Placeholder only'),
        ),
        SwitchListTile.adaptive(
          key: const Key('notification-setting-quiet-hours'),
          value: false,
          onChanged: null,
          contentPadding: EdgeInsets.zero,
          title: const Text('Quiet hours'),
          subtitle: const Text('Placeholder only'),
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
    this.onUpdatePhoto,
  });

  final MemberProfile profile;
  final String roleLabel;
  final VoidCallback onEditProfile;
  final VoidCallback? onUpdatePhoto;

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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.fullName,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: colorScheme.onPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  roleLabel,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onPrimary.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: colorScheme.surface,
                        foregroundColor: colorScheme.onSurface,
                      ),
                      onPressed: onEditProfile,
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Edit profile'),
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colorScheme.onPrimary,
                        side: BorderSide(
                          color: colorScheme.onPrimary.withValues(alpha: 0.45),
                        ),
                      ),
                      onPressed: onUpdatePhoto,
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: const Text('Update photo'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

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
                  'Edit profile',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Update your member profile details and social links.',
                  style: theme.textTheme.bodyMedium,
                ),
                if (_submitError != null) ...[
                  const SizedBox(height: 16),
                  _ProfileInfoCard(
                    icon: Icons.error_outline,
                    title: 'Could not save profile',
                    description: _memberErrorMessage(_submitError!),
                    tone: theme.colorScheme.errorContainer,
                  ),
                ],
                const SizedBox(height: 18),
                TextFormField(
                  controller: _fullNameController,
                  decoration: const InputDecoration(labelText: 'Full name'),
                  validator: (value) {
                    return value == null || value.trim().isEmpty
                        ? 'Full name is required.'
                        : null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _nickNameController,
                  decoration: const InputDecoration(labelText: 'Nickname'),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(labelText: 'Phone'),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _jobTitleController,
                  decoration: const InputDecoration(labelText: 'Job title'),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _addressController,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Address'),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _bioController,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Bio'),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _facebookController,
                  decoration: const InputDecoration(labelText: 'Facebook URL'),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _zaloController,
                  decoration: const InputDecoration(labelText: 'Zalo URL'),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _linkedinController,
                  decoration: const InputDecoration(labelText: 'LinkedIn URL'),
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
                          ? 'Saving...'
                          : 'Save profile',
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
  const _ProfileSectionCard({
    required this.title,
    required this.child,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final Widget child;
  final String? actionLabel;
  final VoidCallback? onAction;

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
                if (actionLabel != null && onAction != null)
                  TextButton(onPressed: onAction, child: Text(actionLabel!)),
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

String _memberErrorMessage(MemberRepositoryErrorCode code) {
  return switch (code) {
    MemberRepositoryErrorCode.duplicatePhone =>
      'This phone number is already linked to another member.',
    MemberRepositoryErrorCode.permissionDenied =>
      'You do not have permission for this action.',
    MemberRepositoryErrorCode.memberNotFound => 'Profile record not found.',
    MemberRepositoryErrorCode.avatarUploadFailed =>
      'Image upload failed. Please try again.',
  };
}
