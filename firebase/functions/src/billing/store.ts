import { FieldValue, Timestamp } from 'firebase-admin/firestore';

import {
  buildEntitlement,
  createSubscriptionDraft,
  normalizeSubscriptionStatus,
  type BillingEntitlement,
  type BillingSubscriptionRecord,
} from './subscription-lifecycle';
import {
  BILLING_PRICING_TIERS,
  computeRenewalWindow,
  resolveEffectivePlanCode,
  resolvePlanByMemberCount,
  type BillingPlanCode,
  type BillingTierPricing,
  type PaymentMethod,
  type PaymentMode,
  type PaymentStatus,
  type SubscriptionStatus,
} from './pricing';
import { db } from '../shared/firestore';
import { logInfo, logWarn } from '../shared/logger';

type NullableDate = Date | null;

export type BillingSettingsRecord = {
  id: string;
  clanId: string;
  paymentMode: PaymentMode;
  autoRenew: boolean;
  reminderDaysBefore: Array<number>;
  updatedAt: NullableDate;
};

export type BillingTransactionRecord = {
  id: string;
  clanId: string;
  subscriptionId: string;
  invoiceId: string;
  paymentMethod: PaymentMethod;
  paymentStatus: PaymentStatus;
  planCode: BillingPlanCode;
  memberCount: number;
  amountVnd: number;
  vatIncluded: boolean;
  currency: string;
  gatewayReference: string | null;
  gatewayPayloadHash: string | null;
  createdAt: NullableDate;
  paidAt: NullableDate;
  failedAt: NullableDate;
};

export type BillingInvoiceRecord = {
  id: string;
  clanId: string;
  subscriptionId: string;
  transactionId: string;
  planCode: BillingPlanCode;
  amountVnd: number;
  vatIncluded: boolean;
  currency: string;
  status: 'issued' | 'paid' | 'failed' | 'void';
  periodStart: NullableDate;
  periodEnd: NullableDate;
  issuedAt: NullableDate;
  paidAt: NullableDate;
};

export type EnsureSubscriptionResult = {
  memberCount: number;
  minimumTier: BillingTierPricing;
  tier: BillingTierPricing;
  subscription: BillingSubscriptionRecord;
  entitlement: BillingEntitlement;
  settings: BillingSettingsRecord;
};

const membersCollection = db.collection('members');
const subscriptionsCollection = db.collection('subscriptions');
const billingSettingsCollection = db.collection('billingSettings');
const transactionsCollection = db.collection('paymentTransactions');
const invoicesCollection = db.collection('subscriptionInvoices');
const webhookEventsCollection = db.collection('paymentWebhookEvents');
const billingAuditLogsCollection = db.collection('billingAuditLogs');

export async function countClanMembers(clanId: string): Promise<number> {
  const snapshot = await membersCollection.where('clanId', '==', clanId).count().get();
  return Number(snapshot.data().count ?? 0);
}

export async function loadBillingSettings(clanId: string): Promise<BillingSettingsRecord> {
  const snapshot = await billingSettingsCollection.doc(clanId).get();
  if (!snapshot.exists) {
    return {
      id: clanId,
      clanId,
      paymentMode: 'manual',
      autoRenew: false,
      reminderDaysBefore: [30, 14, 7, 3, 1],
      updatedAt: null,
    };
  }
  const data = snapshot.data() ?? {};
  return {
    id: snapshot.id,
    clanId: readString(data.clanId, clanId),
    paymentMode: normalizePaymentMode(data.paymentMode),
    autoRenew: readBool(data.autoRenew, false),
    reminderDaysBefore: normalizeReminderDays(data.reminderDaysBefore),
    updatedAt: readDate(data.updatedAt),
  };
}

export async function upsertBillingSettings({
  clanId,
  paymentMode,
  autoRenew,
  reminderDaysBefore,
  actorUid,
}: {
  clanId: string;
  paymentMode: PaymentMode;
  autoRenew: boolean;
  reminderDaysBefore?: Array<number>;
  actorUid: string;
}): Promise<BillingSettingsRecord> {
  const normalizedReminderDays = normalizeReminderDays(reminderDaysBefore);
  await billingSettingsCollection.doc(clanId).set(
    {
      id: clanId,
      clanId,
      paymentMode,
      autoRenew,
      reminderDaysBefore: normalizedReminderDays,
      updatedAt: FieldValue.serverTimestamp(),
      updatedBy: actorUid,
      createdAt: FieldValue.serverTimestamp(),
      createdBy: actorUid,
    },
    { merge: true },
  );
  return loadBillingSettings(clanId);
}

