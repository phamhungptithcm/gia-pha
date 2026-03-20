import { FieldValue, Timestamp } from 'firebase-admin/firestore';

import {
  BILLING_CONTACT_EMAIL_WEBHOOK_URL,
  BILLING_CONTACT_NOTICE_REQUIRE_ENDPOINTS,
  BILLING_CONTACT_SMS_WEBHOOK_URL,
  BILLING_CONTACT_NOTICE_WEBHOOK_BACKOFF_MS,
  BILLING_CONTACT_NOTICE_WEBHOOK_MAX_RETRIES,
  BILLING_CONTACT_NOTICE_WEBHOOK_TIMEOUT_MS,
  NOTIFICATION_ALLOW_NON_OTP_SMS,
  getBillingContactNoticeWebhookToken,
} from '../config/runtime';
import { db } from '../shared/firestore';
import { notifyMembers } from '../notifications/push-delivery';
import { logError, logInfo, logWarn } from '../shared/logger';
import { resolveBillingAudienceMemberIds } from './store';

type DelinquencyRunInput = {
  source: string;
  now?: Date;
  graceDays?: number;
  limit?: number;
  reminderDays?: Array<number>;
};

type DelinquencyRunResult = {
  scanned: number;
  statusUpdated: number;
  remindersSent: number;
  clansDeactivated: number;
  clansReactivated: number;
  skippedNoClan: number;
  skippedNoExpiry: number;
  skippedFreePlan: number;
};

type BillingContactNoticeDispatchRunInput = {
  source: string;
  now?: Date;
  limit?: number;
};

type BillingContactNoticeDispatchRunResult = {
  scanned: number;
  delivered: number;
  failed: number;
  skippedNoEndpoint: number;
  skippedInvalidPayload: number;
};

type ClanMetadata = {
  exists: boolean;
  status: string;
  billingLockReason: string;
  ownerUid: string;
  ownerDisplayName: string | null;
  ownerPhoneE164: string | null;
  ownerEmail: string | null;
};

const subscriptionsCollection = db.collection('subscriptions');
const clansCollection = db.collection('clans');
const membersCollection = db.collection('members');
const billingContactNoticesCollection = db.collection('billingContactNotices');

const PAID_PLANS = new Set(['BASE', 'PLUS', 'PRO']);
const NON_REACTIVATABLE_CLAN_STATUS = new Set(['archived', 'deleted']);
const CONTACT_NOTICE_RETRYABLE_STATUS_CODES = new Set([408, 425, 429, 500, 502, 503, 504]);

