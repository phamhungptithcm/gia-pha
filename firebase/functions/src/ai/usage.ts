import { FieldValue } from "firebase-admin/firestore";
import { HttpsError } from "firebase-functions/v2/https";

import {
  AI_FEATURE_COOLDOWN_MS,
  AI_USAGE_LIMIT_BASE,
  AI_USAGE_LIMIT_FREE,
  AI_USAGE_LIMIT_PLUS,
  AI_USAGE_LIMIT_PRO,
} from "../config/runtime";
import { type BillingPlanCode, hasActiveAccess } from "../billing/pricing";
import { loadSubscription } from "../billing/store";
import { db } from "../shared/firestore";
import { logWarn } from "../shared/logger";

const aiFeatureThrottleCollection = db.collection("aiFeatureThrottle");
const aiMonthlyUsageCollection = db.collection("aiMonthlyUsage");

export type AiFeatureName =
  | "profile_review"
  | "event_copy"
  | "duplicate_genealogy"
  | "app_assistant_chat";

export type AiUsageSummary = {
  windowKey: string;
  planCode: BillingPlanCode;
  quotaCredits: number;
  usedCredits: number;
  remainingCredits: number;
  totalRequests: number;
  featureCounts: Record<string, number>;
  featureCredits: Record<string, number>;
};

const AI_MONTHLY_USAGE_LIMITS: Record<BillingPlanCode, number> = {
  FREE: AI_USAGE_LIMIT_FREE,
  BASE: AI_USAGE_LIMIT_BASE,
  PLUS: AI_USAGE_LIMIT_PLUS,
  PRO: AI_USAGE_LIMIT_PRO,
};

const AI_FEATURE_USAGE_COST: Record<AiFeatureName, number> = {
  profile_review: 1,
  event_copy: 1,
  duplicate_genealogy: 1,
  app_assistant_chat: 2,
};

export function computeAiFeatureThrottleRemainingMs(input: {
  lastRequestedAtMs: number;
  nowMs: number;
  cooldownMs: number;
}): number {
  if (input.lastRequestedAtMs <= 0) {
    return 0;
  }
  return Math.max(
    0,
    input.cooldownMs - Math.max(0, input.nowMs - input.lastRequestedAtMs),
  );
}

export async function enforceAiFeatureThrottle(input: {
  uid: string;
  clanId: string;
  feature: AiFeatureName;
  locale: string;
  traceId: string;
}): Promise<void> {
  const throttleRef = aiFeatureThrottleCollection.doc(
    `${input.uid}_${input.feature}`,
  );
  const nowMs = Date.now();
  const remainingMs = await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(throttleRef);
    const state = asRecord(snapshot.data());
    const lastRequestedAtMs = readPositiveInt(state["lastRequestedAtMs"]);
    const pendingRemainingMs = computeAiFeatureThrottleRemainingMs({
      lastRequestedAtMs,
      nowMs,
      cooldownMs: AI_FEATURE_COOLDOWN_MS,
    });
    if (pendingRemainingMs > 0) {
      return pendingRemainingMs;
    }

    transaction.set(
      throttleRef,
      {
        id: throttleRef.id,
        uid: input.uid,
        clanId: input.clanId,
        feature: input.feature,
        lastRequestedAtMs: nowMs,
        updatedAt: FieldValue.serverTimestamp(),
        createdAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
    return 0;
  });

  if (remainingMs <= 0) {
    return;
  }

  logWarn("AI callable throttled", {
    clanId: input.clanId,
    uid: input.uid,
    feature: input.feature,
    locale: input.locale,
    traceId: input.traceId,
    remaining_ms: remainingMs,
  });
  throw new HttpsError(
    "resource-exhausted",
    localized(
      input.locale,
      `Bạn vừa dùng tính năng này. Hãy thử lại sau khoảng ${Math.ceil(
        remainingMs / 1000,
      )} giây.`,
      `You just used this feature. Try again in about ${Math.ceil(
        remainingMs / 1000,
      )} seconds.`,
    ),
  );
}

export function resolveAiMonthlyUsageLimit(planCode: BillingPlanCode): number {
  return AI_MONTHLY_USAGE_LIMITS[planCode];
}

