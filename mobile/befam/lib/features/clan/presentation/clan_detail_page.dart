import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/services/governance_role_matrix.dart';
import '../../../core/widgets/app_feedback_states.dart';
import '../../../core/widgets/app_workspace_chrome.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../l10n/l10n.dart';
import '../../auth/models/auth_session.dart';
import '../../auth/models/clan_context_option.dart';
import '../../discovery/presentation/join_request_review_page.dart';
import '../../discovery/services/genealogy_discovery_repository.dart';
import '../../onboarding/models/onboarding_models.dart';
import '../../onboarding/presentation/onboarding_coordinator.dart';
import '../../onboarding/presentation/onboarding_scope.dart';
import '../models/branch_draft.dart';
import '../models/branch_profile.dart';
import '../models/clan_draft.dart';
import '../models/clan_member_summary.dart';
import '../services/clan_repository.dart';
import 'branch_list_page.dart';
import 'clan_controller.dart';

class ClanDetailPage extends StatefulWidget {
  const ClanDetailPage({
    super.key,
    required this.session,
    required this.repository,
    this.availableClanContexts = const [],
    this.onSwitchClanContext,
    this.autoOpenClanEditorOnOpen = false,
  });

  final AuthSession session;
  final ClanRepository repository;
  final List<ClanContextOption> availableClanContexts;
  final Future<AuthSession?> Function(String clanId)? onSwitchClanContext;
  final bool autoOpenClanEditorOnOpen;

  @override
  State<ClanDetailPage> createState() => _ClanDetailPageState();
}

class _ClanDetailPageState extends State<ClanDetailPage> {
  late ClanController _controller;
  late AuthSession _session;
  bool _isSwitchingClanContext = false;
  bool _isProfileDetailsExpanded = false;
  bool _hasTriggeredAutoOpenClanEditor = false;
  bool _hasScheduledOnboarding = false;
  late final OnboardingCoordinator _onboardingCoordinator;

  static final Map<String, String> _lastSelectedClanByUid = <String, String>{};