export async function enforceSubscriptionDelinquencyRun(
  input: DelinquencyRunInput,
): Promise<DelinquencyRunResult> {
  const now = input.now ?? new Date();
  const graceDays = clamp(readInt(input.graceDays, 7), 1, 30);
  const reminderDays = normalizeReminderDays(input.reminderDays, graceDays);
  const limit = clamp(readInt(input.limit, 500), 50, 5000);

  const snapshot = await subscriptionsCollection
    .where('status', 'in', ['active', 'grace_period', 'expired'])
    .limit(limit)
    .get();

  const availableSubscriptionDocIds = new Set(snapshot.docs.map((doc) => doc.id));
  const clanMetadataCache = new Map<string, Promise<ClanMetadata>>();
  const audienceCache = new Map<string, Promise<Array<string>>>();

  let statusUpdated = 0;
  let remindersSent = 0;
  let clansDeactivated = 0;
  let clansReactivated = 0;
  let skippedNoClan = 0;
  let skippedNoExpiry = 0;
  let skippedFreePlan = 0;

  for (const doc of snapshot.docs) {
    const data = asRecord(doc.data());
    if (data == null) {
      continue;
    }

    const clanId = resolveClanId(data, doc.id);
    if (clanId.length === 0) {
      skippedNoClan += 1;
      continue;
    }
    const ownerUid = normalizeString(data.ownerUid);
    const hasScopedSubscription = ownerUid.length > 0 &&
      availableSubscriptionDocIds.has(`${clanId}__${ownerUid}`);
    const isLegacySubscriptionDoc = !doc.id.includes('__');
    if (isLegacySubscriptionDoc && hasScopedSubscription) {
      continue;
    }

    const planCode = normalizePlanCode(data.planCode);
    if (!PAID_PLANS.has(planCode)) {
      skippedFreePlan += 1;
      continue;
    }

    const expiresAt = toDate(data.expiresAt);
    if (expiresAt == null) {
      skippedNoExpiry += 1;
      continue;
    }

    const existingGraceEndsAt = toDate(data.graceEndsAt);
    const graceEndsAt = existingGraceEndsAt ?? addDays(expiresAt, graceDays);
    const status = normalizeSubscriptionStatus(data.status);

    if (expiresAt.getTime() > now.getTime()) {
      const didNormalize = await normalizeActiveSubscription({
        ref: doc.ref,
        data,
        status,
        source: input.source,
      });
      if (didNormalize) {
        statusUpdated += 1;
      }
      const didReactivate = await ensureClanReactivatedForPaidSubscription({
        clanId,
        source: input.source,
        cache: clanMetadataCache,
      });
      if (didReactivate) {
        clansReactivated += 1;
      }
      continue;
    }

    if (now.getTime() < graceEndsAt.getTime()) {
      const didEnterGrace = await ensureGraceStatus({
        ref: doc.ref,
        status,
        hasGraceEndsAt: existingGraceEndsAt != null,
        graceEndsAt,
        source: input.source,
      });
      if (didEnterGrace) {
        statusUpdated += 1;
      }

      const daysLeft = diffWholeDays(now, graceEndsAt);
      if (!reminderDays.includes(daysLeft)) {
        continue;
      }

      const marker = `${toUtcDateKey(now)}:${daysLeft}`;
      if (normalizeString(data.delinquencyReminderMarker) === marker) {
        continue;
      }

      const clanMetadata = await loadClanMetadata({
        clanId,
        fallbackOwnerUid: ownerUid,
        cache: clanMetadataCache,
      });
      if (!clanMetadata.exists) {
        skippedNoClan += 1;
        continue;
      }

      const didSend = await sendGraceReminder({
        clanId,
        subscriptionId: doc.id,
        graceEndsAt,
        daysLeft,
        ownerDisplayName: clanMetadata.ownerDisplayName,
        ownerPhoneE164: clanMetadata.ownerPhoneE164,
        ownerEmail: clanMetadata.ownerEmail,
        audienceCache,
      });
      if (didSend) {
        remindersSent += 1;
      }

      await doc.ref.set(
        {
          delinquencyReminderMarker: marker,
          delinquencyLastReminderDaysLeft: daysLeft,
          delinquencyLastReminderAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
          updatedBy: input.source,
        },
        { merge: true },
      );
      continue;
    }

    const didExpire = await expireOverdueSubscription({
      ref: doc.ref,
      status,
      graceEndsAt,
      source: input.source,
    });
    if (didExpire) {
      statusUpdated += 1;
    }

    const clanMetadata = await loadClanMetadata({
      clanId,
      fallbackOwnerUid: ownerUid,
      cache: clanMetadataCache,
    });
    if (!clanMetadata.exists) {
      skippedNoClan += 1;
      continue;
    }
    if (NON_REACTIVATABLE_CLAN_STATUS.has(clanMetadata.status)) {
      continue;
    }

    const didDeactivate = await deactivateClanForOverdueSubscription({
      clanId,
      subscriptionId: doc.id,
      graceEndsAt,
      source: input.source,
      clanMetadata,
      cache: clanMetadataCache,
    });
    if (didDeactivate) {
      clansDeactivated += 1;
    }

    const lockNoticeSentAt = toDate(data.delinquencyLockNoticeAt);
    if (lockNoticeSentAt == null) {
      await sendDeactivatedNotice({
        clanId,
        subscriptionId: doc.id,
        ownerDisplayName: clanMetadata.ownerDisplayName,
        ownerPhoneE164: clanMetadata.ownerPhoneE164,
        ownerEmail: clanMetadata.ownerEmail,
        audienceCache,
      });
      await doc.ref.set(
        {
          delinquencyLockNoticeAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
          updatedBy: input.source,
        },
        { merge: true },
      );
    }
  }

  const result: DelinquencyRunResult = {
    scanned: snapshot.size,
    statusUpdated,
    remindersSent,
    clansDeactivated,
    clansReactivated,
    skippedNoClan,
    skippedNoExpiry,
    skippedFreePlan,
  };
  logInfo('subscription delinquency enforcement run complete', {
    source: input.source,
    graceDays,
    reminderDays,
    ...result,
  });
  return result;
}