export function resolveAiFeatureUsageCost(feature: AiFeatureName): number {
  return AI_FEATURE_USAGE_COST[feature];
}

export function computeAiUsageWindowKey(now: Date = new Date()): string {
  const year = now.getUTCFullYear();
  const month = `${now.getUTCMonth() + 1}`.padStart(2, "0");
  return `${year}-${month}`;
}

export function resolveAiUsageScopeId(uid: string): string {
  return `user_scope__${uid.trim()}`;
}

export function buildAiUsageDocumentId(input: {
  windowKey: string;
  uid: string;
}): string {
  return `${input.windowKey}_${resolveAiUsageScopeId(input.uid)}`;
}

export function computeAiQuotaRemainingCredits(input: {
  usedCredits: number;
  quotaCredits: number;
}): number {
  if (input.quotaCredits <= 0) {
    return 0;
  }
  return Math.max(0, input.quotaCredits - Math.max(0, input.usedCredits));
}

export async function enforceAiPlanUsageLimit(input: {
  uid: string;
  clanId: string;
  feature: AiFeatureName;
  locale: string;
  traceId: string;
}): Promise<void> {
  const planCode = await resolveAiPlanCodeForActor({
    uid: input.uid,
    clanId: input.clanId,
  });
  const quotaCredits = resolveAiMonthlyUsageLimit(planCode);
  const requestCost = resolveAiFeatureUsageCost(input.feature);
  const windowKey = computeAiUsageWindowKey();
  const usageScopeId = resolveAiUsageScopeId(input.uid);
  const usageRef = aiMonthlyUsageCollection.doc(
    buildAiUsageDocumentId({
      windowKey,
      uid: input.uid,
    }),
  );
  const nowMs = Date.now();

  const state = await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(usageRef);
    const usageData = asRecord(snapshot.data());
    const usedCredits = readPositiveInt(usageData["totalCredits"]);
    const usedRequests = readPositiveInt(usageData["totalRequests"]);
    const remainingCredits = computeAiQuotaRemainingCredits({
      usedCredits,
      quotaCredits,
    });
    if (remainingCredits < requestCost) {
      return {
        blocked: true,
        usedCredits,
        usedRequests,
      };
    }

    if (!snapshot.exists) {
      transaction.set(
        usageRef,
        {
          id: usageRef.id,
          windowKey,
          billingScopeId: usageScopeId,
          ownerUid: input.uid,
          lastRequestedClanId: input.clanId,
          planCode,
          quotaCredits,
          totalRequests: 1,
          totalCredits: requestCost,
          featureCounts: {
            [input.feature]: 1,
          },
          featureCredits: {
            [input.feature]: requestCost,
          },
          lastRequestedByUid: input.uid,
          lastFeature: input.feature,
          lastRequestedAtMs: nowMs,
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
    } else {
      transaction.update(usageRef, {
        planCode,
        quotaCredits,
        totalRequests: FieldValue.increment(1),
        totalCredits: FieldValue.increment(requestCost),
        [`featureCounts.${input.feature}`]: FieldValue.increment(1),
        [`featureCredits.${input.feature}`]: FieldValue.increment(requestCost),
        lastRequestedByUid: input.uid,
        lastRequestedClanId: input.clanId,
        lastFeature: input.feature,
        lastRequestedAtMs: nowMs,
        updatedAt: FieldValue.serverTimestamp(),
      });
    }

    return {
      blocked: false,
      usedCredits,
      usedRequests,
    };
  });

  if (!state.blocked) {
    return;
  }

  logWarn("AI callable quota exceeded", {
    clanId: input.clanId,
    billingScopeId: usageScopeId,
    uid: input.uid,
    feature: input.feature,
    locale: input.locale,
    traceId: input.traceId,
    planCode,
    quotaCredits,
    usedCredits: state.usedCredits,
    usedRequests: state.usedRequests,
    requestCost,
    windowKey,
  });

  throw new HttpsError(
    "resource-exhausted",
    localized(
      input.locale,
      `Quota AI tháng này của bạn đã hết cho gói ${planCode}. Hãy chờ sang tháng mới hoặc nâng gói để dùng thêm.`,
      `You have reached your monthly AI quota for the ${planCode} plan. Wait until next month or upgrade for more usage.`,
    ),
  );
}

