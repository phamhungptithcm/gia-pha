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
  rankPlanCode,
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
import { logWarn } from '../shared/logger';

type NullableDate = Date | null;

export type BillingSettingsRecord = {
  id: string;
  clanId: string;
  ownerUid: string;
  paymentMode: PaymentMode;
  autoRenew: boolean;
  reminderDaysBefore: Array<number>;
  updatedAt: NullableDate;
};

export type BillingTransactionRecord = {
  id: string;
  clanId: string;
  subscriptionOwnerUid: string;
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
  subscriptionOwnerUid: string;
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

export type BillingOwnerClanSummary = {
  clanId: string;
  clanName: string;
  ownerUid: string;
  clanStatus: string;
  memberCount: number;
  ownerDisplayName: string | null;
};

export type OwnerBillingPolicySummary = {
  ownerUid: string;
  clans: Array<BillingOwnerClanSummary>;
  totalMemberCount: number;
  minimumTier: BillingTierPricing;
  highestActiveTier: BillingTierPricing;
  highestActivePlanCode: BillingPlanCode;
  hasSufficientActivePlan: boolean;
};

const membersCollection = db.collection('members');
const clansCollection = db.collection('clans');
const subscriptionsCollection = db.collection('subscriptions');
const billingSettingsCollection = db.collection('billingSettings');
const transactionsCollection = db.collection('paymentTransactions');
const invoicesCollection = db.collection('subscriptionInvoices');
const webhookEventsCollection = db.collection('paymentWebhookEvents');
const billingAuditLogsCollection = db.collection('billingAuditLogs');

function scopedBillingDocId({
  clanId,
  ownerUid,
}: {
  clanId: string;
  ownerUid: string;
}): string {
  return `${clanId}__${ownerUid}`;
}

function personalBillingScopeId(uid: string): string {
  return `user_scope__${uid.trim()}`;
}

function ownerBillingDocId(ownerUid: string): string {
  const ownerScopeId = personalBillingScopeId(ownerUid);
  return scopedBillingDocId({ clanId: ownerScopeId, ownerUid });
}

export async function countClanMembers(clanId: string): Promise<number> {
  const snapshot = await membersCollection.where('clanId', '==', clanId).count().get();
  return Number(snapshot.data().count ?? 0);
}

export async function listOwnerClansForBilling(ownerUid: string): Promise<Array<BillingOwnerClanSummary>> {
  const normalizedOwnerUid = ownerUid.trim();
  if (normalizedOwnerUid.length === 0) {
    return [];
  }

  const ownerSnapshot = await clansCollection
    .where('ownerUid', '==', normalizedOwnerUid)
    .limit(400)
    .get();
  const clanById = new Map<string, BillingOwnerClanSummary>();
  for (const snapshot of ownerSnapshot.docs) {
    const data = snapshot.data() ?? {};
    const resolvedOwnerUid = readString(data.ownerUid, '');
    if (resolvedOwnerUid !== normalizedOwnerUid) {
      continue;
    }
    clanById.set(snapshot.id, {
      clanId: snapshot.id,
      clanName: readString(data.name, snapshot.id),
      ownerUid: resolvedOwnerUid,
      clanStatus: normalizeClanStatus(data.status),
      memberCount: Math.max(0, readNumber(data.memberCount, 0)),
      ownerDisplayName: nullableString(data.founderName),
    });
  }
  return [...clanById.values()].sort((left, right) => left.clanId.localeCompare(right.clanId));
}

export async function resolveOwnerBillingPolicy({
  ownerUid,
  now = new Date(),
}: {
  ownerUid: string;
  now?: Date;
}): Promise<OwnerBillingPolicySummary> {
  const normalizedOwnerUid = ownerUid.trim();
  if (normalizedOwnerUid.length === 0) {
    const freeTier = resolveTierByPlanCode('FREE');
    return {
      ownerUid: '',
      clans: [],
      totalMemberCount: 0,
      minimumTier: freeTier,
      highestActiveTier: freeTier,
      highestActivePlanCode: freeTier.planCode,
      hasSufficientActivePlan: true,
    };
  }

  const clans = await listOwnerClansForBilling(normalizedOwnerUid);
  if (clans.length === 0) {
    const freeTier = resolveTierByPlanCode('FREE');
    return {
      ownerUid: normalizedOwnerUid,
      clans: [],
      totalMemberCount: 0,
      minimumTier: freeTier,
      highestActiveTier: freeTier,
      highestActivePlanCode: freeTier.planCode,
      hasSufficientActivePlan: true,
    };
  }

  const authoritativeCounts = await Promise.all(
    clans.map(async (clan) => {
      try {
        return await countClanMembers(clan.clanId);
      } catch {
        return clan.memberCount;
      }
    }),
  );
  const clansWithCounts = clans.map((clan, index) => ({
    ...clan,
    memberCount: Math.max(0, authoritativeCounts[index] ?? clan.memberCount),
  }));
  const totalMemberCount = clansWithCounts.reduce((sum, clan) => sum + clan.memberCount, 0);
  const minimumTier = resolvePlanByMemberCount(totalMemberCount);

  const subscriptionsById = new Map<string, FirebaseFirestore.DocumentSnapshot<FirebaseFirestore.DocumentData>>();
  const ownerSubscriptions = await subscriptionsCollection
    .where('ownerUid', '==', normalizedOwnerUid)
    .limit(400)
    .get();
  for (const doc of ownerSubscriptions.docs) {
    subscriptionsById.set(doc.id, doc);
  }

  const ownerScopedSubscriptionId = ownerBillingDocId(normalizedOwnerUid);
  const fallbackSnapshots = await Promise.all([
    subscriptionsCollection.doc(ownerScopedSubscriptionId).get(),
    ...clansWithCounts.flatMap((clan) => [
      subscriptionsCollection.doc(scopedBillingDocId({
        clanId: clan.clanId,
        ownerUid: normalizedOwnerUid,
      })).get(),
      subscriptionsCollection.doc(clan.clanId).get(),
    ]),
  ]);
  for (const snapshot of fallbackSnapshots) {
    if (!snapshot.exists) {
      continue;
    }
    subscriptionsById.set(snapshot.id, snapshot);
  }

  let highestActiveTier = resolveTierByPlanCode('FREE');
  for (const clan of clansWithCounts) {
    const ownerScopedId = ownerScopedSubscriptionId;
    const scopedId = scopedBillingDocId({
      clanId: clan.clanId,
      ownerUid: normalizedOwnerUid,
    });
    const source =
      subscriptionsById.get(ownerScopedId) ??
      subscriptionsById.get(scopedId) ??
      subscriptionsById.get(clan.clanId);
    if (source == null || !source.exists) {
      continue;
    }
    const subscription = mapSubscription(source.id, source.data() ?? {}, {
      fallbackClanId: clan.clanId,
      fallbackOwnerUid: normalizedOwnerUid,
    });
    const normalizedStatus = normalizeSubscriptionStatus({
      status: subscription.status,
      expiresAt: subscription.expiresAt,
      graceEndsAt: subscription.graceEndsAt,
      now,
    });
    if (normalizedStatus !== 'active' && normalizedStatus !== 'grace_period') {
      continue;
    }
    const candidateTier = resolveTierByPlanCode(subscription.planCode);
    if (rankPlanCode(candidateTier.planCode) > rankPlanCode(highestActiveTier.planCode)) {
      highestActiveTier = candidateTier;
    }
  }

  return {
    ownerUid: normalizedOwnerUid,
    clans: clansWithCounts,
    totalMemberCount,
    minimumTier,
    highestActiveTier,
    highestActivePlanCode: highestActiveTier.planCode,
    hasSufficientActivePlan:
      rankPlanCode(highestActiveTier.planCode) >= rankPlanCode(minimumTier.planCode),
  };
}

export async function loadBillingSettings(
  clanId: string,
  ownerUid: string,
): Promise<BillingSettingsRecord> {
  const ownerScopedId = ownerBillingDocId(ownerUid);
  const scopedId = scopedBillingDocId({ clanId, ownerUid });
  const [ownerScopedSnapshot, scopedSnapshot, legacySnapshot] = await Promise.all([
    billingSettingsCollection.doc(ownerScopedId).get(),
    billingSettingsCollection.doc(scopedId).get(),
    billingSettingsCollection.doc(clanId).get(),
  ]);
  const snapshot = ownerScopedSnapshot.exists
    ? ownerScopedSnapshot
    : scopedSnapshot.exists
      ? scopedSnapshot
      : legacySnapshot;
  if (!snapshot.exists) {
    return {
      id: ownerScopedId,
      clanId: personalBillingScopeId(ownerUid),
      ownerUid,
      paymentMode: 'manual',
      autoRenew: false,
      reminderDaysBefore: [30, 14, 7, 3, 1],
      updatedAt: null,
    };
  }
  const data = snapshot.data() ?? {};
  return {
    id: ownerScopedId,
    clanId: readString(data.clanId, personalBillingScopeId(ownerUid)),
    ownerUid: readString(data.ownerUid, ownerUid),
    paymentMode: normalizePaymentMode(data.paymentMode),
    autoRenew: readBool(data.autoRenew, false),
    reminderDaysBefore: normalizeReminderDays(data.reminderDaysBefore),
    updatedAt: readDate(data.updatedAt),
  };
}

export async function upsertBillingSettings({
  clanId,
  ownerUid,
  paymentMode,
  autoRenew,
  reminderDaysBefore,
  actorUid,
}: {
  clanId: string;
  ownerUid: string;
  paymentMode: PaymentMode;
  autoRenew: boolean;
  reminderDaysBefore?: Array<number>;
  actorUid: string;
}): Promise<BillingSettingsRecord> {
  const scopedId = ownerBillingDocId(ownerUid);
  const normalizedReminderDays = normalizeReminderDays(reminderDaysBefore);
  await billingSettingsCollection.doc(scopedId).set(
    {
      id: scopedId,
      clanId: personalBillingScopeId(ownerUid),
      ownerUid,
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
  return loadBillingSettings(clanId, ownerUid);
}

export async function loadSubscription({
  clanId,
  ownerUid,
}: {
  clanId: string;
  ownerUid: string;
}): Promise<BillingSubscriptionRecord | null> {
  const ownerScopedId = ownerBillingDocId(ownerUid);
  const scopedId = scopedBillingDocId({ clanId, ownerUid });
  const [ownerScopedSnapshot, scopedSnapshot, legacySnapshot] = await Promise.all([
    subscriptionsCollection.doc(ownerScopedId).get(),
    subscriptionsCollection.doc(scopedId).get(),
    subscriptionsCollection.doc(clanId).get(),
  ]);
  const snapshot = ownerScopedSnapshot.exists
    ? ownerScopedSnapshot
    : scopedSnapshot.exists
      ? scopedSnapshot
      : legacySnapshot;
  if (!snapshot.exists) {
    return null;
  }
  return mapSubscription(snapshot.id, snapshot.data() ?? {}, {
    fallbackClanId: clanId,
    fallbackOwnerUid: ownerUid,
  });
}

export async function ensureSubscriptionForClan({
  clanId,
  ownerUid,
  actorUid = ownerUid,
  now = new Date(),
}: {
  clanId: string;
  ownerUid: string;
  actorUid?: string;
  now?: Date;
}): Promise<EnsureSubscriptionResult> {
  const scopedSubscriptionId = ownerBillingDocId(ownerUid);
  const [memberCount, settings, existing] = await Promise.all([
    countClanMembers(clanId),
    loadBillingSettings(clanId, ownerUid),
    loadSubscription({ clanId, ownerUid }),
  ]);
  const minimumTier = resolvePlanByMemberCount(memberCount);

  if (existing == null) {
    const seededDraft = seedSubscription({
      clanId,
      ownerUid,
      tier: minimumTier,
      memberCount,
      settings,
      now,
    });
    const seeded: BillingSubscriptionRecord = {
      ...seededDraft,
      id: scopedSubscriptionId,
      clanId: personalBillingScopeId(ownerUid),
      ownerUid,
    };
    await subscriptionsCollection.doc(scopedSubscriptionId).set(
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
      entityId: scopedSubscriptionId,
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
  const targetTier = resolveTierByPlanCode(existing.planCode);
  const updated: BillingSubscriptionRecord = {
    ...existing,
    id: scopedSubscriptionId,
    clanId: personalBillingScopeId(ownerUid),
    ownerUid,
    planCode: existing.planCode,
    status: normalizeStatusForPlan({
      planCode: existing.planCode,
      currentStatus: normalizedStatus,
    }),
    memberCount,
    amountVndYear: targetTier.priceVndYear,
    vatIncluded: targetTier.vatIncluded,
    paymentMode: settings.paymentMode,
    autoRenew: settings.autoRenew,
    updatedAt: now,
  };

  await subscriptionsCollection.doc(scopedSubscriptionId).set(
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
  ownerUid,
  actorUid = ownerUid,
  paymentMethod,
  requestedPlanCode,
  policyMemberCount,
  now = new Date(),
}: {
  clanId: string;
  ownerUid: string;
  actorUid?: string;
  paymentMethod: PaymentMethod;
  requestedPlanCode?: BillingPlanCode;
  policyMemberCount?: number;
  now?: Date;
}): Promise<{
  tier: BillingTierPricing;
  memberCount: number;
  subscription: BillingSubscriptionRecord;
  transaction: BillingTransactionRecord;
  invoice: BillingInvoiceRecord;
}> {
  const ensured = await ensureSubscriptionForClan({
    clanId,
    ownerUid,
    actorUid,
    now,
  });
  const { memberCount, subscription } = ensured;
  const effectiveMemberCountForPolicy = typeof policyMemberCount === 'number' &&
      Number.isFinite(policyMemberCount)
    ? Math.max(memberCount, Math.trunc(policyMemberCount))
    : memberCount;
  const effectivePlanCode = resolveEffectivePlanCode({
    memberCount: effectiveMemberCountForPolicy,
    currentPlanCode: ensured.tier.planCode,
    requestedPlanCode: requestedPlanCode ?? null,
  });
  const tier = resolveTierByPlanCode(effectivePlanCode);
  const selectedRank = rankPlanCode(tier.planCode);
  const canRenewCurrent = canRenewCurrentPlan(subscription, now);
  if (selectedRank === rankPlanCode(subscription.planCode) && !canRenewCurrent) {
    throw new Error(
      'Current subscription is not in renewal window yet.',
    );
  }

  const transactionRef = transactionsCollection.doc();
  const invoiceRef = invoicesCollection.doc();
  const gatewayReference = `${paymentMethod.toUpperCase()}-${Date.now()}-${transactionRef.id.slice(0, 8)}`;

  const transaction: BillingTransactionRecord = {
    id: transactionRef.id,
    clanId,
    subscriptionOwnerUid: ownerUid,
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
    subscriptionOwnerUid: ownerUid,
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
  const keepCurrentPlanUntilPaid = tier.planCode !== 'FREE';
  batch.set(
    subscriptionsCollection.doc(subscription.id),
    {
      id: subscription.id,
      clanId,
      ownerUid,
      planCode: keepCurrentPlanUntilPaid ? subscription.planCode : tier.planCode,
      memberCount,
      amountVndYear: keepCurrentPlanUntilPaid
        ? subscription.amountVndYear
        : tier.priceVndYear,
      vatIncluded: keepCurrentPlanUntilPaid
        ? subscription.vatIncluded
        : tier.vatIncluded,
      status: keepCurrentPlanUntilPaid ? subscription.status : 'active',
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
    planCode: keepCurrentPlanUntilPaid ? subscription.planCode : tier.planCode,
    memberCount,
    amountVndYear: keepCurrentPlanUntilPaid
      ? subscription.amountVndYear
      : tier.priceVndYear,
    vatIncluded: keepCurrentPlanUntilPaid
      ? subscription.vatIncluded
      : tier.vatIncluded,
    status: keepCurrentPlanUntilPaid ? subscription.status : 'active',
    lastPaymentMethod: paymentMethod,
    lastTransactionId: transaction.id,
    updatedAt: now,
  };

  return { tier, memberCount, subscription: checkoutSubscription, transaction, invoice };
}

export async function cancelStalePendingTransactionsRun({
  source,
  now = new Date(),
  timeoutMinutes = 20,
  clanId,
  ownerUid,
  limit = 300,
}: {
  source: string;
  now?: Date;
  timeoutMinutes?: number;
  clanId?: string;
  ownerUid?: string;
  limit?: number;
}): Promise<{
  scanned: number;
  canceled: number;
  skippedFresh: number;
  skippedScopeMismatch: number;
  failed: number;
}> {
  const safeTimeoutMinutes = Math.max(1, Math.min(180, Math.trunc(timeoutMinutes)));
  const timeoutMs = safeTimeoutMinutes * 60 * 1000;
  const scopeClanId = (clanId ?? '').trim();
  const scopeOwnerUid = (ownerUid ?? '').trim();

  const snapshot = await transactionsCollection
    .where('paymentStatus', 'in', ['pending', 'created'])
    .limit(Math.max(1, Math.min(1000, Math.trunc(limit))))
    .get();

  let canceled = 0;
  let skippedFresh = 0;
  let skippedScopeMismatch = 0;
  let failed = 0;

  for (const doc of snapshot.docs) {
    const tx = mapTransaction(doc.id, doc.data() ?? {});
    if (
      (scopeClanId.length > 0 && tx.clanId !== scopeClanId) ||
      (scopeOwnerUid.length > 0 && tx.subscriptionOwnerUid !== scopeOwnerUid)
    ) {
      skippedScopeMismatch += 1;
      continue;
    }
    if (!isPendingPaymentStatus(tx.paymentStatus)) {
      continue;
    }
    const createdAt = tx.createdAt;
    if (createdAt == null) {
      skippedFresh += 1;
      continue;
    }
    if (now.getTime() - createdAt.getTime() < timeoutMs) {
      skippedFresh += 1;
      continue;
    }

    try {
      await applyPaymentResult({
        transactionId: tx.id,
        provider: 'system_timeout',
        gatewayReference: `TIMEOUT-${safeTimeoutMinutes}M-${tx.id.slice(0, 8)}`,
        paymentStatus: 'canceled',
        payloadHash: `timeout:${tx.id}:${now.toISOString()}`,
        actorUid: source,
        now,
      });
      canceled += 1;
    } catch (error) {
      failed += 1;
      logWarn('cancelStalePendingTransactionsRun failed for transaction', {
        transactionId: tx.id,
        error: `${error}`,
      });
    }
  }

  return {
    scanned: snapshot.size,
    canceled,
    skippedFresh,
    skippedScopeMismatch,
    failed,
  };
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
  try {
    await ref.create({
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
  } catch (error) {
    const code = (error as { code?: unknown }).code;
    const message = `${error}`.toLowerCase();
    if (code === 6 || code === 'already-exists' || message.includes('already exists')) {
      return { id: key, alreadyProcessed: true };
    }
    throw error;
  }
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
  if (
    transactionData.paymentStatus == 'succeeded' ||
    transactionData.paymentStatus == 'failed' ||
    transactionData.paymentStatus == 'canceled'
  ) {
    if (
      transactionData.paymentStatus == 'canceled' &&
      paymentStatus == 'succeeded'
    ) {
      throw new Error(
        `payment transaction ${transactionId} was canceled and cannot be marked as succeeded`,
      );
    }
    const subscription = await loadSubscription({
      clanId: transactionData.clanId,
      ownerUid: transactionData.subscriptionOwnerUid,
    });
    const invoice = await loadInvoice(transactionData.invoiceId);
    return {
      clanId: transactionData.clanId,
      transaction: transactionData,
      invoice,
      subscription,
    };
  }
  const invoiceRef = invoicesCollection.doc(transactionData.invoiceId);
  const subscriptionRef = subscriptionsCollection.doc(transactionData.subscriptionId);
  const clanRef = clansCollection.doc(transactionData.clanId);

  await db.runTransaction(async (tx) => {
    const [invoiceSnapshot, subscriptionSnapshot, clanSnapshot] = await Promise.all([
      tx.get(invoiceRef),
      tx.get(subscriptionRef),
      tx.get(clanRef),
    ]);

    const existingSubscription = subscriptionSnapshot.exists
      ? mapSubscription(subscriptionSnapshot.id, subscriptionSnapshot.data() ?? {}, {
        fallbackClanId: transactionData.clanId,
        fallbackOwnerUid: transactionData.subscriptionOwnerUid,
      })
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
      const tier = resolveTierByPlanCode(transactionData.planCode);
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
          id: transactionData.subscriptionId,
          clanId: transactionData.clanId,
          ownerUid: transactionData.subscriptionOwnerUid,
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
      if (clanSnapshot.exists) {
        const clanData = clanSnapshot.data() ?? {};
        const currentClanStatus = normalizeClanStatus(clanData.status);
        const billingLockReason = readString(clanData.billingLockReason, '');
        const shouldReactivateClan = currentClanStatus === 'inactive' &&
          billingLockReason === 'subscription_overdue';
        if (shouldReactivateClan) {
          tx.set(
            clanRef,
            {
              status: 'active',
              billingLockReason: null,
              billingLockedAt: null,
              billingGraceEndsAt: null,
              billingSubscriptionId: transactionData.subscriptionId,
              billingRestoredAt: FieldValue.serverTimestamp(),
              updatedAt: FieldValue.serverTimestamp(),
              updatedBy: actorUid,
            },
            { merge: true },
          );
        }
      }
    } else {
      const keepCurrentEntitlement = existingSubscription != null &&
        isSubscriptionValidForUpgradeOnly(existingSubscription, now);
      const nextStatus = keepCurrentEntitlement
        ? existingSubscription!.status
        : 'expired';
      tx.set(
        subscriptionRef,
        {
          status: nextStatus,
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
    subscriptionsCollection.doc(transactionData.subscriptionId).get(),
    invoicesCollection.doc(transactionData.invoiceId).get(),
  ]);

  return {
    clanId: transactionData.clanId,
    transaction: mapTransaction(transactionId, refreshedTransaction.data() ?? {}),
    invoice: refreshedInvoice.exists
      ? mapInvoice(refreshedInvoice.id, refreshedInvoice.data() ?? {})
      : null,
    subscription: refreshedSubscription.exists
      ? mapSubscription(refreshedSubscription.id, refreshedSubscription.data() ?? {}, {
        fallbackClanId: transactionData.clanId,
        fallbackOwnerUid: transactionData.subscriptionOwnerUid,
      })
      : null,
  };
}

export async function resolveBillingAudienceMemberIds(clanId: string): Promise<Array<string>> {
  const snapshot = await membersCollection.where('clanId', '==', clanId).limit(1000).get();
  const adminRoles = new Set([
    'SUPER_ADMIN',
    'CLAN_ADMIN',
    'BRANCH_ADMIN',
    'CLAN_OWNER',
    'CLAN_LEADER',
    'VICE_LEADER',
    'SUPPORTER_OF_LEADER',
  ]);
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

function isSubscriptionValidForUpgradeOnly(
  subscription: BillingSubscriptionRecord,
  now: Date,
): boolean {
  if (subscription.status === 'active') {
    if (subscription.expiresAt == null) {
      return true;
    }
    return subscription.expiresAt.getTime() > now.getTime();
  }
  if (subscription.status === 'grace_period') {
    if (subscription.graceEndsAt != null) {
      return subscription.graceEndsAt.getTime() > now.getTime();
    }
    if (subscription.expiresAt != null) {
      return subscription.expiresAt.getTime() > now.getTime();
    }
    return true;
  }
  return false;
}

function canRenewCurrentPlan(
  subscription: BillingSubscriptionRecord,
  now: Date,
): boolean {
  if (subscription.planCode === 'FREE') {
    return false;
  }
  if (subscription.status === 'expired' || subscription.status === 'grace_period') {
    return true;
  }
  if (subscription.status !== 'active') {
    return false;
  }
  if (subscription.expiresAt == null) {
    return false;
  }
  const daysToExpire = (subscription.expiresAt.getTime() - now.getTime()) / (1000 * 60 * 60 * 24);
  return daysToExpire <= 30;
}

function isPendingPaymentStatus(status: PaymentStatus): boolean {
  return status === 'pending' || status === 'created';
}

function seedSubscription({
  clanId,
  ownerUid,
  tier,
  memberCount,
  settings,
  now,
}: {
  clanId: string;
  ownerUid: string;
  tier: BillingTierPricing;
  memberCount: number;
  settings: BillingSettingsRecord;
  now: Date;
}): BillingSubscriptionRecord {
  if (tier.planCode === 'FREE') {
    return createSubscriptionDraft({
      clanId,
      ownerUid,
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
    ownerUid,
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
    ownerUid: record.ownerUid,
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
    subscriptionOwnerUid: record.subscriptionOwnerUid,
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
    subscriptionOwnerUid: record.subscriptionOwnerUid,
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

function mapSubscription(
  id: string,
  data: Record<string, unknown>,
  fallback: {
    fallbackClanId: string;
    fallbackOwnerUid: string;
  },
): BillingSubscriptionRecord {
  return {
    id,
    clanId: readString(data.clanId, fallback.fallbackClanId),
    ownerUid: readString(data.ownerUid, fallback.fallbackOwnerUid),
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
    subscriptionOwnerUid: readString(data.subscriptionOwnerUid, ''),
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
    subscriptionOwnerUid: readString(data.subscriptionOwnerUid, ''),
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

function normalizeClanStatus(value: unknown): string {
  const normalized = readString(value, 'active').toLowerCase();
  if (normalized.length === 0) {
    return 'active';
  }
  return normalized;
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
  const normalized = readString(value, 'card').toLowerCase();
  if (normalized === 'vnpay') {
    return 'vnpay';
  }
  if (normalized === 'apple_iap') {
    return 'apple_iap';
  }
  if (normalized === 'google_play') {
    return 'google_play';
  }
  return 'card';
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
