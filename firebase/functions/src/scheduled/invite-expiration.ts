import { FieldValue, Timestamp } from 'firebase-admin/firestore';

import { db } from '../shared/firestore';
import { logInfo } from '../shared/logger';

type InviteRecord = {
  status?: string | null;
  expiresAt?: Timestamp | Date | { toMillis: () => number } | null;
};

type ExpireInvitesInput = {
  source: string;
  pageSize?: number;
  now?: Timestamp;
};

type ExpireInvitesResult = {
  scanned: number;
  expired: number;
  pages: number;
};

const EXPIRABLE_STATUSES = new Set(['pending', 'active']);

export async function expireInvitesJobRun(
  input: ExpireInvitesInput,
): Promise<ExpireInvitesResult> {
  const now = input.now ?? Timestamp.now();
  const nowMillis = now.toMillis();
  const pageSize = clampPageSize(input.pageSize ?? 250);

  const invitesCollection = db.collection('invites');
  let lastDoc: FirebaseFirestore.QueryDocumentSnapshot | undefined;
  let scanned = 0;
  let expired = 0;
  let pages = 0;

  while (true) {
    let query = invitesCollection
      .where('expiresAt', '<=', now)
      .orderBy('expiresAt')
      .limit(pageSize);
    if (lastDoc != null) {
      query = query.startAfter(lastDoc);
    }

    const page = await query.get();
    if (page.empty) {
      break;
    }

    pages += 1;
    scanned += page.size;
    lastDoc = page.docs[page.docs.length - 1];

    const expirableDocs = page.docs.filter((doc) =>
      shouldExpireInvite(doc.data() as InviteRecord, nowMillis),
    );

    if (expirableDocs.length > 0) {
      const batch = db.batch();
      for (const doc of expirableDocs) {
        batch.set(
          doc.ref,
          {
            status: 'expired',
            updatedAt: FieldValue.serverTimestamp(),
            expiredAt: FieldValue.serverTimestamp(),
            updatedBy: input.source,
          },
          { merge: true },
        );
      }
      await batch.commit();
      expired += expirableDocs.length;
    }
  }

  logInfo('invite expiration run completed', {
    source: input.source,
    scanned,
    expired,
    pages,
    at: now.toDate().toISOString(),
  });

  return { scanned, expired, pages };
}

export function shouldExpireInvite(
  invite: InviteRecord,
  nowMillis: number,
): boolean {
  const status = normalizeStatus(invite.status);
  if (!EXPIRABLE_STATUSES.has(status)) {
    return false;
  }

  const expiresAtMillis = toMillis(invite.expiresAt);
  if (expiresAtMillis == null) {
    return false;
  }

  return expiresAtMillis <= nowMillis;
}

function normalizeStatus(value: unknown): string {
  return typeof value === 'string' ? value.trim().toLowerCase() : 'pending';
}

function toMillis(value: unknown): number | null {
  if (value instanceof Timestamp) {
    return value.toMillis();
  }
  if (value instanceof Date) {
    return value.getTime();
  }
  if (
    value != null &&
    typeof value === 'object' &&
    'toMillis' in value &&
    typeof (value as { toMillis?: unknown }).toMillis === 'function'
  ) {
    try {
      return (value as { toMillis: () => number }).toMillis();
    } catch {
      return null;
    }
  }

  return null;
}

function clampPageSize(value: number): number {
  if (!Number.isFinite(value)) {
    return 250;
  }

  return Math.max(50, Math.min(500, Math.trunc(value)));
}