export async function loadSubscription(clanId: string): Promise<BillingSubscriptionRecord | null> {
  const snapshot = await subscriptionsCollection.doc(clanId).get();
  if (!snapshot.exists) {
    return null;
  }
  return mapSubscription(snapshot.id, snapshot.data() ?? {});
}

export async function ensureSubscriptionForClan({
  clanId,
  actorUid,
  now = new Date(),
}: {
  clanId: string;
  actorUid: string;
  now?: Date;
}): Promise<EnsureSubscriptionResult> {
  const [memberCount, settings, existing] = await Promise.all([
    countClanMembers(clanId),
    loadBillingSettings(clanId),
    loadSubscription(clanId),
  ]);
  const minimumTier = resolvePlanByMemberCount(memberCount);

  if (existing == null) {
    const seeded = seedSubscription({
      clanId,
      tier: minimumTier,
      memberCount,
      settings,
      now,
    });
    await subscriptionsCollection.doc(clanId).set(
      {
        ...toSubscriptionWriteMap(seeded),
        createdAt: FieldValue.serverTimestamp(),
        createdBy: actorUid,
        updatedAt: FieldValue.serverTimestamp(),
        updatedBy: actorUid,
      },
      { merge: true },
    );
    await writeBillingAuditLog({
      clanId,
      actorUid,
      action: 'subscription_bootstrapped',
      entityType: 'subscription',
      entityId: clanId,
      after: {
        planCode: seeded.planCode,
        status: seeded.status,
        memberCount: seeded.memberCount,
      },
    });
    return {
      memberCount,
      minimumTier,
      tier: minimumTier,
      subscription: seeded,
      entitlement: buildEntitlementFromSubscription(seeded),
      settings,
    };
  }

  const normalizedStatus = normalizeSubscriptionStatus({
    status: existing.status,
    expiresAt: existing.expiresAt,
    graceEndsAt: existing.graceEndsAt,
    now,
  });
  const effectivePlanCode = resolveEffectivePlanCode({
    memberCount,
    currentPlanCode: existing.planCode,
  });
  const targetTier = resolveTierByPlanCode(effectivePlanCode);
  const nextPlanCode = targetTier.planCode;
  const updated: BillingSubscriptionRecord = {
    ...existing,
    planCode: nextPlanCode,
    status: normalizeStatusForPlan({
      planCode: nextPlanCode,
      currentStatus: normalizedStatus,
    }),
    memberCount,
    amountVndYear: targetTier.priceVndYear,
    vatIncluded: targetTier.vatIncluded,
    paymentMode: settings.paymentMode,
    autoRenew: settings.autoRenew,
    updatedAt: now,
  };

  await subscriptionsCollection.doc(clanId).set(
    {
      ...toSubscriptionWriteMap(updated),
      updatedAt: FieldValue.serverTimestamp(),
      updatedBy: actorUid,
    },
    { merge: true },
  );

  return {
    memberCount,
    minimumTier,
    tier: targetTier,
    subscription: updated,
    entitlement: buildEntitlementFromSubscription(updated),
    settings,
  };
}

