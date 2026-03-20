import { getAuth } from 'firebase-admin/auth';
import {
  FieldValue,
  type DocumentData,
  type QueryDocumentSnapshot,
  type QuerySnapshot,
} from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';

import { APP_REGION, CALLABLE_ENFORCE_APP_CHECK } from '../config/runtime';
import { requireAuth } from '../shared/errors';
import { db } from '../shared/firestore';
import { logError, logInfo } from '../shared/logger';
import { notifyMembers } from '../notifications/push-delivery';
import {
  GOVERNANCE_ROLES,
  ensureAnyRole,
  ensureClaimedSession,
  ensureClanAccess,
  stringOrNull,
  tokenMemberId,
  tokenPrimaryRole,
} from '../shared/permissions';

type DiscoveryRecord = {
  clanId?: string | null;
  genealogyName?: string | null;
  leaderName?: string | null;
  provinceCity?: string | null;
  summary?: string | null;
  memberCount?: number | null;
  branchCount?: number | null;
  isPublic?: boolean | null;
  genealogyNameNormalized?: string | null;
  leaderNameNormalized?: string | null;
  provinceCityNormalized?: string | null;
};

type JoinRequestRecord = {
  id?: string | null;
  clanId?: string | null;
  status?: string | null;
  applicantUid?: string | null;
  applicantName?: string | null;
  applicantMemberId?: string | null;
  relationshipToFamily?: string | null;
  contactInfo?: string | null;
  contactInfoNormalized?: string | null;
  message?: string | null;
  reviewedByMemberId?: string | null;
  reviewerRole?: string | null;
  reviewNote?: string | null;
  accessProvisioningStatus?: string | null;
  accessProvisioned?: boolean | null;
  linkedApplicantMemberId?: string | null;
  createdAt?: unknown;
  updatedAt?: unknown;
  reviewedAt?: unknown;
  canceledAt?: unknown;
};

type MemberRecord = {
  clanId?: string | null;
  branchId?: string | null;
  fullName?: string | null;
  nickName?: string | null;
  authUid?: string | null;
  primaryRole?: string | null;
  status?: string | null;
  phoneE164?: string | null;
  email?: string | null;
};

type UserRecord = {
  memberId?: string | null;
  clanId?: string | null;
  clanIds?: Array<string> | null;
  branchId?: string | null;
  primaryRole?: string | null;
};

type JoinRequestAccessProvisionResult = {
  status:
    | 'linked'
    | 'pending_applicant_uid'
    | 'pending_member_mapping'
    | 'member_not_found'
    | 'member_clan_mismatch'
    | 'member_already_linked'
    | 'applicant_account_missing'
    | 'provisioning_failed'
    | 'not_required';
  linkedMemberId: string | null;
  clanIds: Array<string>;
};

type LinkedClanContext = {
  clanId: string;
  memberId: string;
  branchId: string | null;
  primaryRole: string;
  displayName: string | null;
  status: string | null;
};

const discoveryCollection = db.collection('genealogyDiscoveryIndex');
const joinRequestsCollection = db.collection('joinRequests');
const joinRequestNotificationEventsCollection = db.collection('joinRequestNotificationEvents');
const joinRequestNotificationsCollection = db.collection('joinRequestNotifications');
const membersCollection = db.collection('members');
const branchesCollection = db.collection('branches');
const usersCollection = db.collection('users');
const auditLogsCollection = db.collection('auditLogs');

const reviewerRoles = [
  GOVERNANCE_ROLES.superAdmin,
  GOVERNANCE_ROLES.clanAdmin,
  'CLAN_LEADER',
  GOVERNANCE_ROLES.branchAdmin,
  GOVERNANCE_ROLES.adminSupport,
  'VICE_LEADER',
  'SUPPORTER_OF_LEADER',
];
const SUPPORTED_PHONE_DIAL_CODES = ['886', '84', '82', '81', '65', '61', '49', '44', '33', '1'];
const APP_CHECK_CALLABLE_OPTIONS = {
  region: APP_REGION,
  enforceAppCheck: CALLABLE_ENFORCE_APP_CHECK,
} as const;

export const searchGenealogyDiscovery = onCall(
  APP_CHECK_CALLABLE_OPTIONS,
  async (request) => {
    const auth = requireAuth(request);

    const leaderQuery = normalizeSearch(optionalString(request.data, 'leaderQuery'));
    const locationQuery = normalizeSearch(optionalString(request.data, 'locationQuery'));
    const query = normalizeSearch(optionalString(request.data, 'query'));
    const limit = resolveLimit(request.data);

    const baseQuery = discoveryCollection.where('isPublic', '==', true);
    const scanLimit = Math.min(600, Math.max(120, limit * 6));
    const pageSize = Math.min(80, Math.max(limit, 30));
    const candidates: Array<{ id: string } & DiscoveryRecord> = [];
    let scanned = 0;
    let cursor: QueryDocumentSnapshot<DocumentData> | null = null;
    while (candidates.length < limit && scanned < scanLimit) {
      const remaining = scanLimit - scanned;
      const chunkSize = Math.max(1, Math.min(pageSize, remaining));
      let pageSnapshot: QuerySnapshot<DocumentData>;
      if (cursor == null) {
        pageSnapshot = await baseQuery.limit(chunkSize).get();
      } else {
        pageSnapshot = await baseQuery.startAfter(cursor).limit(chunkSize).get();
      }
      if (pageSnapshot.empty) {
        break;
      }
      for (const doc of pageSnapshot.docs) {
        scanned += 1;
        const entry = { id: doc.id, ...(doc.data() as DiscoveryRecord) };
        if (matchesDiscoveryQuery(entry, { leaderQuery, locationQuery, query })) {
          candidates.push(entry);
          if (candidates.length >= limit) {
            break;
          }
        }
      }
      cursor = pageSnapshot.docs[pageSnapshot.docs.length - 1] ?? null;
      if (pageSnapshot.docs.length < chunkSize) {
        break;
      }
    }
    const pendingJoinRequestsByClanId = await loadPendingJoinRequestsByApplicant(auth.uid);

    const results = candidates
      .map((entry) => sanitizeDiscoveryResult(entry, {
        pendingRequestSubmittedAtEpochMs:
          pendingJoinRequestsByClanId.get(stringOrNull(entry.clanId) ?? entry.id) ?? null,
      }))
      .slice(0, limit);

    logInfo('searchGenealogyDiscovery succeeded', {
      query,
      leaderQuery,
      locationQuery,
      count: results.length,
      scanned,
      scanLimit,
      uid: auth.uid,
    });

    return { results };
  },
);

