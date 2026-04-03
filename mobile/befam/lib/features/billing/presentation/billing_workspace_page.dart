import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/services/app_environment.dart';
import '../../../core/widgets/app_async_action.dart';
import '../../../core/widgets/app_feedback_states.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../l10n/l10n.dart';
import '../../auth/models/auth_session.dart';
import '../models/billing_workspace_snapshot.dart';
import '../services/billing_repository.dart';
import '../services/store_iap_gateway.dart';
import 'billing_controller.dart';

typedef ExternalUriLauncher = Future<bool> Function(Uri uri);

class BillingWorkspacePage extends StatefulWidget {
  const BillingWorkspacePage({
    super.key,
    required this.session,
    this.repository,
    this.embeddedInShell = false,
    this.externalUrlLauncher,
    this.storeIapGateway,
    this.onPricingQuickActionChanged,
  });

  final AuthSession session;
  final BillingRepository? repository;
  final bool embeddedInShell;
  final ExternalUriLauncher? externalUrlLauncher;
  final StoreIapGateway? storeIapGateway;
  final ValueChanged<AsyncCallback?>? onPricingQuickActionChanged;

  @override
  State<BillingWorkspacePage> createState() => _BillingWorkspacePageState();
}

class _BillingWorkspacePageState extends State<BillingWorkspacePage> {
  late final BillingController _controller;
  late final StoreIapGateway _storeIapGateway;
  String? _paymentModeDraft;
  String? _selectedPlanCodeDraft;
  bool _autoRenewDraft = false;
  Set<int> _reminderDaysDraft = {30, 14, 7, 3, 1};
  String? _draftSeedKey;
  bool _showPreferencesSavedInline = false;
  String _pricingTierCacheKey = '';
  List<BillingPlanPricing> _cachedSortedAllTiers = const [];
  List<BillingPlanPricing> _cachedCheckoutTiers = const [];
  Map<int, BillingPlanPricing> _cachedMinimumTierByMemberCount = {};

  @override
  void initState() {
    super.initState();
    _controller = BillingController(
      repository:
          widget.repository ??
          createDefaultBillingRepository(session: widget.session),
      session: widget.session,
    );
    _storeIapGateway = widget.storeIapGateway ?? createDefaultStoreIapGateway();
    unawaited(_controller.initialize());
    _schedulePricingQuickActionRegistration();
  }

