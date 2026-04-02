import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../../../core/services/firebase_services.dart';
import '../../../core/widgets/app_compact_controls.dart';
import '../../../core/widgets/app_feedback_states.dart';
import '../../../core/widgets/address_autocomplete_field.dart';
import '../../../core/widgets/address_action_tools.dart';
import '../../../core/widgets/member_phone_action.dart';
import '../../../core/widgets/social_link_actions.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../l10n/l10n.dart';
import '../../auth/models/auth_session.dart';
import '../../auth/models/clan_context_option.dart';
import '../../auth/services/phone_number_formatter.dart';
import '../../auth/widgets/phone_country_selector_field.dart';
import '../../clan/models/branch_profile.dart';
import '../../onboarding/models/onboarding_models.dart';
import '../../onboarding/presentation/onboarding_coordinator.dart';
import '../../onboarding/presentation/onboarding_scope.dart';
import '../../relationship/presentation/relationship_inspector_panel.dart';
import '../../relationship/services/relationship_repository.dart';
import '../models/member_draft.dart';
import '../models/member_profile.dart';
import '../models/member_social_links.dart';
import '../services/member_avatar_picker.dart';
import '../services/member_search_analytics_service.dart';
import '../services/member_search_provider.dart';
import '../services/member_repository.dart';
import 'member_controller.dart';

class MemberWorkspacePage extends StatefulWidget {
  const MemberWorkspacePage({
    super.key,
    required this.session,
    required this.repository,
    this.availableClanContexts = const [],
    this.onSwitchClanContext,
    this.avatarPicker,
    this.relationshipRepository,
    this.searchProvider,
    this.searchAnalyticsService,
  });

  final AuthSession session;
  final MemberRepository repository;
  final List<ClanContextOption> availableClanContexts;
  final Future<AuthSession?> Function(String clanId)? onSwitchClanContext;
  final MemberAvatarPicker? avatarPicker;
  final RelationshipRepository? relationshipRepository;
  final MemberSearchProvider? searchProvider;
  final MemberSearchAnalyticsService? searchAnalyticsService;

  @override
  State<MemberWorkspacePage> createState() => _MemberWorkspacePageState();
}

class _MemberWorkspacePageState extends State<MemberWorkspacePage> {
  static const int _memberBatchSize = 20;

  late MemberController _controller;
  late AuthSession _activeSession;
  late final MemberAvatarPicker _avatarPicker;
  late final TextEditingController _searchController;
  late final ScrollController _scrollController;
  late RelationshipRepository _relationshipRepository;
  late final OnboardingCoordinator _onboardingCoordinator;
  int _visibleMemberCount = _memberBatchSize;
  String _memberListSeed = '';

  AuthSession get _session => _activeSession;

  @override
  void initState() {
    super.initState();
    _activeSession = widget.session;
    _controller = MemberController(
      repository: widget.repository,
      session: _session,
      searchProvider: widget.searchProvider,
      searchAnalyticsService: widget.searchAnalyticsService,
    );
    _avatarPicker = widget.avatarPicker ?? createDefaultMemberAvatarPicker();
    _relationshipRepository =
        widget.relationshipRepository ??
        createDefaultRelationshipRepository(session: _session);
    _onboardingCoordinator = createDefaultOnboardingCoordinator(
      session: _session,
    );
    _searchController = TextEditingController();
    _scrollController = ScrollController()..addListener(_handleWorkspaceScroll);
    unawaited(_initializeWorkspace());
  }

  @override
  void didUpdateWidget(covariant MemberWorkspacePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final sessionChanged = oldWidget.session != widget.session;
    final repositoryChanged = oldWidget.repository != widget.repository;
    final relationshipRepositoryChanged =
        oldWidget.relationshipRepository != widget.relationshipRepository;
    final searchProviderChanged =
        oldWidget.searchProvider != widget.searchProvider;
    final analyticsServiceChanged =
        oldWidget.searchAnalyticsService != widget.searchAnalyticsService;
    if (!sessionChanged &&
        !repositoryChanged &&
        !relationshipRepositoryChanged &&
        !searchProviderChanged &&
        !analyticsServiceChanged) {
      return;
    }
    _activeSession = widget.session;
    _controller.dispose();
    _controller = MemberController(
      repository: widget.repository,
      session: _session,
      searchProvider: widget.searchProvider,
      searchAnalyticsService: widget.searchAnalyticsService,
    );
    _onboardingCoordinator.updateSession(_session);
    _relationshipRepository =
        widget.relationshipRepository ??
        createDefaultRelationshipRepository(session: _session);
    _searchController.clear();
    unawaited(_initializeWorkspace());
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleWorkspaceScroll)
      ..dispose();
    _searchController.dispose();
    unawaited(_onboardingCoordinator.interrupt());
    _onboardingCoordinator.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _initializeWorkspace() async {
    await _controller.initialize();
    if (!mounted || !_controller.permissions.canCreateMembers) {
      return;
    }
    await _onboardingCoordinator.scheduleTrigger(
      const OnboardingTrigger(
        id: 'member_workspace_opened',
        routeId: 'member_workspace',
      ),
      delay: const Duration(milliseconds: 900),
    );
  }

  void _handleWorkspaceScroll() {
    if (!_scrollController.hasClients) {
      return;
    }
    final position = _scrollController.position;
    if (position.pixels < position.maxScrollExtent - 260) {
      return;
    }
    _loadMoreMembersIfNeeded();
  }

  void _syncVisibleMemberWindow(List<MemberProfile> members) {
    final filters = _controller.filters;
    final firstId = members.isEmpty ? '' : members.first.id;
    final lastId = members.isEmpty ? '' : members.last.id;
    final seed =
        '${members.length}|$firstId|$lastId|'
        '${filters.query.trim().toLowerCase()}|'
        '${filters.branchId ?? ''}|${filters.generation ?? ''}';
    if (seed == _memberListSeed) {
      if (_visibleMemberCount > members.length) {
        _visibleMemberCount = members.length;
      }
      return;
    }
    _memberListSeed = seed;
    _visibleMemberCount = members.length < _memberBatchSize
        ? members.length
        : _memberBatchSize;
  }

  void _loadMoreMembersIfNeeded() {
    final total = _controller.filteredMembers.length;
    if (_visibleMemberCount >= total) {
      return;
    }
    setState(() {
      final next = _visibleMemberCount + _memberBatchSize;
      _visibleMemberCount = next < total ? next : total;
    });
  }

