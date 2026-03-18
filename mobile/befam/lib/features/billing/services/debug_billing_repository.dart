import 'dart:async';

import '../../../core/services/debug_genealogy_store.dart';
import '../../auth/models/auth_session.dart';
import '../models/billing_workspace_snapshot.dart';
import 'billing_repository.dart';

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
  Future<BillingCheckoutResult> createCheckout({
    required AuthSession session,
    required String paymentMethod,
    String? requestedPlanCode,
    String? returnUrl,
    String? locale,
    String? orderNote,
    String? bankCode,
    String? contactPhone,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 140));
    final clanId = _clanIdOf(session);
    final state = _ensureState(clanId: clanId, ownerUid: session.uid);
    _expireStalePendingTransactions(state);
    _syncStateWithMemberCount(state, clanId);

    final method = paymentMethod.trim().toLowerCase();
    if (method != 'card' && method != 'vnpay') {
      throw const BillingRepositoryException(
        BillingRepositoryErrorCode.invalidArgument,
        'paymentMethod must be card or vnpay.',
      );
    }

    final minimumTier = _resolveTier(state.memberCount);
    final currentTier = _resolveTierByPlanCode(state.subscription.planCode);
    final defaultTier =
        _rankPlanCode(currentTier.planCode) >=
            _rankPlanCode(minimumTier.planCode)
        ? currentTier
        : minimumTier;
    var tier = defaultTier;
    final requestedPlan = requestedPlanCode?.trim().toUpperCase();
    if (requestedPlan != null && requestedPlan.isNotEmpty) {
      final requestedTier = _resolveTierByPlanCode(requestedPlan);
      if (_rankPlanCode(requestedTier.planCode) <
          _rankPlanCode(minimumTier.planCode)) {
        throw const BillingRepositoryException(
          BillingRepositoryErrorCode.invalidArgument,
          'requestedPlanCode is below minimum tier for current member count.',
        );
      }
      tier = requestedTier;
    }
    final canRenewCurrentPlan = _canRenewCurrentPlan(state.subscription);
    final selectedPlanRank = _rankPlanCode(tier.planCode);
    if (selectedPlanRank == _rankPlanCode(state.subscription.planCode) &&
        !canRenewCurrentPlan) {
      throw const BillingRepositoryException(
        BillingRepositoryErrorCode.invalidArgument,
        'Current plan is not in renewal window yet.',
      );
    }

    final now = DateTime.now().toUtc();
    final transactionId = 'txn_debug_${_transactionSequence++}';
    final invoiceId = 'inv_debug_${_invoiceSequence++}';

    final transaction = BillingPaymentTransaction(
      id: transactionId,
      clanId: clanId,
      subscriptionId: state.subscription.id,
      invoiceId: invoiceId,
      paymentMethod: method,
      paymentStatus: tier.planCode == 'FREE' ? 'succeeded' : 'pending',
      planCode: tier.planCode,
      memberCount: state.memberCount,
      amountVnd: tier.priceVndYear,
      vatIncluded: true,
      currency: 'VND',
      gatewayReference:
          '${method.toUpperCase()}-${DateTime.now().millisecondsSinceEpoch}',
      createdAtIso: now.toIso8601String(),
      paidAtIso: tier.planCode == 'FREE' ? now.toIso8601String() : null,
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
      status: tier.planCode == 'FREE' ? 'paid' : 'issued',
      periodStartIso: state.subscription.startsAtIso,
      periodEndIso: state.subscription.expiresAtIso,
      issuedAtIso: now.toIso8601String(),
      paidAtIso: tier.planCode == 'FREE' ? now.toIso8601String() : null,
    );
    state.invoices.insert(0, invoice);

    final keepCurrentPlanUntilPaid = tier.planCode != 'FREE';
    state.subscription = BillingSubscription(
      id: state.subscription.id,
      clanId: clanId,
      planCode: keepCurrentPlanUntilPaid
          ? state.subscription.planCode
          : tier.planCode,
      status: keepCurrentPlanUntilPaid
          ? state.subscription.status
          : (tier.planCode == 'FREE' ? 'active' : 'pending_payment'),
      memberCount: state.memberCount,
      amountVndYear: keepCurrentPlanUntilPaid
          ? state.subscription.amountVndYear
          : tier.priceVndYear,
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

    if (tier.planCode == 'FREE') {
      _applySuccessfulPayment(
        state,
        transactionId: transactionId,
        actorUid: session.uid,
      );
    }

    final checkoutUrl = Uri.https(
      'checkout-debug.befam.local',
      '/billing/vnpay',
      {
        'transactionId': transactionId,
        'amountVnd': '${tier.priceVndYear}',
        if (locale != null && locale.trim().isNotEmpty) 'locale': locale.trim(),
        if (bankCode != null && bankCode.trim().isNotEmpty)
          'bankCode': bankCode.trim().toUpperCase(),
        if (orderNote != null && orderNote.trim().isNotEmpty)
          'orderNote': orderNote.trim(),
        if (contactPhone != null && contactPhone.trim().isNotEmpty)
          'contactPhone': contactPhone.trim(),
        'mode': method,
        'debug': '1',
      },
    ).toString();

    return BillingCheckoutResult(
      clanId: clanId,
      paymentMethod: method,
      planCode: tier.planCode,
      amountVnd: tier.priceVndYear,
      vatIncluded: true,
      transactionId: transactionId,
      invoiceId: invoiceId,
      checkoutUrl: checkoutUrl,
      requiresManualConfirmation: method == 'card' && tier.planCode != 'FREE',
      subscription: state.subscription,
      entitlement: state.entitlement,
    );
  }

  @override
  Future<void> completeCardCheckout({
    required AuthSession session,
    required String transactionId,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 130));
    final clanId = _clanIdOf(session);
    final state = _ensureState(clanId: clanId, ownerUid: session.uid);
    final transaction = _findTransaction(state, transactionId);
    if (transaction.paymentMethod != 'card') {
      throw const BillingRepositoryException(
        BillingRepositoryErrorCode.invalidArgument,
        'Transaction is not a card checkout.',
      );
    }
    _applySuccessfulPayment(
      state,
      transactionId: transactionId.trim(),
      actorUid: session.uid,
    );
  }

  @override
  Future<void> settleVnpayCheckout({
    required AuthSession session,
    required String transactionId,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 130));
    final clanId = _clanIdOf(session);
    final state = _ensureState(clanId: clanId, ownerUid: session.uid);
    final transaction = _findTransaction(state, transactionId);
    if (transaction.paymentMethod != 'vnpay') {
      throw const BillingRepositoryException(
        BillingRepositoryErrorCode.invalidArgument,
        'Transaction is not a VNPay checkout.',
      );
    }
    _applySuccessfulPayment(
      state,
      transactionId: transactionId.trim(),
      actorUid: session.uid,
    );
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
      return const _PricingTier(
        planCode: 'FREE',
        minMembers: 0,
        maxMembers: 10,
        priceVndYear: 0,
        showAds: true,
      );
    }
    if (memberCount <= 200) {
      return const _PricingTier(
        planCode: 'BASE',
        minMembers: 11,
        maxMembers: 200,
        priceVndYear: 49000,
        showAds: true,
      );
    }
    if (memberCount <= 700) {
      return const _PricingTier(
        planCode: 'PLUS',
        minMembers: 201,
        maxMembers: 700,
        priceVndYear: 89000,
        showAds: false,
      );
    }
    return const _PricingTier(
      planCode: 'PRO',
      minMembers: 701,
      maxMembers: null,
      priceVndYear: 119000,
      showAds: false,
    );
  }

  _PricingTier _resolveTierByPlanCode(String planCode) {
    final normalized = planCode.trim().toUpperCase();
    if (normalized == 'BASE') {
      return const _PricingTier(
        planCode: 'BASE',
        minMembers: 11,
        maxMembers: 200,
        priceVndYear: 49000,
        showAds: true,
      );
    }
    if (normalized == 'PLUS') {
      return const _PricingTier(
        planCode: 'PLUS',
        minMembers: 201,
        maxMembers: 700,
        priceVndYear: 89000,
        showAds: false,
      );
    }
    if (normalized == 'PRO') {
      return const _PricingTier(
        planCode: 'PRO',
        minMembers: 701,
        maxMembers: null,
        priceVndYear: 119000,
        showAds: false,
      );
    }
    return const _PricingTier(
      planCode: 'FREE',
      minMembers: 0,
      maxMembers: 10,
      priceVndYear: 0,
      showAds: true,
    );
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
    return expiresAt.difference(DateTime.now().toUtc()).inDays <= 30;
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
      const _PricingTier(
        planCode: 'FREE',
        minMembers: 0,
        maxMembers: 10,
        priceVndYear: 0,
        showAds: true,
      ),
      const _PricingTier(
        planCode: 'BASE',
        minMembers: 11,
        maxMembers: 200,
        priceVndYear: 49000,
        showAds: true,
      ),
      const _PricingTier(
        planCode: 'PLUS',
        minMembers: 201,
        maxMembers: 700,
        priceVndYear: 89000,
        showAds: false,
      ),
      const _PricingTier(
        planCode: 'PRO',
        minMembers: 701,
        maxMembers: null,
        priceVndYear: 119000,
        showAds: false,
      ),
    ].map((tier) => tier.toPricing()).toList(growable: false);

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
      settings: settings,
      checkoutFlow: const BillingCheckoutFlowConfig(
        qrCheckoutEnabled: false,
        qrImageUrlsByPlan: <String, String>{},
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
      pricingTiers: snapshot.pricingTiers,
      memberCount: snapshot.memberCount,
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
  });

  final String planCode;
  final int minMembers;
  final int? maxMembers;
  final int priceVndYear;
  final bool showAds;

  BillingPlanPricing toPricing() {
    return BillingPlanPricing(
      planCode: planCode,
      minMembers: minMembers,
      maxMembers: maxMembers,
      priceVndYear: priceVndYear,
      vatIncluded: true,
      showAds: showAds,
      adFree: !showAds,
    );
  }
}
