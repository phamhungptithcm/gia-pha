import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../app/theme/app_ui_tokens.dart';
import '../../../core/services/app_environment.dart';
import '../../../core/widgets/app_async_action.dart';
import '../../../core/widgets/app_feedback_states.dart';
import '../../../core/widgets/app_workspace_chrome.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../l10n/l10n.dart';
import '../../auth/models/auth_session.dart';
import '../models/billing_workspace_snapshot.dart';
import '../services/billing_repository.dart';
import '../services/store_iap_gateway.dart';
import 'billing_controller.dart';

typedef ExternalUriLauncher = Future<bool> Function(Uri uri);
const List<int> _kDefaultRenewalReminderDays = [5, 4, 3, 2, 1];

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
  String? _selectedPlanCodeDraft;
  String? _draftSeedKey;
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
            _friendlyStorePurchaseErrorMessage(
              errorMessage,
              l10n,
              storeLabel: _activeStoreLabel(l10n),
            ),
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
        '${workspace.entitlement.planCode}|${workspace.memberCount}|$defaultPlanCode';
    if (_draftSeedKey == seed) {
      return;
    }
    _draftSeedKey = seed;
    _selectedPlanCodeDraft = defaultPlanCode;
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
                      en: 'Loading subscription details...',
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

    return RefreshIndicator(
      onRefresh: _controller.refresh,
      child: AppWorkspaceViewport(
        child: ListView(
          padding: appWorkspacePagePadding(context, top: 16, bottom: 32),
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
            if (_controller.isProcessingPayment)
              const LinearProgressIndicator(minHeight: 2),
            if (_controller.isProcessingPayment)
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
                  entitlement.expiresAtIso ??
                  workspace.subscription.expiresAtIso,
              nextPaymentDueAtIso:
                  entitlement.nextPaymentDueAtIso ??
                  workspace.subscription.nextPaymentDueAtIso,
            ),
            if (!canManage) ...[
              const SizedBox(height: 16),
              _InfoCard(
                icon: Icons.lock_outline,
                title: l10n.pick(
                  vi: 'Chỉ quản trị viên có thể đổi gói',
                  en: 'Only admins can manage billing',
                ),
                description: l10n.pick(
                  vi: 'Liên hệ $resolvedOwnerLabel để nâng cấp hoặc gia hạn.',
                  en: 'Contact $resolvedOwnerLabel to upgrade or renew.',
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
                        vi: 'Gói này chưa sẵn sàng để thanh toán',
                        en: 'This plan is not ready for checkout',
                      ),
                      description: l10n.pick(
                        vi: 'Vui lòng thử lại sau.',
                        en: 'Please try again later.',
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
                                          vi: 'Thanh toán chưa sẵn sàng trên phiên này.',
                                          en: 'Checkout is not available in this session.',
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
                ],
              ),
            ),
          ],
        ),
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
      child: AppWorkspaceViewport(
        child: ListView(
          padding: appWorkspacePagePadding(context, top: 16, bottom: 32),
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
              amountVnd:
                  tier?.priceVndYear ?? summary.subscription.amountVndYear,
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
                vi: 'Bạn đang xem gói hiện tại. Quản trị viên có thể đổi gói và theo dõi lịch sử trong Hồ sơ > Cài đặt.',
                en: 'You are viewing the current plan. Admins can change plans and review billing details in Profile > Settings.',
              ),
              tone: colorScheme.secondaryContainer,
            ),
          ],
        ),
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

}

class BillingDetailsPage extends StatefulWidget {
  const BillingDetailsPage({
    super.key,
    required this.session,
    this.repository,
  });

  final AuthSession session;
  final BillingRepository? repository;

  @override
  State<BillingDetailsPage> createState() => _BillingDetailsPageState();
}

class _BillingDetailsPageState extends State<BillingDetailsPage> {
  late final BillingController _controller;
  String? _paymentModeDraft;
  bool _autoRenewDraft = false;
  bool _renewalReminderEnabledDraft = true;
  Set<int> _reminderDaysDraft = _kDefaultRenewalReminderDays.toSet();
  String? _draftSeedKey;
  bool _showPreferencesSavedInline = false;

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

