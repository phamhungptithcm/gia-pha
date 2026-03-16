import { createHmac } from 'node:crypto';

import { HttpsError, onCall } from 'firebase-functions/v2/https';

import { APP_REGION } from '../config/runtime';
import {
  applyPaymentResult,
  countClanMembers,
  buildEntitlementFromSubscription,
  createPendingCheckout,
  ensureSubscriptionForClan,
  resolveBillingAudienceMemberIds,
  upsertBillingSettings,
  writeBillingAuditLog,
} from './store';
import {
  BILLING_PRICING_TIERS,
  rankPlanCode,
  resolvePlanByMemberCount,
  type BillingPlanCode,
  type PaymentMethod,
  type PaymentMode,
} from './pricing';
import { requireAuth } from '../shared/errors';
import { db } from '../shared/firestore';
import { notifyMembers } from '../notifications/push-delivery';
import { logInfo } from '../shared/logger';
import {
  ensureClaimedSession,
  ensureClanAccess,
  tokenClanIds,
  type AuthToken,
} from '../shared/permissions';

const subscriptionsCollection = db.collection('subscriptions');
const transactionsCollection = db.collection('paymentTransactions');
const invoicesCollection = db.collection('subscriptionInvoices');
const billingAuditLogsCollection = db.collection('billingAuditLogs');

function scopedBillingDocId(clanId: string, ownerUid: string): string {
  return `${clanId}__${ownerUid}`;
}

