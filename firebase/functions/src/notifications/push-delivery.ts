import { createHash } from 'node:crypto';

import { FieldValue, type QueryDocumentSnapshot } from 'firebase-admin/firestore';
import { getMessaging } from 'firebase-admin/messaging';

import {
  NOTIFICATION_DEFAULT_EMAIL_ENABLED,
  NOTIFICATION_DEFAULT_PUSH_ENABLED,
  NOTIFICATION_EMAIL_COLLECTION,
  NOTIFICATION_EMAIL_ENABLED,
  NOTIFICATION_PUSH_ENABLED,
} from '../config/runtime';
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
  pushAudienceCount: number;
  emailAudienceCount: number;
  emailQueuedCount: number;
};

type DeviceTokenRecord = {
  token?: string | null;
};

type MemberDeliveryProfile = {
  memberId: string;
  authUid: string | null;
  email: string | null;
};

type UserNotificationPreferenceRecord = {
  pushEnabled?: unknown;
  emailEnabled?: unknown;
  eventReminders?: unknown;
  scholarshipUpdates?: unknown;
  fundTransactions?: unknown;
  systemNotices?: unknown;
};

type UserNotificationSettings = {
  pushEnabled: boolean;
  emailEnabled: boolean;
  eventReminders: boolean;
  scholarshipUpdates: boolean;
  fundTransactions: boolean;
  systemNotices: boolean;
  email: string | null;
};

type NotificationPreferenceCategory =
  | 'eventReminders'
  | 'scholarshipUpdates'
  | 'fundTransactions'
  | 'systemNotices';

type PushDeliveryResult = {
  tokenCount: number;
  sentCount: number;
  failedCount: number;
  invalidTokenCount: number;
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
  const safeMaxAudience = Math.max(10, Math.min(10000, Math.trunc(maxAudience)));
  const queryPageSize = Math.min(500, safeMaxAudience);
  const memberIds = new Set<string>();
  let cursor: QueryDocumentSnapshot | null = null;

  while (memberIds.size < safeMaxAudience) {
    let query = membersCollection.where('clanId', '==', clanId);
    if (normalizedVisibility === 'branch' && normalizedBranchId.length > 0) {
      query = query.where('branchId', '==', normalizedBranchId);
    }
    query = query.limit(Math.min(queryPageSize, safeMaxAudience - memberIds.size));
    if (cursor != null) {
      query = query.startAfter(cursor);
    }

    const snapshot = await query.get();
    if (snapshot.empty) {
      break;
    }
    cursor = snapshot.docs[snapshot.docs.length - 1];

    for (const doc of snapshot.docs) {
      if (!isActiveMember(doc.data())) {
        continue;
      }
      memberIds.add(doc.id);
      if (memberIds.size >= safeMaxAudience) {
        break;
      }
    }
    if (snapshot.docs.length < queryPageSize) {
      break;
    }
  }

  if (memberIds.size >= safeMaxAudience) {
    logWarn('event notification audience truncated to configured max', {
      clanId,
      branchId: normalizedBranchId || null,
      visibility: normalizedVisibility,
      maxAudience: safeMaxAudience,
    });
  }

  return [...memberIds];
}

