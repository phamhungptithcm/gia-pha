import { createHash } from 'node:crypto';

import { FieldValue, type QueryDocumentSnapshot } from 'firebase-admin/firestore';
import { getMessaging } from 'firebase-admin/messaging';

import {
  APP_TIMEZONE,
  NOTIFICATION_DEFAULT_EMAIL_ENABLED,
  NOTIFICATION_DEFAULT_PUSH_ENABLED,
  NOTIFICATION_EMAIL_COLLECTION,
  NOTIFICATION_EMAIL_ENABLED,
  NOTIFICATION_EVENT_MAX_AUDIENCE,
  NOTIFICATION_PUSH_ENABLED,
} from '../config/runtime';
import { db } from '../shared/firestore';
import { logInfo, logWarn } from '../shared/logger';

type NotificationTarget = 'event' | 'scholarship' | 'billing' | 'generic';
type NotificationLanguageCode = 'vi' | 'en';

type LocalizedNotificationMessage = {
  title: string;
  body: string;
};

type LocalizedNotificationContent = Partial<
  Record<NotificationLanguageCode, LocalizedNotificationMessage>
>;

type NotifyMembersInput = {
  clanId: string;
  memberIds: Array<string>;
  type: string;
  title: string;
  body: string;
  localized?: LocalizedNotificationContent;
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
  quietHoursSuppressedCount: number;
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
  quietHoursEnabled?: unknown;
  languageCode?: unknown;
  locale?: unknown;
};

