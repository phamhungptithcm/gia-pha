import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/widgets/app_feedback_states.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../l10n/l10n.dart';
import '../../auth/models/auth_session.dart';
import '../models/billing_workspace_snapshot.dart';
import '../services/billing_repository.dart';
import 'billing_controller.dart';

class BillingWorkspacePage extends StatefulWidget {
  const BillingWorkspacePage({
    super.key,
    required this.session,
    this.repository,
    this.embeddedInShell = false,
  });

  final AuthSession session;
  final BillingRepository? repository;
  final bool embeddedInShell;

  @override
  State<BillingWorkspacePage> createState() => _BillingWorkspacePageState();
}

class _BillingWorkspacePageState extends State<BillingWorkspacePage> {
  late final BillingController _controller;
  String? _paymentModeDraft;
  String? _selectedPlanCodeDraft;
  bool _autoRenewDraft = false;
  Set<int> _reminderDaysDraft = {30, 14, 7, 3, 1};
  String? _draftSeedKey;

  @override
  void initState() {
    super.initState();
    _controller = BillingController(
      repository:
          widget.repository ??
          createDefaultBillingRepository(session: widget.session),
      session: widget.session,
    );
    unawaited(_controller.initialize());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _createCheckout(String paymentMethod) async {
    final result = await _controller.createCheckout(
      paymentMethod: paymentMethod,
      requestedPlanCode: _selectedPlanCodeDraft,
    );
    if (!mounted || result == null) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.l10n.pick(
            vi: 'Đã tạo phiên thanh toán ${paymentMethod.toUpperCase()}.',
            en: '${paymentMethod.toUpperCase()} checkout created.',
          ),
        ),
      ),
    );
  }

  Future<void> _savePreferences() async {
    final mode =
        _paymentModeDraft ?? (_autoRenewDraft ? 'auto_renew' : 'manual');
    await _controller.updatePreferences(
      paymentMode: mode,
      autoRenew: _autoRenewDraft,
      reminderDaysBefore: _reminderDaysDraft.toList(growable: false),
    );
    if (!mounted || _controller.errorMessage != null) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.l10n.pick(
            vi: 'Đã lưu cài đặt thanh toán.',
            en: 'Billing preferences saved.',
          ),
        ),
      ),
    );
  }

  Future<void> _copyCheckoutUrl(String checkoutUrl) async {
    await Clipboard.setData(ClipboardData(text: checkoutUrl));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.l10n.pick(
            vi: 'Đã sao chép liên kết thanh toán.',
            en: 'Checkout link copied.',
          ),
        ),
      ),
    );
  }

  void _syncDraftFromWorkspace(BillingWorkspaceSnapshot workspace) {
    final settings = workspace.settings;
    final minimumTier = _minimumTierForMemberCount(
      workspace.pricingTiers,
      workspace.memberCount,
    );
    final selectablePlans = _selectablePlans(
      tiers: workspace.pricingTiers,
      minimumPlanCode: minimumTier.planCode,
    );
    final currentPlanCode = workspace.subscription.planCode
        .trim()
        .toUpperCase();
    final hasCurrentPlan = selectablePlans.any(
      (tier) => tier.planCode.trim().toUpperCase() == currentPlanCode,
    );
    final defaultPlanCode = hasCurrentPlan
        ? currentPlanCode
        : minimumTier.planCode.trim().toUpperCase();
    final seed =
        '${settings.updatedAtIso}|${settings.paymentMode}|'
        '${settings.autoRenew}|${settings.reminderDaysBefore.join(',')}|'
        '${workspace.memberCount}|$defaultPlanCode';
    if (_draftSeedKey == seed) {
      return;
    }
    _draftSeedKey = seed;
    _paymentModeDraft = settings.paymentMode;
    _selectedPlanCodeDraft = defaultPlanCode;
    _autoRenewDraft = settings.autoRenew;
    _reminderDaysDraft = settings.reminderDaysBefore.toSet();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final l10n = context.l10n;
        final workspace = _controller.workspace;
        final viewerSummary = _controller.viewerSummary;
        if (workspace != null) {
          _syncDraftFromWorkspace(workspace);
        }

        return Scaffold(
          appBar: widget.embeddedInShell
              ? null
              : AppBar(
                  title: Text(l10n.pick(vi: 'Gói dịch vụ', en: 'Subscription')),
                  actions: [
                    IconButton(
                      tooltip: l10n.pick(vi: 'Tải lại', en: 'Refresh'),
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
                      vi: 'Đang tải thông tin gói dịch vụ...',
                      en: 'Loading subscription workspace...',
                    ),
                  )
                : !_controller.hasClanContext
                ? _EmptyState(
                    icon: Icons.lock_outline,
                    title: l10n.pick(
                      vi: 'Thiếu ngữ cảnh họ tộc',
                      en: 'No clan context',
                    ),
                    description: l10n.pick(
                      vi: 'Tài khoản cần liên kết với một họ tộc để xem thông tin gói.',
                      en: 'Link your account to a clan to view subscription details.',
                    ),
                  )
                : _controller.canManageBilling && workspace == null
                ? _EmptyState(
                    icon: Icons.error_outline,
                    title: l10n.pick(
                      vi: 'Không thể tải gói dịch vụ',
                      en: 'Unable to load billing',
                    ),
                    description: _friendlyErrorMessage(
                      _controller.errorMessage,
                      l10n,
                    ),
                  )
                : _controller.canManageBilling
                ? _buildManagerWorkspace(context, workspace!)
                : viewerSummary == null
                ? _EmptyState(
                    icon: Icons.error_outline,
                    title: l10n.pick(
                      vi: 'Không thể tải gói dịch vụ',
                      en: 'Unable to load billing',
                    ),
                    description: _friendlyErrorMessage(
                      _controller.errorMessage,
                      l10n,
                    ),
                  )
                : _buildViewerWorkspace(context, viewerSummary),
          ),
        );
      },
    );
  }

  Widget _buildManagerWorkspace(
    BuildContext context,
    BillingWorkspaceSnapshot workspace,
  ) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final entitlement = workspace.entitlement;
    final tier = workspace.pricingTiers
        .where((item) => item.planCode == entitlement.planCode)
        .firstOrNull;
    final canManage = _controller.canManageBilling;
    final minimumTier = _minimumTierForMemberCount(
      workspace.pricingTiers,
      workspace.memberCount,
    );
    final selectablePlans = _selectablePlans(
      tiers: workspace.pricingTiers,
      minimumPlanCode: minimumTier.planCode,
    );
    final selectedPlanCode = _selectedPlanCodeDraft?.trim().toUpperCase();
    final selectedTier = selectablePlans.firstWhere(
      (tier) => tier.planCode.trim().toUpperCase() == selectedPlanCode,
      orElse: () => minimumTier,
    );
    final pendingTransactions = workspace.transactions
        .where((tx) => _isPendingPaymentStatus(tx.paymentStatus))
        .toList(growable: false);

    return RefreshIndicator(
      onRefresh: _controller.refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          if (_controller.errorMessage case final error?) ...[
            _InfoCard(
              icon: Icons.error_outline,
              title: l10n.pick(
                vi: 'Thao tác thanh toán chưa thành công',
                en: 'Billing action failed',
              ),
              description: _friendlyErrorMessage(error, l10n),
              tone: colorScheme.errorContainer,
            ),
            const SizedBox(height: 12),
          ],
          if (_controller.isSavingPreferences ||
              _controller.isCreatingCheckout ||
              _controller.isProcessingPayment)
            const LinearProgressIndicator(minHeight: 2),
          if (_controller.isSavingPreferences ||
              _controller.isCreatingCheckout ||
              _controller.isProcessingPayment)
            const SizedBox(height: 12),
          _SubscriptionHeroCard(
            planCode: entitlement.planCode,
            status: entitlement.status,
            memberCount: workspace.memberCount,
            amountVnd:
                tier?.priceVndYear ?? workspace.subscription.amountVndYear,
            showAds: entitlement.showAds,
            adFree: entitlement.adFree,
            expiresAtIso:
                entitlement.expiresAtIso ?? workspace.subscription.expiresAtIso,
            nextPaymentDueAtIso:
                entitlement.nextPaymentDueAtIso ??
                workspace.subscription.nextPaymentDueAtIso,
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: l10n.pick(
              vi: 'Thanh toán & gia hạn',
              en: 'Checkout & renewal',
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  key: const Key('billing-plan-selector'),
                  isExpanded: true,
                  initialValue: selectedTier.planCode,
                  decoration: InputDecoration(
                    labelText: l10n.pick(
                      vi: 'Gói muốn áp dụng',
                      en: 'Select plan',
                    ),
                  ),
                  selectedItemBuilder: (context) {
                    return [
                      for (final tier in selectablePlans)
                        Text(
                          _localizedPlanName(tier.planCode, l10n),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ];
                  },
                  items: [
                    for (final tier in selectablePlans)
                      DropdownMenuItem<String>(
                        value: tier.planCode,
                        child: Text(
                          '${_localizedPlanName(tier.planCode, l10n)} • ${_memberRangeLabel(tier, l10n)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          softWrap: false,
                        ),
                      ),
                  ],
                  onChanged: !canManage
                      ? null
                      : (value) {
                          if (value == null || value.trim().isEmpty) {
                            return;
                          }
                          setState(() {
                            _selectedPlanCodeDraft = value.trim().toUpperCase();
                          });
                        },
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.pick(
                    vi: 'Tổng tiền theo gói đã chọn: ${_formatVnd(selectedTier.priceVndYear)} (đã gồm VAT).',
                    en: 'Annual amount for selected plan: ${_formatVnd(selectedTier.priceVndYear)} (VAT included).',
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  selectedTier.showAds
                      ? l10n.pick(
                          vi: 'Gói này có quảng cáo trong ứng dụng.',
                          en: 'This plan includes ads in app.',
                        )
                      : l10n.pick(
                          vi: 'Gói này tắt hoàn toàn quảng cáo.',
                          en: 'This plan is fully ad-free.',
                        ),
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                if (selectedTier.priceVndYear == 0)
                  _InfoCard(
                    icon: Icons.info_outline,
                    title: l10n.pick(
                      vi: 'Gói miễn phí đã được chọn',
                      en: 'Free plan selected',
                    ),
                    description: l10n.pick(
                      vi: 'Không cần thanh toán cho gói này. Hệ thống vẫn lưu thay đổi trạng thái gói khi tạo checkout.',
                      en: 'No payment is required for this plan. Checkout still records the selected tier.',
                    ),
                    tone: colorScheme.tertiaryContainer,
                  )
                else
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      FilledButton.icon(
                        key: const Key('billing-checkout-card-button'),
                        onPressed: canManage && !_controller.isCreatingCheckout
                            ? () => _createCheckout('card')
                            : null,
                        icon: const Icon(Icons.credit_card),
                        label: Text(
                          l10n.pick(vi: 'Thanh toán thẻ', en: 'Pay by card'),
                        ),
                      ),
                      OutlinedButton.icon(
                        key: const Key('billing-checkout-vnpay-button'),
                        onPressed: canManage && !_controller.isCreatingCheckout
                            ? () => _createCheckout('vnpay')
                            : null,
                        icon: const Icon(Icons.qr_code_2_outlined),
                        label: const Text('VNPay'),
                      ),
                    ],
                  ),
                if (_controller.lastCheckout case final checkout?) ...[
                  const SizedBox(height: 12),
                  _CheckoutResultCard(
                    checkout: checkout,
                    onCopyUrl: checkout.checkoutUrl.trim().isEmpty
                        ? null
                        : () => _copyCheckoutUrl(checkout.checkoutUrl),
                    onConfirmCard:
                        canManage &&
                            checkout.paymentMethod == 'card' &&
                            checkout.requiresManualConfirmation
                        ? () => _controller.confirmCardPayment(
                            checkout.transactionId,
                          )
                        : null,
                    onConfirmVnpay:
                        canManage &&
                            checkout.paymentMethod == 'vnpay' &&
                            checkout.planCode != 'FREE'
                        ? () => _controller.confirmVnpayPayment(
                            checkout.transactionId,
                          )
                        : null,
                  ),
                ],
                if (pendingTransactions.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    l10n.pick(
                      vi: 'Giao dịch đang chờ xử lý',
                      en: 'Pending transactions',
                    ),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final tx in pendingTransactions.take(3))
                    Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        dense: true,
                        title: Text(
                          '${tx.paymentMethod.toUpperCase()} • ${_formatVnd(tx.amountVnd)}',
                        ),
                        subtitle: Text(
                          l10n.pick(vi: 'Mã: ${tx.id}', en: 'Ref: ${tx.id}'),
                        ),
                        trailing: tx.paymentMethod == 'card'
                            ? TextButton(
                                onPressed: canManage
                                    ? () =>
                                          _controller.confirmCardPayment(tx.id)
                                    : null,
                                child: Text(
                                  l10n.pick(vi: 'Xác nhận', en: 'Confirm'),
                                ),
                              )
                            : TextButton(
                                onPressed: canManage
                                    ? () =>
                                          _controller.confirmVnpayPayment(tx.id)
                                    : null,
                                child: Text(
                                  l10n.pick(
                                    vi: 'Đã thanh toán',
                                    en: 'Mark paid',
                                  ),
                                ),
                              ),
                      ),
                    ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: l10n.pick(vi: 'Cài đặt gia hạn', en: 'Renewal settings'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _autoRenewDraft,
                  onChanged: canManage
                      ? (value) {
                          setState(() {
                            _autoRenewDraft = value;
                            _paymentModeDraft = value ? 'auto_renew' : 'manual';
                          });
                        }
                      : null,
                  title: Text(
                    l10n.pick(
                      vi: 'Bật tự động gia hạn',
                      en: 'Enable auto-renew',
                    ),
                  ),
                ),
                Text(
                  l10n.pick(vi: 'Nhắc trước hạn', en: 'Reminder schedule'),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final day in const [30, 14, 7, 3, 1])
                      FilterChip(
                        label: Text(
                          l10n.pick(vi: '$day ngày', en: '$day days'),
                        ),
                        selected: _reminderDaysDraft.contains(day),
                        onSelected: canManage
                            ? (selected) {
                                setState(() {
                                  if (selected) {
                                    _reminderDaysDraft.add(day);
                                  } else {
                                    _reminderDaysDraft.remove(day);
                                  }
                                  if (_reminderDaysDraft.isEmpty) {
                                    _reminderDaysDraft = {7, 1};
                                  }
                                });
                              }
                            : null,
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: const Key('billing-save-preferences-button'),
                    onPressed: canManage && !_controller.isSavingPreferences
                        ? _savePreferences
                        : null,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(
                      l10n.pick(vi: 'Lưu cài đặt', en: 'Save settings'),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            sectionKey: const Key('billing-payment-history-section'),
            title: l10n.pick(vi: 'Lịch sử thanh toán', en: 'Payment history'),
            child: workspace.transactions.isEmpty
                ? _EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: l10n.pick(
                      vi: 'Chưa có giao dịch',
                      en: 'No transactions',
                    ),
                    description: l10n.pick(
                      vi: 'Giao dịch sẽ xuất hiện sau khi bạn thanh toán hoặc gia hạn.',
                      en: 'Transactions appear here after checkout and renewals.',
                    ),
                  )
                : Column(
                    children: [
                      for (final tx in workspace.transactions.take(8))
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            '${tx.paymentMethod.toUpperCase()} • ${_formatVnd(tx.amountVnd)}',
                          ),
                          subtitle: Text(
                            '${_localizedPlanName(tx.planCode, l10n)} • ${_humanizeStatus(tx.paymentStatus, l10n)}',
                          ),
                          trailing: Text(
                            _dateLabel(tx.paidAtIso ?? tx.createdAtIso, l10n),
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: l10n.pick(vi: 'Hóa đơn', en: 'Invoices'),
            child: workspace.invoices.isEmpty
                ? _EmptyState(
                    icon: Icons.description_outlined,
                    title: l10n.pick(vi: 'Chưa có hóa đơn', en: 'No invoices'),
                    description: l10n.pick(
                      vi: 'Hóa đơn sẽ được tạo cùng giao dịch thanh toán.',
                      en: 'Invoices are generated together with transactions.',
                    ),
                  )
                : Column(
                    children: [
                      for (final invoice in workspace.invoices.take(6))
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            '${_localizedPlanName(invoice.planCode, l10n)} • ${_formatVnd(invoice.amountVnd)}',
                          ),
                          subtitle: Text(
                            '${l10n.pick(vi: 'Trạng thái', en: 'Status')}: '
                            '${_humanizeInvoiceStatus(invoice.status, l10n)}',
                          ),
                          trailing: Text(
                            _dateLabel(invoice.issuedAtIso, l10n),
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: l10n.pick(vi: 'Nhật ký hệ thống', en: 'Audit logs'),
            child: workspace.auditLogs.isEmpty
                ? _EmptyState(
                    icon: Icons.history_toggle_off,
                    title: l10n.pick(
                      vi: 'Chưa có nhật ký',
                      en: 'No audit records',
                    ),
                    description: l10n.pick(
                      vi: 'Nhật ký thao tác billing sẽ hiển thị tại đây.',
                      en: 'Billing action logs will appear here.',
                    ),
                  )
                : Column(
                    children: [
                      for (final log in workspace.auditLogs.take(8))
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(_humanizeAuditAction(log.action, l10n)),
                          subtitle: Text(
                            '${_humanizeAuditEntityType(log.entityType, l10n)} • ${log.entityId}',
                          ),
                          trailing: Text(
                            _dateLabel(log.createdAtIso, l10n),
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: l10n.pick(vi: 'Bảng giá', en: 'Pricing tiers'),
            child: Column(
              children: [
                for (final tier in workspace.pricingTiers)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      radius: 16,
                      child: Text(tier.planCode.substring(0, 1)),
                    ),
                    title: Text(_localizedPlanName(tier.planCode, l10n)),
                    subtitle: Text(
                      '${_memberRangeLabel(tier, l10n)} • '
                      '${tier.showAds ? l10n.pick(vi: 'Có quảng cáo', en: 'Ads on') : l10n.pick(vi: 'Không quảng cáo', en: 'No ads')}',
                    ),
                    trailing: Text(
                      _formatVnd(tier.priceVndYear),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewerWorkspace(
    BuildContext context,
    BillingViewerSummary summary,
  ) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final entitlement = summary.entitlement;
    final tier = summary.pricingTiers
        .where((item) => item.planCode == entitlement.planCode)
        .firstOrNull;

    return RefreshIndicator(
      onRefresh: _controller.refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          if (_controller.errorMessage case final error?) ...[
            _InfoCard(
              icon: Icons.error_outline,
              title: l10n.pick(
                vi: 'Không thể cập nhật trạng thái gói',
                en: 'Unable to refresh subscription state',
              ),
              description: _friendlyErrorMessage(error, l10n),
              tone: colorScheme.errorContainer,
            ),
            const SizedBox(height: 12),
          ],
          _SubscriptionHeroCard(
            planCode: entitlement.planCode,
            status: entitlement.status,
            memberCount: summary.memberCount,
            amountVnd: tier?.priceVndYear ?? summary.subscription.amountVndYear,
            showAds: entitlement.showAds,
            adFree: entitlement.adFree,
            expiresAtIso:
                entitlement.expiresAtIso ?? summary.subscription.expiresAtIso,
            nextPaymentDueAtIso:
                entitlement.nextPaymentDueAtIso ??
                summary.subscription.nextPaymentDueAtIso,
          ),
          const SizedBox(height: 16),
          _InfoCard(
            icon: Icons.visibility_outlined,
            title: l10n.pick(vi: 'Chế độ xem', en: 'View mode'),
            description: l10n.pick(
              vi: 'Bạn có thể xem trạng thái gói. Chủ tộc và quản trị viên sẽ thực hiện thanh toán/gia hạn.',
              en: 'You can view subscription status. Clan owner/admin accounts handle checkout and renewal.',
            ),
            tone: colorScheme.secondaryContainer,
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: l10n.pick(vi: 'Bảng giá', en: 'Pricing tiers'),
            child: Column(
              children: [
                for (final tier in summary.pricingTiers)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      radius: 16,
                      child: Text(tier.planCode.substring(0, 1)),
                    ),
                    title: Text(_localizedPlanName(tier.planCode, l10n)),
                    subtitle: Text(
                      '${_memberRangeLabel(tier, l10n)} • '
                      '${tier.showAds ? l10n.pick(vi: 'Có quảng cáo', en: 'Ads on') : l10n.pick(vi: 'Không quảng cáo', en: 'No ads')}',
                    ),
                    trailing: Text(
                      _formatVnd(tier.priceVndYear),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  BillingPlanPricing _minimumTierForMemberCount(
    List<BillingPlanPricing> tiers,
    int memberCount,
  ) {
    final sorted = [...tiers]
      ..sort(
        (left, right) =>
            _planRank(left.planCode).compareTo(_planRank(right.planCode)),
      );
    for (final tier in sorted) {
      final inLowerBound = memberCount >= tier.minMembers;
      final inUpperBound =
          tier.maxMembers == null || memberCount <= tier.maxMembers!;
      if (inLowerBound && inUpperBound) {
        return tier;
      }
    }
    return sorted.isNotEmpty
        ? sorted.last
        : const BillingPlanPricing(
            planCode: 'FREE',
            minMembers: 0,
            maxMembers: 10,
            priceVndYear: 0,
            vatIncluded: true,
            showAds: true,
            adFree: false,
          );
  }

  List<BillingPlanPricing> _selectablePlans({
    required List<BillingPlanPricing> tiers,
    required String minimumPlanCode,
  }) {
    final minimumRank = _planRank(minimumPlanCode);
    final filtered = tiers
        .where((tier) => _planRank(tier.planCode) >= minimumRank)
        .toList(growable: false);
    filtered.sort(
      (left, right) =>
          _planRank(left.planCode).compareTo(_planRank(right.planCode)),
    );
    return filtered;
  }

  int _planRank(String planCode) {
    switch (planCode.trim().toUpperCase()) {
      case 'BASE':
        return 1;
      case 'PLUS':
        return 2;
      case 'PRO':
        return 3;
      default:
        return 0;
    }
  }

  String _memberRangeLabel(BillingPlanPricing tier, AppLocalizations l10n) {
    if (tier.maxMembers == null) {
      return l10n.pick(
        vi: '${tier.minMembers}+ thành viên',
        en: '${tier.minMembers}+ members',
      );
    }
    return l10n.pick(
      vi: '${tier.minMembers} - ${tier.maxMembers} thành viên',
      en: '${tier.minMembers} - ${tier.maxMembers} members',
    );
  }

  String _humanizeStatus(String status, AppLocalizations l10n) {
    final normalized = status.trim().toLowerCase();
    switch (normalized) {
      case 'pending':
        return l10n.pick(vi: 'Chờ xử lý', en: 'Pending');
      case 'created':
        return l10n.pick(vi: 'Đã tạo', en: 'Created');
      case 'active':
        return l10n.pick(vi: 'Đang hoạt động', en: 'Active');
      case 'grace_period':
        return l10n.pick(vi: 'Gia hạn ân hạn', en: 'Grace period');
      case 'pending_payment':
        return l10n.pick(vi: 'Chờ thanh toán', en: 'Pending payment');
      case 'expired':
        return l10n.pick(vi: 'Hết hạn', en: 'Expired');
      case 'paid':
        return l10n.pick(vi: 'Đã thanh toán', en: 'Paid');
      case 'issued':
        return l10n.pick(vi: 'Đã phát hành', en: 'Issued');
      case 'void':
        return l10n.pick(vi: 'Đã hủy', en: 'Void');
      case 'canceled':
      case 'cancelled':
        return l10n.pick(vi: 'Đã hủy', en: 'Canceled');
      case 'succeeded':
        return l10n.pick(vi: 'Thành công', en: 'Succeeded');
      case 'failed':
        return l10n.pick(vi: 'Thất bại', en: 'Failed');
      default:
        return _humanizeCode(status);
    }
  }

  String _humanizeInvoiceStatus(String status, AppLocalizations l10n) {
    final normalized = status.trim().toLowerCase();
    switch (normalized) {
      case 'issued':
        return l10n.pick(vi: 'Đã phát hành', en: 'Issued');
      case 'paid':
        return l10n.pick(vi: 'Đã thanh toán', en: 'Paid');
      case 'failed':
        return l10n.pick(vi: 'Thất bại', en: 'Failed');
      case 'void':
      case 'canceled':
      case 'cancelled':
        return l10n.pick(vi: 'Đã hủy', en: 'Canceled');
      case 'pending':
        return l10n.pick(vi: 'Chờ thanh toán', en: 'Pending');
      default:
        return _humanizeCode(status);
    }
  }

  String _humanizeAuditAction(String action, AppLocalizations l10n) {
    final normalized = action.trim().toLowerCase();
    switch (normalized) {
      case 'checkout_created':
        return l10n.pick(vi: 'Đã tạo phiên thanh toán', en: 'Checkout created');
      case 'payment_succeeded':
        return l10n.pick(vi: 'Thanh toán thành công', en: 'Payment succeeded');
      case 'payment_failed':
        return l10n.pick(vi: 'Thanh toán thất bại', en: 'Payment failed');
      case 'billing_preferences_updated':
        return l10n.pick(
          vi: 'Đã cập nhật cài đặt thanh toán',
          en: 'Billing preferences updated',
        );
      default:
        return _humanizeCode(action);
    }
  }

  String _humanizeAuditEntityType(String entityType, AppLocalizations l10n) {
    final normalized = entityType.trim().toLowerCase();
    switch (normalized) {
      case 'paymenttransaction':
      case 'payment_transaction':
        return l10n.pick(vi: 'Giao dịch thanh toán', en: 'Payment transaction');
      case 'billingsettings':
      case 'billing_settings':
        return l10n.pick(vi: 'Cài đặt thanh toán', en: 'Billing settings');
      case 'subscription':
        return l10n.pick(vi: 'Gói dịch vụ', en: 'Subscription');
      case 'invoice':
        return l10n.pick(vi: 'Hóa đơn', en: 'Invoice');
      default:
        return _humanizeCode(entityType);
    }
  }

  bool _isPendingPaymentStatus(String status) {
    final normalized = status.trim().toLowerCase();
    return normalized == 'pending' || normalized == 'created';
  }

  String _humanizeCode(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return raw;
    }
    var normalized = trimmed.replaceAll('_', ' ').replaceAll('-', ' ');
    normalized = normalized.replaceAllMapped(
      RegExp(r'([a-z])([A-Z])'),
      (match) => '${match.group(1)} ${match.group(2)}',
    );
    normalized = normalized.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.isEmpty) {
      return raw;
    }
    return '${normalized[0].toUpperCase()}${normalized.substring(1)}';
  }

  String _dateLabel(String? iso, AppLocalizations l10n) {
    if (iso == null || iso.trim().isEmpty) {
      return l10n.pick(vi: 'N/A', en: 'N/A');
    }
    final parsed = DateTime.tryParse(iso);
    if (parsed == null) {
      return iso;
    }
    final local = parsed.toLocal();
    final day = '${local.day}'.padLeft(2, '0');
    final month = '${local.month}'.padLeft(2, '0');
    return '$day/$month/${local.year}';
  }
}

class _SubscriptionHeroCard extends StatelessWidget {
  const _SubscriptionHeroCard({
    required this.planCode,
    required this.status,
    required this.memberCount,
    required this.amountVnd,
    required this.showAds,
    required this.adFree,
    required this.expiresAtIso,
    required this.nextPaymentDueAtIso,
  });

  final String planCode;
  final String status;
  final int memberCount;
  final int amountVnd;
  final bool showAds;
  final bool adFree;
  final String? expiresAtIso;
  final String? nextPaymentDueAtIso;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final planLabel = _localizedPlanName(planCode, l10n);
    final statusLabel = switch (status) {
      'active' => l10n.pick(vi: 'Đang hoạt động', en: 'Active'),
      'grace_period' => l10n.pick(vi: 'Ân hạn', en: 'Grace period'),
      'pending_payment' => l10n.pick(
        vi: 'Chờ thanh toán',
        en: 'Pending payment',
      ),
      'expired' => l10n.pick(vi: 'Hết hạn', en: 'Expired'),
      _ => status,
    };

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colorScheme.primary, colorScheme.primaryContainer],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                planLabel,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: colorScheme.onPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.onPrimary.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  statusLabel,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: colorScheme.onPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            l10n.pick(
              vi: 'Số thành viên hiện tại: $memberCount',
              en: 'Current members: $memberCount',
            ),
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colorScheme.onPrimary.withValues(alpha: 0.95),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.pick(
              vi: 'Phí năm: ${_formatVnd(amountVnd)} (đã gồm VAT)',
              en: 'Annual fee: ${_formatVnd(amountVnd)} (VAT included)',
            ),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onPrimary.withValues(alpha: 0.92),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _HeroPill(
                icon: adFree ? Icons.block_flipped : Icons.ads_click_outlined,
                text: adFree
                    ? l10n.pick(vi: 'Không quảng cáo', en: 'Ad-free')
                    : l10n.pick(vi: 'Có quảng cáo', en: 'Ads enabled'),
              ),
              _HeroPill(
                icon: Icons.event_available_outlined,
                text: l10n.pick(
                  vi: 'Hết hạn: ${_dateOnly(expiresAtIso)}',
                  en: 'Expires: ${_dateOnly(expiresAtIso)}',
                ),
              ),
              _HeroPill(
                icon: Icons.schedule,
                text: l10n.pick(
                  vi: 'Kỳ tiếp theo: ${_dateOnly(nextPaymentDueAtIso)}',
                  en: 'Next due: ${_dateOnly(nextPaymentDueAtIso)}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CheckoutResultCard extends StatelessWidget {
  const _CheckoutResultCard({
    required this.checkout,
    this.onCopyUrl,
    this.onConfirmCard,
    this.onConfirmVnpay,
  });

  final BillingCheckoutResult checkout;
  final VoidCallback? onCopyUrl;
  final VoidCallback? onConfirmCard;
  final VoidCallback? onConfirmVnpay;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.pick(vi: 'Phiên thanh toán mới nhất', en: 'Latest checkout'),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.pick(
                vi: 'Mã giao dịch: ${checkout.transactionId}',
                en: 'Transaction: ${checkout.transactionId}',
              ),
            ),
            Text(
              l10n.pick(
                vi: 'Phương thức: ${checkout.paymentMethod.toUpperCase()}',
                en: 'Method: ${checkout.paymentMethod.toUpperCase()}',
              ),
            ),
            if (checkout.checkoutUrl.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              SelectableText(checkout.checkoutUrl),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: onCopyUrl,
                icon: const Icon(Icons.copy_outlined),
                label: Text(
                  l10n.pick(
                    vi: 'Sao chép liên kết thanh toán',
                    en: 'Copy checkout link',
                  ),
                ),
              ),
            ],
            if (onConfirmCard != null) ...[
              const SizedBox(height: 8),
              FilledButton(
                onPressed: onConfirmCard,
                child: Text(
                  l10n.pick(
                    vi: 'Xác nhận thanh toán thẻ',
                    en: 'Confirm card payment',
                  ),
                ),
              ),
            ],
            if (onConfirmVnpay != null) ...[
              const SizedBox(height: 8),
              FilledButton.tonal(
                onPressed: onConfirmVnpay,
                child: Text(
                  l10n.pick(
                    vi: 'Đánh dấu VNPay đã thanh toán',
                    en: 'Mark VNPay paid',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.onPrimary.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colorScheme.onPrimary),
          const SizedBox(width: 6),
          Text(
            text,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: colorScheme.onPrimary,
              fontWeight: FontWeight.w600,
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
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    maxLines: 6,
                    overflow: TextOverflow.ellipsis,
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

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    this.sectionKey,
    required this.title,
    required this.child,
  });

  final Key? sectionKey;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: sectionKey,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final minHeight = constraints.maxHeight.isFinite
            ? (constraints.maxHeight - 48).clamp(0, double.infinity).toDouble()
            : 0.0;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minHeight),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 42),
                    const SizedBox(height: 12),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      description,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

String _dateOnly(String? iso) {
  if (iso == null || iso.trim().isEmpty) {
    return 'N/A';
  }
  final parsed = DateTime.tryParse(iso);
  if (parsed == null) {
    return iso;
  }
  final local = parsed.toLocal();
  final day = '${local.day}'.padLeft(2, '0');
  final month = '${local.month}'.padLeft(2, '0');
  return '$day/$month/${local.year}';
}

String _formatVnd(int amount) {
  return '${amount.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} VND';
}

String _localizedPlanName(String planCode, AppLocalizations l10n) {
  switch (planCode.trim().toUpperCase()) {
    case 'FREE':
      return l10n.pick(vi: 'Miễn phí', en: 'Free');
    case 'BASE':
      return l10n.pick(vi: 'Cơ bản', en: 'Base');
    case 'PLUS':
      return l10n.pick(vi: 'Nâng cao', en: 'Plus');
    case 'PRO':
      return l10n.pick(vi: 'Chuyên nghiệp', en: 'Pro');
    default:
      final normalized = planCode.trim();
      return normalized.isEmpty ? planCode : normalized.toUpperCase();
  }
}

String _friendlyErrorMessage(String? raw, AppLocalizations l10n) {
  final fallback = l10n.pick(
    vi: 'Hãy thử tải lại sau.',
    en: 'Please try again later.',
  );
  if (raw == null || raw.trim().isEmpty) {
    return fallback;
  }

  final normalized = raw.replaceAll('\r', '').trim();
  final firstLine = normalized
      .split('\n')
      .map((line) => line.trim())
      .firstWhere((line) => line.isNotEmpty, orElse: () => normalized);
  final lower = firstLine.toLowerCase();
  if (normalized.contains('#0') || normalized.contains('package:')) {
    return l10n.pick(
      vi: 'Dịch vụ gói đang gặp sự cố tạm thời. Vui lòng thử lại sau.',
      en: 'Billing service is temporarily unavailable. Please retry later.',
    );
  }

  if (lower.contains('firebase_functions/not-found') ||
      lower.contains(' not found')) {
    return l10n.pick(
      vi: 'Dịch vụ gói đang được cập nhật trên máy chủ. Vui lòng thử lại sau ít phút.',
      en: 'Billing service is being deployed on the server. Please try again in a few minutes.',
    );
  }
  if (lower.contains('permission-denied')) {
    return l10n.pick(
      vi: 'Bạn chưa có quyền truy cập tính năng gói dịch vụ của gia phả này.',
      en: 'You do not have permission to access billing for this clan.',
    );
  }
  if (lower.contains('unavailable')) {
    return l10n.pick(
      vi: 'Không thể kết nối dịch vụ thanh toán. Vui lòng kiểm tra mạng và thử lại.',
      en: 'Billing service is unavailable. Please check your network and retry.',
    );
  }

  if (firstLine.length > 120) {
    return '${firstLine.substring(0, 120)}...';
  }
  return firstLine;
}

extension on Iterable<BillingPlanPricing> {
  BillingPlanPricing? get firstOrNull {
    for (final item in this) {
      return item;
    }
    return null;
  }
}