async function normalizeActiveSubscription({
  ref,
  data,
  status,
  source,
}: {
  ref: FirebaseFirestore.DocumentReference<FirebaseFirestore.DocumentData>;
  data: Record<string, unknown>;
  status: string;
  source: string;
}): Promise<boolean> {
  const hadGraceEnds = toDate(data.graceEndsAt) != null;
  if (status === 'active' && !hadGraceEnds) {
    return false;
  }

  await ref.set(
    {
      status: 'active',
      graceEndsAt: null,
      delinquencyReminderMarker: null,
      delinquencyLastReminderDaysLeft: null,
      updatedAt: FieldValue.serverTimestamp(),
      updatedBy: source,
    },
    { merge: true },
  );
  return true;
}

async function ensureGraceStatus({
  ref,
  status,
  hasGraceEndsAt,
  graceEndsAt,
  source,
}: {
  ref: FirebaseFirestore.DocumentReference<FirebaseFirestore.DocumentData>;
  status: string;
  hasGraceEndsAt: boolean;
  graceEndsAt: Date;
  source: string;
}): Promise<boolean> {
  if (status === 'grace_period' && hasGraceEndsAt) {
    return false;
  }
  await ref.set(
    {
      status: 'grace_period',
      graceEndsAt: Timestamp.fromDate(graceEndsAt),
      delinquencyGraceStartedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
      updatedBy: source,
    },
    { merge: true },
  );
  return true;
}

async function expireOverdueSubscription({
  ref,
  status,
  graceEndsAt,
  source,
}: {
  ref: FirebaseFirestore.DocumentReference<FirebaseFirestore.DocumentData>;
  status: string;
  graceEndsAt: Date;
  source: string;
}): Promise<boolean> {
  if (status === 'expired') {
    return false;
  }
  await ref.set(
    {
      status: 'expired',
      graceEndsAt: Timestamp.fromDate(graceEndsAt),
      updatedAt: FieldValue.serverTimestamp(),
      updatedBy: source,
    },
    { merge: true },
  );
  return true;
}

async function ensureClanReactivatedForPaidSubscription({
  clanId,
  source,
  cache,
}: {
  clanId: string;
  source: string;
  cache: Map<string, Promise<ClanMetadata>>;
}): Promise<boolean> {
  const metadata = await loadClanMetadata({
    clanId,
    fallbackOwnerUid: '',
    cache,
  });
  if (!metadata.exists) {
    return false;
  }
  const status = metadata.status;
  if (status !== 'inactive' || metadata.billingLockReason !== 'subscription_overdue') {
    return false;
  }

  await clansCollection.doc(clanId).set(
    {
      status: 'active',
      billingLockReason: null,
      billingLockedAt: null,
      billingGraceEndsAt: null,
      billingRestoredAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
      updatedBy: source,
    },
    { merge: true },
  );
  cache.set(clanId, Promise.resolve({
    ...metadata,
    status: 'active',
    billingLockReason: '',
  }));
  return true;
}

async function deactivateClanForOverdueSubscription({
  clanId,
  subscriptionId,
  graceEndsAt,
  source,
  clanMetadata,
  cache,
}: {
  clanId: string;
  subscriptionId: string;
  graceEndsAt: Date;
  source: string;
  clanMetadata: ClanMetadata;
  cache: Map<string, Promise<ClanMetadata>>;
}): Promise<boolean> {
  if (
    clanMetadata.status === 'inactive' &&
    clanMetadata.billingLockReason === 'subscription_overdue'
  ) {
    return false;
  }

  if (clanMetadata.status === 'inactive' && clanMetadata.billingLockReason.length > 0) {
    return false;
  }

  await clansCollection.doc(clanId).set(
    {
      status: 'inactive',
      billingLockReason: 'subscription_overdue',
      billingLockedAt: FieldValue.serverTimestamp(),
      billingGraceEndsAt: Timestamp.fromDate(graceEndsAt),
      billingSubscriptionId: subscriptionId,
      updatedAt: FieldValue.serverTimestamp(),
      updatedBy: source,
    },
    { merge: true },
  );
  cache.set(clanId, Promise.resolve({
    ...clanMetadata,
    status: 'inactive',
    billingLockReason: 'subscription_overdue',
  }));
  return true;
}

