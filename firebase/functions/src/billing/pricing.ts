export type BillingPlanCode = 'FREE' | 'BASE' | 'PLUS' | 'PRO';

export type SubscriptionStatus =
  | 'active'
  | 'grace_period'
  | 'expired'
  | 'pending_payment'
  | 'canceled';

export type PaymentMode = 'auto_renew' | 'manual';
export type PaymentMethod = 'card' | 'vnpay';
export type PaymentStatus =
  | 'created'
  | 'pending'
  | 'succeeded'
  | 'failed'
  | 'canceled';

export type BillingTierPricing = {
  planCode: BillingPlanCode;
  minMembers: number;
  maxMembers: number | null;
  priceVndYear: number;
  vatIncluded: boolean;
  showAds: boolean;
  adFree: boolean;
};

export const BILLING_PRICING_TIERS: ReadonlyArray<BillingTierPricing> = [
  {
    planCode: 'FREE',
    minMembers: 0,
    maxMembers: 10,
    priceVndYear: 0,
    vatIncluded: true,
    showAds: true,
    adFree: false,
  },
  {
    planCode: 'BASE',
    minMembers: 11,
    maxMembers: 200,
    priceVndYear: 49_000,
    vatIncluded: true,
    showAds: true,
    adFree: false,
  },
  {
    planCode: 'PLUS',
    minMembers: 201,
    maxMembers: 700,
    priceVndYear: 89_000,
    vatIncluded: true,
    showAds: false,
    adFree: true,
  },
  {
    planCode: 'PRO',
    minMembers: 701,
    maxMembers: null,
    priceVndYear: 119_000,
    vatIncluded: true,
    showAds: false,
    adFree: true,
  },
];

const PLAN_RANK: Record<BillingPlanCode, number> = {
  FREE: 0,
  BASE: 1,
  PLUS: 2,
  PRO: 3,
};

export function normalizeMemberCount(value: unknown): number {
  if (typeof value === 'number' && Number.isFinite(value)) {
    return Math.max(0, Math.trunc(value));
  }
  if (typeof value === 'string') {
    const parsed = Number(value);
    if (Number.isFinite(parsed)) {
      return Math.max(0, Math.trunc(parsed));
    }
  }
  return 0;
}

export function resolvePlanByMemberCount(memberCountInput: unknown): BillingTierPricing {
  const memberCount = normalizeMemberCount(memberCountInput);
  const matched = BILLING_PRICING_TIERS.find((tier) => {
    const inLowerBound = memberCount >= tier.minMembers;
    const inUpperBound = tier.maxMembers == null || memberCount <= tier.maxMembers;
    return inLowerBound && inUpperBound;
  });

  return matched ?? BILLING_PRICING_TIERS[BILLING_PRICING_TIERS.length - 1];
}

export function rankPlanCode(planCode: BillingPlanCode): number {
  return PLAN_RANK[planCode] ?? 0;
}

export function resolveEffectivePlanCode({
  memberCount,
  currentPlanCode,
  requestedPlanCode,
}: {
  memberCount: number;
  currentPlanCode?: BillingPlanCode | null;
  requestedPlanCode?: BillingPlanCode | null;
}): BillingPlanCode {
  const minimumPlanCode = resolvePlanByMemberCount(memberCount).planCode;
  const baselinePlanCode =
    currentPlanCode != null &&
        rankPlanCode(currentPlanCode) >= rankPlanCode(minimumPlanCode)
      ? currentPlanCode
      : minimumPlanCode;

  if (requestedPlanCode == null) {
    return baselinePlanCode;
  }
  if (rankPlanCode(requestedPlanCode) < rankPlanCode(minimumPlanCode)) {
    throw new Error(
      `requestedPlanCode ${requestedPlanCode} is below minimum ${minimumPlanCode}.`,
    );
  }
  return requestedPlanCode;
}

export function isPaidPlan(planCode: BillingPlanCode): boolean {
  return planCode !== 'FREE';
}

export function hasActiveAccess(status: SubscriptionStatus): boolean {
  return status === 'active' || status === 'grace_period';
}

export function canAccessPremiumFeatures(
  planCode: BillingPlanCode,
  status: SubscriptionStatus,
): boolean {
  if (!hasActiveAccess(status)) {
    return false;
  }
  return isPaidPlan(planCode);
}

export function shouldShowAds(
  planCode: BillingPlanCode,
  status: SubscriptionStatus,
): boolean {
  if (!hasActiveAccess(status)) {
    return true;
  }
  return planCode === 'FREE' || planCode === 'BASE';
}

export function computeRenewalWindow({
  now = new Date(),
  years = 1,
}: {
  now?: Date;
  years?: number;
}): { startsAt: Date; expiresAt: Date } {
  const startsAt = new Date(now);
  const expiresAt = new Date(now);
  expiresAt.setUTCFullYear(expiresAt.getUTCFullYear() + years);
  return { startsAt, expiresAt };
}
