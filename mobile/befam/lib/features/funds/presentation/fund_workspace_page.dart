import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/services/governance_role_matrix.dart';
import '../../../core/services/kinship_title_resolver.dart';
import '../../../core/widgets/app_feedback_states.dart';
import '../../../l10n/l10n.dart';
import '../../auth/models/auth_session.dart';
import '../../auth/models/clan_context_option.dart';
import '../../member/models/member_profile.dart';
import '../../member/services/member_repository.dart';
import '../models/fund_draft.dart';
import '../models/fund_profile.dart';
import '../models/fund_transaction.dart';
import '../models/fund_transaction_draft.dart';
import '../models/treasurer_dashboard_snapshot.dart';
import '../services/currency_minor_units.dart';
import '../services/fund_repository.dart';
import '../services/treasurer_dashboard_repository.dart';
import 'fund_controller.dart';

class FundWorkspacePage extends StatefulWidget {
  const FundWorkspacePage({
    super.key,
    required this.session,
    required this.repository,
    this.treasurerDashboardRepository,
    this.memberRepository,
    this.availableClanContexts = const [],
  });

  final AuthSession session;
  final FundRepository repository;
  final TreasurerDashboardRepository? treasurerDashboardRepository;
  final MemberRepository? memberRepository;
  final List<ClanContextOption> availableClanContexts;

  @override
  State<FundWorkspacePage> createState() => _FundWorkspacePageState();
}

class _FundWorkspacePageState extends State<FundWorkspacePage> {
  static const int _fundBatchSize = 10;

  late FundController _controller;
  late AuthSession _activeSession;
  late MemberRepository _memberRepository;
  late TreasurerDashboardRepository _treasurerDashboardRepository;
  late final ScrollController _workspaceScrollController;
  String _cachedMembersClanId = '';
  List<MemberProfile> _cachedMembers = const [];
  List<MemberProfile> _treasurerMembers = const [];
  String _treasurerClanId = '';
  bool _isLoadingTreasurers = false;
  bool _hasResolvedTreasurers = false;
  bool _treasurerLookupFailed = false;
  bool _isExportingTreasurerReport = false;
  int _treasurerRequestToken = 0;
  int _visibleFundCount = _fundBatchSize;
  String _fundListSeed = '';

  AuthSession get _session => _activeSession;

  List<ClanContextOption> get _clanContexts {
    return widget.availableClanContexts;
  }

  @override
  void initState() {
    super.initState();
    _activeSession = widget.session;
    _memberRepository =
        widget.memberRepository ??
        createDefaultMemberRepository(session: _session);
    _treasurerDashboardRepository =
        widget.treasurerDashboardRepository ??
        createDefaultTreasurerDashboardRepository(session: _session);
    _controller = FundController(
      repository: widget.repository,
      session: _session,
      treasurerDashboardRepository: _treasurerDashboardRepository,
    );
    _workspaceScrollController = ScrollController()
      ..addListener(_handleWorkspaceScroll);
    unawaited(_controller.initialize());
    unawaited(_refreshTreasurerRoster(force: true));
  }

  @override
  void didUpdateWidget(covariant FundWorkspacePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final sessionChanged = oldWidget.session != widget.session;
    final repositoryChanged = oldWidget.repository != widget.repository;
    final memberRepositoryChanged =
        oldWidget.memberRepository != widget.memberRepository;
    final treasurerRepositoryChanged =
        oldWidget.treasurerDashboardRepository !=
        widget.treasurerDashboardRepository;
    if (!sessionChanged &&
        !repositoryChanged &&
        !memberRepositoryChanged &&
        !treasurerRepositoryChanged) {
      return;
    }

    _activeSession = widget.session;
    if (memberRepositoryChanged) {
      _memberRepository =
          widget.memberRepository ??
          createDefaultMemberRepository(session: _session);
    }
    if (sessionChanged || treasurerRepositoryChanged) {
      _treasurerDashboardRepository =
          widget.treasurerDashboardRepository ??
          createDefaultTreasurerDashboardRepository(session: _session);
    }
    _cachedMembers = const [];
    _cachedMembersClanId = '';
    _controller.dispose();
    _controller = FundController(
      repository: widget.repository,
      session: _session,
      treasurerDashboardRepository: _treasurerDashboardRepository,
    );
    unawaited(_controller.initialize());
    unawaited(_refreshTreasurerRoster(force: true));
  }

  @override
  void dispose() {
    _workspaceScrollController
      ..removeListener(_handleWorkspaceScroll)
      ..dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleWorkspaceScroll() {
    if (!_workspaceScrollController.hasClients) {
      return;
    }
    final position = _workspaceScrollController.position;
    if (position.pixels < position.maxScrollExtent - 240) {
      return;
    }
    _loadMoreFundsIfNeeded();
  }

  void _syncVisibleFundWindow(List<FundProfile> funds) {
    final firstId = funds.isEmpty ? '' : funds.first.id;
    final lastId = funds.isEmpty ? '' : funds.last.id;
    final seed = '${funds.length}|$firstId|$lastId';
    if (_fundListSeed == seed) {
      if (_visibleFundCount > funds.length) {
        _visibleFundCount = funds.length;
      }
      return;
    }
    _fundListSeed = seed;
    _visibleFundCount = funds.length < _fundBatchSize
        ? funds.length
        : _fundBatchSize;
  }

  void _loadMoreFundsIfNeeded() {
    final total = _controller.funds.length;
    if (_visibleFundCount >= total) {
      return;
    }
    setState(() {
      final next = _visibleFundCount + _fundBatchSize;
      _visibleFundCount = next < total ? next : total;
    });
  }

  Future<void> _openFundEditor({FundProfile? fund}) async {
    final l10n = context.l10n;
    final didSave = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _FundEditorSheet(
          title: fund == null
              ? l10n.pick(vi: 'Tạo quỹ', en: 'Create fund')
              : l10n.pick(vi: 'Chỉnh sửa quỹ', en: 'Edit fund'),
          description: l10n.pick(
            vi: 'Thiết lập quỹ để ghi nhận thu, chi và số dư.',
            en: 'Set up a fund to track income, expense, and balance.',
          ),
          initialDraft: fund == null
              ? FundDraft.empty()
              : FundDraft.fromProfile(fund),
          activeClanId: (_session.clanId ?? '').trim(),
          activeClanLabel: _clanDisplayNameForId(
            context,
            (_session.clanId ?? '').trim(),
          ),
          resolveViewerMemberId: () => _session.memberId,
          loadMembersForClan: _loadMembersForClan,
          isSaving: _controller.isSavingFund,
          onSubmit: (draft) {
            return _controller.saveFund(fundId: fund?.id, draft: draft);
          },
        );
      },
    );