async function sendGraceReminder({
  clanId,
  subscriptionId,
  graceEndsAt,
  daysLeft,
  ownerDisplayName,
  ownerPhoneE164,
  ownerEmail,
  audienceCache,
}: {
  clanId: string;
  subscriptionId: string;
  graceEndsAt: Date;
  daysLeft: number;
  ownerDisplayName: string | null;
  ownerPhoneE164: string | null;
  ownerEmail: string | null;
  audienceCache: Map<string, Promise<Array<string>>>;
}): Promise<boolean> {
  const memberIds = await resolveAudienceMemberIds(clanId, audienceCache);
  if (memberIds.length === 0) {
    return false;
  }
  const ownerLabel = ownerDisplayName ?? 'the clan owner';
  await notifyMembers({
    clanId,
    memberIds,
    type: 'billing_subscription_grace_period',
    title: `Billing overdue: ${daysLeft} day${daysLeft === 1 ? '' : 's'} left`,
    body:
      `Payment is overdue. Complete renewal by ${formatDate(graceEndsAt)} ` +
      `to keep clan access active. Contact ${ownerLabel} for upgrade.`,
    target: 'billing',
    targetId: subscriptionId,
    extraData: {
      billing: 'true',
      reminderType: 'delinquency_grace_period',
      daysLeft: `${daysLeft}`,
    },
  });
  await queueOwnerContactNotice({
    clanId,
    subscriptionId,
    noticeType: 'billing_grace_period',
    dedupeToken: `grace_${daysLeft}`,
    ownerDisplayName,
    ownerPhoneE164,
    ownerEmail,
    subject: `Billing overdue: ${daysLeft} day${daysLeft === 1 ? '' : 's'} left`,
    message:
      `Payment is overdue. Complete renewal by ${formatDate(graceEndsAt)} ` +
      'to keep clan access active.',
  });
  return true;
}

async function sendDeactivatedNotice({
  clanId,
  subscriptionId,
  ownerDisplayName,
  ownerPhoneE164,
  ownerEmail,
  audienceCache,
}: {
  clanId: string;
  subscriptionId: string;
  ownerDisplayName: string | null;
  ownerPhoneE164: string | null;
  ownerEmail: string | null;
  audienceCache: Map<string, Promise<Array<string>>>;
}): Promise<void> {
  const memberIds = await resolveAudienceMemberIds(clanId, audienceCache);
  if (memberIds.length === 0) {
    return;
  }
  const ownerLabel = ownerDisplayName ?? 'the clan owner';
  await notifyMembers({
    clanId,
    memberIds,
    type: 'billing_clan_deactivated',
    title: 'Clan access is temporarily locked',
    body:
      `Subscription grace period has ended. Contact ${ownerLabel} to renew ` +
      'the plan and reactivate clan access.',
    target: 'billing',
    targetId: subscriptionId,
    extraData: {
      billing: 'true',
      reminderType: 'delinquency_locked',
    },
  });
  await queueOwnerContactNotice({
    clanId,
    subscriptionId,
    noticeType: 'billing_clan_deactivated',
    dedupeToken: 'locked',
    ownerDisplayName,
    ownerPhoneE164,
    ownerEmail,
    subject: 'Clan access is temporarily locked',
    message:
      'Subscription grace period has ended. Renew the plan to reactivate clan access.',
  });
}

