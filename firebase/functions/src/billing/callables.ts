import { HttpsError, onCall } from "firebase-functions/v2/https";

import {
  APP_REGION,
  CALLABLE_ENFORCE_APP_CHECK,
} from "../config/runtime";
import {
  loadBillingRuntimeConfig,
} from "../config/runtime-overrides";
import {
  applyPaymentResult,
  cancelStalePendingTransactionsRun,
  buildEntitlementFromSubscription,
  createPendingCheckout,
  ensureSubscriptionForClan,
  resolveOwnerBillingPolicy,
  resolveBillingAudienceMemberIds,
  upsertBillingSettings,
  writeBillingAuditLog,
  resolveTierByPlanCode,
} from "./store";
import {
  BILLING_PRICING_TIERS,
  refreshBillingPricingTiers,
  type BillingPlanCode,
  type PaymentMethod,
  type PaymentMode,
} from "./pricing";
import {
  refreshIapProductCatalogFromFirestore,
  normalizeIapPlatform,
  resolvePlanCodeForIapProductId,
  resolveStoreProductIdsByPlan,
  verifyInAppStorePurchase,
  type IapPlatform,
} from "./iap-verification";
import { requireAuth } from "../shared/errors";
import { FieldValue } from "firebase-admin/firestore";
import { db } from "../shared/firestore";
import { notifyMembers } from "../notifications/push-delivery";
import {
  ensureAnyRole,
  ensureClaimedSession,
  ensureClanAccess,
  tokenClanIds,
  type AuthToken,
} from "../shared/permissions";

const subscriptionsCollection = db.collection("subscriptions");
const clansCollection = db.collection("clans");
const membersCollection = db.collection("members");
const usersCollection = db.collection("users");
const transactionsCollection = db.collection("paymentTransactions");
const invoicesCollection = db.collection("subscriptionInvoices");
const billingAuditLogsCollection = db.collection("billingAuditLogs");
const iapPurchaseVerificationsCollection = db.collection(
  "iapPurchaseVerifications",
);
const iapPurchaseLineagesCollection = db.collection("iapPurchaseLineages");
const BILLING_ADMIN_ROLES = [
  "SUPER_ADMIN",
  "CLAN_ADMIN",
  "BRANCH_ADMIN",
  "CLAN_OWNER",
  "CLAN_LEADER",
  "VICE_LEADER",
  "SUPPORTER_OF_LEADER",
];
const APP_CHECK_CALLABLE_OPTIONS = {
  region: APP_REGION,
  enforceAppCheck: CALLABLE_ENFORCE_APP_CHECK,
} as const;

function scopedBillingDocId(clanId: string, ownerUid: string): string {
  return `${clanId}__${ownerUid}`;
}

function personalBillingScopeId(uid: string): string {
  return `user_scope__${uid.trim()}`;
}

function ownerBillingDocId(ownerUid: string): string {
  const ownerScopeId = personalBillingScopeId(ownerUid);
  return scopedBillingDocId(ownerScopeId, ownerUid);
}

function isPersonalBillingScope(scopeId: string, uid: string): boolean {
  return scopeId.trim() === personalBillingScopeId(uid);
}

function resolveBillingScopeId(
  uid: string,
  token: AuthToken,
  data: unknown,
): string {
  const clanIds = tokenClanIds(token);
  const dataClanId = readString(data, "clanId");
  const dataOwnerUid = readString(data, "ownerUid");
  const personalScopeId = personalBillingScopeId(uid);
  if (dataOwnerUid != null && dataOwnerUid === uid) {
    return personalScopeId;
  }
  if (dataClanId != null && dataClanId.length > 0) {
    if (dataClanId === personalScopeId) {
      return personalScopeId;
    }
    if (!clanIds.includes(dataClanId)) {
      throw new HttpsError(
        "permission-denied",
        "This session does not have access to the requested clan.",
      );
    }
    return dataClanId;
  }
  if (clanIds.length > 0) {
    return clanIds[0];
  }
  return personalScopeId;
}

function ensureBillingScopeAccess({
  uid,
  token,
  scopeId,
}: {
  uid: string;
  token: AuthToken;
  scopeId: string;
}): void {
  if (isPersonalBillingScope(scopeId, uid)) {
    return;
  }
  ensureClaimedSession(token);
  ensureClanAccess(token, scopeId);
}

