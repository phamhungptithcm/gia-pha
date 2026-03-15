import 'dart:async';

import 'package:flutter/material.dart';

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
import '../services/currency_minor_units.dart';
import '../services/fund_repository.dart';
import 'fund_controller.dart';

class FundWorkspacePage extends StatefulWidget {
  const FundWorkspacePage({
    super.key,
    required this.session,
    required this.repository,
    this.memberRepository,
    this.availableClanContexts = const [],
    this.onSwitchClanContext,
  });

  final AuthSession session;
  final FundRepository repository;
  final MemberRepository? memberRepository;
  final List<ClanContextOption> availableClanContexts;
  final Future<AuthSession?> Function(String clanId)? onSwitchClanContext;

  @override
  State<FundWorkspacePage> createState() => _FundWorkspacePageState();
}

class _FundWorkspacePageState extends State<FundWorkspacePage> {
  late FundController _controller;
  late AuthSession _activeSession;
  late MemberRepository _memberRepository;
  bool _isSwitchingClanContext = false;
  String _cachedMembersClanId = '';
  List<MemberProfile> _cachedMembers = const [];

  AuthSession get _session => _activeSession;

  List<ClanContextOption> get _clanContexts {
    if (widget.availableClanContexts.isNotEmpty) {
      return widget.availableClanContexts;
    }
    final clanId = (_session.clanId ?? '').trim();
    if (clanId.isEmpty) {
      return const [];
    }
    return [
      ClanContextOption(
        clanId: clanId,
        clanName: clanId,
        memberId: (_session.memberId ?? '').trim(),
        primaryRole: (_session.primaryRole ?? 'MEMBER').trim().toUpperCase(),
        branchId: _nullIfBlank(_session.branchId),
        displayName: _nullIfBlank(_session.displayName),
      ),
    ];
  }

  @override
  void initState() {
    super.initState();
    _activeSession = widget.session;
    _memberRepository =
        widget.memberRepository ??
        createDefaultMemberRepository(session: _session);
    _controller = FundController(
      repository: widget.repository,
      session: _session,
    );
    unawaited(_controller.initialize());
  }

  @override
  void didUpdateWidget(covariant FundWorkspacePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final sessionChanged = oldWidget.session != widget.session;
    final repositoryChanged = oldWidget.repository != widget.repository;
    final memberRepositoryChanged =
        oldWidget.memberRepository != widget.memberRepository;
    if (!sessionChanged && !repositoryChanged && !memberRepositoryChanged) {
      return;
    }

    _activeSession = widget.session;
    if (memberRepositoryChanged) {
      _memberRepository =
          widget.memberRepository ??
          createDefaultMemberRepository(session: _session);
    }
    _cachedMembers = const [];
    _cachedMembersClanId = '';
    _controller.dispose();
    _controller = FundController(
      repository: widget.repository,
      session: _session,
    );
    unawaited(_controller.initialize());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
            vi: 'Thiết lập hồ sơ quỹ để ghi nhận đóng góp, chi tiêu và theo dõi số dư minh bạch.',
            en: 'Set up a fund profile for donations, expenses, and transparent balance tracking.',
          ),
          initialDraft: fund == null
              ? FundDraft.empty()
              : FundDraft.fromProfile(fund),
          availableClanContexts: _clanContexts,
          activeClanId: (_session.clanId ?? '').trim(),
          onEnsureClanContext: _ensureClanContext,
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

  Future<bool> _ensureClanContext(String clanId) async {
    final normalizedClanId = clanId.trim();
    if (normalizedClanId.isEmpty) {
      return false;
    }
    if (normalizedClanId == (_session.clanId ?? '').trim()) {
      return true;
    }
    final switched = await _switchClanContext(normalizedClanId);
    return switched != null &&
        (switched.clanId ?? '').trim() == normalizedClanId;
  }

  Future<List<MemberProfile>> _loadMembersForClan(String clanId) async {
    final normalizedClanId = clanId.trim();
    if (normalizedClanId.isEmpty) {
      return const [];
    }
    if (_cachedMembersClanId == normalizedClanId && _cachedMembers.isNotEmpty) {
      return _cachedMembers;
    }

    AuthSession effectiveSession = _session;
    if ((_session.clanId ?? '').trim() != normalizedClanId) {
      final switched = await _switchClanContext(normalizedClanId);
      if (switched == null) {
        return const [];
      }
      effectiveSession = switched;
    }

    final snapshot = await _memberRepository.loadWorkspace(
      session: effectiveSession,
    );
    final members = snapshot.members
        .where((member) => member.clanId.trim() == normalizedClanId)
        .toList(growable: false);
    _cachedMembersClanId = normalizedClanId;
    _cachedMembers = members;
    return members;
  }