export async function loadAiUsageSummaryForUser(
  uid: string,
  options?: {
    clanId?: string;
  },
): Promise<AiUsageSummary> {
  const planCode = await resolveAiPlanCodeForActor({
    uid,
    clanId: options?.clanId ?? "",
  });
  const quotaCredits = resolveAiMonthlyUsageLimit(planCode);
  const windowKey = computeAiUsageWindowKey();
  const usageSnapshot = await aiMonthlyUsageCollection
    .doc(
      buildAiUsageDocumentId({
        windowKey,
        uid,
      }),
    )
    .get();
  const usageData = asRecord(usageSnapshot.data());
  const usedCredits = readPositiveInt(usageData["totalCredits"]);
  const totalRequests = readPositiveInt(usageData["totalRequests"]);
  const remainingCredits = computeAiQuotaRemainingCredits({
    usedCredits,
    quotaCredits,
  });
  return {
    windowKey,
    planCode,
    quotaCredits,
    usedCredits,
    remainingCredits,
    totalRequests,
    featureCounts: readNestedPositiveIntMap(usageData["featureCounts"]),
    featureCredits: readNestedPositiveIntMap(usageData["featureCredits"]),
  };
}

async function resolveAiPlanCodeForActor(input: {
  uid: string;
  clanId: string;
}): Promise<BillingPlanCode> {
  try {
    const personalScopeId = resolveAiUsageScopeId(input.uid);
    const personalPlanCode = await loadActiveSubscriptionPlanCode({
      clanId: personalScopeId,
      ownerUid: input.uid,
    });
    if (personalPlanCode != null) {
      return personalPlanCode;
    }

    const currentClanId = input.clanId.trim();
    if (currentClanId.length > 0 && currentClanId !== personalScopeId) {
      const legacyClanPlanCode = await loadActiveSubscriptionPlanCode({
        clanId: currentClanId,
        ownerUid: input.uid,
      });
      if (legacyClanPlanCode != null) {
        return legacyClanPlanCode;
      }
    }

    return "FREE";
  } catch (error) {
    logWarn("AI billing plan resolution fell back to FREE", {
      uid: input.uid,
      clanId: input.clanId,
      error: error instanceof Error ? error.message : `${error}`,
    });
    return "FREE";
  }
}

async function loadActiveSubscriptionPlanCode(input: {
  clanId: string;
  ownerUid: string;
}): Promise<BillingPlanCode | null> {
  const subscription = await loadSubscription({
    clanId: input.clanId,
    ownerUid: input.ownerUid,
  });
  if (subscription == null) {
    return null;
  }
  if (!hasActiveAccess(subscription.status)) {
    return null;
  }
  return subscription.planCode;
}

function localized(locale: string, vi: string, en: string): string {
  return locale.trim().toLowerCase().startsWith("vi") ? vi : en;
}

function asRecord(value: unknown): Record<string, unknown> {
  if (value == null || typeof value !== "object" || Array.isArray(value)) {
    return {};
  }
  return value as Record<string, unknown>;
}

function toNumber(value: unknown): number {
  if (typeof value === "number" && Number.isFinite(value)) {
    return value;
  }
  if (typeof value === "string") {
    const parsed = Number.parseFloat(value);
    if (Number.isFinite(parsed)) {
      return parsed;
    }
  }
  return 0;
}

function readPositiveInt(value: unknown): number {
  const parsed = toNumber(value);
  if (!Number.isFinite(parsed) || parsed <= 0) {
    return 0;
  }
  return Math.round(parsed);
}

function readNestedPositiveIntMap(value: unknown): Record<string, number> {
  const record = asRecord(value);
  const output: Record<string, number> = {};
  for (const [key, entry] of Object.entries(record)) {
    const normalizedKey = key.trim();
    if (normalizedKey.length === 0) {
      continue;
    }
    const parsed = readPositiveInt(entry);
    if (parsed <= 0) {
      continue;
    }
    output[normalizedKey] = parsed;
  }
  return output;
}