export async function createPendingCheckout({
  clanId,
  actorUid,
  paymentMethod,
  requestedPlanCode,
  now = new Date(),
}: {
  clanId: string;
  actorUid: string;
  paymentMethod: PaymentMethod;
  requestedPlanCode?: BillingPlanCode;
  now?: Date;
}): Promise<{
  tier: BillingTierPricing;
  memberCount: number;
  subscription: BillingSubscriptionRecord;
  transaction: BillingTransactionRecord;
  invoice: BillingInvoiceRecord;
}> {
  const ensured = await ensureSubscriptionForClan({ clanId, actorUid, now });
  const { memberCount, subscription } = ensured;
  const effectivePlanCode = resolveEffectivePlanCode({
    memberCount,
    currentPlanCode: ensured.tier.planCode,
    requestedPlanCode: requestedPlanCode ?? null,
  });
  const tier = resolveTierByPlanCode(effectivePlanCode);

  const transactionRef = transactionsCollection.doc();
  const invoiceRef = invoicesCollection.doc();
  const gatewayReference = `${paymentMethod.toUpperCase()}-${Date.now()}-${transactionRef.id.slice(0, 8)}`;

  const transaction: BillingTransactionRecord = {
    id: transactionRef.id,
    clanId,
    subscriptionId: subscription.id,
    invoiceId: invoiceRef.id,
    paymentMethod,
    paymentStatus: tier.planCode === 'FREE' ? 'succeeded' : 'pending',
    planCode: tier.planCode,
    memberCount,
    amountVnd: tier.priceVndYear,
    vatIncluded: tier.vatIncluded,
    currency: 'VND',
    gatewayReference,
    gatewayPayloadHash: null,
    createdAt: now,
    paidAt: tier.planCode === 'FREE' ? now : null,
    failedAt: null,
  };

  const invoice: BillingInvoiceRecord = {
    id: invoiceRef.id,
    clanId,
    subscriptionId: subscription.id,
    transactionId: transaction.id,
    planCode: tier.planCode,
    amountVnd: tier.priceVndYear,
    vatIncluded: tier.vatIncluded,
    currency: 'VND',
    status: tier.planCode === 'FREE' ? 'paid' : 'issued',
    periodStart: subscription.startsAt,
    periodEnd: subscription.expiresAt,
    issuedAt: now,
    paidAt: tier.planCode === 'FREE' ? now : null,
  };

  const batch = db.batch();
  batch.set(transactionRef, {
    ...toTransactionWriteMap(transaction),
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
    createdBy: actorUid,
    updatedBy: actorUid,
  });
  batch.set(invoiceRef, {
    ...toInvoiceWriteMap(invoice),
    issuedAt: FieldValue.serverTimestamp(),
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
    createdBy: actorUid,
    updatedBy: actorUid,
  });
  batch.set(
    subscriptionsCollection.doc(clanId),
    {
      planCode: tier.planCode,
      memberCount,
      amountVndYear: tier.priceVndYear,
      vatIncluded: tier.vatIncluded,
      status: tier.planCode === 'FREE' ? 'active' : 'pending_payment',
      lastTransactionId: transaction.id,
      lastInvoiceId: invoice.id,
      lastPaymentMethod: paymentMethod,
      updatedAt: FieldValue.serverTimestamp(),
      updatedBy: actorUid,
    },
    { merge: true },
  );
  await batch.commit();

  await writeBillingAuditLog({
    clanId,
    actorUid,
    action: 'checkout_created',
    entityType: 'paymentTransaction',
    entityId: transaction.id,
    after: {
      planCode: transaction.planCode,
      amountVnd: transaction.amountVnd,
      paymentMethod,
      invoiceId: invoice.id,
    },
  });

  const checkoutSubscription: BillingSubscriptionRecord = {
    ...subscription,
    planCode: tier.planCode,
    memberCount,
    amountVndYear: tier.priceVndYear,
    vatIncluded: tier.vatIncluded,
    status: tier.planCode === 'FREE' ? 'active' : 'pending_payment',
    lastPaymentMethod: paymentMethod,
    lastTransactionId: transaction.id,
    updatedAt: now,
  };

  return { tier, memberCount, subscription: checkoutSubscription, transaction, invoice };
}

export async function recordPaymentWebhookEvent({
  provider,
  externalEventId,
  transactionId,
  payloadHash,
  validSignature,
  rawPayload,
}: {
  provider: string;
  externalEventId: string;
  transactionId: string;
  payloadHash: string;
  validSignature: boolean;
  rawPayload: Record<string, unknown>;
}): Promise<{ id: string; alreadyProcessed: boolean }> {
  const key = `${provider}:${externalEventId}`;
  const ref = webhookEventsCollection.doc(key);
  const existing = await ref.get();
  if (existing.exists) {
    return { id: key, alreadyProcessed: true };
  }

  await ref.set({
    id: key,
    provider,
    externalEventId,
    transactionId,
    payloadHash,
    validSignature,
    rawPayload,
    processedAt: FieldValue.serverTimestamp(),
    createdAt: FieldValue.serverTimestamp(),
  });

  return { id: key, alreadyProcessed: false };
}

