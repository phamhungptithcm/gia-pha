import { createHash } from 'node:crypto';

import { FieldValue } from 'firebase-admin/firestore';
import { getMessaging } from 'firebase-admin/messaging';

import { db } from '../shared/firestore';
import { logInfo, logWarn } from '../shared/logger';

type NotificationTarget = 'event' | 'scholarship' | 'generic';

type NotifyMembersInput = {
  clanId: string;
  memberIds: Array<string>;
  type: string;
  title: string;
  body: string;
  target: NotificationTarget;
  targetId: string;
  extraData?: Record<string, string>;
};

type NotifyMembersResult = {
  audienceCount: number;
  tokenCount: number;
  sentCount: number;
  failedCount: number;
  invalidTokenCount: number;
};

type DeviceTokenRecord = {
  token?: string | null;
};

const membersCollection = db.collection('members');
const usersCollection = db.collection('users');
const notificationsCollection = db.collection('notifications');

const invalidTokenErrorCodes = new Set([
  'messaging/invalid-registration-token',
  'messaging/registration-token-not-registered',
]);

export async function resolveAudienceMemberIdsByEventScope({
  clanId,
  branchId,
  visibility,
  maxAudience = 500,
}: {
  clanId: string;
  branchId: string | null;
  visibility: string;
  maxAudience?: number;
}): Promise<Array<string>> {
  const normalizedVisibility = visibility.trim().toLowerCase();
  const normalizedBranchId = branchId?.trim() ?? '';

  let query = membersCollection.where('clanId', '==', clanId);
  if (normalizedVisibility === 'branch' && normalizedBranchId.length > 0) {
    query = query.where('branchId', '==', normalizedBranchId);
  }

  const snapshot = await query.limit(maxAudience).get();
  return snapshot.docs
    .filter((doc) => isActiveMember(doc.data()))
    .map((doc) => doc.id);
}

export async function notifyMembers(
  input: NotifyMembersInput,
): Promise<NotifyMembersResult> {
  const memberIds = uniqueMemberIds(input.memberIds);
  if (memberIds.length === 0) {
    return {
      audienceCount: 0,
      tokenCount: 0,
      sentCount: 0,
      failedCount: 0,
      invalidTokenCount: 0,
    };
  }

  await writeNotificationDocuments({
    clanId: input.clanId,
    memberIds,
    type: input.type,
    title: input.title,
    body: input.body,
    target: input.target,
    targetId: input.targetId,
    extraData: input.extraData,
  });

  const authUidsByMemberId = await loadAuthUidsForMembers(memberIds);
  if (authUidsByMemberId.size === 0) {
    return {
      audienceCount: memberIds.length,
      tokenCount: 0,
      sentCount: 0,
      failedCount: 0,
      invalidTokenCount: 0,
    };
  }

  const tokenMetadataByToken = await loadDeviceTokenMetadata(
    [...authUidsByMemberId.values()],
  );
  const allTokens = [...tokenMetadataByToken.keys()];
  if (allTokens.length === 0) {
    return {
      audienceCount: memberIds.length,
      tokenCount: 0,
      sentCount: 0,
      failedCount: 0,
      invalidTokenCount: 0,
    };
  }

  let sentCount = 0;
  let failedCount = 0;
  const invalidTokens = new Set<string>();
  const payloadData: Record<string, string> = {
    target: input.target,
    id: input.targetId,
    clanId: input.clanId,
    ...input.extraData,
  };

  for (const tokenChunk of chunk(allTokens, 500)) {
    const response = await getMessaging().sendEachForMulticast({
      tokens: tokenChunk,
      notification: {
        title: input.title,
        body: input.body,
      },
      data: payloadData,
      android: {
        priority: 'high',
      },
      apns: {
        headers: {
          'apns-priority': '10',
        },
        payload: {
          aps: {
            sound: 'default',
          },
        },
      },
    });

    sentCount += response.successCount;
    failedCount += response.failureCount;

    for (let i = 0; i < response.responses.length; i += 1) {
      const sendResponse = response.responses[i];
      if (sendResponse.success) {
        continue;
      }

      const code = extractErrorCode(sendResponse.error);
      if (code != null && invalidTokenErrorCodes.has(code)) {
        invalidTokens.add(tokenChunk[i]);
      }
    }
  }

  if (invalidTokens.size > 0) {
    await Promise.all(
      [...invalidTokens].map(async (token) => {
        const metadata = tokenMetadataByToken.get(token);
        if (metadata == null) {
          return;
        }
        await usersCollection
          .doc(metadata.uid)
          .collection('deviceTokens')
          .doc(metadata.documentId)
          .delete()
          .catch((error: unknown) => {
            logWarn('failed to cleanup invalid device token', {
              uid: metadata.uid,
              tokenFingerprint: fingerprintToken(token),
              error: `${error}`,
            });
          });
      }),
    );
  }

  const result: NotifyMembersResult = {
    audienceCount: memberIds.length,
    tokenCount: allTokens.length,
    sentCount,
    failedCount,
    invalidTokenCount: invalidTokens.size,
  };

  logInfo('notification delivery result', {
    clanId: input.clanId,
    type: input.type,
    target: input.target,
    targetId: input.targetId,
    ...result,
  });

  return result;
}

