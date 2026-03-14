import 'dart:async';

import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../l10n/l10n.dart';
import '../../auth/models/auth_session.dart';
import '../../auth/services/phone_number_formatter.dart';
import '../../clan/models/branch_profile.dart';
import '../../relationship/presentation/relationship_inspector_panel.dart';
import '../../relationship/services/relationship_repository.dart';
import '../models/member_draft.dart';
import '../models/member_profile.dart';
import '../models/member_social_links.dart';
import '../services/member_avatar_picker.dart';
import '../services/member_repository.dart';
import 'member_controller.dart';

class MemberWorkspacePage extends StatefulWidget {
  const MemberWorkspacePage({
    super.key,
    required this.session,
    required this.repository,
    this.avatarPicker,
    this.relationshipRepository,
  });

  final AuthSession session;
  final MemberRepository repository;
  final MemberAvatarPicker? avatarPicker;
  final RelationshipRepository? relationshipRepository;

  @override
  State<MemberWorkspacePage> createState() => _MemberWorkspacePageState();
}

class _MemberWorkspacePageState extends State<MemberWorkspacePage> {
  late final MemberController _controller;
  late final MemberAvatarPicker _avatarPicker;
  late final TextEditingController _searchController;
  late final RelationshipRepository _relationshipRepository;

  @override
  void initState() {
    super.initState();
    _controller = MemberController(
      repository: widget.repository,
      session: widget.session,
    );
    _avatarPicker = widget.avatarPicker ?? createDefaultMemberAvatarPicker();
    _relationshipRepository =
        widget.relationshipRepository ?? createDefaultRelationshipRepository();
    _searchController = TextEditingController();
    unawaited(_controller.initialize());
  }

  @override
  void dispose() {
    _searchController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _openMemberEditor({MemberProfile? member}) async {
    final didSave = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _MemberEditorSheet(
          title: member == null
              ? context.l10n.memberAddSheetTitle
              : context.l10n.memberEditSheetTitle,
          allowOrganizationFields:
              member == null ||
              _controller.permissions.canEditOrganizationFields,
          initialDraft: member == null
              ? MemberDraft.empty(
                  defaultBranchId: _controller.permissions.restrictedBranchId,
                )
              : MemberDraft.fromProfile(member),
          branches: _controller.visibleBranches,
          isSaving: _controller.isSaving,
          onSubmit: (draft) {
            return _controller.saveMember(memberId: member?.id, draft: draft);
          },
        );
      },
    );

