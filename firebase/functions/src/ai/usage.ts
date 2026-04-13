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
import { stringOrNull } from "../shared/permissions";

const aiFeatureThrottleCollection = db.collection("aiFeatureThrottle");
const aiMonthlyUsageCollection = db.collection("aiMonthlyUsage");
const clansCollection = db.collection("clans");

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
  const planCode = await resolveAiPlanCodeForClan(input.clanId);
  const quotaCredits = resolveAiMonthlyUsageLimit(planCode);
  const requestCost = resolveAiFeatureUsageCost(input.feature);
  const windowKey = computeAiUsageWindowKey();
  const usageRef = aiMonthlyUsageCollection.doc(`${windowKey}_${input.clanId}`);
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
          clanId: input.clanId,
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
      `Quota AI tháng này của gia phả đã hết cho gói ${planCode}. Hãy chờ sang tháng mới hoặc nâng gói để dùng thêm.`,
      `This genealogy has reached its monthly AI quota for the ${planCode} plan. Wait until next month or upgrade for more usage.`,
    ),
  );
}

export async function loadAiUsageSummaryForClan(
  clanId: string,
): Promise<AiUsageSummary> {
  const planCode = await resolveAiPlanCodeForClan(clanId);
  const quotaCredits = resolveAiMonthlyUsageLimit(planCode);
  const windowKey = computeAiUsageWindowKey();
  const usageSnapshot = await aiMonthlyUsageCollection
    .doc(`${windowKey}_${clanId}`)
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

async function resolveAiPlanCodeForClan(
  clanId: string,
): Promise<BillingPlanCode> {
  try {
    const ownerUid = await resolveBillingOwnerUidForScope(clanId);
    if (ownerUid == null) {
      return "FREE";
    }
    const subscription = await loadSubscription({
      clanId,
      ownerUid,
    });
    if (subscription == null) {
      return "FREE";
    }
    if (!hasActiveAccess(subscription.status)) {
      return "FREE";
    }
    return subscription.planCode;
  } catch (error) {
    logWarn("AI billing plan resolution fell back to FREE", {
      clanId,
      error: error instanceof Error ? error.message : `${error}`,
    });
    return "FREE";
  }
}

async function resolveBillingOwnerUidForScope(
  clanId: string,
): Promise<string | null> {
  if (clanId.startsWith("user_scope__")) {
    const ownerUid = clanId.replace("user_scope__", "").trim();
    return ownerUid.length == 0 ? null : ownerUid;
  }
  return resolveClanOwnerUid(clanId);
}

async function resolveClanOwnerUid(clanId: string): Promise<string | null> {
  const snapshot = await clansCollection.doc(clanId).get();
  if (!snapshot.exists) {
    return null;
  }
  const data = asRecord(snapshot.data());
  const ownerUid = stringOrNull(data["ownerUid"]);
  return ownerUid == null ? null : ownerUid.trim();
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