type UserNotificationSettings = {
  pushEnabled: boolean;
  emailEnabled: boolean;
  eventReminders: boolean;
  scholarshipUpdates: boolean;
  fundTransactions: boolean;
  systemNotices: boolean;
  quietHoursEnabled: boolean;
  email: string | null;
  languageCode: NotificationLanguageCode;
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
const QUIET_HOURS_START_HOUR = 22;
const QUIET_HOURS_END_HOUR = 7;
const appTimezoneHourFormatter = new Intl.DateTimeFormat('en-US', {
  hour: '2-digit',
  hourCycle: 'h23',
  timeZone: APP_TIMEZONE,
});

export async function resolveAudienceMemberIdsByEventScope({
  clanId,
  branchId,
  visibility,
  maxAudience = NOTIFICATION_EVENT_MAX_AUDIENCE,
}: {
  clanId: string;
  branchId: string | null;
  visibility: string;
  maxAudience?: number;
}): Promise<Array<string>> {
  const normalizedVisibility = visibility.trim().toLowerCase();
  const normalizedBranchId = branchId?.trim() ?? '';
  const safeMaxAudience = Math.max(10, Math.min(50000, Math.trunc(maxAudience)));
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
    quietHoursSuppressedCount: 0,
  };
  if (memberIds.length === 0) {
    return emptyResult;
  }

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

  const defaultContent: LocalizedNotificationMessage = {
    title: input.title,
    body: input.body,
  };
  const contentByMemberId = new Map<string, LocalizedNotificationMessage>();
  const pushAudienceUidsByLanguage = new Map<NotificationLanguageCode, Set<string>>();
  const emailAudienceByAddress = new Map<
    string,
    {
      uid: string;
      memberId: string;
      email: string;
      title: string;
      body: string;
    }
  >();
  const now = new Date();
  const quietHoursActiveNow = isWithinQuietHours(now);
  let quietHoursSuppressedCount = 0;
  for (const profile of memberProfiles) {
    const authUid = profile.authUid;
    if (authUid == null || authUid.length === 0) {
      continue;
    }
    const settings = userSettingsByUid.get(authUid) ?? buildDefaultUserNotificationSettings();
    if (!isCategoryEnabled(settings, category)) {
      continue;
    }
    const localizedContent = resolveLocalizedMessageForUser({
      defaultContent,
      localized: input.localized,
      languageCode: settings.languageCode,
    });
    contentByMemberId.set(profile.memberId, localizedContent);
    if (quietHoursActiveNow && settings.quietHoursEnabled) {
      quietHoursSuppressedCount += 1;
      continue;
    }
    if (NOTIFICATION_PUSH_ENABLED && settings.pushEnabled) {
      const localeBucket =
        pushAudienceUidsByLanguage.get(settings.languageCode) ?? new Set<string>();
      localeBucket.add(authUid);
      pushAudienceUidsByLanguage.set(settings.languageCode, localeBucket);
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
        title: localizedContent.title,
        body: localizedContent.body,
      });
    }
  }

  await writeNotificationDocuments({
    clanId: input.clanId,
    memberIds,
    type: input.type,
    defaultContent,
    contentByMemberId,
    target: input.target,
    targetId: input.targetId,
    extraData: input.extraData,
  });

  const payloadData: Record<string, string> = {
    target: input.target,
    id: input.targetId,
    clanId: input.clanId,
    ...input.extraData,
  };
  let pushTokenCount = 0;
  let pushSentCount = 0;
  let pushFailedCount = 0;
  let pushInvalidTokenCount = 0;
  for (const [languageCode, authUids] of pushAudienceUidsByLanguage.entries()) {
    const localizedContent = resolveLocalizedMessageForUser({
      defaultContent,
      localized: input.localized,
      languageCode,
    });
    const pushResult = await sendPushToAudience({
      authUids: [...authUids],
      title: localizedContent.title,
      body: localizedContent.body,
      payloadData,
    });
    pushTokenCount += pushResult.tokenCount;
    pushSentCount += pushResult.sentCount;
    pushFailedCount += pushResult.failedCount;
    pushInvalidTokenCount += pushResult.invalidTokenCount;
  }
  const emailAudience = [...emailAudienceByAddress.values()];
  const emailQueuedCount = await queueEmailNotifications({
    audience: emailAudience,
    clanId: input.clanId,
    type: input.type,
    target: input.target,
    targetId: input.targetId,
    extraData: input.extraData,
  });

  const result: NotifyMembersResult = {
    audienceCount: memberIds.length,
    tokenCount: pushTokenCount,
    sentCount: pushSentCount,
    failedCount: pushFailedCount,
    invalidTokenCount: pushInvalidTokenCount,
    pushAudienceCount: [...pushAudienceUidsByLanguage.values()].reduce(
      (sum, audience) => sum + audience.size,
      0,
    ),
    emailAudienceCount: emailAudience.length,
    emailQueuedCount,
    quietHoursSuppressedCount,
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
  defaultContent,
  contentByMemberId,
  target,
  targetId,
  extraData,
}: {
  clanId: string;
  memberIds: Array<string>;
  type: string;
  defaultContent: LocalizedNotificationMessage;
  contentByMemberId: Map<string, LocalizedNotificationMessage>;
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
      const content = contentByMemberId.get(memberId) ?? defaultContent;
      const docRef = notificationsCollection.doc();
      batch.set(docRef, {
        id: docRef.id,
        memberId,
        clanId,
        type,
        title: content.title,
        body: content.body,
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
  const profiles: Array<MemberDeliveryProfile> = [];
  for (const memberChunk of chunk(memberIds, 400)) {
    const refs = memberChunk.map((memberId) => membersCollection.doc(memberId));
    const snapshots = await db.getAll(...refs);
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

  const settingsByUid = new Map<string, UserNotificationSettings>();
  for (const uidChunk of chunk(uniqueUids, 400)) {
    const userRefs = uidChunk.map((uid) => usersCollection.doc(uid));
    const preferenceRefs = uidChunk.map((uid) => usersCollection
      .doc(uid)
      .collection('preferences')
      .doc('notifications'));
    const [userSnapshots, preferenceSnapshots] = await Promise.all([
      db.getAll(...userRefs),
      db.getAll(...preferenceRefs),
    ]);

    for (let i = 0; i < uidChunk.length; i += 1) {
      const uid = uidChunk[i];
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
        quietHoursEnabled: readBoolean(preferenceData?.quietHoursEnabled, false),
        email: normalizeNullableEmail(userData?.email),
        languageCode: resolveNotificationLanguageCode(
          preferenceData?.languageCode,
          preferenceData?.locale,
          userData?.languageCode,
          userData?.locale,
        ),
      });
    }
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
  clanId,
  type,
  target,
  targetId,
  extraData,
}: {
  audience: Array<{
    uid: string;
    memberId: string;
    email: string;
    title: string;
    body: string;
  }>;
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
          subject: recipient.title,
          text: recipient.body,
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
    quietHoursEnabled: false,
    email: null,
    languageCode: 'vi',
  };
}

function isWithinQuietHours(value: Date): boolean {
  const nowHour = readHourInAppTimezone(value);
  if (QUIET_HOURS_START_HOUR < QUIET_HOURS_END_HOUR) {
    return nowHour >= QUIET_HOURS_START_HOUR &&
      nowHour < QUIET_HOURS_END_HOUR;
  }
  return nowHour >= QUIET_HOURS_START_HOUR ||
    nowHour < QUIET_HOURS_END_HOUR;
}

function readHourInAppTimezone(value: Date): number {
  const hourToken = appTimezoneHourFormatter.format(value);
  const parsed = Number.parseInt(hourToken, 10);
  if (!Number.isFinite(parsed)) {
    return value.getUTCHours();
  }
  return Math.max(0, Math.min(23, Math.trunc(parsed)));
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

function resolveNotificationLanguageCode(
  ...candidates: Array<unknown>
): NotificationLanguageCode {
  for (const candidate of candidates) {
    const normalized = normalizeNullableString(candidate)?.toLowerCase() ?? '';
    if (normalized.startsWith('en')) {
      return 'en';
    }
    if (normalized.startsWith('vi')) {
      return 'vi';
    }
  }
  return 'vi';
}

function resolveLocalizedMessageForUser(input: {
  defaultContent: LocalizedNotificationMessage;
  localized?: LocalizedNotificationContent;
  languageCode: NotificationLanguageCode;
}): LocalizedNotificationMessage {
  const preferred = input.localized?.[input.languageCode];
  if (
    preferred != null &&
    preferred.title.trim().length > 0 &&
    preferred.body.trim().length > 0
  ) {
    return {
      title: preferred.title.trim(),
      body: preferred.body.trim(),
    };
  }
  const fallbackLanguage = input.languageCode === 'en' ? 'vi' : 'en';
  const fallback = input.localized?.[fallbackLanguage];
  if (
    fallback != null &&
    fallback.title.trim().length > 0 &&
    fallback.body.trim().length > 0
  ) {
    return {
      title: fallback.title.trim(),
      body: fallback.body.trim(),
    };
  }
  return {
    title: input.defaultContent.title.trim(),
    body: input.defaultContent.body.trim(),
  };
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