  Future<AuthSession?> _switchClanContext(String clanId) async {
    final normalizedClanId = clanId.trim();
    if (normalizedClanId.isEmpty) {
      return null;
    }
    if (normalizedClanId == (_session.clanId ?? '').trim()) {
      return _session;
    }
    final switcher = widget.onSwitchClanContext;
    if (switcher == null) {
      return null;
    }
    if (_isSwitchingClanContext) {
      return null;
    }

    setState(() {
      _isSwitchingClanContext = true;
    });
    try {
      final switched = await switcher(normalizedClanId);
      if (switched == null) {
        return null;
      }
      if (!mounted) {
        return switched;
      }
      _activeSession = switched;
      _cachedMembers = const [];
      _cachedMembersClanId = '';
      _controller.dispose();
      _controller = FundController(
        repository: widget.repository,
        session: _session,
      );
      setState(() {});
      await _controller.initialize();
      return _session;
    } finally {
      if (mounted) {
        setState(() {
          _isSwitchingClanContext = false;
        });
      } else {
        _isSwitchingClanContext = false;
      }
    }
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

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final l10n = context.l10n;
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;

        return Scaffold(
          appBar: AppBar(
            title: Text(l10n.pick(vi: 'Quỹ', en: 'Funds')),
            actions: [
              if (_isSwitchingClanContext)
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else if (_clanContexts.length > 1)
                PopupMenuButton<String>(
                  tooltip: l10n.pick(vi: 'Chuyển gia phả', en: 'Switch clan'),
                  onSelected: (clanId) {
                    unawaited(_switchClanContext(clanId));
                  },
                  itemBuilder: (context) => [
                    for (final option in _clanContexts)
                      PopupMenuItem<String>(
                        value: option.clanId,
                        child: Text(
                          option.clanId == (_session.clanId ?? '').trim()
                              ? '• ${option.clanName}'
                              : option.clanName,
                        ),
                      ),
                  ],
                  icon: const Icon(Icons.account_tree_outlined),
                ),
              IconButton(
                tooltip: l10n.pick(vi: 'Tải lại', en: 'Refresh'),
                onPressed: _controller.isLoading ? null : _controller.refresh,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          floatingActionButton: _controller.canManageFunds
              ? FloatingActionButton.extended(
                  onPressed: () => _openFundEditor(),
                  tooltip: l10n.pick(vi: 'Thêm quỹ', en: 'Add fund'),
                  icon: const Icon(Icons.add),
                  label: Text(l10n.pick(vi: 'Thêm quỹ', en: 'Add fund')),
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
                      vi: 'Chỉ vai trò Trưởng tộc, Trưởng chi, hoặc Thủ quỹ mới xem được sổ quỹ.',
                      en: 'Only Clan Lead, Branch Lead, or Treasurer roles can access the fund ledger.',
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _controller.refresh,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                      children: [
                        _WorkspaceHero(
                          title: l10n.pick(
                            vi: 'Không gian sổ quỹ',
                            en: 'Fund ledger workspace',
                          ),
                          description: l10n.pick(
                            vi: 'Theo dõi đóng góp, chi tiêu, số dư hiện tại và lịch sử theo từng quỹ.',
                            en: 'Track donations, expenses, running balance, and history across each fund.',
                          ),
                          canManageFunds: _controller.canManageFunds,
                          onPrimaryAction: _controller.canManageFunds
                              ? () => _openFundEditor()
                              : null,
                        ),
                        const SizedBox(height: 16),
                        _ClanScopeCard(
                          activeClanId: (_session.clanId ?? '').trim(),
                          clanContexts: _clanContexts,
                          isSwitching: _isSwitchingClanContext,
                          onSwitch: widget.onSwitchClanContext == null
                              ? null
                              : (clanId) => _switchClanContext(clanId),
                        ),
                        const SizedBox(height: 20),
                        if (_controller.errorMessage case final error?) ...[
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
                              onPressed: _controller.refresh,
                              icon: const Icon(Icons.refresh),
                              label: Text(
                                l10n.pick(vi: 'Tải lại', en: 'Retry'),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                        if (!_controller.canManageFunds) ...[
                          _InfoCard(
                            icon: Icons.visibility_outlined,
                            title: l10n.pick(
                              vi: 'Vai trò chỉ xem',
                              en: 'Read-only role',
                            ),
                            description: l10n.pick(
                              vi: 'Chỉ quản trị cấp họ tộc mới có thể tạo quỹ hoặc ghi giao dịch.',
                              en: 'Only clan-level administrators can create funds or post transactions.',
                            ),
                            tone: colorScheme.secondaryContainer,
                          ),
                          const SizedBox(height: 20),
                        ],
                        _StatRow(
                          items: [
                            _StatTile(
                              label: l10n.pick(vi: 'Quỹ', en: 'Funds'),
                              value: '${_controller.funds.length}',
                              icon: Icons.account_balance_wallet_outlined,
                            ),
                            _StatTile(
                              label: l10n.pick(
                                vi: 'Giao dịch',
                                en: 'Transactions',
                              ),
                              value: '${_controller.transactions.length}',
                              icon: Icons.receipt_long_outlined,
                            ),
                            _StatTile(
                              label: l10n.pick(
                                vi: 'Quyền truy cập',
                                en: 'Access',
                              ),
                              value: _controller.canManageFunds
                                  ? l10n.pick(vi: 'Ghi', en: 'Write')
                                  : l10n.pick(vi: 'Đọc', en: 'Read'),
                              icon: Icons.verified_user_outlined,
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _SectionCard(
                          title: l10n.pick(
                            vi: 'Danh sách quỹ',
                            en: 'Fund list',
                          ),
                          actionLabel: _controller.canManageFunds
                              ? l10n.pick(vi: 'Tạo quỹ', en: 'Create fund')
                              : null,
                          onAction: _controller.canManageFunds
                              ? () => _openFundEditor()
                              : null,
                          child: _controller.funds.isEmpty
                              ? _EmptyWorkspace(
                                  icon: Icons.savings_outlined,
                                  title: l10n.pick(
                                    vi: 'Chưa có quỹ nào',
                                    en: 'No funds yet',
                                  ),
                                  description: l10n.pick(
                                    vi: 'Tạo quỹ đầu tiên để bắt đầu ghi nhận đóng góp và chi tiêu.',
                                    en: 'Create the first fund to start recording donations and expenses.',
                                  ),
                                )
                              : Column(
                                  children: [
                                    for (
                                      var i = 0;
                                      i < _controller.funds.length;
                                      i++
                                    )
                                      Padding(
                                        padding: EdgeInsets.only(
                                          bottom:
                                              i == _controller.funds.length - 1
                                              ? 0
                                              : 14,
                                        ),
                                        child: _FundSummaryCard(
                                          fund: _controller.funds[i],
                                          memberCountLabel:
                                              _memberCountLabelForFund(
                                                context,
                                                _controller.funds[i],
                                              ),
                                          onTap: () => _openFundDetail(
                                            _controller.funds[i],
                                          ),
                                          onEdit: _controller.canManageFunds
                                              ? () => _openFundEditor(
                                                  fund: _controller.funds[i],
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
        );
      },
    );
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
                        CurrencyMinorUnits.formatMinorUnits(
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
                            vi: 'Tạo giao dịch đóng góp hoặc chi tiêu để hiển thị sổ quỹ.',
                            en: 'Create a donation or expense to populate this ledger.',
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
    required this.availableClanContexts,
    required this.activeClanId,
    required this.onEnsureClanContext,
    required this.loadMembersForClan,
    required this.isSaving,
    required this.onSubmit,
  });

  final String title;
  final String description;
  final FundDraft initialDraft;
  final List<ClanContextOption> availableClanContexts;
  final String activeClanId;
  final Future<bool> Function(String clanId) onEnsureClanContext;
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
  bool _isLoadingMembers = false;
  String? _memberLoadError;
  FundRepositoryErrorCode? _submitError;
  bool _isSubmitting = false;

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
    final candidateClanId =
        _nullIfBlank(widget.initialDraft.clanId) ??
        _nullIfBlank(widget.activeClanId) ??
        (widget.availableClanContexts.isNotEmpty
            ? widget.availableClanContexts.first.clanId
            : '');
    if (widget.availableClanContexts.isNotEmpty &&
        !widget.availableClanContexts.any(
          (entry) => entry.clanId.trim() == candidateClanId.trim(),
        )) {
      _selectedClanId = widget.availableClanContexts.first.clanId;
    } else {
      _selectedClanId = candidateClanId;
    }
    _selectedMemberIds = widget.initialDraft.appliedMemberIds
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

    final clanReady = await widget.onEnsureClanContext(targetClanId);
    if (!clanReady) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSubmitting = false;
        _submitError = FundRepositoryErrorCode.permissionDenied;
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
        _memberLoadError = null;
      });
      return;
    }

    setState(() {
      _isLoadingMembers = true;
      _memberLoadError = null;
    });
    try {
      final ensured = await widget.onEnsureClanContext(normalizedClanId);
      if (!ensured) {
        throw StateError('switch_context_failed');
      }
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

  Future<void> _handleClanChanged(String? clanId) async {
    final normalizedClanId = _nullIfBlank(clanId);
    if (normalizedClanId == null || normalizedClanId == _selectedClanId) {
      return;
    }
    setState(() {
      _selectedClanId = normalizedClanId;
      _selectedMemberIds.clear();
    });
    await _loadMembersForClan(normalizedClanId);
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
                      vi: 'Không thể lưu quỹ',
                      en: 'Unable to save fund',
                    ),
                    description: _errorMessageForCode(context, _submitError!),
                    tone: theme.colorScheme.errorContainer,
                  ),
                ],
                const SizedBox(height: 18),
                DropdownButtonFormField<String>(
                  key: const Key('fund-clan-selector'),
                  initialValue: _selectedClanId.isEmpty
                      ? null
                      : _selectedClanId,
                  decoration: InputDecoration(
                    labelText: l10n.pick(
                      vi: 'Gia phả quản lý',
                      en: 'Target clan',
                    ),
                  ),
                  items: [
                    for (final contextOption in widget.availableClanContexts)
                      DropdownMenuItem<String>(
                        value: contextOption.clanId,
                        child: Text(contextOption.clanName),
                      ),
                    if (widget.availableClanContexts.isEmpty &&
                        _selectedClanId.isNotEmpty)
                      DropdownMenuItem<String>(
                        value: _selectedClanId,
                        child: Text(_selectedClanId),
                      ),
                  ],
                  onChanged: (value) {
                    unawaited(_handleClanChanged(value));
                  },
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
                              child: CircularProgressIndicator(strokeWidth: 2),
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
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final member in _members)
                                  FilterChip(
                                    label: Text(member.displayName),
                                    selected: _selectedMemberIds.contains(
                                      member.id,
                                    ),
                                    onSelected: (selected) {
                                      setState(() {
                                        if (selected) {
                                          _selectedMemberIds.add(member.id);
                                        } else {
                                          _selectedMemberIds.remove(member.id);
                                        }
                                      });
                                    },
                                  ),
                              ],
                            ),
                          ],
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
                          ? l10n.pick(vi: 'Đang lưu...', en: 'Saving...')
                          : l10n.pick(vi: 'Lưu quỹ', en: 'Save fund'),
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
                          _titleCase(fund.fundType),
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
                        CurrencyMinorUnits.formatMinorUnits(
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
                        '${isDonation ? '+' : '-'}${CurrencyMinorUnits.formatMinorUnits(amountMinor: transaction.amountMinor, currency: transaction.currency)}',
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

class _ClanScopeCard extends StatelessWidget {
  const _ClanScopeCard({
    required this.activeClanId,
    required this.clanContexts,
    required this.isSwitching,
    this.onSwitch,
  });

  final String activeClanId;
  final List<ClanContextOption> clanContexts;
  final bool isSwitching;
  final Future<AuthSession?> Function(String clanId)? onSwitch;

  @override
  Widget build(BuildContext context) {
    if (clanContexts.isEmpty) {
      return const SizedBox.shrink();
    }
    final activeContext = clanContexts.firstWhere(
      (item) => item.clanId.trim() == activeClanId.trim(),
      orElse: () => clanContexts.first,
    );
    final l10n = context.l10n;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.account_tree_outlined),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.pick(
                      vi: 'Phạm vi gia phả đang quản lý',
                      en: 'Active clan scope',
                    ),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (isSwitching)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: activeContext.clanId,
              decoration: InputDecoration(
                labelText: l10n.pick(vi: 'Gia phả', en: 'Clan'),
              ),
              items: [
                for (final contextOption in clanContexts)
                  DropdownMenuItem<String>(
                    value: contextOption.clanId,
                    child: Text(contextOption.clanName),
                  ),
              ],
              onChanged: onSwitch == null || isSwitching
                  ? null
                  : (value) {
                      final resolved = _nullIfBlank(value);
                      if (resolved == null) {
                        return;
                      }
                      unawaited(onSwitch!(resolved));
                    },
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
    this.onPrimaryAction,
  });

  final String title;
  final String description;
  final bool canManageFunds;
  final VoidCallback? onPrimaryAction;

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

class _StatRow extends StatelessWidget {
  const _StatRow({required this.items});

  final List<_StatTile> items;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final crossAxisCount = screenWidth > 840 ? 3 : 1;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: crossAxisCount == 1 ? 3.4 : 1.8,
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
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: colorScheme.primaryContainer,
              child: Icon(icon),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(label, style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
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