export async function applyPaymentResult({
  transactionId,
  provider,
  gatewayReference,
  paymentStatus,
  payloadHash,
  actorUid,
  now = new Date(),
}: {
  transactionId: string;
  provider: string;
  gatewayReference: string;
  paymentStatus: Extract<PaymentStatus, 'succeeded' | 'failed' | 'canceled'>;
  payloadHash: string;
  actorUid: string;
  now?: Date;
}): Promise<{
  clanId: string;
  transaction: BillingTransactionRecord;
  invoice: BillingInvoiceRecord | null;
  subscription: BillingSubscriptionRecord | null;
}> {
  const transactionRef = transactionsCollection.doc(transactionId);
  const txnSnapshot = await transactionRef.get();
  if (!txnSnapshot.exists) {
    throw new Error(`payment transaction ${transactionId} not found`);
  }

  const transactionData = mapTransaction(transactionId, txnSnapshot.data() ?? {});
  if (transactionData.paymentStatus === 'succeeded' && paymentStatus === 'succeeded') {
    const subscription = await loadSubscription(transactionData.clanId);
    const invoice = await loadInvoice(transactionData.invoiceId);
    return {
      clanId: transactionData.clanId,
      transaction: transactionData,
      invoice,
      subscription,
    };
  }

  const invoiceRef = invoicesCollection.doc(transactionData.invoiceId);
  const subscriptionRef = subscriptionsCollection.doc(transactionData.clanId);

  await db.runTransaction(async (tx) => {
    const [invoiceSnapshot, subscriptionSnapshot] = await Promise.all([
      tx.get(invoiceRef),
      tx.get(subscriptionRef),
    ]);

    const existingSubscription = subscriptionSnapshot.exists
      ? mapSubscription(subscriptionSnapshot.id, subscriptionSnapshot.data() ?? {})
      : null;

    const transactionWrite: Record<string, unknown> = {
      paymentStatus,
      gatewayReference,
      gatewayPayloadHash: payloadHash,
      provider,
      updatedAt: FieldValue.serverTimestamp(),
      updatedBy: actorUid,
    };
    if (paymentStatus === 'succeeded') {
      transactionWrite.paidAt = FieldValue.serverTimestamp();
      transactionWrite.failedAt = null;
    } else {
      transactionWrite.failedAt = FieldValue.serverTimestamp();
    }
    tx.set(transactionRef, transactionWrite, { merge: true });

    if (invoiceSnapshot.exists) {
      tx.set(
        invoiceRef,
        {
          status: paymentStatus === 'succeeded' ? 'paid' : 'failed',
          paidAt: paymentStatus === 'succeeded' ? FieldValue.serverTimestamp() : null,
          updatedAt: FieldValue.serverTimestamp(),
          updatedBy: actorUid,
        },
        { merge: true },
      );
    }

    if (paymentStatus === 'succeeded') {
      const tier = resolvePlanByMemberCount(transactionData.memberCount);
      const anchorStart = existingSubscription?.expiresAt != null &&
          existingSubscription.expiresAt.getTime() > now.getTime()
        ? existingSubscription.expiresAt
        : now;
      const { startsAt, expiresAt } = computeRenewalWindow({
        now: anchorStart,
        years: 1,
      });
      const paymentMode = existingSubscription?.paymentMode ?? 'manual';
      const autoRenew = existingSubscription?.autoRenew ?? false;

      tx.set(
        subscriptionRef,
        {
          id: transactionData.clanId,
          clanId: transactionData.clanId,
          planCode: tier.planCode,
          status: 'active',
          memberCount: transactionData.memberCount,
          amountVndYear: tier.priceVndYear,
          vatIncluded: tier.vatIncluded,
          paymentMode,
          autoRenew,
          showAds: tier.showAds,
          adFree: tier.adFree,
          startsAt: Timestamp.fromDate(startsAt),
          expiresAt: Timestamp.fromDate(expiresAt),
          nextPaymentDueAt: Timestamp.fromDate(expiresAt),
          graceEndsAt: null,
          lastPaymentMethod: transactionData.paymentMethod,
          lastTransactionId: transactionData.id,
          lastInvoiceId: transactionData.invoiceId,
          updatedAt: FieldValue.serverTimestamp(),
          updatedBy: actorUid,
          createdAt: FieldValue.serverTimestamp(),
          createdBy: actorUid,
        },
        { merge: true },
      );
    } else {
      tx.set(
        subscriptionRef,
        {
          status: 'expired',
          updatedAt: FieldValue.serverTimestamp(),
          updatedBy: actorUid,
        },
        { merge: true },
      );
    }

    const auditRef = billingAuditLogsCollection.doc();
    tx.set(auditRef, {
      id: auditRef.id,
      clanId: transactionData.clanId,
      actorUid,
      action: paymentStatus === 'succeeded' ? 'payment_succeeded' : 'payment_failed',
      entityType: 'paymentTransaction',
      entityId: transactionData.id,
      before: {
        status: transactionData.paymentStatus,
      },
      after: {
        status: paymentStatus,
        provider,
        gatewayReference,
      },
      createdAt: FieldValue.serverTimestamp(),
    });
  });

  const [refreshedTransaction, refreshedSubscription, refreshedInvoice] = await Promise.all([
    transactionsCollection.doc(transactionId).get(),
    subscriptionsCollection.doc(transactionData.clanId).get(),
    invoicesCollection.doc(transactionData.invoiceId).get(),
  ]);

  return {
    clanId: transactionData.clanId,
    transaction: mapTransaction(transactionId, refreshedTransaction.data() ?? {}),
    invoice: refreshedInvoice.exists
      ? mapInvoice(refreshedInvoice.id, refreshedInvoice.data() ?? {})
      : null,
    subscription: refreshedSubscription.exists
      ? mapSubscription(refreshedSubscription.id, refreshedSubscription.data() ?? {})
      : null,
  };
}

