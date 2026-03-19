import { createHmac } from "node:crypto";

import { HttpsError, onCall } from "firebase-functions/v2/https";

import {
  APP_REGION,
  BILLING_ALLOW_MANUAL_SETTLEMENT,
  getBillingWebhookSecret,
  getVnpayHashSecret,
  getVnpayTmnCode,
} from "../config/runtime";
import {
  loadBillingRuntimeConfig,
  type BillingRuntimeConfig,
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
} from "./store";
import {
  BILLING_PRICING_TIERS,
  rankPlanCode,
  type BillingPlanCode,
  type PaymentMethod,
  type PaymentMode,
} from "./pricing";
import { requireAuth } from "../shared/errors";
import { db } from "../shared/firestore";
import { notifyMembers } from "../notifications/push-delivery";
import { logInfo } from "../shared/logger";
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
const transactionsCollection = db.collection("paymentTransactions");
const invoicesCollection = db.collection("subscriptionInvoices");
const billingAuditLogsCollection = db.collection("billingAuditLogs");
const BILLING_ADMIN_ROLES = [
  "SUPER_ADMIN",
  "CLAN_ADMIN",
  "BRANCH_ADMIN",
  "CLAN_OWNER",
  "CLAN_LEADER",
  "VICE_LEADER",
  "SUPPORTER_OF_LEADER",
];

function scopedBillingDocId(clanId: string, ownerUid: string): string {
  return `${clanId}__${ownerUid}`;
}

function personalBillingScopeId(uid: string): string {
  return `user_scope__${uid.trim()}`;
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
  const clanScope = await resolveClanBillingScopeMetadata(scopeId, {
    fallbackOwnerUid: uid,
    actorUid: uid,
  });
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
  options?: {
    fallbackOwnerUid?: string;
    actorUid?: string;
  },
): Promise<ClanBillingScopeMetadata> {
  const snapshot = await clansCollection.doc(clanId).get();
  if (!snapshot.exists) {
    throw new HttpsError(
      "failed-precondition",
      "Clan billing scope is not configured yet.",
    );
  }
  const data = snapshot.data() ?? {};
  const billingOwnerUid = normalizeString(data.billingOwnerUid);
  const ownerUid = normalizeString(data.ownerUid);
  let resolved = billingOwnerUid.length > 0 ? billingOwnerUid : ownerUid;
  if (resolved.length == 0) {
    const fallbackOwnerUid = normalizeString(options?.fallbackOwnerUid);
    if (fallbackOwnerUid.length == 0) {
      throw new HttpsError(
        "failed-precondition",
        "Clan billing owner is missing.",
      );
    }
    resolved = fallbackOwnerUid;
    await clansCollection.doc(clanId).set(
      {
        billingOwnerUid: resolved,
        updatedAt: new Date(),
        updatedBy: normalizeString(options?.actorUid) || resolved,
      },
      { merge: true },
    );
  }

  let ownerDisplayName = normalizeString(data.founderName);
  if (ownerDisplayName.length == 0) {
    const ownerMemberSnapshot = await membersCollection
      .where("clanId", "==", clanId)
      .where("authUid", "==", resolved)
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
    ownerUid: resolved,
    ownerDisplayName: ownerDisplayName.length > 0 ? ownerDisplayName : null,
    clanStatus: normalizeClanStatus(data.status),
  };
}

function ensureManualSettlementAllowed(token: AuthToken): void {
  if (!BILLING_ALLOW_MANUAL_SETTLEMENT) {
    throw new HttpsError(
      "failed-precondition",
      "Manual settlement is disabled in this environment.",
    );
  }
  ensureAnyRole(
    token,
    ["SUPER_ADMIN"],
    "Manual settlement is restricted to super admins.",
  );
}

export const resolveBillingEntitlement = onCall(
  { region: APP_REGION },
  async (request) => {
    const auth = requireAuth(request);
    const scope = await resolveBillingScopeContext({
      uid: auth.uid,
      token: auth.token,
      data: request.data,
    });

    const ensured = await ensureSubscriptionForClan({
      clanId: scope.clanId,
      ownerUid: scope.ownerUid,
      actorUid: auth.uid,
    });
    const entitlement = buildEntitlementFromSubscription(ensured.subscription);

    return {
      clanId: scope.clanId,
      scope: serializeBillingScope(scope),
      subscription: serializeSubscription(ensured.subscription),
      entitlement,
      pricingTiers: BILLING_PRICING_TIERS,
      settings: ensured.settings,
      memberCount: ensured.memberCount,
    };
  },
);

