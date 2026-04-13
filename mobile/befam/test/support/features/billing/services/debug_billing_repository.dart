import 'dart:async';

import 'package:befam/features/auth/models/auth_session.dart';
import 'package:befam/features/billing/models/billing_workspace_snapshot.dart';
import 'package:befam/features/billing/services/billing_repository.dart';
import '../../../core/services/debug_genealogy_store.dart';

class DebugBillingRepository implements BillingRepository {
  DebugBillingRepository._({required DebugGenealogyStore genealogyStore})
    : _genealogyStore = genealogyStore;

  factory DebugBillingRepository.shared() {
    return DebugBillingRepository._(
      genealogyStore: DebugGenealogyStore.sharedSeeded(),
    );
  }

  final DebugGenealogyStore _genealogyStore;

  static final Map<String, _DebugBillingState> _statesByScopeId = {};
  static int _transactionSequence = 1;
  static int _invoiceSequence = 1;
  static int _auditSequence = 1;
  static const Duration _pendingTimeout = Duration(minutes: 20);

  @override
  bool get isSandbox => true;

  @override
  Future<BillingWorkspaceSnapshot> loadWorkspace({
    required AuthSession session,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    final clanId = _clanIdOf(session);
    final state = _ensureState(clanId: clanId, ownerUid: session.uid);
    _expireStalePendingTransactions(state);
    _syncStateWithMemberCount(state, clanId);
    return state.toSnapshot();
  }

  @override
  Future<BillingViewerSummary> loadViewerSummary({
    required AuthSession session,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 90));
    final clanId = _clanIdOf(session);
    final state = _ensureState(clanId: clanId, ownerUid: session.uid);
    _expireStalePendingTransactions(state);
    _syncStateWithMemberCount(state, clanId);
    return state.toViewerSummary();
  }

