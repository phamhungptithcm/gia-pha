class BillingWorkspaceSnapshot {
  const BillingWorkspaceSnapshot({
    required this.clanId,
    required this.subscription,
    required this.entitlement,
    required this.settings,
    required this.pricingTiers,
    required this.memberCount,
    required this.transactions,
    required this.invoices,
    required this.auditLogs,
  });

  final String clanId;
  final BillingSubscription subscription;
  final BillingEntitlement entitlement;
  final BillingSettings settings;
  final List<BillingPlanPricing> pricingTiers;
  final int memberCount;
  final List<BillingPaymentTransaction> transactions;
  final List<BillingInvoice> invoices;
  final List<BillingAuditLog> auditLogs;
}

class BillingSubscription {
  const BillingSubscription({
    required this.id,
    required this.clanId,
    required this.planCode,
    required this.status,
    required this.memberCount,
    required this.amountVndYear,
    required this.vatIncluded,
    required this.paymentMode,
    required this.autoRenew,
    required this.startsAtIso,
    required this.expiresAtIso,
    required this.nextPaymentDueAtIso,
    required this.graceEndsAtIso,
    required this.lastPaymentMethod,
    required this.lastTransactionId,
    required this.updatedAtIso,
  });

  final String id;
  final String clanId;
  final String planCode;
  final String status;
  final int memberCount;
  final int amountVndYear;
  final bool vatIncluded;
  final String paymentMode;
  final bool autoRenew;
  final String? startsAtIso;
  final String? expiresAtIso;
  final String? nextPaymentDueAtIso;
  final String? graceEndsAtIso;
  final String? lastPaymentMethod;
  final String? lastTransactionId;
  final String? updatedAtIso;
}

class BillingEntitlement {
  const BillingEntitlement({
    required this.planCode,
    required this.status,
    required this.showAds,
    required this.adFree,
    required this.hasPremiumAccess,
    required this.expiresAtIso,
    required this.nextPaymentDueAtIso,
  });

  final String planCode;
  final String status;
  final bool showAds;
  final bool adFree;
  final bool hasPremiumAccess;
  final String? expiresAtIso;
  final String? nextPaymentDueAtIso;
}

class BillingSettings {
  const BillingSettings({
    required this.id,
    required this.clanId,
    required this.paymentMode,
    required this.autoRenew,
    required this.reminderDaysBefore,
    required this.updatedAtIso,
  });

  final String id;
  final String clanId;
  final String paymentMode;
  final bool autoRenew;
  final List<int> reminderDaysBefore;
  final String? updatedAtIso;
}

class BillingPlanPricing {
  const BillingPlanPricing({
    required this.planCode,
    required this.minMembers,
    required this.maxMembers,
    required this.priceVndYear,
    required this.vatIncluded,
    required this.showAds,
    required this.adFree,
  });

  final String planCode;
  final int minMembers;
  final int? maxMembers;
  final int priceVndYear;
  final bool vatIncluded;
  final bool showAds;
  final bool adFree;
}

class BillingPaymentTransaction {
  const BillingPaymentTransaction({
    required this.id,
    required this.clanId,
    required this.subscriptionId,
    required this.invoiceId,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.planCode,
    required this.memberCount,
    required this.amountVnd,
    required this.vatIncluded,
    required this.currency,
    required this.gatewayReference,
    required this.createdAtIso,
    required this.paidAtIso,
    required this.failedAtIso,
  });

  final String id;
  final String clanId;
  final String subscriptionId;
  final String invoiceId;
  final String paymentMethod;
  final String paymentStatus;
  final String planCode;
  final int memberCount;
  final int amountVnd;
  final bool vatIncluded;
  final String currency;
  final String? gatewayReference;
  final String? createdAtIso;
  final String? paidAtIso;
  final String? failedAtIso;
}

class BillingInvoice {
  const BillingInvoice({
    required this.id,
    required this.clanId,
    required this.subscriptionId,
    required this.transactionId,
    required this.planCode,
    required this.amountVnd,
    required this.vatIncluded,
    required this.currency,
    required this.status,
    required this.periodStartIso,
    required this.periodEndIso,
    required this.issuedAtIso,
    required this.paidAtIso,
  });

  final String id;
  final String clanId;
  final String subscriptionId;
  final String transactionId;
  final String planCode;
  final int amountVnd;
  final bool vatIncluded;
  final String currency;
  final String status;
  final String? periodStartIso;
  final String? periodEndIso;
  final String? issuedAtIso;
  final String? paidAtIso;
}

class BillingAuditLog {
  const BillingAuditLog({
    required this.id,
    required this.clanId,
    required this.actorUid,
    required this.action,
    required this.entityType,
    required this.entityId,
    required this.createdAtIso,
  });

  final String id;
  final String clanId;
  final String? actorUid;
  final String action;
  final String entityType;
  final String entityId;
  final String? createdAtIso;
}

class BillingCheckoutResult {
  const BillingCheckoutResult({
    required this.clanId,
    required this.paymentMethod,
    required this.planCode,
    required this.amountVnd,
    required this.vatIncluded,
    required this.transactionId,
    required this.invoiceId,
    required this.checkoutUrl,
    required this.requiresManualConfirmation,
    required this.subscription,
    required this.entitlement,
  });

  final String clanId;
  final String paymentMethod;
  final String planCode;
  final int amountVnd;
  final bool vatIncluded;
  final String transactionId;
  final String invoiceId;
  final String checkoutUrl;
  final bool requiresManualConfirmation;
  final BillingSubscription subscription;
  final BillingEntitlement entitlement;
}