  Future<void> _savePreferences() async {
    final mode =
        _paymentModeDraft ?? (_autoRenewDraft ? 'auto_renew' : 'manual');
    final reminderDaysBefore = _renewalReminderEnabledDraft
        ? _kDefaultRenewalReminderDays
        : const <int>[];
    await _controller.updatePreferences(
      paymentMode: mode,
      autoRenew: _autoRenewDraft,
      reminderDaysBefore: reminderDaysBefore,
    );
    if (!mounted || _controller.errorMessage != null) {
      return;
    }
    setState(() {
      _reminderDaysDraft = reminderDaysBefore.toSet();
      _showPreferencesSavedInline = true;
    });
  }

  void _syncDraftFromWorkspace(BillingWorkspaceSnapshot workspace) {
    final settings = workspace.settings;
    final seed =
        '${settings.updatedAtIso}|${settings.paymentMode}|'
        '${settings.autoRenew}|${settings.reminderDaysBefore.join(',')}';
    if (_draftSeedKey == seed) {
      return;
    }
    _draftSeedKey = seed;
    _paymentModeDraft = settings.paymentMode;
    _autoRenewDraft = settings.autoRenew;
    _renewalReminderEnabledDraft = settings.reminderDaysBefore.isNotEmpty;
    _reminderDaysDraft = _renewalReminderEnabledDraft
        ? settings.reminderDaysBefore.toSet()
        : <int>{};
  }