type BillingScopeContext = {
  clanId: string;
  ownerUid: string;
  ownerDisplayName: string | null;
  clanStatus: string;
  viewerIsOwner: boolean;
};

async function resolveBillingScopeContext({
  uid,
  token,
  data,
  requireManageRole = false,
  requireOwnerMutationAccess = false,
}: {
  uid: string;
  token: AuthToken;
  data: unknown;
  requireManageRole?: boolean;
  requireOwnerMutationAccess?: boolean;
}): Promise<BillingScopeContext> {
  const scopeId = resolveBillingScopeId(uid, token, data);
  ensureBillingScopeAccess({
    uid,
    token,
    scopeId,
  });
  if (!isPersonalBillingScope(scopeId, uid) && requireManageRole) {
    ensureAnyRole(
      token,
      BILLING_ADMIN_ROLES,
      "This role cannot access billing administration actions.",
    );
  }
  if (isPersonalBillingScope(scopeId, uid)) {
    return {
      clanId: scopeId,
      ownerUid: uid,
      ownerDisplayName: null,
      clanStatus: "active",
      viewerIsOwner: true,
    };
  }
  const clanScope = await resolveClanBillingScopeMetadata(scopeId);
  if (requireOwnerMutationAccess && uid !== clanScope.ownerUid) {
    const ownerLabel = clanScope.ownerDisplayName ?? clanScope.ownerUid;
    throw new HttpsError(
      "permission-denied",
      `Only clan owner ${ownerLabel} can perform this billing action.`,
    );
  }
  return {
    clanId: scopeId,
    ownerUid: clanScope.ownerUid,
    ownerDisplayName: clanScope.ownerDisplayName,
    clanStatus: clanScope.clanStatus,
    viewerIsOwner: uid === clanScope.ownerUid,
  };
}

type ClanBillingScopeMetadata = {
  ownerUid: string;
  ownerDisplayName: string | null;
  clanStatus: string;
};

async function resolveClanBillingScopeMetadata(
  clanId: string,
): Promise<ClanBillingScopeMetadata> {
  const snapshot = await clansCollection.doc(clanId).get();
  if (!snapshot.exists) {
    throw new HttpsError(
      "failed-precondition",
      "Clan billing scope is not configured yet.",
    );
  }
  const data = snapshot.data() ?? {};
  const ownerUid = normalizeString(data.ownerUid);
  if (ownerUid.length == 0) {
    throw new HttpsError(
      "failed-precondition",
      "Clan owner is missing.",
    );
  }

  let ownerDisplayName = normalizeString(data.founderName);
  if (ownerDisplayName.length == 0) {
    const ownerMemberSnapshot = await membersCollection
      .where("clanId", "==", clanId)
      .where("authUid", "==", ownerUid)
      .limit(1)
      .get();
    if (!ownerMemberSnapshot.empty) {
      const ownerMember = ownerMemberSnapshot.docs[0]?.data() ?? {};
      ownerDisplayName =
        normalizeString(ownerMember.fullName) ||
        normalizeString(ownerMember.nickName);
    }
  }
  return {
    ownerUid,
    ownerDisplayName: ownerDisplayName.length > 0 ? ownerDisplayName : null,
    clanStatus: normalizeClanStatus(data.status),
  };
}

export const resolveBillingEntitlement = onCall(
  APP_CHECK_CALLABLE_OPTIONS,
  async (request) => {
    const auth = requireAuth(request);
    const now = new Date();
    await refreshBillingPricingTiers();
    await refreshIapProductCatalogFromFirestore();
    const scope = await resolveBillingScopeContext({
      uid: auth.uid,
      token: auth.token,
      data: request.data,
    });

    const ensured = await ensureSubscriptionForClan({
      clanId: scope.clanId,
      ownerUid: scope.ownerUid,
      actorUid: auth.uid,
      now,
    });
    const resolvedMemberCount = await resolveWorkspaceMemberCount({
      scope,
      fallbackMemberCount: ensured.memberCount,
      now,
    });
    const entitlement = buildEntitlementFromSubscription(ensured.subscription);

    return {
      clanId: scope.clanId,
      scope: serializeBillingScope(scope),
      subscription: serializeSubscription({
        ...ensured.subscription,
        memberCount: resolvedMemberCount,
      }),
      entitlement,
      pricingTiers: BILLING_PRICING_TIERS,
      settings: ensured.settings,
      memberCount: resolvedMemberCount,
    };
  },
);