export async function resolveBillingAudienceMemberIds(clanId: string): Promise<Array<string>> {
  const snapshot = await membersCollection.where('clanId', '==', clanId).limit(1000).get();
  const adminRoles = new Set(['SUPER_ADMIN', 'CLAN_ADMIN', 'BRANCH_ADMIN']);
  return snapshot.docs
    .filter((doc) => {
      const role = readString(doc.data().primaryRole, '').toUpperCase();
      return adminRoles.has(role);
    })
    .map((doc) => doc.id);
}

export async function writeBillingAuditLog({
  clanId,
  actorUid,
  action,
  entityType,
  entityId,
  before,
  after,
}: {
  clanId: string;
  actorUid: string;
  action: string;
  entityType: string;
  entityId: string;
  before?: Record<string, unknown>;
  after?: Record<string, unknown>;
}): Promise<void> {
  const ref = billingAuditLogsCollection.doc();
  await ref.set({
    id: ref.id,
    clanId,
    actorUid,
    action,
    entityType,
    entityId,
    before: before ?? null,
    after: after ?? null,
    createdAt: FieldValue.serverTimestamp(),
  });
}

export function buildEntitlementFromSubscription(
  subscription: BillingSubscriptionRecord,
): BillingEntitlement {
  const status = normalizeSubscriptionStatus({
    status: subscription.status,
    expiresAt: subscription.expiresAt,
    graceEndsAt: subscription.graceEndsAt,
  });
  return buildEntitlement({
    planCode: subscription.planCode,
    status,
    expiresAt: subscription.expiresAt,
    nextPaymentDueAt: subscription.nextPaymentDueAt,
  });
}

export function resolveTierByPlanCode(planCode: BillingPlanCode): BillingTierPricing {
  const matched = BILLING_PRICING_TIERS.find((tier) => tier.planCode === planCode);
  return matched ?? BILLING_PRICING_TIERS[0];
}

function normalizeStatusForPlan({
  planCode,
  currentStatus,
}: {
  planCode: BillingPlanCode;
  currentStatus: SubscriptionStatus;
}): SubscriptionStatus {
  if (planCode === 'FREE') {
    return 'active';
  }
  if (currentStatus === 'active' || currentStatus === 'grace_period') {
    return currentStatus;
  }
  if (currentStatus === 'pending_payment') {
    return currentStatus;
  }
  return 'expired';
}

function seedSubscription({
  clanId,
  tier,
  memberCount,
  settings,
  now,
}: {
  clanId: string;
  tier: BillingTierPricing;
  memberCount: number;
  settings: BillingSettingsRecord;
  now: Date;
}): BillingSubscriptionRecord {
  if (tier.planCode === 'FREE') {
    return createSubscriptionDraft({
      clanId,
      tier,
      memberCount,
      paymentMode: settings.paymentMode,
      autoRenew: settings.autoRenew,
      startsAt: now,
      expiresAt: null,
      status: 'active',
      now,
    });
  }

  return createSubscriptionDraft({
    clanId,
    tier,
    memberCount,
    paymentMode: settings.paymentMode,
    autoRenew: settings.autoRenew,
    startsAt: null,
    expiresAt: now,
    status: 'expired',
    now,
  });
}

