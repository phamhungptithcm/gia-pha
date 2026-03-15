import {
  type BillingPlanCode,
  type BillingTierPricing,
  type PaymentMode,
  type SubscriptionStatus,
  canAccessPremiumFeatures,
  shouldShowAds,
} from './pricing';

type NullableDate = Date | null;

export type BillingSubscriptionRecord = {
  id: string;
  clanId: string;
  planCode: BillingPlanCode;
  status: SubscriptionStatus;
  memberCount: number;
  amountVndYear: number;
  vatIncluded: boolean;
  paymentMode: PaymentMode;
  autoRenew: boolean;
  startsAt: NullableDate;
  expiresAt: NullableDate;
  nextPaymentDueAt: NullableDate;
  graceEndsAt: NullableDate;
  lastPaymentMethod: string | null;
  lastTransactionId: string | null;
  updatedAt: NullableDate;
};

export type BillingEntitlement = {
  planCode: BillingPlanCode;
  status: SubscriptionStatus;
  showAds: boolean;
  adFree: boolean;
  hasPremiumAccess: boolean;
  expiresAtIso: string | null;
  nextPaymentDueAtIso: string | null;
};

export function normalizeSubscriptionStatus({
  status,
  expiresAt,
  graceEndsAt,
  now = new Date(),
}: {
  status: SubscriptionStatus;
  expiresAt: NullableDate;
  graceEndsAt: NullableDate;
  now?: Date;
}): SubscriptionStatus {
  if (status === 'canceled') {
    return 'canceled';
  }
  if (status === 'pending_payment') {
    return 'pending_payment';
  }

  if (expiresAt == null) {
    return status;
  }
  if (expiresAt.getTime() > now.getTime()) {
    return 'active';
  }
  if (graceEndsAt != null && graceEndsAt.getTime() > now.getTime()) {
    return 'grace_period';
  }
  return 'expired';
}

export function buildEntitlement({
  planCode,
  status,
  expiresAt,
  nextPaymentDueAt,
}: {
  planCode: BillingPlanCode;
  status: SubscriptionStatus;
  expiresAt: NullableDate;
  nextPaymentDueAt: NullableDate;
}): BillingEntitlement {
  const showAds = shouldShowAds(planCode, status);
  return {
    planCode,
    status,
    showAds,
    adFree: !showAds,
    hasPremiumAccess: canAccessPremiumFeatures(planCode, status),
    expiresAtIso: expiresAt?.toISOString() ?? null,
    nextPaymentDueAtIso: nextPaymentDueAt?.toISOString() ?? null,
  };
}

export function createSubscriptionDraft({
  clanId,
  tier,
  memberCount,
  paymentMode,
  autoRenew,
  startsAt,
  expiresAt,
  status = 'active',
  now = new Date(),
}: {
  clanId: string;
  tier: BillingTierPricing;
  memberCount: number;
  paymentMode: PaymentMode;
  autoRenew: boolean;
  startsAt: NullableDate;
  expiresAt: NullableDate;
  status?: SubscriptionStatus;
  now?: Date;
}): BillingSubscriptionRecord {
  return {
    id: clanId,
    clanId,
    planCode: tier.planCode,
    status,
    memberCount,
    amountVndYear: tier.priceVndYear,
    vatIncluded: tier.vatIncluded,
    paymentMode,
    autoRenew,
    startsAt,
    expiresAt,
    nextPaymentDueAt: expiresAt,
    graceEndsAt: null,
    lastPaymentMethod: null,
    lastTransactionId: null,
    updatedAt: now,
  };
}
