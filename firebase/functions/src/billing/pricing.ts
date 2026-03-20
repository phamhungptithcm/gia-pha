import { db } from '../shared/firestore';
import { logWarn } from '../shared/logger';

export type BillingPlanCode = 'FREE' | 'BASE' | 'PLUS' | 'PRO';

export type SubscriptionStatus =
  | 'active'
  | 'grace_period'
  | 'expired'
  | 'pending_payment'
  | 'canceled';

export type PaymentMode = 'auto_renew' | 'manual';
export type PaymentMethod = 'card' | 'apple_iap' | 'google_play';
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

const DEFAULT_BILLING_PRICING_TIERS: ReadonlyArray<BillingTierPricing> = [
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

const subscriptionPackagesCollection = db.collection('subscriptionPackages');
const BILLING_PRICING_CACHE_MS = resolvePricingCacheMs();

export let BILLING_PRICING_TIERS: ReadonlyArray<BillingTierPricing> = [
  ...DEFAULT_BILLING_PRICING_TIERS,
];

let pricingLastLoadedAtMs = 0;
let pricingRefreshInFlight: Promise<ReadonlyArray<BillingTierPricing>> | null = null;

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

export async function refreshBillingPricingTiers({
  force = false,
}: {
  force?: boolean;
} = {}): Promise<ReadonlyArray<BillingTierPricing>> {
  const now = Date.now();
  if (
    !force &&
    pricingLastLoadedAtMs > 0 &&
    now - pricingLastLoadedAtMs <= BILLING_PRICING_CACHE_MS
  ) {
    return BILLING_PRICING_TIERS;
  }
  if (pricingRefreshInFlight != null) {
    return pricingRefreshInFlight;
  }
  pricingRefreshInFlight = (async () => {
    try {
      const snapshot = await subscriptionPackagesCollection.limit(20).get();
      const parsed = normalizePricingDocs(
        snapshot.docs.map((doc) => ({
          id: doc.id,
          data: doc.data() ?? {},
        })),
      );
      if (parsed.length === 0) {
        return BILLING_PRICING_TIERS;
      }
      BILLING_PRICING_TIERS = parsed;
      pricingLastLoadedAtMs = Date.now();
      return BILLING_PRICING_TIERS;
    } catch (error) {
      logWarn('billing pricing refresh failed, using in-memory tiers', {
        error: `${error}`,
      });
      return BILLING_PRICING_TIERS;
    } finally {
      pricingRefreshInFlight = null;
    }
  })();
  return pricingRefreshInFlight;
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

function normalizePricingDocs(
  docs: Array<{ id: string; data: Record<string, unknown> }>,
): Array<BillingTierPricing> {
  const byPlan = new Map<BillingPlanCode, BillingTierPricing>();
  for (const doc of docs) {
    const planCode = normalizePlanCode(
      readString(doc.data.planCode) || readString(doc.data.id) || doc.id,
    );
    if (planCode == null) {
      continue;
    }
    const isActive = readBoolean(doc.data.isActive, true);
    if (!isActive) {
      continue;
    }
    const fallback = defaultTierForPlanCode(planCode);
    const minMembers = normalizeMemberCount(
      readNumber(doc.data.minMembers, fallback.minMembers),
    );
    const maxMembers = normalizeNullableMemberCount(
      doc.data.maxMembers,
      fallback.maxMembers,
    );
    const priceVndYear = normalizeMemberCount(
      readNumber(doc.data.priceVndYear, fallback.priceVndYear),
    );
    const configuredShowAds = readBoolean(doc.data.showAds, fallback.showAds);
    const configuredAdFree = readBoolean(doc.data.adFree, fallback.adFree);
    const adFree = configuredAdFree || !configuredShowAds;
    const showAds = !adFree;
    byPlan.set(planCode, {
      planCode,
      minMembers,
      maxMembers,
      priceVndYear,
      vatIncluded: readBoolean(doc.data.vatIncluded, fallback.vatIncluded),
      showAds,
      adFree,
    });
  }

  const merged = (['FREE', 'BASE', 'PLUS', 'PRO'] as const).map((planCode) => {
    return byPlan.get(planCode) ?? defaultTierForPlanCode(planCode);
  });
  if (!isTierStructureValid(merged)) {
    logWarn('subscriptionPackages pricing tiers are invalid; fallback to defaults', {
      tiers: merged,
    });
    return [...DEFAULT_BILLING_PRICING_TIERS];
  }
  return merged;
}

function defaultTierForPlanCode(planCode: BillingPlanCode): BillingTierPricing {
  const matched = DEFAULT_BILLING_PRICING_TIERS.find((tier) => tier.planCode === planCode);
  return (
    matched ?? {
      planCode,
      minMembers: 0,
      maxMembers: null,
      priceVndYear: 0,
      vatIncluded: true,
      showAds: true,
      adFree: false,
    }
  );
}

function isTierStructureValid(tiers: Array<BillingTierPricing>): boolean {
  if (tiers.length === 0) {
    return false;
  }
  let previousMax: number | null = null;
  for (const tier of tiers) {
    if (tier.minMembers < 0 || tier.priceVndYear < 0) {
      return false;
    }
    if (tier.maxMembers != null && tier.maxMembers < tier.minMembers) {
      return false;
    }
    if (previousMax != null && tier.minMembers <= previousMax) {
      return false;
    }
    previousMax = tier.maxMembers;
  }
  return true;
}

function normalizePlanCode(value: string): BillingPlanCode | null {
  const normalized = value.trim().toUpperCase();
  if (
    normalized === 'FREE' ||
    normalized === 'BASE' ||
    normalized === 'PLUS' ||
    normalized === 'PRO'
  ) {
    return normalized;
  }
  return null;
}

function readBoolean(value: unknown, fallback: boolean): boolean {
  if (typeof value === 'boolean') {
    return value;
  }
  if (typeof value === 'string') {
    const normalized = value.trim().toLowerCase();
    if (normalized === 'true' || normalized === '1' || normalized === 'yes') {
      return true;
    }
    if (normalized === 'false' || normalized === '0' || normalized === 'no') {
      return false;
    }
  }
  return fallback;
}

function readNumber(value: unknown, fallback: number): number {
  if (typeof value === 'number' && Number.isFinite(value)) {
    return Math.trunc(value);
  }
  if (typeof value === 'string') {
    const parsed = Number(value);
    if (Number.isFinite(parsed)) {
      return Math.trunc(parsed);
    }
  }
  return fallback;
}

function readString(value: unknown): string {
  return typeof value === 'string' ? value.trim() : '';
}

function normalizeNullableMemberCount(
  value: unknown,
  fallback: number | null,
): number | null {
  if (value == null) {
    return fallback;
  }
  if (typeof value === 'number' && Number.isFinite(value)) {
    return Math.max(0, Math.trunc(value));
  }
  if (typeof value === 'string') {
    const trimmed = value.trim().toLowerCase();
    if (trimmed.length === 0 || trimmed === 'null' || trimmed === 'unlimited') {
      return null;
    }
    const parsed = Number(trimmed);
    if (Number.isFinite(parsed)) {
      return Math.max(0, Math.trunc(parsed));
    }
  }
  return fallback;
}

function resolvePricingCacheMs(): number {
  const raw = process.env.BILLING_PRICING_CACHE_MS;
  if (typeof raw !== 'string' || raw.trim().length === 0) {
    return 2 * 60 * 1000;
  }
  const parsed = Number.parseInt(raw.trim(), 10);
  if (!Number.isFinite(parsed)) {
    return 2 * 60 * 1000;
  }
  return Math.max(10_000, Math.min(15 * 60 * 1000, parsed));
}