  @override
  void didUpdateWidget(covariant BillingWorkspacePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.onPricingQuickActionChanged !=
            widget.onPricingQuickActionChanged ||
        oldWidget.embeddedInShell != widget.embeddedInShell) {
      _schedulePricingQuickActionRegistration();
    }
  }

  @override
  void dispose() {
    widget.onPricingQuickActionChanged?.call(null);
    _controller.dispose();
    super.dispose();
  }

  void _schedulePricingQuickActionRegistration() {
    if (!widget.embeddedInShell) {
      return;
    }
    final onPricingQuickActionChanged = widget.onPricingQuickActionChanged;
    if (onPricingQuickActionChanged == null) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      onPricingQuickActionChanged(_openPricingQuickView);
    });
  }

  bool get _shouldUseStoreCheckout {
    if (_controller.isRepositorySandbox || kIsWeb) {
      return false;
    }
    return defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android;
  }

  bool _validatePaidPlanSelection({
    required BillingWorkspaceSnapshot workspace,
    required BillingPlanPricing minimumTier,
    required BillingPlanPricing selectedTier,
    required bool canRenewCurrentPlan,
  }) {
    final l10n = context.l10n;
    final currentRank = _planRank(workspace.entitlement.planCode);
    final minimumRank = _planRank(minimumTier.planCode);
    final selectedRank = _planRank(selectedTier.planCode);
    final isDowngrade = selectedRank < currentRank;
    final isRenew = selectedRank == currentRank;
    final isUpgrade = selectedRank > currentRank;
    if (selectedRank < minimumRank) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.pick(
              vi: 'Không thể hạ gói vì số thành viên hiện tại vượt giới hạn của gói đã chọn.',
              en: 'Cannot downgrade because current member count exceeds the selected plan limit.',
            ),
          ),
        ),
      );
      return false;
    }
    if (isDowngrade) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.pick(
              vi: 'Hạ gói chỉ mở sau khi kỳ hiện tại kết thúc.',
              en: 'Downgrade is available only after the current term ends.',
            ),
          ),
        ),
      );
      return false;
    }
    if (isRenew && !canRenewCurrentPlan) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.pick(
              vi: 'Gia hạn chỉ mở khi gói hiện tại gần hết hạn.',
              en: 'Renewal is available only near expiry.',
            ),
          ),
        ),
      );
      return false;
    }
    return isUpgrade || isRenew;
  }

  String _activeStoreLabel(AppLocalizations l10n) {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return 'App Store';
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'Google Play';
    }
    return l10n.pick(vi: 'cửa hàng ứng dụng', en: 'app store');
  }

  String? _iapProductIdForPlan(
    BillingWorkspaceSnapshot workspace,
    String planCode,
  ) {
    final platformKey = defaultTargetPlatform == TargetPlatform.iOS
        ? 'ios'
        : defaultTargetPlatform == TargetPlatform.android
        ? 'android'
        : null;
    return workspace.checkoutFlow.storeProductIdForPlan(
      planCode,
      platform: platformKey,
    );
  }

  Future<void> _openStoreCheckoutFlow({
    required BillingWorkspaceSnapshot workspace,
    required BillingPlanPricing minimumTier,
    required BillingPlanPricing selectedTier,
    required bool canRenewCurrentPlan,
  }) async {
    final l10n = context.l10n;
    if (!_validatePaidPlanSelection(
      workspace: workspace,
      minimumTier: minimumTier,
      selectedTier: selectedTier,
      canRenewCurrentPlan: canRenewCurrentPlan,
    )) {
      return;
    }
    final productId = _iapProductIdForPlan(workspace, selectedTier.planCode);
    if (productId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.pick(
              vi: 'Gói này chưa được cấu hình mua trong ứng dụng.',
              en: 'This plan is not configured for in-app purchase yet.',
            ),
          ),
        ),
      );
      return;
    }

    final purchase = await _storeIapGateway.purchaseSubscription(
      productId: productId,
    );
    if (!mounted) {
      return;
    }
    if (purchase.canceled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.pick(
              vi: 'Bạn đã hủy giao dịch trên ${_activeStoreLabel(l10n)}.',
              en: 'You canceled the purchase on ${_activeStoreLabel(l10n)}.',
            ),
          ),
        ),
      );
      return;
    }
    if (!purchase.succeeded) {
      final errorMessage = (purchase.errorMessage ?? '').trim();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            errorMessage.isEmpty
                ? l10n.pick(
                    vi: 'Không thể hoàn tất giao dịch. Vui lòng thử lại.',
                    en: 'Could not complete this purchase. Please try again.',
                  )
                : errorMessage,
          ),
        ),
      );
      return;
    }

    final entitlement = await _controller.verifyInAppPurchase(
      platform: purchase.platform,
      productId: purchase.productId,
      payload: purchase.payload,
    );
    if (!mounted) {
      return;
    }
    if (entitlement == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_friendlyErrorMessage(_controller.errorMessage, l10n)),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          l10n.pick(
            vi: 'Đã kích hoạt gói thành công qua ${_activeStoreLabel(l10n)}.',
            en: 'Subscription activated successfully via ${_activeStoreLabel(l10n)}.',
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
    setState(() {
      _showPreferencesSavedInline = true;
    });
  }

  Future<void> _openPendingTransactionDetail({
    required BillingPaymentTransaction transaction,
  }) async {
    final l10n = context.l10n;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        final createdAtLabel = _dateLabel(transaction.createdAtIso, l10n);
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.pick(
                    vi: 'Chi tiết giao dịch chờ',
                    en: 'Pending transaction detail',
                  ),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                _BillingDetailRow(
                  label: l10n.pick(vi: 'Phương thức', en: 'Method'),
                  value: transaction.paymentMethod.toUpperCase(),
                ),
                _BillingDetailRow(
                  label: l10n.pick(vi: 'Trạng thái', en: 'Status'),
                  value: _humanizeStatus(transaction.paymentStatus, l10n),
                ),
                _BillingDetailRow(
                  label: l10n.pick(vi: 'Số tiền', en: 'Amount'),
                  value: _formatVnd(transaction.amountVnd),
                ),
                _BillingDetailRow(
                  label: l10n.pick(vi: 'Tạo lúc', en: 'Created at'),
                  value: createdAtLabel,
                ),
                _BillingDetailRow(
                  label: l10n.pick(vi: 'Tự hủy', en: 'Auto-cancel'),
                  value: _pendingTimeoutLabel(
                    transaction,
                    l10n,
                  ).replaceAll('\n', ' '),
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    l10n.pick(
                      vi: 'Gói chỉ được kích hoạt khi BeFam xác nhận giao dịch thành công.',
                      en: 'The plan becomes active only after BeFam confirms the purchase.',
                    ),
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openPricingQuickView() async {
    final l10n = context.l10n;
    final workspace = _controller.workspace;
    final viewerSummary = _controller.viewerSummary;
    final tiers = workspace?.pricingTiers ?? viewerSummary?.pricingTiers ?? [];
    if (tiers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.pick(
              vi: 'Bảng giá chưa sẵn sàng. Vui lòng thử lại sau.',
              en: 'Pricing is not ready yet. Please try again shortly.',
            ),
          ),
        ),
      );
      return;
    }

    final currentPlanCode =
        workspace?.entitlement.planCode ?? viewerSummary?.entitlement.planCode;
    final memberCount = workspace?.memberCount ?? viewerSummary?.memberCount;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) {
        final theme = Theme.of(context);
        final sheetL10n = context.l10n;
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sheetL10n.pick(vi: 'Bảng giá', en: 'Pricing tiers'),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  sheetL10n.pick(
                    vi: 'Giá theo năm, đã gồm VAT.',
                    en: 'Annual pricing, VAT included.',
                  ),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (memberCount != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    sheetL10n.pick(
                      vi: 'Gia phả hiện có $memberCount thành viên.',
                      en: 'This family tree currently has $memberCount members.',
                    ),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                _buildPricingTierList(
                  context,
                  tiers: tiers,
                  currentPlanCode: currentPlanCode,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _syncDraftFromWorkspace(BillingWorkspaceSnapshot workspace) {
    final settings = workspace.settings;
    final minimumTier = _minimumTierForMemberCount(
      workspace.pricingTiers,
      workspace.memberCount,
    );
    final canRenewCurrentPlan = _canRenewCurrentPlan(workspace.subscription);
    final currentPlanCode = workspace.entitlement.planCode.trim().toUpperCase();
    final selectablePlans = _checkoutSelectablePlans(
      tiers: workspace.pricingTiers,
    );
    final currentPlanRank = _planRank(currentPlanCode);
    BillingPlanPricing? firstUpgradePlan;
    for (final tier in selectablePlans) {
      if (_planRank(tier.planCode) > currentPlanRank) {
        firstUpgradePlan = tier;
        break;
      }
    }
    final hasCurrentPlan = selectablePlans.any(
      (tier) => tier.planCode.trim().toUpperCase() == currentPlanCode,
    );
    final defaultPlanCode = hasCurrentPlan
        ? (canRenewCurrentPlan || firstUpgradePlan == null
              ? currentPlanCode
              : firstUpgradePlan.planCode.trim().toUpperCase())
        : selectablePlans.isNotEmpty
        ? selectablePlans.first.planCode.trim().toUpperCase()
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
                      key: const Key('billing-pricing-quick-action'),
                      tooltip: l10n.pick(
                        vi: 'Xem nhanh bảng giá',
                        en: 'Quick pricing view',
                      ),
                      onPressed: _openPricingQuickView,
                      icon: const Icon(Icons.sell_outlined),
                    ),
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
    final canManage = _controller.canMutateBilling;
    final ownerLabel = (workspace.scope.ownerDisplayName ?? '').trim();
    final resolvedOwnerLabel = ownerLabel.isEmpty
        ? l10n.pick(vi: 'quản trị gia phả', en: 'the clan owner')
        : ownerLabel;
    final minimumTier = _minimumTierForMemberCount(
      workspace.pricingTiers,
      workspace.memberCount,
    );
    final minimumPlanRank = _planRank(minimumTier.planCode);
    final currentPlanCode = entitlement.planCode.trim().toUpperCase();
    final canRenewCurrentPlan = _canRenewCurrentPlan(workspace.subscription);
    final selectablePlans = _checkoutSelectablePlans(
      tiers: workspace.pricingTiers,
    );
    final hasSelectablePlans = selectablePlans.isNotEmpty;
    final fallbackTier = hasSelectablePlans
        ? selectablePlans.first
        : minimumTier;
    final selectedPlanCode = _selectedPlanCodeDraft?.trim().toUpperCase();
    final selectedTier = selectablePlans.firstWhere(
      (tier) => tier.planCode.trim().toUpperCase() == selectedPlanCode,
      orElse: () => fallbackTier,
    );
    final selectedPlanRank = _planRank(selectedTier.planCode);
    final currentPlanRank = _planRank(currentPlanCode);
    final isRenewSelection = selectedPlanRank == currentPlanRank;
    final isUpgradeSelection = selectedPlanRank > currentPlanRank;
    final useStoreCheckout = _shouldUseStoreCheckout;
    final hasStoreProductConfig =
        _iapProductIdForPlan(workspace, selectedTier.planCode) != null;
    final supportsSelectedCheckoutPath = useStoreCheckout
        ? hasStoreProductConfig
        : true;
    final isBelowMinimumForMemberCount = selectedPlanRank < minimumPlanRank;
    final canCheckoutSelectedPlan =
        selectedTier.priceVndYear > 0 &&
        canManage &&
        hasSelectablePlans &&
        supportsSelectedCheckoutPath &&
        !isBelowMinimumForMemberCount &&
        (isUpgradeSelection || (isRenewSelection && canRenewCurrentPlan));
    final pendingTransactions = workspace.transactions
        .where((tx) => _isPendingPaymentStatus(tx.paymentStatus))
        .toList(growable: false);
    final hasRenewalSettingsChanges = _hasRenewalSettingsChanges(workspace);
    final checkoutActionTitle = useStoreCheckout
        ? isRenewSelection
              ? l10n.pick(
                  vi: 'Gia hạn trên ${_activeStoreLabel(l10n)}',
                  en: 'Renew in ${_activeStoreLabel(l10n)}',
                )
              : l10n.pick(
                  vi: 'Nâng cấp trên ${_activeStoreLabel(l10n)}',
                  en: 'Upgrade in ${_activeStoreLabel(l10n)}',
                )
        : isRenewSelection
        ? l10n.pick(
            vi: 'Gia hạn ${_localizedPlanName(selectedTier.planCode, l10n, tier: selectedTier)}',
            en: 'Renew ${_localizedPlanName(selectedTier.planCode, l10n, tier: selectedTier)}',
          )
        : l10n.pick(
            vi: 'Nâng cấp lên ${_localizedPlanName(selectedTier.planCode, l10n, tier: selectedTier)}',
            en: 'Upgrade to ${_localizedPlanName(selectedTier.planCode, l10n, tier: selectedTier)}',
          );
    final checkoutActionPriceLabel = _annualPriceLabel(
      selectedTier.priceVndYear,
      l10n,
    );
    final checkoutActionIcon = useStoreCheckout
        ? Icons.shopping_bag_outlined
        : Icons.account_balance_wallet_outlined;
    final renewalAutomationDescription = l10n.pick(
      vi: 'BeFam sẽ nhắc trước hạn và mở nhanh luồng gia hạn khi cần.',
      en: 'BeFam reminds you before expiry and opens the renewal flow when needed.',
    );

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
              _controller.isProcessingPayment)
            const LinearProgressIndicator(minHeight: 2),
          if (_controller.isSavingPreferences ||
              _controller.isProcessingPayment)
            const SizedBox(height: 12),
          _SubscriptionHeroCard(
            planCode: entitlement.planCode,
            planDisplayName: _localizedPlanName(
              entitlement.planCode,
              l10n,
              tier: tier,
            ),
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
          if (!canManage) ...[
            const SizedBox(height: 12),
            _InfoCard(
              icon: Icons.lock_outline,
              title: l10n.pick(
                vi: 'Chỉ tài khoản quản trị clan được thanh toán và đổi gói',
                en: 'Only clan admin roles can manage checkout',
              ),
              description: l10n.pick(
                vi: 'Gói dịch vụ được tính theo owner. Liên hệ $resolvedOwnerLabel để nâng cấp hoặc gia hạn khi vượt giới hạn thành viên.',
                en: 'The subscription is enforced by owner scope. Contact $resolvedOwnerLabel to upgrade or renew when member limits are reached.',
              ),
              tone: colorScheme.primaryContainer,
            ),
          ],
          const SizedBox(height: 16),
          _SectionCard(
            title: l10n.pick(
              vi: 'Chọn gói phù hợp',
              en: 'Choose the right plan',
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.pick(
                    vi: 'Chọn gói theo số lượng thành viên hiện tại. Giá tính theo năm và đã gồm VAT.',
                    en: 'Choose a plan based on your current member count. Pricing is annual and VAT included.',
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                if (hasSelectablePlans)
                  Column(
                    key: const Key('billing-plan-selector'),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (
                        var index = 0;
                        index < selectablePlans.length;
                        index++
                      )
                        Padding(
                          padding: EdgeInsets.only(
                            bottom: index == selectablePlans.length - 1
                                ? 0
                                : 10,
                          ),
                          child: _CheckoutPlanOptionTile(
                            key: Key(
                              'billing-plan-option-${selectablePlans[index].planCode.toLowerCase()}',
                            ),
                            planName: _localizedPlanName(
                              selectablePlans[index].planCode,
                              l10n,
                              tier: selectablePlans[index],
                            ),
                            description: _planShortDescription(
                              selectablePlans[index].planCode,
                              l10n,
                              tier: selectablePlans[index],
                            ),
                            detailLabel:
                                '${_memberRangeLabel(selectablePlans[index], l10n)} • ${_adsExperienceLabel(selectablePlans[index], l10n)}',
                            priceLabel: _annualPriceLabel(
                              selectablePlans[index].priceVndYear,
                              l10n,
                            ),
                            isSelected:
                                selectablePlans[index].planCode
                                    .trim()
                                    .toUpperCase() ==
                                selectedTier.planCode.trim().toUpperCase(),
                            isCurrentPlan:
                                selectablePlans[index].planCode
                                    .trim()
                                    .toUpperCase() ==
                                currentPlanCode,
                            isEnabled: canManage,
                            onTap: !canManage
                                ? null
                                : () {
                                    setState(() {
                                      _selectedPlanCodeDraft =
                                          selectablePlans[index].planCode
                                              .trim()
                                              .toUpperCase();
                                    });
                                  },
                          ),
                        ),
                    ],
                  ),
                const SizedBox(height: 12),
                if (!hasSelectablePlans)
                  Text(
                    l10n.pick(
                      vi: 'Hiện chưa có lựa chọn thanh toán phù hợp.',
                      en: 'No eligible payment choice at this time.',
                    ),
                    style: theme.textTheme.bodySmall,
                  )
                else if (selectedTier.priceVndYear == 0)
                  _InfoCard(
                    icon: Icons.info_outline,
                    title: l10n.pick(
                      vi: 'Gói miễn phí đã được chọn',
                      en: 'Free plan selected',
                    ),
                    description: l10n.pick(
                      vi: useStoreCheckout
                          ? 'Gói miễn phí không cần mua trong ứng dụng.'
                          : 'Gói miễn phí không tạo checkout.',
                      en: useStoreCheckout
                          ? 'Free plan does not require in-app purchase.'
                          : 'Free plan does not create checkout.',
                    ),
                    tone: colorScheme.tertiaryContainer,
                  )
                else if (!hasStoreProductConfig)
                  _InfoCard(
                    icon: Icons.warning_amber_rounded,
                    title: l10n.pick(
                      vi: 'Thiếu cấu hình gói trên cửa hàng',
                      en: 'Missing store product config',
                    ),
                    description: l10n.pick(
                      vi: 'Gói ${_localizedPlanName(selectedTier.planCode, l10n, tier: selectedTier)} chưa được map với productId IAP trên máy chủ.',
                      en: '${_localizedPlanName(selectedTier.planCode, l10n, tier: selectedTier)} is not mapped to a store productId on the server.',
                    ),
                    tone: colorScheme.errorContainer,
                  )
                else if (isBelowMinimumForMemberCount)
                  _InfoCard(
                    icon: Icons.warning_amber_rounded,
                    title: l10n.pick(
                      vi: 'Không thể hạ xuống gói này',
                      en: 'Downgrade blocked',
                    ),
                    description: l10n.pick(
                      vi: 'Gia phả hiện có ${workspace.memberCount} thành viên, vượt giới hạn gói ${_localizedPlanName(selectedTier.planCode, l10n, tier: selectedTier)}.',
                      en: 'Current clan has ${workspace.memberCount} members, which exceeds ${_localizedPlanName(selectedTier.planCode, l10n, tier: selectedTier)}.',
                    ),
                    tone: colorScheme.errorContainer,
                  )
                else if (!canCheckoutSelectedPlan)
                  Text(
                    l10n.pick(
                      vi: 'Gia hạn cùng gói sẽ mở khi gần ngày hết hạn. Bạn có thể chọn gói khác ngay.',
                      en: 'Renewing the same plan opens near expiry. You can switch to another plan now.',
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  )
                else ...[
                  SizedBox(
                    width: double.infinity,
                    child: AppAsyncAction(
                      enabled: canCheckoutSelectedPlan,
                      onPressed: canCheckoutSelectedPlan
                          ? () async {
                              if (!useStoreCheckout) {
                                if (!mounted) {
                                  return;
                                }
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      l10n.pick(
                                        vi: 'Môi trường thử nghiệm chưa mở mua trong ứng dụng.',
                                        en: 'Sandbox mode does not enable in-app purchase.',
                                      ),
                                    ),
                                  ),
                                );
                                return;
                              }
                              await _openStoreCheckoutFlow(
                                workspace: workspace,
                                minimumTier: minimumTier,
                                selectedTier: selectedTier,
                                canRenewCurrentPlan: canRenewCurrentPlan,
                              );
                            }
                          : null,
                      builder: (context, onPressed, isLoading) {
                        return FilledButton(
                          key: const Key('billing-open-checkout-button'),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(60),
                          ),
                          onPressed: onPressed,
                          child: AppStableLoadingChild(
                            isLoading: isLoading,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Icon(checkoutActionIcon),
                                const SizedBox(width: 10),
                                Flexible(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        checkoutActionTitle,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        checkoutActionPriceLabel,
                                        style: theme.textTheme.labelLarge
                                            ?.copyWith(
                                              color: colorScheme.onPrimary
                                                  .withValues(alpha: 0.92),
                                            ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
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
                  for (final entry
                      in pendingTransactions
                          .take(3)
                          .toList(growable: false)
                          .asMap()
                          .entries)
                    Card(
                      key: Key('billing-pending-transaction-item-${entry.key}'),
                      margin: const EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          _openPendingTransactionDetail(
                            transaction: entry.value,
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${entry.value.paymentMethod.toUpperCase()} • ${_formatVnd(entry.value.amountVnd)}',
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      l10n.pick(
                                        vi: 'Tạo lúc: ${_dateLabel(entry.value.createdAtIso, l10n)}',
                                        en: 'Created: ${_dateLabel(entry.value.createdAtIso, l10n)}',
                                      ),
                                      style: theme.textTheme.bodyMedium,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      l10n.pick(
                                        vi: 'Trạng thái: ${_humanizeStatus(entry.value.paymentStatus, l10n)}',
                                        en: 'Status: ${_humanizeStatus(entry.value.paymentStatus, l10n)}',
                                      ),
                                      style: theme.textTheme.bodyMedium,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Icon(
                                    Icons.schedule_outlined,
                                    color: colorScheme.primary,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _pendingTimeoutLabel(entry.value, l10n),
                                    textAlign: TextAlign.right,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colorScheme.primary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Icon(
                                    Icons.chevron_right,
                                    size: 18,
                                    color: colorScheme.outline,
                                  ),
                                ],
                              ),
                            ],
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
            title: l10n.pick(
              vi: 'Gia hạn & nhắc hạn',
              en: 'Renewal & reminders',
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  container: true,
                  label: l10n.pick(
                    vi: 'Công tắc bật tự động gia hạn',
                    en: 'Auto-renew switch',
                  ),
                  hint: renewalAutomationDescription,
                  toggled: _autoRenewDraft,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.pick(
                                  vi: 'Tự động gia hạn',
                                  en: 'Auto-renew',
                                ),
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                renewalAutomationDescription,
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        height: 48,
                        child: Switch.adaptive(
                          value: _autoRenewDraft,
                          activeThumbColor: colorScheme.onPrimaryContainer,
                          activeTrackColor: colorScheme.primaryContainer,
                          inactiveThumbColor: colorScheme.onSurface,
                          inactiveTrackColor:
                              colorScheme.surfaceContainerHighest,
                          onChanged: canManage
                              ? (value) {
                                  setState(() {
                                    _autoRenewDraft = value;
                                    _paymentModeDraft = value
                                        ? 'auto_renew'
                                        : 'manual';
                                    _showPreferencesSavedInline = false;
                                  });
                                }
                              : null,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.pick(vi: 'Nhắc trước hạn', en: 'Reminder schedule'),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                if (!_autoRenewDraft)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      l10n.pick(
                        vi: 'Bạn vẫn nhận nhắc để gia hạn thủ công.',
                        en: 'You will still receive reminders for manual renewal.',
                      ),
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final day in const [1, 3, 7, 14, 30])
                      Builder(
                        builder: (context) {
                          final isSelected = _reminderDaysDraft.contains(day);
                          return Semantics(
                            button: true,
                            selected: isSelected,
                            label: l10n.pick(
                              vi: 'Nhắc trước hạn $day ngày',
                              en: '$day-day reminder',
                            ),
                            child: FilterChip(
                              key: Key('billing-reminder-chip-$day'),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.padded,
                              showCheckmark: isSelected,
                              checkmarkColor: colorScheme.onSecondaryContainer,
                              side: BorderSide(
                                color: isSelected
                                    ? colorScheme.secondaryContainer
                                    : colorScheme.outline,
                              ),
                              backgroundColor: colorScheme.surface,
                              selectedColor: colorScheme.secondaryContainer,
                              labelStyle: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: isSelected
                                    ? colorScheme.onSecondaryContainer
                                    : colorScheme.onSurface,
                              ),
                              label: Text(
                                l10n.pick(vi: '$day ngày', en: '$day days'),
                              ),
                              selected: isSelected,
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
                                        _showPreferencesSavedInline = false;
                                      });
                                    }
                                  : null,
                            ),
                          );
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Semantics(
                  button: true,
                  label: l10n.pick(
                    vi: 'Lưu cài đặt gia hạn',
                    en: 'Save renewal settings',
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: AppAsyncAction(
                      enabled:
                          canManage &&
                          !_controller.isSavingPreferences &&
                          hasRenewalSettingsChanges,
                      onPressed:
                          canManage &&
                              !_controller.isSavingPreferences &&
                              hasRenewalSettingsChanges
                          ? _savePreferences
                          : null,
                      builder: (context, onPressed, isLoading) {
                        final saveInProgress =
                            isLoading || _controller.isSavingPreferences;
                        return FilledButton(
                          key: const Key('billing-save-preferences-button'),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                          ),
                          onPressed: onPressed,
                          child: AppStableLoadingChild(
                            isLoading: saveInProgress,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.save_outlined),
                                const SizedBox(width: 8),
                                Text(l10n.pick(vi: 'Lưu', en: 'Save')),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                if (_showPreferencesSavedInline)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      key: const Key('billing-save-success-indicator'),
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 18,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          l10n.pick(vi: 'Đã lưu', en: 'Saved'),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
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
                            '${_localizedPlanName(tx.planCode, l10n, tier: _findPricingTierByPlanCode(workspace.pricingTiers, tx.planCode))} • ${_humanizeStatus(tx.paymentStatus, l10n)}',
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
                            '${_localizedPlanName(invoice.planCode, l10n, tier: _findPricingTierByPlanCode(workspace.pricingTiers, invoice.planCode))} • ${_formatVnd(invoice.amountVnd)}',
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
                            _humanizeAuditEntityType(log.entityType, l10n),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.pick(
                    vi: 'So sánh nhanh các gói hiện có.',
                    en: 'Compare the available plans at a glance.',
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                _buildPricingTierList(
                  context,
                  tiers: workspace.pricingTiers,
                  currentPlanCode: entitlement.planCode,
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
            planDisplayName: _localizedPlanName(
              entitlement.planCode,
              l10n,
              tier: tier,
            ),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.pick(
                    vi: 'So sánh nhanh các gói hiện có.',
                    en: 'Compare the available plans at a glance.',
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                _buildPricingTierList(
                  context,
                  tiers: summary.pricingTiers,
                  currentPlanCode: entitlement.planCode,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _ensurePricingTierCache(List<BillingPlanPricing> tiers) {
    final cacheKey = _buildPricingTierCacheKey(tiers);
    if (cacheKey == _pricingTierCacheKey) {
      return;
    }
    _pricingTierCacheKey = cacheKey;
    final sorted = [...tiers]
      ..sort(
        (left, right) =>
            _planRank(left.planCode).compareTo(_planRank(right.planCode)),
      );
    _cachedSortedAllTiers = sorted;
    _cachedCheckoutTiers = sorted
        .where((tier) => _planRank(tier.planCode) > 0)
        .toList(growable: false);
    _cachedMinimumTierByMemberCount = {};
  }

  String _buildPricingTierCacheKey(List<BillingPlanPricing> tiers) {
    if (tiers.isEmpty) {
      return 'empty';
    }
    final normalized =
        tiers
            .map(
              (tier) =>
                  '${tier.planCode.trim().toUpperCase()}:'
                  '${tier.minMembers}:'
                  '${tier.maxMembers ?? ''}:'
                  '${tier.priceVndYear}:'
                  '${tier.vatIncluded ? 1 : 0}:'
                  '${tier.showAds ? 1 : 0}:'
                  '${tier.adFree ? 1 : 0}:'
                  '${tier.displayName ?? ''}:'
                  '${tier.displayNameEn ?? ''}:'
                  '${tier.displayNameVi ?? ''}:'
                  '${tier.descriptionEn ?? ''}:'
                  '${tier.descriptionVi ?? ''}',
            )
            .toList(growable: false)
          ..sort();
    return normalized.join('|');
  }

  BillingPlanPricing _minimumTierForMemberCount(
    List<BillingPlanPricing> tiers,
    int memberCount,
  ) {
    _ensurePricingTierCache(tiers);
    final cached = _cachedMinimumTierByMemberCount[memberCount];
    if (cached != null) {
      return cached;
    }

    final sorted = _cachedSortedAllTiers;
    BillingPlanPricing resolved = sorted.isNotEmpty
        ? sorted.last
        : const BillingPlanPricing(
            planCode: 'FREE',
            minMembers: 0,
            maxMembers: 10,
            priceVndYear: 0,
            vatIncluded: true,
            showAds: true,
            adFree: false,
            displayName: 'Miễn phí',
            displayNameEn: 'Free',
            displayNameVi: 'Miễn phí',
            descriptionEn: 'For small family trees, up to 10 members, with ads',
            descriptionVi:
                'Cho gia phả nhỏ, tối đa 10 thành viên, có quảng cáo',
          );
    for (final tier in sorted) {
      final inLowerBound = memberCount >= tier.minMembers;
      final inUpperBound =
          tier.maxMembers == null || memberCount <= tier.maxMembers!;
      if (inLowerBound && inUpperBound) {
        resolved = tier;
        break;
      }
    }
    _cachedMinimumTierByMemberCount[memberCount] = resolved;
    return resolved;
  }

  Widget _buildPricingTierList(
    BuildContext context, {
    required List<BillingPlanPricing> tiers,
    required String? currentPlanCode,
  }) {
    final l10n = context.l10n;
    final normalizedCurrentPlanCode = currentPlanCode?.trim().toUpperCase();
    return Column(
      children: [
        for (var index = 0; index < tiers.length; index += 1)
          Padding(
            padding: EdgeInsets.only(
              bottom: index == tiers.length - 1 ? 0 : 10,
            ),
            child: _PricingTierTile(
              planName: _localizedPlanName(
                tiers[index].planCode,
                l10n,
                tier: tiers[index],
              ),
              description: _planShortDescription(
                tiers[index].planCode,
                l10n,
                tier: tiers[index],
              ),
              detailLabel:
                  '${_memberRangeLabel(tiers[index], l10n)} • '
                  '${_adsExperienceLabel(tiers[index], l10n)}',
              priceLabel: _annualPriceLabel(tiers[index].priceVndYear, l10n),
              badgeLabel:
                  tiers[index].planCode.trim().toUpperCase() ==
                      normalizedCurrentPlanCode
                  ? l10n.pick(vi: 'Đang dùng', en: 'Current')
                  : null,
              isHighlighted:
                  tiers[index].planCode.trim().toUpperCase() ==
                  normalizedCurrentPlanCode,
            ),
          ),
      ],
    );
  }

  bool _hasRenewalSettingsChanges(BillingWorkspaceSnapshot workspace) {
    final settings = workspace.settings;
    final normalizedDraftMode =
        (_paymentModeDraft ?? (_autoRenewDraft ? 'auto_renew' : 'manual'))
            .trim()
            .toLowerCase();
    final normalizedCurrentMode = settings.paymentMode.trim().toLowerCase();
    final remindersOnServer = settings.reminderDaysBefore.toSet();
    final remindersUnchanged =
        _reminderDaysDraft.length == remindersOnServer.length &&
        _reminderDaysDraft.containsAll(remindersOnServer);
    return normalizedDraftMode != normalizedCurrentMode ||
        _autoRenewDraft != settings.autoRenew ||
        !remindersUnchanged;
  }

  List<BillingPlanPricing> _checkoutSelectablePlans({
    required List<BillingPlanPricing> tiers,
  }) {
    _ensurePricingTierCache(tiers);
    return _cachedCheckoutTiers;
  }

  bool _canRenewCurrentPlan(BillingSubscription subscription) {
    final planCode = subscription.planCode.trim().toUpperCase();
    if (planCode == 'FREE') {
      return false;
    }
    final status = subscription.status.trim().toLowerCase();
    if (status == 'expired' || status == 'grace_period') {
      return true;
    }
    if (status != 'active') {
      return false;
    }
    final expiresAtIso = subscription.expiresAtIso;
    if (expiresAtIso == null || expiresAtIso.trim().isEmpty) {
      return false;
    }
    final expiresAt = DateTime.tryParse(expiresAtIso)?.toUtc();
    if (expiresAt == null) {
      return false;
    }
    final now = DateTime.now().toUtc();
    final daysRemaining = expiresAt.difference(now).inDays;
    return daysRemaining <= 30;
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

  int get _pendingTimeoutMinutes {
    final configured = AppEnvironment.billingPendingTimeoutMinutes;
    return configured > 0 ? configured : 20;
  }

  String _pendingTimeoutLabel(
    BillingPaymentTransaction tx,
    AppLocalizations l10n,
  ) {
    final createdAt = DateTime.tryParse(tx.createdAtIso ?? '')?.toUtc();
    final timeoutMinutes = _pendingTimeoutMinutes;
    if (createdAt == null) {
      return l10n.pick(
        vi: 'Tự hủy\nsau $timeoutMinutes phút',
        en: 'Auto-cancel\nin $timeoutMinutes minutes',
      );
    }
    final elapsedMinutes = DateTime.now()
        .toUtc()
        .difference(createdAt)
        .inMinutes;
    final remaining = timeoutMinutes - elapsedMinutes;
    if (remaining <= 0) {
      return l10n.pick(vi: 'Đang\ntự hủy', en: 'Canceling\nnow');
    }
    return l10n.pick(vi: 'Còn $remaining phút', en: '$remaining min left');
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
    required this.planDisplayName,
    required this.status,
    required this.memberCount,
    required this.amountVnd,
    required this.showAds,
    required this.adFree,
    required this.expiresAtIso,
    required this.nextPaymentDueAtIso,
  });

  final String planCode;
  final String planDisplayName;
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
    final expiresLabel = _heroTimelineLabel(
      iso: expiresAtIso,
      planCode: planCode,
      l10n: l10n,
      isNextDueDate: false,
    );
    final nextDueLabel = _heroTimelineLabel(
      iso: nextPaymentDueAtIso,
      planCode: planCode,
      l10n: l10n,
      isNextDueDate: true,
    );
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
                planDisplayName,
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
                  vi: 'Hết hạn: $expiresLabel',
                  en: 'Expires: $expiresLabel',
                ),
              ),
              _HeroPill(
                icon: Icons.schedule,
                text: l10n.pick(
                  vi: 'Kỳ tiếp theo: $nextDueLabel',
                  en: 'Next due: $nextDueLabel',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CheckoutPlanOptionTile extends StatelessWidget {
  const _CheckoutPlanOptionTile({
    super.key,
    required this.planName,
    required this.description,
    required this.detailLabel,
    required this.priceLabel,
    required this.isSelected,
    required this.isCurrentPlan,
    required this.isEnabled,
    required this.onTap,
  });

  final String planName;
  final String description;
  final String detailLabel;
  final String priceLabel;
  final bool isSelected;
  final bool isCurrentPlan;
  final bool isEnabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isInteractive = isEnabled && onTap != null;
    final borderColor = isSelected
        ? colorScheme.primary
        : isInteractive
        ? colorScheme.outline
        : colorScheme.outlineVariant;
    final backgroundColor = isSelected
        ? colorScheme.primaryContainer.withValues(alpha: 0.42)
        : isInteractive
        ? colorScheme.surface
        : colorScheme.surfaceContainerLowest;
    final mutedColor = colorScheme.onSurfaceVariant;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: isInteractive ? onTap : null,
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor, width: isSelected ? 1.6 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(
                      isSelected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      size: 18,
                      color: isSelected
                          ? colorScheme.primary
                          : isInteractive
                          ? colorScheme.onSurfaceVariant
                          : mutedColor,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                planName,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: isInteractive ? null : mutedColor,
                                ),
                              ),
                            ),
                            if (isCurrentPlan) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  l10n.pick(vi: 'Hiện tại', en: 'Current'),
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (description.trim().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: isInteractive
                                  ? colorScheme.onSurfaceVariant
                                  : mutedColor,
                            ),
                          ),
                        ],
                        const SizedBox(height: 4),
                        Text(
                          detailLabel,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isInteractive
                                ? colorScheme.onSurfaceVariant
                                : mutedColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  priceLabel,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: isSelected
                        ? colorScheme.primary
                        : isInteractive
                        ? colorScheme.onSurface
                        : mutedColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PricingTierTile extends StatelessWidget {
  const _PricingTierTile({
    required this.planName,
    required this.description,
    required this.detailLabel,
    required this.priceLabel,
    this.badgeLabel,
    this.isHighlighted = false,
  });

  final String planName;
  final String description;
  final String detailLabel;
  final String priceLabel;
  final String? badgeLabel;
  final bool isHighlighted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isHighlighted
            ? colorScheme.primaryContainer.withValues(alpha: 0.26)
            : colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isHighlighted
              ? colorScheme.primary
              : colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  planName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (badgeLabel case final badge?)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: isHighlighted
                        ? colorScheme.primary.withValues(alpha: 0.12)
                        : colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    badge,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isHighlighted
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
          if (description.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            detailLabel,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              priceLabel,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: isHighlighted ? colorScheme.primary : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BillingDetailRow extends StatelessWidget {
  const _BillingDetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(value, style: theme.textTheme.bodyLarge),
        ],
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

String _formatDateOnly(String? iso) {
  if (iso == null || iso.trim().isEmpty) {
    return '';
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

String _annualPriceLabel(int amount, AppLocalizations l10n) {
  return l10n.pick(
    vi: '${_formatVnd(amount)}/năm',
    en: '${_formatVnd(amount)}/year',
  );
}

String _adsExperienceLabel(BillingPlanPricing tier, AppLocalizations l10n) {
  if (tier.adFree || !tier.showAds) {
    return l10n.pick(vi: 'Không quảng cáo', en: 'Ad-free');
  }
  return l10n.pick(vi: 'Có quảng cáo', en: 'With ads');
}

BillingPlanPricing? _findPricingTierByPlanCode(
  Iterable<BillingPlanPricing> tiers,
  String planCode,
) {
  final normalizedPlanCode = planCode.trim().toUpperCase();
  for (final tier in tiers) {
    if (tier.planCode.trim().toUpperCase() == normalizedPlanCode) {
      return tier;
    }
  }
  return null;
}

String _resolveLocalizedText({
  required AppLocalizations l10n,
  String? generic,
  String? vi,
  String? en,
}) {
  final preferred = l10n.pick(vi: vi ?? '', en: en ?? '').trim();
  if (preferred.isNotEmpty) {
    return preferred;
  }
  final fallback = (generic ?? '').trim();
  if (fallback.isNotEmpty) {
    return fallback;
  }
  return '';
}

String _defaultPlanShortDescription(String planCode, AppLocalizations l10n) {
  switch (planCode.trim().toUpperCase()) {
    case 'FREE':
      return l10n.pick(
        vi: 'Cho gia phả nhỏ, bắt đầu nhanh',
        en: 'A quick start for small family trees',
      );
    case 'BASE':
      return l10n.pick(
        vi: 'Phù hợp khi gia phả bắt đầu mở rộng',
        en: 'A good fit for growing family trees',
      );
    case 'PLUS':
      return l10n.pick(
        vi: 'Không quảng cáo, phù hợp quy mô lớn',
        en: 'Ad-free for larger family trees',
      );
    case 'PRO':
      return l10n.pick(
        vi: 'Không giới hạn thành viên',
        en: 'Unlimited members for large family trees',
      );
    default:
      return '';
  }
}

String _planShortDescription(
  String planCode,
  AppLocalizations l10n, {
  BillingPlanPricing? tier,
}) {
  final localized = _resolveLocalizedText(
    l10n: l10n,
    vi: tier?.descriptionVi,
    en: tier?.descriptionEn,
  );
  if (localized.isNotEmpty) {
    return localized;
  }
  return _defaultPlanShortDescription(planCode, l10n);
}

String _heroTimelineLabel({
  required String? iso,
  required String planCode,
  required AppLocalizations l10n,
  required bool isNextDueDate,
}) {
  final formatted = _formatDateOnly(iso);
  if (formatted.isNotEmpty) {
    return formatted;
  }
  if (planCode.trim().toUpperCase() == 'FREE') {
    return isNextDueDate
        ? l10n.pick(vi: 'Không áp dụng', en: 'Not applicable')
        : l10n.pick(vi: 'Không giới hạn', en: 'No expiry');
  }
  return l10n.pick(vi: 'Chưa có', en: 'Not set');
}

String _defaultLocalizedPlanName(String planCode, AppLocalizations l10n) {
  switch (planCode.trim().toUpperCase()) {
    case 'FREE':
      return l10n.pick(vi: 'Miễn phí', en: 'Free');
    case 'BASE':
      return l10n.pick(vi: 'Tiêu chuẩn', en: 'Standard');
    case 'PLUS':
      return l10n.pick(vi: 'Nâng cao', en: 'Advanced');
    case 'PRO':
      return l10n.pick(vi: 'Toàn diện', en: 'Pro');
    default:
      final normalized = planCode.trim();
      return normalized.isEmpty ? planCode : normalized.toUpperCase();
  }
}

String _localizedPlanName(
  String planCode,
  AppLocalizations l10n, {
  BillingPlanPricing? tier,
}) {
  final localized = _resolveLocalizedText(
    l10n: l10n,
    generic: tier?.displayName,
    vi: tier?.displayNameVi,
    en: tier?.displayNameEn,
  );
  if (localized.isNotEmpty) {
    return localized;
  }
  return _defaultLocalizedPlanName(planCode, l10n);
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
