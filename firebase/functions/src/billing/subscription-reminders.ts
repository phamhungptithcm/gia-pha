import { FieldValue, Timestamp } from 'firebase-admin/firestore';

import { db } from '../shared/firestore';
import { notifyMembers } from '../notifications/push-delivery';
import { logInfo, logWarn } from '../shared/logger';
import { loadBillingSettings, resolveBillingAudienceMemberIds } from './store';

type ReminderRunInput = {
  source: string;
  now?: Date;
  lookAheadDays?: number;
};

type ReminderRunResult = {
  scanned: number;
  reminderCandidates: number;
  remindersSent: number;
  skippedNoAudience: number;
  skippedNotDue: number;
};

const subscriptionsCollection = db.collection('subscriptions');

export async function sendSubscriptionRemindersRun(
  input: ReminderRunInput,
): Promise<ReminderRunResult> {
  const now = input.now ?? new Date();
  const lookAheadDays = Math.max(1, Math.min(60, input.lookAheadDays ?? 30));
  const deadline = addDays(now, lookAheadDays);

  const snapshot = await subscriptionsCollection
    .where('status', 'in', ['active', 'grace_period'])
    .where('expiresAt', '>=', Timestamp.fromDate(now))
    .where('expiresAt', '<=', Timestamp.fromDate(deadline))
    .orderBy('expiresAt', 'asc')
    .limit(400)
    .get();

  let reminderCandidates = 0;
  let remindersSent = 0;
  let skippedNoAudience = 0;
  let skippedNotDue = 0;

  for (const doc of snapshot.docs) {
    const data = doc.data();
    const clanId = normalizeString(data.clanId ?? doc.id);
    if (clanId.length === 0) {
      continue;
    }

    const expiresAt = toDate(data.expiresAt);
    if (expiresAt == null) {
      continue;
    }

    const daysLeft = diffWholeDays(now, expiresAt);
    if (daysLeft < 0) {
      continue;
    }

    const [settings, memberIds] = await Promise.all([
      loadBillingSettings(clanId),
      resolveBillingAudienceMemberIds(clanId),
    ]);

    reminderCandidates += 1;
    if (memberIds.length === 0) {
      skippedNoAudience += 1;
      continue;
    }
    if (!settings.reminderDaysBefore.includes(daysLeft)) {
      skippedNotDue += 1;
      continue;
    }

    const marker = `${toUtcDateKey(now)}:${daysLeft}`;
    const lastReminderMarker = normalizeString(data.lastReminderMarker);
    if (marker == lastReminderMarker) {
      skippedNotDue += 1;
      continue;
    }

    await notifyMembers({
      clanId,
      memberIds,
      type: 'billing_subscription_expiry_reminder',
      title: daysLeft <= 1
        ? 'Subscription expires tomorrow'
        : `Subscription expires in ${daysLeft} days`,
      body: `Current plan will expire on ${formatDate(expiresAt)}. Open Billing to renew.`,
      target: 'generic',
      targetId: doc.id,
      extraData: {
        billing: 'true',
        reminderType: 'subscription_expiry',
        daysLeft: `${daysLeft}`,
      },
    });
    remindersSent += 1;

    await doc.ref.set(
      {
        lastReminderAt: FieldValue.serverTimestamp(),
        lastReminderDaysLeft: daysLeft,
        lastReminderMarker: marker,
        updatedAt: FieldValue.serverTimestamp(),
        updatedBy: input.source,
      },
      { merge: true },
    );
  }

  const result: ReminderRunResult = {
    scanned: snapshot.size,
    reminderCandidates,
    remindersSent,
    skippedNoAudience,
    skippedNotDue,
  };

  logInfo('subscription reminder run complete', {
    source: input.source,
    ...result,
  });
  return result;
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

function normalizeString(value: unknown): string {
  return typeof value === 'string' ? value.trim() : '';
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
  return `${day}/${month}/${value.getUTCFullYear()}`;
}