export const submitJoinRequest = onCall(
  APP_CHECK_CALLABLE_OPTIONS,
  async (request) => {
    const auth = requireAuth(request);

    const clanId = requireNonEmptyString(request.data, 'clanId');
    const applicantName = requireNonEmptyString(request.data, 'applicantName');
    const relationshipToFamily = requireNonEmptyString(
      request.data,
      'relationshipToFamily',
    );
    const contactInfo = requireNonEmptyString(request.data, 'contactInfo');
    const message = stringOrNull((request.data as Record<string, unknown>)?.message);
    const applicantUid = auth.uid;
    const applicantMemberId = stringOrNull(
      (request.data as Record<string, unknown>)?.applicantMemberId,
    ) ?? tokenMemberId(auth.token);

    const discoverySnapshot = await discoveryCollection.doc(clanId).get();
    const discovery = discoverySnapshot.data() as DiscoveryRecord | undefined;
    if (!discoverySnapshot.exists || discovery?.isPublic !== true) {
      throw new HttpsError('not-found', 'Public genealogy discovery entry not found.');
    }
    const claimantClanIdsRaw = Array.isArray(auth.token.clanIds) ? auth.token.clanIds : [];
    const claimantClanIds = claimantClanIdsRaw
      .filter((entry): entry is string => typeof entry === 'string')
      .map((entry) => entry.trim())
      .filter((entry) => entry.length > 0);
    if (claimantClanIds.includes(clanId) || stringOrNull(auth.token.clanId) === clanId) {
      throw new HttpsError(
        'failed-precondition',
        'You are already a member of this clan.',
      );
    }

    const normalizedContact = normalizeContact(contactInfo);
    const duplicatePendingByApplicantSnapshot = await joinRequestsCollection
      .where('applicantUid', '==', applicantUid)
      .limit(300)
      .get();
    const duplicatePendingByApplicant = duplicatePendingByApplicantSnapshot.docs.some((doc) => {
      const item = doc.data() as JoinRequestRecord;
      return (stringOrNull(item.clanId) ?? '') === clanId &&
        (stringOrNull(item.status)?.toLowerCase() ?? 'pending') === 'pending';
    });
    const duplicatePendingByContact = await joinRequestsCollection
      .where('clanId', '==', clanId)
      .where('contactInfoNormalized', '==', normalizedContact)
      .where('status', '==', 'pending')
      .limit(1)
      .get();
    if (duplicatePendingByApplicant || !duplicatePendingByContact.empty) {
      throw new HttpsError(
        'already-exists',
        'A pending join request already exists for this genealogy.',
      );
    }

    const requestRef = joinRequestsCollection.doc();
    await requestRef.set({
      id: requestRef.id,
      clanId,
      status: 'pending',
      applicantUid,
      applicantMemberId,
      applicantName,
      relationshipToFamily,
      contactInfo,
      contactInfoNormalized: normalizedContact,
      message,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });

    const reviewerDelivery = await notifyReviewersForJoinRequest({
      joinRequestId: requestRef.id,
      clanId,
      applicantName,
      relationshipToFamily,
    });

    const auditRef = auditLogsCollection.doc();
    await auditRef.set({
      id: auditRef.id,
      clanId,
      action: 'join_request_submitted',
      entityType: 'join_request',
      entityId: requestRef.id,
      uid: applicantUid,
      memberId: applicantMemberId,
      after: {
        applicantName,
        relationshipToFamily,
        contactInfoNormalized: normalizedContact,
      },
      createdAt: FieldValue.serverTimestamp(),
    });

    logInfo('submitJoinRequest succeeded', {
      joinRequestId: requestRef.id,
      clanId,
      applicantUid,
      ...reviewerDelivery,
    });

    return {
      id: requestRef.id,
      clanId,
      status: 'pending',
      notifiedReviewers: reviewerDelivery.audienceCount,
    };
  },
);

export const listMyJoinRequests = onCall(
  APP_CHECK_CALLABLE_OPTIONS,
  async (request) => {
    const auth = requireAuth(request);
    const statusFilterRaw = optionalString(request.data, 'status')?.trim().toLowerCase() ?? '';
    const statusFilter = ['pending', 'approved', 'rejected', 'canceled'].includes(statusFilterRaw)
      ? statusFilterRaw
      : '';

    const snapshot = await joinRequestsCollection
      .where('applicantUid', '==', auth.uid)
      .limit(300)
      .get();
    const clanIds = Array.from(new Set(snapshot.docs
      .map((doc) => stringOrNull((doc.data() as JoinRequestRecord).clanId) ?? '')
      .filter((clanId) => clanId.length > 0)));
    const genealogyNameByClanId = await loadDiscoveryNamesByClanIds(clanIds);

    const requests = snapshot.docs
      .map((doc) => {
        const item = doc.data() as JoinRequestRecord;
        const status = stringOrNull(item.status)?.toLowerCase() ?? 'pending';
        const clanId = stringOrNull(item.clanId) ?? '';
        return {
          id: doc.id,
          clanId,
          genealogyName: genealogyNameByClanId.get(clanId) ?? '',
          status,
          submittedAtEpochMs: timestampToEpochMillis(item.createdAt),
          reviewedAtEpochMs: timestampToEpochMillis(item.reviewedAt),
          canceledAtEpochMs: timestampToEpochMillis(item.canceledAt),
          canCancel: status === 'pending',
        };
      })
      .filter((entry) => entry.clanId.length > 0)
      .filter((entry) => statusFilter.length == 0 || entry.status === statusFilter)
      .sort((left, right) => (right.submittedAtEpochMs ?? 0) - (left.submittedAtEpochMs ?? 0));

    return { requests };
  },
);