function toSubscriptionWriteMap(record: BillingSubscriptionRecord): Record<string, unknown> {
  return {
    id: record.id,
    clanId: record.clanId,
    planCode: record.planCode,
    status: record.status,
    memberCount: record.memberCount,
    amountVndYear: record.amountVndYear,
    vatIncluded: record.vatIncluded,
    paymentMode: record.paymentMode,
    autoRenew: record.autoRenew,
    showAds: buildEntitlementFromSubscription(record).showAds,
    adFree: buildEntitlementFromSubscription(record).adFree,
    startsAt: toTimestamp(record.startsAt),
    expiresAt: toTimestamp(record.expiresAt),
    nextPaymentDueAt: toTimestamp(record.nextPaymentDueAt),
    graceEndsAt: toTimestamp(record.graceEndsAt),
    lastPaymentMethod: record.lastPaymentMethod,
    lastTransactionId: record.lastTransactionId,
  };
}

function toTransactionWriteMap(record: BillingTransactionRecord): Record<string, unknown> {
  return {
    id: record.id,
    clanId: record.clanId,
    subscriptionId: record.subscriptionId,
    invoiceId: record.invoiceId,
    paymentMethod: record.paymentMethod,
    paymentStatus: record.paymentStatus,
    planCode: record.planCode,
    memberCount: record.memberCount,
    amountVnd: record.amountVnd,
    vatIncluded: record.vatIncluded,
    currency: record.currency,
    gatewayReference: record.gatewayReference,
    gatewayPayloadHash: record.gatewayPayloadHash,
    paidAt: toTimestamp(record.paidAt),
    failedAt: toTimestamp(record.failedAt),
  };
}

function toInvoiceWriteMap(record: BillingInvoiceRecord): Record<string, unknown> {
  return {
    id: record.id,
    clanId: record.clanId,
    subscriptionId: record.subscriptionId,
    transactionId: record.transactionId,
    planCode: record.planCode,
    amountVnd: record.amountVnd,
    vatIncluded: record.vatIncluded,
    currency: record.currency,
    status: record.status,
    periodStart: toTimestamp(record.periodStart),
    periodEnd: toTimestamp(record.periodEnd),
    paidAt: toTimestamp(record.paidAt),
  };
}

function mapSubscription(id: string, data: Record<string, unknown>): BillingSubscriptionRecord {
  return {
    id,
    clanId: readString(data.clanId, ''),
    planCode: normalizePlanCode(data.planCode),
    status: normalizeSubscriptionStatusCode(data.status),
    memberCount: readNumber(data.memberCount, 0),
    amountVndYear: readNumber(data.amountVndYear, 0),
    vatIncluded: readBool(data.vatIncluded, true),
    paymentMode: normalizePaymentMode(data.paymentMode),
    autoRenew: readBool(data.autoRenew, false),
    startsAt: readDate(data.startsAt),
    expiresAt: readDate(data.expiresAt),
    nextPaymentDueAt: readDate(data.nextPaymentDueAt),
    graceEndsAt: readDate(data.graceEndsAt),
    lastPaymentMethod: nullableString(data.lastPaymentMethod),
    lastTransactionId: nullableString(data.lastTransactionId),
    updatedAt: readDate(data.updatedAt),
  };
}

function mapTransaction(id: string, data: Record<string, unknown>): BillingTransactionRecord {
  return {
    id,
    clanId: readString(data.clanId, ''),
    subscriptionId: readString(data.subscriptionId, ''),
    invoiceId: readString(data.invoiceId, ''),
    paymentMethod: normalizePaymentMethod(data.paymentMethod),
    paymentStatus: normalizePaymentStatus(data.paymentStatus),
    planCode: normalizePlanCode(data.planCode),
    memberCount: readNumber(data.memberCount, 0),
    amountVnd: readNumber(data.amountVnd, 0),
    vatIncluded: readBool(data.vatIncluded, true),
    currency: readString(data.currency, 'VND'),
    gatewayReference: nullableString(data.gatewayReference),
    gatewayPayloadHash: nullableString(data.gatewayPayloadHash),
    createdAt: readDate(data.createdAt),
    paidAt: readDate(data.paidAt),
    failedAt: readDate(data.failedAt),
  };
}