async function loadClanMetadata({
  clanId,
  fallbackOwnerUid,
  cache,
}: {
  clanId: string;
  fallbackOwnerUid: string;
  cache: Map<string, Promise<ClanMetadata>>;
}): Promise<ClanMetadata> {
  const cached = cache.get(clanId);
  if (cached != null) {
    return cached;
  }

  const loader = (async (): Promise<ClanMetadata> => {
    const snapshot = await clansCollection.doc(clanId).get();
    if (!snapshot.exists) {
      return {
        exists: false,
        status: '',
        billingLockReason: '',
        ownerUid: fallbackOwnerUid,
        ownerDisplayName: null,
        ownerPhoneE164: null,
        ownerEmail: null,
      };
    }
    const data = asRecord(snapshot.data()) ?? {};
    const ownerUid =
      normalizeString(data.ownerUid) ||
      fallbackOwnerUid;
    let ownerDisplayName = normalizeNullableString(data.founderName);
    let ownerPhoneE164: string | null = null;
    let ownerEmail: string | null = null;
    if (ownerUid.length > 0) {
      const ownerContact = await resolveOwnerContact(clanId, ownerUid);
      ownerPhoneE164 = ownerContact.phoneE164;
      ownerEmail = ownerContact.email;
      if (ownerDisplayName == null) {
        ownerDisplayName = ownerContact.displayName;
      }
    }
    return {
      exists: true,
      status: normalizeClanStatus(data.status),
      billingLockReason: normalizeString(data.billingLockReason),
      ownerUid,
      ownerDisplayName,
      ownerPhoneE164,
      ownerEmail,
    };
  })().catch((error) => {
    logWarn('failed to load clan metadata for delinquency enforcement', {
      clanId,
      error: `${error}`,
    });
    return {
      exists: false,
      status: '',
      billingLockReason: '',
      ownerUid: fallbackOwnerUid,
      ownerDisplayName: null,
      ownerPhoneE164: null,
      ownerEmail: null,
    };
  });

  cache.set(clanId, loader);
  return loader;
}

async function resolveOwnerContact(
  clanId: string,
  ownerUid: string,
): Promise<{
  displayName: string | null;
  phoneE164: string | null;
  email: string | null;
}> {
  try {
    const ownerMemberSnapshot = await membersCollection
      .where('clanId', '==', clanId)
      .where('authUid', '==', ownerUid)
      .limit(1)
      .get();
    if (ownerMemberSnapshot.empty) {
      return {
        displayName: null,
        phoneE164: null,
        email: null,
      };
    }
    const data = asRecord(ownerMemberSnapshot.docs[0]?.data());
    const name = normalizeString(data?.fullName) || normalizeString(data?.nickName);
    return {
      displayName: name.length > 0 ? name : null,
      phoneE164: normalizeNullableString(data?.phoneE164),
      email: normalizeNullableString(data?.email),
    };
  } catch {
    return {
      displayName: null,
      phoneE164: null,
      email: null,
    };
  }
}