  @override
  void initState() {
    super.initState();
    _session = widget.session;
    final currentClanId = (_session.clanId ?? '').trim();
    if (currentClanId.isNotEmpty) {
      _lastSelectedClanByUid[_session.uid] = currentClanId;
    }
    _controller = _createController(_session);
    _onboardingCoordinator = createDefaultOnboardingCoordinator(
      session: _session,
    );
    unawaited(_initializeWorkspace());
    if (widget.autoOpenClanEditorOnOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_scheduleAutoOpenClanEditor());
      });
    }
  }

  ClanController _createController(AuthSession session) {
    return ClanController(repository: widget.repository, session: session);
  }

  Future<void> _initializeWorkspace() async {
    await _controller.initialize();
    _scheduleOnboardingIfNeeded();
  }

  @override
  void didUpdateWidget(covariant ClanDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session != widget.session) {
      _session = widget.session;
      _onboardingCoordinator.updateSession(_session);
      _hasScheduledOnboarding = false;
      final previous = _controller;
      _controller = _createController(_session);
      previous.dispose();
      unawaited(_initializeWorkspace());
    }
  }

  @override
  void dispose() {
    unawaited(_onboardingCoordinator.interrupt());
    _onboardingCoordinator.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _scheduleAutoOpenClanEditor() async {
    if (!widget.autoOpenClanEditorOnOpen || _hasTriggeredAutoOpenClanEditor) {
      return;
    }
    for (var attempt = 0; attempt < 4; attempt++) {
      if (!mounted) {
        return;
      }
      final route = ModalRoute.of(context);
      if (route?.isCurrent ?? true) {
        await Future<void>.delayed(
          Duration(milliseconds: attempt == 0 ? 220 : 140),
        );
        if (!mounted) {
          return;
        }
        final activeRoute = ModalRoute.of(context);
        if (!(activeRoute?.isCurrent ?? true)) {
          continue;
        }
        _hasTriggeredAutoOpenClanEditor = true;
        await _openClanEditor();
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 120));
    }
  }

  Future<void> _openClanEditor() async {
    final didSave = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _ClanEditorSheet(
          initialDraft: _controller.clan == null
              ? ClanDraft.empty()
              : ClanDraft.fromProfile(_controller.clan!),
          onSubmit: _controller.saveClan,
        );
      },
    );

    if (didSave != true || !mounted) {
      return;
    }
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final createdFromUnlinkedSession =
        (_session.clanId ?? '').trim().isEmpty &&
        _controller.permissions.canBootstrapClan;
    if (createdFromUnlinkedSession &&
        widget.onSwitchClanContext != null &&
        _controller.clan != null) {
      final createdClanId = _controller.clan!.id.trim();
      if (createdClanId.isNotEmpty) {
        await _switchClanContext(createdClanId);
        if (!mounted) {
          return;
        }
      }
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          createdFromUnlinkedSession
              ? l10n.pick(
                  vi: 'Đã tạo gia phả mới và chuyển sang không gian quản lý.',
                  en: 'New clan workspace created and switched successfully.',
                )
              : l10n.clanSaveSuccess,
        ),
      ),
    );
  }

  Future<void> _openBranchEditor({BranchProfile? branch}) async {
    final didSave = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _BranchEditorSheet(
          members: _controller.members,
          initialDraft: branch == null
              ? BranchDraft.empty()
              : BranchDraft.fromProfile(branch),
          onSubmit: (draft) {
            return _controller.saveBranch(branchId: branch?.id, draft: draft);
          },
        );
      },
    );

    if (didSave == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.clanBranchSaveSuccess)),
      );
    }
  }

  void _openBranchList() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) {
          return BranchListPage(
            controller: _controller,
            onEditBranch: _openBranchEditor,
          );
        },
      ),
    );
  }

  bool get _canReviewJoinRequests {
    return GovernanceRoleMatrix.canReviewJoinRequests(_session);
  }

  void _openJoinRequestReview() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) {
          return JoinRequestReviewPage(
            session: _session,
            repository: createDefaultGenealogyDiscoveryRepository(
              session: _session,
            ),
          );
        },
      ),
    );
  }

  Future<void> _switchClanContext(String clanId) async {
    final normalized = clanId.trim();
    if (normalized.isEmpty || normalized == (_session.clanId ?? '').trim()) {
      return;
    }
    final switcher = widget.onSwitchClanContext;
    if (switcher == null) {
      return;
    }
    if (_isSwitchingClanContext) {
      return;
    }
    setState(() => _isSwitchingClanContext = true);
    try {
      final switched = await switcher(normalized);
      if (!mounted || switched == null) {
        return;
      }
      _lastSelectedClanByUid[switched.uid] = normalized;
      final previous = _controller;
      final next = _createController(switched);
      setState(() {
        _session = switched;
        _controller = next;
        _isProfileDetailsExpanded = false;
      });
      _onboardingCoordinator.updateSession(switched);
      _hasScheduledOnboarding = false;
      previous.dispose();
      await _initializeWorkspace();
    } finally {
      if (mounted) {
        setState(() => _isSwitchingClanContext = false);
      }
    }
  }

  void _scheduleOnboardingIfNeeded() {
    if (_hasScheduledOnboarding ||
        !mounted ||
        widget.autoOpenClanEditorOnOpen ||
        !_controller.permissions.canEditClanSettings) {
      return;
    }
    _hasScheduledOnboarding = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(
        _onboardingCoordinator.scheduleTrigger(
          const OnboardingTrigger(
            id: 'clan_detail_opened',
            routeId: 'clan_detail',
          ),
          delay: const Duration(milliseconds: 900),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        final l10n = context.l10n;
        final screenWidth = MediaQuery.sizeOf(context).width;
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        final compactAppBarActions = screenWidth < 360 || textScale > 1.15;
        final profileRows = _profileRows();
        final clanName = _controller.clan?.name ?? l10n.clanCreateFirstTitle;
        final heroHighlights = <_HeroHighlight>[
          _HeroHighlight(
            icon: Icons.account_tree_outlined,
            label: l10n.pick(
              vi: '${_controller.branches.length} chi',
              en: '${_controller.branches.length} branches',
            ),
          ),
          _HeroHighlight(
            icon: Icons.groups_2_outlined,
            label: l10n.pick(
              vi: '${_controller.clan?.memberCount ?? _controller.members.length} thành viên',
              en: '${_controller.clan?.memberCount ?? _controller.members.length} members',
            ),
          ),
          if ((_controller.clan?.countryCode.trim().isNotEmpty ?? false))
            _HeroHighlight(
              icon: Icons.public_outlined,
              label: _countryDisplayName(_controller.clan!.countryCode, l10n),
            ),
        ];

        final scaffold = Scaffold(
          appBar: AppBar(
            title: Text(
              l10n.clanDetailTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            actions: compactAppBarActions
                ? [
                    PopupMenuButton<String>(
                      tooltip: l10n.pick(
                        vi: 'Tùy chọn không gian họ tộc',
                        en: 'Clan workspace options',
                      ),
                      onSelected: (value) {
                        switch (value) {
                          case 'join_requests':
                            _openJoinRequestReview();
                            break;
                          case 'refresh':
                            if (!_controller.isLoading) {
                              _controller.refresh();
                            }
                            break;
                        }
                      },
                      itemBuilder: (context) => [
                        if (_canReviewJoinRequests)
                          PopupMenuItem<String>(
                            value: 'join_requests',
                            child: Text(
                              l10n.pick(
                                vi: 'Duyệt yêu cầu tham gia',
                                en: 'Review join requests',
                              ),
                            ),
                          ),
                        PopupMenuItem<String>(
                          value: 'refresh',
                          child: Text(l10n.clanRefreshAction),
                        ),
                      ],
                    ),
                  ]
                : [
                    if (_canReviewJoinRequests)
                      IconButton(
                        tooltip: l10n.pick(
                          vi: 'Duyệt yêu cầu tham gia',
                          en: 'Review join requests',
                        ),
                        onPressed: _openJoinRequestReview,
                        icon: const Icon(Icons.fact_check_outlined),
                      ),
                    IconButton(
                      tooltip: l10n.clanRefreshAction,
                      onPressed: _controller.isLoading
                          ? null
                          : _controller.refresh,
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
          ),
          body: SafeArea(
            child: _controller.isLoading
                ? AppLoadingState(
                    message: l10n.pick(
                      vi: 'Đang tải không gian họ tộc...',
                      en: 'Loading clan workspace...',
                    ),
                  )
                : !_controller.permissions.canViewWorkspace
                ? _EmptyWorkspace(
                    icon: Icons.lock_outline,
                    title: l10n.clanNoContextTitle,
                  )
                : RefreshIndicator(
                    onRefresh: _controller.refresh,
                    child: AppWorkspaceViewport(
                      child: ListView(
                        padding: appWorkspacePagePadding(
                          context,
                          top: 16,
                          bottom: 108,
                        ),
                        children: [
                          _WorkspaceHero(
                            title: clanName,
                            highlights: heroHighlights,
                          ),
                          const SizedBox(height: 16),
                          if (_controller.errorMessage != null) ...[
                            _InfoCard(
                              icon: Icons.error_outline,
                              title: l10n.clanLoadErrorTitle,
                              description:
                                  _controller.errorMessage ==
                                      'permission_denied'
                                  ? l10n.clanPermissionDeniedDescription
                                  : l10n.clanLoadErrorDescription,
                              tone: colorScheme.errorContainer,
                            ),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                onPressed: _controller.refresh,
                                icon: const Icon(Icons.refresh),
                                label: Text(l10n.clanRefreshAction),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          if (_controller.permissions.isReadOnly) ...[
                            _InfoCard(
                              icon: Icons.visibility_outlined,
                              title: l10n.clanReadOnlyTitle,
                              tone: colorScheme.secondaryContainer,
                            ),
                            const SizedBox(height: 16),
                          ],
                          _QuickStatsGrid(
                            items: [
                              _QuickStatCard(
                                label: l10n.clanStatBranches,
                                value: '${_controller.branches.length}',
                                icon: Icons.account_tree_outlined,
                              ),
                              _QuickStatCard(
                                label: l10n.clanStatMembers,
                                value:
                                    '${_controller.clan?.memberCount ?? _controller.members.length}',
                                icon: Icons.groups_2_outlined,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _SectionCard(
                            title: l10n.pick(
                              vi: 'Tổng quan họ tộc',
                              en: 'Clan overview',
                            ),
                            child: _controller.clan == null
                                ? _EmptySection(
                                    icon: Icons.domain_add_outlined,
                                    title: l10n.clanProfileEmptyTitle,
                                  )
                                : Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _ProfileSummary(
                                        rows: profileRows,
                                        expanded: _isProfileDetailsExpanded,
                                        collapsedCount: 2,
                                      ),
                                      if (profileRows.length > 2)
                                        Align(
                                          alignment: Alignment.centerLeft,
                                          child: TextButton(
                                            onPressed: () {
                                              setState(() {
                                                _isProfileDetailsExpanded =
                                                    !_isProfileDetailsExpanded;
                                              });
                                            },
                                            child: Text(
                                              _isProfileDetailsExpanded
                                                  ? l10n.pick(
                                                      vi: 'Thu gọn',
                                                      en: 'Collapse',
                                                    )
                                                  : l10n.pick(
                                                      vi: 'Xem thêm',
                                                      en: 'View more',
                                                    ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                          ),
                          const SizedBox(height: 16),
                          _SectionCard(
                            key: const Key('clan-branch-section'),
                            title: l10n.pick(
                              vi: 'Các chi nổi bật',
                              en: 'Key branches',
                            ),
                            anchorId: 'clan.branch_section',
                            actionLabel:
                                _controller.permissions.canManageBranches
                                ? l10n.pick(
                                    vi: 'Thêm chi mới',
                                    en: 'Add branch',
                                  )
                                : null,
                            onAction: _controller.permissions.canManageBranches
                                ? () => _openBranchEditor()
                                : null,
                            footer: _controller.branches.isNotEmpty
                                ? SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      onPressed: _openBranchList,
                                      icon: const Icon(Icons.list_alt_outlined),
                                      label: Text(
                                        l10n.pick(
                                          vi: 'Mở danh sách chi',
                                          en: 'Open branch list',
                                        ),
                                      ),
                                    ),
                                  )
                                : null,
                            child: _controller.branches.isEmpty
                                ? _EmptySection(
                                    icon: Icons.fork_right_outlined,
                                    title: l10n.clanBranchEmptyTitle,
                                  )
                                : Column(
                                    children: [
                                      for (final branch
                                          in _controller.branches.take(3))
                                        Padding(
                                          padding: EdgeInsets.only(
                                            bottom:
                                                branch ==
                                                    _controller.branches
                                                        .take(3)
                                                        .last
                                                ? 0
                                                : 12,
                                          ),
                                          child: _BranchPreviewCard(
                                            branch: branch,
                                            leaderName: _controller.memberName(
                                              branch.leaderMemberId,
                                            ),
                                            viceLeaderName: _controller
                                                .memberName(
                                                  branch.viceLeaderMemberId,
                                                ),
                                            canEdit: _controller
                                                .permissions
                                                .canManageBranches,
                                            onEdit:
                                                _controller
                                                    .permissions
                                                    .canManageBranches
                                                ? () => _openBranchEditor(
                                                    branch: branch,
                                                  )
                                                : null,
                                          ),
                                        ),
                                    ],
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
          floatingActionButton: _controller.permissions.canEditClanSettings
              ? OnboardingAnchor(
                  anchorId: 'clan.edit_fab',
                  child: FloatingActionButton(
                    key: const Key('clan-edit-fab'),
                    onPressed: _openClanEditor,
                    tooltip: _controller.clan == null
                        ? l10n.clanCreateAction
                        : l10n.clanEditAction,
                    child: Icon(
                      _controller.clan == null
                          ? Icons.add
                          : Icons.edit_outlined,
                    ),
                  ),
                )
              : null,
        );
        return OnboardingScope(
          controller: _onboardingCoordinator,
          child: scaffold,
        );
      },
    );
  }

  List<_SummaryRowData> _profileRows() {
    final l10n = context.l10n;
    if (_controller.clan == null) {
      return const [];
    }
    final clan = _controller.clan!;
    final rows = <_SummaryRowData>[
      _SummaryRowData(
        label: l10n.pick(vi: 'Người khởi lập', en: 'Founder'),
        value: clan.founderName.trim().isEmpty
            ? l10n.pick(vi: 'Chưa cập nhật', en: 'Not set')
            : clan.founderName,
      ),
      _SummaryRowData(
        label: l10n.pick(vi: 'Quốc gia hoạt động', en: 'Operating country'),
        value: clan.countryCode.trim().isEmpty
            ? l10n.pick(vi: 'Chưa cập nhật', en: 'Not set')
            : _countryDisplayName(clan.countryCode, l10n),
      ),
    ];
    final cleanedDescription = clan.description.trim();
    if (cleanedDescription.isNotEmpty &&
        !_looksLikeDevelopmentCopy(cleanedDescription)) {
      rows.add(
        _SummaryRowData(
          label: l10n.pick(vi: 'Giới thiệu', en: 'Intro'),
          value: cleanedDescription,
        ),
      );
    }
    return rows;
  }

  bool _looksLikeDevelopmentCopy(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized.isEmpty) {
      return false;
    }
    const markers = [
      'kiểm thử',
      'test',
      'demo',
      'sample',
      'mock',
      'seed',
      'local',
      'dữ liệu gần thực tế',
      'qa',
      'development',
      'debug',
    ];
    return markers.any(normalized.contains);
  }

  String _countryDisplayName(String rawCountryCode, AppLocalizations l10n) {
    switch (rawCountryCode.trim().toUpperCase()) {
      case 'VN':
        return l10n.pick(vi: 'Việt Nam', en: 'Vietnam');
      case 'US':
        return l10n.pick(vi: 'Hoa Kỳ', en: 'United States');
      default:
        final normalized = rawCountryCode.trim().toUpperCase();
        return normalized.isEmpty
            ? l10n.pick(vi: 'Chưa cập nhật', en: 'Not set')
            : normalized;
    }
  }
}

class _WorkspaceHero extends StatelessWidget {
  const _WorkspaceHero({required this.title, required this.highlights});

  final String title;
  final List<_HeroHighlight> highlights;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return AppWorkspaceSurface(
      padding: const EdgeInsets.all(24),
      gradient: appWorkspaceHeroGradient(context),
      showAccentOrbs: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w800,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (highlights.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final highlight in highlights)
                  _HeroHighlightChip(highlight: highlight),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    super.key,
    required this.title,
    required this.child,
    this.description,
    this.anchorId,
    this.actionLabel,
    this.onAction,
    this.footer,
  });

  final String title;
  final Widget child;
  final String? description;
  final String? anchorId;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final card = AppWorkspaceSurface(
      key: key,
      padding: const EdgeInsets.all(20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stackHeader = constraints.maxWidth < 420;
          final actionButton = actionLabel != null && onAction != null
              ? TextButton.icon(
                  onPressed: onAction,
                  icon: const Icon(Icons.add_circle_outline),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(44, 44),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  label: Text(actionLabel!, overflow: TextOverflow.ellipsis),
                )
              : null;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (stackHeader)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionCardHeaderText(
                      title: title,
                      description: description,
                    ),
                    if (actionButton != null) ...[
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: actionButton,
                      ),
                    ],
                  ],
                )
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _SectionCardHeaderText(
                        title: title,
                        description: description,
                      ),
                    ),
                    if (actionButton != null) ...[
                      const SizedBox(width: 12),
                      Flexible(child: actionButton),
                    ],
                  ],
                ),
              const SizedBox(height: 16),
              child,
              if (footer != null) ...[const SizedBox(height: 16), footer!],
            ],
          );
        },
      ),
    );
    if (anchorId == null) {
      return card;
    }
    return OnboardingAnchor(anchorId: anchorId!, child: card);
  }
}

class _SectionCardHeaderText extends StatelessWidget {
  const _SectionCardHeaderText({
    required this.title,
    required this.description,
  });

  final String title;
  final String? description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        if (description != null && description!.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              description!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}

class _EditorSheetScaffold extends StatelessWidget {
  const _EditorSheetScaffold({
    required this.formKey,
    required this.bottomInset,
    required this.scrollChild,
    required this.footer,
  });

  final GlobalKey<FormState> formKey;
  final double bottomInset;
  final Widget scrollChild;
  final Widget footer;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withValues(alpha: 0.14),
              blurRadius: 32,
              offset: const Offset(0, -10),
            ),
          ],
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.9,
          ),
          child: Form(
            key: formKey,
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                    child: scrollChild,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: footer,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CompactEditorHeader extends StatelessWidget {
  const _CompactEditorHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return AppWorkspaceSurface(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      gradient: appWorkspaceHeroGradient(context),
      showAccentOrbs: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.tone,
    this.description,
  });

  final IconData icon;
  final String title;
  final String? description;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppWorkspaceSurface(
      color: tone,
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
                if (description != null && description!.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(description!, style: theme.textTheme.bodyMedium),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickStatsGrid extends StatelessWidget {
  const _QuickStatsGrid({required this.items});

  final List<_QuickStatCard> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }
    if (items.length == 1) {
      return items.first;
    }
    if (items.length == 2) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: items[0]),
          const SizedBox(width: 12),
          Expanded(child: items[1]),
        ],
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 12.0;
        final tileWidth = (constraints.maxWidth - spacing) / 2;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final item in items) SizedBox(width: tileWidth, child: item),
          ],
        );
      },
    );
  }
}