async function writeNotificationDocuments({
  clanId,
  memberIds,
  type,
  title,
  body,
  target,
  targetId,
  extraData,
}: {
  clanId: string;
  memberIds: Array<string>;
  type: string;
  title: string;
  body: string;
  target: NotificationTarget;
  targetId: string;
  extraData?: Record<string, string>;
}): Promise<void> {
  const sharedData = {
    target,
    id: targetId,
    ...extraData,
  };

  for (const memberChunk of chunk(memberIds, 450)) {
    const batch = db.batch();

    for (const memberId of memberChunk) {
      const docRef = notificationsCollection.doc();
      batch.set(docRef, {
        id: docRef.id,
        memberId,
        clanId,
        type,
        title,
        body,
        data: sharedData,
        isRead: false,
        sentAt: FieldValue.serverTimestamp(),
        createdAt: FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }
}

async function loadAuthUidsForMembers(
  memberIds: Array<string>,
): Promise<Map<string, string>> {
  const refs = memberIds.map((memberId) => membersCollection.doc(memberId));
  const snapshots = await db.getAll(...refs);

  const map = new Map<string, string>();
  for (const snapshot of snapshots) {
    if (!snapshot.exists) {
      continue;
    }

    const data = snapshot.data();
    const authUid = typeof data?.authUid === 'string' ? data.authUid.trim() : '';
    if (authUid.length > 0) {
      map.set(snapshot.id, authUid);
    }
  }

  return map;
}

async function loadDeviceTokenMetadata(
  authUids: Array<string>,
): Promise<Map<string, { uid: string; documentId: string }>> {
  const uniqueUids = [...new Set(authUids.map((uid) => uid.trim()).filter(Boolean))];
  const metadataByToken = new Map<string, { uid: string; documentId: string }>();

  await Promise.all(
    uniqueUids.map(async (uid) => {
      const snapshot = await usersCollection
        .doc(uid)
        .collection('deviceTokens')
        .limit(20)
        .get();

      for (const doc of snapshot.docs) {
        const data = doc.data() as DeviceTokenRecord;
        const token = (data.token ?? doc.id).trim();
        if (token.length === 0 || metadataByToken.has(token)) {
          continue;
        }
        metadataByToken.set(token, { uid, documentId: doc.id });
      }
    }),
  );

  return metadataByToken;
}

function uniqueMemberIds(memberIds: Array<string>): Array<string> {
  return [...new Set(memberIds.map((id) => id.trim()).filter(Boolean))];
}

function isActiveMember(data: Record<string, unknown>): boolean {
  const status = typeof data.status === 'string' ? data.status.toLowerCase() : 'active';
  return !['inactive', 'archived', 'deleted'].includes(status);
}

function extractErrorCode(error: unknown): string | null {
  if (error == null || typeof error !== 'object') {
    return null;
  }

  const code = (error as { code?: unknown }).code;
  return typeof code === 'string' ? code : null;
}

function chunk<T>(values: Array<T>, size: number): Array<Array<T>> {
  const chunks: Array<Array<T>> = [];
  for (let i = 0; i < values.length; i += size) {
    chunks.push(values.slice(i, i + size));
  }
  return chunks;
}

function fingerprintToken(value: string): string {
  const trimmed = value.trim();
  if (trimmed.length === 0) {
    return 'token:masked';
  }
  const digest = createHash('sha256').update(trimmed).digest('hex').slice(0, 16);
  return `token_hash:${digest}`;
}