async function queueOwnerContactNotice({
  clanId,
  subscriptionId,
  noticeType,
  dedupeToken,
  ownerDisplayName,
  ownerPhoneE164,
  ownerEmail,
  subject,
  message,
}: {
  clanId: string;
  subscriptionId: string;
  noticeType: string;
  dedupeToken: string;
  ownerDisplayName: string | null;
  ownerPhoneE164: string | null;
  ownerEmail: string | null;
  subject: string;
  message: string;
}): Promise<void> {
  const channels = [
    ...(NOTIFICATION_ALLOW_NON_OTP_SMS
      ? [{
          channel: 'sms' as const,
          destination: ownerPhoneE164,
        }]
      : []),
    {
      channel: 'email' as const,
      destination: ownerEmail,
    },
  ].filter((entry): entry is { channel: 'sms' | 'email'; destination: string } =>
    entry.destination != null && entry.destination.trim().length > 0
  );
  if (channels.length === 0) {
    return;
  }

  for (const entry of channels) {
    const id = buildOutboxNoticeId({
      clanId,
      subscriptionId,
      noticeType,
      dedupeToken,
      channel: entry.channel,
    });
    await billingContactNoticesCollection.doc(id).set(
      {
        id,
        clanId,
        subscriptionId,
        noticeType,
        channel: entry.channel,
        destination: entry.destination,
        ownerDisplayName,
        subject,
        message,
        status: 'queued',
        queuedAt: FieldValue.serverTimestamp(),
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
  }
}

export async function dispatchBillingContactNoticesRun(
  input: BillingContactNoticeDispatchRunInput,
): Promise<BillingContactNoticeDispatchRunResult> {
  const now = input.now ?? new Date();
  const limit = clamp(readInt(input.limit, 200), 10, 1000);
  const snapshot = await billingContactNoticesCollection
    .where('status', '==', 'queued')
    .limit(limit)
    .get();

  let delivered = 0;
  let failed = 0;
  let skippedNoEndpoint = 0;
  let skippedInvalidPayload = 0;
  const webhookToken = getBillingContactNoticeWebhookToken();

  for (const doc of snapshot.docs) {
    const data = asRecord(doc.data()) ?? {};
    const channel = normalizeString(data.channel).toLowerCase();
    const destination = normalizeNullableString(data.destination);
    const subject = normalizeString(data.subject);
    const message = normalizeString(data.message);
    const webhookUrl = resolveContactNoticeWebhookUrl(channel);
    if (destination == null || message.length === 0 || channel.length === 0) {
      skippedInvalidPayload += 1;
      await doc.ref.set(
        {
          status: 'failed',
          failedAt: FieldValue.serverTimestamp(),
          failureCode: 'invalid_payload',
          failureReason:
            'Missing channel, destination, or message for contact notice dispatch.',
          updatedAt: FieldValue.serverTimestamp(),
          updatedBy: input.source,
          deliveryAttempts: FieldValue.increment(1),
        },
        { merge: true },
      );
      continue;
    }
    if (webhookUrl.length === 0) {
      skippedNoEndpoint += 1;
      await doc.ref.set(
        {
          status: 'skipped_no_endpoint',
          skippedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
          updatedBy: input.source,
          deliveryAttempts: FieldValue.increment(1),
        },
        { merge: true },
      );
      continue;
    }

    try {
      await dispatchContactNoticeWithRetry({
        id: doc.id,
        webhookUrl,
        webhookToken,
        payload: {
          id: doc.id,
          channel,
          destination,
          subject,
          message,
          queuedAtIso: now.toISOString(),
        },
      });

      delivered += 1;
      await doc.ref.set(
        {
          status: 'sent',
          sentAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
          updatedBy: input.source,
          deliveryAttempts: FieldValue.increment(1),
        },
        { merge: true },
      );
    } catch (error) {
      failed += 1;
      await doc.ref.set(
        {
          status: 'failed',
          failedAt: FieldValue.serverTimestamp(),
          failureCode: 'provider_error',
          failureReason: truncateLogValue(`${error}`, 500),
          updatedAt: FieldValue.serverTimestamp(),
          updatedBy: input.source,
          deliveryAttempts: FieldValue.increment(1),
        },
        { merge: true },
      );
      logWarn('billing contact notice dispatch failed', {
        noticeId: doc.id,
        channel,
        destination: maskContactDestination(destination),
        error: `${error}`,
      });
    }
  }

  const result: BillingContactNoticeDispatchRunResult = {
    scanned: snapshot.size,
    delivered,
    failed,
    skippedNoEndpoint,
    skippedInvalidPayload,
  };
  if (skippedNoEndpoint > 0) {
    logError('billing contact notice dispatch skipped due to missing webhook endpoint', {
      skippedNoEndpoint,
      scanned: snapshot.size,
      source: input.source,
      smsEnabled: NOTIFICATION_ALLOW_NON_OTP_SMS,
      smsWebhookConfigured: BILLING_CONTACT_SMS_WEBHOOK_URL.trim().length > 0,
      emailWebhookConfigured: BILLING_CONTACT_EMAIL_WEBHOOK_URL.trim().length > 0,
    });
    if (BILLING_CONTACT_NOTICE_REQUIRE_ENDPOINTS) {
      throw new Error(
        `Missing billing contact notice webhook endpoints for ${skippedNoEndpoint} queued notices.`,
      );
    }
  }
  logInfo('billing contact notice dispatch run complete', result);
  return result;
}

class ContactNoticeDispatchError extends Error {
  constructor(message: string, readonly retryable: boolean) {
    super(message);
    this.name = 'ContactNoticeDispatchError';
  }
}

async function dispatchContactNoticeWithRetry({
  id,
  webhookUrl,
  webhookToken,
  payload,
}: {
  id: string;
  webhookUrl: string;
  webhookToken: string;
  payload: Record<string, unknown>;
}): Promise<void> {
  const timeoutMs = clamp(BILLING_CONTACT_NOTICE_WEBHOOK_TIMEOUT_MS, 1000, 30000);
  const maxRetries = clamp(BILLING_CONTACT_NOTICE_WEBHOOK_MAX_RETRIES, 0, 8);
  const backoffMs = clamp(BILLING_CONTACT_NOTICE_WEBHOOK_BACKOFF_MS, 50, 5000);
  const maxAttempts = maxRetries + 1;
  let attempt = 0;

  while (attempt < maxAttempts) {
    attempt += 1;
    try {
      await dispatchContactNoticeOnce({
        webhookUrl,
        webhookToken,
        payload,
        timeoutMs,
      });
      return;
    } catch (error) {
      const dispatchError = toContactNoticeDispatchError(error, timeoutMs);
      const shouldRetry = dispatchError.retryable && attempt < maxAttempts;
      if (!shouldRetry) {
        throw dispatchError;
      }

      const sleepMs = Math.min(backoffMs * Math.pow(2, attempt - 1), 20000);
      logWarn('billing contact notice dispatch retry scheduled', {
        noticeId: id,
        attempt,
        maxAttempts,
        backoffMs: sleepMs,
        reason: dispatchError.message,
      });
      await wait(sleepMs);
    }
  }
}

async function dispatchContactNoticeOnce({
  webhookUrl,
  webhookToken,
  payload,
  timeoutMs,
}: {
  webhookUrl: string;
  webhookToken: string;
  payload: Record<string, unknown>;
  timeoutMs: number;
}): Promise<void> {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const response = await fetch(webhookUrl, {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        ...(webhookToken.length > 0
          ? { authorization: `Bearer ${webhookToken}` }
          : {}),
      },
      body: JSON.stringify(payload),
      signal: controller.signal,
    });
    if (!response.ok) {
      const bodyText = await response.text();
      throw new ContactNoticeDispatchError(
        `provider_http_${response.status}:${truncateLogValue(bodyText, 240)}`,
        CONTACT_NOTICE_RETRYABLE_STATUS_CODES.has(response.status),
      );
    }
  } catch (error) {
    throw toContactNoticeDispatchError(error, timeoutMs);
  } finally {
    clearTimeout(timeout);
  }
}