    if (didSave == true && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.memberSaveSuccess)));
    }
  }

  void _openMemberDetail(MemberProfile member) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) {
          return _MemberDetailPage(
            controller: _controller,
            session: widget.session,
            memberId: member.id,
            avatarPicker: _avatarPicker,
            relationshipRepository: _relationshipRepository,
            onEditMember: _openMemberEditor,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        final l10n = context.l10n;

        return Scaffold(
          appBar: AppBar(
            title: Text(l10n.memberWorkspaceTitle),
            actions: [
              IconButton(
                tooltip: l10n.memberRefreshAction,
                onPressed: _controller.isLoading ? null : _controller.refresh,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          body: SafeArea(
            child: _controller.isLoading
                ? const Center(child: CircularProgressIndicator())
                : !_controller.hasClanContext
                ? _WorkspaceEmptyState(
                    icon: Icons.lock_outline,
                    title: l10n.memberNoContextTitle,
                    description: l10n.memberNoContextDescription,
                  )
                : RefreshIndicator(
                    onRefresh: _controller.refresh,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                      children: [
                        _WorkspaceHero(
                          title: l10n.memberWorkspaceHeroTitle,
                          description: l10n.memberWorkspaceHeroDescription,
                          isSandbox: widget.repository.isSandbox,
                          canCreateMembers:
                              _controller.permissions.canCreateMembers,
                          onAddMember: _controller.permissions.canCreateMembers
                              ? () => _openMemberEditor()
                              : null,
                        ),
                        const SizedBox(height: 20),
                        if (_controller.permissions.isReadOnly) ...[
                          _MessageCard(
                            icon: Icons.visibility_outlined,
                            title: l10n.memberReadOnlyTitle,
                            description: l10n.memberReadOnlyDescription,
                            tone: colorScheme.secondaryContainer,
                          ),
                          const SizedBox(height: 20),
                        ],
                        if (_controller.errorMessage != null) ...[
                          _MessageCard(
                            icon: Icons.error_outline,
                            title: l10n.memberLoadErrorTitle,
                            description: l10n.memberLoadErrorDescription,
                            tone: colorScheme.errorContainer,
                          ),
                          const SizedBox(height: 20),
                        ],
                        _StatGrid(
                          items: [
                            _StatTile(
                              label: l10n.memberStatCount,
                              value: '${_controller.members.length}',
                              icon: Icons.groups_2_outlined,
                            ),
                            _StatTile(
                              label: l10n.memberStatVisible,
                              value: '${_controller.filteredMembers.length}',
                              icon: Icons.filter_alt_outlined,
                            ),
                            _StatTile(
                              label: l10n.memberStatRole,
                              value: l10n.roleLabel(widget.session.primaryRole),
                              icon: Icons.verified_user_outlined,
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        if (_controller.selfMember case final selfMember?) ...[
                          _SectionCard(
                            title: l10n.memberOwnProfileTitle,
                            actionLabel: _controller.canEditMember(selfMember)
                                ? l10n.memberEditOwnProfileAction
                                : null,
                            onAction: _controller.canEditMember(selfMember)
                                ? () => _openMemberEditor(member: selfMember)
                                : null,
                            child: _MemberSummaryCard(
                              member: selfMember,
                              branchName: _controller.branchName(
                                selfMember.branchId,
                              ),
                              roleLabel: l10n.roleLabel(selfMember.primaryRole),
                              onTap: () => _openMemberDetail(selfMember),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                        _SectionCard(
                          title: l10n.memberFilterSectionTitle,
                          child: _FilterPanel(
                            searchController: _searchController,
                            branches: _controller.visibleBranches,
                            generationOptions: _controller.generationOptions,
                            filtersBranchId: _controller.filters.branchId,
                            filtersGeneration: _controller.filters.generation,
                            onSearchChanged: _controller.updateSearchQuery,
                            onBranchChanged: _controller.updateBranchFilter,
                            onGenerationChanged:
                                _controller.updateGenerationFilter,
                            onClearFilters: () {
                              _searchController.clear();
                              _controller.updateSearchQuery('');
                              _controller.updateBranchFilter(null);
                              _controller.updateGenerationFilter(null);
                            },
                          ),
                        ),
                        const SizedBox(height: 20),
                        _SectionCard(
                          title: l10n.memberListSectionTitle,
                          actionLabel: _controller.permissions.canCreateMembers
                              ? l10n.memberAddAction
                              : null,
                          onAction: _controller.permissions.canCreateMembers
                              ? () => _openMemberEditor()
                              : null,
                          child: _controller.filteredMembers.isEmpty
                              ? _WorkspaceEmptyState(
                                  icon: Icons.person_search_outlined,
                                  title: l10n.memberListEmptyTitle,
                                  description: l10n.memberListEmptyDescription,
                                )
                              : Column(
                                  children: [
                                    for (final member
                                        in _controller.filteredMembers)
                                      Padding(
                                        padding: EdgeInsets.only(
                                          bottom:
                                              member ==
                                                  _controller
                                                      .filteredMembers
                                                      .last
                                              ? 0
                                              : 14,
                                        ),
                                        child: _MemberSummaryCard(
                                          key: Key('member-row-${member.id}'),
                                          member: member,
                                          branchName: _controller.branchName(
                                            member.branchId,
                                          ),
                                          roleLabel: l10n.roleLabel(
                                            member.primaryRole,
                                          ),
                                          onTap: () =>
                                              _openMemberDetail(member),
                                        ),
                                      ),
                                  ],
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

class _MemberDetailPage extends StatelessWidget {
  const _MemberDetailPage({
    required this.controller,
    required this.session,
    required this.memberId,
    required this.avatarPicker,
    required this.relationshipRepository,
    required this.onEditMember,
  });

  final MemberController controller;
  final AuthSession session;
  final String memberId;
  final MemberAvatarPicker avatarPicker;
  final RelationshipRepository relationshipRepository;
  final Future<void> Function({MemberProfile? member}) onEditMember;

  Future<void> _handleAvatarUpload(
    BuildContext context,
    MemberProfile member,
  ) async {
    final l10n = context.l10n;
    final picked = await avatarPicker.pickAvatar();
    if (picked == null || !context.mounted) {
      return;
    }

    final error = await controller.uploadAvatar(
      member: member,
      bytes: picked.bytes,
      fileName: picked.fileName,
      contentType: picked.contentType,
    );
    if (!context.mounted) {
      return;
    }

    if (error == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.memberAvatarUploadSuccess)));
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_memberRepositoryErrorMessage(l10n, error))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final member = controller.memberById(memberId);
        final l10n = context.l10n;
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;

        return Scaffold(
          appBar: AppBar(
            title: Text(l10n.memberDetailTitle),
            actions: [
              if (member != null && controller.canUploadAvatar(member))
                IconButton(
                  key: const Key('member-upload-avatar-button'),
                  tooltip: l10n.memberUploadAvatarAction,
                  onPressed: controller.isUploadingAvatar
                      ? null
                      : () => _handleAvatarUpload(context, member),
                  icon: const Icon(Icons.cloud_upload_outlined),
                ),
              if (member != null && controller.canEditMember(member))
                IconButton(
                  key: const Key('member-edit-button'),
                  tooltip: l10n.memberEditAction,
                  onPressed: () => onEditMember(member: member),
                  icon: const Icon(Icons.edit_outlined),
                ),
            ],
          ),
          body: SafeArea(
            child: member == null
                ? _WorkspaceEmptyState(
                    icon: Icons.person_off_outlined,
                    title: l10n.memberNotFoundTitle,
                    description: l10n.memberNotFoundDescription,
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _AvatarBadge(member: member, radius: 34),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      member.fullName,
                                      style: theme.textTheme.headlineSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      member.nickName.trim().isEmpty
                                          ? l10n.memberDetailNoNickname
                                          : member.nickName,
                                      style: theme.textTheme.titleMedium,
                                    ),
                                    const SizedBox(height: 12),
                                    Wrap(
                                      spacing: 10,
                                      runSpacing: 10,
                                      children: [
                                        _ChipPill(
                                          icon: Icons.account_tree_outlined,
                                          label: controller.branchName(
                                            member.branchId,
                                          ),
                                        ),
                                        _ChipPill(
                                          icon: Icons.filter_5_outlined,
                                          label:
                                              '${l10n.memberGenerationLabel}: ${member.generation}',
                                        ),
                                        _ChipPill(
                                          icon: Icons.verified_user_outlined,
                                          label: l10n.roleLabel(
                                            member.primaryRole,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      _SectionCard(
                        title: l10n.memberDetailSummaryTitle,
                        actionLabel: controller.canEditMember(member)
                            ? l10n.memberEditAction
                            : null,
                        onAction: controller.canEditMember(member)
                            ? () => onEditMember(member: member)
                            : null,
                        child: Column(
                          children: [
                            _DetailRow(
                              label: l10n.memberFullNameLabel,
                              value: member.fullName,
                            ),
                            _DetailRow(
                              label: l10n.memberNicknameLabel,
                              value: member.nickName.trim().isEmpty
                                  ? l10n.memberFieldUnset
                                  : member.nickName,
                            ),
                            _DetailRow(
                              label: l10n.memberPhoneLabel,
                              value: member.phoneE164 ?? l10n.memberFieldUnset,
                            ),
                            _DetailRow(
                              label: l10n.memberEmailLabel,
                              value: member.email ?? l10n.memberFieldUnset,
                            ),
                            _DetailRow(
                              label: l10n.memberGenderLabel,
                              value: _genderLabel(l10n, member.gender),
                            ),
                            _DetailRow(
                              label: l10n.memberBirthDateLabel,
                              value: member.birthDate ?? l10n.memberFieldUnset,
                            ),
                            _DetailRow(
                              label: l10n.memberDeathDateLabel,
                              value: member.deathDate ?? l10n.memberFieldUnset,
                            ),
                            _DetailRow(
                              label: l10n.memberJobTitleLabel,
                              value: member.jobTitle ?? l10n.memberFieldUnset,
                            ),
                            _DetailRow(
                              label: l10n.memberAddressLabel,
                              value:
                                  member.addressText ?? l10n.memberFieldUnset,
                            ),
                            _DetailRow(
                              label: l10n.memberBioLabel,
                              value: member.bio ?? l10n.memberFieldUnset,
                              isLast: true,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      _SectionCard(
                        title: l10n.memberSocialLinksTitle,
                        child: member.socialLinks.isEmpty
                            ? _WorkspaceEmptyState(
                                icon: Icons.link_off_outlined,
                                title: l10n.memberSocialLinksEmptyTitle,
                                description:
                                    l10n.memberSocialLinksEmptyDescription,
                              )
                            : Column(
                                children: [
                                  if (member.socialLinks.facebook != null)
                                    _DetailRow(
                                      label: 'Facebook',
                                      value: member.socialLinks.facebook!,
                                    ),
                                  if (member.socialLinks.zalo != null)
                                    _DetailRow(
                                      label: 'Zalo',
                                      value: member.socialLinks.zalo!,
                                    ),
                                  if (member.socialLinks.linkedin != null)
                                    _DetailRow(
                                      label: 'LinkedIn',
                                      value: member.socialLinks.linkedin!,
                                      isLast: true,
                                    ),
                                ],
                              ),
                      ),
                      const SizedBox(height: 20),
                      RelationshipInspectorPanel(
                        session: session,
                        member: member,
                        members: controller.members,
                        repository: relationshipRepository,
                        onRelationshipsChanged: controller.refresh,
                      ),
                      if (controller.canUploadAvatar(member)) ...[
                        const SizedBox(height: 20),
                        Card(
                          color: colorScheme.secondaryContainer,
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Row(
                              children: [
                                const Icon(Icons.image_outlined),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    l10n.memberAvatarHint,
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                ),
                              ],
                            ),
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

class _MemberEditorSheet extends StatefulWidget {
  const _MemberEditorSheet({
    required this.title,
    required this.allowOrganizationFields,
    required this.initialDraft,
    required this.branches,
    required this.isSaving,
    required this.onSubmit,
  });

  final String title;
  final bool allowOrganizationFields;
  final MemberDraft initialDraft;
  final List<BranchProfile> branches;
  final bool isSaving;
  final Future<MemberRepositoryErrorCode?> Function(MemberDraft draft) onSubmit;

  @override
  State<_MemberEditorSheet> createState() => _MemberEditorSheetState();
}

class _MemberEditorSheetState extends State<_MemberEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _fullNameController;
  late final TextEditingController _nickNameController;
  late final TextEditingController _birthDateController;
  late final TextEditingController _deathDateController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _addressController;
  late final TextEditingController _jobTitleController;
  late final TextEditingController _bioController;
  late final TextEditingController _generationController;
  late final TextEditingController _facebookController;
  late final TextEditingController _zaloController;
  late final TextEditingController _linkedinController;

  String? _branchId;
  String? _gender;
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
    _birthDateController = TextEditingController(
      text: widget.initialDraft.birthDate ?? '',
    );
    _deathDateController = TextEditingController(
      text: widget.initialDraft.deathDate ?? '',
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
    _generationController = TextEditingController(
      text: '${widget.initialDraft.generation}',
    );
    _facebookController = TextEditingController(
      text: widget.initialDraft.socialLinks.facebook ?? '',
    );
    _zaloController = TextEditingController(
      text: widget.initialDraft.socialLinks.zalo ?? '',
    );
    _linkedinController = TextEditingController(
      text: widget.initialDraft.socialLinks.linkedin ?? '',
    );
    _branchId = widget.initialDraft.branchId;
    _gender = widget.initialDraft.gender;
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _nickNameController.dispose();
    _birthDateController.dispose();
    _deathDateController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _jobTitleController.dispose();
    _bioController.dispose();
    _generationController.dispose();
    _facebookController.dispose();
    _zaloController.dispose();
    _linkedinController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(TextEditingController controller) async {
    final current = _tryParseIsoDate(controller.text.trim());
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
      initialDate: current ?? DateTime.now(),
    );
    if (picked == null || !mounted) {
      return;
    }

    controller.text = _formatIsoDate(picked);
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
      MemberDraft(
        branchId: _branchId,
        fullName: _fullNameController.text.trim(),
        nickName: _nickNameController.text.trim(),
        gender: _gender,
        birthDate: _nullIfBlank(_birthDateController.text),
        deathDate: _nullIfBlank(_deathDateController.text),
        phoneInput: _phoneController.text.trim(),
        email: _emailController.text.trim(),
        addressText: _addressController.text.trim(),
        jobTitle: _jobTitleController.text.trim(),
        bio: _bioController.text.trim(),
        generation: int.parse(_generationController.text.trim()),
        socialLinks: MemberSocialLinks(
          facebook: _nullIfBlank(_facebookController.text),
          zalo: _nullIfBlank(_zaloController.text),
          linkedin: _nullIfBlank(_linkedinController.text),
        ),
        isMinor: false,
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
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final insets = MediaQuery.viewInsetsOf(context);

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
                  widget.title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  l10n.memberEditorDescription,
                  style: theme.textTheme.bodyMedium,
                ),
                if (_submitError != null) ...[
                  const SizedBox(height: 16),
                  _MessageCard(
                    icon: Icons.error_outline,
                    title: l10n.memberSaveErrorTitle,
                    description: _memberRepositoryErrorMessage(
                      l10n,
                      _submitError!,
                    ),
                    tone: theme.colorScheme.errorContainer,
                  ),
                ],
                const SizedBox(height: 20),
                TextFormField(
                  key: const Key('member-full-name-input'),
                  controller: _fullNameController,
                  decoration: InputDecoration(
                    labelText: l10n.memberFullNameLabel,
                    hintText: l10n.memberFullNameHint,
                  ),
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    return value == null || value.trim().isEmpty
                        ? l10n.memberValidationNameRequired
                        : null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  key: const Key('member-nickname-input'),
                  controller: _nickNameController,
                  decoration: InputDecoration(
                    labelText: l10n.memberNicknameLabel,
                    hintText: l10n.memberNicknameHint,
                  ),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  key: const Key('member-branch-input'),
                  initialValue: _branchId,
                  decoration: InputDecoration(
                    labelText: l10n.memberBranchLabel,
                  ),
                  items: [
                    for (final branch in widget.branches)
                      DropdownMenuItem<String>(
                        value: branch.id,
                        child: Text(branch.name),
                      ),
                  ],
                  onChanged: widget.allowOrganizationFields
                      ? (value) {
                          setState(() {
                            _branchId = value;
                          });
                        }
                      : null,
                  validator: (value) {
                    return value == null || value.isEmpty
                        ? l10n.memberValidationBranchRequired
                        : null;
                  },
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String?>(
                        key: const Key('member-gender-input'),
                        initialValue: _gender,
                        decoration: InputDecoration(
                          labelText: l10n.memberGenderLabel,
                        ),
                        items: [
                          DropdownMenuItem<String?>(
                            value: null,
                            child: Text(l10n.memberGenderUnspecified),
                          ),
                          DropdownMenuItem<String?>(
                            value: 'male',
                            child: Text(l10n.memberGenderMale),
                          ),
                          DropdownMenuItem<String?>(
                            value: 'female',
                            child: Text(l10n.memberGenderFemale),
                          ),
                          DropdownMenuItem<String?>(
                            value: 'other',
                            child: Text(l10n.memberGenderOther),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _gender = value;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: TextFormField(
                        key: const Key('member-generation-input'),
                        controller: _generationController,
                        enabled: widget.allowOrganizationFields,
                        decoration: InputDecoration(
                          labelText: l10n.memberGenerationLabel,
                        ),
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.next,
                        validator: (value) {
                          final parsed = int.tryParse(value ?? '');
                          return parsed == null || parsed <= 0
                              ? l10n.memberValidationGenerationRequired
                              : null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        key: const Key('member-birth-date-input'),
                        controller: _birthDateController,
                        decoration: InputDecoration(
                          labelText: l10n.memberBirthDateLabel,
                          hintText: 'YYYY-MM-DD',
                          suffixIcon: IconButton(
                            onPressed: () => _pickDate(_birthDateController),
                            icon: const Icon(Icons.calendar_today_outlined),
                          ),
                        ),
                        validator: (value) {
                          return _isValidIsoDateOrBlank(value)
                              ? null
                              : l10n.memberValidationDateInvalid;
                        },
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: TextFormField(
                        key: const Key('member-death-date-input'),
                        controller: _deathDateController,
                        decoration: InputDecoration(
                          labelText: l10n.memberDeathDateLabel,
                          hintText: 'YYYY-MM-DD',
                          suffixIcon: IconButton(
                            onPressed: () => _pickDate(_deathDateController),
                            icon: const Icon(Icons.calendar_today_outlined),
                          ),
                        ),
                        validator: (value) {
                          return _isValidIsoDateOrBlank(value)
                              ? null
                              : l10n.memberValidationDateInvalid;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextFormField(
                  key: const Key('member-phone-input'),
                  controller: _phoneController,
                  decoration: InputDecoration(
                    labelText: l10n.memberPhoneLabel,
                    hintText: l10n.memberPhoneHint,
                  ),
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    final trimmed = value?.trim() ?? '';
                    if (trimmed.isEmpty) {
                      return null;
                    }

                    try {
                      PhoneNumberFormatter.parse(trimmed);
                      return null;
                    } catch (_) {
                      return l10n.memberValidationPhoneInvalid;
                    }
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  key: const Key('member-email-input'),
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: l10n.memberEmailLabel,
                    hintText: 'member@befam.vn',
                  ),
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  key: const Key('member-job-title-input'),
                  controller: _jobTitleController,
                  decoration: InputDecoration(
                    labelText: l10n.memberJobTitleLabel,
                    hintText: l10n.memberJobTitleHint,
                  ),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  key: const Key('member-address-input'),
                  controller: _addressController,
                  decoration: InputDecoration(
                    labelText: l10n.memberAddressLabel,
                    hintText: l10n.memberAddressHint,
                  ),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  key: const Key('member-facebook-input'),
                  controller: _facebookController,
                  decoration: const InputDecoration(labelText: 'Facebook'),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  key: const Key('member-zalo-input'),
                  controller: _zaloController,
                  decoration: const InputDecoration(labelText: 'Zalo'),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  key: const Key('member-linkedin-input'),
                  controller: _linkedinController,
                  decoration: const InputDecoration(labelText: 'LinkedIn'),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  key: const Key('member-bio-input'),
                  controller: _bioController,
                  decoration: InputDecoration(labelText: l10n.memberBioLabel),
                  minLines: 3,
                  maxLines: 5,
                ),
                const SizedBox(height: 22),
                FilledButton.icon(
                  key: const Key('member-save-button'),
                  onPressed: (_isSubmitting || widget.isSaving)
                      ? null
                      : _submit,
                  icon: (_isSubmitting || widget.isSaving)
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(l10n.memberSaveAction),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FilterPanel extends StatelessWidget {
  const _FilterPanel({
    required this.searchController,
    required this.branches,
    required this.generationOptions,
    required this.filtersBranchId,
    required this.filtersGeneration,
    required this.onSearchChanged,
    required this.onBranchChanged,
    required this.onGenerationChanged,
    required this.onClearFilters,
  });

  final TextEditingController searchController;
  final List<BranchProfile> branches;
  final List<int> generationOptions;
  final String? filtersBranchId;
  final int? filtersGeneration;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String?> onBranchChanged;
  final ValueChanged<int?> onGenerationChanged;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Column(
      children: [
        TextField(
          key: const Key('members-search-input'),
          controller: searchController,
          onChanged: onSearchChanged,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            labelText: l10n.memberSearchLabel,
            hintText: l10n.memberSearchHint,
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String?>(
                key: const Key('members-branch-filter'),
                initialValue: filtersBranchId,
                decoration: InputDecoration(
                  labelText: l10n.memberFilterBranchLabel,
                ),
                items: [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text(l10n.memberFilterAllBranches),
                  ),
                  for (final branch in branches)
                    DropdownMenuItem<String?>(
                      value: branch.id,
                      child: Text(branch.name),
                    ),
                ],
                onChanged: onBranchChanged,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: DropdownButtonFormField<int?>(
                key: const Key('members-generation-filter'),
                initialValue: filtersGeneration,
                decoration: InputDecoration(
                  labelText: l10n.memberFilterGenerationLabel,
                ),
                items: [
                  DropdownMenuItem<int?>(
                    value: null,
                    child: Text(l10n.memberFilterAllGenerations),
                  ),
                  for (final generation in generationOptions)
                    DropdownMenuItem<int?>(
                      value: generation,
                      child: Text('${l10n.memberGenerationLabel} $generation'),
                    ),
                ],
                onChanged: onGenerationChanged,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: onClearFilters,
            icon: const Icon(Icons.filter_alt_off_outlined),
            label: Text(l10n.memberClearFiltersAction),
          ),
        ),
      ],
    );
  }
}

class _MemberSummaryCard extends StatelessWidget {
  const _MemberSummaryCard({
    super.key,
    required this.member,
    required this.branchName,
    required this.roleLabel,
    required this.onTap,
  });

  final MemberProfile member;
  final String branchName;
  final String roleLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = context.l10n;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _AvatarBadge(member: member),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.fullName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _ChipPill(
                          icon: Icons.account_tree_outlined,
                          label: branchName,
                        ),
                        _ChipPill(
                          icon: Icons.filter_5_outlined,
                          label:
                              '${l10n.memberGenerationLabel}: ${member.generation}',
                        ),
                        _ChipPill(icon: Icons.badge_outlined, label: roleLabel),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      member.phoneE164 ?? l10n.memberPhoneMissing,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _AvatarBadge extends StatelessWidget {
  const _AvatarBadge({required this.member, this.radius = 26});

  final MemberProfile member;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final url = member.avatarUrl;
    final isNetwork =
        url != null &&
        (url.startsWith('http://') || url.startsWith('https://'));

    return CircleAvatar(
      radius: radius,
      backgroundColor: colorScheme.primaryContainer,
      foregroundColor: colorScheme.onPrimaryContainer,
      backgroundImage: isNetwork ? NetworkImage(url) : null,
      child: isNetwork
          ? null
          : Text(
              member.initials,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
    );
  }
}

class _WorkspaceHero extends StatelessWidget {
  const _WorkspaceHero({
    required this.title,
    required this.description,
    required this.isSandbox,
    required this.canCreateMembers,
    this.onAddMember,
  });

  final String title;
  final String description;
  final bool isSandbox;
  final bool canCreateMembers;
  final VoidCallback? onAddMember;

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
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _ChipPill(
                icon: canCreateMembers
                    ? Icons.person_add_alt_1_outlined
                    : Icons.visibility_outlined,
                label: canCreateMembers
                    ? l10n.memberPermissionEditor
                    : l10n.memberPermissionViewer,
                backgroundColor: colorScheme.onPrimary.withValues(alpha: 0.16),
                foregroundColor: colorScheme.onPrimary,
              ),
              _ChipPill(
                icon: isSandbox
                    ? Icons.science_outlined
                    : Icons.cloud_done_outlined,
                label: isSandbox ? l10n.memberSandboxChip : l10n.memberLiveChip,
                backgroundColor: colorScheme.onPrimary.withValues(alpha: 0.16),
                foregroundColor: colorScheme.onPrimary,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            title,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: colorScheme.onPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            description,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colorScheme.onPrimary.withValues(alpha: 0.92),
            ),
          ),
          if (onAddMember != null) ...[
            const SizedBox(height: 18),
            FilledButton.icon(
              key: const Key('member-add-button'),
              onPressed: onAddMember,
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.onPrimary,
                foregroundColor: colorScheme.primary,
              ),
              icon: const Icon(Icons.person_add_alt_1_outlined),
              label: Text(l10n.memberAddAction),
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
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
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (actionLabel != null && onAction != null)
                  TextButton.icon(
                    onPressed: onAction,
                    icon: const Icon(Icons.edit_outlined),
                    label: Text(actionLabel!),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({
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
    final theme = Theme.of(context);

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
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(description, style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.items});

  final List<_StatTile> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 820 ? 3 : 1;
        return GridView.builder(
          itemCount: items.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: crossAxisCount == 1 ? 3.2 : 1.65,
          ),
          itemBuilder: (context, index) => items[index],
        );
      },
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      color: colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon),
            const SizedBox(height: 10),
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(label, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _ChipPill extends StatelessWidget {
  const _ChipPill({
    required this.icon,
    required this.label,
    this.backgroundColor,
    this.foregroundColor,
  });

  final IconData icon;
  final String label;
  final Color? backgroundColor;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor ?? colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: foregroundColor),
            const SizedBox(width: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: foregroundColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkspaceEmptyState extends StatelessWidget {
  const _WorkspaceEmptyState({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: colorScheme.secondaryContainer,
              child: Icon(icon, size: 28),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              description,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
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
            width: 132,
            child: Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

String _memberRepositoryErrorMessage(
  AppLocalizations l10n,
  MemberRepositoryErrorCode error,
) {
  return switch (error) {
    MemberRepositoryErrorCode.duplicatePhone => l10n.memberDuplicatePhoneError,
    MemberRepositoryErrorCode.permissionDenied =>
      l10n.memberPermissionDeniedError,
    MemberRepositoryErrorCode.memberNotFound => l10n.memberNotFoundDescription,
    MemberRepositoryErrorCode.avatarUploadFailed =>
      l10n.memberAvatarUploadError,
  };
}

String _genderLabel(AppLocalizations l10n, String? gender) {
  return switch (gender?.trim().toLowerCase()) {
    'male' => l10n.memberGenderMale,
    'female' => l10n.memberGenderFemale,
    'other' => l10n.memberGenderOther,
    _ => l10n.memberGenderUnspecified,
  };
}

bool _isValidIsoDateOrBlank(String? value) {
  final trimmed = value?.trim() ?? '';
  if (trimmed.isEmpty) {
    return true;
  }

  return _tryParseIsoDate(trimmed) != null;
}

DateTime? _tryParseIsoDate(String value) {
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
  if (match == null) {
    return null;
  }

  final year = int.tryParse(match.group(1)!);
  final month = int.tryParse(match.group(2)!);
  final day = int.tryParse(match.group(3)!);
  if (year == null || month == null || day == null) {
    return null;
  }

  try {
    final date = DateTime(year, month, day);
    if (date.year != year || date.month != month || date.day != day) {
      return null;
    }
    return date;
  } catch (_) {
    return null;
  }
}

String _formatIsoDate(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

String? _nullIfBlank(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