export const cancelJoinRequest = onCall(
  APP_CHECK_CALLABLE_OPTIONS,
  async (request) => {
    const auth = requireAuth(request);
    const requestId = requireNonEmptyString(request.data, 'requestId');
    const joinRequestRef = joinRequestsCollection.doc(requestId);
    const joinRequestSnapshot = await joinRequestRef.get();
    if (!joinRequestSnapshot.exists || joinRequestSnapshot.data() == null) {
      throw new HttpsError('not-found', 'Join request was not found.');
    }

    const joinRequest = joinRequestSnapshot.data() as JoinRequestRecord;
    const applicantUid = stringOrNull(joinRequest.applicantUid);
    if (applicantUid == null || applicantUid !== auth.uid) {
      throw new HttpsError('permission-denied', 'You can only cancel your own join request.');
    }

    const status = stringOrNull(joinRequest.status)?.toLowerCase() ?? 'pending';
    if (status !== 'pending') {
      throw new HttpsError('failed-precondition', 'Only pending join requests can be canceled.');
    }

    const clanId = stringOrNull(joinRequest.clanId) ?? '';
    const memberId = tokenMemberId(auth.token);
    await joinRequestRef.set(
      {
        status: 'canceled',
        canceledAt: FieldValue.serverTimestamp(),
        canceledByUid: auth.uid,
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    const auditRef = auditLogsCollection.doc();
    await auditRef.set({
      id: auditRef.id,
      clanId,
      action: 'join_request_canceled',
      entityType: 'join_request',
      entityId: requestId,
      uid: auth.uid,
      memberId,
      createdAt: FieldValue.serverTimestamp(),
    });

    logInfo('cancelJoinRequest succeeded', {
      requestId,
      clanId,
      applicantUid: auth.uid,
    });

    return {
      id: requestId,
      status: 'canceled',
      canceledAtEpochMs: Date.now(),
    };
  },
);

export const reviewJoinRequest = onCall(
  APP_CHECK_CALLABLE_OPTIONS,
  async (request) => {
    const auth = requireAuth(request);
    ensureClaimedSession(auth.token);
    ensureAnyRole(auth.token, reviewerRoles, 'Only clan governance reviewers can review join requests.');

    const requestId = requireNonEmptyString(request.data, 'requestId');
    const decision = requireDecision(request.data, 'decision');
    const note = stringOrNull((request.data as Record<string, unknown>)?.note);
    const reviewerMemberId = tokenMemberId(auth.token) ?? auth.uid;
    const reviewerRole = tokenPrimaryRole(auth.token);

    const joinRequestRef = joinRequestsCollection.doc(requestId);
    const joinRequestSnapshot = await joinRequestRef.get();
    if (!joinRequestSnapshot.exists || joinRequestSnapshot.data() == null) {
      throw new HttpsError('not-found', 'Join request was not found.');
    }

    const joinRequest = joinRequestSnapshot.data() as JoinRequestRecord;
    const clanId = stringOrNull(joinRequest.clanId);
    if (clanId == null) {
      throw new HttpsError('failed-precondition', 'Join request has no clan context.');
    }
    ensureClanAccess(auth.token, clanId);

    const status = stringOrNull(joinRequest.status)?.toLowerCase() ?? 'pending';
    if (status !== 'pending') {
      throw new HttpsError(
        'failed-precondition',
        'Join request has already been reviewed.',
      );
    }

    const nextStatus = decision === 'approve' ? 'approved' : 'rejected';
    let accessProvisioning: JoinRequestAccessProvisionResult = {
      status: 'not_required',
      linkedMemberId: null,
      clanIds: [],
    };
    if (nextStatus === 'approved') {
      try {
        accessProvisioning = await provisionApprovedJoinRequestAccess({
          requestId,
          clanId,
          joinRequest,
          reviewerUid: auth.uid,
          reviewerMemberId,
        });
      } catch (error) {
        logError('reviewJoinRequest access provisioning failed', {
          requestId,
          clanId,
          reviewerMemberId,
          errorMessage: error instanceof Error ? error.message : String(error),
        });
        accessProvisioning = {
          status: 'provisioning_failed',
          linkedMemberId: null,
          clanIds: [],
        };
      }
    }
    await joinRequestRef.set(
      {
        status: nextStatus,
        reviewedByMemberId: reviewerMemberId,
        reviewerRole,
        reviewNote: note,
        accessProvisioningStatus: accessProvisioning.status,
        accessProvisioned: accessProvisioning.status === 'linked',
        linkedApplicantMemberId: accessProvisioning.linkedMemberId,
        reviewedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    const auditRef = auditLogsCollection.doc();
    await auditRef.set({
      id: auditRef.id,
      clanId,
      action: 'join_request_reviewed',
      entityType: 'join_request',
      entityId: requestId,
      uid: auth.uid,
      memberId: reviewerMemberId,
      after: {
        status: nextStatus,
        reviewerRole,
        accessProvisioningStatus: accessProvisioning.status,
        linkedApplicantMemberId: accessProvisioning.linkedMemberId,
      },
      createdAt: FieldValue.serverTimestamp(),
    });

    const applicantDelivery = await notifyApplicantForJoinRequest({
      requestId,
      clanId,
      joinRequest,
      nextStatus,
      reviewerMemberId,
      reviewerRole,
      note,
      accessProvisioningStatus: accessProvisioning.status,
      linkedApplicantMemberId: accessProvisioning.linkedMemberId,
    });

    logInfo('reviewJoinRequest succeeded', {
      requestId,
      clanId,
      reviewerMemberId,
      reviewerRole,
      nextStatus,
      accessProvisioningStatus: accessProvisioning.status,
      ...applicantDelivery,
    });

    return {
      id: requestId,
      clanId,
      status: nextStatus,
      applicantNotified: applicantDelivery.sent,
      accessProvisioningStatus: accessProvisioning.status,
      linkedApplicantMemberId: accessProvisioning.linkedMemberId,
    };
  },
);

export const listJoinRequestsForReview = onCall(
  APP_CHECK_CALLABLE_OPTIONS,
  async (request) => {
    const auth = requireAuth(request);
    ensureClaimedSession(auth.token);
    ensureAnyRole(auth.token, reviewerRoles, 'Only governance reviewers can list join requests.');

    const clanIdsRaw = Array.isArray(auth.token.clanIds) ? auth.token.clanIds : [];
    const clanIds = clanIdsRaw
      .filter((entry): entry is string => typeof entry === 'string')
      .map((entry) => entry.trim())
      .filter((entry) => entry.length > 0);
    const clanId = clanIds[0] ?? null;
    if (clanId == null) {
      throw new HttpsError('failed-precondition', 'No clan context was found for this reviewer.');
    }

    const requestedStatus = optionalString(request.data, 'status')?.trim().toLowerCase() ?? 'pending';
    const status = ['pending', 'approved', 'rejected'].includes(requestedStatus)
      ? requestedStatus
      : 'pending';

    const snapshot = await joinRequestsCollection
      .where('clanId', '==', clanId)
      .where('status', '==', status)
      .orderBy('createdAt', 'desc')
      .limit(120)
      .get();

    const requests = snapshot.docs.map((doc) => {
      const item = doc.data() as JoinRequestRecord;
      return {
        id: doc.id,
        clanId,
        status: stringOrNull(item.status) ?? status,
        applicantUid: stringOrNull(item.applicantUid),
        applicantMemberId: stringOrNull(item.applicantMemberId),
        applicantName: stringOrNull(item.applicantName) ?? 'Unknown applicant',
        relationshipToFamily:
          stringOrNull(item.relationshipToFamily) ?? 'Unspecified relationship',
        contactInfo: stringOrNull(item.contactInfo) ?? '',
        message: stringOrNull(item.message),
        submittedAtEpochMs: timestampToEpochMillis(item.createdAt),
      };
    });

    return { requests };
  },
);

export const detectDuplicateGenealogy = onCall(
  APP_CHECK_CALLABLE_OPTIONS,
  async (request) => {
    const auth = requireAuth(request);
    ensureClaimedSession(auth.token);
    ensureAnyRole(
      auth.token,
      [GOVERNANCE_ROLES.superAdmin, GOVERNANCE_ROLES.clanAdmin, GOVERNANCE_ROLES.adminSupport],
      'Only governance setup roles can run duplicate detection.',
    );

    const genealogyName = normalizeSearch(requireNonEmptyString(request.data, 'genealogyName'));
    const leaderName = normalizeSearch(requireNonEmptyString(request.data, 'leaderName'));
    const provinceCity = normalizeSearch(requireNonEmptyString(request.data, 'provinceCity'));

    const snapshot = await discoveryCollection.where('isPublic', '==', true).limit(200).get();
    const candidates = snapshot.docs
      .map((doc) => ({ id: doc.id, ...(doc.data() as DiscoveryRecord) }))
      .map((entry) => ({
        entry,
        score: duplicateScore(entry, { genealogyName, leaderName, provinceCity }),
      }))
      .filter((candidate) => candidate.score >= 55)
      .sort((left, right) => right.score - left.score)
      .slice(0, 10)
      .map((candidate) => ({
        ...sanitizeDiscoveryResult(candidate.entry),
        score: candidate.score,
      }));

    const clanIdsRaw = Array.isArray(auth.token.clanIds) ? auth.token.clanIds : [];
    const clanIds = clanIdsRaw
      .filter((entry): entry is string => typeof entry === 'string')
      .map((entry) => entry.trim())
      .filter((entry) => entry.length > 0);
    const clanId = clanIds[0] ?? null;

    const auditRef = auditLogsCollection.doc();
    await auditRef.set({
      id: auditRef.id,
      clanId,
      action: 'genealogy_duplicate_check',
      entityType: 'clan',
      entityId: clanId,
      uid: auth.uid,
      memberId: tokenMemberId(auth.token),
      before: { genealogyName, leaderName, provinceCity },
      after: {
        candidateCount: candidates.length,
        candidateIds: candidates.map((candidate) => candidate.clanId),
      },
      createdAt: FieldValue.serverTimestamp(),
    });

    return { candidates };
  },
);

async function notifyReviewersForJoinRequest(input: {
  joinRequestId: string;
  clanId: string;
  applicantName: string;
  relationshipToFamily: string;
}): Promise<{ audienceCount: number }> {
  const eventId = `${input.joinRequestId}_reviewers`;
  const eventRef = joinRequestNotificationEventsCollection.doc(eventId);
  const existing = await eventRef.get();
  if (existing.exists) {
    return {
      audienceCount: (existing.data()?.audienceCount as number | undefined) ?? 0,
    };
  }

  const [roleMembersSnapshot, branchesSnapshot] = await Promise.all([
    membersCollection
      .where('clanId', '==', input.clanId)
      .where('primaryRole', 'in', reviewerRoles)
      .limit(120)
      .get(),
    branchesCollection.where('clanId', '==', input.clanId).limit(120).get(),
  ]);

  const reviewerMemberIds = new Set<string>();
  for (const doc of roleMembersSnapshot.docs) {
    reviewerMemberIds.add(doc.id);
  }
  for (const branch of branchesSnapshot.docs) {
    const leaderMemberId = stringOrNull(branch.data().leaderMemberId);
    const viceLeaderMemberId = stringOrNull(branch.data().viceLeaderMemberId);
    if (leaderMemberId != null) {
      reviewerMemberIds.add(leaderMemberId);
    }
    if (viceLeaderMemberId != null) {
      reviewerMemberIds.add(viceLeaderMemberId);
    }
  }

  const audience = [...reviewerMemberIds];
  if (audience.length > 0) {
    await notifyMembers({
      clanId: input.clanId,
      memberIds: audience,
      type: 'join_request_created',
      title: 'New join request',
      body: `${input.applicantName} (${input.relationshipToFamily}) requested to join this genealogy.`,
      target: 'generic',
      targetId: input.joinRequestId,
      extraData: {
        target: 'join_request',
        joinRequestId: input.joinRequestId,
        referencePath: buildJoinRequestReferencePath(input.clanId, input.joinRequestId),
      },
    });
  }

  await eventRef.set({
    id: eventId,
    joinRequestId: input.joinRequestId,
    eventType: 'reviewer_inbound',
    clanId: input.clanId,
    audienceCount: audience.length,
    referencePath: buildJoinRequestReferencePath(input.clanId, input.joinRequestId),
    createdAt: FieldValue.serverTimestamp(),
  });

  return { audienceCount: audience.length };
}

async function notifyApplicantForJoinRequest(input: {
  requestId: string;
  clanId: string;
  joinRequest: JoinRequestRecord;
  nextStatus: string;
  reviewerMemberId: string;
  reviewerRole: string;
  note: string | null;
  accessProvisioningStatus: JoinRequestAccessProvisionResult['status'];
  linkedApplicantMemberId: string | null;
}): Promise<{ sent: boolean; recipientMemberId: string | null }> {
  const eventId = `${input.requestId}_applicant`;
  const eventRef = joinRequestNotificationEventsCollection.doc(eventId);
  const existing = await eventRef.get();
  if (existing.exists) {
    const recipientMemberId = stringOrNull(existing.data()?.recipientMemberId);
    return { sent: existing.data()?.sent === true, recipientMemberId };
  }

  let recipientMemberId = stringOrNull(input.joinRequest.applicantMemberId);
  if (recipientMemberId == null) {
    recipientMemberId = input.linkedApplicantMemberId;
  }
  if (recipientMemberId == null) {
    const applicantUid = stringOrNull(input.joinRequest.applicantUid);
    if (applicantUid != null) {
      const userSnapshot = await usersCollection.doc(applicantUid).get();
      const user = userSnapshot.data() as UserRecord | undefined;
      recipientMemberId = stringOrNull(user?.memberId);
    }
  }

  let sent = false;
  if (recipientMemberId != null) {
    const approvedAndLinked = input.nextStatus === 'approved' &&
      input.accessProvisioningStatus === 'linked';
    const approvedProvisioningFailed = input.nextStatus === 'approved' &&
      input.accessProvisioningStatus === 'provisioning_failed';
    const approvedPendingAccess = input.nextStatus === 'approved' &&
      !approvedAndLinked &&
      !approvedProvisioningFailed;
    const body = approvedAndLinked
      ? 'Your join request has been approved. Access is now available.'
      : approvedProvisioningFailed
        ? 'Your join request was approved. Access setup is in progress and will be finalized shortly.'
      : approvedPendingAccess
        ? 'Your join request was approved and is waiting for membership linking.'
        : 'Your join request was not approved at this time.';

    await notifyMembers({
      clanId: input.clanId,
      memberIds: [recipientMemberId],
      type: 'join_request_reviewed',
      title: input.nextStatus === 'approved' ? 'Join request approved' : 'Join request reviewed',
      body,
      target: 'generic',
      targetId: input.requestId,
      extraData: {
        target: 'join_request',
        joinRequestId: input.requestId,
        status: input.nextStatus,
        accessProvisioningStatus: input.accessProvisioningStatus,
        referencePath: buildJoinRequestReferencePath(input.clanId, input.requestId),
      },
    });
    sent = true;
  }

  const outboundRef = joinRequestNotificationsCollection.doc();
  await outboundRef.set({
    id: outboundRef.id,
    joinRequestId: input.requestId,
    clanId: input.clanId,
    recipientMemberId,
    reviewerMemberId: input.reviewerMemberId,
    reviewerRole: input.reviewerRole,
    status: input.nextStatus,
    note: input.note,
    accessProvisioningStatus: input.accessProvisioningStatus,
    linkedApplicantMemberId: input.linkedApplicantMemberId,
    sent,
    referencePath: buildJoinRequestReferencePath(input.clanId, input.requestId),
    createdAt: FieldValue.serverTimestamp(),
  });

  await eventRef.set({
    id: eventId,
    joinRequestId: input.requestId,
    eventType: 'applicant_outbound',
    clanId: input.clanId,
    recipientMemberId,
    accessProvisioningStatus: input.accessProvisioningStatus,
    linkedApplicantMemberId: input.linkedApplicantMemberId,
    sent,
    referencePath: buildJoinRequestReferencePath(input.clanId, input.requestId),
    createdAt: FieldValue.serverTimestamp(),
  });

  return { sent, recipientMemberId };
}

async function provisionApprovedJoinRequestAccess(input: {
  requestId: string;
  clanId: string;
  joinRequest: JoinRequestRecord;
  reviewerUid: string;
  reviewerMemberId: string;
}): Promise<JoinRequestAccessProvisionResult> {
  const applicantUid = stringOrNull(input.joinRequest.applicantUid);
  if (applicantUid == null) {
    return {
      status: 'pending_applicant_uid',
      linkedMemberId: null,
      clanIds: [],
    };
  }

  const userSnapshot = await usersCollection.doc(applicantUid).get();
  const userData = userSnapshot.data() as UserRecord | undefined;
  const targetMemberId = await resolveJoinRequestApplicantMemberId({
    clanId: input.clanId,
    joinRequest: input.joinRequest,
    fallbackMemberId: stringOrNull(userData?.memberId),
  });
  if (targetMemberId == null) {
    return {
      status: 'pending_member_mapping',
      linkedMemberId: null,
      clanIds: [],
    };
  }

  const memberRef = membersCollection.doc(targetMemberId);
  const memberSnapshot = await memberRef.get();
  if (!memberSnapshot.exists || memberSnapshot.data() == null) {
    return {
      status: 'member_not_found',
      linkedMemberId: targetMemberId,
      clanIds: [],
    };
  }

  const member = memberSnapshot.data() as MemberRecord;
  if (stringOrNull(member.clanId) !== input.clanId) {
    return {
      status: 'member_clan_mismatch',
      linkedMemberId: targetMemberId,
      clanIds: [],
    };
  }

  const existingAuthUid = stringOrNull(member.authUid);
  if (existingAuthUid != null && existingAuthUid !== applicantUid) {
    return {
      status: 'member_already_linked',
      linkedMemberId: targetMemberId,
      clanIds: [],
    };
  }

  const memberPatch: Record<string, unknown> = {
    authUid: applicantUid,
    updatedAt: FieldValue.serverTimestamp(),
    updatedBy: input.reviewerMemberId,
  };
  if (existingAuthUid == null) {
    memberPatch.claimedAt = FieldValue.serverTimestamp();
  }
  await memberRef.set(memberPatch, { merge: true });

  const contexts = await loadLinkedClanContextsForUid(applicantUid);
  const fallbackContext = linkedContextFromMemberSnapshot(targetMemberId, member);
  if (contexts.length === 0 && fallbackContext == null) {
    return {
      status: 'pending_member_mapping',
      linkedMemberId: targetMemberId,
      clanIds: [],
    };
  }

  const mergedContexts = contexts.length > 0
    ? contexts
    : [fallbackContext!];
  const existingUserClanId = stringOrNull(userData?.clanId);
  const activeContext = selectActiveContext({
    contexts: mergedContexts,
    preferredClanId: existingUserClanId,
    fallbackClanId: input.clanId,
  });
  if (activeContext == null) {
    return {
      status: 'pending_member_mapping',
      linkedMemberId: targetMemberId,
      clanIds: [],
    };
  }

  const orderedClanIds = [
    activeContext.clanId,
    ...mergedContexts
      .map((context) => context.clanId)
      .filter((clanId) => clanId !== activeContext.clanId),
  ];

  const authAdmin = getAuth();
  let authUserClaims: Record<string, unknown> = {};
  try {
    const authUser = await authAdmin.getUser(applicantUid);
    authUserClaims = authUser.customClaims ?? {};
  } catch {
    return {
      status: 'applicant_account_missing',
      linkedMemberId: targetMemberId,
      clanIds: orderedClanIds,
    };
  }

  await authAdmin.setCustomUserClaims(applicantUid, {
    ...authUserClaims,
    clanIds: orderedClanIds,
    clanId: activeContext.clanId,
    activeClanId: activeContext.clanId,
    memberId: activeContext.memberId,
    branchId: activeContext.branchId ?? '',
    primaryRole: activeContext.primaryRole,
    memberAccessMode: 'claimed',
  });

  await usersCollection.doc(applicantUid).set(
    {
      uid: applicantUid,
      memberId: activeContext.memberId,
      clanId: activeContext.clanId,
      clanIds: orderedClanIds,
      branchId: activeContext.branchId ?? '',
      primaryRole: activeContext.primaryRole,
      accessMode: 'claimed',
      linkedAuthUid: true,
      updatedAt: FieldValue.serverTimestamp(),
      createdAt: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  await auditLogsCollection.add({
    clanId: input.clanId,
    action: 'join_request_access_provisioned',
    entityType: 'join_request',
    entityId: input.requestId,
    uid: input.reviewerUid,
    memberId: input.reviewerMemberId,
    after: {
      applicantUid,
      linkedMemberId: targetMemberId,
      activeClanId: activeContext.clanId,
      activeMemberId: activeContext.memberId,
      clanIds: orderedClanIds,
    },
    createdAt: FieldValue.serverTimestamp(),
  });

  return {
    status: 'linked',
    linkedMemberId: targetMemberId,
    clanIds: orderedClanIds,
  };
}

async function resolveJoinRequestApplicantMemberId(input: {
  clanId: string;
  joinRequest: JoinRequestRecord;
  fallbackMemberId: string | null;
}): Promise<string | null> {
  const directCandidates = [
    stringOrNull(input.joinRequest.applicantMemberId),
    input.fallbackMemberId,
  ]
    .filter((entry): entry is string => entry != null)
    .map((entry) => entry.trim())
    .filter((entry, index, source) => entry.length > 0 && source.indexOf(entry) === index);
  if (directCandidates.length > 0) {
    return directCandidates[0]!;
  }

  const normalizedContact = normalizeContact(stringOrNull(input.joinRequest.contactInfo) ?? '');
  if (normalizedContact.length === 0) {
    return null;
  }

  const snapshot = await membersCollection
    .where('clanId', '==', input.clanId)
    .limit(500)
    .get();
  const matches = snapshot.docs
    .filter((doc) => {
      const member = doc.data() as MemberRecord;
      const phone = normalizeContact(stringOrNull(member.phoneE164) ?? '');
      const email = normalizeContact(stringOrNull(member.email) ?? '');
      return phone === normalizedContact || email === normalizedContact;
    })
    .map((doc) => doc.id);
  if (matches.length === 1) {
    return matches[0]!;
  }
  return null;
}

async function loadLinkedClanContextsForUid(uid: string): Promise<Array<LinkedClanContext>> {
  const snapshot = await membersCollection
    .where('authUid', '==', uid)
    .limit(300)
    .get();
  if (snapshot.empty) {
    return [];
  }

  const byClan = new Map<string, LinkedClanContext>();
  for (const doc of snapshot.docs) {
    const member = doc.data() as MemberRecord;
    const clanId = stringOrNull(member.clanId);
    if (clanId == null) {
      continue;
    }
    const candidate: LinkedClanContext = {
      clanId,
      memberId: doc.id,
      branchId: stringOrNull(member.branchId),
      primaryRole: normalizeRole(stringOrNull(member.primaryRole) ?? 'MEMBER'),
      displayName: stringOrNull(member.fullName) ?? stringOrNull(member.nickName),
      status: stringOrNull(member.status),
    };
    const existing = byClan.get(clanId);
    if (existing == null || preferredClanContext(candidate, existing)) {
      byClan.set(clanId, candidate);
    }
  }

  return [...byClan.values()];
}

function linkedContextFromMemberSnapshot(
  memberId: string,
  member: MemberRecord,
): LinkedClanContext | null {
  const clanId = stringOrNull(member.clanId);
  if (clanId == null) {
    return null;
  }
  return {
    clanId,
    memberId,
    branchId: stringOrNull(member.branchId),
    primaryRole: normalizeRole(stringOrNull(member.primaryRole) ?? 'MEMBER'),
    displayName: stringOrNull(member.fullName) ?? stringOrNull(member.nickName),
    status: stringOrNull(member.status),
  };
}

function selectActiveContext(input: {
  contexts: Array<LinkedClanContext>;
  preferredClanId: string | null;
  fallbackClanId: string;
}): LinkedClanContext | null {
  if (input.contexts.length === 0) {
    return null;
  }

  if (input.preferredClanId != null) {
    const preferred = input.contexts.find((entry) => entry.clanId === input.preferredClanId);
    if (preferred != null) {
      return preferred;
    }
  }

  const fallback = input.contexts.find((entry) => entry.clanId === input.fallbackClanId);
  if (fallback != null) {
    return fallback;
  }

  return input.contexts[0] ?? null;
}

function preferredClanContext(candidate: LinkedClanContext, current: LinkedClanContext): boolean {
  const candidateRank = rolePriority(candidate.primaryRole);
  const currentRank = rolePriority(current.primaryRole);
  if (candidateRank !== currentRank) {
    return candidateRank > currentRank;
  }

  const candidateActive = (candidate.status ?? 'active').toLowerCase() === 'active';
  const currentActive = (current.status ?? 'active').toLowerCase() === 'active';
  if (candidateActive !== currentActive) {
    return candidateActive;
  }

  return candidate.memberId.localeCompare(current.memberId) < 0;
}

function rolePriority(role: string): number {
  const normalized = normalizeRole(role);
  switch (normalized) {
    case 'SUPER_ADMIN':
      return 100;
    case 'CLAN_ADMIN':
      return 95;
    case 'CLAN_OWNER':
      return 90;
    case 'CLAN_LEADER':
      return 85;
    case 'VICE_LEADER':
      return 80;
    case 'SUPPORTER_OF_LEADER':
      return 75;
    case 'BRANCH_ADMIN':
      return 70;
    case 'ADMIN_SUPPORT':
      return 65;
    case 'TREASURER':
      return 60;
    case 'SCHOLARSHIP_COUNCIL_HEAD':
      return 55;
    case 'MEMBER':
      return 30;
    default:
      return 10;
  }
}

function normalizeRole(value: string): string {
  return value.trim().toUpperCase();
}

function buildJoinRequestReferencePath(clanId: string, joinRequestId: string): string {
  return `/clans/${clanId}/join-requests/${joinRequestId}`;
}

async function loadDiscoveryNamesByClanIds(clanIds: Array<string>): Promise<Map<string, string>> {
  const namesByClanId = new Map<string, string>();
  const normalizedClanIds = Array.from(
    new Set(
      clanIds
        .map((clanId) => clanId.trim())
        .filter((clanId) => clanId.length > 0),
    ),
  );
  if (normalizedClanIds.length === 0) {
    return namesByClanId;
  }

  for (const batch of chunkArray(normalizedClanIds, 30)) {
    const snapshot = await discoveryCollection
      .where('clanId', 'in', batch)
      .limit(batch.length)
      .get();
    for (const doc of snapshot.docs) {
      const data = doc.data() as DiscoveryRecord;
      const clanId = stringOrNull(data.clanId) ?? '';
      const name = stringOrNull(data.genealogyName) ?? '';
      if (clanId.length === 0 || name.length === 0) {
        continue;
      }
      namesByClanId.set(clanId, name);
    }
  }

  const unresolvedClanIds = normalizedClanIds.filter((clanId) => !namesByClanId.has(clanId));
  for (const clanId of unresolvedClanIds) {
    const snapshot = await discoveryCollection.doc(clanId).get();
    if (!snapshot.exists || snapshot.data() == null) {
      continue;
    }
    const data = snapshot.data() as DiscoveryRecord;
    const name = stringOrNull(data.genealogyName) ?? '';
    if (name.length > 0) {
      namesByClanId.set(clanId, name);
    }
  }

  return namesByClanId;
}

function chunkArray<T>(values: Array<T>, size: number): Array<Array<T>> {
  if (values.length === 0) {
    return [];
  }
  const chunks: Array<Array<T>> = [];
  for (let index = 0; index < values.length; index += size) {
    chunks.push(values.slice(index, index + size));
  }
  return chunks;
}

function sanitizeDiscoveryResult(
  entry: { id: string } & DiscoveryRecord,
  options?: { pendingRequestSubmittedAtEpochMs?: number | null },
) {
  const pendingRequestSubmittedAtEpochMs = options?.pendingRequestSubmittedAtEpochMs ?? null;
  const hasPendingJoinRequest = pendingRequestSubmittedAtEpochMs != null;
  const clanId = stringOrNull(entry.clanId) ?? entry.id;
  const genealogyName = stringOrNull(entry.genealogyName) ?? '';
  const leaderName = stringOrNull(entry.leaderName) ?? '';
  const provinceCity = stringOrNull(entry.provinceCity) ?? '';

  return {
    id: entry.id,
    clanId,
    genealogyName,
    leaderName,
    provinceCity,
    summary: stringOrNull(entry.summary) ?? '',
    memberCount: typeof entry.memberCount === 'number' ? entry.memberCount : 0,
    branchCount: typeof entry.branchCount === 'number' ? entry.branchCount : 0,
    hasPendingJoinRequest,
    pendingJoinRequestSubmittedAtEpochMs: pendingRequestSubmittedAtEpochMs,
    isHiddenWhilePending: false,
  };
}

function duplicateScore(
  entry: DiscoveryRecord,
  input: {
    genealogyName: string;
    leaderName: string;
    provinceCity: string;
  },
): number {
  const name = normalizeSearch(
    entry.genealogyNameNormalized ?? entry.genealogyName ?? '',
  );
  const leader = normalizeSearch(entry.leaderNameNormalized ?? entry.leaderName ?? '');
  const location = normalizeSearch(
    entry.provinceCityNormalized ?? entry.provinceCity ?? '',
  );

  let score = 0;
  if (name === input.genealogyName) {
    score += 60;
  } else if (name.includes(input.genealogyName) || input.genealogyName.includes(name)) {
    score += 40;
  } else {
    score += overlapTokenScore(name, input.genealogyName, 32);
  }

  if (leader === input.leaderName) {
    score += 25;
  } else if (leader.includes(input.leaderName) || input.leaderName.includes(leader)) {
    score += 15;
  }

  if (location === input.provinceCity) {
    score += 20;
  } else if (location.includes(input.provinceCity) || input.provinceCity.includes(location)) {
    score += 10;
  }
  return score;
}

function matchesDiscoveryQuery(
  entry: DiscoveryRecord,
  query: {
    leaderQuery: string;
    locationQuery: string;
    query: string;
  },
): boolean {
  const leader = normalizeSearch(entry.leaderNameNormalized ?? entry.leaderName ?? '');
  const location = normalizeSearch(entry.provinceCityNormalized ?? entry.provinceCity ?? '');
  const name = normalizeSearch(entry.genealogyNameNormalized ?? entry.genealogyName ?? '');

  if (query.leaderQuery.length > 0 && !leader.includes(query.leaderQuery)) {
    return false;
  }
  if (query.locationQuery.length > 0 && !location.includes(query.locationQuery)) {
    return false;
  }
  if (query.query.length > 0) {
    return leader.includes(query.query) ||
      location.includes(query.query) ||
      name.includes(query.query);
  }
  return true;
}

function overlapTokenScore(left: string, right: string, maxScore: number): number {
  const leftTokens = new Set(left.split(' ').filter(Boolean));
  const rightTokens = new Set(right.split(' ').filter(Boolean));
  if (leftTokens.size === 0 || rightTokens.size === 0) {
    return 0;
  }
  let overlap = 0;
  for (const token of leftTokens) {
    if (rightTokens.has(token)) {
      overlap += 1;
    }
  }
  const denominator = Math.max(leftTokens.size, rightTokens.size);
  const ratio = overlap / denominator;
  return Math.round(ratio * maxScore);
}

function normalizeSearch(value: string | null): string {
  const normalized = (value ?? '')
    .toLowerCase()
    .trim()
    .replace(/[àáạảãăằắặẳẵâầấậẩẫ]/g, 'a')
    .replace(/[èéẹẻẽêềếệểễ]/g, 'e')
    .replace(/[ìíịỉĩ]/g, 'i')
    .replace(/[òóọỏõôồốộổỗơờớợởỡ]/g, 'o')
    .replace(/[ùúụủũưừứựửữ]/g, 'u')
    .replace(/[ỳýỵỷỹ]/g, 'y')
    .replace(/đ/g, 'd')
    .replace(/\s+/g, ' ');
  return normalized;
}

function normalizeContact(value: string): string {
  const trimmed = value.trim();
  if (trimmed.length === 0) {
    return '';
  }
  const compact = trimmed.toLowerCase().replace(/\s+/g, '');
  if (compact.includes('@')) {
    return compact;
  }
  try {
    return normalizePhoneE164ForContact(trimmed);
  } catch {
    return compact;
  }
}

function normalizePhoneE164ForContact(input: string): string {
  const trimmed = input.trim();
  const digitsAndPlus = trimmed.replace(/[^0-9+]/g, '');
  if (digitsAndPlus.length === 0) {
    throw new Error('Invalid phone input');
  }
  const digitsOnly = digitsAndPlus.replace(/[^0-9]/g, '');
  let normalized = '';
  if (digitsAndPlus.startsWith('+')) {
    normalized = `+${digitsAndPlus.slice(1).replace(/[^0-9]/g, '')}`;
  } else if (digitsAndPlus.startsWith('00')) {
    normalized = `+${digitsAndPlus.slice(2).replace(/[^0-9]/g, '')}`;
  } else if (digitsOnly.startsWith('0')) {
    normalized = `+84${digitsOnly.slice(1)}`;
  } else if (looksLikeInternationalPhoneDigits(digitsOnly, '84')) {
    normalized = `+${digitsOnly}`;
  } else {
    normalized = `+84${digitsOnly}`;
  }

  if (normalized.startsWith('+840')) {
    normalized = `+84${normalized.slice(4)}`;
  }
  if (normalized.startsWith('+84') && normalized.length > 3 && normalized[3] === '0') {
    normalized = `+84${normalized.slice(4)}`;
  }
  if (!/^\+[1-9]\d{8,14}$/.test(normalized)) {
    throw new Error('Invalid phone format');
  }
  return normalized;
}

function looksLikeInternationalPhoneDigits(
  digits: string,
  fallbackDialCode: string,
): boolean {
  if (digits.length === 0) {
    return false;
  }
  if (digits.startsWith(fallbackDialCode) && digits.length > fallbackDialCode.length + 6) {
    return true;
  }
  for (const dialCode of SUPPORTED_PHONE_DIAL_CODES) {
    if (digits.startsWith(dialCode) && digits.length > dialCode.length + 6) {
      return true;
    }
  }
  return false;
}

function requireNonEmptyString(data: unknown, key: string): string {
  if (data == null || typeof data !== 'object') {
    throw new HttpsError('invalid-argument', `${key} is required.`);
  }
  const value = (data as Record<string, unknown>)[key];
  if (typeof value !== 'string' || value.trim().length === 0) {
    throw new HttpsError('invalid-argument', `${key} is required.`);
  }
  return value.trim();
}

function optionalString(data: unknown, key: string): string | null {
  if (data == null || typeof data !== 'object') {
    return null;
  }
  const value = (data as Record<string, unknown>)[key];
  return typeof value === 'string' ? value : null;
}

function resolveLimit(data: unknown): number {
  if (data == null || typeof data !== 'object') {
    return 20;
  }
  const value = (data as Record<string, unknown>).limit;
  if (typeof value !== 'number' || !Number.isFinite(value)) {
    return 20;
  }
  return Math.max(1, Math.min(50, Math.trunc(value)));
}

function requireDecision(data: unknown, key: string): 'approve' | 'reject' {
  const value = requireNonEmptyString(data, key).toLowerCase();
  if (value !== 'approve' && value !== 'reject') {
    throw new HttpsError('invalid-argument', `${key} must be approve or reject.`);
  }
  return value;
}

async function loadPendingJoinRequestsByApplicant(uid: string): Promise<Map<string, number>> {
  const snapshot = await joinRequestsCollection
    .where('applicantUid', '==', uid)
    .limit(300)
    .get();

  const pendingByClanId = new Map<string, number>();
  for (const doc of snapshot.docs) {
    const item = doc.data() as JoinRequestRecord;
    const clanId = stringOrNull(item.clanId);
    if (clanId == null) {
      continue;
    }
    const status = stringOrNull(item.status)?.toLowerCase() ?? 'pending';
    if (status !== 'pending') {
      continue;
    }
    const submittedAtEpochMs = timestampToEpochMillis(item.createdAt) ?? 0;
    const existing = pendingByClanId.get(clanId);
    if (existing == null || submittedAtEpochMs > existing) {
      pendingByClanId.set(clanId, submittedAtEpochMs);
    }
  }
  return pendingByClanId;
}

function timestampToEpochMillis(value: unknown): number | null {
  if (value == null) {
    return null;
  }
  if (typeof value === 'number' && Number.isFinite(value)) {
    return Math.trunc(value);
  }
  if (typeof value === 'string') {
    const epoch = Date.parse(value);
    return Number.isFinite(epoch) ? epoch : null;
  }
  if (typeof value === 'object') {
    const candidate = value as { toMillis?: () => number };
    if (typeof candidate.toMillis === 'function') {
      const epoch = candidate.toMillis();
      return Number.isFinite(epoch) ? epoch : null;
    }
  }
  return null;
}