export const loadBillingWorkspace = onCall(
  APP_CHECK_CALLABLE_OPTIONS,
  async (request) => {
    const auth = requireAuth(request);
    const now = new Date();
    await refreshBillingPricingTiers();
    await refreshIapProductCatalogFromFirestore();
    const scope = await resolveBillingScopeContext({
      uid: auth.uid,
      token: auth.token,
      data: request.data,
      requireManageRole: true,
    });

    const runtimeConfig = await loadBillingRuntimeConfig();
    await cancelStalePendingTransactionsRun({
      source: "system:billing_pending_timeout",
      clanId: scope.clanId,
      ownerUid: scope.ownerUid,
      timeoutMinutes: runtimeConfig.pendingTimeoutMinutes,
      limit: runtimeConfig.pendingTimeoutLimit,
    });

    const ensured = await ensureSubscriptionForClan({
      clanId: scope.clanId,
      ownerUid: scope.ownerUid,
      actorUid: auth.uid,
      now,
    });
    const resolvedMemberCount = await resolveWorkspaceMemberCount({
      scope,
      fallbackMemberCount: ensured.memberCount,
      now,
    });
    const [transactionsSnapshot, invoicesSnapshot, auditSnapshot] =
      await Promise.all([
        transactionsCollection
          .where("clanId", "==", scope.clanId)
          .orderBy("createdAt", "desc")
          .limit(50)
          .get(),
        invoicesCollection
          .where("clanId", "==", scope.clanId)
          .orderBy("createdAt", "desc")
          .limit(24)
          .get(),
        billingAuditLogsCollection
          .where("clanId", "==", scope.clanId)
          .orderBy("createdAt", "desc")
          .limit(40)
          .get(),
      ]);

    return {
      clanId: scope.clanId,
      scope: serializeBillingScope(scope),
      subscription: serializeSubscription({
        ...ensured.subscription,
        memberCount: resolvedMemberCount,
      }),
      entitlement: buildEntitlementFromSubscription(ensured.subscription),
      settings: ensured.settings,
      checkoutFlow: buildCheckoutFlowConfig(),
      pricingTiers: BILLING_PRICING_TIERS,
      memberCount: resolvedMemberCount,
      transactions: transactionsSnapshot.docs.map((doc) => ({
        id: doc.id,
        ...normalizeFirestoreJson(doc.data()),
      })),
      invoices: invoicesSnapshot.docs.map((doc) => ({
        id: doc.id,
        ...normalizeFirestoreJson(doc.data()),
      })),
      auditLogs: auditSnapshot.docs.map((doc) => ({
        id: doc.id,
        ...normalizeFirestoreJson(doc.data()),
      })),
    };
  },
);

export const updateBillingPreferences = onCall(
  APP_CHECK_CALLABLE_OPTIONS,
  async (request) => {
    const auth = requireAuth(request);
    const scope = await resolveBillingScopeContext({
      uid: auth.uid,
      token: auth.token,
      data: request.data,
      requireManageRole: true,
    });

    const paymentMode = normalizePaymentModeFromInput(request.data);
    const autoRenew = readBoolean(
      request.data,
      "autoRenew",
      paymentMode === "auto_renew",
    );
    const reminderDaysBefore = readReminderDays(request.data);

    const settings = await upsertBillingSettings({
      clanId: scope.clanId,
      ownerUid: scope.ownerUid,
      paymentMode,
      autoRenew,
      reminderDaysBefore,
      actorUid: auth.uid,
    });

    await subscriptionsCollection
      .doc(ownerBillingDocId(scope.ownerUid))
      .set(
        {
          paymentMode: settings.paymentMode,
          autoRenew: settings.autoRenew,
          updatedAt: new Date(),
          updatedBy: auth.uid,
        },
        { merge: true },
      );

    await writeBillingAuditLog({
      clanId: scope.clanId,
      actorUid: auth.uid,
      action: "billing_preferences_updated",
      entityType: "billingSettings",
      entityId: scope.clanId,
      after: {
        paymentMode: settings.paymentMode,
        autoRenew: settings.autoRenew,
        reminderDaysBefore: settings.reminderDaysBefore,
      },
    });

    return settings;
  },
);