  Future<void> _openMemberEditor({MemberProfile? member}) async {
    final createDraft = member == null
        ? await _buildCreateDraftFromPhoneLookup()
        : null;
    if (!mounted) {
      return;
    }
    if (member == null && createDraft == null) {
      return;
    }

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
          isEditing: member != null,
          editingMemberId: member?.id,
          allowOrganizationFields:
              member == null ||
              _controller.permissions.canEditOrganizationFields,
          initialDraft: member == null
              ? createDraft!
              : MemberDraft.fromProfile(member),
          branches: _controller.visibleBranches,
          members: _controller.members,
          canAssignRoleManually:
              member == null && _controller.canAssignRoleManually,
          assignableRoles: _controller.assignableCreateRoles,
          resolveAutoRole: _controller.resolveAutoRoleForDraft,
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

  Future<MemberDraft?> _buildCreateDraftFromPhoneLookup() async {
    final l10n = context.l10n;
    final baseDraft = MemberDraft.empty(
      defaultBranchId: _controller.permissions.restrictedBranchId,
    );
    final phoneInput = await showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _MemberPhoneLookupSheet(),
    );
    if (phoneInput == null) {
      return null;
    }

    final trimmedPhone = phoneInput.trim();
    if (trimmedPhone.isEmpty) {
      return baseDraft;
    }

    final normalizedPhone = PhoneNumberFormatter.tryParseE164(trimmedPhone);
    if (normalizedPhone == null) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)
          ?..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                l10n.pick(
                  vi: 'Số điện thoại chưa đúng định dạng.',
                  en: 'Invalid phone number format.',
                ),
              ),
            ),
          );
      }
      return baseDraft;
    }
    MemberProfile? existingInClan;
    for (final candidate in _controller.members) {
      if (PhoneNumberFormatter.areEquivalent(
        candidate.phoneE164,
        normalizedPhone,
      )) {
        existingInClan = candidate;
        break;
      }
    }
    if (existingInClan != null) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)
          ?..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                l10n.pick(
                  vi: 'Số điện thoại này đã có trong gia phả hiện tại. Mở chế độ chỉnh sửa hồ sơ.',
                  en: 'This phone already exists in the current genealogy. Opening edit mode.',
                ),
              ),
            ),
          );
      }
      await _openMemberEditor(member: existingInClan);
      return null;
    }

    final profile = await _lookupGlobalMemberProfileByPhone(normalizedPhone);
    if (profile == null) {
      return baseDraft.copyWith(phoneInput: normalizedPhone);
    }

    if (mounted) {
      ScaffoldMessenger.maybeOf(context)
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              l10n.pick(
                vi: 'Đã tìm thấy hồ sơ trong BeFam. Hệ thống đã tự điền thông tin, bạn chỉ cần cập nhật "Con của".',
                en: 'A BeFam profile was found. We prefilled the form, you only need to choose "Child of".',
              ),
            ),
          ),
        );
    }
    return _memberDraftFromLookupProfile(
      baseDraft: baseDraft,
      profile: profile,
      phoneE164: normalizedPhone,
    );
  }

  Future<Map<String, dynamic>?> _lookupGlobalMemberProfileByPhone(
    String phoneE164,
  ) async {
    try {
      final callable = FirebaseServices.functions.httpsCallable(
        'lookupMemberProfileByPhone',
      );
      final response = await callable.call(<String, dynamic>{
        'phoneE164': phoneE164,
      });
      final payload = _asStringKeyMap(response.data);
      if (payload['found'] != true) {
        return null;
      }
      final profile = _asStringKeyMap(payload['profile']);
      return profile.isEmpty ? null : profile;
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) {
        return null;
      }
      final l10n = context.l10n;
      final message = switch (error.code) {
        'permission-denied' => l10n.pick(
          vi: 'Tài khoản hiện tại chưa đủ quyền tra cứu toàn hệ thống. Bạn vẫn có thể tạo mới thủ công.',
          en: 'This account is not allowed to search across the whole system yet. You can still create manually.',
        ),
        'unimplemented' => l10n.pick(
          vi: 'Máy chủ chưa bật tra cứu toàn hệ thống. Bạn vẫn có thể tạo mới thủ công.',
          en: 'Global profile lookup is not enabled on the server yet. You can still create manually.',
        ),
        _ => l10n.pick(
          vi: 'Không thể tra cứu hồ sơ toàn hệ thống lúc này. Bạn vẫn có thể tạo mới thủ công.',
          en: 'Unable to lookup global profiles right now. You can still create manually.',
        ),
      };
      ScaffoldMessenger.maybeOf(context)
        ?..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
      return null;
    } catch (_) {
      return null;
    }
  }

  MemberDraft _memberDraftFromLookupProfile({
    required MemberDraft baseDraft,
    required Map<String, dynamic> profile,
    required String phoneE164,
  }) {
    final socialLinks = _asStringKeyMap(profile['socialLinks']);
    final generation = _asPositiveInt(profile['generation'], fallback: 1);
    return baseDraft.copyWith(
      fullName: _asTrimmedString(profile['fullName']),
      nickName: _asTrimmedString(profile['nickName']),
      gender: _nullIfBlank(_asTrimmedString(profile['gender'])),
      birthDate: _nullIfBlank(_asTrimmedString(profile['birthDate'])),
      deathDate: _nullIfBlank(_asTrimmedString(profile['deathDate'])),
      phoneInput:
          PhoneNumberFormatter.tryParseE164(
            _asTrimmedString(profile['phoneE164'], fallback: phoneE164),
          ) ??
          phoneE164,
      email: _asTrimmedString(profile['email']),
      addressText: _asTrimmedString(profile['addressText']),
      jobTitle: _asTrimmedString(profile['jobTitle']),
      bio: _asTrimmedString(profile['bio']),
      generation: generation,
      socialLinks: MemberSocialLinks(
        facebook: _nullIfBlank(_asTrimmedString(socialLinks['facebook'])),
        zalo: _nullIfBlank(_asTrimmedString(socialLinks['zalo'])),
        linkedin: _nullIfBlank(_asTrimmedString(socialLinks['linkedin'])),
      ),
      isMinor: profile['isMinor'] == true,
    );
  }

  void _openMemberDetail(MemberProfile member) {
    _controller.trackMemberOpened(member);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) {
          return _MemberDetailPage(
            controller: _controller,
            session: _session,
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
        final hasActiveFilters =
            _controller.filters.query.trim().isNotEmpty ||
            _controller.filters.branchId != null ||
            _controller.filters.generation != null;
        final filteredMembers = _controller.filteredMembers;
        _syncVisibleMemberWindow(filteredMembers);
        final visibleMembers = filteredMembers
            .take(_visibleMemberCount)
            .toList(growable: false);
        final hasMoreMembers = visibleMembers.length < filteredMembers.length;

        final scaffold = Scaffold(
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
          floatingActionButton: _controller.permissions.canCreateMembers
              ? OnboardingAnchor(
                  anchorId: 'member.add_fab',
                  child: FloatingActionButton(
                    key: const Key('member-add-fab'),
                    onPressed: _openMemberEditor,
                    tooltip: l10n.memberAddAction,
                    child: const Icon(Icons.add),
                  ),
                )
              : null,
          body: SafeArea(
            child: _controller.isLoading
                ? AppLoadingState(
                    message: l10n.pick(
                      vi: 'Đang tải không gian thành viên...',
                      en: 'Loading member workspace...',
                    ),
                  )
                : !_controller.hasClanContext
                ? _WorkspaceEmptyState(
                    icon: Icons.lock_outline,
                    title: l10n.memberNoContextTitle,
                    description: l10n.memberNoContextDescription,
                  )
                : RefreshIndicator(
                    onRefresh: _controller.refresh,
                    child: ListView(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                      children: [
                        _WorkspaceHero(
                          title: l10n.memberWorkspaceHeroTitle,
                          description: l10n.pick(
                            vi: 'Quản lý và cập nhật hồ sơ thành viên theo chi và đời.',
                            en: 'Manage and update member profiles by branch and generation.',
                          ),
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
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: _controller.refresh,
                              icon: const Icon(Icons.refresh),
                              label: Text(l10n.memberRefreshAction),
                            ),
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
                              value: '${filteredMembers.length}',
                              icon: Icons.filter_alt_outlined,
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        if (_controller.selfMember case final selfMember?) ...[
                          Text(
                            l10n.memberOwnProfileTitle,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _MemberSummaryCard(
                            member: selfMember,
                            branchName: _controller.branchName(
                              selfMember.branchId,
                            ),
                            roleLabel: l10n.roleLabel(selfMember.primaryRole),
                            showRoleBadge: true,
                            onTap: () => _openMemberDetail(selfMember),
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
                        Text(
                          l10n.memberListSectionTitle,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _controller.isSearching
                            ? _SearchStateCard(
                                key: const Key('member-search-loading-state'),
                                icon: Icons.search,
                                title: l10n.memberSearchLabel,
                                description: l10n.memberSearchHint,
                                trailing: const Padding(
                                  padding: EdgeInsets.only(top: 4),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            : _controller.searchError != null
                            ? _SearchStateCard(
                                key: const Key('member-search-error-state'),
                                icon: Icons.wifi_tethering_error_outlined,
                                title: l10n.memberLoadErrorTitle,
                                description: l10n.memberLoadErrorDescription,
                                trailing: TextButton.icon(
                                  key: const Key('member-search-retry-action'),
                                  onPressed: _controller.retrySearch,
                                  icon: const Icon(Icons.refresh),
                                  label: Text(l10n.memberRefreshAction),
                                ),
                              )
                            : filteredMembers.isEmpty
                            ? _SearchStateCard(
                                key: const Key('member-search-empty-state'),
                                icon: Icons.person_search_outlined,
                                title: hasActiveFilters
                                    ? l10n.memberSearchLabel
                                    : l10n.memberListEmptyTitle,
                                description: hasActiveFilters
                                    ? l10n.memberSearchHint
                                    : l10n.memberListEmptyDescription,
                                trailing: hasActiveFilters
                                    ? TextButton.icon(
                                        onPressed: () {
                                          _searchController.clear();
                                          _controller.updateSearchQuery('');
                                          _controller.updateBranchFilter(null);
                                          _controller.updateGenerationFilter(
                                            null,
                                          );
                                        },
                                        icon: const Icon(
                                          Icons.filter_alt_off_outlined,
                                        ),
                                        label: Text(
                                          l10n.memberClearFiltersAction,
                                        ),
                                      )
                                    : null,
                              )
                            : Column(
                                children: [
                                  for (final member in visibleMembers)
                                    Padding(
                                      padding: EdgeInsets.only(
                                        bottom: member == visibleMembers.last
                                            ? 0
                                            : 14,
                                      ),
                                      child: KeyedSubtree(
                                        key: Key(
                                          'member-search-result-${member.id}',
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
                                          showRoleBadge:
                                              member.primaryRole
                                                  .trim()
                                                  .toUpperCase() !=
                                              'MEMBER',
                                          highlightQuery:
                                              _controller.filters.query,
                                          onTap: () =>
                                              _openMemberDetail(member),
                                        ),
                                      ),
                                    ),
                                  if (hasMoreMembers) ...[
                                    const SizedBox(height: 14),
                                    _SearchStateCard(
                                      icon: Icons.unfold_more_outlined,
                                      title: l10n.pick(
                                        vi: 'Đang tải thêm thành viên',
                                        en: 'Loading more members',
                                      ),
                                      description: l10n.pick(
                                        vi: 'Đã hiển thị ${visibleMembers.length}/${filteredMembers.length}. Kéo xuống để tải thêm.',
                                        en: 'Showing ${visibleMembers.length}/${filteredMembers.length}. Scroll down to load more.',
                                      ),
                                      trailing: TextButton.icon(
                                        onPressed: _loadMoreMembersIfNeeded,
                                        icon: const Icon(Icons.expand_more),
                                        label: Text(
                                          l10n.pick(
                                            vi: 'Tải thêm',
                                            en: 'Load more',
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                      ],
                    ),
                  ),
          ),
        );
        return OnboardingScope(
          controller: _onboardingCoordinator,
          child: scaffold,
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
      SnackBar(
        content: Text(
          _memberRepositoryErrorMessage(
            l10n,
            error.code,
            overrideMessage: error.message,
          ),
        ),
      ),
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
        final siblingOrder = member == null
            ? null
            : _resolveSiblingOrder(member);
        final siblingOrderLabel = _siblingOrderLabel(l10n, siblingOrder);

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
            ],
          ),
          floatingActionButton:
              member != null && controller.canEditMember(member)
              ? FloatingActionButton(
                  key: const Key('member-edit-fab'),
                  onPressed: () => onEditMember(member: member),
                  child: const Icon(Icons.edit_outlined),
                )
              : null,
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
                                          label: l10n.pick(
                                            vi: 'Đời thứ ${member.generation}',
                                            en: 'Generation ${member.generation}',
                                          ),
                                        ),
                                        _ChipPill(
                                          icon: Icons.verified_user_outlined,
                                          label: l10n.roleLabel(
                                            member.primaryRole,
                                          ),
                                        ),
                                        if (siblingOrderLabel != null)
                                          _ChipPill(
                                            icon: Icons.format_list_numbered,
                                            label: siblingOrderLabel,
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
                              trailing: MemberPhoneActionIconButton(
                                phoneNumber: member.phoneE164 ?? '',
                                contactName: member.displayName,
                              ),
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
                              label: l10n.pick(
                                vi: 'Thứ bậc anh/chị/em',
                                en: 'Sibling order',
                              ),
                              value: siblingOrderLabel ?? l10n.memberFieldUnset,
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
                              trailing: AddressDirectionIconButton(
                                address: member.addressText ?? '',
                                label: member.displayName,
                              ),
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
                                      if (member.socialLinks.facebook != null)
                                        SocialLinkActionIconButton(
                                          platform: SocialPlatform.facebook,
                                          rawValue:
                                              member.socialLinks.facebook!,
                                        ),
                                      if (member.socialLinks.zalo != null)
                                        SocialLinkActionIconButton(
                                          platform: SocialPlatform.zalo,
                                          rawValue: member.socialLinks.zalo!,
                                        ),
                                      if (member.socialLinks.linkedin != null)
                                        SocialLinkActionIconButton(
                                          platform: SocialPlatform.linkedin,
                                          rawValue:
                                              member.socialLinks.linkedin!,
                                        ),
                                    ],
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
                        onOpenMemberDetail: (linkedMember) {
                          if (linkedMember.id == member.id) {
                            return;
                          }
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (context) {
                                return _MemberDetailPage(
                                  controller: controller,
                                  session: session,
                                  memberId: linkedMember.id,
                                  avatarPicker: avatarPicker,
                                  relationshipRepository:
                                      relationshipRepository,
                                  onEditMember: onEditMember,
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }

  int? _resolveSiblingOrder(MemberProfile member) {
    final directOrder = member.siblingOrder;
    if (directOrder != null && directOrder > 0) {
      return directOrder;
    }

    final parentIds = member.parentIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
    if (parentIds.isEmpty) {
      return null;
    }

    final siblings = <MemberProfile>[];
    for (final candidate in controller.members) {
      if (candidate.id == member.id) {
        siblings.add(candidate);
        continue;
      }
      final hasSharedParent = _sharesSiblingParents(
        referenceParentIds: parentIds,
        candidateParentIds: candidate.parentIds,
      );
      if (hasSharedParent) {
        siblings.add(candidate);
      }
    }
    siblings.sort(_compareMembersBySeniority);
    final index = siblings.indexWhere((entry) => entry.id == member.id);
    if (index < 0) {
      return null;
    }
    return index + 1;
  }
}

class _MemberPhoneLookupSheet extends StatefulWidget {
  const _MemberPhoneLookupSheet();

  @override
  State<_MemberPhoneLookupSheet> createState() =>
      _MemberPhoneLookupSheetState();
}

class _MemberPhoneLookupSheetState extends State<_MemberPhoneLookupSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _phoneController;
  late String _selectedCountryIsoCode;
  bool _resolvedAutoCountry = false;

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController();
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
    _phoneController.dispose();
    super.dispose();
  }

  void _normalizePhoneInputForCountry() {
    final normalized = PhoneNumberFormatter.toNationalInput(
      _phoneController.text,
      defaultCountryIso: _selectedCountryIsoCode,
    );
    if (normalized == _phoneController.text.trim()) {
      return;
    }
    _phoneController
      ..text = normalized
      ..selection = TextSelection.collapsed(offset: normalized.length);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    _normalizePhoneInputForCountry();
    final trimmed = _phoneController.text.trim();
    if (trimmed.isEmpty) {
      Navigator.of(context).pop('');
      return;
    }
    final normalized = PhoneNumberFormatter.parse(
      trimmed,
      defaultCountryIso: _selectedCountryIsoCode,
    ).e164;
    Navigator.of(context).pop(normalized);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final insets = MediaQuery.viewInsetsOf(context);
    final phoneHint = PhoneNumberFormatter.nationalNumberHint(
      _selectedCountryIsoCode,
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
                  l10n.pick(
                    vi: 'Nhập số điện thoại trước',
                    en: 'Enter phone number first',
                  ),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  l10n.pick(
                    vi: 'BeFam sẽ kiểm tra toàn hệ thống. Nếu đã có hồ sơ, hệ thống tự điền thông tin để bạn chỉ cần chọn "Con của".',
                    en: 'BeFam will search the whole system. If a profile exists, we will prefill details so you only need to choose "Child of".',
                  ),
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PhoneCountrySelectorField(
                      selectedIsoCode: _selectedCountryIsoCode,
                      onChanged: (value) {
                        setState(() {
                          _selectedCountryIsoCode = value;
                          _normalizePhoneInputForCountry();
                        });
                      },
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        key: const Key('member-phone-lookup-input'),
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.done,
                        decoration: InputDecoration(
                          labelText: l10n.memberPhoneLabel,
                          hintText: phoneHint,
                        ),
                        onEditingComplete: _normalizePhoneInputForCountry,
                        onFieldSubmitted: (_) => _submit(),
                        validator: (value) {
                          final trimmed = value?.trim() ?? '';
                          if (trimmed.isEmpty) {
                            return null;
                          }
                          try {
                            PhoneNumberFormatter.parse(
                              trimmed,
                              defaultCountryIso: _selectedCountryIsoCode,
                            );
                            return null;
                          } catch (_) {
                            return l10n.pick(
                              vi: 'Số điện thoại chưa đúng định dạng.',
                              en: 'Invalid phone number format.',
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 520;
                    final cancelButton = OutlinedButton(
                      key: const Key('member-phone-lookup-cancel'),
                      onPressed: () => Navigator.of(context).pop<String?>(null),
                      child: Text(l10n.pick(vi: 'Hủy', en: 'Cancel')),
                    );
                    final skipButton = OutlinedButton(
                      key: const Key('member-phone-lookup-skip'),
                      onPressed: () => Navigator.of(context).pop(''),
                      child: Text(
                        l10n.pick(
                          vi: 'Tạo mới thủ công',
                          en: 'Create manually',
                        ),
                      ),
                    );
                    final continueButton = FilledButton.icon(
                      key: const Key('member-phone-lookup-continue'),
                      onPressed: _submit,
                      icon: const Icon(Icons.search),
                      label: Text(l10n.pick(vi: 'Tiếp tục', en: 'Continue')),
                    );

                    if (compact) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(child: cancelButton),
                              const SizedBox(width: 10),
                              Expanded(child: skipButton),
                            ],
                          ),
                          const SizedBox(height: 10),
                          continueButton,
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(child: cancelButton),
                        const SizedBox(width: 10),
                        Expanded(child: skipButton),
                        const SizedBox(width: 10),
                        Expanded(child: continueButton),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MemberEditorSheet extends StatefulWidget {
  const _MemberEditorSheet({
    required this.title,
    required this.isEditing,
    required this.editingMemberId,
    required this.allowOrganizationFields,
    required this.initialDraft,
    required this.branches,
    required this.members,
    required this.canAssignRoleManually,
    required this.assignableRoles,
    required this.resolveAutoRole,
    required this.isSaving,
    required this.onSubmit,
  });

  final String title;
  final bool isEditing;
  final String? editingMemberId;
  final bool allowOrganizationFields;
  final MemberDraft initialDraft;
  final List<BranchProfile> branches;
  final List<MemberProfile> members;
  final bool canAssignRoleManually;
  final List<String> assignableRoles;
  final String Function(MemberDraft draft) resolveAutoRole;
  final bool isSaving;
  final Future<MemberRepositoryException?> Function(MemberDraft draft) onSubmit;

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
  String? _selectedFatherId;
  String? _selectedMotherId;
  String? _gender;
  late String _phoneCountryIsoCode;
  String? _selectedPrimaryRole;
  MemberRepositoryException? _submitError;
  bool _isSubmitting = false;
  int _editorStep = 0;
  bool _resolvedAutoPhoneCountry = false;

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
    _seedInitialParentSelection(widget.initialDraft.parentIds);
    _gender = widget.initialDraft.gender;
    final initialRole = widget.initialDraft.primaryRole.trim().toUpperCase();
    if (widget.assignableRoles.contains(initialRole)) {
      _selectedPrimaryRole = initialRole;
    } else if (widget.assignableRoles.isNotEmpty) {
      _selectedPrimaryRole = widget.assignableRoles.first;
    } else {
      _selectedPrimaryRole = 'MEMBER';
    }
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

    setState(() {
      controller.text = _formatIsoDate(picked);
      if (identical(controller, _birthDateController)) {
        _syncParentSelectionWithBirthDate();
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    _normalizePhoneInputForCountry();

    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });

    final baseDraft = _composeDraft(
      primaryRole: _selectedPrimaryRole ?? widget.initialDraft.primaryRole,
    );
    final resolvedPrimaryRole = widget.isEditing
        ? widget.initialDraft.primaryRole
        : widget.canAssignRoleManually
        ? baseDraft.primaryRole
        : widget.resolveAutoRole(baseDraft);
    final draftToSave = baseDraft.copyWith(primaryRole: resolvedPrimaryRole);
    final error = await widget.onSubmit(draftToSave);

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
    final selectedParent = _primarySelectedParent;
    final selectedParentBranchName = _branchNameById(selectedParent?.branchId);
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
                      _submitError!.code,
                      overrideMessage: _submitError!.message,
                    ),
                    tone: theme.colorScheme.errorContainer,
                  ),
                ],
                const SizedBox(height: 20),
                _MemberEditorStepIndicator(
                  currentStep: _editorStep,
                  labels: [
                    l10n.pick(vi: 'Thông tin', en: 'Info'),
                    l10n.pick(vi: 'Quan hệ', en: 'Relation'),
                    l10n.pick(vi: 'Bổ sung', en: 'More'),
                  ],
                  onStepSelected: (step) {
                    setState(() => _editorStep = step);
                  },
                ),
                const SizedBox(height: 16),
                if (_editorStep == 0) ...[
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
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxWidth < 520;
                      final birthDateField = TextFormField(
                        key: const Key('member-birth-date-input'),
                        controller: _birthDateController,
                        decoration: InputDecoration(
                          labelText: l10n.memberBirthDateLabel,
                          hintText: l10n.pick(
                            vi: 'YYYY-MM-DD',
                            en: 'YYYY-MM-DD',
                          ),
                          suffixIcon: IconButton(
                            tooltip: l10n.pick(
                              vi: 'Chọn ngày sinh',
                              en: 'Select birth date',
                            ),
                            onPressed: () => _pickDate(_birthDateController),
                            icon: const Icon(Icons.calendar_today_outlined),
                          ),
                        ),
                        validator: (value) {
                          return _isValidIsoDateOrBlank(value)
                              ? null
                              : l10n.memberValidationDateInvalid;
                        },
                        onChanged: (_) =>
                            setState(_syncParentSelectionWithBirthDate),
                      );
                      final deathDateField = TextFormField(
                        key: const Key('member-death-date-input'),
                        controller: _deathDateController,
                        decoration: InputDecoration(
                          labelText: l10n.memberDeathDateLabel,
                          hintText: l10n.pick(
                            vi: 'YYYY-MM-DD',
                            en: 'YYYY-MM-DD',
                          ),
                          suffixIcon: IconButton(
                            tooltip: l10n.pick(
                              vi: 'Chọn ngày mất',
                              en: 'Select death date',
                            ),
                            onPressed: () => _pickDate(_deathDateController),
                            icon: const Icon(Icons.calendar_today_outlined),
                          ),
                        ),
                        validator: (value) {
                          return _isValidIsoDateOrBlank(value)
                              ? null
                              : l10n.memberValidationDateInvalid;
                        },
                      );
                      if (compact) {
                        return Column(
                          children: [
                            birthDateField,
                            const SizedBox(height: 14),
                            deathDateField,
                          ],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(child: birthDateField),
                          const SizedBox(width: 14),
                          Expanded(child: deathDateField),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PhoneCountrySelectorField(
                        selectedIsoCode: _phoneCountryIsoCode,
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
                          key: const Key('member-phone-input'),
                          controller: _phoneController,
                          decoration: InputDecoration(
                            labelText: l10n.memberPhoneLabel,
                            hintText: phoneHint,
                          ),
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.next,
                          onEditingComplete: _normalizePhoneInputForCountry,
                          validator: (value) {
                            final trimmed = value?.trim() ?? '';
                            if (trimmed.isEmpty) {
                              return l10n.pick(
                                vi: 'Hãy nhập số điện thoại.',
                                en: 'Please enter a phone number.',
                              );
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
                ],
                if (_editorStep == 1) ...[
                  const SizedBox(height: 14),
                  if (widget.isEditing)
                    DropdownButtonFormField<String>(
                      key: const Key('member-branch-input'),
                      isExpanded: true,
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
                    )
                  else
                    FormField<List<String>>(
                      key: const Key('member-parent-input'),
                      initialValue: _resolvedParentIds,
                      validator: (_) {
                        if (_parentCandidates.isEmpty) {
                          return null;
                        }
                        return _resolvedParentIds.isEmpty
                            ? l10n.pick(
                                vi: 'Hãy chọn cha/mẹ để hệ thống tự gán chi và thứ bậc anh/chị/em.',
                                en: 'Choose parents so the system can auto-assign branch and sibling order.',
                              )
                            : null;
                      },
                      builder: (field) {
                        final father = _selectedFather;
                        final mother = _selectedMother;
                        return InputDecorator(
                          decoration: InputDecoration(
                            labelText: l10n.pick(vi: 'Con của', en: 'Child of'),
                            errorText: field.errorText,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  key: const Key('member-parent-picker-button'),
                                  onPressed: _parentCandidates.isEmpty
                                      ? null
                                      : () async {
                                          final result =
                                              await _pickParentsFromBottomSheet();
                                          if (!mounted || result == null) {
                                            return;
                                          }
                                          setState(() {
                                            _selectedFatherId = result.fatherId;
                                            _selectedMotherId = result.motherId;
                                            _autofillPhoneFromSelectedFather();
                                          });
                                          field.didChange(_resolvedParentIds);
                                          _formKey.currentState?.validate();
                                        },
                                  icon: const Icon(
                                    Icons.family_restroom_outlined,
                                  ),
                                  label: Text(_parentPickerButtonLabel(l10n)),
                                ),
                              ),
                              if (father != null || mother != null) ...[
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    if (father != null)
                                      _ParentRoleBadge(
                                        icon: Icons.male,
                                        roleLabel: l10n.pick(
                                          vi: 'Cha',
                                          en: 'Father',
                                        ),
                                        memberName: father.displayName,
                                      ),
                                    if (mother != null)
                                      _ParentRoleBadge(
                                        icon: Icons.female,
                                        roleLabel: l10n.pick(
                                          vi: 'Mẹ',
                                          en: 'Mother',
                                        ),
                                        memberName: mother.displayName,
                                      ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String?>(
                    key: const Key('member-gender-input'),
                    isExpanded: true,
                    initialValue: _gender,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w400,
                    ),
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
                  if (!widget.isEditing) ...[
                    const SizedBox(height: 14),
                    InputDecorator(
                      key: const Key('member-branch-auto-input'),
                      decoration: InputDecoration(
                        labelText: l10n.memberBranchLabel,
                      ),
                      child: Text(
                        selectedParent == null
                            ? l10n.pick(
                                vi: 'Trống (sẽ hiển thị sau khi chọn cha/mẹ)',
                                en: 'Empty (will be shown after choosing parents)',
                              )
                            : selectedParentBranchName,
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (widget.canAssignRoleManually)
                      DropdownButtonFormField<String>(
                        key: const Key('member-role-input'),
                        isExpanded: true,
                        initialValue: _selectedPrimaryRole,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w400,
                        ),
                        decoration: InputDecoration(
                          labelText: l10n.pick(vi: 'Vai trò', en: 'Role'),
                        ),
                        items: [
                          for (final role in widget.assignableRoles)
                            DropdownMenuItem<String>(
                              value: role,
                              child: Text(l10n.roleLabel(role)),
                            ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedPrimaryRole = value;
                          });
                        },
                        validator: (value) {
                          return value == null || value.trim().isEmpty
                              ? l10n.pick(
                                  vi: 'Hãy chọn vai trò cho thành viên.',
                                  en: 'Please choose a role for this member.',
                                )
                              : null;
                        },
                      )
                    else
                      InputDecorator(
                        key: const Key('member-role-auto-input'),
                        decoration: InputDecoration(
                          labelText: l10n.pick(vi: 'Vai trò', en: 'Role'),
                        ),
                        child: Text(
                          l10n.roleLabel(_autoResolvedRole),
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    const SizedBox(height: 14),
                    InputDecorator(
                      key: const Key('member-sibling-order-auto-input'),
                      decoration: InputDecoration(
                        labelText: l10n.pick(
                          vi: 'Thứ bậc anh/chị/em',
                          en: 'Sibling order',
                        ),
                      ),
                      child: Text(
                        _siblingOrderLabel(l10n, _predictedSiblingOrder) ??
                            l10n.pick(
                              vi: 'Chọn cha/mẹ để hệ thống tự tính.',
                              en: 'Choose parents for auto calculation.',
                            ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    InputDecorator(
                      key: const Key('member-sibling-list-auto-input'),
                      decoration: InputDecoration(
                        labelText: l10n.pick(
                          vi: 'Anh/chị/em ruột',
                          en: 'Biological siblings',
                        ),
                      ),
                      child: _siblingCandidates.isEmpty
                          ? Text(
                              l10n.pick(
                                vi: 'Chưa có dữ liệu anh/chị/em ruột.',
                                en: 'No biological siblings found.',
                              ),
                            )
                          : Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final sibling in _siblingCandidates)
                                  _ChipPill(
                                    icon: Icons.person_outline,
                                    label: sibling.displayName,
                                    compact: true,
                                  ),
                              ],
                            ),
                    ),
                  ],
                ],
                if (_editorStep == 2) ...[
                  const SizedBox(height: 14),
                  TextFormField(
                    key: const Key('member-email-input'),
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: l10n.memberEmailLabel,
                      hintText: l10n.pick(
                        vi: 'member@befam.vn',
                        en: 'member@befam.vn',
                      ),
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
                  AddressAutocompleteField(
                    key: const Key('member-address-input'),
                    controller: _addressController,
                    labelText: l10n.memberAddressLabel,
                    hintText: l10n.memberAddressHint,
                    textInputAction: TextInputAction.next,
                    maxLines: 2,
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
                    key: const Key('member-facebook-input'),
                    controller: _facebookController,
                    decoration: InputDecoration(
                      labelText: l10n.pick(vi: 'Facebook', en: 'Facebook'),
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
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    key: const Key('member-zalo-input'),
                    controller: _zaloController,
                    decoration: InputDecoration(
                      labelText: l10n.pick(vi: 'Zalo', en: 'Zalo'),
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
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    key: const Key('member-linkedin-input'),
                    controller: _linkedinController,
                    decoration: InputDecoration(
                      labelText: l10n.pick(vi: 'LinkedIn', en: 'LinkedIn'),
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
                ],
                const SizedBox(height: 22),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 520;
                    final backButton = OutlinedButton.icon(
                      onPressed: (_isSubmitting || widget.isSaving)
                          ? null
                          : () {
                              setState(() {
                                _editorStep = (_editorStep - 1).clamp(0, 2);
                              });
                            },
                      icon: const Icon(Icons.arrow_back),
                      label: Text(l10n.pick(vi: 'Quay lại', en: 'Back')),
                    );
                    final saveDraftButton = OutlinedButton.icon(
                      onPressed: (_isSubmitting || widget.isSaving)
                          ? null
                          : () => Navigator.of(context).pop(false),
                      icon: const Icon(Icons.save_as_outlined),
                      label: Text(l10n.pick(vi: 'Lưu nháp', en: 'Save draft')),
                    );
                    final continueOrSaveButton = _editorStep < 2
                        ? FilledButton.icon(
                            onPressed: (_isSubmitting || widget.isSaving)
                                ? null
                                : () {
                                    if (_editorStep == 0 &&
                                        (_fullNameController.text
                                            .trim()
                                            .isEmpty)) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            l10n.pick(
                                              vi: 'Thiếu thông tin: Cần nhập họ và tên.',
                                              en: 'Missing info: Please enter full name.',
                                            ),
                                          ),
                                        ),
                                      );
                                      return;
                                    }
                                    setState(() {
                                      _editorStep = (_editorStep + 1).clamp(
                                        0,
                                        2,
                                      );
                                    });
                                  },
                            icon: const Icon(Icons.arrow_forward),
                            label: Text(
                              l10n.pick(vi: 'Tiếp tục', en: 'Continue'),
                            ),
                          )
                        : FilledButton.icon(
                            key: const Key('member-save-button'),
                            onPressed: (_isSubmitting || widget.isSaving)
                                ? null
                                : _submit,
                            icon: (_isSubmitting || widget.isSaving)
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.save_outlined),
                            label: Text(l10n.memberSaveAction),
                          );

                    if (compact) {
                      return Column(
                        children: [
                          Row(
                            children: [
                              if (_editorStep > 0) ...[
                                Expanded(child: backButton),
                                const SizedBox(width: 10),
                              ],
                              Expanded(child: saveDraftButton),
                            ],
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: continueOrSaveButton,
                          ),
                        ],
                      );
                    }

                    return Row(
                      children: [
                        if (_editorStep > 0) ...[
                          Expanded(child: backButton),
                          const SizedBox(width: 10),
                        ],
                        Expanded(child: saveDraftButton),
                        const SizedBox(width: 10),
                        Expanded(child: continueOrSaveButton),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  MemberDraft _composeDraft({required String primaryRole}) {
    return MemberDraft(
      branchId: _resolvedBranchId,
      parentIds: _resolvedParentIds,
      fullName: _fullNameController.text.trim(),
      nickName: _nickNameController.text.trim(),
      gender: _gender,
      birthDate: _nullIfBlank(_birthDateController.text),
      deathDate: _nullIfBlank(_deathDateController.text),
      phoneInput: _normalizedPhoneDraftInput,
      email: _emailController.text.trim(),
      addressText: _addressController.text.trim(),
      jobTitle: _jobTitleController.text.trim(),
      bio: _bioController.text.trim(),
      siblingOrder: _predictedSiblingOrder,
      generation: _resolvedGeneration,
      socialLinks: MemberSocialLinks(
        facebook: normalizeSocialLinkForStorage(
          SocialPlatform.facebook,
          _facebookController.text,
        ),
        zalo: normalizeSocialLinkForStorage(
          SocialPlatform.zalo,
          _zaloController.text,
        ),
        linkedin: normalizeSocialLinkForStorage(
          SocialPlatform.linkedin,
          _linkedinController.text,
        ),
      ),
      primaryRole: primaryRole,
      status: widget.initialDraft.status,
      isMinor: widget.initialDraft.isMinor,
    );
  }

  String get _autoResolvedRole {
    final previewDraft = _composeDraft(primaryRole: 'MEMBER');
    return widget.resolveAutoRole(previewDraft);
  }

  String get _normalizedPhoneDraftInput {
    final trimmed = _phoneController.text.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    final normalized = PhoneNumberFormatter.tryParseE164(
      trimmed,
      defaultCountryIso: _phoneCountryIsoCode,
    );
    return normalized ?? trimmed;
  }

  MemberProfile? get _selectedFather => _memberById(_selectedFatherId);

  MemberProfile? get _selectedMother => _memberById(_selectedMotherId);

  MemberProfile? get _primarySelectedParent =>
      _selectedFather ?? _selectedMother;

  void _seedInitialParentSelection(List<String> parentIds) {
    final normalizedIds = parentIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
    if (normalizedIds.isEmpty) {
      return;
    }

    final unresolved = <String>[];
    for (final parentId in normalizedIds) {
      final member = _memberById(parentId);
      if (_selectedFatherId == null && _isMaleGenderValue(member?.gender)) {
        _selectedFatherId = parentId;
        continue;
      }
      if (_selectedMotherId == null && _isFemaleGenderValue(member?.gender)) {
        _selectedMotherId = parentId;
        continue;
      }
      unresolved.add(parentId);
    }

    for (final parentId in unresolved) {
      if (_selectedFatherId == null) {
        _selectedFatherId = parentId;
        continue;
      }
      if (_selectedMotherId == null && parentId != _selectedFatherId) {
        _selectedMotherId = parentId;
        break;
      }
    }
  }

  String _parentPickerButtonLabel(AppLocalizations l10n) {
    final father = _selectedFather;
    final mother = _selectedMother;
    if (father == null && mother == null) {
      return l10n.pick(
        vi: 'Chọn cha/mẹ hoặc người giám hộ',
        en: 'Choose father/mother or guardian',
      );
    }
    if (father != null && mother != null) {
      return l10n.pick(
        vi: 'Cha: ${father.displayName} · Mẹ: ${mother.displayName}',
        en: 'Father: ${father.displayName} · Mother: ${mother.displayName}',
      );
    }
    if (father != null) {
      return l10n.pick(
        vi: 'Cha: ${father.displayName}',
        en: 'Father: ${father.displayName}',
      );
    }
    final resolvedMother = mother;
    if (resolvedMother == null) {
      return l10n.pick(
        vi: 'Chọn cha/mẹ hoặc người giám hộ',
        en: 'Choose father/mother or guardian',
      );
    }
    return l10n.pick(
      vi: 'Mẹ: ${resolvedMother.displayName}',
      en: 'Mother: ${resolvedMother.displayName}',
    );
  }

  Future<_ParentSelectionResult?> _pickParentsFromBottomSheet() async {
    final l10n = context.l10n;
    final sourceMembers = _parentCandidates;
    if (sourceMembers.isEmpty) {
      return null;
    }
    final childBirthDate = _draftBirthDate;

    final maleCandidates = sourceMembers
        .where((member) => _isMaleGenderValue(member.gender))
        .toList(growable: false);
    final femaleCandidates = sourceMembers
        .where((member) => _isFemaleGenderValue(member.gender))
        .toList(growable: false);
    String? fatherId = _selectedFatherId;
    String? motherId = _selectedMotherId;
    var query = '';

    MemberProfile? resolveMemberById(String? memberId) {
      final normalizedId = (memberId ?? '').trim();
      if (normalizedId.isEmpty) {
        return null;
      }
      for (final member in sourceMembers) {
        if (member.id == normalizedId) {
          return member;
        }
      }
      return null;
    }

    List<MemberProfile> applyFilter({
      required Iterable<MemberProfile> members,
      int? requiredGeneration,
      String? excludedMemberId,
    }) {
      final normalizedQuery = query.trim().toLowerCase();
      return members
          .where((member) {
            if (excludedMemberId != null && member.id == excludedMemberId) {
              return false;
            }
            if (requiredGeneration != null &&
                member.generation != requiredGeneration) {
              return false;
            }
            if (childBirthDate != null &&
                !_isEligibleParentByBirthDate(
                  member: member,
                  childBirthDate: childBirthDate,
                )) {
              return false;
            }
            if (normalizedQuery.isEmpty) {
              return true;
            }
            final fullName = member.fullName.toLowerCase();
            final nickName = member.nickName.toLowerCase();
            final id = member.id.toLowerCase();
            return fullName.contains(normalizedQuery) ||
                nickName.contains(normalizedQuery) ||
                id.contains(normalizedQuery);
          })
          .toList(growable: false);
    }

    MemberProfile? resolveSpouseCandidate({
      required MemberProfile anchor,
      required bool expectFemale,
    }) {
      final candidates = expectFemale ? femaleCandidates : maleCandidates;
      for (final candidate in candidates) {
        if (candidate.id == anchor.id) {
          continue;
        }
        if (candidate.generation != anchor.generation) {
          continue;
        }
        if (childBirthDate != null &&
            !_isEligibleParentByBirthDate(
              member: candidate,
              childBirthDate: childBirthDate,
            )) {
          continue;
        }
        final linkedAsSpouse =
            anchor.spouseIds.contains(candidate.id) ||
            candidate.spouseIds.contains(anchor.id);
        if (linkedAsSpouse) {
          return candidate;
        }
      }
      return null;
    }

    return showModalBottomSheet<_ParentSelectionResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final selectedFather = resolveMemberById(fatherId);
            final selectedMother = resolveMemberById(motherId);
            final fatherOptions = selectedFather == null
                ? applyFilter(
                    members: maleCandidates,
                    requiredGeneration: selectedMother?.generation,
                    excludedMemberId: motherId,
                  )
                : const <MemberProfile>[];
            final motherOptions = selectedMother == null
                ? applyFilter(
                    members: femaleCandidates,
                    requiredGeneration: selectedFather?.generation,
                    excludedMemberId: fatherId,
                  )
                : const <MemberProfile>[];
            final pairLocked = selectedFather != null && selectedMother != null;

            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                height: MediaQuery.sizeOf(context).height * 0.78,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.pick(vi: 'Chọn cha/mẹ', en: 'Pick parents'),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search),
                        hintText: l10n.pick(
                          vi: 'Tìm thành viên...',
                          en: 'Search members...',
                        ),
                      ),
                      onChanged: (value) {
                        if (pairLocked) {
                          return;
                        }
                        setModalState(() {
                          query = value;
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    if (childBirthDate != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text(
                          l10n.pick(
                            vi: 'Đang lọc theo ngày sinh: chỉ hiển thị người lớn hơn tối thiểu 15 tuổi.',
                            en: 'Birth-date filter: only candidates at least 15 years older are shown.',
                          ),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    if (selectedFather != null || selectedMother != null) ...[
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (selectedFather != null)
                            _ParentRoleBadge(
                              icon: Icons.male,
                              roleLabel: l10n.pick(vi: 'Cha', en: 'Father'),
                              memberName: selectedFather.displayName,
                            ),
                          if (selectedMother != null)
                            _ParentRoleBadge(
                              icon: Icons.female,
                              roleLabel: l10n.pick(vi: 'Mẹ', en: 'Mother'),
                              memberName: selectedMother.displayName,
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (pairLocked)
                      Text(
                        l10n.pick(
                          vi: 'Đã chọn đủ Cha và Mẹ. Không thể chọn thêm.',
                          en: 'Both father and mother are selected. No more selection allowed.',
                        ),
                        style: Theme.of(context).textTheme.bodySmall,
                      )
                    else if (selectedFather != null || selectedMother != null)
                      Text(
                        selectedFather != null
                            ? l10n.pick(
                                vi: 'Đã chọn Cha. Chỉ hiển thị ứng viên Mẹ cùng đời.',
                                en: 'Father selected. Only same-generation female candidates are shown.',
                              )
                            : l10n.pick(
                                vi: 'Đã chọn Mẹ. Chỉ hiển thị ứng viên Cha cùng đời.',
                                en: 'Mother selected. Only same-generation male candidates are shown.',
                              ),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    if ((selectedFather != null || selectedMother != null) &&
                        !pairLocked)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          key: const Key('member-parent-picker-reset'),
                          onPressed: () {
                            setModalState(() {
                              fatherId = null;
                              motherId = null;
                              query = '';
                            });
                          },
                          icon: const Icon(Icons.restart_alt_outlined),
                          label: Text(l10n.pick(vi: 'Chọn lại', en: 'Reset')),
                        ),
                      ),
                    Expanded(
                      child: ListView(
                        children: [
                          if (selectedFather == null) ...[
                            Text(
                              l10n.pick(
                                vi: 'Chọn Cha (nam)',
                                en: 'Choose father (male)',
                              ),
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            if (fatherOptions.isEmpty)
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: 8,
                                  bottom: 12,
                                ),
                                child: Text(
                                  l10n.pick(
                                    vi: 'Không có ứng viên Cha phù hợp.',
                                    en: 'No suitable father candidates.',
                                  ),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              )
                            else
                              for (final member in fatherOptions)
                                ListTile(
                                  key: Key(
                                    'member-parent-picker-father-${member.id}',
                                  ),
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(member.displayName),
                                  subtitle: Text(
                                    '${_branchNameById(member.branchId)} · ${l10n.pick(vi: 'Đời', en: 'Gen')} ${member.generation}',
                                  ),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () {
                                    final spouse = resolveSpouseCandidate(
                                      anchor: member,
                                      expectFemale: true,
                                    );
                                    setModalState(() {
                                      fatherId = member.id;
                                      if (spouse != null) {
                                        motherId = spouse.id;
                                      }
                                    });
                                  },
                                ),
                            const SizedBox(height: 12),
                          ],
                          if (selectedMother == null) ...[
                            Text(
                              l10n.pick(
                                vi: 'Chọn Mẹ (nữ)',
                                en: 'Choose mother (female)',
                              ),
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            if (motherOptions.isEmpty)
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: 8,
                                  bottom: 12,
                                ),
                                child: Text(
                                  l10n.pick(
                                    vi: 'Không có ứng viên Mẹ phù hợp.',
                                    en: 'No suitable mother candidates.',
                                  ),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              )
                            else
                              for (final member in motherOptions)
                                ListTile(
                                  key: Key(
                                    'member-parent-picker-mother-${member.id}',
                                  ),
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(member.displayName),
                                  subtitle: Text(
                                    '${_branchNameById(member.branchId)} · ${l10n.pick(vi: 'Đời', en: 'Gen')} ${member.generation}',
                                  ),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () {
                                    final spouse = resolveSpouseCandidate(
                                      anchor: member,
                                      expectFemale: false,
                                    );
                                    setModalState(() {
                                      motherId = member.id;
                                      if (spouse != null) {
                                        fatherId = spouse.id;
                                      }
                                    });
                                  },
                                ),
                          ],
                          if (selectedFather == null &&
                              selectedMother == null &&
                              fatherOptions.isEmpty &&
                              motherOptions.isEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                l10n.pick(
                                  vi: 'Không có ứng viên phù hợp để chọn cha/mẹ.',
                                  en: 'No matching candidates for parent selection.',
                                ),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          if (pairLocked) ...[
                            const SizedBox(height: 8),
                            Text(
                              l10n.pick(
                                vi: 'Hệ thống đã khóa lựa chọn thêm sau khi đủ cặp cha/mẹ.',
                                en: 'Selection is locked after both parents are chosen.',
                              ),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                          if ((selectedFather != null ||
                                  selectedMother != null) &&
                              !pairLocked)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: AppCompactTextButton(
                                onPressed: () {
                                  setModalState(() {
                                    fatherId = null;
                                    motherId = null;
                                    query = '';
                                  });
                                },
                                child: Text(
                                  l10n.pick(
                                    vi: 'Bỏ chọn tất cả',
                                    en: 'Clear all',
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            key: const Key('member-parent-picker-cancel'),
                            onPressed: () => Navigator.of(context).pop(),
                            child: Text(l10n.pick(vi: 'Hủy', en: 'Cancel')),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            key: const Key('member-parent-picker-done'),
                            onPressed: fatherId == null && motherId == null
                                ? null
                                : () {
                                    Navigator.of(context).pop(
                                      _ParentSelectionResult(
                                        fatherId: fatherId,
                                        motherId: motherId,
                                      ),
                                    );
                                  },
                            child: Text(l10n.pick(vi: 'Xong', en: 'Done')),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  int? get _predictedSiblingOrder {
    if (widget.isEditing) {
      return widget.initialDraft.siblingOrder;
    }
    final selectedParentIds = _resolvedParentIds.toSet();
    if (selectedParentIds.isEmpty) {
      return null;
    }

    final siblingEntries =
        <({String id, String name, int generation, DateTime? birthDate})>[
          for (final member in widget.members)
            if (_sharesSiblingParents(
              referenceParentIds: selectedParentIds,
              candidateParentIds: member.parentIds,
            ))
              (
                id: member.id,
                name: member.fullName,
                generation: member.generation,
                birthDate: _tryParseIsoDate(member.birthDate ?? ''),
              ),
          (
            id: '__draft__',
            name: _fullNameController.text.trim().isEmpty
                ? 'draft'
                : _fullNameController.text.trim(),
            generation: _resolvedGeneration,
            birthDate: _tryParseIsoDate(_birthDateController.text.trim()),
          ),
        ];

    siblingEntries.sort((left, right) {
      final byBirthDate = _compareNullableDate(left.birthDate, right.birthDate);
      if (byBirthDate != 0) {
        return byBirthDate;
      }
      final byGeneration = left.generation.compareTo(right.generation);
      if (byGeneration != 0) {
        return byGeneration;
      }
      final byName = left.name.toLowerCase().compareTo(
        right.name.toLowerCase(),
      );
      if (byName != 0) {
        return byName;
      }
      return left.id.compareTo(right.id);
    });

    final index = siblingEntries.indexWhere((entry) => entry.id == '__draft__');
    if (index < 0) {
      return null;
    }
    return index + 1;
  }

  List<MemberProfile> get _parentCandidates {
    final accessibleBranchIds = widget.branches
        .map((branch) => branch.id)
        .where((id) => id.trim().isNotEmpty)
        .toSet();
    final candidates = widget.members
        .where((member) => member.id != widget.editingMemberId)
        .where(
          (member) =>
              accessibleBranchIds.isEmpty ||
              accessibleBranchIds.contains(member.branchId),
        )
        .toList(growable: false);
    candidates.sort(
      (left, right) => left.displayName.toLowerCase().compareTo(
        right.displayName.toLowerCase(),
      ),
    );
    return candidates;
  }

  MemberProfile? _memberById(String? memberId) {
    if (memberId == null || memberId.isEmpty) {
      return null;
    }
    for (final member in widget.members) {
      if (member.id == memberId) {
        return member;
      }
    }
    return null;
  }

  List<String> get _resolvedParentIds {
    if (widget.isEditing) {
      return widget.initialDraft.parentIds;
    }
    final fatherId = _selectedFatherId?.trim();
    final motherId = _selectedMotherId?.trim();
    final parentIds = <String>[];
    if (fatherId != null && fatherId.isNotEmpty) {
      parentIds.add(fatherId);
    }
    if (motherId != null &&
        motherId.isNotEmpty &&
        !parentIds.contains(motherId)) {
      parentIds.add(motherId);
    }
    return parentIds;
  }

  String? get _resolvedBranchId {
    if (widget.isEditing) {
      return _branchId;
    }
    final selectedParent = _primarySelectedParent;
    return selectedParent?.branchId ?? _branchId;
  }

  int get _resolvedGeneration {
    if (widget.isEditing) {
      final parsed = int.tryParse(_generationController.text.trim());
      return parsed ?? widget.initialDraft.generation;
    }
    final selectedParent = _primarySelectedParent;
    if (selectedParent == null) {
      return widget.initialDraft.generation;
    }
    return selectedParent.generation + 1;
  }

  List<MemberProfile> get _siblingCandidates {
    final selectedParentIds = _resolvedParentIds.toSet();
    if (selectedParentIds.isEmpty) {
      return const <MemberProfile>[];
    }
    final candidates =
        widget.members
            .where((member) => member.id != widget.editingMemberId)
            .where(
              (member) => _sharesSiblingParents(
                referenceParentIds: selectedParentIds,
                candidateParentIds: member.parentIds,
              ),
            )
            .toList(growable: false)
          ..sort(_compareMembersBySeniority);
    return candidates;
  }

  DateTime? get _draftBirthDate =>
      _tryParseIsoDate(_birthDateController.text.trim());

  bool _isEligibleParentByBirthDate({
    required MemberProfile member,
    required DateTime childBirthDate,
  }) {
    final parentBirthDate = _tryParseIsoDate(member.birthDate ?? '');
    if (parentBirthDate != null) {
      return _isAtLeastYearsOlder(
        olderBirthDate: parentBirthDate,
        youngerBirthDate: childBirthDate,
        minimumYears: 15,
      );
    }
    return member.generation < _resolvedGeneration;
  }

  void _syncParentSelectionWithBirthDate() {
    final childBirthDate = _draftBirthDate;
    if (childBirthDate == null) {
      return;
    }
    final father = _selectedFather;
    if (father != null &&
        !_isEligibleParentByBirthDate(
          member: father,
          childBirthDate: childBirthDate,
        )) {
      _selectedFatherId = null;
    }
    final mother = _selectedMother;
    if (mother != null &&
        !_isEligibleParentByBirthDate(
          member: mother,
          childBirthDate: childBirthDate,
        )) {
      _selectedMotherId = null;
    }
  }

  void _autofillPhoneFromSelectedFather() {
    final current = _phoneController.text.trim();
    if (current.isNotEmpty) {
      return;
    }
    final father = _selectedFather;
    final fatherPhone = father?.phoneE164?.trim() ?? '';
    if (fatherPhone.isEmpty) {
      return;
    }
    _phoneController.text = fatherPhone;
    _phoneCountryIsoCode = PhoneNumberFormatter.inferCountryOption(
      fatherPhone,
    ).isoCode;
  }

  String _branchNameById(String? branchId) {
    if (branchId == null || branchId.isEmpty) {
      return '-';
    }
    for (final branch in widget.branches) {
      if (branch.id == branchId) {
        return branch.name;
      }
    }
    return branchId;
  }
}

class _ParentSelectionResult {
  const _ParentSelectionResult({this.fatherId, this.motherId});

  final String? fatherId;
  final String? motherId;
}

class _ParentRoleBadge extends StatelessWidget {
  const _ParentRoleBadge({
    required this.icon,
    required this.roleLabel,
    required this.memberName,
  });

  final IconData icon;
  final String roleLabel;
  final String memberName;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Text(
            '$roleLabel: $memberName',
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _MemberEditorStepIndicator extends StatelessWidget {
  const _MemberEditorStepIndicator({
    required this.currentStep,
    required this.labels,
    required this.onStepSelected,
  });

  final int currentStep;
  final List<String> labels;
  final ValueChanged<int> onStepSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    const circleSize = 34.0;
    const connectorThickness = 3.0;
    const connectorHorizontalInset = 16.0;
    const labelRowHeight = 44.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: circleSize,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final stepCount = labels.length;
              final stepWidth = stepCount == 0
                  ? 0.0
                  : constraints.maxWidth / stepCount;
              final connectorWidth =
                  stepWidth - (connectorHorizontalInset * 2) > 0
                  ? stepWidth - (connectorHorizontalInset * 2)
                  : 0.0;

              return Stack(
                alignment: Alignment.center,
                children: [
                  if (stepCount > 1)
                    for (var index = 0; index < stepCount - 1; index++)
                      Positioned(
                        left:
                            (stepWidth * (index + 0.5)) +
                            connectorHorizontalInset,
                        top: (circleSize - connectorThickness) / 2,
                        width: connectorWidth,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          height: connectorThickness,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            color: index < currentStep
                                ? colorScheme.primary
                                : colorScheme.outlineVariant,
                          ),
                        ),
                      ),
                  Row(
                    children: [
                      for (var index = 0; index < labels.length; index++)
                        Expanded(
                          child: Center(
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                key: Key(
                                  'member-editor-step-${index + 1}-circle',
                                ),
                                borderRadius: BorderRadius.circular(20),
                                onTap: () => onStepSelected(index),
                                child: Padding(
                                  padding: const EdgeInsets.all(2),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    width: circleSize,
                                    height: circleSize,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: index <= currentStep
                                          ? colorScheme.primary
                                          : colorScheme.surfaceContainerHighest,
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      '${index + 1}',
                                      style: textTheme.titleSmall?.copyWith(
                                        color: index <= currentStep
                                            ? colorScheme.onPrimary
                                            : colorScheme.onSurfaceVariant,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: labelRowHeight,
          child: Row(
            children: [
              for (var index = 0; index < labels.length; index++) ...[
                Expanded(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      key: Key('member-editor-step-${index + 1}-label'),
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => onStepSelected(index),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        child: Text(
                          labels[index],
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.labelLarge?.copyWith(
                            fontWeight: index == currentStep
                                ? FontWeight.w800
                                : FontWeight.w600,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
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
    final hasActiveFilters =
        searchController.text.trim().isNotEmpty ||
        filtersBranchId != null ||
        filtersGeneration != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          key: const Key('members-search-input'),
          controller: searchController,
          onChanged: onSearchChanged,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            labelText: l10n.memberSearchLabel,
            hintText: l10n.memberSearchHint,
            suffixIcon: searchController.text.trim().isEmpty
                ? null
                : AppCompactIconButton(
                    key: const Key('members-search-clear-query'),
                    tooltip: l10n.memberClearFiltersAction,
                    onPressed: () {
                      searchController.clear();
                      onSearchChanged('');
                    },
                    icon: const Icon(Icons.close),
                  ),
          ),
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 560;
            final branchFilter = DropdownButtonFormField<String?>(
              key: const Key('members-branch-filter-dropdown'),
              isExpanded: true,
              initialValue: filtersBranchId,
              decoration: InputDecoration(
                labelText: l10n.memberFilterBranchLabel,
              ),
              items: [
                DropdownMenuItem<String?>(
                  value: null,
                  child: Text(
                    l10n.memberFilterAllBranches,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                for (final branch in branches)
                  DropdownMenuItem<String?>(
                    value: branch.id,
                    child: Text(branch.name, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: onBranchChanged,
            );
            final generationFilter = DropdownButtonFormField<int?>(
              key: const Key('members-generation-filter-dropdown'),
              isExpanded: true,
              initialValue: filtersGeneration,
              decoration: InputDecoration(
                labelText: l10n.memberFilterGenerationLabel,
              ),
              items: [
                DropdownMenuItem<int?>(
                  value: null,
                  child: Text(
                    l10n.memberFilterAllGenerations,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                for (final generation in generationOptions)
                  DropdownMenuItem<int?>(
                    value: generation,
                    child: Text(
                      '${l10n.memberGenerationLabel} $generation',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: onGenerationChanged,
            );
            if (compact) {
              return Column(
                children: [
                  branchFilter,
                  const SizedBox(height: 10),
                  generationFilter,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: branchFilter),
                const SizedBox(width: 10),
                Expanded(child: generationFilter),
              ],
            );
          },
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            key: const Key('members-clear-filters'),
            onPressed: hasActiveFilters ? onClearFilters : null,
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
    this.showRoleBadge = true,
    this.highlightQuery = '',
    required this.onTap,
  });

  final MemberProfile member;
  final String branchName;
  final String roleLabel;
  final bool showRoleBadge;
  final String highlightQuery;
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
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _AvatarBadge(member: member, radius: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _HighlightedText(
                      text: member.fullName,
                      query: highlightQuery,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                      highlightStyle: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: colorScheme.primary,
                      ),
                    ),
                    if (member.nickName.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      _HighlightedText(
                        text: member.nickName,
                        query: highlightQuery,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        highlightStyle: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _ChipPill(
                          icon: Icons.account_tree_outlined,
                          label: branchName,
                          compact: true,
                        ),
                        _ChipPill(
                          icon: Icons.filter_5_outlined,
                          label:
                              '${l10n.memberGenerationLabel}: ${member.generation}',
                          compact: true,
                        ),
                        if (showRoleBadge)
                          _ChipPill(
                            icon: Icons.badge_outlined,
                            label: roleLabel,
                            compact: true,
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: _HighlightedText(
                            text: member.phoneE164 ?? l10n.memberPhoneMissing,
                            query: highlightQuery,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                            highlightStyle: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if ((member.phoneE164 ?? '').trim().isNotEmpty)
                          MemberPhoneActionIconButton(
                            phoneNumber: member.phoneE164!,
                            contactName: member.displayName,
                            iconSize: 18,
                            constraints: const BoxConstraints(
                              minWidth: 28,
                              minHeight: 28,
                            ),
                          ),
                      ],
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
  const _WorkspaceHero({required this.title, required this.description});

  final String title;
  final String description;

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
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colorScheme.onPrimary.withValues(alpha: 0.92),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 560;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (compact)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  )
                else
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
                    ],
                  ),
                const SizedBox(height: 16),
                child,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SearchStateCard extends StatelessWidget {
  const _SearchStateCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String description;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                  if (trailing != null) ...[
                    const SizedBox(height: 10),
                    trailing!,
                  ],
                ],
              ),
            ),
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
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        final crossAxisCount = constraints.maxWidth > 820 ? 3 : 2;
        final narrow = constraints.maxWidth < 420;
        final compactRatio = textScale > 1.1 || narrow ? 1.45 : 1.8;
        return GridView.builder(
          itemCount: items.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: crossAxisCount == 2 ? compactRatio : 1.65,
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
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Icon(icon),
            const SizedBox(height: 8),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
            ),
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
    this.compact = false,
  });

  final IconData icon;
  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 12,
          vertical: compact ? 5 : 8,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: compact ? 14 : 16),
            SizedBox(width: compact ? 6 : 8),
            Text(
              label,
              style:
                  (compact
                          ? Theme.of(context).textTheme.labelMedium
                          : Theme.of(context).textTheme.labelLarge)
                      ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _HighlightedText extends StatelessWidget {
  const _HighlightedText({
    required this.text,
    required this.query,
    this.style,
    this.highlightStyle,
  });

  final String text;
  final String query;
  final TextStyle? style;
  final TextStyle? highlightStyle;

  @override
  Widget build(BuildContext context) {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) {
      return Text(text, style: style);
    }

    final lowerText = text.toLowerCase();
    final start = lowerText.indexOf(normalizedQuery);
    if (start < 0) {
      return Text(text, style: style);
    }
    final end = start + normalizedQuery.length;

    return RichText(
      text: TextSpan(
        style: style ?? DefaultTextStyle.of(context).style,
        children: [
          TextSpan(text: text.substring(0, start)),
          TextSpan(
            text: text.substring(start, end),
            style: (highlightStyle ?? style)?.copyWith(
              backgroundColor: Theme.of(
                context,
              ).colorScheme.primaryContainer.withValues(alpha: 0.8),
            ),
          ),
          TextSpan(text: text.substring(end)),
        ],
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
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

String _memberRepositoryErrorMessage(
  AppLocalizations l10n,
  MemberRepositoryErrorCode error, {
  String? overrideMessage,
}) {
  final customMessage = overrideMessage?.trim();
  if (customMessage != null && customMessage.isNotEmpty) {
    return customMessage;
  }
  return switch (error) {
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

String _genderLabel(AppLocalizations l10n, String? gender) {
  return switch (gender?.trim().toLowerCase()) {
    'male' => l10n.memberGenderMale,
    'female' => l10n.memberGenderFemale,
    'other' => l10n.memberGenderOther,
    _ => l10n.memberGenderUnspecified,
  };
}

bool _isMaleGenderValue(String? gender) {
  final normalized = (gender ?? '').trim().toLowerCase();
  return normalized == 'male' ||
      normalized == 'm' ||
      normalized == 'nam' ||
      normalized == 'boy' ||
      normalized == 'man';
}

bool _isFemaleGenderValue(String? gender) {
  final normalized = (gender ?? '').trim().toLowerCase();
  return normalized == 'female' ||
      normalized == 'f' ||
      normalized == 'nữ' ||
      normalized == 'nu' ||
      normalized == 'girl' ||
      normalized == 'woman';
}

bool _sharesSiblingParents({
  required Iterable<String> referenceParentIds,
  required Iterable<String> candidateParentIds,
}) {
  final reference = referenceParentIds
      .map((id) => id.trim())
      .where((id) => id.isNotEmpty)
      .toSet();
  final candidate = candidateParentIds
      .map((id) => id.trim())
      .where((id) => id.isNotEmpty)
      .toSet();
  if (reference.isEmpty || candidate.isEmpty) {
    return false;
  }
  if (reference.length >= 2) {
    return reference.every(candidate.contains);
  }
  return candidate.contains(reference.first);
}

String? _siblingOrderLabel(AppLocalizations l10n, int? siblingOrder) {
  if (siblingOrder == null || siblingOrder <= 0) {
    return null;
  }
  if (siblingOrder == 1) {
    return l10n.pick(vi: 'Con trưởng', en: 'First-born child');
  }
  return l10n.pick(vi: 'Con thứ $siblingOrder', en: 'Child #$siblingOrder');
}

int _compareMembersBySeniority(MemberProfile left, MemberProfile right) {
  final byBirthDate = _compareNullableDate(
    _tryParseIsoDate(left.birthDate ?? ''),
    _tryParseIsoDate(right.birthDate ?? ''),
  );
  if (byBirthDate != 0) {
    return byBirthDate;
  }
  final byGeneration = left.generation.compareTo(right.generation);
  if (byGeneration != 0) {
    return byGeneration;
  }
  final byName = left.fullName.toLowerCase().compareTo(
    right.fullName.toLowerCase(),
  );
  if (byName != 0) {
    return byName;
  }
  return left.id.compareTo(right.id);
}

int _compareNullableDate(DateTime? left, DateTime? right) {
  if (left == null && right == null) {
    return 0;
  }
  if (left == null) {
    return 1;
  }
  if (right == null) {
    return -1;
  }
  return left.compareTo(right);
}

bool _isAtLeastYearsOlder({
  required DateTime olderBirthDate,
  required DateTime youngerBirthDate,
  required int minimumYears,
}) {
  final cutoffYear = youngerBirthDate.year - minimumYears;
  if (olderBirthDate.year < cutoffYear) {
    return true;
  }
  if (olderBirthDate.year > cutoffYear) {
    return false;
  }
  if (olderBirthDate.month < youngerBirthDate.month) {
    return true;
  }
  if (olderBirthDate.month > youngerBirthDate.month) {
    return false;
  }
  return olderBirthDate.day <= youngerBirthDate.day;
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

Map<String, dynamic> _asStringKeyMap(Object? value) {
  if (value is! Map) {
    return const {};
  }
  return value.map((key, entry) => MapEntry(key.toString(), entry));
}

String _asTrimmedString(Object? value, {String fallback = ''}) {
  if (value is! String) {
    return fallback.trim();
  }
  return value.trim();
}

int _asPositiveInt(Object? value, {required int fallback}) {
  if (value is int && value > 0) {
    return value;
  }
  return fallback;
}

String? _nullIfBlank(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