export async function notifyMembers(
  input: NotifyMembersInput,
): Promise<NotifyMembersResult> {
  const memberIds = uniqueMemberIds(input.memberIds);
  const emptyResult: NotifyMembersResult = {
    audienceCount: memberIds.length,
    tokenCount: 0,
    sentCount: 0,
    failedCount: 0,
    invalidTokenCount: 0,
    pushAudienceCount: 0,
    emailAudienceCount: 0,
    emailQueuedCount: 0,
  };
  if (memberIds.length === 0) {
    return emptyResult;
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

  const memberProfiles = await loadMemberDeliveryProfiles(memberIds);
  if (memberProfiles.length === 0) {
    return emptyResult;
  }
  const category = resolvePreferenceCategory(input.type);
  const authUids = [...new Set(
    memberProfiles
      .map((profile) => profile.authUid)
      .filter((value): value is string => value != null && value.length > 0),
  )];
  const userSettingsByUid = await loadUserNotificationSettings(authUids);

  const pushAudienceUids = new Set<string>();
  const emailAudienceByAddress = new Map<
    string,
    { uid: string; memberId: string; email: string }
  >();
  for (const profile of memberProfiles) {
    const authUid = profile.authUid;
    if (authUid == null || authUid.length === 0) {
      continue;
    }
    const settings = userSettingsByUid.get(authUid) ?? buildDefaultUserNotificationSettings();
    if (!isCategoryEnabled(settings, category)) {
      continue;
    }
    if (NOTIFICATION_PUSH_ENABLED && settings.pushEnabled) {
      pushAudienceUids.add(authUid);
    }
    if (!NOTIFICATION_EMAIL_ENABLED || !settings.emailEnabled) {
      continue;
    }
    const resolvedEmail = normalizeNullableEmail(profile.email) ??
      normalizeNullableEmail(settings.email);
    if (resolvedEmail == null) {
      continue;
    }
    if (!emailAudienceByAddress.has(resolvedEmail)) {
      emailAudienceByAddress.set(resolvedEmail, {
        uid: authUid,
        memberId: profile.memberId,
        email: resolvedEmail,
      });
    }
  }

  const payloadData: Record<string, string> = {
    target: input.target,
    id: input.targetId,
    clanId: input.clanId,
    ...input.extraData,
  };
  const pushResult = await sendPushToAudience({
    authUids: [...pushAudienceUids],
    title: input.title,
    body: input.body,
    payloadData,
  });
  const emailAudience = [...emailAudienceByAddress.values()];
  const emailQueuedCount = await queueEmailNotifications({
    audience: emailAudience,
    title: input.title,
    body: input.body,
    clanId: input.clanId,
    type: input.type,
    target: input.target,
    targetId: input.targetId,
    extraData: input.extraData,
  });

  const result: NotifyMembersResult = {
    audienceCount: memberIds.length,
    tokenCount: pushResult.tokenCount,
    sentCount: pushResult.sentCount,
    failedCount: pushResult.failedCount,
    invalidTokenCount: pushResult.invalidTokenCount,
    pushAudienceCount: pushAudienceUids.size,
    emailAudienceCount: emailAudience.length,
    emailQueuedCount,
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

async function loadMemberDeliveryProfiles(
  memberIds: Array<string>,
): Promise<Array<MemberDeliveryProfile>> {
  if (memberIds.length === 0) {
    return [];
  }
  const refs = memberIds.map((memberId) => membersCollection.doc(memberId));
  const snapshots = await db.getAll(...refs);

  const profiles: Array<MemberDeliveryProfile> = [];
  for (const snapshot of snapshots) {
    if (!snapshot.exists) {
      continue;
    }

    const data = snapshot.data() as Record<string, unknown> | undefined;
    const authUid = normalizeNullableString(data?.authUid);
    const email = normalizeNullableEmail(data?.email);
    profiles.push({
      memberId: snapshot.id,
      authUid,
      email,
    });
  }

  return profiles;
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

async function loadUserNotificationSettings(
  authUids: Array<string>,
): Promise<Map<string, UserNotificationSettings>> {
  const uniqueUids = [...new Set(authUids.map((uid) => uid.trim()).filter(Boolean))];
  if (uniqueUids.length === 0) {
    return new Map();
  }
  const userRefs = uniqueUids.map((uid) => usersCollection.doc(uid));
  const preferenceRefs = uniqueUids.map((uid) => usersCollection
    .doc(uid)
    .collection('preferences')
    .doc('notifications'));
  const [userSnapshots, preferenceSnapshots] = await Promise.all([
    db.getAll(...userRefs),
    db.getAll(...preferenceRefs),
  ]);

  const settingsByUid = new Map<string, UserNotificationSettings>();
  for (let i = 0; i < uniqueUids.length; i += 1) {
    const uid = uniqueUids[i];
    const userData = userSnapshots[i]?.data() as Record<string, unknown> | undefined;
    const preferenceData = preferenceSnapshots[i]?.data() as UserNotificationPreferenceRecord | undefined;
    settingsByUid.set(uid, {
      pushEnabled: readBoolean(
        preferenceData?.pushEnabled,
        NOTIFICATION_DEFAULT_PUSH_ENABLED,
      ),
      emailEnabled: readBoolean(
        preferenceData?.emailEnabled,
        NOTIFICATION_DEFAULT_EMAIL_ENABLED,
      ),
      eventReminders: readBoolean(preferenceData?.eventReminders, true),
      scholarshipUpdates: readBoolean(preferenceData?.scholarshipUpdates, true),
      fundTransactions: readBoolean(preferenceData?.fundTransactions, true),
      systemNotices: readBoolean(preferenceData?.systemNotices, true),
      email: normalizeNullableEmail(userData?.email),
    });
  }
  return settingsByUid;
}

async function sendPushToAudience({
  authUids,
  title,
  body,
  payloadData,
}: {
  authUids: Array<string>;
  title: string;
  body: string;
  payloadData: Record<string, string>;
}): Promise<PushDeliveryResult> {
  if (authUids.length === 0 || !NOTIFICATION_PUSH_ENABLED) {
    return {
      tokenCount: 0,
      sentCount: 0,
      failedCount: 0,
      invalidTokenCount: 0,
    };
  }
  const tokenMetadataByToken = await loadDeviceTokenMetadata(authUids);
  const allTokens = [...tokenMetadataByToken.keys()];
  if (allTokens.length === 0) {
    return {
      tokenCount: 0,
      sentCount: 0,
      failedCount: 0,
      invalidTokenCount: 0,
    };
  }

  let sentCount = 0;
  let failedCount = 0;
  const invalidTokens = new Set<string>();
  for (const tokenChunk of chunk(allTokens, 500)) {
    const response = await getMessaging().sendEachForMulticast({
      tokens: tokenChunk,
      notification: {
        title,
        body,
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
  return {
    tokenCount: allTokens.length,
    sentCount,
    failedCount,
    invalidTokenCount: invalidTokens.size,
  };
}

async function queueEmailNotifications({
  audience,
  title,
  body,
  clanId,
  type,
  target,
  targetId,
  extraData,
}: {
  audience: Array<{ uid: string; memberId: string; email: string }>;
  title: string;
  body: string;
  clanId: string;
  type: string;
  target: NotificationTarget;
  targetId: string;
  extraData?: Record<string, string>;
}): Promise<number> {
  if (!NOTIFICATION_EMAIL_ENABLED || audience.length === 0) {
    return 0;
  }
  const collectionName = NOTIFICATION_EMAIL_COLLECTION.trim();
  if (collectionName.length === 0) {
    return 0;
  }
  const emailCollection = db.collection(collectionName);
  let queuedCount = 0;
  for (const audienceChunk of chunk(audience, 400)) {
    const batch = db.batch();
    for (const recipient of audienceChunk) {
      const docRef = emailCollection.doc();
      batch.set(docRef, {
        id: docRef.id,
        to: [recipient.email],
        message: {
          subject: title,
          text: body,
        },
        notification: {
          clanId,
          memberId: recipient.memberId,
          uid: recipient.uid,
          type,
          target,
          targetId,
          ...extraData,
        },
        queuedAt: FieldValue.serverTimestamp(),
        createdAt: FieldValue.serverTimestamp(),
      });
      queuedCount += 1;
    }
    await batch.commit();
  }
  return queuedCount;
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

function resolvePreferenceCategory(type: string): NotificationPreferenceCategory {
  const normalized = type.trim().toLowerCase();
  if (normalized.startsWith('event_')) {
    return 'eventReminders';
  }
  if (normalized.startsWith('scholarship_')) {
    return 'scholarshipUpdates';
  }
  if (
    normalized.startsWith('fund_') ||
    normalized.includes('fund') ||
    normalized.includes('transaction')
  ) {
    return 'fundTransactions';
  }
  return 'systemNotices';
}

function buildDefaultUserNotificationSettings(): UserNotificationSettings {
  return {
    pushEnabled: NOTIFICATION_DEFAULT_PUSH_ENABLED,
    emailEnabled: NOTIFICATION_DEFAULT_EMAIL_ENABLED,
    eventReminders: true,
    scholarshipUpdates: true,
    fundTransactions: true,
    systemNotices: true,
    email: null,
  };
}

function isCategoryEnabled(
  settings: UserNotificationSettings,
  category: NotificationPreferenceCategory,
): boolean {
  if (category === 'eventReminders') {
    return settings.eventReminders;
  }
  if (category === 'scholarshipUpdates') {
    return settings.scholarshipUpdates;
  }
  if (category === 'fundTransactions') {
    return settings.fundTransactions;
  }
  return settings.systemNotices;
}

function readBoolean(value: unknown, fallback: boolean): boolean {
  return typeof value === 'boolean' ? value : fallback;
}

function normalizeNullableString(value: unknown): string | null {
  if (typeof value !== 'string') {
    return null;
  }
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}

function normalizeNullableEmail(value: unknown): string | null {
  const normalized = normalizeNullableString(value)?.toLowerCase() ?? null;
  if (normalized == null || !normalized.includes('@')) {
    return null;
  }
  return normalized;
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