  @override
  Future<BillingEntitlement> resolveEntitlement({
    required AuthSession session,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 60));
    final clanId = _clanIdOf(session);
    final state = _ensureState(clanId: clanId, ownerUid: session.uid);
    _expireStalePendingTransactions(state);
    _syncStateWithMemberCount(state, clanId);
    return state.entitlement;
  }

  @override
  Future<BillingSettings> updatePreferences({
    required AuthSession session,
    required String paymentMode,
    required bool autoRenew,
    List<int>? reminderDaysBefore,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 90));
    final clanId = _clanIdOf(session);
    final state = _ensureState(clanId: clanId, ownerUid: session.uid);

    final normalizedMode = paymentMode.trim().toLowerCase();
    if (normalizedMode != 'manual' && normalizedMode != 'auto_renew') {
      throw const BillingRepositoryException(
        BillingRepositoryErrorCode.invalidArgument,
        'paymentMode must be manual or auto_renew.',
      );
    }

    state.settings = BillingSettings(
      id: '${clanId}__${session.uid}',
      clanId: clanId,
      paymentMode: normalizedMode,
      autoRenew: autoRenew,
      reminderDaysBefore:
          (reminderDaysBefore ?? state.settings.reminderDaysBefore)
              .where((value) => value > 0 && value <= 60)
              .toSet()
              .toList(growable: false)
            ..sort((left, right) => right.compareTo(left)),
      updatedAtIso: DateTime.now().toUtc().toIso8601String(),
    );

    state.subscription = BillingSubscription(
      id: state.subscription.id,
      clanId: state.subscription.clanId,
      planCode: state.subscription.planCode,
      status: state.subscription.status,
      memberCount: state.subscription.memberCount,
      amountVndYear: state.subscription.amountVndYear,
      vatIncluded: state.subscription.vatIncluded,
      paymentMode: state.settings.paymentMode,
      autoRenew: state.settings.autoRenew,
      startsAtIso: state.subscription.startsAtIso,
      expiresAtIso: state.subscription.expiresAtIso,
      nextPaymentDueAtIso: state.subscription.nextPaymentDueAtIso,
      graceEndsAtIso: state.subscription.graceEndsAtIso,
      lastPaymentMethod: state.subscription.lastPaymentMethod,
      lastTransactionId: state.subscription.lastTransactionId,
      updatedAtIso: DateTime.now().toUtc().toIso8601String(),
    );

    _writeAudit(
      state,
      clanId: clanId,
      action: 'billing_preferences_updated',
      entityType: 'billingSettings',
      entityId: state.settings.id,
      actorUid: session.uid,
    );

    return state.settings;
  }

  @override
  Future<BillingEntitlement> verifyInAppPurchase({
    required AuthSession session,
    required String platform,
    required String productId,
    required Map<String, dynamic> payload,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 140));
    final planCode = _planCodeFromIapProduct(productId);
    if (planCode == null) {
      throw const BillingRepositoryException(
        BillingRepositoryErrorCode.invalidArgument,
        'Unsupported in-app productId.',
      );
    }
    final paymentMethod = platform.trim().toLowerCase() == 'ios'
        ? 'apple_iap'
        : 'google_play';
    final transactionId = await _createIapCheckoutAndReturnTransactionId(
      session: session,
      paymentMethod: paymentMethod,
      requestedPlanCode: planCode,
    );
    final clanId = _clanIdOf(session);
    final state = _ensureState(clanId: clanId, ownerUid: session.uid);
    _applySuccessfulPayment(
      state,
      transactionId: transactionId,
      actorUid: session.uid,
    );
    return state.entitlement;
  }

  Future<String> _createIapCheckoutAndReturnTransactionId({
    required AuthSession session,
    required String paymentMethod,
    required String requestedPlanCode,
  }) async {
    final clanId = _clanIdOf(session);
    final state = _ensureState(clanId: clanId, ownerUid: session.uid);
    _expireStalePendingTransactions(state);
    _syncStateWithMemberCount(state, clanId);

    final method = paymentMethod.trim().toLowerCase();
    if (method != 'apple_iap' && method != 'google_play') {
      throw const BillingRepositoryException(
        BillingRepositoryErrorCode.invalidArgument,
        'paymentMethod must be apple_iap or google_play.',
      );
    }

    final minimumTier = _resolveTier(state.memberCount);
    final requestedPlan = requestedPlanCode.trim().toUpperCase();
    final requestedTier = _resolveTierByPlanCode(requestedPlan);
    if (_rankPlanCode(requestedTier.planCode) <
        _rankPlanCode(minimumTier.planCode)) {
      throw const BillingRepositoryException(
        BillingRepositoryErrorCode.invalidArgument,
        'requestedPlanCode is below minimum tier for current member count.',
      );
    }
    final tier = requestedTier;

    final now = DateTime.now().toUtc();
    final transactionId = 'txn_debug_${_transactionSequence++}';
    final invoiceId = 'inv_debug_${_invoiceSequence++}';

    final transaction = BillingPaymentTransaction(
      id: transactionId,
      clanId: clanId,
      subscriptionId: state.subscription.id,
      invoiceId: invoiceId,
      paymentMethod: method,
      paymentStatus: 'pending',
      planCode: tier.planCode,
      memberCount: state.memberCount,
      amountVnd: tier.priceVndYear,
      vatIncluded: true,
      currency: 'VND',
      gatewayReference:
          '${method.toUpperCase()}-${DateTime.now().millisecondsSinceEpoch}',
      createdAtIso: now.toIso8601String(),
      paidAtIso: null,
      failedAtIso: null,
    );
    state.transactions.insert(0, transaction);

    final invoice = BillingInvoice(
      id: invoiceId,
      clanId: clanId,
      subscriptionId: state.subscription.id,
      transactionId: transactionId,
      planCode: tier.planCode,
      amountVnd: tier.priceVndYear,
      vatIncluded: true,
      currency: 'VND',
      status: 'issued',
      periodStartIso: state.subscription.startsAtIso,
      periodEndIso: state.subscription.expiresAtIso,
      issuedAtIso: now.toIso8601String(),
      paidAtIso: null,
    );
    state.invoices.insert(0, invoice);

    state.subscription = BillingSubscription(
      id: state.subscription.id,
      clanId: clanId,
      planCode: state.subscription.planCode,
      status: state.subscription.status,
      memberCount: state.memberCount,
      amountVndYear: state.subscription.amountVndYear,
      vatIncluded: true,
      paymentMode: state.settings.paymentMode,
      autoRenew: state.settings.autoRenew,
      startsAtIso: state.subscription.startsAtIso,
      expiresAtIso: state.subscription.expiresAtIso,
      nextPaymentDueAtIso: state.subscription.nextPaymentDueAtIso,
      graceEndsAtIso: state.subscription.graceEndsAtIso,
      lastPaymentMethod: method,
      lastTransactionId: transactionId,
      updatedAtIso: now.toIso8601String(),
    );
    state.entitlement = _buildEntitlement(
      planCode: state.subscription.planCode,
      status: state.subscription.status,
      expiresAtIso: state.subscription.expiresAtIso,
      nextPaymentDueAtIso: state.subscription.nextPaymentDueAtIso,
    );

    _writeAudit(
      state,
      clanId: clanId,
      action: 'checkout_created',
      entityType: 'paymentTransaction',
      entityId: transactionId,
      actorUid: session.uid,
    );

    return transactionId;
  }

  _DebugBillingState _ensureState({
    required String clanId,
    required String ownerUid,
  }) {
    final scopeId = '${clanId}__$ownerUid';
    return _statesByScopeId.putIfAbsent(scopeId, () {
      final memberCount = _memberCountForClan(clanId);
      final tier = _resolveTier(memberCount);
      final now = DateTime.now().toUtc();
      final subscription = BillingSubscription(
        id: scopeId,
        clanId: clanId,
        planCode: tier.planCode,
        status: tier.planCode == 'FREE' ? 'active' : 'expired',
        memberCount: memberCount,
        amountVndYear: tier.priceVndYear,
        vatIncluded: true,
        paymentMode: 'manual',
        autoRenew: false,
        startsAtIso: tier.planCode == 'FREE' ? now.toIso8601String() : null,
        expiresAtIso: tier.planCode == 'FREE' ? null : now.toIso8601String(),
        nextPaymentDueAtIso: tier.planCode == 'FREE'
            ? null
            : now.toIso8601String(),
        graceEndsAtIso: null,
        lastPaymentMethod: null,
        lastTransactionId: null,
        updatedAtIso: now.toIso8601String(),
      );
      final settings = BillingSettings(
        id: scopeId,
        clanId: clanId,
        paymentMode: 'manual',
        autoRenew: false,
        reminderDaysBefore: const [30, 14, 7, 3, 1],
        updatedAtIso: now.toIso8601String(),
      );
      return _DebugBillingState(
        ownerUid: ownerUid,
        clanId: clanId,
        memberCount: memberCount,
        subscription: subscription,
        entitlement: _buildEntitlement(
          planCode: subscription.planCode,
          status: subscription.status,
          expiresAtIso: subscription.expiresAtIso,
          nextPaymentDueAtIso: subscription.nextPaymentDueAtIso,
        ),
        settings: settings,
        transactions: [],
        invoices: [],
        auditLogs: [],
      );
    });
  }

  void _syncStateWithMemberCount(_DebugBillingState state, String clanId) {
    final memberCount = _memberCountForClan(clanId);
    if (memberCount == state.memberCount) {
      return;
    }
    final minimumTier = _resolveTier(memberCount);
    final currentTier = _resolveTierByPlanCode(state.subscription.planCode);
    final tier =
        _rankPlanCode(currentTier.planCode) >=
            _rankPlanCode(minimumTier.planCode)
        ? currentTier
        : minimumTier;
    state.memberCount = memberCount;
    state.subscription = BillingSubscription(
      id: state.subscription.id,
      clanId: state.subscription.clanId,
      planCode: tier.planCode,
      status: tier.planCode == 'FREE' ? 'active' : state.subscription.status,
      memberCount: memberCount,
      amountVndYear: tier.priceVndYear,
      vatIncluded: true,
      paymentMode: state.settings.paymentMode,
      autoRenew: state.settings.autoRenew,
      startsAtIso: state.subscription.startsAtIso,
      expiresAtIso: state.subscription.expiresAtIso,
      nextPaymentDueAtIso: state.subscription.nextPaymentDueAtIso,
      graceEndsAtIso: state.subscription.graceEndsAtIso,
      lastPaymentMethod: state.subscription.lastPaymentMethod,
      lastTransactionId: state.subscription.lastTransactionId,
      updatedAtIso: DateTime.now().toUtc().toIso8601String(),
    );
    state.entitlement = _buildEntitlement(
      planCode: state.subscription.planCode,
      status: state.subscription.status,
      expiresAtIso: state.subscription.expiresAtIso,
      nextPaymentDueAtIso: state.subscription.nextPaymentDueAtIso,
    );
  }

  BillingPaymentTransaction _findTransaction(
    _DebugBillingState state,
    String transactionId,
  ) {
    final normalized = transactionId.trim();
    BillingPaymentTransaction? transaction;
    for (final item in state.transactions) {
      if (item.id == normalized) {
        transaction = item;
        break;
      }
    }
    if (transaction == null) {
      throw const BillingRepositoryException(
        BillingRepositoryErrorCode.notFound,
        'Transaction not found.',
      );
    }
    return transaction;
  }

  String? _planCodeFromIapProduct(String productId) {
    final normalized = productId.trim().toLowerCase();
    switch (normalized) {
      case 'base_yearly':
      case 'base_annual':
        return 'BASE';
      case 'plus_yearly':
      case 'plus_annual':
        return 'PLUS';
      case 'pro_yearly':
      case 'pro_annual':
        return 'PRO';
      default:
        return null;
    }
  }

  void _expireStalePendingTransactions(_DebugBillingState state) {
    final now = DateTime.now().toUtc();
    final expiredAt = now.subtract(_pendingTimeout);
    for (var index = 0; index < state.transactions.length; index += 1) {
      final tx = state.transactions[index];
      if (!_isPendingPaymentStatus(tx.paymentStatus)) {
        continue;
      }
      final createdAt = DateTime.tryParse(tx.createdAtIso ?? '')?.toUtc();
      if (createdAt == null || createdAt.isAfter(expiredAt)) {
        continue;
      }

      state.transactions[index] = BillingPaymentTransaction(
        id: tx.id,
        clanId: tx.clanId,
        subscriptionId: tx.subscriptionId,
        invoiceId: tx.invoiceId,
        paymentMethod: tx.paymentMethod,
        paymentStatus: 'canceled',
        planCode: tx.planCode,
        memberCount: tx.memberCount,
        amountVnd: tx.amountVnd,
        vatIncluded: tx.vatIncluded,
        currency: tx.currency,
        gatewayReference: tx.gatewayReference,
        createdAtIso: tx.createdAtIso,
        paidAtIso: null,
        failedAtIso: now.toIso8601String(),
      );

      final invoiceIndex = state.invoices.indexWhere(
        (item) => item.id == tx.invoiceId,
      );
      if (invoiceIndex >= 0) {
        final invoice = state.invoices[invoiceIndex];
        state.invoices[invoiceIndex] = BillingInvoice(
          id: invoice.id,
          clanId: invoice.clanId,
          subscriptionId: invoice.subscriptionId,
          transactionId: invoice.transactionId,
          planCode: invoice.planCode,
          amountVnd: invoice.amountVnd,
          vatIncluded: invoice.vatIncluded,
          currency: invoice.currency,
          status: 'void',
          periodStartIso: invoice.periodStartIso,
          periodEndIso: invoice.periodEndIso,
          issuedAtIso: invoice.issuedAtIso,
          paidAtIso: null,
        );
      }

      _writeAudit(
        state,
        clanId: state.clanId,
        action: 'payment_canceled_timeout',
        entityType: 'paymentTransaction',
        entityId: tx.id,
        actorUid: 'system:billing_pending_timeout',
      );
    }
  }

  void _applySuccessfulPayment(
    _DebugBillingState state, {
    required String transactionId,
    required String actorUid,
  }) {
    final now = DateTime.now().toUtc();
    final transaction = _findTransaction(state, transactionId);
    final txStatus = transaction.paymentStatus.trim().toLowerCase();
    if (txStatus == 'canceled' || txStatus == 'cancelled') {
      throw const BillingRepositoryException(
        BillingRepositoryErrorCode.failedPrecondition,
        'Transaction timed out and was canceled.',
      );
    }
    if (txStatus == 'failed') {
      throw const BillingRepositoryException(
        BillingRepositoryErrorCode.failedPrecondition,
        'Transaction is already marked as failed.',
      );
    }
    final txIndex = state.transactions.indexWhere(
      (item) => item.id == transactionId,
    );
    final paidTransaction = BillingPaymentTransaction(
      id: transaction.id,
      clanId: transaction.clanId,
      subscriptionId: transaction.subscriptionId,
      invoiceId: transaction.invoiceId,
      paymentMethod: transaction.paymentMethod,
      paymentStatus: 'succeeded',
      planCode: transaction.planCode,
      memberCount: transaction.memberCount,
      amountVnd: transaction.amountVnd,
      vatIncluded: transaction.vatIncluded,
      currency: transaction.currency,
      gatewayReference: transaction.gatewayReference,
      createdAtIso: transaction.createdAtIso,
      paidAtIso: now.toIso8601String(),
      failedAtIso: null,
    );
    state.transactions[txIndex] = paidTransaction;

    final invoiceIndex = state.invoices.indexWhere(
      (item) => item.id == transaction.invoiceId,
    );
    if (invoiceIndex >= 0) {
      final invoice = state.invoices[invoiceIndex];
      state.invoices[invoiceIndex] = BillingInvoice(
        id: invoice.id,
        clanId: invoice.clanId,
        subscriptionId: invoice.subscriptionId,
        transactionId: invoice.transactionId,
        planCode: invoice.planCode,
        amountVnd: invoice.amountVnd,
        vatIncluded: invoice.vatIncluded,
        currency: invoice.currency,
        status: 'paid',
        periodStartIso: invoice.periodStartIso,
        periodEndIso: invoice.periodEndIso,
        issuedAtIso: invoice.issuedAtIso,
        paidAtIso: now.toIso8601String(),
      );
    }

    final existingExpiry = DateTime.tryParse(
      state.subscription.expiresAtIso ?? '',
    )?.toUtc();
    final startsAt = existingExpiry != null && existingExpiry.isAfter(now)
        ? existingExpiry
        : now;
    final expiresAt = DateTime.utc(
      startsAt.year + 1,
      startsAt.month,
      startsAt.day,
      startsAt.hour,
      startsAt.minute,
      startsAt.second,
    );
    state.subscription = BillingSubscription(
      id: state.subscription.id,
      clanId: state.subscription.clanId,
      planCode: paidTransaction.planCode,
      status: 'active',
      memberCount: state.memberCount,
      amountVndYear: paidTransaction.amountVnd,
      vatIncluded: true,
      paymentMode: state.settings.paymentMode,
      autoRenew: state.settings.autoRenew,
      startsAtIso: startsAt.toIso8601String(),
      expiresAtIso: expiresAt.toIso8601String(),
      nextPaymentDueAtIso: expiresAt.toIso8601String(),
      graceEndsAtIso: null,
      lastPaymentMethod: paidTransaction.paymentMethod,
      lastTransactionId: paidTransaction.id,
      updatedAtIso: now.toIso8601String(),
    );
    state.entitlement = _buildEntitlement(
      planCode: state.subscription.planCode,
      status: state.subscription.status,
      expiresAtIso: state.subscription.expiresAtIso,
      nextPaymentDueAtIso: state.subscription.nextPaymentDueAtIso,
    );

    _writeAudit(
      state,
      clanId: state.clanId,
      action: 'payment_succeeded',
      entityType: 'paymentTransaction',
      entityId: transactionId,
      actorUid: actorUid,
    );
  }

  void _writeAudit(
    _DebugBillingState state, {
    required String clanId,
    required String action,
    required String entityType,
    required String entityId,
    required String actorUid,
  }) {
    state.auditLogs.insert(
      0,
      BillingAuditLog(
        id: 'audit_debug_${_auditSequence++}',
        clanId: clanId,
        actorUid: actorUid,
        action: action,
        entityType: entityType,
        entityId: entityId,
        createdAtIso: DateTime.now().toUtc().toIso8601String(),
      ),
    );
  }

  bool _isPendingPaymentStatus(String status) {
    final normalized = status.trim().toLowerCase();
    return normalized == 'pending' || normalized == 'created';
  }

  int _memberCountForClan(String clanId) {
    return _genealogyStore.members.values
        .where((member) => member.clanId == clanId)
        .length;
  }

  _PricingTier _resolveTier(int memberCount) {
    if (memberCount <= 10) {
      return _catalogTierForPlanCode('FREE');
    }
    if (memberCount <= 200) {
      return _catalogTierForPlanCode('BASE');
    }
    if (memberCount <= 700) {
      return _catalogTierForPlanCode('PLUS');
    }
    return _catalogTierForPlanCode('PRO');
  }

  _PricingTier _resolveTierByPlanCode(String planCode) {
    final normalized = planCode.trim().toUpperCase();
    if (normalized == 'BASE' || normalized == 'PLUS' || normalized == 'PRO') {
      return _catalogTierForPlanCode(normalized);
    }
    return _catalogTierForPlanCode('FREE');
  }

  int _rankPlanCode(String planCode) {
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

  BillingEntitlement _buildEntitlement({
    required String planCode,
    required String status,
    required String? expiresAtIso,
    required String? nextPaymentDueAtIso,
  }) {
    final isActive = status == 'active' || status == 'grace_period';
    final showAds = !isActive
        ? true
        : (planCode == 'FREE' || planCode == 'BASE');
    return BillingEntitlement(
      planCode: planCode,
      status: status,
      showAds: showAds,
      adFree: !showAds,
      hasPremiumAccess: isActive && planCode != 'FREE',
      expiresAtIso: expiresAtIso,
      nextPaymentDueAtIso: nextPaymentDueAtIso,
    );
  }

  String _clanIdOf(AuthSession session) {
    final clanId = (session.clanId ?? '').trim();
    if (clanId.isNotEmpty) {
      return clanId;
    }
    final uid = session.uid.trim();
    if (uid.isEmpty) {
      throw const BillingRepositoryException(
        BillingRepositoryErrorCode.failedPrecondition,
        'Missing authenticated user for billing scope.',
      );
    }
    return 'user_scope__$uid';
  }
}