  bool _hasRenewalSettingsChanges(BillingWorkspaceSnapshot workspace) {
    final settings = workspace.settings;
    final serverPaymentMode = settings.paymentMode.trim().toLowerCase();
    final draftPaymentMode =
        (_paymentModeDraft ?? (_autoRenewDraft ? 'auto_renew' : 'manual'))
            .trim()
            .toLowerCase();
    final remindersOnServer = settings.reminderDaysBefore.toSet();
    final reminderSetMatches =
        _reminderDaysDraft.length == remindersOnServer.length &&
        _reminderDaysDraft.containsAll(remindersOnServer);
    return _autoRenewDraft != settings.autoRenew ||
        draftPaymentMode != serverPaymentMode ||
        reminderSetMatches == false;
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
          appBar: AppBar(
            title: Text(
              l10n.pick(
                vi: 'Lượt AI và thanh toán',
                en: 'AI usage & billing',
              ),
            ),
            actions: [
              IconButton(
                tooltip: l10n.pick(vi: 'Tải lại', en: 'Refresh'),
                onPressed: _controller.isLoading ? null : _controller.refresh,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          body: SafeArea(
            child: _controller.isLoading
                ? AppLoadingState(
                    message: l10n.pick(
                      vi: 'Đang tải thông tin thanh toán...',
                      en: 'Loading billing details...',
                    ),
                  )
                : workspace != null
                ? _buildManagerWorkspace(context, workspace)
                : viewerSummary != null
                ? _buildViewerWorkspace(context, viewerSummary)
                : _EmptyState(
                    icon: Icons.error_outline,
                    title: l10n.pick(
                      vi: 'Không thể tải chi tiết thanh toán',
                      en: 'Unable to load billing details',
                    ),
                    description: _friendlyErrorMessage(
                      _controller.errorMessage,
                      l10n,
                    ),
                  ),
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
    final renewalReminderDescription = l10n.pick(
      vi: 'Bật lên để BeFam gửi push mỗi ngày trong 5 ngày cuối trước khi gói hết hạn.',
      en: 'Turn this on so BeFam sends a push each day during the final 5 days before your plan expires.',
    );
    final pendingTransactions = workspace.transactions
        .where((tx) => _isPendingPaymentStatus(tx.paymentStatus))
        .toList(growable: false);
    final hasRenewalSettingsChanges = _hasRenewalSettingsChanges(workspace);

    return RefreshIndicator(
      onRefresh: _controller.refresh,
      child: AppWorkspaceViewport(
        child: ListView(
          padding: appWorkspacePagePadding(context, top: 16, bottom: 32),
          children: [
            if (_controller.errorMessage case final error?) ...[
              _InfoCard(
                icon: Icons.error_outline,
                title: l10n.pick(
                  vi: 'Không thể cập nhật cài đặt thanh toán',
                  en: 'Unable to update billing settings',
                ),
                description: _friendlyErrorMessage(error, l10n),
                tone: colorScheme.errorContainer,
              ),
              const SizedBox(height: 12),
            ],
            if (_controller.isSavingPreferences)
              const LinearProgressIndicator(minHeight: 2),
            if (_controller.isSavingPreferences) const SizedBox(height: 12),
            _AiUsageSummaryCard(summary: workspace.aiUsageSummary),
            const SizedBox(height: 16),
            _SectionCard(
              title: l10n.pick(vi: 'Nhắc gia hạn', en: 'Renewal reminders'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    container: true,
                    label: l10n.pick(
                      vi: 'Công tắc bật tự động nhắc gia hạn',
                      en: 'Renewal reminder switch',
                    ),
                    hint: renewalReminderDescription,
                    toggled: _renewalReminderEnabledDraft,
                    child: AppWorkspaceSurface(
                      color: colorScheme.surfaceContainerLowest.withValues(
                        alpha: 0.82,
                      ),
                      padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: colorScheme.secondaryContainer.withValues(
                                alpha: 0.88,
                              ),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              Icons.notifications_active_outlined,
                              color: colorScheme.onSecondaryContainer,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.pick(
                                    vi: 'Tự động nhắc gia hạn',
                                    en: 'Automatic renewal reminders',
                                  ),
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  renewalReminderDescription,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Switch.adaptive(
                            value: _renewalReminderEnabledDraft,
                            activeThumbColor: colorScheme.onPrimaryContainer,
                            activeTrackColor: colorScheme.primaryContainer,
                            inactiveThumbColor: colorScheme.onSurface,
                            inactiveTrackColor:
                                colorScheme.surfaceContainerHighest,
                            onChanged: _controller.canMutateBilling
                                ? (value) {
                                    setState(() {
                                      _renewalReminderEnabledDraft = value;
                                      _reminderDaysDraft = value
                                          ? _kDefaultRenewalReminderDays.toSet()
                                          : <int>{};
                                      _showPreferencesSavedInline = false;
                                    });
                                  }
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _renewalReminderEnabledDraft
                        ? l10n.pick(
                            vi: 'BeFam sẽ gửi push nhắc gia hạn mỗi ngày từ 5 ngày trước khi hết hạn.',
                            en: 'BeFam will send a renewal push every day starting 5 days before expiry.',
                          )
                        : l10n.pick(
                            vi: 'Tắt để dừng toàn bộ push nhắc gia hạn tự động.',
                            en: 'Turn this off to stop automatic renewal reminder pushes.',
                          ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: AppAsyncAction(
                      enabled:
                          _controller.canMutateBilling &&
                          !_controller.isSavingPreferences &&
                          hasRenewalSettingsChanges,
                      onPressed:
                          _controller.canMutateBilling &&
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
            if (pendingTransactions.isNotEmpty) ...[
              const SizedBox(height: 16),
              _SectionCard(
                title: l10n.pick(
                  vi: 'Giao dịch đang chờ xử lý',
                  en: 'Pending transactions',
                ),
                child: Column(
                  children: [
                    for (final entry
                        in pendingTransactions.take(4).toList(growable: false))
                      Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            _openPendingTransactionDetail(transaction: entry);
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${entry.paymentMethod.toUpperCase()} • ${_formatVnd(entry.amountVnd)}',
                                        style: theme.textTheme.titleSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        l10n.pick(
                                          vi: 'Tạo lúc: ${_dateLabel(entry.createdAtIso, l10n)}',
                                          en: 'Created: ${_dateLabel(entry.createdAtIso, l10n)}',
                                        ),
                                        style: theme.textTheme.bodyMedium,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        l10n.pick(
                                          vi: 'Trạng thái: ${_humanizeStatus(entry.paymentStatus, l10n)}',
                                          en: 'Status: ${_humanizeStatus(entry.paymentStatus, l10n)}',
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
                                      _pendingTimeoutLabel(entry, l10n),
                                      textAlign: TextAlign.right,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: colorScheme.primary,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
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
                      title: l10n.pick(
                        vi: 'Chưa có hóa đơn',
                        en: 'No invoices',
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
          ],
        ),
      ),
    );
  }

  Widget _buildViewerWorkspace(
    BuildContext context,
    BillingViewerSummary summary,
  ) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final ownerLabel = (summary.scope.ownerDisplayName ?? '').trim();
    final resolvedOwnerLabel = ownerLabel.isEmpty
        ? l10n.pick(vi: 'quản trị gia phả', en: 'the clan owner')
        : ownerLabel;

    return RefreshIndicator(
      onRefresh: _controller.refresh,
      child: AppWorkspaceViewport(
        child: ListView(
          padding: appWorkspacePagePadding(context, top: 16, bottom: 32),
          children: [
            _AiUsageSummaryCard(summary: summary.aiUsageSummary),
            const SizedBox(height: 16),
            _InfoCard(
              icon: Icons.lock_outline,
              title: l10n.pick(
                vi: 'Lịch sử thanh toán do quản trị viên quản lý',
                en: 'Billing history is managed by admins',
              ),
              description: l10n.pick(
                vi: 'Liên hệ $resolvedOwnerLabel nếu bạn cần xem hóa đơn hoặc cập nhật cài đặt gia hạn.',
                en: 'Contact $resolvedOwnerLabel if you need invoices or renewal setting updates.',
              ),
              tone: colorScheme.secondaryContainer,
            ),
          ],
        ),
      ),
    );
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

    return AppWorkspaceSurface(
      padding: const EdgeInsets.all(22),
      gradient: appWorkspaceHeroGradient(context),
      showAccentOrbs: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                planDisplayName,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: colorScheme.onSurface,
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
                  color: colorScheme.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  statusLabel,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: colorScheme.onSurface,
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
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.pick(
              vi: 'Phí năm: ${_formatVnd(amountVnd)} (đã gồm VAT)',
              en: 'Annual fee: ${_formatVnd(amountVnd)} (VAT included)',
            ),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
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
    required this.detailLabel,
    required this.priceLabel,
    required this.isSelected,
    required this.isCurrentPlan,
    required this.isEnabled,
    required this.onTap,
  });

  final String planName;
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
    required this.detailLabel,
    required this.priceLabel,
    this.badgeLabel,
    this.isHighlighted = false,
  });

  final String planName;
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

class _AiUsageSummaryCard extends StatelessWidget {
  const _AiUsageSummaryCard({required this.summary});

  final BillingAiUsageSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final tokens = context.uiTokens;
    final planLabel = _localizedPlanName(summary.planCode, l10n);
    final progress = summary.usageProgress;
    final isExhausted = summary.remainingCredits <= 0;
    final isNearLimit = !isExhausted && progress >= 0.8;
    final featureEntries = summary.featureCredits.entries.toList(growable: false)
      ..sort((left, right) => right.value.compareTo(left.value));
    final topFeatures = featureEntries.take(3).toList(growable: false);
    final statusTitle = isExhausted
        ? l10n.pick(
            vi: 'Đã dùng hết lượt trong tháng này',
            en: 'Monthly AI help has been used up',
          )
        : isNearLimit
        ? l10n.pick(
            vi: 'Sắp chạm giới hạn tháng',
            en: 'Getting close to the monthly limit',
          )
        : l10n.pick(
            vi: 'Vẫn còn dư để dùng khi thật sự cần',
            en: 'Still plenty left for the moments that matter',
          );
    final statusDescription = isExhausted
        ? l10n.pick(
            vi:
                'Các tính năng AI sẽ tạm nghỉ đến kỳ mới hoặc khi gói được nâng cấp.',
            en:
                'AI features pause until the next billing window or until the plan is upgraded.',
          )
        : isNearLimit
        ? l10n.pick(
            vi:
                'Ưu tiên giữ lượt cho các câu hỏi tìm người thân hoặc tác vụ thật sự cần thiết.',
            en:
                'Save the remaining uses for family lookups or the tasks that matter most.',
          )
        : l10n.pick(
            vi:
                'Bạn vẫn còn khá thoải mái cho chat tìm người, hỗ trợ hồ sơ, và gợi ý nội dung.',
            en:
                'You still have comfortable room for family search, profile help, and content suggestions.',
          );
    final topFeature = topFeatures.isEmpty ? null : topFeatures.first;

    return _SectionCard(
      sectionKey: const Key('billing-ai-usage-section'),
      title: l10n.pick(
        vi: 'Lượt hỗ trợ AI tháng này',
        en: 'AI help this month',
      ),
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
                      l10n.pick(
                        vi: 'Còn lại',
                        en: 'Remaining',
                      ),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: tokens.spaceXs),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${summary.remainingCredits}',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: isExhausted
                                ? colorScheme.error
                                : colorScheme.onSurface,
                          ),
                        ),
                        SizedBox(width: tokens.spaceSm),
                        Padding(
                          padding: EdgeInsets.only(bottom: tokens.spaceXs),
                          child: Text(
                            l10n.pick(
                              vi: '/ ${summary.quotaCredits} lượt',
                              en: '/ ${summary.quotaCredits} uses',
                            ),
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: tokens.spaceXs),
                      Text(
                        l10n.pick(
                          vi:
                            'Đang áp dụng theo gói $planLabel cho ${_aiUsageWindowLabel(summary.windowKey, l10n)}.',
                          en:
                            'Based on the $planLabel plan for ${_aiUsageWindowLabel(summary.windowKey, l10n)}.',
                        ),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: tokens.spaceMd),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: tokens.spaceMd,
                  vertical: tokens.spaceSm,
                ),
                decoration: BoxDecoration(
                  color: isExhausted
                      ? colorScheme.errorContainer
                      : isNearLimit
                      ? colorScheme.tertiaryContainer
                      : colorScheme.primaryContainer.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(tokens.radiusLg),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.pick(vi: 'Đã dùng', en: 'Used'),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: tokens.spaceXs / 2),
                    Text(
                      '${summary.usedCredits}',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: tokens.spaceMd),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: progress,
              backgroundColor: colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(
                isExhausted
                    ? colorScheme.error
                    : isNearLimit
                    ? colorScheme.tertiary
                    : colorScheme.primary,
              ),
            ),
          ),
          SizedBox(height: tokens.spaceMd),
          Wrap(
            spacing: tokens.spaceSm,
            runSpacing: tokens.spaceSm,
            children: [
              _HeroPill(
                icon: Icons.history_outlined,
                text: l10n.pick(
                  vi: '${summary.totalRequests} lần dùng',
                  en: '${summary.totalRequests} uses',
                ),
              ),
              _HeroPill(
                icon: Icons.auto_awesome_outlined,
                text: topFeature == null
                    ? l10n.pick(vi: 'Chưa có hoạt động', en: 'No usage yet')
                    : l10n.pick(
                        vi: 'Dùng nhiều nhất: ${_aiFeatureLabel(topFeature.key, l10n)}',
                        en:
                            'Top use: ${_aiFeatureLabel(topFeature.key, l10n)}',
                      ),
              ),
            ],
          ),
          SizedBox(height: tokens.spaceMd),
          Container(
            padding: EdgeInsets.all(tokens.spaceMd),
            decoration: BoxDecoration(
              color: isExhausted
                  ? colorScheme.errorContainer.withValues(alpha: 0.82)
                  : isNearLimit
                  ? colorScheme.tertiaryContainer.withValues(alpha: 0.82)
                  : colorScheme.secondaryContainer.withValues(alpha: 0.68),
              borderRadius: BorderRadius.circular(tokens.radiusLg),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  isExhausted
                      ? Icons.block_outlined
                      : isNearLimit
                      ? Icons.warning_amber_rounded
                      : Icons.favorite_border_rounded,
                ),
                SizedBox(width: tokens.spaceSm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        statusTitle,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: tokens.spaceXs),
                      Text(
                        statusDescription,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (topFeatures.isNotEmpty) ...[
            SizedBox(height: tokens.spaceMd),
            Text(
              l10n.pick(
                vi: 'Dùng nhiều nhất',
                en: 'Used most often',
              ),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: tokens.spaceSm),
            for (var index = 0; index < topFeatures.length; index += 1)
              Container(
                margin: EdgeInsets.only(
                  bottom: index == topFeatures.length - 1 ? 0 : tokens.spaceSm,
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: tokens.spaceMd,
                  vertical: tokens.spaceSm,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.56,
                  ),
                  borderRadius: BorderRadius.circular(tokens.radiusLg),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _aiFeatureLabel(topFeatures[index].key, l10n),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    SizedBox(width: tokens.spaceSm),
                    Text(
                      l10n.pick(
                        vi:
                            '${summary.featureCounts[topFeatures[index].key] ?? 0} lần • ${topFeatures[index].value} lượt',
                        en:
                            '${summary.featureCounts[topFeatures[index].key] ?? 0} uses • ${topFeatures[index].value} credits',
                      ),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
          ],
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

String _aiFeatureLabel(String feature, AppLocalizations l10n) {
  switch (feature.trim()) {
    case 'app_assistant_chat':
      return l10n.pick(vi: 'Bubble chat và tìm kiếm', en: 'Bubble chat and search');
    case 'event_copy':
      return l10n.pick(vi: 'Gợi ý nội dung sự kiện', en: 'Event copy suggestions');
    case 'profile_review':
      return l10n.pick(vi: 'Kiểm tra nhanh hồ sơ', en: 'Quick profile check');
    case 'duplicate_genealogy':
      return l10n.pick(
        vi: 'Rà soát tạo trùng gia phả',
        en: 'Duplicate genealogy review',
      );
    default:
      return feature.trim().isEmpty ? l10n.pick(vi: 'AI khác', en: 'Other AI') : feature;
  }
}

String _aiUsageWindowLabel(String windowKey, AppLocalizations l10n) {
  final parts = windowKey.split('-');
  if (parts.length != 2) {
    return windowKey;
  }
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  if (year == null || month == null || month < 1 || month > 12) {
    return windowKey;
  }
  final normalizedMonth = month.toString().padLeft(2, '0');
  return l10n.pick(
    vi: 'tháng $normalizedMonth/$year',
    en: '$normalizedMonth/$year',
  );
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
        color: colorScheme.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colorScheme.onSurface),
          const SizedBox(width: 6),
          Text(
            text,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurface,
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
    required this.tone,
    this.description,
  });

  final IconData icon;
  final String title;
  final String? description;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return AppWorkspaceSurface(
      color: tone,
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
                if (description != null && description!.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    description!,
                    maxLines: 6,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
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
    return AppWorkspaceSurface(
      key: sectionKey,
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
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    this.description,
  });

  final IconData icon;
  final String title;
  final String? description;

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
                    if (description != null &&
                        description!.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        description!,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
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

String _friendlyStorePurchaseErrorMessage(
  String? raw,
  AppLocalizations l10n, {
  required String storeLabel,
}) {
  final fallback = l10n.pick(
    vi: 'Không thể hoàn tất giao dịch. Vui lòng thử lại.',
    en: 'Could not complete this purchase. Please try again.',
  );
  if (raw == null || raw.trim().isEmpty) {
    return fallback;
  }

  final normalized = raw.replaceAll('\r', '').trim();
  final lower = normalized.toLowerCase();
  final isPlayMissingItem =
      lower.contains('could not be found') ||
      lower.contains('item unavailable') ||
      lower.contains('item is unavailable') ||
      lower.contains('product not available') ||
      lower.contains('requested product is not available');

  if (isPlayMissingItem) {
    return l10n.pick(
      vi: '$storeLabel chưa nhận ra gói đăng ký cho bản app hiện tại. Nếu đây là bản cài thủ công bằng adb, hãy test bằng build cài từ Google Play internal testing hoặc thêm tài khoản vào License Testing. Đồng thời kiểm tra product ID đang active trên Play Console: befam.base.yearly, befam.plus.yearly, befam.pro.yearly.',
      en: '$storeLabel does not recognize the subscription for this app build. If this is a sideloaded adb build, test with a build installed from Google Play internal testing or add the account to License Testing. Also verify these Play Console product IDs are active: befam.base.yearly, befam.plus.yearly, befam.pro.yearly.',
    );
  }

  if (lower.contains('billing unavailable') ||
      lower.contains('store billing')) {
    return l10n.pick(
      vi: 'Thiết bị này chưa sẵn sàng cho thanh toán qua $storeLabel. Hãy kiểm tra Google Play Services, tài khoản đăng nhập và kết nối mạng rồi thử lại.',
      en: 'This device is not ready for $storeLabel billing yet. Check Google Play Services, the signed-in account, and network connectivity, then try again.',
    );
  }

  if (normalized.length > 180) {
    return '${normalized.substring(0, 180)}...';
  }
  return normalized;
}

extension on Iterable<BillingPlanPricing> {
  BillingPlanPricing? get firstOrNull {
    for (final item in this) {
      return item;
    }
    return null;
  }
}
