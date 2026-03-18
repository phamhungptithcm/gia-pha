import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/services/governance_role_matrix.dart';
import '../../../core/widgets/app_feedback_states.dart';
import '../../../l10n/l10n.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/models/auth_session.dart';
import '../../auth/models/clan_context_option.dart';
import '../../discovery/presentation/join_request_review_page.dart';
import '../../discovery/services/genealogy_discovery_repository.dart';
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
  });

  final AuthSession session;
  final ClanRepository repository;
  final List<ClanContextOption> availableClanContexts;
  final Future<AuthSession?> Function(String clanId)? onSwitchClanContext;

  @override
  State<ClanDetailPage> createState() => _ClanDetailPageState();
}

class _ClanDetailPageState extends State<ClanDetailPage> {
  late ClanController _controller;
  late AuthSession _session;
  bool _isSwitchingClanContext = false;
  bool _isHeroDescriptionExpanded = false;
  bool _isProfileDetailsExpanded = false;

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
    unawaited(_controller.initialize());
  }

  ClanController _createController(AuthSession session) {
    return ClanController(repository: widget.repository, session: session);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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

    if (didSave == true && mounted) {
      final createdFromUnlinkedSession =
          (_session.clanId ?? '').trim().isEmpty &&
          _controller.permissions.canBootstrapClan;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            createdFromUnlinkedSession
                ? context.l10n.pick(
                    vi: 'Đã tạo gia phả mới. Nếu chưa thấy dữ liệu đầy đủ, vui lòng đăng xuất và đăng nhập lại.',
                    en: 'New clan workspace created. If data is not fully visible yet, please sign out and sign in again.',
                  )
                : context.l10n.clanSaveSuccess,
          ),
        ),
      );
    }
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

  List<ClanContextOption> get _clanContexts {
    final options = widget.availableClanContexts;
    if (options.isNotEmpty) {
      return options;
    }
    final clanId = (_session.clanId ?? '').trim();
    if (clanId.isEmpty) {
      return const [];
    }
    return [
      ClanContextOption(
        clanId: clanId,
        clanName: _controller.clan?.name ?? clanId,
        memberId: (_session.memberId ?? '').trim(),
        primaryRole: (_session.primaryRole ?? 'MEMBER').trim().isEmpty
            ? 'MEMBER'
            : _session.primaryRole!.trim().toUpperCase(),
        branchId: (_session.branchId ?? '').trim().isEmpty
            ? null
            : _session.branchId!.trim(),
        displayName: _session.displayName,
        ownerUid: _session.uid.trim().isEmpty ? null : _session.uid.trim(),
        ownerDisplayName: _session.displayName,
      ),
    ];
  }

  Future<void> _openClanSwitcher() async {
    if (_clanContexts.length < 2 ||
        _isSwitchingClanContext ||
        widget.onSwitchClanContext == null) {
      return;
    }
    final selected = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) {
        return _ClanContextPickerSheet(
          activeClanId:
              _lastSelectedClanByUid[_session.uid] ??
              (_session.clanId ?? '').trim(),
          contexts: _clanContexts,
          roleLabelBuilder: (role) => context.l10n.roleLabel(role),
          ownerLabelBuilder: (option) {
            final ownerLabel =
                (option.ownerDisplayName ?? option.ownerUid ?? '').trim();
            return ownerLabel.isEmpty
                ? context.l10n.pick(vi: 'Owner: --', en: 'Owner: --')
                : context.l10n.pick(
                    vi: 'Owner: $ownerLabel',
                    en: 'Owner: $ownerLabel',
                  );
          },
          planLabelBuilder: (option) {
            final planCode = (option.billingPlanCode ?? '').trim().toUpperCase();
            return planCode.isEmpty
                ? context.l10n.pick(vi: 'Gói: --', en: 'Plan: --')
                : context.l10n.pick(
                    vi: 'Gói: $planCode',
                    en: 'Plan: $planCode',
                  );
          },
          statusLabelBuilder: (status) =>
              _contextStatusLabel(context.l10n, status),
          memberCountLabelBuilder: (option) {
            final activeClanId = (_session.clanId ?? '').trim();
            if (option.clanId.trim() == activeClanId) {
              final count =
                  _controller.clan?.memberCount ?? _controller.members.length;
              return context.l10n.pick(
                vi: '$count thành viên',
                en: '$count members',
              );
            }
            return context.l10n.pick(vi: 'Thành viên: --', en: 'Members: --');
          },
        );
      },
    );
    if (!mounted || selected == null) {
      return;
    }
    await _switchClanContext(selected);
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
        _isHeroDescriptionExpanded = false;
        _isProfileDetailsExpanded = false;
      });
      previous.dispose();
      await _controller.initialize();
    } finally {
      if (mounted) {
        setState(() => _isSwitchingClanContext = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        final l10n = context.l10n;
        final profileRows = _profileRows();

        return Scaffold(
          appBar: AppBar(
            title: Text(l10n.clanDetailTitle),
            actions: [
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
                onPressed: _controller.isLoading ? null : _controller.refresh,
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
                    description: l10n.clanNoContextDescription,
                  )
                : RefreshIndicator(
                    onRefresh: _controller.refresh,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                      children: [
                        if (_clanContexts.length > 1) ...[
                          _ClanContextSwitcherCard(
                            activeClanId: (_session.clanId ?? '').trim(),
                            activeClanName:
                                _controller.clan?.name ??
                                l10n.pick(
                                  vi: 'Chưa chọn gia phả',
                                  en: 'No clan',
                                ),
                            isEnabled: widget.onSwitchClanContext != null,
                            isSwitching: _isSwitchingClanContext,
                            onTap: _openClanSwitcher,
                          ),
                          const SizedBox(height: 16),
                        ],
                        _WorkspaceHero(
                          title:
                              _controller.clan?.name ??
                              l10n.clanCreateFirstTitle,
                          description:
                              _controller.clan?.description.isNotEmpty == true
                              ? _controller.clan!.description
                              : l10n.clanCreateFirstDescription,
                          isDescriptionExpanded: _isHeroDescriptionExpanded,
                          onToggleDescription: () {
                            setState(() {
                              _isHeroDescriptionExpanded =
                                  !_isHeroDescriptionExpanded;
                            });
                          },
                        ),
                        const SizedBox(height: 20),
                        if (_controller.errorMessage != null) ...[
                          _InfoCard(
                            icon: Icons.error_outline,
                            title: l10n.clanLoadErrorTitle,
                            description:
                                _controller.errorMessage == 'permission_denied'
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
                          const SizedBox(height: 20),
                        ],
                        if (_controller.permissions.isReadOnly) ...[
                          _InfoCard(
                            icon: Icons.visibility_outlined,
                            title: l10n.clanReadOnlyTitle,
                            description: l10n.clanReadOnlyDescription,
                            tone: colorScheme.secondaryContainer,
                          ),
                          const SizedBox(height: 20),
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
                        const SizedBox(height: 20),
                        _SectionCard(
                          title: l10n.clanProfileSectionTitle,
                          child: _controller.clan == null
                              ? _EmptySection(
                                  icon: Icons.domain_add_outlined,
                                  title: l10n.clanProfileEmptyTitle,
                                  description: l10n.clanProfileEmptyDescription,
                                )
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _ProfileSummary(
                                      rows: profileRows,
                                      expanded: _isProfileDetailsExpanded,
                                      collapsedCount: 3,
                                    ),
                                    if (profileRows.length > 3)
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
                        const SizedBox(height: 20),
                        _SectionCard(
                          title: l10n.clanBranchSectionTitle,
                          actionLabel: _controller.permissions.canManageBranches
                              ? l10n.clanAddBranchAction
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
                                    label: Text(l10n.clanOpenBranchListAction),
                                  ),
                                )
                              : null,
                          child: _controller.branches.isEmpty
                              ? _EmptySection(
                                  icon: Icons.fork_right_outlined,
                                  title: l10n.clanBranchEmptyTitle,
                                  description: l10n.clanBranchEmptyDescription,
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
                                              : 14,
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
                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
          ),
          floatingActionButton: _controller.permissions.canEditClanSettings
              ? FloatingActionButton(
                  key: const Key('clan-edit-fab'),
                  onPressed: _openClanEditor,
                  tooltip: _controller.clan == null
                      ? l10n.clanCreateAction
                      : l10n.clanEditAction,
                  child: Icon(
                    _controller.clan == null ? Icons.add : Icons.edit_outlined,
                  ),
                )
              : null,
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
    return [
      _SummaryRowData(label: l10n.clanFieldName, value: clan.name),
      _SummaryRowData(label: l10n.clanFieldSlug, value: clan.slug),
      _SummaryRowData(
        label: l10n.clanFieldCountry,
        value: clan.countryCode.trim().isEmpty
            ? l10n.clanFieldUnset
            : clan.countryCode,
      ),
      _SummaryRowData(
        label: l10n.clanFieldFounder,
        value: clan.founderName.isEmpty
            ? l10n.clanFieldUnset
            : clan.founderName,
      ),
      _SummaryRowData(
        label: l10n.clanFieldDescription,
        value: clan.description.isEmpty
            ? l10n.clanFieldUnset
            : clan.description,
      ),
    ];
  }
}

class _WorkspaceHero extends StatelessWidget {
  const _WorkspaceHero({
    required this.title,
    required this.description,
    required this.isDescriptionExpanded,
    required this.onToggleDescription,
  });

  final String title;
  final String description;
  final bool isDescriptionExpanded;
  final VoidCallback onToggleDescription;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(20),
      ),
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
          const SizedBox(height: 10),
          Text(
            description,
            maxLines: isDescriptionExpanded ? null : 2,
            overflow: isDescriptionExpanded ? null : TextOverflow.ellipsis,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colorScheme.onPrimaryContainer.withValues(alpha: 0.9),
            ),
          ),
          if (description.trim().length > 80)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: onToggleDescription,
                child: Text(
                  isDescriptionExpanded
                      ? l10n.pick(vi: 'Thu gọn', en: 'Collapse')
                      : l10n.pick(vi: 'Xem thêm', en: 'View more'),
                  style: TextStyle(color: colorScheme.onPrimaryContainer),
                ),
              ),
            ),
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
    this.footer,
  });

  final String title;
  final Widget child;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                    icon: const Icon(Icons.add_circle_outline),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(44, 44),
                    ),
                    label: Text(actionLabel!),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            child,
            if (footer != null) ...[const SizedBox(height: 12), footer!],
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
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
    final colorScheme = theme.colorScheme;

    return Card(
      color: tone,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
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

    return Card(
      color: colorScheme.secondaryContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon),
            const SizedBox(height: 8),
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: theme.textTheme.bodyMedium,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _ClanContextSwitcherCard extends StatelessWidget {
  const _ClanContextSwitcherCard({
    required this.activeClanId,
    required this.activeClanName,
    required this.isEnabled,
    required this.isSwitching,
    required this.onTap,
  });

  final String activeClanId;
  final String activeClanName;
  final bool isEnabled;
  final bool isSwitching;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: isSwitching || !isEnabled ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              const Icon(Icons.account_tree_outlined),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.pick(vi: 'Gia phả hiện tại', en: 'Current clan'),
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      activeClanName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (activeClanId.isNotEmpty)
                      Text(
                        activeClanId,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (isSwitching)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                const Icon(Icons.expand_more),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClanContextPickerSheet extends StatelessWidget {
  const _ClanContextPickerSheet({
    required this.activeClanId,
    required this.contexts,
    required this.roleLabelBuilder,
    required this.ownerLabelBuilder,
    required this.planLabelBuilder,
    required this.statusLabelBuilder,
    required this.memberCountLabelBuilder,
  });

  final String activeClanId;
  final List<ClanContextOption> contexts;
  final String Function(String? role) roleLabelBuilder;
  final String Function(ClanContextOption option) ownerLabelBuilder;
  final String Function(ClanContextOption option) planLabelBuilder;
  final String Function(String? status) statusLabelBuilder;
  final String Function(ClanContextOption option) memberCountLabelBuilder;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text(
            l10n.pick(vi: 'Chọn gia phả', en: 'Switch clan'),
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.pick(
              vi: 'Mỗi tài khoản có thể thuộc nhiều gia phả. Chọn một gia phả để tiếp tục.',
              en: 'Your account can belong to multiple clans. Pick one to continue.',
            ),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 14),
          for (final option in contexts)
            Card(
              child: ListTile(
                minVerticalPadding: 10,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                onTap: () => Navigator.of(context).pop(option.clanId),
                leading: Icon(
                  option.clanId.trim() == activeClanId.trim()
                      ? Icons.check_circle
                      : Icons.circle_outlined,
                ),
                title: Text(
                  option.clanName.trim().isEmpty
                      ? option.clanId
                      : option.clanName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${roleLabelBuilder(option.primaryRole)} · '
                    '${planLabelBuilder(option)} · '
                    '${ownerLabelBuilder(option)} · '
                    '${memberCountLabelBuilder(option)} · '
                    '${statusLabelBuilder(option.status)}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                trailing: const Icon(Icons.chevron_right),
              ),
            ),
        ],
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
    final colorScheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.46),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
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
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${l10n.clanBranchCodeLabel}: ${branch.code}',
                        style: theme.textTheme.bodyMedium,
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
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _MiniPill(
                  icon: Icons.star_outline,
                  label:
                      '${l10n.clanLeaderLabel}: '
                      '${leaderName.isEmpty ? l10n.clanFieldUnset : leaderName}',
                ),
                _MiniPill(
                  icon: Icons.handshake_outlined,
                  label:
                      '${l10n.clanViceLeaderLabel}: '
                      '${viceLeaderName.isEmpty ? l10n.clanFieldUnset : viceLeaderName}',
                ),
                _MiniPill(
                  icon: Icons.hub_outlined,
                  label:
                      '${l10n.clanGenerationHintLabel}: ${branch.generationLevelHint}',
                ),
              ],
            ),
          ],
        ),
      ),
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