class _DebugBillingState {
  _DebugBillingState({
    required this.ownerUid,
    required this.clanId,
    required this.memberCount,
    required this.subscription,
    required this.entitlement,
    required this.settings,
    required this.transactions,
    required this.invoices,
    required this.auditLogs,
  });

  final String ownerUid;
  final String clanId;
  int memberCount;
  BillingSubscription subscription;
  BillingEntitlement entitlement;
  BillingSettings settings;
  final List<BillingPaymentTransaction> transactions;
  final List<BillingInvoice> invoices;
  final List<BillingAuditLog> auditLogs;

  BillingWorkspaceSnapshot toSnapshot() {
    final pricing = [
      _catalogTierForPlanCode('FREE'),
      _catalogTierForPlanCode('BASE'),
      _catalogTierForPlanCode('PLUS'),
      _catalogTierForPlanCode('PRO'),
    ].map((tier) => tier.toPricing()).toList(growable: false);
    final aiUsageSummary = _buildAiUsageSummary(subscription.planCode);

    return BillingWorkspaceSnapshot(
      clanId: clanId,
      scope: BillingScopeContext(
        clanId: clanId,
        ownerUid: ownerUid,
        ownerDisplayName: null,
        clanStatus: 'active',
        viewerIsOwner: true,
      ),
      subscription: subscription,
      entitlement: entitlement,
      aiUsageSummary: aiUsageSummary,
      settings: settings,
      checkoutFlow: const BillingCheckoutFlowConfig(
        storeProductIdsByPlan: <String, String>{
          'BASE': 'befam.base.yearly',
          'PLUS': 'befam.plus.yearly',
          'PRO': 'befam.pro.yearly',
        },
        storeProductIdsByPlanByPlatform: <String, Map<String, String>>{
          'BASE': <String, String>{
            'ios': 'befam.base.yearly',
            'android': 'befam.base.yearly',
          },
          'PLUS': <String, String>{
            'ios': 'befam.plus.yearly',
            'android': 'befam.plus.yearly',
          },
          'PRO': <String, String>{
            'ios': 'befam.pro.yearly',
            'android': 'befam.pro.yearly',
          },
        },
      ),
      pricingTiers: pricing,
      memberCount: memberCount,
      transactions: List.unmodifiable(transactions),
      invoices: List.unmodifiable(invoices),
      auditLogs: List.unmodifiable(auditLogs),
    );
  }