function toContactNoticeDispatchError(
  error: unknown,
  timeoutMs: number,
): ContactNoticeDispatchError {
  if (error instanceof ContactNoticeDispatchError) {
    return error;
  }
  if (isAbortError(error)) {
    return new ContactNoticeDispatchError(
      `provider_timeout_${timeoutMs}ms`,
      true,
    );
  }
  const raw = truncateLogValue(`${error}`, 500);
  return new ContactNoticeDispatchError(
    raw,
    isRetryableNetworkErrorMessage(raw),
  );
}

function isAbortError(error: unknown): boolean {
  if (error == null || typeof error !== 'object') {
    return false;
  }
  const name = normalizeString((error as { name?: unknown }).name).toLowerCase();
  return name === 'aborterror';
}

function isRetryableNetworkErrorMessage(message: string): boolean {
  const normalized = message.trim().toLowerCase();
  return (
    normalized.includes('timeout') ||
    normalized.includes('timed out') ||
    normalized.includes('econnreset') ||
    normalized.includes('etimedout') ||
    normalized.includes('eai_again') ||
    normalized.includes('enotfound') ||
    normalized.includes('econnrefused') ||
    normalized.includes('network')
  );
}

function wait(ms: number): Promise<void> {
  return new Promise((resolve) => {
    setTimeout(resolve, ms);
  });
}

function buildOutboxNoticeId({
  clanId,
  subscriptionId,
  noticeType,
  dedupeToken,
  channel,
}: {
  clanId: string;
  subscriptionId: string;
  noticeType: string;
  dedupeToken: string;
  channel: string;
}): string {
  const value = `${clanId}__${subscriptionId}__${noticeType}__${dedupeToken}__${channel}`;
  return value
    .toLowerCase()
    .replace(/[^a-z0-9_]+/g, '_')
    .slice(0, 160);
}

function resolveContactNoticeWebhookUrl(channel: string): string {
  if (channel === 'sms') {
    if (!NOTIFICATION_ALLOW_NON_OTP_SMS) {
      return '';
    }
    return BILLING_CONTACT_SMS_WEBHOOK_URL.trim();
  }
  if (channel === 'email') {
    return BILLING_CONTACT_EMAIL_WEBHOOK_URL.trim();
  }
  return '';
}

function maskContactDestination(value: string): string {
  const trimmed = value.trim();
  if (trimmed.length <= 4) {
    return '****';
  }
  return `${trimmed.slice(0, 2)}***${trimmed.slice(-2)}`;
}

function truncateLogValue(value: string, maxLength: number): string {
  if (value.length <= maxLength) {
    return value;
  }
  return `${value.slice(0, maxLength)}...`;
}