export const loadBillingWorkspace = onCall(
  { region: APP_REGION },
  async (request) => {
    const auth = requireAuth(request);
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
      subscription: serializeSubscription(ensured.subscription),
      entitlement: buildEntitlementFromSubscription(ensured.subscription),
      settings: ensured.settings,
      checkoutFlow: buildCheckoutFlowConfig(runtimeConfig),
      pricingTiers: BILLING_PRICING_TIERS,
      memberCount: ensured.memberCount,
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
  { region: APP_REGION },
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
      .doc(scopedBillingDocId(scope.clanId, scope.ownerUid))
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

export const createSubscriptionCheckout = onCall(
  { region: APP_REGION },
  async (request) => {
    const auth = requireAuth(request);
    const scope = await resolveBillingScopeContext({
      uid: auth.uid,
      token: auth.token,
      data: request.data,
      requireManageRole: true,
    });

    const paymentMethod = normalizePaymentMethod(request.data);
    const runtimeConfig = await loadBillingRuntimeConfig();
    const checkoutLocale = normalizeVnpayLocaleInput(request.data);
    const checkoutBankCode = normalizeVnpayBankCodeInput(request.data);
    const checkoutOrderNote = normalizeVnpayOrderNoteInput(request.data);
    const checkoutContactPhone = normalizeVnpayContactPhoneInput(request.data);
    await cancelStalePendingTransactionsRun({
      source: "system:billing_pending_timeout",
      clanId: scope.clanId,
      ownerUid: scope.ownerUid,
      timeoutMinutes: runtimeConfig.pendingTimeoutMinutes,
      limit: runtimeConfig.pendingTimeoutLimit,
    });
    const now = new Date();
    const ownerPolicy = await resolveOwnerBillingPolicy({
      ownerUid: scope.ownerUid,
      now,
    });
    const minimumPlanCode = ownerPolicy.minimumTier.planCode;
    const requestedPlanCode = normalizeRequestedPlanCode(request.data);
    if (requestedPlanCode != null) {
      if (rankPlanCode(requestedPlanCode) < rankPlanCode(minimumPlanCode)) {
        throw new HttpsError(
          "invalid-argument",
          `requestedPlanCode must be at least ${minimumPlanCode} for ${ownerPolicy.totalMemberCount} total members across owner clans.`,
        );
      }
    }
    const ensured = await ensureSubscriptionForClan({
      clanId: scope.clanId,
      ownerUid: scope.ownerUid,
      actorUid: auth.uid,
    });
    const selectedPlanCode = requestedPlanCode ?? ensured.subscription.planCode;
    const selectedRank = rankPlanCode(selectedPlanCode);
    const currentRank = rankPlanCode(ensured.subscription.planCode);
    if (
      selectedRank < currentRank &&
      isSubscriptionActiveAndValid(ensured.subscription, now)
    ) {
      throw new HttpsError(
        "failed-precondition",
        "Downgrade is available only after the current paid term ends.",
      );
    }
    const canRenewCurrent = canRenewCurrentPlan(
      ensured.subscription,
      now,
    );
    if (
      selectedRank === currentRank &&
      !canRenewCurrent
    ) {
      throw new HttpsError(
        "failed-precondition",
        "Current subscription is not eligible for this payment option yet.",
      );
    }

    let checkout;
    try {
      checkout = await createPendingCheckout({
        clanId: scope.clanId,
        ownerUid: scope.ownerUid,
        actorUid: auth.uid,
        paymentMethod,
        requestedPlanCode: requestedPlanCode ?? undefined,
        policyMemberCount: ownerPolicy.totalMemberCount,
      });
    } catch (error) {
      if (
        error instanceof Error &&
        (error.message.toLowerCase().includes("renewal window") ||
          error.message.toLowerCase().includes("downgrade"))
      ) {
        throw new HttpsError(
          "failed-precondition",
          "Current subscription is not eligible for this payment option yet.",
        );
      }
      throw error;
    }

    let checkoutUrl = "";
    let requiresManualConfirmation = false;
    if (checkout.tier.planCode === "FREE") {
      checkoutUrl = "";
      requiresManualConfirmation = false;
    } else if (paymentMethod === "vnpay") {
      const vnpayCheckout = buildVnpayCheckoutUrl({
        transactionId: checkout.transaction.id,
        amountVnd: checkout.transaction.amountVnd,
        orderInfo: buildVnpayOrderInfo({
          planCode: checkout.tier.planCode,
          orderNote: checkoutOrderNote,
          contactPhone: checkoutContactPhone,
        }),
        bankCode: checkoutBankCode,
        localeOverride: checkoutLocale,
        returnUrl:
          readString(request.data, "returnUrl") ?? runtimeConfig.vnpayReturnUrl,
        runtimeConfig,
      });
      if (!vnpayCheckout.ready) {
        throw new HttpsError(
          "failed-precondition",
          vnpayCheckout.reason ?? "VNPay checkout is not configured yet.",
        );
      }
      checkoutUrl = vnpayCheckout.url;
    } else {
      checkoutUrl = buildCardCheckoutHintUrl({
        transactionId: checkout.transaction.id,
        runtimeConfig,
      });
      if (checkoutUrl.length === 0) {
        throw new HttpsError(
          "failed-precondition",
          "Card checkout is not configured yet.",
        );
      }
      requiresManualConfirmation = true;
    }

    logInfo("createSubscriptionCheckout created", {
      uid: auth.uid,
      clanId: scope.clanId,
      paymentMethod,
      transactionId: checkout.transaction.id,
      planCode: checkout.tier.planCode,
      amountVnd: checkout.transaction.amountVnd,
    });

    return {
      clanId: scope.clanId,
      scope: serializeBillingScope(scope),
      paymentMethod,
      planCode: checkout.tier.planCode,
      amountVnd: checkout.transaction.amountVnd,
      vatIncluded: checkout.transaction.vatIncluded,
      transactionId: checkout.transaction.id,
      invoiceId: checkout.invoice.id,
      checkoutUrl,
      requiresManualConfirmation,
      subscription: serializeSubscription(checkout.subscription),
      entitlement: buildEntitlementFromSubscription(checkout.subscription),
      ownerPolicy: {
        totalMemberCount: ownerPolicy.totalMemberCount,
        minimumPlanCode,
        highestActivePlanCode: ownerPolicy.highestActivePlanCode,
        hasSufficientActivePlan: ownerPolicy.hasSufficientActivePlan,
      },
    };
  },
);

export const completeCardCheckout = onCall(
  { region: APP_REGION },
  async (request) => {
    const auth = requireAuth(request);
    const scope = await resolveBillingScopeContext({
      uid: auth.uid,
      token: auth.token,
      data: request.data,
      requireManageRole: true,
    });
    ensureManualSettlementAllowed(auth.token);

    const transactionId = readString(request.data, "transactionId");
    if (transactionId == null || transactionId.length === 0) {
      throw new HttpsError("invalid-argument", "transactionId is required.");
    }

    const txSnapshot = await transactionsCollection.doc(transactionId).get();
    if (!txSnapshot.exists) {
      throw new HttpsError("not-found", "transaction not found.");
    }
    const txClanId = normalizeString(txSnapshot.data()?.clanId);
    if (txClanId !== scope.clanId) {
      throw new HttpsError("permission-denied", "transaction clan mismatch.");
    }
    const txOwnerUid = normalizeString(txSnapshot.data()?.subscriptionOwnerUid);
    if (txOwnerUid.length > 0 && txOwnerUid !== scope.ownerUid) {
      throw new HttpsError("permission-denied", "transaction owner mismatch.");
    }

    const payment = await applyPaymentResult({
      transactionId,
      provider: "card",
      gatewayReference: `CARD-CONF-${transactionId.slice(0, 10)}`,
      paymentStatus: "succeeded",
      payloadHash: createPayloadHash({ transactionId, actorUid: auth.uid }),
      actorUid: auth.uid,
    });

    await notifyBillingResult({
      clanId: scope.clanId,
      approved: true,
      amountVnd: Number(payment.transaction.amountVnd),
      transactionId,
      provider: "card",
    });

    return {
      status: "succeeded",
      transactionId,
      subscription: payment.subscription
        ? serializeSubscription(payment.subscription)
        : null,
      entitlement: payment.subscription
        ? buildEntitlementFromSubscription(payment.subscription)
        : null,
      invoice: payment.invoice,
    };
  },
);

export const simulateVnpaySettlement = onCall(
  { region: APP_REGION },
  async (request) => {
    const auth = requireAuth(request);
    const scope = await resolveBillingScopeContext({
      uid: auth.uid,
      token: auth.token,
      data: request.data,
    });
    ensureManualSettlementAllowed(auth.token);

    const transactionId = readString(request.data, "transactionId");
    if (transactionId == null || transactionId.length === 0) {
      throw new HttpsError("invalid-argument", "transactionId is required.");
    }

    const txSnapshot = await transactionsCollection.doc(transactionId).get();
    if (!txSnapshot.exists) {
      throw new HttpsError("not-found", "transaction not found.");
    }
    const txClanId = normalizeString(txSnapshot.data()?.clanId);
    if (txClanId !== scope.clanId) {
      throw new HttpsError("permission-denied", "transaction clan mismatch.");
    }
    const txOwnerUid = normalizeString(txSnapshot.data()?.subscriptionOwnerUid);
    if (txOwnerUid.length > 0 && txOwnerUid !== scope.ownerUid) {
      throw new HttpsError("permission-denied", "transaction owner mismatch.");
    }

    const payment = await applyPaymentResult({
      transactionId,
      provider: "vnpay",
      gatewayReference: `VNPAY-SIM-${transactionId.slice(0, 10)}`,
      paymentStatus: "succeeded",
      payloadHash: createPayloadHash({ transactionId, actorUid: auth.uid }),
      actorUid: auth.uid,
    });

    await notifyBillingResult({
      clanId: scope.clanId,
      approved: true,
      amountVnd: Number(payment.transaction.amountVnd),
      transactionId,
      provider: "vnpay",
    });

    return {
      status: "succeeded",
      transactionId,
      subscription: payment.subscription
        ? serializeSubscription(payment.subscription)
        : null,
      entitlement: payment.subscription
        ? buildEntitlementFromSubscription(payment.subscription)
        : null,
      invoice: payment.invoice,
    };
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
    title: approved ? "Subscription updated successfully" : "Payment failed",
    body: approved
      ? `Payment ${formatVnd(amountVnd)} via ${provider.toUpperCase()} was confirmed.`
      : `Payment attempt for ${formatVnd(amountVnd)} failed.`,
    target: "generic",
    targetId: transactionId,
    extraData: {
      transactionId,
      billing: "true",
      result: approved ? "success" : "failed",
      provider,
    },
  });
}

function canRenewCurrentPlan(
  subscription: {
    planCode?: unknown;
    status?: unknown;
    expiresAt?: unknown;
  },
  now: Date,
): boolean {
  const planCode = normalizeString(subscription.planCode).toUpperCase();
  if (planCode === "FREE") {
    return false;
  }
  const status = normalizeString(subscription.status).toLowerCase();
  if (status === "expired" || status === "grace_period") {
    return true;
  }
  if (status !== "active") {
    return false;
  }
  const expiresAt = subscription.expiresAt;
  if (!(expiresAt instanceof Date)) {
    return false;
  }
  const daysToExpire =
    (expiresAt.getTime() - now.getTime()) / (1000 * 60 * 60 * 24);
  return daysToExpire <= 30;
}

function normalizePaymentMethod(data: unknown): PaymentMethod {
  const method = readString(data, "paymentMethod")?.toLowerCase();
  if (method === "card") {
    return "card";
  }
  if (method === "vnpay") {
    return "vnpay";
  }
  throw new HttpsError(
    "invalid-argument",
    'paymentMethod must be "card" or "vnpay".',
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

function normalizeVnpayLocaleInput(data: unknown): "vn" | "en" | null {
  return normalizeVnpayLocale(readString(data, "locale"));
}

function normalizeVnpayBankCodeInput(data: unknown): string | null {
  const raw = readString(data, "bankCode");
  if (raw == null) {
    return null;
  }
  const normalized = raw
    .toUpperCase()
    .replace(/[^A-Z0-9_]/g, "")
    .slice(0, 32);
  return normalized.length > 0 ? normalized : null;
}

function normalizeVnpayOrderNoteInput(data: unknown): string | null {
  const raw = readString(data, "orderNote");
  if (raw == null) {
    return null;
  }
  const normalized = sanitizeVnpayOrderInfo(raw);
  return normalized.length > 0 ? normalized : null;
}

function normalizeVnpayContactPhoneInput(data: unknown): string | null {
  const raw = readString(data, "contactPhone");
  if (raw == null) {
    return null;
  }
  const normalized = raw.replace(/[^0-9+]/g, "").slice(0, 20);
  return normalized.length > 0 ? normalized : null;
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

function isSubscriptionActiveAndValid(
  subscription: {
    status?: unknown;
    expiresAt?: unknown;
  },
  now: Date,
): boolean {
  const status = normalizeString(subscription.status).toLowerCase();
  if (status !== "active" && status !== "grace_period") {
    return false;
  }
  const expiresAt = subscription.expiresAt;
  if (!(expiresAt instanceof Date)) {
    return status === "grace_period";
  }
  return expiresAt.getTime() > now.getTime();
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

function createPayloadHash(payload: Record<string, unknown>): string {
  return createHmac("sha256", getBillingWebhookSecret())
    .update(JSON.stringify(payload))
    .digest("hex");
}

function buildCardCheckoutHintUrl({
  transactionId,
  runtimeConfig,
}: {
  transactionId: string;
  runtimeConfig: BillingRuntimeConfig;
}): string {
  const base = normalizeHttpUrl(runtimeConfig.cardCheckoutUrlBase);
  if (base == null) {
    return "";
  }
  try {
    const url = new URL(base);
    url.searchParams.set("transactionId", transactionId);
    return url.toString();
  } catch {
    return "";
  }
}

function buildVnpayOrderInfo({
  planCode,
  orderNote,
  contactPhone,
}: {
  planCode: BillingPlanCode;
  orderNote: string | null;
  contactPhone: string | null;
}): string {
  const base = `BeFam ${planCode} annual subscription`;
  const note = orderNote == null || orderNote.length === 0 ? "" : ` ${orderNote}`;
  const phone =
    contactPhone == null || contactPhone.length === 0
      ? ""
      : ` Phone ${contactPhone}`;
  const composed = `${base}${note}${phone}`.trim();
  const normalized = sanitizeVnpayOrderInfo(composed);
  return normalized.length > 0
    ? normalized
    : sanitizeVnpayOrderInfo(base);
}

function sanitizeVnpayOrderInfo(value: string): string {
  const withoutTone = value.normalize("NFD").replace(/[\u0300-\u036f]/g, "");
  const asciiOnly = withoutTone
    .replace(/[^\x20-\x7E]/g, " ")
    .replace(/\s+/g, " ")
    .trim();
  return asciiOnly.slice(0, 255);
}

function normalizeVnpayLocale(value: string | null): "vn" | "en" {
  if (value == null) {
    return "vn";
  }
  const normalized = value.trim().toLowerCase();
  if (normalized.startsWith("en")) {
    return "en";
  }
  return "vn";
}

function buildVnpayCheckoutUrl({
  transactionId,
  amountVnd,
  orderInfo,
  bankCode,
  localeOverride,
  returnUrl,
  runtimeConfig,
}: {
  transactionId: string;
  amountVnd: number;
  orderInfo: string;
  bankCode: string | null;
  localeOverride: "vn" | "en" | null;
  returnUrl: string;
  runtimeConfig: BillingRuntimeConfig;
}): {
  ready: boolean;
  url: string;
  reason?: string;
} {
  const tmnCode = getVnpayTmnCode();
  const hashSecret = getVnpayHashSecret();
  const normalizedReturnUrl =
    normalizeHttpUrl(returnUrl) ??
    normalizeHttpUrl(runtimeConfig.vnpayReturnUrl);
  if (
    tmnCode.length === 0 ||
    hashSecret.length === 0 ||
    normalizedReturnUrl == null
  ) {
    const fallback = normalizeHttpUrl(runtimeConfig.vnpayFallbackUrl);
    if (fallback == null) {
      return {
        ready: false,
        url: "",
        reason:
          "VNPay checkout is missing config (VNPAY_TMNCODE, VNPAY_HASH_SECRET, or returnUrl).",
      };
    }
    try {
      const url = new URL(fallback);
      url.searchParams.set("transactionId", transactionId);
      url.searchParams.set("amountVnd", `${amountVnd}`);
      return {
        ready: true,
        url: url.toString(),
      };
    } catch {
      return {
        ready: false,
        url: "",
        reason:
          "VNPay checkout fallback URL is invalid or unavailable.",
      };
    }
  }

  const gatewayBaseUrl = normalizeHttpUrl(runtimeConfig.vnpayGatewayBaseUrl);
  if (gatewayBaseUrl == null) {
    return {
      ready: false,
      url: "",
      reason: "VNPay gateway base URL is invalid.",
    };
  }

  const now = new Date();
  const createDate = formatVnpTimestamp(now);
  const locale =
    localeOverride ?? normalizeVnpayLocale(normalizeString(runtimeConfig.vnpayLocale));
  const ipAddress =
    normalizeString(runtimeConfig.vnpayIpAddress) || "127.0.0.1";
  const params: Record<string, string> = {
    vnp_Version: "2.1.0",
    vnp_Command: "pay",
    vnp_TmnCode: tmnCode,
    vnp_Amount: `${Math.max(0, Math.trunc(amountVnd)) * 100}`,
    vnp_CurrCode: "VND",
    vnp_TxnRef: transactionId,
    vnp_OrderInfo: orderInfo,
    vnp_OrderType: "billpayment",
    vnp_Locale: locale,
    vnp_ReturnUrl: normalizedReturnUrl,
    vnp_IpAddr: ipAddress,
    vnp_CreateDate: createDate,
  };
  if (bankCode != null && bankCode.length > 0) {
    params.vnp_BankCode = bankCode;
  }

  const queryString = Object.keys(params)
    .sort()
    .map((key) => `${key}=${encodeURIComponent(params[key])}`)
    .join("&");
  const secureHash = createHmac("sha512", hashSecret)
    .update(queryString)
    .digest("hex");
  const gateway = new URL(gatewayBaseUrl);
  const base = `${gateway.origin}${gateway.pathname}`;
  return {
    ready: true,
    url: `${base}?${queryString}&vnp_SecureHash=${secureHash}`,
    reason: undefined,
  };
}

function normalizeHttpUrl(value: string): string | null {
  const trimmed = value.trim();
  if (trimmed.length === 0) {
    return null;
  }
  try {
    const url = new URL(trimmed);
    if (url.protocol !== "https:" && url.protocol !== "http:") {
      return null;
    }
    return url.toString();
  } catch {
    return null;
  }
}

function formatVnpTimestamp(value: Date): string {
  const year = value.getUTCFullYear();
  const month = `${value.getUTCMonth() + 1}`.padStart(2, "0");
  const day = `${value.getUTCDate()}`.padStart(2, "0");
  const hour = `${value.getUTCHours()}`.padStart(2, "0");
  const minute = `${value.getUTCMinutes()}`.padStart(2, "0");
  const second = `${value.getUTCSeconds()}`.padStart(2, "0");
  return `${year}${month}${day}${hour}${minute}${second}`;
}

function formatVnd(amount: number): string {
  return `${Math.max(0, Math.trunc(amount)).toLocaleString("vi-VN")} VND`;
}

function buildCheckoutFlowConfig(
  runtimeConfig: BillingRuntimeConfig,
): Record<string, unknown> {
  const qrImageUrlsByPlan: Record<string, string> = {};
  const baseQr = normalizeHttpUrl(runtimeConfig.qrImageBaseUrl);
  const plusQr = normalizeHttpUrl(runtimeConfig.qrImagePlusUrl);
  const proQr = normalizeHttpUrl(runtimeConfig.qrImageProUrl);
  if (baseQr != null) {
    qrImageUrlsByPlan.BASE = baseQr;
  }
  if (plusQr != null) {
    qrImageUrlsByPlan.PLUS = plusQr;
  }
  if (proQr != null) {
    qrImageUrlsByPlan.PRO = proQr;
  }
  return {
    qrCheckoutEnabled: runtimeConfig.qrCheckoutEnabled,
    qrImageUrlsByPlan,
  };
}