class _QuickStatCard extends StatelessWidget {
  const _QuickStatCard({
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

    return AppWorkspaceSurface(
      color: colorScheme.secondaryContainer,
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: Colors.white.withValues(alpha: 0.72),
            foregroundColor: colorScheme.onSecondaryContainer,
            child: Icon(icon),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSecondaryContainer.withValues(
                      alpha: 0.9,
                    ),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroHighlight {
  const _HeroHighlight({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

class _HeroHighlightChip extends StatelessWidget {
  const _HeroHighlightChip({required this.highlight});

  final _HeroHighlight highlight;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(highlight.icon, size: 16, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Text(
              highlight.label,
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileSummary extends StatelessWidget {
  const _ProfileSummary({
    required this.rows,
    required this.expanded,
    required this.collapsedCount,
  });

  final List<_SummaryRowData> rows;
  final bool expanded;
  final int collapsedCount;

  @override
  Widget build(BuildContext context) {
    final visibleRows = expanded
        ? rows
        : rows.take(collapsedCount).toList(growable: false);
    return Column(
      children: [
        for (var index = 0; index < visibleRows.length; index += 1)
          _SummaryRow(
            label: visibleRows[index].label,
            value: visibleRows[index].value,
            isLast: index == visibleRows.length - 1,
          ),
      ],
    );
  }
}

class _SummaryRowData {
  const _SummaryRowData({required this.label, required this.value});

  final String label;
  final String value;
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 420;
        return Padding(
          padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
          child: isCompact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(value, style: theme.textTheme.bodyMedium),
                  ],
                )
              : Row(
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
                      child: Text(
                        value,
                        style: theme.textTheme.bodyMedium,
                        softWrap: true,
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}

class _BranchPreviewCard extends StatelessWidget {
  const _BranchPreviewCard({
    required this.branch,
    required this.leaderName,
    required this.viceLeaderName,
    required this.canEdit,
    this.onEdit,
  });

  final BranchProfile branch;
  final String leaderName;
  final String viceLeaderName;
  final bool canEdit;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final leaderDisplay = leaderName.isEmpty ? l10n.clanFieldUnset : leaderName;
    final viceLeaderDisplay = viceLeaderName.isEmpty
        ? l10n.clanFieldUnset
        : viceLeaderName;

    return AppWorkspaceSurface(
      color: Colors.white.withValues(alpha: 0.9),
      padding: const EdgeInsets.all(18),
      child: SizedBox(
        height: 200,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            branch.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            l10n.pick(
                              vi: '${l10n.clanBranchCodeLabel}: ${branch.code} • Đời ${branch.generationLevelHint}',
                              en: '${l10n.clanBranchCodeLabel}: ${branch.code} • Gen ${branch.generationLevelHint}',
                            ),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (canEdit && onEdit != null)
                      PopupMenuButton<String>(
                        tooltip: l10n.pick(vi: 'Tùy chọn', en: 'Options'),
                        onSelected: (value) {
                          if (value == 'edit') {
                            onEdit?.call();
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem<String>(
                            value: 'edit',
                            child: Text(l10n.clanEditBranchAction),
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                _BranchMetaRow(
                  icon: Icons.star_outline,
                  label: l10n.pick(vi: 'Trưởng chi', en: 'Leader'),
                  value: leaderDisplay,
                ),
                const SizedBox(height: 10),
                _BranchMetaRow(
                  icon: Icons.handshake_outlined,
                  label: l10n.pick(vi: 'Phó chi', en: 'Vice leader'),
                  value: viceLeaderDisplay,
                ),
              ],
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MiniPill(
                  icon: Icons.groups_2_outlined,
                  label:
                      '${branch.memberCount} ${l10n.pick(vi: 'thành viên', en: 'members')}',
                ),
                _MiniPill(
                  icon: Icons.hub_outlined,
                  label: l10n.pick(
                    vi: 'Đời ${branch.generationLevelHint}',
                    en: 'Gen ${branch.generationLevelHint}',
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

class _BranchMetaRow extends StatelessWidget {
  const _BranchMetaRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MiniPill extends StatelessWidget {
  const _MiniPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final maxWidth = MediaQuery.sizeOf(context).width - 120;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Text(
                label,
                style: textTheme.bodyLarge,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptySection extends StatelessWidget {
  const _EmptySection({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: colorScheme.secondaryContainer,
              child: Icon(icon),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyWorkspace extends StatelessWidget {
  const _EmptyWorkspace({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 34,
                    backgroundColor: colorScheme.secondaryContainer,
                    child: Icon(icon, size: 32),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ClanEditorSheet extends StatefulWidget {
  const _ClanEditorSheet({required this.initialDraft, required this.onSubmit});

  final ClanDraft initialDraft;
  final Future<bool> Function(ClanDraft draft) onSubmit;

  @override
  State<_ClanEditorSheet> createState() => _ClanEditorSheetState();
}

class _ClanEditorSheetState extends State<_ClanEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _slugController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _countryController;
  late final TextEditingController _founderController;
  late final TextEditingController _logoUrlController;
  int _editorStep = 0;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialDraft.name);
    _slugController = TextEditingController(text: widget.initialDraft.slug);
    _descriptionController = TextEditingController(
      text: widget.initialDraft.description,
    );
    _countryController = TextEditingController(
      text: widget.initialDraft.countryCode,
    );
    _founderController = TextEditingController(
      text: widget.initialDraft.founderName,
    );
    _logoUrlController = TextEditingController(
      text: widget.initialDraft.logoUrl,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _slugController.dispose();
    _descriptionController.dispose();
    _countryController.dispose();
    _founderController.dispose();
    _logoUrlController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_validateCurrentStep()) {
      return;
    }
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final draft = ClanDraft(
      name: _nameController.text.trim(),
      slug: _resolvedSlug,
      description: _descriptionController.text.trim(),
      countryCode: _countryController.text.trim().toUpperCase(),
      founderName: _founderController.text.trim(),
      logoUrl: _logoUrlController.text.trim(),
      status: widget.initialDraft.status,
    );

    final didSave = await widget.onSubmit(draft);
    if (!mounted) {
      return;
    }

    setState(() {
      _isSubmitting = false;
    });

    if (didSave) {
      Navigator.of(context).pop(true);
    }
  }

  String get _resolvedSlug {
    final typed = _slugController.text.trim();
    if (typed.isNotEmpty) {
      return _slugify(typed);
    }

    return _slugify(_nameController.text.trim());
  }

  bool _validateCurrentStep() {
    if (_editorStep != 0) {
      return true;
    }
    final l10n = context.l10n;
    final error = switch ((
      _nameController.text.trim().isEmpty,
      _countryController.text.trim().length < 2,
    )) {
      (true, _) => l10n.pick(
        vi: 'Thiếu thông tin: Hãy nhập tên gia phả trước khi tiếp tục.',
        en: 'Missing info: Please enter the genealogy name before continuing.',
      ),
      (_, true) => l10n.pick(
        vi: 'Thiếu thông tin: Hãy chọn quốc gia trước khi tiếp tục.',
        en: 'Missing info: Please choose the country before continuing.',
      ),
      _ => null,
    };
    if (error == null) {
      return true;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    return false;
  }

  void _goToStep(int nextStep) {
    if (nextStep > _editorStep && !_validateCurrentStep()) {
      return;
    }
    setState(() => _editorStep = nextStep);
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.viewInsetsOf(context);
    final l10n = context.l10n;
    final isEditing = widget.initialDraft.name.trim().isNotEmpty;
    final editorTitle = isEditing
        ? l10n.pick(vi: 'Cập nhật gia phả', en: 'Update genealogy')
        : l10n.pick(vi: 'Tạo gia phả', en: 'Create genealogy');
    final editorDescription = l10n.pick(
      vi: 'Điền vài thông tin cơ bản để bắt đầu gia phả của gia đình.',
      en: 'Add a few essentials to start the family genealogy.',
    );
    return _EditorSheetScaffold(
      formKey: _formKey,
      bottomInset: insets.bottom,
      scrollChild: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 14),
          _CompactEditorHeader(title: editorTitle, subtitle: editorDescription),
          const SizedBox(height: 12),
          AppWorkspaceSurface(
            padding: const EdgeInsets.all(16),
            color: Colors.white.withValues(alpha: 0.76),
            child: _BranchEditorStepIndicator(
              currentStep: _editorStep,
              labels: [
                l10n.pick(vi: 'Thông tin', en: 'Info'),
                l10n.pick(vi: 'Giới thiệu', en: 'Story'),
              ],
              onStepSelected: _goToStep,
            ),
          ),
          const SizedBox(height: 12),
          if (_editorStep == 0)
            _SectionCard(
              title: l10n.pick(vi: 'Thông tin chính', en: 'Core details'),
              description: l10n.pick(
                vi: 'Tên gia phả, quốc gia và người đại diện là phần quan trọng nhất để bắt đầu gọn và dễ hiểu.',
                en: 'Genealogy name, country, and representative are the key details to start clearly.',
              ),
              child: Column(
                children: [
                  TextFormField(
                    key: const Key('clan-name-input'),
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: l10n.clanFieldName,
                      hintText: l10n.clanFieldNameHint,
                    ),
                    textInputAction: TextInputAction.next,
                    validator: (value) {
                      return value == null || value.trim().isEmpty
                          ? l10n.clanValidationNameRequired
                          : null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    key: const Key('clan-country-input'),
                    controller: _countryController,
                    decoration: InputDecoration(
                      labelText: l10n.clanFieldCountry,
                      hintText: l10n.pick(vi: 'VN', en: 'VN'),
                    ),
                    textCapitalization: TextCapitalization.characters,
                    textInputAction: TextInputAction.next,
                    validator: (value) {
                      return value == null || value.trim().length < 2
                          ? l10n.clanValidationCountryRequired
                          : null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    key: const Key('clan-founder-input'),
                    controller: _founderController,
                    decoration: InputDecoration(
                      labelText: l10n.clanFieldFounder,
                      hintText: l10n.clanFieldFounderHint,
                    ),
                    textInputAction: TextInputAction.next,
                  ),
                ],
              ),
            ),
          if (_editorStep == 1)
            _SectionCard(
              title: l10n.pick(
                vi: 'Giới thiệu & chia sẻ',
                en: 'Story & sharing',
              ),
              description: l10n.pick(
                vi: 'Thêm liên kết chia sẻ, ảnh đại diện và vài dòng giới thiệu để gia phả trông hoàn chỉnh hơn.',
                en: 'Add a share link, avatar, and a short intro so the genealogy feels complete.',
              ),
              child: Column(
                children: [
                  TextFormField(
                    key: const Key('clan-slug-input'),
                    controller: _slugController,
                    decoration: InputDecoration(
                      labelText: l10n.pick(
                        vi: 'Đường dẫn chia sẻ',
                        en: 'Share link',
                      ),
                      hintText: l10n.pick(
                        vi: 'vi-du-ho-nguyen-van',
                        en: 'example-clan-link',
                      ),
                      helperText: l10n.pick(
                        vi: 'Để trống để hệ thống tự tạo từ tên gia phả.',
                        en: 'Leave blank to generate it from the genealogy name.',
                      ),
                    ),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    key: const Key('clan-logo-url-input'),
                    controller: _logoUrlController,
                    decoration: InputDecoration(
                      labelText: l10n.clanFieldLogoUrl,
                      hintText: l10n.pick(vi: 'https://...', en: 'https://...'),
                    ),
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    key: const Key('clan-description-input'),
                    controller: _descriptionController,
                    decoration: InputDecoration(
                      labelText: l10n.clanFieldDescription,
                      hintText: l10n.clanFieldDescriptionHint,
                    ),
                    maxLines: 4,
                    minLines: 3,
                    textInputAction: TextInputAction.newline,
                  ),
                ],
              ),
            ),
        ],
      ),
      footer: AppWorkspaceSurface(
        padding: const EdgeInsets.all(16),
        color: Colors.white.withValues(alpha: 0.76),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 520;
            final secondaryButton = OutlinedButton.icon(
              onPressed: _isSubmitting
                  ? null
                  : () {
                      if (_editorStep == 0) {
                        Navigator.of(context).pop(false);
                        return;
                      }
                      setState(() => _editorStep = 0);
                    },
              icon: Icon(
                _editorStep == 0 ? Icons.close_outlined : Icons.arrow_back,
              ),
              label: Text(
                _editorStep == 0
                    ? l10n.pick(vi: 'Hủy', en: 'Cancel')
                    : l10n.pick(vi: 'Quay lại', en: 'Back'),
              ),
            );
            final primaryButton = _editorStep == 0
                ? FilledButton.icon(
                    onPressed: _isSubmitting
                        ? null
                        : () {
                            if (!_validateCurrentStep()) {
                              return;
                            }
                            setState(() => _editorStep = 1);
                          },
                    icon: const Icon(Icons.arrow_forward),
                    label: Text(l10n.pick(vi: 'Tiếp tục', en: 'Continue')),
                  )
                : FilledButton.icon(
                    key: const Key('clan-save-button'),
                    onPressed: _isSubmitting ? null : _submit,
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(
                      isEditing
                          ? l10n.clanSaveAction
                          : l10n.pick(
                              vi: 'Tạo gia phả',
                              en: 'Create genealogy',
                            ),
                    ),
                  );

            if (compact) {
              return Column(
                children: [
                  SizedBox(width: double.infinity, child: secondaryButton),
                  const SizedBox(height: 10),
                  SizedBox(width: double.infinity, child: primaryButton),
                ],
              );
            }

            return Row(
              children: [
                Expanded(child: secondaryButton),
                const SizedBox(width: 10),
                Expanded(child: primaryButton),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _BranchEditorSheet extends StatefulWidget {
  const _BranchEditorSheet({
    required this.members,
    required this.initialDraft,
    required this.onSubmit,
  });

  final List<ClanMemberSummary> members;
  final BranchDraft initialDraft;
  final Future<bool> Function(BranchDraft draft) onSubmit;

  @override
  State<_BranchEditorSheet> createState() => _BranchEditorSheetState();
}

class _BranchEditorSheetState extends State<_BranchEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _codeController;
  late final TextEditingController _generationController;
  String? _leaderMemberId;
  String? _viceLeaderMemberId;
  int _editorStep = 0;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialDraft.name);
    _codeController = TextEditingController(text: widget.initialDraft.code);
    _generationController = TextEditingController(
      text: '${widget.initialDraft.generationLevelHint}',
    );
    _leaderMemberId = widget.initialDraft.leaderMemberId;
    _viceLeaderMemberId = widget.initialDraft.viceLeaderMemberId;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _generationController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_ensureIdentityStepReadyForSubmit()) {
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_leaderMemberId != null && _leaderMemberId == _viceLeaderMemberId) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.clanValidationViceDistinct)),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final draft = BranchDraft(
      name: _nameController.text.trim(),
      code: _codeController.text.trim().toUpperCase(),
      generationLevelHint: int.tryParse(_generationController.text.trim()) ?? 1,
      leaderMemberId: _leaderMemberId,
      viceLeaderMemberId: _viceLeaderMemberId,
      status: widget.initialDraft.status,
    );

    final didSave = await widget.onSubmit(draft);
    if (!mounted) {
      return;
    }

    setState(() {
      _isSubmitting = false;
    });

    if (didSave) {
      Navigator.of(context).pop(true);
    }
  }

  bool _ensureIdentityStepReadyForSubmit() {
    final l10n = context.l10n;
    final error = switch ((
      _nameController.text.trim().isEmpty,
      _codeController.text.trim().isEmpty,
      int.tryParse(_generationController.text.trim()) == null ||
          (int.tryParse(_generationController.text.trim()) ?? 0) <= 0,
    )) {
      (true, _, _) => l10n.pick(
        vi: 'Thiếu thông tin: Hãy nhập tên chi trước khi lưu.',
        en: 'Missing info: Please enter the branch name before saving.',
      ),
      (_, true, _) => l10n.pick(
        vi: 'Thiếu thông tin: Hãy nhập mã chi trước khi lưu.',
        en: 'Missing info: Please enter the branch code before saving.',
      ),
      (_, _, true) => l10n.pick(
        vi: 'Thiếu thông tin: Hãy nhập đời bắt đầu hợp lệ.',
        en: 'Missing info: Please enter a valid generation hint.',
      ),
      _ => null,
    };
    if (error == null) {
      return true;
    }
    setState(() => _editorStep = 0);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    return false;
  }

  bool _validateCurrentStep() {
    if (_editorStep == 0) {
      return _formKey.currentState?.validate() ?? false;
    }
    return true;
  }

  void _goToStep(int nextStep) {
    if (nextStep > _editorStep && !_validateCurrentStep()) {
      return;
    }
    setState(() => _editorStep = nextStep);
  }

  String _memberOptionLabel(ClanMemberSummary member, AppLocalizations l10n) {
    return '${member.shortLabel} • ${l10n.roleLabel(member.primaryRole)}';
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.viewInsetsOf(context);
    final l10n = context.l10n;
    final members = widget.members;
    final isEditing =
        widget.initialDraft.name.trim().isNotEmpty ||
        widget.initialDraft.code.trim().isNotEmpty;
    final editorTitle = isEditing
        ? l10n.pick(vi: 'Cập nhật chi', en: 'Update branch')
        : l10n.pick(vi: 'Thêm chi mới', en: 'Create branch');
    final editorDescription = l10n.pick(
      vi: 'Điền tên chi và người phụ trách để gia phả của gia đình rõ ràng hơn.',
      en: 'Add the branch name and leads so the family tree stays clear.',
    );

    return _EditorSheetScaffold(
      formKey: _formKey,
      bottomInset: insets.bottom,
      scrollChild: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 14),
          _CompactEditorHeader(title: editorTitle, subtitle: editorDescription),
          const SizedBox(height: 12),
          AppWorkspaceSurface(
            padding: const EdgeInsets.all(16),
            color: Colors.white.withValues(alpha: 0.76),
            child: _BranchEditorStepIndicator(
              currentStep: _editorStep,
              labels: [
                l10n.pick(vi: 'Nhận diện', en: 'Identity'),
                l10n.pick(vi: 'Điều hành', en: 'Leadership'),
              ],
              onStepSelected: _goToStep,
            ),
          ),
          const SizedBox(height: 12),
          if (_editorStep == 0)
            _SectionCard(
              title: l10n.pick(vi: 'Nhận diện chi', en: 'Branch identity'),
              description: l10n.pick(
                vi: 'Tên chi, mã chi và đời bắt đầu nên được chốt ở bước đầu để phần còn lại nhất quán hơn.',
                en: 'Keep branch name, code, and starting generation together in the first step so the rest stays consistent.',
              ),
              child: Column(
                children: [
                  TextFormField(
                    key: const Key('branch-name-input'),
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: l10n.clanBranchNameLabel,
                      hintText: l10n.clanBranchNameHint,
                    ),
                    textInputAction: TextInputAction.next,
                    validator: (value) {
                      return value == null || value.trim().isEmpty
                          ? l10n.clanValidationBranchNameRequired
                          : null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    key: const Key('branch-code-input'),
                    controller: _codeController,
                    decoration: InputDecoration(
                      labelText: l10n.clanBranchCodeLabel,
                      hintText: l10n.clanBranchCodeHint,
                    ),
                    textCapitalization: TextCapitalization.characters,
                    textInputAction: TextInputAction.next,
                    validator: (value) {
                      return value == null || value.trim().isEmpty
                          ? l10n.clanValidationBranchCodeRequired
                          : null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    key: const Key('branch-generation-input'),
                    controller: _generationController,
                    decoration: InputDecoration(
                      labelText: l10n.pick(
                        vi: 'Đời bắt đầu',
                        en: 'Starting generation',
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    validator: (value) {
                      final parsed = int.tryParse(value ?? '');
                      return parsed == null || parsed <= 0
                          ? l10n.clanValidationGenerationRequired
                          : null;
                    },
                  ),
                ],
              ),
            ),
          if (_editorStep == 1)
            _SectionCard(
              title: l10n.pick(vi: 'Điều hành chi', en: 'Branch leadership'),
              description: l10n.pick(
                vi: 'Chọn trưởng chi và phó chi để sơ đồ điều hành rõ ràng hơn ngay khi tạo mới.',
                en: 'Assign the branch leader and vice leader so the leadership structure is clear from the start.',
              ),
              child: Column(
                children: [
                  DropdownButtonFormField<String?>(
                    key: const Key('branch-leader-input'),
                    initialValue: _leaderMemberId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: l10n.clanLeaderLabel,
                    ),
                    items: [
                      DropdownMenuItem<String?>(
                        value: null,
                        child: Text(l10n.clanNoLeaderOption),
                      ),
                      for (final member in members)
                        DropdownMenuItem<String?>(
                          value: member.id,
                          child: Text(
                            _memberOptionLabel(member, l10n),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _leaderMemberId = value;
                      });
                    },
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String?>(
                    key: const Key('branch-vice-input'),
                    initialValue: _viceLeaderMemberId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: l10n.clanViceLeaderLabel,
                    ),
                    items: [
                      DropdownMenuItem<String?>(
                        value: null,
                        child: Text(l10n.clanNoViceLeaderOption),
                      ),
                      for (final member in members)
                        DropdownMenuItem<String?>(
                          value: member.id,
                          child: Text(
                            _memberOptionLabel(member, l10n),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _viceLeaderMemberId = value;
                      });
                    },
                  ),
                ],
              ),
            ),
        ],
      ),
      footer: AppWorkspaceSurface(
        padding: const EdgeInsets.all(16),
        color: Colors.white.withValues(alpha: 0.76),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 520;
            final secondaryButton = OutlinedButton.icon(
              onPressed: _isSubmitting
                  ? null
                  : () {
                      if (_editorStep == 0) {
                        Navigator.of(context).pop(false);
                        return;
                      }
                      setState(() => _editorStep = 0);
                    },
              icon: Icon(
                _editorStep == 0 ? Icons.close_outlined : Icons.arrow_back,
              ),
              label: Text(
                _editorStep == 0
                    ? l10n.pick(vi: 'Hủy', en: 'Cancel')
                    : l10n.pick(vi: 'Quay lại', en: 'Back'),
              ),
            );
            final primaryButton = _editorStep == 0
                ? FilledButton.icon(
                    onPressed: _isSubmitting
                        ? null
                        : () {
                            if (!_validateCurrentStep()) {
                              return;
                            }
                            setState(() => _editorStep = 1);
                          },
                    icon: const Icon(Icons.arrow_forward),
                    label: Text(l10n.pick(vi: 'Tiếp tục', en: 'Continue')),
                  )
                : FilledButton.icon(
                    key: const Key('branch-save-button'),
                    onPressed: _isSubmitting ? null : _submit,
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(
                      l10n.pick(vi: 'Lưu thay đổi', en: 'Save changes'),
                    ),
                  );

            if (compact) {
              return Column(
                children: [
                  SizedBox(width: double.infinity, child: secondaryButton),
                  const SizedBox(height: 10),
                  SizedBox(width: double.infinity, child: primaryButton),
                ],
              );
            }

            return Row(
              children: [
                Expanded(child: secondaryButton),
                const SizedBox(width: 10),
                Expanded(child: primaryButton),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _BranchEditorStepIndicator extends StatelessWidget {
  const _BranchEditorStepIndicator({
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
    const labelRowHeight = 40.0;

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
              for (var index = 0; index < labels.length; index++)
                Expanded(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
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
          ),
        ),
      ],
    );
  }
}

String _slugify(String value) {
  return value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
}
