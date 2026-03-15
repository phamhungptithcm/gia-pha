import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/widgets/app_feedback_states.dart';
import '../../../l10n/l10n.dart';
import '../../auth/models/auth_session.dart';
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
  });

  final AuthSession session;
  final FundRepository repository;

  @override
  State<FundWorkspacePage> createState() => _FundWorkspacePageState();
}

class _FundWorkspacePageState extends State<FundWorkspacePage> {
  late final FundController _controller;

  @override
  void initState() {
    super.initState();
    _controller = FundController(
      repository: widget.repository,
      session: widget.session,
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
                : !_controller.hasClanContext
                ? _EmptyWorkspace(
                    icon: Icons.lock_outline,
                    title: l10n.pick(
                      vi: 'Thiếu ngữ cảnh họ tộc',
                      en: 'No clan context',
                    ),
                    description: l10n.pick(
                      vi: 'Liên kết tài khoản này với một họ tộc trước khi xem quỹ và giao dịch.',
                      en: 'Link this account to a clan before viewing funds and transactions.',
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
    final didSave = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _TransactionEditorSheet(
          title: type == FundTransactionType.donation
              ? 'Record donation'
              : 'Record expense',
          description: type == FundTransactionType.donation
              ? 'Add incoming contributions to this fund.'
              : 'Log outgoing expenses from this fund.',
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
                ? 'Donation saved.'
                : 'Expense saved.',
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

        if (fund == null) {
          return const Scaffold(
            body: SafeArea(
              child: _EmptyWorkspace(
                icon: Icons.search_off,
                title: 'Fund not found',
                description: 'This fund may have been removed or changed.',
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
                tooltip: 'Refresh',
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
                        _titleCase(fund.fundType),
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: colorScheme.onPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Running balance',
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
                              label: const Text('Add donation'),
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
                              label: const Text('Add expense'),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _SectionCard(
                  title: 'Transaction filters',
                  actionLabel:
                      widget.controller.filters.query.trim().isNotEmpty ||
                          widget.controller.filters.transactionType != null
                      ? 'Clear'
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
                        decoration: const InputDecoration(
                          labelText: 'Search note/reference/member',
                          prefixIcon: Icon(Icons.search),
                        ),
                        textInputAction: TextInputAction.search,
                        onChanged: widget.controller.updateQueryFilter,
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<FundTransactionType?>(
                        initialValue: widget.controller.filters.transactionType,
                        decoration: const InputDecoration(
                          labelText: 'Transaction type',
                        ),
                        items: const [
                          DropdownMenuItem<FundTransactionType?>(
                            value: null,
                            child: Text('All types'),
                          ),
                          DropdownMenuItem<FundTransactionType?>(
                            value: FundTransactionType.donation,
                            child: Text('Donations'),
                          ),
                          DropdownMenuItem<FundTransactionType?>(
                            value: FundTransactionType.expense,
                            child: Text('Expenses'),
                          ),
                        ],
                        onChanged: widget.controller.updateTypeFilter,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _SectionCard(
                  title: 'Transaction history',
                  actionLabel: widget.controller.canManageFunds
                      ? 'Donation'
                      : null,
                  onAction: widget.controller.canManageFunds
                      ? () => _openTransactionEditor(
                          fund,
                          FundTransactionType.donation,
                        )
                      : null,
                  child: transactions.isEmpty
                      ? const _EmptyWorkspace(
                          icon: Icons.receipt_long_outlined,
                          title: 'No transactions',
                          description:
                              'Create a donation or expense to populate this ledger.',
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
    required this.isSaving,
    required this.onSubmit,
  });

  final String title;
  final String description;
  final FundDraft initialDraft;
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

    final error = await widget.onSubmit(
      FundDraft(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        fundType: _fundType,
        currency: _currency,
        branchId: _nullIfBlank(_branchIdController.text),
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
                    title: 'Unable to save fund',
                    description: _errorMessageForCode(_submitError!),
                    tone: theme.colorScheme.errorContainer,
                  ),
                ],
                const SizedBox(height: 18),
                TextFormField(
                  key: const Key('fund-name-input'),
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Fund name',
                    hintText: 'Scholarship Fund',
                  ),
                  validator: (value) {
                    return value == null || value.trim().isEmpty
                        ? 'Fund name is required.'
                        : null;
                  },
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: _fundType,
                  decoration: const InputDecoration(labelText: 'Fund type'),
                  items: [
                    for (final type in _fundTypes)
                      DropdownMenuItem<String>(
                        value: type,
                        child: Text(_titleCase(type)),
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
                  decoration: const InputDecoration(labelText: 'Currency'),
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
                  decoration: const InputDecoration(
                    labelText: 'Branch id (optional)',
                    hintText: 'branch_demo_001',
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  key: const Key('fund-description-input'),
                  controller: _descriptionController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText:
                        'Describe who this fund supports and how it is used.',
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
                          ? 'Saving...'
                          : 'Save fund',
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
                    title: 'Unable to save transaction',
                    description: _errorMessageForCode(_submitError!),
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
                    labelText: 'Amount',
                    hintText: widget.initialDraft.currency == 'VND'
                        ? '500000'
                        : '50.00',
                    suffixText: widget.initialDraft.currency,
                  ),
                  validator: (value) {
                    return value == null || value.trim().isEmpty
                        ? 'Amount is required.'
                        : null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  key: const Key('fund-transaction-note-input'),
                  controller: _noteController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Note',
                    hintText: 'Tet contribution',
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  key: const Key('fund-transaction-member-input'),
                  controller: _memberIdController,
                  decoration: const InputDecoration(
                    labelText: 'Member id (optional)',
                    hintText: 'member_demo_parent_001',
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  key: const Key('fund-transaction-reference-input'),
                  controller: _referenceController,
                  decoration: const InputDecoration(
                    labelText: 'Reference (optional)',
                    hintText: 'RECEIPT-2026-001',
                  ),
                ),
                const SizedBox(height: 14),
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: _pickOccurredDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Occurred date',
                      suffixIcon: Icon(Icons.calendar_today_outlined),
                    ),
                    child: Text(_formatDate(_occurredAt)),
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
                          ? 'Saving...'
                          : widget.initialDraft.transactionType ==
                                FundTransactionType.donation
                          ? 'Save donation'
                          : 'Save expense',
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
    required this.onTap,
    this.onEdit,
  });

  final FundProfile fund;
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
                      ],
                    ),
                  ),
                  if (onEdit != null)
                    IconButton(
                      tooltip: 'Edit fund',
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
                    '${transaction.transactionType.label} • ${_formatDate(transaction.occurredAt)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if ((transaction.externalReference ?? '')
                      .trim()
                      .isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Ref: ${transaction.externalReference}',
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
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _HeroTag(
                label: canManageFunds ? 'Write enabled' : 'Read-only access',
                tone: colorScheme.secondaryContainer,
              ),
              _HeroTag(
                label: 'Balance + history',
                tone: colorScheme.surfaceContainerHighest,
              ),
            ],
          ),
          if (canManageFunds && onPrimaryAction != null) ...[
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onPrimaryAction,
              icon: const Icon(Icons.add),
              label: const Text('Create first fund'),
            ),
          ],
        ],
      ),
    );
  }
}

class _HeroTag extends StatelessWidget {
  const _HeroTag({required this.label, required this.tone});

  final String label;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tone,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
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

String _formatDate(DateTime value) {
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '${local.year}-$month-$day';
}

String? _nullIfBlank(String? value) {
  final trimmed = value?.trim() ?? '';
  return trimmed.isEmpty ? null : trimmed;
}

String _errorMessageForCode(FundRepositoryErrorCode code) {
  return switch (code) {
    FundRepositoryErrorCode.permissionDenied =>
      'You do not have permission for this action.',
    FundRepositoryErrorCode.fundNotFound => 'The selected fund was not found.',
    FundRepositoryErrorCode.invalidCurrency =>
      'Currency is invalid. Use a 3-letter ISO code like VND or USD.',
    FundRepositoryErrorCode.invalidAmount =>
      'Amount is invalid. Check decimal format and value.',
    FundRepositoryErrorCode.insufficientBalance =>
      'Expense exceeds available balance.',
    FundRepositoryErrorCode.validationFailed =>
      'Submitted data did not pass validation.',
    FundRepositoryErrorCode.writeFailed =>
      'Unable to save changes right now. Try again.',
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