  BillingViewerSummary toViewerSummary() {
    final snapshot = toSnapshot();
    return BillingViewerSummary(
      clanId: snapshot.clanId,
      scope: snapshot.scope,
      subscription: snapshot.subscription,
      entitlement: snapshot.entitlement,
      aiUsageSummary: snapshot.aiUsageSummary,
      pricingTiers: snapshot.pricingTiers,
      memberCount: snapshot.memberCount,
    );
  }

  BillingAiUsageSummary _buildAiUsageSummary(String planCode) {
    final normalizedPlanCode = planCode.trim().toUpperCase();
    final quotaCredits = _aiQuotaForPlan(normalizedPlanCode);
    final usedCredits = switch (normalizedPlanCode) {
      'PRO' => 184,
      'PLUS' => 72,
      'BASE' => 18,
      _ => 6,
    };
    return BillingAiUsageSummary(
      windowKey: '2026-04',
      planCode: normalizedPlanCode.isEmpty ? 'FREE' : normalizedPlanCode,
      quotaCredits: quotaCredits,
      usedCredits: usedCredits,
      remainingCredits: (quotaCredits - usedCredits).clamp(0, quotaCredits),
      totalRequests: switch (normalizedPlanCode) {
        'PRO' => 129,
        'PLUS' => 48,
        'BASE' => 12,
        _ => 4,
      },
      featureCounts: const <String, int>{
        'app_assistant_chat': 8,
        'event_copy': 3,
        'profile_review': 2,
      },
      featureCredits: const <String, int>{
        'app_assistant_chat': 16,
        'event_copy': 3,
        'profile_review': 2,
      },
    );
  }
}

