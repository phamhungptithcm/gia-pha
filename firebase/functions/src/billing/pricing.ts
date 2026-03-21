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

const REQUIRED_PLAN_ORDER: ReadonlyArray<BillingPlanCode> = [
  'FREE',
  'BASE',
  'PLUS',
  'PRO',
];

const subscriptionPackagesCollection = db.collection('subscriptionPackages');
const BILLING_PRICING_CACHE_MS = resolvePricingCacheMs();

export let BILLING_PRICING_TIERS: ReadonlyArray<BillingTierPricing> = [
  // Strict mode: pricing must be loaded from Firestore subscriptionPackages.
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

export function setBillingPricingTiersForTesting(
  tiers: Array<BillingTierPricing> | null,
): void {
  if (tiers == null) {
    BILLING_PRICING_TIERS = [];
    pricingLastLoadedAtMs = 0;
    return;
  }
  const byPlan = new Map<BillingPlanCode, BillingTierPricing>();
  for (const tier of tiers) {
    byPlan.set(tier.planCode, tier);
  }
  const normalized = REQUIRED_PLAN_ORDER.map((planCode) => {
    const tier = byPlan.get(planCode);
    if (tier == null) {
      throw new Error(`Missing testing pricing tier for plan ${planCode}.`);
    }
    return {
      planCode,
      minMembers: normalizeMemberCount(tier.minMembers),
      maxMembers: normalizeNullableMemberCount(
        tier.maxMembers,
        `test:${planCode}.maxMembers`,
      ),
      priceVndYear: readRequiredNonNegativeInt(
        tier.priceVndYear,
        `test:${planCode}.priceVndYear`,
      ),
      vatIncluded: tier.vatIncluded,
      showAds: tier.showAds,
      adFree: tier.adFree,
    };
  });
  if (!isTierStructureValid(normalized)) {
    throw new Error('Testing pricing tiers are invalid.');
  }
  BILLING_PRICING_TIERS = normalized;
  pricingLastLoadedAtMs = Date.now();
}

function getPricingTiersOrThrow(): ReadonlyArray<BillingTierPricing> {
  if (BILLING_PRICING_TIERS.length === 0) {
    throw new Error(
      'Billing pricing catalog is not loaded. Ensure subscriptionPackages contains active FREE/BASE/PLUS/PRO plans and call refreshBillingPricingTiers() before resolving pricing.',
    );
  }
  return BILLING_PRICING_TIERS;
}

export function resolvePlanByMemberCount(memberCountInput: unknown): BillingTierPricing {
  const tiers = getPricingTiersOrThrow();
  const memberCount = normalizeMemberCount(memberCountInput);
  const matched = tiers.find((tier) => {
    const inLowerBound = memberCount >= tier.minMembers;
    const inUpperBound = tier.maxMembers == null || memberCount <= tier.maxMembers;
    return inLowerBound && inUpperBound;
  });
  if (matched == null) {
    throw new Error(
      `No pricing tier matches memberCount=${memberCount}. Check subscriptionPackages tier boundaries.`,
    );
  }
  return matched;
}

export function resolveTierByPlanCodeFromPricing(
  planCode: BillingPlanCode,
): BillingTierPricing {
  const tiers = getPricingTiersOrThrow();
  const matched = tiers.find((tier) => tier.planCode === planCode);
  if (matched == null) {
    throw new Error(
      `No pricing tier found for planCode=${planCode}. Check subscriptionPackages configuration.`,
    );
  }
  return matched;
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
      BILLING_PRICING_TIERS = parsed;
      pricingLastLoadedAtMs = Date.now();
      return BILLING_PRICING_TIERS;
    } catch (error) {
      logWarn('billing pricing refresh failed', {
        error: `${error}`,
      });
      throw error;
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
  return resolveTierByPlanCodeFromPricing(planCode).priceVndYear > 0;
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
  return resolveTierByPlanCodeFromPricing(planCode).showAds;
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
    if (byPlan.has(planCode)) {
      throw new Error(
        `subscriptionPackages has duplicate active pricing docs for plan ${planCode}.`,
      );
    }
    const minMembers = readRequiredNonNegativeInt(
      doc.data.minMembers,
      `${doc.id}.minMembers`,
    );
    const maxMembers = normalizeNullableMemberCount(
      doc.data.maxMembers,
      `${doc.id}.maxMembers`,
    );
    const priceVndYear = readRequiredNonNegativeInt(
      doc.data.priceVndYear,
      `${doc.id}.priceVndYear`,
    );
    const configuredShowAds = readOptionalBoolean(doc.data.showAds);
    const configuredAdFree = readOptionalBoolean(doc.data.adFree);
    if (configuredShowAds == null && configuredAdFree == null) {
      throw new Error(
        `subscriptionPackages doc ${doc.id} must define showAds or adFree.`,
      );
    }
    if (
      configuredShowAds != null &&
      configuredAdFree != null &&
      configuredShowAds === configuredAdFree
    ) {
      throw new Error(
        `subscriptionPackages doc ${doc.id} has conflicting showAds/adFree.`,
      );
    }
    const showAds = configuredShowAds ?? !configuredAdFree;
    const adFree = configuredAdFree ?? !configuredShowAds;
    byPlan.set(planCode, {
      planCode,
      minMembers,
      maxMembers,
      priceVndYear,
      vatIncluded: readRequiredBoolean(doc.data.vatIncluded, `${doc.id}.vatIncluded`),
      showAds,
      adFree,
    });
  }

  const missingPlans = REQUIRED_PLAN_ORDER.filter((planCode) => !byPlan.has(planCode));
  if (missingPlans.length > 0) {
    throw new Error(
      `subscriptionPackages is missing active plans: ${missingPlans.join(', ')}.`,
    );
  }
  const merged = REQUIRED_PLAN_ORDER.map((planCode) => byPlan.get(planCode)!);
  if (!isTierStructureValid(merged)) {
    throw new Error(
      'subscriptionPackages pricing tiers are invalid. Check min/max boundaries and order.',
    );
  }
  return merged;
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

function readOptionalBoolean(value: unknown): boolean | null {
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
  return null;
}

function readRequiredBoolean(value: unknown, fieldPath: string): boolean {
  const parsed = readOptionalBoolean(value);
  if (parsed == null) {
    throw new Error(`subscriptionPackages field ${fieldPath} must be boolean.`);
  }
  return parsed;
}

function readRequiredNonNegativeInt(value: unknown, fieldPath: string): number {
  if (typeof value === 'number' && Number.isFinite(value)) {
    const normalized = Math.trunc(value);
    if (normalized < 0) {
      throw new Error(`subscriptionPackages field ${fieldPath} must be >= 0.`);
    }
    return normalized;
  }
  if (typeof value === 'string') {
    const parsed = Number(value.trim());
    if (Number.isFinite(parsed)) {
      const normalized = Math.trunc(parsed);
      if (normalized < 0) {
        throw new Error(`subscriptionPackages field ${fieldPath} must be >= 0.`);
      }
      return normalized;
    }
  }
  throw new Error(`subscriptionPackages field ${fieldPath} must be a number.`);
}

function readString(value: unknown): string {
  return typeof value === 'string' ? value.trim() : '';
}

function normalizeNullableMemberCount(
  value: unknown,
  fieldPath: string,
): number | null {
  if (value == null) {
    return null;
  }
  if (typeof value === 'number' && Number.isFinite(value)) {
    const normalized = Math.trunc(value);
    if (normalized < 0) {
      throw new Error(`subscriptionPackages field ${fieldPath} must be >= 0 or null.`);
    }
    return normalized;
  }
  if (typeof value === 'string') {
    const trimmed = value.trim().toLowerCase();
    if (trimmed.length === 0 || trimmed === 'null' || trimmed === 'unlimited') {
      return null;
    }
    const parsed = Number(trimmed);
    if (Number.isFinite(parsed)) {
      const normalized = Math.trunc(parsed);
      if (normalized < 0) {
        throw new Error(`subscriptionPackages field ${fieldPath} must be >= 0 or null.`);
      }
      return normalized;
    }
  }
  throw new Error(`subscriptionPackages field ${fieldPath} must be a number or null.`);
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