export const resolveBillingEntitlement = onCall(
  { region: APP_REGION },
  async (request) => {
    const auth = requireAuth(request);
    ensureClaimedSession(auth.token);
    const clanId = resolveClanId(auth.token, request.data);
    if (clanId.length === 0) {
      throw new HttpsError('failed-precondition', 'No clan context is available.');
    }
    ensureClanAccess(auth.token, clanId);

    const ensured = await ensureSubscriptionForClan({
      clanId,
      actorUid: auth.uid,
    });
    const entitlement = buildEntitlementFromSubscription(ensured.subscription);

    return {
      clanId,
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
    ensureClaimedSession(auth.token);
    const clanId = resolveClanId(auth.token, request.data);
    if (clanId.length === 0) {
      throw new HttpsError('failed-precondition', 'No clan context is available.');
    }
    ensureClanAccess(auth.token, clanId);

    const ensured = await ensureSubscriptionForClan({
      clanId,
      actorUid: auth.uid,
    });
    const [transactionsSnapshot, invoicesSnapshot, auditSnapshot] = await Promise.all([
      transactionsCollection
        .where('clanId', '==', clanId)
        .orderBy('createdAt', 'desc')
        .limit(50)
        .get(),
      invoicesCollection
        .where('clanId', '==', clanId)
        .orderBy('createdAt', 'desc')
        .limit(24)
        .get(),
      billingAuditLogsCollection
        .where('clanId', '==', clanId)
        .orderBy('createdAt', 'desc')
        .limit(40)
        .get(),
    ]);

    return {
      clanId,
      subscription: serializeSubscription(ensured.subscription),
      entitlement: buildEntitlementFromSubscription(ensured.subscription),
      settings: ensured.settings,
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
    ensureClaimedSession(auth.token);
    const clanId = resolveClanId(auth.token, request.data);
    if (clanId.length === 0) {
      throw new HttpsError('failed-precondition', 'No clan context is available.');
    }
    ensureClanAccess(auth.token, clanId);

    const paymentMode = normalizePaymentModeFromInput(request.data);
    const autoRenew = readBoolean(request.data, 'autoRenew', paymentMode === 'auto_renew');
    const reminderDaysBefore = readReminderDays(request.data);

    const settings = await upsertBillingSettings({
      clanId,
      ownerUid: auth.uid,
      paymentMode,
      autoRenew,
      reminderDaysBefore,
      actorUid: auth.uid,
    });

    await subscriptionsCollection.doc(scopedBillingDocId(clanId, auth.uid)).set(
      {
        paymentMode: settings.paymentMode,
        autoRenew: settings.autoRenew,
        updatedAt: new Date(),
        updatedBy: auth.uid,
      },
      { merge: true },
    );

    await writeBillingAuditLog({
      clanId,
      actorUid: auth.uid,
      action: 'billing_preferences_updated',
      entityType: 'billingSettings',
      entityId: clanId,
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
    ensureClaimedSession(auth.token);
    const clanId = resolveClanId(auth.token, request.data);
    if (clanId.length === 0) {
      throw new HttpsError('failed-precondition', 'No clan context is available.');
    }
    ensureClanAccess(auth.token, clanId);

    const paymentMethod = normalizePaymentMethod(request.data);
    const requestedPlanCode = normalizeRequestedPlanCode(request.data);
    if (requestedPlanCode != null) {
      const memberCount = await countClanMembers(clanId);
      const minimumPlanCode = resolvePlanByMemberCount(memberCount).planCode;
      if (rankPlanCode(requestedPlanCode) < rankPlanCode(minimumPlanCode)) {
        throw new HttpsError(
          'invalid-argument',
          `requestedPlanCode must be at least ${minimumPlanCode} for ${memberCount} members.`,
        );
      }
    }
    const checkout = await createPendingCheckout({
      clanId,
      actorUid: auth.uid,
      paymentMethod,
      requestedPlanCode: requestedPlanCode ?? undefined,
    });

    let checkoutUrl = '';
    let requiresManualConfirmation = false;
    if (checkout.tier.planCode === 'FREE') {
      checkoutUrl = '';
      requiresManualConfirmation = false;
    } else if (paymentMethod === 'vnpay') {
      checkoutUrl = buildVnpayCheckoutUrl({
        transactionId: checkout.transaction.id,
        amountVnd: checkout.transaction.amountVnd,
        orderInfo: `BeFam ${checkout.tier.planCode} annual subscription`,
        returnUrl:
          readString(request.data, 'returnUrl') ??
          process.env.VNPAY_RETURN_URL ??
          'https://example.com/billing/vnpay-return',
      });
    } else {
      checkoutUrl = buildCardCheckoutHintUrl({
        transactionId: checkout.transaction.id,
      });
      requiresManualConfirmation = true;
    }

    logInfo('createSubscriptionCheckout created', {
      uid: auth.uid,
      clanId,
      paymentMethod,
      transactionId: checkout.transaction.id,
      planCode: checkout.tier.planCode,
      amountVnd: checkout.transaction.amountVnd,
    });

    return {
      clanId,
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
    };
  },
);

export const completeCardCheckout = onCall(
  { region: APP_REGION },
  async (request) => {
    const auth = requireAuth(request);
    ensureClaimedSession(auth.token);
    const clanId = resolveClanId(auth.token, request.data);
    if (clanId.length === 0) {
      throw new HttpsError('failed-precondition', 'No clan context is available.');
    }
    ensureClanAccess(auth.token, clanId);

    const transactionId = readString(request.data, 'transactionId');
    if (transactionId == null || transactionId.length === 0) {
      throw new HttpsError('invalid-argument', 'transactionId is required.');
    }

    const txSnapshot = await transactionsCollection.doc(transactionId).get();
    if (!txSnapshot.exists) {
      throw new HttpsError('not-found', 'transaction not found.');
    }
    const txClanId = normalizeString(txSnapshot.data()?.clanId);
    if (txClanId !== clanId) {
      throw new HttpsError('permission-denied', 'transaction clan mismatch.');
    }
    const txOwnerUid = normalizeString(txSnapshot.data()?.subscriptionOwnerUid);
    if (txOwnerUid.length > 0 && txOwnerUid !== auth.uid) {
      throw new HttpsError('permission-denied', 'transaction owner mismatch.');
    }

    const payment = await applyPaymentResult({
      transactionId,
      provider: 'card',
      gatewayReference: `CARD-CONF-${transactionId.slice(0, 10)}`,
      paymentStatus: 'succeeded',
      payloadHash: createPayloadHash({ transactionId, actorUid: auth.uid }),
      actorUid: auth.uid,
    });

    await notifyBillingResult({
      clanId,
      approved: true,
      amountVnd: Number(payment.transaction.amountVnd),
      transactionId,
      provider: 'card',
    });

    return {
      status: 'succeeded',
      transactionId,
      subscription: payment.subscription ? serializeSubscription(payment.subscription) : null,
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
    ensureClaimedSession(auth.token);
    const clanId = resolveClanId(auth.token, request.data);
    if (clanId.length === 0) {
      throw new HttpsError('failed-precondition', 'No clan context is available.');
    }
    ensureClanAccess(auth.token, clanId);

    const transactionId = readString(request.data, 'transactionId');
    if (transactionId == null || transactionId.length === 0) {
      throw new HttpsError('invalid-argument', 'transactionId is required.');
    }

    const txSnapshot = await transactionsCollection.doc(transactionId).get();
    if (!txSnapshot.exists) {
      throw new HttpsError('not-found', 'transaction not found.');
    }
    const txClanId = normalizeString(txSnapshot.data()?.clanId);
    if (txClanId !== clanId) {
      throw new HttpsError('permission-denied', 'transaction clan mismatch.');
    }
    const txOwnerUid = normalizeString(txSnapshot.data()?.subscriptionOwnerUid);
    if (txOwnerUid.length > 0 && txOwnerUid !== auth.uid) {
      throw new HttpsError('permission-denied', 'transaction owner mismatch.');
    }

    const payment = await applyPaymentResult({
      transactionId,
      provider: 'vnpay',
      gatewayReference: `VNPAY-SIM-${transactionId.slice(0, 10)}`,
      paymentStatus: 'succeeded',
      payloadHash: createPayloadHash({ transactionId, actorUid: auth.uid }),
      actorUid: auth.uid,
    });

    await notifyBillingResult({
      clanId,
      approved: true,
      amountVnd: Number(payment.transaction.amountVnd),
      transactionId,
      provider: 'vnpay',
    });

    return {
      status: 'succeeded',
      transactionId,
      subscription: payment.subscription ? serializeSubscription(payment.subscription) : null,
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
    type: approved ? 'billing_payment_succeeded' : 'billing_payment_failed',
    title: approved ? 'Subscription updated successfully' : 'Payment failed',
    body: approved
      ? `Payment ${formatVnd(amountVnd)} via ${provider.toUpperCase()} was confirmed.`
      : `Payment attempt for ${formatVnd(amountVnd)} failed.`,
    target: 'generic',
    targetId: transactionId,
    extraData: {
      transactionId,
      billing: 'true',
      result: approved ? 'success' : 'failed',
      provider,
    },
  });
}

function resolveClanId(token: AuthToken, data: unknown): string {
  const clanIds = tokenClanIds(token);
  const dataClanId = readString(data, 'clanId');
  if (dataClanId != null && dataClanId.length > 0) {
    if (!clanIds.includes(dataClanId)) {
      throw new HttpsError(
        'permission-denied',
        'This session does not have access to the requested clan.',
      );
    }
    return dataClanId;
  }
  return clanIds[0] ?? '';
}

function normalizePaymentMethod(data: unknown): PaymentMethod {
  const method = readString(data, 'paymentMethod')?.toLowerCase();
  if (method === 'card') {
    return 'card';
  }
  if (method === 'vnpay') {
    return 'vnpay';
  }
  throw new HttpsError('invalid-argument', 'paymentMethod must be "card" or "vnpay".');
}

function normalizePaymentModeFromInput(data: unknown): PaymentMode {
  const mode = readString(data, 'paymentMode')?.toLowerCase();
  if (mode === 'manual') {
    return 'manual';
  }
  if (mode === 'auto_renew' || mode === 'auto' || mode === 'automatic') {
    return 'auto_renew';
  }
  throw new HttpsError(
    'invalid-argument',
    'paymentMode must be "manual" or "auto_renew".',
  );
}

function normalizeRequestedPlanCode(data: unknown): BillingPlanCode | null {
  const planCode = readString(data, 'requestedPlanCode')?.toUpperCase();
  if (planCode == null || planCode.length === 0) {
    return null;
  }
  if (planCode === 'FREE' || planCode === 'BASE' || planCode === 'PLUS' || planCode === 'PRO') {
    return planCode;
  }
  throw new HttpsError(
    'invalid-argument',
    'requestedPlanCode must be one of FREE, BASE, PLUS, PRO.',
  );
}

function readReminderDays(data: unknown): Array<number> | undefined {
  if (data == null || typeof data !== 'object') {
    return undefined;
  }
  const raw = (data as Record<string, unknown>).reminderDaysBefore;
  if (!Array.isArray(raw)) {
    return undefined;
  }
  const normalized = raw
    .map((value) => (typeof value === 'number' ? Math.trunc(value) : Number.NaN))
    .filter((value) => Number.isFinite(value) && value > 0 && value <= 60);
  if (normalized.length === 0) {
    return undefined;
  }
  return [...new Set(normalized)].sort((left, right) => right - left);
}

function readString(data: unknown, key: string): string | null {
  if (data == null || typeof data !== 'object') {
    return null;
  }
  const value = (data as Record<string, unknown>)[key];
  if (typeof value !== 'string') {
    return null;
  }
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}

function readBoolean(data: unknown, key: string, fallback: boolean): boolean {
  if (data == null || typeof data !== 'object') {
    return fallback;
  }
  const value = (data as Record<string, unknown>)[key];
  return typeof value === 'boolean' ? value : fallback;
}

function normalizeString(value: unknown): string {
  return typeof value === 'string' ? value.trim() : '';
}

function serializeSubscription(subscription: Record<string, unknown>): Record<string, unknown> {
  return normalizeFirestoreJson(subscription);
}

function normalizeFirestoreJson(source: Record<string, unknown>): Record<string, unknown> {
  const output: Record<string, unknown> = {};
  for (const [key, value] of Object.entries(source)) {
    if (value instanceof Date) {
      output[key] = value.toISOString();
      continue;
    }
    if (
      value != null &&
      typeof value === 'object' &&
      'toDate' in value &&
      typeof (value as { toDate?: unknown }).toDate === 'function'
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
  return createHmac('sha256', process.env.BILLING_WEBHOOK_SECRET ?? 'billing-local-secret')
    .update(JSON.stringify(payload))
    .digest('hex');
}

function buildCardCheckoutHintUrl({
  transactionId,
}: {
  transactionId: string;
}): string {
  const base = process.env.BILLING_CARD_CHECKOUT_URL_BASE ?? 'https://example.com/billing/card';
  const url = new URL(base);
  url.searchParams.set('transactionId', transactionId);
  return url.toString();
}

function buildVnpayCheckoutUrl({
  transactionId,
  amountVnd,
  orderInfo,
  returnUrl,
}: {
  transactionId: string;
  amountVnd: number;
  orderInfo: string;
  returnUrl: string;
}): string {
  const tmnCode = process.env.VNPAY_TMNCODE?.trim() ?? '';
  const hashSecret = process.env.VNPAY_HASH_SECRET?.trim() ?? '';
  if (tmnCode.length === 0 || hashSecret.length === 0) {
    const fallback = new URL(
      process.env.BILLING_VNPAY_FALLBACK_URL ?? 'https://example.com/billing/vnpay',
    );
    fallback.searchParams.set('transactionId', transactionId);
    fallback.searchParams.set('amountVnd', `${amountVnd}`);
    return fallback.toString();
  }

  const now = new Date();
  const createDate = formatVnpTimestamp(now);
  const params: Record<string, string> = {
    vnp_Version: '2.1.0',
    vnp_Command: 'pay',
    vnp_TmnCode: tmnCode,
    vnp_Amount: `${Math.max(0, Math.trunc(amountVnd)) * 100}`,
    vnp_CurrCode: 'VND',
    vnp_TxnRef: transactionId,
    vnp_OrderInfo: orderInfo,
    vnp_OrderType: 'billpayment',
    vnp_Locale: 'vn',
    vnp_ReturnUrl: returnUrl,
    vnp_IpAddr: '127.0.0.1',
    vnp_CreateDate: createDate,
  };

  const queryString = Object.keys(params)
    .sort()
    .map((key) => `${key}=${encodeURIComponent(params[key])}`)
    .join('&');
  const secureHash = createHmac('sha512', hashSecret).update(queryString).digest('hex');
  return `https://sandbox.vnpayment.vn/paymentv2/vpcpay.html?${queryString}&vnp_SecureHash=${secureHash}`;
}

function formatVnpTimestamp(value: Date): string {
  const year = value.getUTCFullYear();
  const month = `${value.getUTCMonth() + 1}`.padStart(2, '0');
  const day = `${value.getUTCDate()}`.padStart(2, '0');
  const hour = `${value.getUTCHours()}`.padStart(2, '0');
  const minute = `${value.getUTCMinutes()}`.padStart(2, '0');
  const second = `${value.getUTCSeconds()}`.padStart(2, '0');
  return `${year}${month}${day}${hour}${minute}${second}`;
}

function formatVnd(amount: number): string {
  return `${Math.max(0, Math.trunc(amount)).toLocaleString('vi-VN')} VND`;
}