String _contextStatusLabel(AppLocalizations l10n, String? status) {
  final normalized = status?.trim().toLowerCase() ?? '';
  return switch (normalized) {
    'active' || 'enabled' || '' => l10n.pick(vi: 'Đang dùng', en: 'Active'),
    'pending' => l10n.pick(vi: 'Chờ kích hoạt', en: 'Pending'),
    'suspended' || 'disabled' => l10n.pick(vi: 'Tạm ngưng', en: 'Suspended'),
    _ => l10n.pick(vi: 'Đang dùng', en: 'Active'),
  };
}

class _EmptySection extends StatelessWidget {
  const _EmptySection({
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

class _EmptyWorkspace extends StatelessWidget {
  const _EmptyWorkspace({
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
                  const SizedBox(height: 10),
                  Text(
                    description,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge,
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
                  l10n.clanEditorTitle,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  l10n.clanEditorDescription,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 20),
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
                  key: const Key('clan-slug-input'),
                  controller: _slugController,
                  decoration: InputDecoration(
                    labelText: l10n.clanFieldSlug,
                    hintText: l10n.clanFieldSlugHint,
                    helperText: l10n.clanFieldSlugHelper,
                  ),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  key: const Key('clan-country-input'),
                  controller: _countryController,
                  decoration: InputDecoration(
                    labelText: l10n.clanFieldCountry,
                    hintText: 'VN',
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
                const SizedBox(height: 14),
                TextFormField(
                  key: const Key('clan-logo-url-input'),
                  controller: _logoUrlController,
                  decoration: InputDecoration(
                    labelText: l10n.clanFieldLogoUrl,
                    hintText: 'https://...',
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
                const SizedBox(height: 22),
                FilledButton.icon(
                  key: const Key('clan-save-button'),
                  onPressed: _isSubmitting ? null : _submit,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(l10n.clanSaveAction),
                ),
              ],
            ),
          ),
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

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.viewInsetsOf(context);
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final members = widget.members;

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
                  l10n.clanBranchEditorTitle,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  l10n.clanBranchEditorDescription,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 20),
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
                    labelText: l10n.clanGenerationHintLabel,
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
                const SizedBox(height: 14),
                DropdownButtonFormField<String?>(
                  key: const Key('branch-leader-input'),
                  initialValue: _leaderMemberId,
                  decoration: InputDecoration(labelText: l10n.clanLeaderLabel),
                  items: [
                    DropdownMenuItem<String?>(
                      value: null,
                      child: Text(l10n.clanNoLeaderOption),
                    ),
                    for (final member in members)
                      DropdownMenuItem<String?>(
                        value: member.id,
                        child: Text(
                          '${member.shortLabel} • ${l10n.roleLabel(member.primaryRole)}',
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
                          '${member.shortLabel} • ${l10n.roleLabel(member.primaryRole)}',
                        ),
                      ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _viceLeaderMemberId = value;
                    });
                  },
                ),
                const SizedBox(height: 22),
                FilledButton.icon(
                  key: const Key('branch-save-button'),
                  onPressed: _isSubmitting ? null : _submit,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(l10n.clanSaveAction),
                ),
              ],
            ),
          ),
        ),
      ),
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