    if (didSave == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            fund == null
                ? l10n.pick(
                    vi: 'Tạo quỹ thành công.',
                    en: 'Fund created successfully.',
                  )
                : l10n.pick(
                    vi: 'Cập nhật quỹ thành công.',
                    en: 'Fund updated successfully.',
                  ),
          ),
        ),
      );
    }
  }

  Future<List<MemberProfile>> _loadMembersForClan(String clanId) async {
    final normalizedClanId = clanId.trim();
    if (normalizedClanId.isEmpty) {
      return const [];
    }
    if (_cachedMembersClanId == normalizedClanId && _cachedMembers.isNotEmpty) {
      return _cachedMembers;
    }

    if ((_session.clanId ?? '').trim() != normalizedClanId) {
      return const [];
    }

    final snapshot = await _memberRepository.loadWorkspace(session: _session);
    final members = snapshot.members
        .where((member) => member.clanId.trim() == normalizedClanId)
        .toList(growable: false);
    _cachedMembersClanId = normalizedClanId;
    _cachedMembers = members;
    return members;
  }

  void _openFundDetail(FundProfile fund) {
    _controller.selectFund(fund.id);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) {
          return _FundDetailPage(controller: _controller, fundId: fund.id);
        },
      ),
    );
  }

  Future<void> _refreshWorkspace() async {
    await _controller.refresh();
    await _refreshTreasurerRoster(force: true);
  }

  Future<void> _refreshTreasurerRoster({bool force = false}) async {
    final clanId = (_session.clanId ?? '').trim();
    if (clanId.isEmpty) {
      if (!mounted) {
        return;
      }
      setState(() {
        _treasurerMembers = const [];
        _treasurerClanId = '';
        _isLoadingTreasurers = false;
        _hasResolvedTreasurers = true;
        _treasurerLookupFailed = false;
      });
      return;
    }

    if (!force && _hasResolvedTreasurers && _treasurerClanId == clanId) {
      return;
    }

    final requestToken = ++_treasurerRequestToken;
    if (mounted) {
      setState(() {
        _isLoadingTreasurers = true;
        _treasurerLookupFailed = false;
      });
    }

    try {
      final members = await _loadMembersForClan(clanId);
      if (!mounted || requestToken != _treasurerRequestToken) {
        return;
      }

      final treasurers =
          members
              .where(
                (member) =>
                    GovernanceRoleMatrix.normalizeRole(member.primaryRole) ==
                    GovernanceRoles.treasurer,
              )
              .toList(growable: false)
            ..sort(
              (left, right) => left.displayName.toLowerCase().compareTo(
                right.displayName.toLowerCase(),
              ),
            );

      setState(() {
        _treasurerMembers = treasurers;
        _treasurerClanId = clanId;
        _isLoadingTreasurers = false;
        _hasResolvedTreasurers = true;
      });
    } catch (_) {
      if (!mounted || requestToken != _treasurerRequestToken) {
        return;
      }
      setState(() {
        _treasurerMembers = const [];
        _treasurerClanId = clanId;
        _isLoadingTreasurers = false;
        _hasResolvedTreasurers = true;
        _treasurerLookupFailed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final l10n = context.l10n;
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        final currentFund = _controller.selectedFund;
        final hasFunds = _controller.funds.isNotEmpty;
        final listBottomPadding =
            (_controller.canManageFunds ? 120.0 : 32.0) +
            MediaQuery.paddingOf(context).bottom;
        final displayCurrency =
            currentFund?.currency ??
            (_controller.funds.isNotEmpty
                ? _controller.funds.first.currency
                : 'VND');
        _syncVisibleFundWindow(_controller.funds);
        final visibleFunds = _controller.funds
            .take(_visibleFundCount)
            .toList(growable: false);
        final hasMoreFunds = visibleFunds.length < _controller.funds.length;

        return Scaffold(
          appBar: AppBar(
            title: Text(l10n.pick(vi: 'Quỹ', en: 'Funds')),
          ),
          floatingActionButton: _controller.canManageFunds
              ? FloatingActionButton(
                  onPressed: () => _openFundEditor(),
                  tooltip: l10n.pick(vi: 'Thêm quỹ', en: 'Add fund'),
                  child: const Icon(Icons.add),
                )
              : null,
          body: SafeArea(
            child: _controller.isLoading
                ? AppLoadingState(
                    message: l10n.pick(
                      vi: 'Đang tải không gian quỹ...',
                      en: 'Loading fund workspace...',
                    ),
                  )
                : !_controller.canViewFunds
                ? _EmptyWorkspace(
                    icon: Icons.lock_outline,
                    title: l10n.pick(
                      vi: 'Không có quyền tài chính',
                      en: 'No finance access',
                    ),
                    description: l10n.pick(
                      vi: 'Chỉ Trưởng tộc, Trưởng chi hoặc Thủ quỹ được xem sổ quỹ.',
                      en: 'Only Clan Lead, Branch Lead, or Treasurer can view the ledger.',
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _refreshWorkspace,
                    child: ListView(
                      controller: _workspaceScrollController,
                      padding: EdgeInsets.fromLTRB(
                        20,
                        16,
                        20,
                        listBottomPadding,
                      ),
                      children: [
                        _WorkspaceHero(
                          title: l10n.pick(
                            vi: 'Không gian sổ quỹ',
                            en: 'Fund ledger workspace',
                          ),
                          description: hasFunds
                              ? l10n.pick(
                                  vi: 'Theo dõi số dư và biến động theo quỹ.',
                                  en: 'Track balance changes by fund.',
                                )
                              : l10n.pick(
                                  vi: 'Theo dõi thu, chi và số dư theo từng quỹ.',
                                  en: 'Track income, expense, and balance by fund.',
                                ),
                          canManageFunds: _controller.canManageFunds,
                          compact: hasFunds,
                          onPrimaryAction:
                              _controller.canManageFunds && !hasFunds
                              ? () => _openFundEditor()
                              : null,
                        ),
                        const SizedBox(height: 16),
                        if (_controller.canViewFunds)
                          _buildTreasurerDashboardSection(
                            context,
                            displayCurrency: displayCurrency,
                          ),
                        if (_controller.canViewFunds)
                          const SizedBox(height: 16),
                        if (_friendlyRuntimeErrorMessage(
                              context,
                              _controller.errorMessage,
                            )
                            case final error?) ...[
                          _InfoCard(
                            icon: Icons.error_outline,
                            title: l10n.pick(
                              vi: 'Không thể đồng bộ quỹ',
                              en: 'Unable to sync funds',
                            ),
                            description: error,
                            tone: colorScheme.errorContainer,
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: () {
                                unawaited(_refreshWorkspace());
                              },
                              icon: const Icon(Icons.refresh),
                              label: Text(
                                l10n.pick(vi: 'Tải lại', en: 'Retry'),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                        if (_controller.canManageFunds &&
                            currentFund != null &&
                            _treasurerSummaryLabel(
                              context,
                              currentFund: currentFund,
                            ).trim().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Text(
                              l10n.pick(
                                vi: 'Thủ quỹ hiện tại: ${_treasurerSummaryLabel(context, currentFund: currentFund)}',
                                en: 'Current treasurer: ${_treasurerSummaryLabel(context, currentFund: currentFund)}',
                              ),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        if (currentFund != null &&
                            _hasFundTransferInfo(currentFund))
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: _FundTransferInfoCard(
                              bankName: currentFund.bankName,
                              accountNumber: currentFund.bankAccountNumber,
                              accountHolder: currentFund.bankAccountHolder,
                              onCopyAccountNumber: (value) =>
                                  _copyFundTransferField(
                                    value: value,
                                    successMessage: l10n.pick(
                                      vi: 'Đã sao chép số tài khoản.',
                                      en: 'Account number copied.',
                                    ),
                                  ),
                              onCopyAccountHolder: (value) =>
                                  _copyFundTransferField(
                                    value: value,
                                    successMessage: l10n.pick(
                                      vi: 'Đã sao chép chủ tài khoản.',
                                      en: 'Account holder copied.',
                                    ),
                                  ),
                            ),
                          ),
                        if (hasFunds && _shouldShowFundSummaryTiles()) ...[
                          _StatRow(
                            items: [
                              _StatTile(
                                label: l10n.pick(vi: 'Số dư', en: 'Balance'),
                                value: _formatMoney(
                                  context,
                                  amountMinor: _totalBalanceMinor(),
                                  currency: displayCurrency,
                                ),
                                icon: Icons.account_balance_wallet_outlined,
                              ),
                              _StatTile(
                                label: l10n.pick(
                                  vi: 'Thu tháng này',
                                  en: 'This month income',
                                ),
                                value: _formatMoney(
                                  context,
                                  amountMinor: _donationThisMonthMinor(),
                                  currency: displayCurrency,
                                ),
                                icon: Icons.south_west_rounded,
                                iconBackgroundColor:
                                    colorScheme.primaryContainer,
                                valueColor: colorScheme.primary,
                              ),
                              _StatTile(
                                label: l10n.pick(
                                  vi: 'Chi tháng này',
                                  en: 'This month expense',
                                ),
                                value: _formatMoney(
                                  context,
                                  amountMinor: _expenseThisMonthMinor(),
                                  currency: displayCurrency,
                                ),
                                icon: Icons.north_east_rounded,
                                iconBackgroundColor: colorScheme.errorContainer,
                                valueColor: colorScheme.error,
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Text(
                            l10n.pick(vi: 'Danh sách quỹ', en: 'Fund list'),
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Column(
                            children: [
                              for (var i = 0; i < visibleFunds.length; i++)
                                Padding(
                                  padding: EdgeInsets.only(
                                    bottom:
                                        i == visibleFunds.length - 1 &&
                                            !hasMoreFunds
                                        ? 0
                                        : 14,
                                  ),
                                  child: _FundSummaryCard(
                                    key: Key('fund-row-${visibleFunds[i].id}'),
                                    fund: visibleFunds[i],
                                    memberCountLabel: _memberCountLabelForFund(
                                      context,
                                      visibleFunds[i],
                                    ),
                                    onTap: () =>
                                        _openFundDetail(visibleFunds[i]),
                                    onEdit: _controller.canManageFunds
                                        ? () => _openFundEditor(
                                            fund: visibleFunds[i],
                                          )
                                        : null,
                                  ),
                                ),
                              if (hasMoreFunds)
                                _InfoCard(
                                  icon: Icons.unfold_more_outlined,
                                  title: l10n.pick(
                                    vi: 'Đang tải thêm quỹ',
                                    en: 'Loading more funds',
                                  ),
                                  description: l10n.pick(
                                    vi: 'Đã hiển thị ${visibleFunds.length}/${_controller.funds.length}. Kéo xuống để tải thêm.',
                                    en: 'Showing ${visibleFunds.length}/${_controller.funds.length}. Scroll to load more.',
                                  ),
                                  tone: colorScheme.surfaceContainerHighest,
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
          ),
        );
      },
    );
  }

  Widget _buildTreasurerDashboardSection(
    BuildContext context, {
    required String displayCurrency,
  }) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final dashboard = _controller.treasurerDashboard;
    final donationHistory = dashboard.donationHistory
        .take(8)
        .toList(growable: false);
    final scholarshipHistory = dashboard.scholarshipRequests
        .take(8)
        .toList(growable: false);
    final hasDashboardData =
        dashboard.funds.isNotEmpty ||
        dashboard.transactions.isNotEmpty ||
        dashboard.scholarshipRequests.isNotEmpty ||
        dashboard.reportSummary.trim().isNotEmpty;
    final loadError = _friendlyRuntimeErrorMessage(
      context,
      _controller.treasurerDashboardErrorMessage,
    );
    final dashboardClanId = dashboard.clanId.trim().isEmpty
        ? (_session.clanId ?? '').trim()
        : dashboard.clanId.trim();
    final dashboardClanLabel = _clanDisplayNameForId(context, dashboardClanId);
    final reportSummary = _buildTreasurerReportSummary(
      context,
      dashboard: dashboard,
      displayCurrency: displayCurrency,
      clanLabel: dashboardClanLabel,
    );
    final hasReportSummary = reportSummary.trim().isNotEmpty;

    if (_controller.isLoadingTreasurerDashboard && !hasDashboardData) {
      return _InfoCard(
        icon: Icons.analytics_outlined,
        title: l10n.pick(
          vi: 'Đang tải bảng điều hành thủ quỹ',
          en: 'Loading treasurer dashboard',
        ),
        description: l10n.pick(
          vi: 'Đang đồng bộ số dư, lịch sử đóng góp và yêu cầu chi...',
          en: 'Syncing balances, donations, and payout requests...',
        ),
        tone: colorScheme.surfaceContainerHighest,
      );
    }

    if (loadError != null && !hasDashboardData) {
      return _InfoCard(
        icon: Icons.error_outline,
        title: l10n.pick(
          vi: 'Không tải được bảng điều hành thủ quỹ',
          en: 'Unable to load treasurer dashboard',
        ),
        description: loadError,
        tone: colorScheme.errorContainer,
      );
    }

    return _SectionCard(
      title: l10n.pick(vi: 'Bảng điều hành thủ quỹ', en: 'Treasurer dashboard'),
      actionLabel: _controller.isLoadingTreasurerDashboard
          ? null
          : l10n.pick(vi: 'Làm mới', en: 'Refresh'),
      onAction: _controller.isLoadingTreasurerDashboard
          ? null
          : () => unawaited(_refreshWorkspace()),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (dashboardClanId.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                l10n.pick(
                  vi: 'Phạm vi gia phả: $dashboardClanLabel',
                  en: 'Clan scope: $dashboardClanLabel',
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          if (loadError != null && hasDashboardData) ...[
            _InfoCard(
              icon: Icons.info_outline,
              title: l10n.pick(
                vi: 'Dữ liệu thủ quỹ chưa đồng bộ hoàn toàn',
                en: 'Dashboard data is partially synced',
              ),
              description: loadError,
              tone: colorScheme.surfaceContainerHighest,
              compact: true,
            ),
            const SizedBox(height: 12),
          ],
          _StatRow(
            items: [
              _StatTile(
                label: l10n.pick(
                  vi: 'Tổng số dư quỹ',
                  en: 'Total fund balance',
                ),
                value: _formatMoney(
                  context,
                  amountMinor: dashboard.totals.totalBalanceMinor,
                  currency: displayCurrency,
                ),
                icon: Icons.account_balance_wallet_outlined,
              ),
              _StatTile(
                label: l10n.pick(vi: 'Tổng đóng góp', en: 'Total donations'),
                value: _formatMoney(
                  context,
                  amountMinor: dashboard.totals.totalDonationsMinor,
                  currency: displayCurrency,
                ),
                icon: Icons.south_west_rounded,
                iconBackgroundColor: colorScheme.primaryContainer,
                valueColor: colorScheme.primary,
              ),
              _StatTile(
                label: l10n.pick(vi: 'Tổng chi', en: 'Total expenses'),
                value: _formatMoney(
                  context,
                  amountMinor: dashboard.totals.totalExpensesMinor,
                  currency: displayCurrency,
                ),
                icon: Icons.north_east_rounded,
                iconBackgroundColor: colorScheme.errorContainer,
                valueColor: colorScheme.error,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            l10n.pick(vi: 'Lịch sử đóng góp', en: 'Donation history'),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          if (donationHistory.isEmpty)
            Text(
              l10n.pick(
                vi: 'Chưa có bản ghi đóng góp trong phạm vi hiển thị.',
                en: 'No donation records in the current dashboard range.',
              ),
            )
          else
            for (final transaction in donationHistory)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            transaction.note.trim().isEmpty
                                ? l10n.pick(
                                    vi: 'Đóng góp quỹ',
                                    en: 'Fund donation',
                                  )
                                : transaction.note,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _formatDate(context, transaction.occurredAt),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _formatMoney(
                        context,
                        amountMinor: transaction.amountMinor,
                        currency: transaction.currency,
                      ),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
          const SizedBox(height: 16),
          Text(
            l10n.pick(
              vi: 'Lịch sử yêu cầu học bổng',
              en: 'Scholarship request history',
            ),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          if (scholarshipHistory.isEmpty)
            Text(
              l10n.pick(
                vi: 'Chưa có hồ sơ học bổng trong phạm vi hiển thị.',
                en: 'No scholarship requests in the current dashboard range.',
              ),
            )
          else
            for (final request in scholarshipHistory)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            request.title.trim().isEmpty
                                ? request.studentNameSnapshot
                                : request.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            request.studentNameSnapshot.trim().isEmpty
                                ? _formatScholarshipRequestDate(
                                    context,
                                    request.updatedAtIso,
                                  )
                                : '${request.studentNameSnapshot} • ${_formatScholarshipRequestDate(context, request.updatedAtIso)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    _StatusChip(
                      label: _scholarshipStatusLabel(context, request.status),
                      tone: _scholarshipStatusTone(
                        context,
                        request.status,
                        colorScheme: colorScheme,
                      ),
                    ),
                  ],
                ),
              ),
          const SizedBox(height: 16),
          Text(
            l10n.pick(vi: 'Tóm tắt báo cáo', en: 'Report summary'),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          if (!hasReportSummary)
            Text(
              l10n.pick(
                vi: 'Chưa có dữ liệu báo cáo.',
                en: 'No report summary available.',
              ),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final line in reportSummary.split('\n'))
                  if (line.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(line, style: theme.textTheme.bodyMedium),
                    ),
              ],
            ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ActionChip(
                onPressed: hasReportSummary
                    ? () => _copyTreasurerReportSummary(reportSummary)
                    : null,
                avatar: const Icon(Icons.copy_all_outlined),
                label: Text(l10n.pick(vi: 'Sao chép', en: 'Copy')),
              ),
              ActionChip(
                onPressed: !hasReportSummary || _isExportingTreasurerReport
                    ? null
                    : () => _exportTreasurerReportSummaryPdf(
                        reportSummary: reportSummary,
                        clanId: dashboardClanId,
                        clanLabel: dashboardClanLabel,
                      ),
                avatar: _isExportingTreasurerReport
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download_for_offline_outlined),
                label: Text(
                  _isExportingTreasurerReport
                      ? l10n.pick(vi: 'Đang xuất...', en: 'Exporting...')
                      : l10n.pick(vi: 'Xuất PDF', en: 'Export PDF'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  bool _shouldShowFundSummaryTiles() {
    final dashboard = _controller.treasurerDashboard;
    final hasDashboardMetrics =
        dashboard.funds.isNotEmpty ||
        dashboard.transactions.isNotEmpty ||
        dashboard.scholarshipRequests.isNotEmpty ||
        dashboard.totals.totalBalanceMinor != 0 ||
        dashboard.totals.totalDonationsMinor != 0 ||
        dashboard.totals.totalExpensesMinor != 0;
    return !(_controller.canViewFunds && hasDashboardMetrics);
  }

  String? _friendlyRuntimeErrorMessage(BuildContext context, String? rawError) {
    final normalized = (rawError ?? '').trim();
    if (normalized.isEmpty) {
      return null;
    }
    final lowered = normalized.toLowerCase();
    final l10n = context.l10n;
    if (lowered == 'permission_denied' ||
        lowered.contains('permission-denied') ||
        lowered.contains('permission denied')) {
      return l10n.pick(
        vi: 'Bạn chưa có quyền truy cập dữ liệu quỹ của gia phả này.',
        en: 'You do not have permission to access this clan fund data.',
      );
    }
    return l10n.pick(
      vi: 'Không thể đồng bộ dữ liệu quỹ lúc này. Vui lòng thử lại sau.',
      en: 'Unable to sync fund data right now. Please try again later.',
    );
  }

  String _clanDisplayNameForId(BuildContext context, String clanId) {
    final normalizedClanId = clanId.trim();
    if (normalizedClanId.isEmpty) {
      return context.l10n.pick(vi: 'Gia phả hiện tại', en: 'Current clan');
    }
    final option = _clanContexts.firstWhere(
      (item) => item.clanId.trim() == normalizedClanId,
      orElse: () => ClanContextOption(
        clanId: normalizedClanId,
        clanName: normalizedClanId,
        memberId: '',
        primaryRole: 'MEMBER',
      ),
    );
    return _clanContextDisplayLabel(context, option);
  }

  String _buildTreasurerReportSummary(
    BuildContext context, {
    required TreasurerDashboardSnapshot dashboard,
    required String displayCurrency,
    required String clanLabel,
  }) {
    final l10n = context.l10n;
    final resolvedClanLabel = clanLabel.trim().isEmpty
        ? l10n.pick(vi: 'Gia phả hiện tại', en: 'Current clan')
        : clanLabel.trim();
    final generatedAt = dashboard.transactions.isEmpty
        ? DateTime.now()
        : dashboard.transactions.first.occurredAt.toLocal();
    final lines = <String>[
      l10n.pick(
        vi: 'Gia phả: $resolvedClanLabel',
        en: 'Clan: $resolvedClanLabel',
      ),
      l10n.pick(
        vi: 'Số dư hiện tại: ${_formatMoney(context, amountMinor: dashboard.totals.totalBalanceMinor, currency: displayCurrency)}',
        en: 'Current balance: ${_formatMoney(context, amountMinor: dashboard.totals.totalBalanceMinor, currency: displayCurrency)}',
      ),
      l10n.pick(
        vi: 'Tổng đóng góp: ${_formatMoney(context, amountMinor: dashboard.totals.totalDonationsMinor, currency: displayCurrency)}',
        en: 'Total donations: ${_formatMoney(context, amountMinor: dashboard.totals.totalDonationsMinor, currency: displayCurrency)}',
      ),
      l10n.pick(
        vi: 'Tổng chi: ${_formatMoney(context, amountMinor: dashboard.totals.totalExpensesMinor, currency: displayCurrency)}',
        en: 'Total expenses: ${_formatMoney(context, amountMinor: dashboard.totals.totalExpensesMinor, currency: displayCurrency)}',
      ),
      l10n.pick(
        vi: 'Hồ sơ khuyến học: ${dashboard.scholarshipRequests.length}',
        en: 'Scholarship requests: ${dashboard.scholarshipRequests.length}',
      ),
      l10n.pick(
        vi: 'Cập nhật lúc: ${_formatDateTime(context, generatedAt)}',
        en: 'Updated at: ${_formatDateTime(context, generatedAt)}',
      ),
    ];
    return lines.join('\n');
  }

  Future<void> _copyTreasurerReportSummary(String summary) async {
    final l10n = context.l10n;
    await Clipboard.setData(ClipboardData(text: summary));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          l10n.pick(
            vi: 'Đã sao chép tóm tắt báo cáo.',
            en: 'Report summary copied.',
          ),
        ),
      ),
    );
  }

  bool _hasFundTransferInfo(FundProfile fund) {
    return (fund.bankAccountNumber ?? '').trim().isNotEmpty ||
        (fund.bankAccountHolder ?? '').trim().isNotEmpty;
  }

  Future<void> _copyFundTransferField({
    required String value,
    required String successMessage,
  }) async {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: normalized));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(successMessage)));
  }

  Future<void> _exportTreasurerReportSummaryPdf({
    required String reportSummary,
    required String clanId,
    required String clanLabel,
  }) async {
    if (_isExportingTreasurerReport) {
      return;
    }
    final l10n = context.l10n;
    setState(() {
      _isExportingTreasurerReport = true;
    });
    try {
      final pdfBytes = await _buildTreasurerReportPdfBytes(
        reportSummary: reportSummary,
        clanId: clanId,
        clanLabel: clanLabel,
      );
      final fileName = _treasurerReportFileName(clanId);
      await Printing.sharePdf(bytes: pdfBytes, filename: fileName);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.pick(
              vi: 'Đã tạo báo cáo PDF. Bạn có thể lưu hoặc chia sẻ.',
              en: 'PDF report is ready to save or share.',
            ),
          ),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.pick(
              vi: 'Chưa thể xuất báo cáo PDF. Vui lòng thử lại.',
              en: 'Unable to export PDF report. Please retry.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isExportingTreasurerReport = false;
        });
      } else {
        _isExportingTreasurerReport = false;
      }
    }
  }

  Future<Uint8List> _buildTreasurerReportPdfBytes({
    required String reportSummary,
    required String clanId,
    required String clanLabel,
  }) async {
    final l10n = context.l10n;
    final pdf = pw.Document();
    final generatedAt = _formatDateTime(context, DateTime.now());
    final resolvedClanLabel = clanLabel.trim().isEmpty ? clanId : clanLabel;
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          pw.Text(
            l10n.pick(
              vi: 'Tổng hợp tài chính dành cho thủ quỹ',
              en: 'Treasurer Financial Summary',
            ),
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            l10n.pick(
              vi: 'Gia phả: $resolvedClanLabel',
              en: 'Clan: $resolvedClanLabel',
            ),
          ),
          pw.Text(
            l10n.pick(
              vi: 'Thời điểm tạo: $generatedAt',
              en: 'Generated at: $generatedAt',
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Text(reportSummary.trim()),
        ],
      ),
    );
    return pdf.save();
  }

  String _treasurerReportFileName(String clanId) {
    final now = DateTime.now().toLocal();
    final year = now.year.toString().padLeft(4, '0');
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    final scope = clanId.isEmpty ? 'unknown' : clanId;
    return 'treasurer-report-$scope-$year$month$day.pdf';
  }

  String _formatScholarshipRequestDate(BuildContext context, String isoValue) {
    final parsed = DateTime.tryParse(isoValue);
    if (parsed == null) {
      return context.l10n.pick(vi: 'Không rõ thời gian', en: 'Unknown date');
    }
    return _formatDate(context, parsed.toUtc());
  }

  String _scholarshipStatusLabel(BuildContext context, String status) {
    final l10n = context.l10n;
    return switch (status.trim().toLowerCase()) {
      'approved' => l10n.pick(vi: 'Đã duyệt', en: 'Approved'),
      'rejected' => l10n.pick(vi: 'Từ chối', en: 'Rejected'),
      _ => l10n.pick(vi: 'Chờ duyệt', en: 'Pending'),
    };
  }

  Color _scholarshipStatusTone(
    BuildContext context,
    String status, {
    required ColorScheme colorScheme,
  }) {
    switch (status.trim().toLowerCase()) {
      case 'approved':
        return colorScheme.primaryContainer;
      case 'rejected':
        return colorScheme.errorContainer;
      default:
        return colorScheme.surfaceContainerHighest;
    }
  }

  String? _memberCountLabelForFund(BuildContext context, FundProfile fund) {
    if (fund.appliedMemberIds.isEmpty) {
      return null;
    }
    return context.l10n.pick(
      vi: 'Áp dụng: ${fund.appliedMemberIds.length} thành viên',
      en: 'Applies to ${fund.appliedMemberIds.length} members',
    );
  }

  int _totalBalanceMinor() {
    var sum = 0;
    for (final fund in _controller.funds) {
      sum += fund.balanceMinor;
    }
    return sum;
  }

  int _donationThisMonthMinor() {
    final now = DateTime.now();
    var sum = 0;
    for (final tx in _controller.transactions) {
      final localDate = tx.occurredAt.toLocal();
      if (localDate.year == now.year &&
          localDate.month == now.month &&
          tx.isDonation) {
        sum += tx.amountMinor;
      }
    }
    return sum;
  }

  int _expenseThisMonthMinor() {
    final now = DateTime.now();
    var sum = 0;
    for (final tx in _controller.transactions) {
      final localDate = tx.occurredAt.toLocal();
      if (localDate.year == now.year &&
          localDate.month == now.month &&
          tx.isExpense) {
        sum += tx.amountMinor;
      }
    }
    return sum;
  }

  String _treasurerSummaryLabel(
    BuildContext context, {
    required FundProfile? currentFund,
  }) {
    final l10n = context.l10n;
    if (_isLoadingTreasurers && !_hasResolvedTreasurers) {
      return l10n.pick(vi: 'Đang tải...', en: 'Loading...');
    }
    if (_treasurerLookupFailed) {
      return l10n.pick(vi: 'Chưa tải được', en: 'Unavailable');
    }
    if (currentFund == null) {
      return l10n.pick(vi: 'Chưa chọn quỹ', en: 'No fund selected');
    }

    final activeClanId = (_session.clanId ?? '').trim();
    final fundClanId = currentFund.clanId.trim();
    if (activeClanId.isEmpty || fundClanId != activeClanId) {
      return l10n.pick(vi: 'Ngoài phạm vi gia phả', en: 'Out of clan scope');
    }

    final treasurerNames = _resolveTreasurerNamesForCurrentFund(
      currentFund: currentFund,
      activeClanId: activeClanId,
    );
    if (treasurerNames.isEmpty) {
      return l10n.pick(vi: 'Chưa phân công', en: 'Unassigned');
    }
    if (treasurerNames.length == 1) {
      return treasurerNames.first;
    }
    final first = treasurerNames.first;
    final remaining = treasurerNames.length - 1;
    return '$first +$remaining';
  }

  List<String> _resolveTreasurerNamesForCurrentFund({
    required FundProfile currentFund,
    required String activeClanId,
  }) {
    final explicitTreasurerIds = currentFund.treasurerMemberIds
        .map((entry) => entry.trim())
        .where((entry) => entry.isNotEmpty)
        .toSet();
    if (explicitTreasurerIds.isNotEmpty) {
      final names =
          _cachedMembers
              .where((member) => member.clanId.trim() == activeClanId)
              .where((member) => explicitTreasurerIds.contains(member.id))
              .map((member) => member.displayName.trim())
              .where((name) => name.isNotEmpty)
              .toSet()
              .toList(growable: false)
            ..sort(
              (left, right) =>
                  left.toLowerCase().compareTo(right.toLowerCase()),
            );
      return names;
    }

    Iterable<MemberProfile> scoped = _treasurerMembers.where(
      (member) => member.clanId.trim() == activeClanId,
    );

    final branchId = _nullIfBlank(currentFund.branchId);
    if (branchId != null) {
      scoped = scoped.where((member) => member.branchId.trim() == branchId);
    }

    final appliedMemberIds = currentFund.appliedMemberIds
        .map((entry) => entry.trim())
        .where((entry) => entry.isNotEmpty)
        .toSet();

    if (appliedMemberIds.isNotEmpty) {
      scoped = scoped.where((member) => appliedMemberIds.contains(member.id));
    } else {
      final transactionActorIds = _controller.transactions
          .where(
            (transaction) =>
                transaction.fundId == currentFund.id &&
                transaction.clanId.trim() == activeClanId,
          )
          .expand((transaction) {
            return [
              transaction.memberId?.trim() ?? '',
              transaction.createdBy?.trim() ?? '',
            ];
          })
          .where((entry) => entry.isNotEmpty)
          .toSet();
      if (transactionActorIds.isNotEmpty) {
        scoped = scoped.where(
          (member) => transactionActorIds.contains(member.id),
        );
      }
    }

    final names =
        scoped
            .map((member) => member.displayName.trim())
            .where((name) => name.isNotEmpty)
            .toSet()
            .toList(growable: false)
          ..sort(
            (left, right) => left.toLowerCase().compareTo(right.toLowerCase()),
          );
    return names;
  }

  String _formatMoney(
    BuildContext context, {
    required int amountMinor,
    required String currency,
  }) {
    return CurrencyMinorUnits.formatMinorUnits(
      amountMinor: amountMinor,
      currency: currency,
      locale: Localizations.localeOf(context).toLanguageTag(),
    );
  }
}

class _FundDetailPage extends StatefulWidget {
  const _FundDetailPage({required this.controller, required this.fundId});

  final FundController controller;
  final String fundId;

  @override
  State<_FundDetailPage> createState() => _FundDetailPageState();
}

class _FundDetailPageState extends State<_FundDetailPage> {
  late final TextEditingController _queryController;

  @override
  void initState() {
    super.initState();
    _queryController = TextEditingController(
      text: widget.controller.filters.query,
    );
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _openTransactionEditor(
    FundProfile fund,
    FundTransactionType type,
  ) async {
    final l10n = context.l10n;
    final didSave = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _TransactionEditorSheet(
          title: type == FundTransactionType.donation
              ? l10n.pick(vi: 'Ghi nhận đóng góp', en: 'Record donation')
              : l10n.pick(vi: 'Ghi nhận chi tiêu', en: 'Record expense'),
          description: type == FundTransactionType.donation
              ? l10n.pick(
                  vi: 'Thêm khoản đóng góp vào quỹ này.',
                  en: 'Add incoming contributions to this fund.',
                )
              : l10n.pick(
                  vi: 'Ghi nhận khoản chi từ quỹ này.',
                  en: 'Log outgoing expenses from this fund.',
                ),
          initialDraft: FundTransactionDraft.empty(
            fundId: fund.id,
            transactionType: type,
            currency: fund.currency,
          ),
          isSaving: widget.controller.isSavingTransaction,
          onSubmit: (draft) {
            return widget.controller.recordTransaction(draft: draft);
          },
        );
      },
    );

    if (didSave == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            type == FundTransactionType.donation
                ? l10n.pick(vi: 'Đã lưu khoản đóng góp.', en: 'Donation saved.')
                : l10n.pick(vi: 'Đã lưu khoản chi.', en: 'Expense saved.'),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final fund = widget.controller.funds
            .where((item) => item.id == widget.fundId)
            .firstOrNull;
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        final l10n = context.l10n;

        if (fund == null) {
          return Scaffold(
            body: SafeArea(
              child: _EmptyWorkspace(
                icon: Icons.search_off,
                title: l10n.pick(
                  vi: 'Không tìm thấy quỹ',
                  en: 'Fund not found',
                ),
                description: l10n.pick(
                  vi: 'Quỹ này có thể đã bị xóa hoặc thay đổi.',
                  en: 'This fund may have been removed or changed.',
                ),
              ),
            ),
          );
        }

        final transactions = widget.controller.filteredTransactionsForFund(
          fund.id,
        );

        return Scaffold(
          appBar: AppBar(
            title: Text(fund.name),
            actions: [
              IconButton(
                tooltip: l10n.pick(vi: 'Tải lại', en: 'Refresh'),
                onPressed: widget.controller.isLoading
                    ? null
                    : widget.controller.refresh,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        colorScheme.primary,
                        colorScheme.primaryContainer,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _fundTypeLabel(context, fund.fundType),
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: colorScheme.onPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        l10n.pick(vi: 'Số dư hiện tại', en: 'Running balance'),
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: colorScheme.onPrimary.withValues(alpha: 0.9),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _formatMoneyText(
                          context,
                          amountMinor: fund.balanceMinor,
                          currency: fund.currency,
                        ),
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: colorScheme.onPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (fund.description.trim().isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          fund.description,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onPrimary.withValues(
                              alpha: 0.88,
                            ),
                          ),
                        ),
                      ],
                      if (widget.controller.canManageFunds) ...[
                        const SizedBox(height: 18),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            FilledButton.icon(
                              onPressed: () => _openTransactionEditor(
                                fund,
                                FundTransactionType.donation,
                              ),
                              icon: const Icon(Icons.add_circle_outline),
                              label: Text(
                                l10n.pick(
                                  vi: 'Thêm đóng góp',
                                  en: 'Add donation',
                                ),
                              ),
                            ),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: colorScheme.onPrimary,
                                side: BorderSide(
                                  color: colorScheme.onPrimary.withValues(
                                    alpha: 0.4,
                                  ),
                                ),
                              ),
                              onPressed: () => _openTransactionEditor(
                                fund,
                                FundTransactionType.expense,
                              ),
                              icon: const Icon(Icons.remove_circle_outline),
                              label: Text(
                                l10n.pick(
                                  vi: 'Thêm chi tiêu',
                                  en: 'Add expense',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _SectionCard(
                  title: l10n.pick(
                    vi: 'Bộ lọc giao dịch',
                    en: 'Transaction filters',
                  ),
                  actionLabel:
                      widget.controller.filters.query.trim().isNotEmpty ||
                          widget.controller.filters.transactionType != null
                      ? l10n.pick(vi: 'Xóa lọc', en: 'Clear')
                      : null,
                  onAction:
                      widget.controller.filters.query.trim().isNotEmpty ||
                          widget.controller.filters.transactionType != null
                      ? () {
                          _queryController.clear();
                          widget.controller.clearFilters();
                        }
                      : null,
                  child: Column(
                    children: [
                      TextField(
                        controller: _queryController,
                        decoration: InputDecoration(
                          labelText: l10n.pick(
                            vi: 'Tìm theo ghi chú/mã tham chiếu/thành viên',
                            en: 'Search note/reference/member',
                          ),
                          prefixIcon: const Icon(Icons.search),
                        ),
                        textInputAction: TextInputAction.search,
                        onChanged: widget.controller.updateQueryFilter,
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<FundTransactionType?>(
                        initialValue: widget.controller.filters.transactionType,
                        decoration: InputDecoration(
                          labelText: l10n.pick(
                            vi: 'Loại giao dịch',
                            en: 'Transaction type',
                          ),
                        ),
                        items: [
                          DropdownMenuItem<FundTransactionType?>(
                            value: null,
                            child: Text(
                              l10n.pick(vi: 'Tất cả', en: 'All types'),
                            ),
                          ),
                          DropdownMenuItem<FundTransactionType?>(
                            value: FundTransactionType.donation,
                            child: Text(
                              l10n.pick(vi: 'Đóng góp', en: 'Donations'),
                            ),
                          ),
                          DropdownMenuItem<FundTransactionType?>(
                            value: FundTransactionType.expense,
                            child: Text(
                              l10n.pick(vi: 'Chi tiêu', en: 'Expenses'),
                            ),
                          ),
                        ],
                        onChanged: widget.controller.updateTypeFilter,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _SectionCard(
                  title: l10n.pick(
                    vi: 'Lịch sử giao dịch',
                    en: 'Transaction history',
                  ),
                  actionLabel: widget.controller.canManageFunds
                      ? l10n.pick(vi: 'Đóng góp', en: 'Donation')
                      : null,
                  onAction: widget.controller.canManageFunds
                      ? () => _openTransactionEditor(
                          fund,
                          FundTransactionType.donation,
                        )
                      : null,
                  child: transactions.isEmpty
                      ? _EmptyWorkspace(
                          icon: Icons.receipt_long_outlined,
                          title: l10n.pick(
                            vi: 'Chưa có giao dịch',
                            en: 'No transactions',
                          ),
                          description: l10n.pick(
                            vi: 'Thêm giao dịch thu hoặc chi để bắt đầu sổ quỹ.',
                            en: 'Add an income or expense transaction to start the ledger.',
                          ),
                        )
                      : Column(
                          children: [
                            for (var i = 0; i < transactions.length; i++)
                              Padding(
                                padding: EdgeInsets.only(
                                  bottom: i == transactions.length - 1 ? 0 : 12,
                                ),
                                child: _TransactionRow(
                                  transaction: transactions[i],
                                ),
                              ),
                          ],
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

class _FundEditorSheet extends StatefulWidget {
  const _FundEditorSheet({
    required this.title,
    required this.description,
    required this.initialDraft,
    required this.activeClanId,
    required this.activeClanLabel,
    required this.resolveViewerMemberId,
    required this.loadMembersForClan,
    required this.isSaving,
    required this.onSubmit,
  });

  final String title;
  final String description;
  final FundDraft initialDraft;
  final String activeClanId;
  final String activeClanLabel;
  final String? Function() resolveViewerMemberId;
  final Future<List<MemberProfile>> Function(String clanId) loadMembersForClan;
  final bool isSaving;
  final Future<FundRepositoryErrorCode?> Function(FundDraft draft) onSubmit;

  @override
  State<_FundEditorSheet> createState() => _FundEditorSheetState();
}

class _FundEditorSheetState extends State<_FundEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _branchIdController;

  late String _fundType;
  late String _currency;
  late String _selectedClanId;
  List<MemberProfile> _members = const [];
  Set<String> _selectedMemberIds = <String>{};
  Set<String> _selectedTreasurerMemberIds = <String>{};
  bool _isLoadingMembers = false;
  String? _memberLoadError;
  FundRepositoryErrorCode? _submitError;
  bool _isSubmitting = false;
  int _editorStep = 0;

  static const _fundTypes = [
    'scholarship',
    'operations',
    'maintenance',
    'custom',
  ];

  static const _currencies = ['VND', 'USD', 'EUR'];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialDraft.name);
    _descriptionController = TextEditingController(
      text: widget.initialDraft.description,
    );
    _branchIdController = TextEditingController(
      text: widget.initialDraft.branchId ?? '',
    );
    _fundType = _fundTypes.contains(widget.initialDraft.fundType)
        ? widget.initialDraft.fundType
        : 'custom';
    _currency = _currencies.contains(widget.initialDraft.currency.toUpperCase())
        ? widget.initialDraft.currency.toUpperCase()
        : 'VND';
    final activeClanId = _nullIfBlank(widget.activeClanId) ?? '';
    final initialClanId = _nullIfBlank(widget.initialDraft.clanId) ?? '';
    _selectedClanId = initialClanId.isNotEmpty ? initialClanId : activeClanId;
    _selectedMemberIds = widget.initialDraft.appliedMemberIds
        .map((entry) => entry.trim())
        .where((entry) => entry.isNotEmpty)
        .toSet();
    _selectedTreasurerMemberIds = widget.initialDraft.treasurerMemberIds
        .map((entry) => entry.trim())
        .where((entry) => entry.isNotEmpty)
        .toSet();
    if (_selectedClanId.isNotEmpty) {
      unawaited(_loadMembersForClan(_selectedClanId));
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _branchIdController.dispose();
    super.dispose();
  }

  bool _validateStepOne({required bool showSnackBar}) {
    final l10n = context.l10n;
    if (_selectedClanId.trim().isEmpty) {
      if (showSnackBar) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n.pick(
                vi: 'Chưa có gia phả đang hoạt động. Hãy chọn gia phả ở menu trên cùng rồi thử lại.',
                en: 'No active clan found. Please select a clan from the top menu and try again.',
              ),
            ),
          ),
        );
      }
      return false;
    }

    if (_nameController.text.trim().isEmpty) {
      if (showSnackBar) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n.pick(
                vi: 'Tên quỹ là bắt buộc.',
                en: 'Fund name is required.',
              ),
            ),
          ),
        );
      }
      return false;
    }
    return true;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });

    final targetClanId = _selectedClanId.trim();
    if (targetClanId.isEmpty) {
      setState(() {
        _isSubmitting = false;
        _submitError = FundRepositoryErrorCode.validationFailed;
      });
      return;
    }

    final error = await widget.onSubmit(
      FundDraft(
        clanId: targetClanId,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        fundType: _fundType,
        currency: _currency,
        branchId: _nullIfBlank(_branchIdController.text),
        appliedMemberIds: _selectedMemberIds.toList(growable: false),
        treasurerMemberIds: _selectedTreasurerMemberIds.toList(growable: false),
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

  Future<void> _loadMembersForClan(String clanId) async {
    final normalizedClanId = clanId.trim();
    if (normalizedClanId.isEmpty) {
      setState(() {
        _members = const [];
        _selectedMemberIds.clear();
        _selectedTreasurerMemberIds.clear();
        _memberLoadError = null;
      });
      return;
    }

    setState(() {
      _isLoadingMembers = true;
      _memberLoadError = null;
    });
    try {
      final members = await widget.loadMembersForClan(normalizedClanId);
      if (!mounted) {
        return;
      }
      final memberIdSet = members.map((entry) => entry.id).toSet();
      setState(() {
        _members = members;
        _selectedMemberIds = _selectedMemberIds
            .where(memberIdSet.contains)
            .toSet();
        _selectedTreasurerMemberIds = _selectedTreasurerMemberIds
            .where(memberIdSet.contains)
            .toSet();
        _isLoadingMembers = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoadingMembers = false;
        _memberLoadError = context.l10n.pick(
          vi: 'Không thể tải thành viên theo gia phả đã chọn.',
          en: 'Unable to load members for the selected clan.',
        );
      });
    }
  }

  List<MemberProfile> _selectedMembersFor(Set<String> ids) {
    if (ids.isEmpty) {
      return const [];
    }
    final selected =
        _members
            .where((member) => ids.contains(member.id))
            .toList(growable: false)
          ..sort(
            (left, right) => left.fullName.toLowerCase().compareTo(
              right.fullName.toLowerCase(),
            ),
          );
    return selected;
  }

  MemberProfile? _memberById(String? memberId) {
    final normalized = (memberId ?? '').trim();
    if (normalized.isEmpty) {
      return null;
    }
    for (final member in _members) {
      if (member.id == normalized) {
        return member;
      }
    }
    return null;
  }

  String _memberKinshipBadge(MemberProfile member, BuildContext context) {
    final l10n = context.l10n;
    final viewer = _memberById(widget.resolveViewerMemberId());
    if (viewer == null) {
      return l10n.pick(
        vi: 'Đời ${member.generation}',
        en: 'Generation ${member.generation}',
      );
    }
    final membersById = {
      for (final candidate in _members) candidate.id: candidate,
    };
    return KinshipTitleResolver.resolve(
      l10n: l10n,
      viewer: viewer,
      member: member,
      membersById: membersById,
    );
  }

  String? _memberDeathDateCaption(MemberProfile member, BuildContext context) {
    final deathDate = _tryParseIsoDate(member.deathDate);
    if (deathDate == null) {
      return null;
    }
    final l10n = context.l10n;
    final day = deathDate.day.toString().padLeft(2, '0');
    final month = deathDate.month.toString().padLeft(2, '0');
    return l10n.pick(
      vi: 'Ngày mất: $day/$month/${deathDate.year}',
      en: 'Passed away: $month/$day/${deathDate.year}',
    );
  }

  DateTime? _tryParseIsoDate(String? raw) {
    final normalized = (raw ?? '').trim();
    if (normalized.isEmpty) {
      return null;
    }
    return DateTime.tryParse(normalized);
  }

  Future<void> _pickMemberIds({
    required String title,
    required Set<String> initialSelected,
    required ValueChanged<Set<String>> onApplied,
  }) async {
    final selected = Set<String>.from(initialSelected);
    String query = '';
    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final normalizedQuery = query.trim().toLowerCase();
            final filteredMembers = _members
                .where((member) {
                  if (normalizedQuery.isEmpty) {
                    return true;
                  }
                  return member.fullName.toLowerCase().contains(
                        normalizedQuery,
                      ) ||
                      member.displayName.toLowerCase().contains(
                        normalizedQuery,
                      ) ||
                      member.nickName.toLowerCase().contains(normalizedQuery) ||
                      member.id.toLowerCase().contains(normalizedQuery);
                })
                .toList(growable: false);

            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                height: MediaQuery.sizeOf(context).height * 0.72,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search),
                        hintText: context.l10n.pick(
                          vi: 'Tìm thành viên...',
                          en: 'Search members...',
                        ),
                      ),
                      onChanged: (value) {
                        setModalState(() {
                          query = value;
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: filteredMembers.isEmpty
                          ? Center(
                              child: Text(
                                context.l10n.pick(
                                  vi: 'Không tìm thấy thành viên phù hợp.',
                                  en: 'No matching members found.',
                                ),
                              ),
                            )
                          : ListView.builder(
                              itemCount: filteredMembers.length,
                              itemBuilder: (context, index) {
                                final member = filteredMembers[index];
                                final isChecked = selected.contains(member.id);
                                final kinshipBadge = _memberKinshipBadge(
                                  member,
                                  context,
                                );
                                final deathDateCaption =
                                    _memberDeathDateCaption(member, context);
                                final nickName = member.nickName.trim();
                                final showNickName =
                                    nickName.isNotEmpty &&
                                    nickName.toLowerCase() !=
                                        member.fullName.toLowerCase();
                                return CheckboxListTile(
                                  value: isChecked,
                                  controlAffinity:
                                      ListTileControlAffinity.trailing,
                                  title: Text(member.fullName),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (showNickName)
                                          Text(
                                            nickName,
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodySmall,
                                          ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.secondaryContainer,
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                          ),
                                          child: Text(
                                            kinshipBadge,
                                            style: Theme.of(context)
                                                .textTheme
                                                .labelMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                          ),
                                        ),
                                        if (deathDateCaption != null) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            deathDateCaption,
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodySmall,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  onChanged: (value) {
                                    setModalState(() {
                                      if (value == true) {
                                        selected.add(member.id);
                                      } else {
                                        selected.remove(member.id);
                                      }
                                    });
                                  },
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: Text(
                              context.l10n.pick(vi: 'Hủy', en: 'Cancel'),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: () =>
                                Navigator.of(context).pop(selected),
                            child: Text(
                              context.l10n.pick(vi: 'Xong', en: 'Done'),
                            ),
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
    if (result == null) {
      return;
    }
    onApplied(result);
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.viewInsetsOf(context);
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final selectedTreasurerMembers = _selectedMembersFor(
      _selectedTreasurerMemberIds,
    );
    final selectedAppliedMembers = _selectedMembersFor(_selectedMemberIds);

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
                Text(widget.description, style: theme.textTheme.bodyMedium),
                if (_submitError != null) ...[
                  const SizedBox(height: 16),
                  _InfoCard(
                    icon: Icons.error_outline,
                    title: l10n.pick(
                      vi: 'Không thể lưu quỹ',
                      en: 'Unable to save fund',
                    ),
                    description: _errorMessageForCode(context, _submitError!),
                    tone: theme.colorScheme.errorContainer,
                  ),
                ],
                const SizedBox(height: 18),
                _FundEditorStepIndicator(
                  currentStep: _editorStep,
                  labels: [
                    l10n.pick(vi: 'Hồ sơ quỹ', en: 'Fund profile'),
                    l10n.pick(vi: 'Thành viên', en: 'Members'),
                  ],
                  onStepSelected: (step) {
                    if (step == 1 && !_validateStepOne(showSnackBar: true)) {
                      return;
                    }
                    setState(() => _editorStep = step);
                  },
                ),
                const SizedBox(height: 16),
                if (_editorStep == 0) ...[
                  InputDecorator(
                    decoration: InputDecoration(
                      labelText: l10n.pick(
                        vi: 'Gia phả hiện tại',
                        en: 'Current clan',
                      ),
                    ),
                    child: Text(
                      widget.activeClanLabel.trim().isNotEmpty
                          ? widget.activeClanLabel
                          : (_selectedClanId.trim().isNotEmpty
                                ? _selectedClanId
                                : l10n.pick(
                                    vi: 'Chưa chọn gia phả',
                                    en: 'No clan selected',
                                  )),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    key: const Key('fund-name-input'),
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: l10n.pick(vi: 'Tên quỹ', en: 'Fund name'),
                      hintText: l10n.pick(
                        vi: 'Quỹ khuyến học',
                        en: 'Scholarship Fund',
                      ),
                    ),
                    validator: (value) {
                      return value == null || value.trim().isEmpty
                          ? l10n.pick(
                              vi: 'Tên quỹ là bắt buộc.',
                              en: 'Fund name is required.',
                            )
                          : null;
                    },
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: _fundType,
                    decoration: InputDecoration(
                      labelText: l10n.pick(vi: 'Loại quỹ', en: 'Fund type'),
                    ),
                    items: [
                      for (final type in _fundTypes)
                        DropdownMenuItem<String>(
                          value: type,
                          child: Text(_fundTypeLabel(context, type)),
                        ),
                    ],
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      setState(() {
                        _fundType = value;
                      });
                    },
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: _currency,
                    decoration: InputDecoration(
                      labelText: l10n.pick(vi: 'Tiền tệ', en: 'Currency'),
                    ),
                    items: [
                      for (final currency in _currencies)
                        DropdownMenuItem<String>(
                          value: currency,
                          child: Text(currency),
                        ),
                    ],
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      setState(() {
                        _currency = value;
                      });
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    key: const Key('fund-branch-id-input'),
                    controller: _branchIdController,
                    decoration: InputDecoration(
                      labelText: l10n.pick(
                        vi: 'Mã chi (tuỳ chọn)',
                        en: 'Branch id (optional)',
                      ),
                      hintText: l10n.pick(
                        vi: 'chi_demo_001',
                        en: 'branch_demo_001',
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    key: const Key('fund-description-input'),
                    controller: _descriptionController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: l10n.pick(vi: 'Mô tả', en: 'Description'),
                      hintText: l10n.pick(
                        vi: 'Mô tả quỹ hỗ trợ ai và cách sử dụng.',
                        en: 'Describe who this fund supports and how it is used.',
                      ),
                    ),
                  ),
                ],
                if (_editorStep == 1) ...[
                  _InfoCard(
                    icon: Icons.groups_outlined,
                    title: l10n.pick(
                      vi: 'Bước 2: Gán thành viên',
                      en: 'Step 2: Assign members',
                    ),
                    description: l10n.pick(
                      vi: 'Chọn thủ quỹ phụ trách và danh sách thành viên áp dụng cho quỹ này.',
                      en: 'Select treasurers and members who belong to this fund.',
                    ),
                    tone: theme.colorScheme.surfaceContainerHighest,
                    compact: true,
                  ),
                  const SizedBox(height: 14),
                  InputDecorator(
                    decoration: InputDecoration(
                      labelText: l10n.pick(
                        vi: 'Thủ quỹ phụ trách',
                        en: 'Assigned treasurer',
                      ),
                    ),
                    child: _isLoadingMembers
                        ? Row(
                            children: [
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                l10n.pick(
                                  vi: 'Đang tải thành viên...',
                                  en: 'Loading members...',
                                ),
                              ),
                            ],
                          )
                        : _memberLoadError != null
                        ? Text(_memberLoadError!)
                        : _members.isEmpty
                        ? Text(
                            l10n.pick(
                              vi: 'Không có thành viên khả dụng trong gia phả này.',
                              en: 'No members available in this clan.',
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.pick(
                                  vi: 'Đã chọn ${_selectedTreasurerMemberIds.length}/${_members.length} thủ quỹ',
                                  en: 'Selected ${_selectedTreasurerMemberIds.length}/${_members.length} treasurers',
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                l10n.pick(
                                  vi: 'Thành viên được chọn sẽ được cấp vai trò Thủ quỹ mặc định.',
                                  en: 'Selected members are granted the Treasurer role by default.',
                                ),
                                style: theme.textTheme.bodySmall,
                              ),
                              const SizedBox(height: 10),
                              OutlinedButton.icon(
                                key: const Key('fund-treasurer-picker'),
                                onPressed: () {
                                  unawaited(
                                    _pickMemberIds(
                                      title: l10n.pick(
                                        vi: 'Chọn thủ quỹ',
                                        en: 'Select treasurers',
                                      ),
                                      initialSelected:
                                          _selectedTreasurerMemberIds,
                                      onApplied: (picked) {
                                        setState(() {
                                          _selectedTreasurerMemberIds = picked;
                                        });
                                      },
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.person_search_outlined),
                                label: Text(
                                  l10n.pick(
                                    vi: 'Chọn thành viên',
                                    en: 'Choose members',
                                  ),
                                ),
                              ),
                              if (selectedTreasurerMembers.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    for (final member
                                        in selectedTreasurerMembers)
                                      Chip(
                                        label: Text(
                                          '${member.fullName} • ${_memberKinshipBadge(member, context)}',
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                  ),
                  const SizedBox(height: 14),
                  InputDecorator(
                    decoration: InputDecoration(
                      labelText: l10n.pick(
                        vi: 'Áp dụng cho thành viên',
                        en: 'Apply to members',
                      ),
                    ),
                    child: _isLoadingMembers
                        ? Row(
                            children: [
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                l10n.pick(
                                  vi: 'Đang tải thành viên...',
                                  en: 'Loading members...',
                                ),
                              ),
                            ],
                          )
                        : _memberLoadError != null
                        ? Text(_memberLoadError!)
                        : _members.isEmpty
                        ? Text(
                            l10n.pick(
                              vi: 'Không có thành viên khả dụng trong gia phả này.',
                              en: 'No members available in this clan.',
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.pick(
                                  vi: 'Đã chọn ${_selectedMemberIds.length}/${_members.length} thành viên',
                                  en: 'Selected ${_selectedMemberIds.length}/${_members.length} members',
                                ),
                              ),
                              const SizedBox(height: 10),
                              OutlinedButton.icon(
                                key: const Key('fund-applied-members-picker'),
                                onPressed: () {
                                  unawaited(
                                    _pickMemberIds(
                                      title: l10n.pick(
                                        vi: 'Chọn thành viên áp dụng',
                                        en: 'Select applicable members',
                                      ),
                                      initialSelected: _selectedMemberIds,
                                      onApplied: (picked) {
                                        setState(() {
                                          _selectedMemberIds = picked;
                                        });
                                      },
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.group_outlined),
                                label: Text(
                                  l10n.pick(
                                    vi: 'Chọn thành viên',
                                    en: 'Choose members',
                                  ),
                                ),
                              ),
                              if (selectedAppliedMembers.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    for (final member in selectedAppliedMembers)
                                      Chip(
                                        label: Text(
                                          '${member.fullName} • ${_memberKinshipBadge(member, context)}',
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                  ),
                ],
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        key: Key(
                          _editorStep == 0
                              ? 'fund-editor-cancel-button'
                              : 'fund-editor-back-step-button',
                        ),
                        onPressed: (_isSubmitting || widget.isSaving)
                            ? null
                            : _editorStep == 0
                            ? () => Navigator.of(context).pop()
                            : () {
                                setState(() => _editorStep = 0);
                              },
                        icon: Icon(
                          _editorStep == 0
                              ? Icons.close_outlined
                              : Icons.arrow_back_outlined,
                        ),
                        label: Text(
                          _editorStep == 0
                              ? l10n.profileCancelAction
                              : l10n.pick(vi: 'Quay lại', en: 'Back'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        key: Key(
                          _editorStep == 0
                              ? 'fund-editor-next-step-button'
                              : 'fund-save-button',
                        ),
                        onPressed: (_isSubmitting || widget.isSaving)
                            ? null
                            : _editorStep == 0
                            ? () {
                                if (_validateStepOne(showSnackBar: true)) {
                                  setState(() => _editorStep = 1);
                                }
                              }
                            : _submit,
                        icon: (_isSubmitting || widget.isSaving)
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(
                                _editorStep == 0
                                    ? Icons.arrow_forward_outlined
                                    : Icons.save_outlined,
                              ),
                        label: Text(
                          (_isSubmitting || widget.isSaving)
                              ? l10n.pick(vi: 'Đang lưu...', en: 'Saving...')
                              : _editorStep == 0
                              ? l10n.pick(vi: 'Tiếp tục', en: 'Continue')
                              : l10n.pick(vi: 'Lưu quỹ', en: 'Save fund'),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TransactionEditorSheet extends StatefulWidget {
  const _TransactionEditorSheet({
    required this.title,
    required this.description,
    required this.initialDraft,
    required this.isSaving,
    required this.onSubmit,
  });

  final String title;
  final String description;
  final FundTransactionDraft initialDraft;
  final bool isSaving;
  final Future<FundRepositoryErrorCode?> Function(FundTransactionDraft draft)
  onSubmit;

  @override
  State<_TransactionEditorSheet> createState() =>
      _TransactionEditorSheetState();
}

class _TransactionEditorSheetState extends State<_TransactionEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;
  late final TextEditingController _memberIdController;
  late final TextEditingController _referenceController;
  late DateTime _occurredAt;

  FundRepositoryErrorCode? _submitError;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.initialDraft.amountInput,
    );
    _noteController = TextEditingController(text: widget.initialDraft.note);
    _memberIdController = TextEditingController(
      text: widget.initialDraft.memberId ?? '',
    );
    _referenceController = TextEditingController(
      text: widget.initialDraft.externalReference ?? '',
    );
    _occurredAt = widget.initialDraft.occurredAt;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    _memberIdController.dispose();
    _referenceController.dispose();
    super.dispose();
  }

  Future<void> _pickOccurredDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
      initialDate: _occurredAt,
    );

    if (picked == null || !mounted) {
      return;
    }

    setState(() {
      _occurredAt = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _occurredAt.hour,
        _occurredAt.minute,
      );
    });
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
      FundTransactionDraft(
        fundId: widget.initialDraft.fundId,
        transactionType: widget.initialDraft.transactionType,
        amountInput: _amountController.text.trim(),
        currency: widget.initialDraft.currency,
        occurredAt: _occurredAt,
        note: _noteController.text.trim(),
        memberId: _nullIfBlank(_memberIdController.text),
        externalReference: _nullIfBlank(_referenceController.text),
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
                  widget.title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(widget.description, style: theme.textTheme.bodyMedium),
                if (_submitError != null) ...[
                  const SizedBox(height: 16),
                  _InfoCard(
                    icon: Icons.error_outline,
                    title: l10n.pick(
                      vi: 'Không thể lưu giao dịch',
                      en: 'Unable to save transaction',
                    ),
                    description: _errorMessageForCode(context, _submitError!),
                    tone: theme.colorScheme.errorContainer,
                  ),
                ],
                const SizedBox(height: 18),
                TextFormField(
                  key: const Key('fund-transaction-amount-input'),
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: l10n.pick(vi: 'Số tiền', en: 'Amount'),
                    hintText: widget.initialDraft.currency == 'VND'
                        ? l10n.pick(vi: '500000', en: '500000')
                        : l10n.pick(vi: '50.00', en: '50.00'),
                    suffixText: widget.initialDraft.currency,
                  ),
                  validator: (value) {
                    return value == null || value.trim().isEmpty
                        ? l10n.pick(
                            vi: 'Số tiền là bắt buộc.',
                            en: 'Amount is required.',
                          )
                        : null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  key: const Key('fund-transaction-note-input'),
                  controller: _noteController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: l10n.pick(vi: 'Ghi chú', en: 'Note'),
                    hintText: l10n.pick(
                      vi: 'Đóng góp Tết',
                      en: 'Tet contribution',
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  key: const Key('fund-transaction-member-input'),
                  controller: _memberIdController,
                  decoration: InputDecoration(
                    labelText: l10n.pick(
                      vi: 'Mã thành viên (tuỳ chọn)',
                      en: 'Member id (optional)',
                    ),
                    hintText: l10n.pick(
                      vi: 'thanh_vien_demo_001',
                      en: 'member_demo_parent_001',
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  key: const Key('fund-transaction-reference-input'),
                  controller: _referenceController,
                  decoration: InputDecoration(
                    labelText: l10n.pick(
                      vi: 'Mã tham chiếu (tuỳ chọn)',
                      en: 'Reference (optional)',
                    ),
                    hintText: l10n.pick(
                      vi: 'BIENLAI-2026-001',
                      en: 'RECEIPT-2026-001',
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: _pickOccurredDate,
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: l10n.pick(
                        vi: 'Ngày phát sinh',
                        en: 'Occurred date',
                      ),
                      suffixIcon: const Icon(Icons.calendar_today_outlined),
                    ),
                    child: Text(_formatDate(context, _occurredAt)),
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
                        : Icon(
                            widget.initialDraft.transactionType ==
                                    FundTransactionType.donation
                                ? Icons.add_circle_outline
                                : Icons.remove_circle_outline,
                          ),
                    label: Text(
                      (_isSubmitting || widget.isSaving)
                          ? l10n.pick(vi: 'Đang lưu...', en: 'Saving...')
                          : widget.initialDraft.transactionType ==
                                FundTransactionType.donation
                          ? l10n.pick(vi: 'Lưu đóng góp', en: 'Save donation')
                          : l10n.pick(vi: 'Lưu chi tiêu', en: 'Save expense'),
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

class _FundSummaryCard extends StatelessWidget {
  const _FundSummaryCard({
    super.key,
    required this.fund,
    this.memberCountLabel,
    required this.onTap,
    this.onEdit,
  });

  final FundProfile fund;
  final String? memberCountLabel;
  final VoidCallback onTap;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
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
                          fund.name,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _fundTypeLabel(context, fund.fundType),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if (memberCountLabel != null &&
                            memberCountLabel!.trim().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            memberCountLabel!,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (onEdit != null)
                    IconButton(
                      constraints: const BoxConstraints.tightFor(
                        width: 44,
                        height: 44,
                      ),
                      tooltip: context.l10n.pick(
                        vi: 'Chỉnh sửa quỹ',
                        en: 'Edit fund',
                      ),
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined),
                    ),
                ],
              ),
              if (fund.description.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  fund.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.trending_up_outlined, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _formatMoneyText(
                          context,
                          amountMinor: fund.balanceMinor,
                          currency: fund.currency,
                        ),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TransactionRow extends StatelessWidget {
  const _TransactionRow({required this.transaction});

  final FundTransaction transaction;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDonation =
        transaction.transactionType == FundTransactionType.donation;
    final tileColor = isDonation
        ? colorScheme.primaryContainer
        : colorScheme.tertiaryContainer;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: tileColor,
              child: Icon(
                isDonation ? Icons.add : Icons.remove,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          transaction.note.trim().isEmpty
                              ? transaction.transactionType.label
                              : transaction.note,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${isDonation ? '+' : '-'}${_formatMoneyText(context, amountMinor: transaction.amountMinor, currency: transaction.currency)}',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: isDonation
                              ? colorScheme.primary
                              : colorScheme.tertiary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${_transactionTypeLabel(context, transaction.transactionType)} • ${_formatDate(context, transaction.occurredAt)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if ((transaction.externalReference ?? '')
                      .trim()
                      .isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      '${context.l10n.pick(vi: 'Mã: ', en: 'Ref: ')}${transaction.externalReference}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
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

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.tone});

  final String label;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: tone,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700),
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
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color tone;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: tone,
      child: Padding(
        padding: EdgeInsets.all(compact ? 14 : 18),
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

class _FundTransferInfoCard extends StatelessWidget {
  const _FundTransferInfoCard({
    required this.accountNumber,
    required this.accountHolder,
    required this.onCopyAccountNumber,
    required this.onCopyAccountHolder,
    this.bankName,
  });

  final String? bankName;
  final String? accountNumber;
  final String? accountHolder;
  final ValueChanged<String> onCopyAccountNumber;
  final ValueChanged<String> onCopyAccountHolder;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final normalizedBankName = (bankName ?? '').trim();
    final normalizedAccountNumber = (accountNumber ?? '').trim();
    final normalizedAccountHolder = (accountHolder ?? '').trim();
    if (normalizedAccountNumber.isEmpty && normalizedAccountHolder.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.pick(
                vi: 'Thông tin chuyển khoản quỹ',
                en: 'Fund transfer details',
              ),
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            if (normalizedBankName.isNotEmpty) ...[
              const SizedBox(height: 8),
              _FundTransferInfoRow(
                label: l10n.pick(vi: 'Ngân hàng', en: 'Bank'),
                value: normalizedBankName,
                canCopy: false,
              ),
            ],
            if (normalizedAccountNumber.isNotEmpty) ...[
              const SizedBox(height: 8),
              _FundTransferInfoRow(
                label: l10n.pick(vi: 'Số tài khoản', en: 'Account number'),
                value: normalizedAccountNumber,
                canCopy: true,
                onCopy: () => onCopyAccountNumber(normalizedAccountNumber),
              ),
            ],
            if (normalizedAccountHolder.isNotEmpty) ...[
              const SizedBox(height: 8),
              _FundTransferInfoRow(
                label: l10n.pick(vi: 'Chủ tài khoản', en: 'Account holder'),
                value: normalizedAccountHolder,
                canCopy: true,
                onCopy: () => onCopyAccountHolder(normalizedAccountHolder),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FundTransferInfoRow extends StatelessWidget {
  const _FundTransferInfoRow({
    required this.label,
    required this.value,
    required this.canCopy,
    this.onCopy,
  });

  final String label;
  final String value;
  final bool canCopy;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(value)),
        const SizedBox(width: 8),
        if (canCopy)
          IconButton(
            tooltip: context.l10n.pick(vi: 'Sao chép', en: 'Copy'),
            icon: const Icon(Icons.copy_outlined),
            visualDensity: VisualDensity.compact,
            onPressed: onCopy,
          ),
      ],
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
          ],
        ),
      ),
    );
  }
}

class _WorkspaceHero extends StatelessWidget {
  const _WorkspaceHero({
    required this.title,
    required this.description,
    required this.canManageFunds,
    this.compact = false,
    this.onPrimaryAction,
  });

  final String title;
  final String description;
  final bool canManageFunds;
  final bool compact;
  final VoidCallback? onPrimaryAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = context.l10n;

    return Container(
      padding: EdgeInsets.all(compact ? 18 : 24),
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
            style:
                (compact
                        ? theme.textTheme.titleLarge
                        : theme.textTheme.headlineSmall)
                    ?.copyWith(
                      color: colorScheme.onPrimary,
                      fontWeight: FontWeight.w800,
                    ),
          ),
          SizedBox(height: compact ? 8 : 10),
          Text(
            description,
            maxLines: compact ? 2 : null,
            overflow: compact ? TextOverflow.ellipsis : TextOverflow.visible,
            style:
                (compact
                        ? theme.textTheme.bodyMedium
                        : theme.textTheme.bodyLarge)
                    ?.copyWith(
                      color: colorScheme.onPrimary.withValues(alpha: 0.9),
                    ),
          ),
          if (canManageFunds && onPrimaryAction != null) ...[
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onPrimaryAction,
              icon: const Icon(Icons.add),
              label: Text(
                l10n.pick(vi: 'Tạo quỹ đầu tiên', en: 'Create first fund'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FundEditorStepIndicator extends StatelessWidget {
  const _FundEditorStepIndicator({
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
    if (labels.isEmpty) {
      return const SizedBox.shrink();
    }
    final safeStep = currentStep.clamp(0, labels.length - 1);
    const nodeSize = 34.0;
    const indicatorHeight = 64.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final cellWidth = constraints.maxWidth / labels.length;
        final lineInset = cellWidth / 2;
        final segmentCount = labels.length - 1;
        final progress = segmentCount <= 0 ? 1.0 : safeStep / segmentCount;

        return SizedBox(
          height: indicatorHeight,
          child: Stack(
            children: [
              if (labels.length > 1)
                Positioned(
                  left: lineInset,
                  right: lineInset,
                  top: (nodeSize / 2) - 1.5,
                  child: Container(
                    height: 3,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: colorScheme.outlineVariant,
                    ),
                  ),
                ),
              if (labels.length > 1)
                Positioned(
                  left: lineInset,
                  right: lineInset,
                  top: (nodeSize / 2) - 1.5,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: progress,
                      child: Container(
                        height: 3,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          color: colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                ),
              Row(
                children: [
                  for (var index = 0; index < labels.length; index++)
                    Expanded(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => onStepSelected(index),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  width: nodeSize,
                                  height: nodeSize,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: index <= safeStep
                                        ? colorScheme.primary
                                        : colorScheme.surfaceContainerHighest,
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    '${index + 1}',
                                    style: textTheme.titleSmall?.copyWith(
                                      color: index <= safeStep
                                          ? colorScheme.onPrimary
                                          : colorScheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  labels[index],
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: textTheme.titleSmall?.copyWith(
                                    fontWeight: index == safeStep
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.items});

  final List<_StatTile> items;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final crossAxisCount = screenWidth > 840 ? 3 : 2;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final baseHeight = crossAxisCount == 2 ? 158.0 : 142.0;
    final scaleBoost = ((textScale - 1).clamp(0.0, 1.2)).toDouble() * 30;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        mainAxisExtent: baseHeight + scaleBoost,
      ),
      itemBuilder: (context, index) {
        return items[index];
      },
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    this.iconBackgroundColor,
    this.valueColor,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color? iconBackgroundColor;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor:
                      iconBackgroundColor ?? colorScheme.primaryContainer,
                  radius: 20,
                  child: Icon(icon, size: 19),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: valueColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatMoneyText(
  BuildContext context, {
  required int amountMinor,
  required String currency,
}) {
  return CurrencyMinorUnits.formatMinorUnits(
    amountMinor: amountMinor,
    currency: currency,
    locale: Localizations.localeOf(context).toLanguageTag(),
  );
}

String _titleCase(String value) {
  final clean = value.trim().replaceAll('_', ' ');
  if (clean.isEmpty) {
    return '';
  }

  final words = clean.split(RegExp(r'\s+'));
  return words
      .map((word) {
        if (word.isEmpty) {
          return word;
        }
        return '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}';
      })
      .join(' ');
}

String _fundTypeLabel(BuildContext context, String fundType) {
  final l10n = context.l10n;
  return switch (fundType.trim().toLowerCase()) {
    'scholarship' => l10n.pick(vi: 'Khuyến học', en: 'Scholarship'),
    'operations' => l10n.pick(vi: 'Vận hành', en: 'Operations'),
    'maintenance' => l10n.pick(vi: 'Bảo trì', en: 'Maintenance'),
    'custom' => l10n.pick(vi: 'Tuỳ chỉnh', en: 'Custom'),
    _ => _titleCase(fundType),
  };
}

String _transactionTypeLabel(BuildContext context, FundTransactionType type) {
  final l10n = context.l10n;
  return switch (type) {
    FundTransactionType.donation => l10n.pick(vi: 'Đóng góp', en: 'Donation'),
    FundTransactionType.expense => l10n.pick(vi: 'Chi tiêu', en: 'Expense'),
  };
}

String _formatDate(BuildContext context, DateTime value) {
  final local = value.toLocal();
  return MaterialLocalizations.of(context).formatCompactDate(local);
}

String? _nullIfBlank(String? value) {
  final trimmed = value?.trim() ?? '';
  return trimmed.isEmpty ? null : trimmed;
}

String _clanContextDisplayLabel(
  BuildContext context,
  ClanContextOption option,
) {
  final explicitName = option.clanName.trim();
  if (explicitName.isNotEmpty && !_looksLikeIdentifier(explicitName)) {
    return explicitName;
  }

  final ownerName = (option.ownerDisplayName ?? '').trim();
  if (ownerName.isNotEmpty) {
    return context.l10n.pick(
      vi: 'Gia phả của $ownerName',
      en: "$ownerName's clan",
    );
  }

  final memberName = (option.displayName ?? '').trim();
  if (memberName.isNotEmpty) {
    return context.l10n.pick(
      vi: 'Gia phả của $memberName',
      en: "$memberName's clan",
    );
  }

  final readableClanId = _humanizeIdentifier(option.clanId);
  return readableClanId.isEmpty ? option.clanId : readableClanId;
}

bool _looksLikeIdentifier(String value) {
  final normalized = value.trim().toLowerCase();
  if (normalized.isEmpty) {
    return false;
  }
  return RegExp(r'^[a-z0-9]+(?:[_-][a-z0-9]+)*$').hasMatch(normalized);
}

String _humanizeIdentifier(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    return '';
  }
  final noPrefix = normalized.replaceFirst(
    RegExp(r'^(clan|gia[_-]?pha)[_-]?', caseSensitive: false),
    '',
  );
  final tokens = (noPrefix.isEmpty ? normalized : noPrefix)
      .replaceAll(RegExp(r'[_-]+'), ' ')
      .split(RegExp(r'\s+'))
      .where((item) => item.trim().isNotEmpty)
      .map((item) {
        final text = item.trim();
        return '${text[0].toUpperCase()}${text.substring(1).toLowerCase()}';
      })
      .toList(growable: false);
  if (tokens.isEmpty) {
    return '';
  }
  return tokens.join(' ');
}

String _formatDateTime(BuildContext context, DateTime value) {
  final local = value.toLocal();
  final date = MaterialLocalizations.of(context).formatCompactDate(local);
  final time = MaterialLocalizations.of(
    context,
  ).formatTimeOfDay(TimeOfDay.fromDateTime(local), alwaysUse24HourFormat: true);
  return '$date • $time';
}

String _errorMessageForCode(
  BuildContext context,
  FundRepositoryErrorCode code,
) {
  final l10n = context.l10n;
  return switch (code) {
    FundRepositoryErrorCode.permissionDenied => l10n.pick(
      vi: 'Bạn không có quyền thực hiện thao tác này.',
      en: 'You do not have permission for this action.',
    ),
    FundRepositoryErrorCode.fundNotFound => l10n.pick(
      vi: 'Không tìm thấy quỹ đã chọn.',
      en: 'The selected fund was not found.',
    ),
    FundRepositoryErrorCode.invalidCurrency => l10n.pick(
      vi: 'Tiền tệ không hợp lệ. Hãy dùng mã ISO 3 ký tự như VND hoặc USD.',
      en: 'Currency is invalid. Use a 3-letter ISO code like VND or USD.',
    ),
    FundRepositoryErrorCode.invalidAmount => l10n.pick(
      vi: 'Số tiền không hợp lệ. Vui lòng kiểm tra định dạng.',
      en: 'Amount is invalid. Check decimal format and value.',
    ),
    FundRepositoryErrorCode.insufficientBalance => l10n.pick(
      vi: 'Khoản chi vượt quá số dư hiện tại.',
      en: 'Expense exceeds available balance.',
    ),
    FundRepositoryErrorCode.validationFailed => l10n.pick(
      vi: 'Dữ liệu gửi lên chưa hợp lệ.',
      en: 'Submitted data did not pass validation.',
    ),
    FundRepositoryErrorCode.writeFailed => l10n.pick(
      vi: 'Không thể lưu thay đổi lúc này. Vui lòng thử lại.',
      en: 'Unable to save changes right now. Try again.',
    ),
  };
}

extension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) {
      return null;
    }
    return iterator.current;
  }
}