async function resolveAudienceMemberIds(
  clanId: string,
  cache: Map<string, Promise<Array<string>>>,
): Promise<Array<string>> {
  const cached = cache.get(clanId);
  if (cached != null) {
    return cached;
  }
  const loader = resolveBillingAudienceMemberIds(clanId).catch((error) => {
    logWarn('failed to resolve billing reminder audience', {
      clanId,
      error: `${error}`,
    });
    return [];
  });
  cache.set(clanId, loader);
  return loader;
}

function resolveClanId(data: Record<string, unknown>, docId: string): string {
  const explicit = normalizeString(data.clanId);
  if (explicit.length > 0) {
    return explicit;
  }
  const separatorIndex = docId.indexOf('__');
  if (separatorIndex > 0) {
    return docId.slice(0, separatorIndex);
  }
  return docId.trim();
}

function normalizePlanCode(value: unknown): string {
  return normalizeString(value).toUpperCase();
}

function normalizeSubscriptionStatus(value: unknown): string {
  const normalized = normalizeString(value).toLowerCase();
  if (
    normalized === 'active' ||
    normalized === 'grace_period' ||
    normalized === 'expired'
  ) {
    return normalized;
  }
  return 'expired';
}

function normalizeClanStatus(value: unknown): string {
  const normalized = normalizeString(value).toLowerCase();
  return normalized.length > 0 ? normalized : 'active';
}

function asRecord(value: unknown): Record<string, unknown> | null {
  if (value == null || typeof value !== 'object' || Array.isArray(value)) {
    return null;
  }
  return value as Record<string, unknown>;
}

function normalizeString(value: unknown): string {
  return typeof value === 'string' ? value.trim() : '';
}

function normalizeNullableString(value: unknown): string | null {
  const normalized = normalizeString(value);
  return normalized.length > 0 ? normalized : null;
}

function toDate(value: unknown): Date | null {
  if (value instanceof Timestamp) {
    return value.toDate();
  }
  if (value instanceof Date) {
    return value;
  }
  if (
    value != null &&
    typeof value === 'object' &&
    'toDate' in value &&
    typeof (value as { toDate?: unknown }).toDate === 'function'
  ) {
    try {
      return (value as { toDate: () => Date }).toDate();
    } catch {
      return null;
    }
  }
  return null;
}

function addDays(base: Date, days: number): Date {
  const next = new Date(base);
  next.setUTCDate(next.getUTCDate() + days);
  return next;
}

function diffWholeDays(left: Date, right: Date): number {
  const leftUtc = Date.UTC(left.getUTCFullYear(), left.getUTCMonth(), left.getUTCDate());
  const rightUtc = Date.UTC(right.getUTCFullYear(), right.getUTCMonth(), right.getUTCDate());
  return Math.trunc((rightUtc - leftUtc) / (1000 * 60 * 60 * 24));
}

function toUtcDateKey(value: Date): string {
  const year = value.getUTCFullYear();
  const month = `${value.getUTCMonth() + 1}`.padStart(2, '0');
  const day = `${value.getUTCDate()}`.padStart(2, '0');
  return `${year}-${month}-${day}`;
}

function formatDate(value: Date): string {
  const day = `${value.getUTCDate()}`.padStart(2, '0');
  const month = `${value.getUTCMonth() + 1}`.padStart(2, '0');
  const year = value.getUTCFullYear();
  return `${day}/${month}/${year}`;
}

function readInt(value: unknown, fallback: number): number {
  if (typeof value === 'number' && Number.isFinite(value)) {
    return Math.trunc(value);
  }
  if (typeof value === 'string') {
    const parsed = Number.parseInt(value.trim(), 10);
    if (Number.isFinite(parsed)) {
      return parsed;
    }
  }
  return fallback;
}

function clamp(value: number, min: number, max: number): number {
  if (value < min) {
    return min;
  }
  if (value > max) {
    return max;
  }
  return value;
}

function normalizeReminderDays(input: Array<number> | undefined, graceDays: number): Array<number> {
  const normalized = (input ?? [graceDays, 3, 1])
    .map((value) => Math.trunc(value))
    .filter((value) => Number.isFinite(value) && value >= 1 && value <= graceDays);
  if (normalized.length === 0) {
    return [graceDays, 1].filter((value, index, list) => list.indexOf(value) === index);
  }
  return [...new Set(normalized)].sort((left, right) => right - left);
}