int _aiQuotaForPlan(String planCode) {
  switch (planCode.trim().toUpperCase()) {
    case 'BASE':
      return 80;
    case 'PLUS':
      return 240;
    case 'PRO':
      return 800;
    default:
      return 20;
  }
}

_PricingTier _catalogTierForPlanCode(String planCode) {
  switch (planCode.trim().toUpperCase()) {
    case 'BASE':
      return const _PricingTier(
        planCode: 'BASE',
        minMembers: 11,
        maxMembers: 200,
        priceVndYear: 99000,
        showAds: true,
        displayName: 'Tiêu chuẩn',
        displayNameEn: 'Standard',
        displayNameVi: 'Tiêu chuẩn',
        descriptionEn: 'For growing family trees, 11 - 200 members, with ads',
        descriptionVi:
            'Phù hợp gia phả đang mở rộng, 11 - 200 thành viên, có quảng cáo',
      );
    case 'PLUS':
      return const _PricingTier(
        planCode: 'PLUS',
        minMembers: 201,
        maxMembers: 700,
        priceVndYear: 199000,
        showAds: false,
        displayName: 'Nâng cao',
        displayNameEn: 'Advanced',
        displayNameVi: 'Nâng cao',
        descriptionEn: 'Ad-free for larger family trees, 201 - 700 members',
        descriptionVi: 'Không quảng cáo, dành cho gia phả 201 - 700 thành viên',
      );
    case 'PRO':
      return const _PricingTier(
        planCode: 'PRO',
        minMembers: 701,
        maxMembers: null,
        priceVndYear: 299000,
        showAds: false,
        displayName: 'Toàn diện',
        displayNameEn: 'Pro',
        displayNameVi: 'Toàn diện',
        descriptionEn: 'Ad-free with unlimited members',
        descriptionVi: 'Không quảng cáo, không giới hạn thành viên',
      );
    default:
      return const _PricingTier(
        planCode: 'FREE',
        minMembers: 0,
        maxMembers: 10,
        priceVndYear: 0,
        showAds: true,
        displayName: 'Miễn phí',
        displayNameEn: 'Free',
        displayNameVi: 'Miễn phí',
        descriptionEn: 'For small family trees, up to 10 members, with ads',
        descriptionVi: 'Cho gia phả nhỏ, tối đa 10 thành viên, có quảng cáo',
      );
  }
}

class _PricingTier {
  const _PricingTier({
    required this.planCode,
    required this.minMembers,
    required this.maxMembers,
    required this.priceVndYear,
    required this.showAds,
    required this.displayName,
    required this.displayNameEn,
    required this.displayNameVi,
    required this.descriptionEn,
    required this.descriptionVi,
  });

  final String planCode;
  final int minMembers;
  final int? maxMembers;
  final int priceVndYear;
  final bool showAds;
  final String displayName;
  final String displayNameEn;
  final String displayNameVi;
  final String descriptionEn;
  final String descriptionVi;

  BillingPlanPricing toPricing() {
    return BillingPlanPricing(
      planCode: planCode,
      minMembers: minMembers,
      maxMembers: maxMembers,
      priceVndYear: priceVndYear,
      vatIncluded: true,
      showAds: showAds,
      adFree: !showAds,
      displayName: displayName,
      displayNameEn: displayNameEn,
      displayNameVi: displayNameVi,
      descriptionEn: descriptionEn,
      descriptionVi: descriptionVi,
    );
  }
}