function mapInvoice(id: string, data: Record<string, unknown>): BillingInvoiceRecord {
  return {
    id,
    clanId: readString(data.clanId, ''),
    subscriptionId: readString(data.subscriptionId, ''),
    transactionId: readString(data.transactionId, ''),
    planCode: normalizePlanCode(data.planCode),
    amountVnd: readNumber(data.amountVnd, 0),
    vatIncluded: readBool(data.vatIncluded, true),
    currency: readString(data.currency, 'VND'),
    status: normalizeInvoiceStatus(data.status),
    periodStart: readDate(data.periodStart),
    periodEnd: readDate(data.periodEnd),
    issuedAt: readDate(data.issuedAt),
    paidAt: readDate(data.paidAt),
  };
}

async function loadInvoice(invoiceId: string): Promise<BillingInvoiceRecord | null> {
  if (invoiceId.trim().length === 0) {
    return null;
  }
  const snapshot = await invoicesCollection.doc(invoiceId).get();
  if (!snapshot.exists) {
    return null;
  }
  return mapInvoice(snapshot.id, snapshot.data() ?? {});
}

function normalizePlanCode(value: unknown): BillingPlanCode {
  const normalized = readString(value, 'FREE').toUpperCase();
  if (normalized === 'BASE' || normalized === 'PLUS' || normalized === 'PRO') {
    return normalized;
  }
  return 'FREE';
}

function normalizeSubscriptionStatusCode(value: unknown): SubscriptionStatus {
  const normalized = readString(value, 'expired').toLowerCase();
  switch (normalized) {
    case 'active':
      return 'active';
    case 'grace_period':
      return 'grace_period';
    case 'pending_payment':
      return 'pending_payment';
    case 'canceled':
      return 'canceled';
    default:
      return 'expired';
  }
}

function normalizePaymentMode(value: unknown): PaymentMode {
  return readString(value, 'manual').toLowerCase() === 'auto_renew'
    ? 'auto_renew'
    : 'manual';
}

function normalizePaymentMethod(value: unknown): PaymentMethod {
  return readString(value, 'card').toLowerCase() === 'vnpay' ? 'vnpay' : 'card';
}

function normalizePaymentStatus(value: unknown): PaymentStatus {
  const normalized = readString(value, 'created').toLowerCase();
  switch (normalized) {
    case 'pending':
      return 'pending';
    case 'succeeded':
      return 'succeeded';
    case 'failed':
      return 'failed';
    case 'canceled':
      return 'canceled';
    default:
      return 'created';
  }
}

function normalizeInvoiceStatus(
  value: unknown,
): BillingInvoiceRecord['status'] {
  const normalized = readString(value, 'issued').toLowerCase();
  switch (normalized) {
    case 'paid':
      return 'paid';
    case 'failed':
      return 'failed';
    case 'void':
      return 'void';
    default:
      return 'issued';
  }
}

function normalizeReminderDays(value: unknown): Array<number> {
  const fallback = [30, 14, 7, 3, 1];
  if (!Array.isArray(value)) {
    return fallback;
  }
  const values = value
    .map((item) => (typeof item === 'number' ? Math.trunc(item) : Number.NaN))
    .filter((item) => Number.isFinite(item) && item > 0 && item <= 60);
  if (values.length === 0) {
    return fallback;
  }
  return [...new Set(values)].sort((left, right) => right - left);
}

function readDate(value: unknown): NullableDate {
  if (value == null) {
    return null;
  }
  if (value instanceof Timestamp) {
    return value.toDate();
  }
  if (value instanceof Date) {
    return value;
  }
  if (
    typeof value === 'object' &&
    value != null &&
    'toDate' in value &&
    typeof (value as { toDate?: unknown }).toDate === 'function'
  ) {
    try {
      return (value as { toDate: () => Date }).toDate();
    } catch {
      return null;
    }
  }
  if (typeof value === 'string') {
    const parsed = new Date(value);
    if (!Number.isNaN(parsed.getTime())) {
      return parsed;
    }
  }
  return null;
}

function readString(value: unknown, fallback: string): string {
  return typeof value === 'string' && value.trim().length > 0
    ? value.trim()
    : fallback;
}

function nullableString(value: unknown): string | null {
  if (typeof value !== 'string') {
    return null;
  }
  const trimmed = value.trim();
  return trimmed.length === 0 ? null : trimmed;
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

function readBool(value: unknown, fallback: boolean): boolean {
  return typeof value === 'boolean' ? value : fallback;
}

function toTimestamp(value: NullableDate): Timestamp | null {
  if (value == null) {
    return null;
  }
  return Timestamp.fromDate(value);
}