export const verifyInAppPurchase = onCall(
  APP_CHECK_CALLABLE_OPTIONS,
  async (request) => {
    const auth = requireAuth(request);
    const now = new Date();
    await refreshBillingPricingTiers();
    const scope = await resolveBillingScopeContext({
      uid: auth.uid,
      token: auth.token,
      data: request.data,
      requireManageRole: true,
    });

    const platform = normalizeIapPlatform(
      readString(request.data, "platform"),
    );
    const payload = readRecord(request.data, "payload");
    if (payload == null) {
      throw new HttpsError(
        "invalid-argument",
        "payload is required for store purchase verification.",
      );
    }

    const verifiedPurchase = await verifyInAppStorePurchase({
      platform,
      payload,
    });
    if (verifiedPurchase.status !== "active") {
      throw new HttpsError(
        "failed-precondition",
        "The submitted store purchase is not active.",
      );
    }

    const requestedPlanCode = normalizeRequestedPlanCode(request.data);
    const productPlanCode =
      resolvePlanCodeForIapProductId(verifiedPurchase.productId, platform) ??
      verifiedPurchase.planCode;
    if (
      requestedPlanCode != null &&
      requestedPlanCode !== productPlanCode
    ) {
      throw new HttpsError(
        "invalid-argument",
        `Requested plan ${requestedPlanCode} does not match purchased product ${verifiedPurchase.productId}.`,
      );
    }

    const verificationId = verifiedPurchase.storeTransactionKey;
    const verificationRef =
      iapPurchaseVerificationsCollection.doc(verificationId);
    const lineageRef = iapPurchaseLineagesCollection.doc(
      verifiedPurchase.lineageKey,
    );

    let lockAcquired = false;
    try {
      await verificationRef.create({
        id: verificationId,
        uid: auth.uid,
        clanId: scope.clanId,
        ownerUid: scope.ownerUid,
        productId: verifiedPurchase.productId,
        planCode: productPlanCode,
        platform: verifiedPurchase.platform,
        externalTransactionId: verifiedPurchase.externalTransactionId,
        status: "processing",
        idempotencyKey: verifiedPurchase.idempotencyKey,
        storeTransactionKey: verifiedPurchase.storeTransactionKey,
        lineageKey: verifiedPurchase.lineageKey,
        updatedAt: FieldValue.serverTimestamp(),
        createdAt: FieldValue.serverTimestamp(),
      });
      lockAcquired = true;
    } catch (error) {
      if (!isAlreadyExistsError(error)) {
        throw error;
      }
      const existingVerification = await verificationRef.get();
      const existingData = existingVerification.data() ?? {};
      const existingStatus = normalizeString(existingData.status).toLowerCase();
      const existingClanId = normalizeString(existingData.clanId);
      const existingOwnerUid = normalizeString(existingData.ownerUid);
      if (
        existingClanId.length > 0 &&
        existingOwnerUid.length > 0 &&
        (existingClanId !== scope.clanId || existingOwnerUid !== scope.ownerUid)
      ) {
        throw new HttpsError(
          "permission-denied",
          "This store transaction is already attached to another billing scope.",
        );
      }
      if (existingStatus === "succeeded") {
        const ensured = await ensureSubscriptionForClan({
          clanId: scope.clanId,
          ownerUid: scope.ownerUid,
          actorUid: auth.uid,
          now,
        });
        const resolvedMemberCount = await resolveWorkspaceMemberCount({
          scope,
          fallbackMemberCount: ensured.memberCount,
          now,
        });
        const entitlement = buildEntitlementFromSubscription(
          ensured.subscription,
        );
        await upsertUserIapEntitlementSnapshot({
          uid: auth.uid,
          purchase: verifiedPurchase,
          planCode: ensured.subscription.planCode,
          entitlement,
        });
        return {
          clanId: scope.clanId,
          scope: serializeBillingScope(scope),
          replayed: true,
          subscription: serializeSubscription({
            ...ensured.subscription,
            memberCount: resolvedMemberCount,
          }),
          entitlement,
          productId: verifiedPurchase.productId,
          platform: verifiedPurchase.platform,
        };
      }
      if (existingStatus === "processing") {
        throw new HttpsError(
          "aborted",
          "This store transaction is being processed. Please retry in a moment.",
        );
      }
      if (existingStatus !== "failed") {
        throw new HttpsError(
          "failed-precondition",
          "This store transaction cannot be processed again.",
        );
      }
      await db.runTransaction(async (tx) => {
        const latest = await tx.get(verificationRef);
        const latestData = latest.data() ?? {};
        const latestStatus = normalizeString(latestData.status).toLowerCase();
        if (latestStatus !== "failed") {
          throw new HttpsError(
            "aborted",
            "This store transaction is already being processed.",
          );
        }
        tx.update(verificationRef, {
          status: "processing",
          retryCount: FieldValue.increment(1),
          retryRequestedBy: auth.uid,
          updatedAt: FieldValue.serverTimestamp(),
        });
      });
      lockAcquired = true;
    }

    if (!lockAcquired) {
      throw new HttpsError(
        "aborted",
        "Could not acquire purchase verification lock.",
      );
    }

    try {
      const ownerPolicy = await resolveOwnerBillingPolicy({
        ownerUid: scope.ownerUid,
        now,
      });
      const checkout = await createPendingCheckout({
        clanId: scope.clanId,
        ownerUid: scope.ownerUid,
        actorUid: auth.uid,
        paymentMethod: iapPlatformToPaymentMethod(platform),
        requestedPlanCode: productPlanCode,
        policyMemberCount: ownerPolicy.totalMemberCount,
        now,
      });

      const payment = await applyPaymentResult({
        transactionId: checkout.transaction.id,
        provider: iapPlatformToPaymentMethod(platform),
        gatewayReference: verifiedPurchase.externalTransactionId,
        paymentStatus: "succeeded",
        payloadHash: verifiedPurchase.storeTransactionKey,
        actorUid: auth.uid,
        now,
      });

      const activeSubscription = payment.subscription ?? checkout.subscription;
      const entitlement = buildEntitlementFromSubscription(activeSubscription);

      await Promise.all([
        verificationRef.set(
          {
            status: "succeeded",
            transactionId: checkout.transaction.id,
            invoiceId: checkout.invoice.id,
            verifiedExpiresAtMs: verifiedPurchase.expiresAtMs,
            sourcePayload: verifiedPurchase.sourcePayload,
            lineageKey: verifiedPurchase.lineageKey,
            storeTransactionKey: verifiedPurchase.storeTransactionKey,
            updatedAt: FieldValue.serverTimestamp(),
          },
          { merge: true },
        ),
        lineageRef.set(
          {
            id: verifiedPurchase.lineageKey,
            clanId: scope.clanId,
            ownerUid: scope.ownerUid,
            platform: verifiedPurchase.platform,
            productId: verifiedPurchase.productId,
            planCode: productPlanCode,
            lastExternalTransactionId: verifiedPurchase.externalTransactionId,
            lastStoreTransactionKey: verifiedPurchase.storeTransactionKey,
            lastVerificationId: verificationId,
            lastTransactionId: checkout.transaction.id,
            lastInvoiceId: checkout.invoice.id,
            verifiedExpiresAtMs: verifiedPurchase.expiresAtMs,
            updatedAt: FieldValue.serverTimestamp(),
            createdAt: FieldValue.serverTimestamp(),
          },
          { merge: true },
        ),
      ]);

      await upsertUserIapEntitlementSnapshot({
        uid: auth.uid,
        purchase: verifiedPurchase,
        planCode: activeSubscription.planCode,
        entitlement,
      });

      await notifyBillingResult({
        clanId: scope.clanId,
        approved: true,
        amountVnd: Number(checkout.transaction.amountVnd),
        transactionId: checkout.transaction.id,
        provider: iapPlatformToPaymentMethod(platform),
      });

      return {
        clanId: scope.clanId,
        scope: serializeBillingScope(scope),
        replayed: false,
        productId: verifiedPurchase.productId,
        platform: verifiedPurchase.platform,
        transactionId: checkout.transaction.id,
        subscription: serializeSubscription(activeSubscription),
        entitlement,
        invoice: payment.invoice,
      };
    } catch (error) {
      await verificationRef.set(
        {
          status: "failed",
          errorCode: normalizeStoreProcessingErrorCode(error),
          errorMessage: normalizeStoreProcessingErrorMessage(error),
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
      throw error;
    }
  },
);

async function notifyBillingResult({
  clanId,
  approved,
  amountVnd,
  transactionId,
  provider,
}: {
  clanId: string;
  approved: boolean;
  amountVnd: number;
  transactionId: string;
  provider: string;
}): Promise<void> {
  const memberIds = await resolveBillingAudienceMemberIds(clanId);
  if (memberIds.length === 0) {
    return;
  }
  await notifyMembers({
    clanId,
    memberIds,
    type: approved ? "billing_payment_succeeded" : "billing_payment_failed",
    title: approved ? "Billing payment succeeded" : "Billing payment failed",
    body: approved
      ? `Confirmed ${formatVnd(amountVnd)} via ${provider.toUpperCase()}.`
      : `Could not confirm ${formatVnd(amountVnd)} via ${provider.toUpperCase()}.`,
    target: "billing",
    targetId: transactionId,
    extraData: {
      transactionId,
      billing: "true",
      result: approved ? "success" : "failed",
      provider,
    },
  });
}

function iapPlatformToPaymentMethod(platform: IapPlatform): PaymentMethod {
  return platform === "ios" ? "apple_iap" : "google_play";
}

async function upsertUserIapEntitlementSnapshot({
  uid,
  purchase,
  planCode,
  entitlement,
}: {
  uid: string;
  purchase: {
    productId: string;
    platform: IapPlatform;
    status: "active" | "expired";
    expiresAtMs: number;
  };
  planCode: BillingPlanCode;
  entitlement: {
    adFree?: unknown;
    showAds?: unknown;
  };
}): Promise<void> {
  const tier = resolveTierByPlanCode(planCode);
  const maxClanMembers = tier.maxMembers ?? 999999;
  const adFree = readTruthy(entitlement.adFree) || !readTruthy(entitlement.showAds);
  await usersCollection.doc(uid).set(
    {
      subscription: {
        productId: purchase.productId,
        platform: purchase.platform,
        status: purchase.status.toUpperCase(),
        planCode,
        expiresAt: purchase.expiresAtMs,
      },
      entitlements: {
        ads_free: adFree,
        max_clan_members: maxClanMembers,
        plan_code: planCode,
      },
      updatedAt: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
}

function normalizePaymentModeFromInput(data: unknown): PaymentMode {
  const mode = readString(data, "paymentMode")?.toLowerCase();
  if (mode === "manual") {
    return "manual";
  }
  if (mode === "auto_renew" || mode === "auto" || mode === "automatic") {
    return "auto_renew";
  }
  throw new HttpsError(
    "invalid-argument",
    'paymentMode must be "manual" or "auto_renew".',
  );
}

function normalizeRequestedPlanCode(data: unknown): BillingPlanCode | null {
  const planCode = readString(data, "requestedPlanCode")?.toUpperCase();
  if (planCode == null || planCode.length === 0) {
    return null;
  }
  if (
    planCode === "FREE" ||
    planCode === "BASE" ||
    planCode === "PLUS" ||
    planCode === "PRO"
  ) {
    return planCode;
  }
  throw new HttpsError(
    "invalid-argument",
    "requestedPlanCode must be one of FREE, BASE, PLUS, PRO.",
  );
}

function readReminderDays(data: unknown): Array<number> | undefined {
  if (data == null || typeof data !== "object") {
    return undefined;
  }
  const raw = (data as Record<string, unknown>).reminderDaysBefore;
  if (!Array.isArray(raw)) {
    return undefined;
  }
  const normalized = raw
    .map((value) =>
      typeof value === "number" ? Math.trunc(value) : Number.NaN,
    )
    .filter((value) => Number.isFinite(value) && value > 0 && value <= 60);
  if (normalized.length === 0) {
    return undefined;
  }
  return [...new Set(normalized)].sort((left, right) => right - left);
}

function readString(data: unknown, key: string): string | null {
  if (data == null || typeof data !== "object") {
    return null;
  }
  const value = (data as Record<string, unknown>)[key];
  if (typeof value !== "string") {
    return null;
  }
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}

function readRecord(
  data: unknown,
  key: string,
): Record<string, unknown> | null {
  if (data == null || typeof data !== "object") {
    return null;
  }
  const value = (data as Record<string, unknown>)[key];
  if (value == null || typeof value !== "object" || Array.isArray(value)) {
    return null;
  }
  return value as Record<string, unknown>;
}

function readBoolean(data: unknown, key: string, fallback: boolean): boolean {
  if (data == null || typeof data !== "object") {
    return fallback;
  }
  const value = (data as Record<string, unknown>)[key];
  return typeof value === "boolean" ? value : fallback;
}

function normalizeString(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

function isAlreadyExistsError(error: unknown): boolean {
  const code = (error as { code?: unknown })?.code;
  const message = `${error}`.toLowerCase();
  return (
    code === 6 ||
    code === "already-exists" ||
    message.includes("already exists")
  );
}

function normalizeStoreProcessingErrorCode(error: unknown): string {
  if (error instanceof HttpsError) {
    return error.code;
  }
  return "internal";
}

function normalizeStoreProcessingErrorMessage(error: unknown): string {
  if (error instanceof HttpsError) {
    return normalizeString(error.message) || "Store transaction processing failed.";
  }
  return "Store transaction processing failed.";
}

function readTruthy(value: unknown): boolean {
  if (typeof value === "boolean") {
    return value;
  }
  if (typeof value === "string") {
    const normalized = value.trim().toLowerCase();
    return normalized === "true" || normalized === "1" || normalized === "yes";
  }
  if (typeof value === "number") {
    return value !== 0;
  }
  return false;
}

function normalizeClanStatus(value: unknown): string {
  const normalized = normalizeString(value).toLowerCase();
  return normalized.length > 0 ? normalized : "active";
}

function serializeBillingScope(
  scope: BillingScopeContext,
): Record<string, unknown> {
  return {
    clanId: scope.clanId,
    ownerUid: scope.ownerUid,
    ownerDisplayName: scope.ownerDisplayName,
    clanStatus: scope.clanStatus,
    viewerIsOwner: scope.viewerIsOwner,
  };
}

async function resolveWorkspaceMemberCount({
  scope,
  fallbackMemberCount,
  now,
}: {
  scope: BillingScopeContext;
  fallbackMemberCount: number;
  now: Date;
}): Promise<number> {
  if (!isPersonalBillingScope(scope.clanId, scope.ownerUid)) {
    return fallbackMemberCount;
  }
  const policy = await resolveOwnerBillingPolicy({
    ownerUid: scope.ownerUid,
    now,
  });
  return policy.totalMemberCount;
}

function serializeSubscription(
  subscription: Record<string, unknown>,
): Record<string, unknown> {
  return normalizeFirestoreJson(subscription);
}

function normalizeFirestoreJson(
  source: Record<string, unknown>,
): Record<string, unknown> {
  const output: Record<string, unknown> = {};
  for (const [key, value] of Object.entries(source)) {
    if (value instanceof Date) {
      output[key] = value.toISOString();
      continue;
    }
    if (
      value != null &&
      typeof value === "object" &&
      "toDate" in value &&
      typeof (value as { toDate?: unknown }).toDate === "function"
    ) {
      try {
        output[key] = (value as { toDate: () => Date }).toDate().toISOString();
      } catch {
        output[key] = value;
      }
      continue;
    }
    output[key] = value;
  }
  return output;
}

function formatVnd(amount: number): string {
  return `${Math.max(0, Math.trunc(amount)).toLocaleString("vi-VN")} VND`;
}

function buildCheckoutFlowConfig(): Record<string, unknown> {
  const storeProductIdsByPlan: Record<string, string> = {};
  const storeProductIdsByPlanByPlatform: Record<
    string,
    Record<string, string>
  > = {};
  const configuredStoreProducts = resolveStoreProductIdsByPlan();
  for (const [planCode, platformProducts] of Object.entries(configuredStoreProducts)) {
    const normalizedPlanCode = normalizeString(planCode).toUpperCase();
    if (
      normalizedPlanCode.length === 0 ||
      platformProducts == null ||
      typeof platformProducts !== "object" ||
      Array.isArray(platformProducts)
    ) {
      continue;
    }
    const perPlatform: Record<string, string> = {};
    for (const [platformKey, productId] of Object.entries(platformProducts)) {
      const normalizedPlatform = normalizeString(platformKey).toLowerCase();
      const normalizedProductId = normalizeString(productId).toLowerCase();
      if (
        (normalizedPlatform !== "ios" && normalizedPlatform !== "android") ||
        normalizedProductId.length === 0
      ) {
        continue;
      }
      perPlatform[normalizedPlatform] = normalizedProductId;
    }
    if (Object.keys(perPlatform).length === 0) {
      continue;
    }
    storeProductIdsByPlanByPlatform[normalizedPlanCode] = perPlatform;
    storeProductIdsByPlan[normalizedPlanCode] =
      perPlatform.ios ?? perPlatform.android ?? "";
  }
  return {
    storeProductIdsByPlan,
    storeProductIdsByPlanByPlatform,
  };
}
