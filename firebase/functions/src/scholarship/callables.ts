import {
  FieldValue,
  Timestamp,
  type DocumentData,
  type Transaction,
} from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';

import { APP_REGION } from '../config/runtime';
import { requireAuth } from '../shared/errors';
import { db } from '../shared/firestore';
import { logInfo } from '../shared/logger';
import {
  GOVERNANCE_ROLES,
  ensureAnyRole,
  ensureClaimedSession,
  ensureClanAccess,
  stringOrNull,
  tokenMemberId,
  tokenPrimaryRole,
} from '../shared/permissions';

type SubmissionRecord = {
  clanId?: string | null;
  status?: string | null;
  title?: string | null;
  approvalVotes?: Array<{
    memberId?: string | null;
    decision?: string | null;
    createdAt?: string | null;
    note?: string | null;
  }> | null;
};

type MemberRecord = {
  clanId?: string | null;
  primaryRole?: string | null;
  status?: string | null;
};

const submissionsCollection = db.collection('achievementSubmissions');
const approvalLogsCollection = db.collection('scholarshipApprovalLogs');
const membersCollection = db.collection('members');

export const reviewScholarshipSubmission = onCall(
  { region: APP_REGION },
  async (request) => {
    const auth = requireAuth(request);
    ensureClaimedSession(auth.token);
    ensureAnyRole(
      auth.token,
      [GOVERNANCE_ROLES.scholarshipCouncilHead],
      'Only Scholarship Council Heads can vote on submissions.',
    );

    const memberId = tokenMemberId(auth.token);
    if (memberId == null) {
      throw new HttpsError(
        'permission-denied',
        'A linked member session is required for scholarship voting.',
      );
    }

    const submissionId = requireNonEmptyString(request.data, 'submissionId');
    const decision = requireDecision(request.data, 'decision');
    const note = stringOrNull((request.data as Record<string, unknown>)?.note);

    const actorMemberSnapshot = await membersCollection.doc(memberId).get();
    if (!actorMemberSnapshot.exists) {
      throw new HttpsError('permission-denied', 'Reviewer member record not found.');
    }

    const actorMember = actorMemberSnapshot.data() as MemberRecord;
    const clanId = stringOrNull(actorMember.clanId);
    if (clanId == null) {
      throw new HttpsError('permission-denied', 'Reviewer is not scoped to a clan.');
    }
    ensureClanAccess(auth.token, clanId);

    const actorRole = stringOrNull(actorMember.primaryRole)?.toUpperCase() ?? '';
    if (actorRole !== GOVERNANCE_ROLES.scholarshipCouncilHead) {
      throw new HttpsError(
        'permission-denied',
        'Only active Scholarship Council Heads can review submissions.',
      );
    }

    const councilSnapshot = await membersCollection
      .where('clanId', '==', clanId)
      .where('primaryRole', '==', GOVERNANCE_ROLES.scholarshipCouncilHead)
      .get();
    const activeCouncilMemberIds = councilSnapshot.docs
      .filter((doc) => {
        const status = stringOrNull((doc.data() as MemberRecord).status)?.toLowerCase();
        return status == null || status === 'active';
      })
      .map((doc) => doc.id);

    if (!activeCouncilMemberIds.includes(memberId)) {
      throw new HttpsError(
        'permission-denied',
        'Only active Scholarship Council Heads can review submissions.',
      );
    }
    if (activeCouncilMemberIds.length !== 3) {
      throw new HttpsError(
        'failed-precondition',
        'Council configuration invalid: exactly 3 active council heads are required for 2-of-3 voting.',
      );
    }

    const transactionResult = await db.runTransaction(async (transaction) => {
      const submissionRef = submissionsCollection.doc(submissionId);
      const submissionSnapshot = await transaction.get(submissionRef);
      if (!submissionSnapshot.exists || submissionSnapshot.data() == null) {
        throw new HttpsError('not-found', 'Scholarship submission was not found.');
      }

      const submission = submissionSnapshot.data() as SubmissionRecord;
      if (stringOrNull(submission.clanId) !== clanId) {
        throw new HttpsError(
          'permission-denied',
          'Submission clan context does not match reviewer clan scope.',
        );
      }

      const status = stringOrNull(submission.status)?.toLowerCase() ?? 'pending';
      if (status !== 'pending') {
        throw new HttpsError(
          'failed-precondition',
          'Submission is no longer pending review.',
        );
      }

      const existingVotes = normalizeVotes(submission.approvalVotes);
      if (existingVotes.some((vote) => vote.memberId === memberId)) {
        throw new HttpsError(
          'already-exists',
          'This council head has already voted for the submission.',
        );
      }

      const nowIso = new Date().toISOString();
      const vote = {
        memberId,
        decision,
        createdAt: nowIso,
        note,
      };
      const nextVotes = [...existingVotes, vote];
      const approvalCount = nextVotes.filter((entry) => entry.decision === 'approve').length;
      const rejectionCount = nextVotes.filter((entry) => entry.decision === 'reject').length;

      let nextStatus: 'pending' | 'approved' | 'rejected' = 'pending';
      if (approvalCount >= 2) {
        nextStatus = 'approved';
      } else if (rejectionCount >= 2) {
        nextStatus = 'rejected';
      }
      const finalDecisionReason = nextStatus === 'pending'
        ? null
        : resolveFinalDecisionReason({
          status: nextStatus,
          latestNote: note,
          votes: nextVotes,
        });

      transaction.set(
        submissionRef,
        {
          approvalVotes: nextVotes,
          approvalCount,
          rejectionCount,
          status: nextStatus,
          finalDecisionReason,
          reviewNote: finalDecisionReason,
          reviewedBy: nextStatus === 'pending' ? null : memberId,
          reviewedAt: nextStatus === 'pending' ? null : FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
          updatedBy: memberId,
        },
        { merge: true },
      );

      writeApprovalLog(transaction, {
        clanId,
        submissionId,
        action: 'vote',
        decision,
        actorMemberId: memberId,
        actorRole,
        note,
      });
      if (nextStatus !== 'pending') {
        writeApprovalLog(transaction, {
          clanId,
          submissionId,
          action: 'finalized',
          decision: nextStatus,
          actorMemberId: memberId,
          actorRole,
          note: finalDecisionReason,
        });
      }

      return {
        status: nextStatus,
        approvalCount,
        rejectionCount,
      };
    });

    const updated = await submissionsCollection.doc(submissionId).get();
    const submissionData = updated.data() ?? {};

    logInfo('reviewScholarshipSubmission succeeded', {
      uid: auth.uid,
      actorMemberId: memberId,
      actorRole: tokenPrimaryRole(auth.token),
      submissionId,
      decision,
      clanId,
      ...transactionResult,
    });

    return {
      submission: normalizeFirestoreValue(submissionData),
      ...transactionResult,
    };
  },
);

function writeApprovalLog(
  transaction: Transaction,
  input: {
    clanId: string;
    submissionId: string;
    action: string;
    decision: string;
    actorMemberId: string;
    actorRole: string;
    note: string | null;
  },
): void {
  const ref = approvalLogsCollection.doc();
  transaction.set(ref, {
    id: ref.id,
    clanId: input.clanId,
    submissionId: input.submissionId,
    action: input.action,
    decision: input.decision,
    actorMemberId: input.actorMemberId,
    actorRole: input.actorRole,
    note: input.note,
    createdAt: FieldValue.serverTimestamp(),
  });
}

function normalizeVotes(input: SubmissionRecord['approvalVotes']): Array<{
  memberId: string;
  decision: 'approve' | 'reject';
  createdAt: string;
  note: string | null;
}> {
  if (!Array.isArray(input)) {
    return [];
  }
  const votes: Array<{
    memberId: string;
    decision: 'approve' | 'reject';
    createdAt: string;
    note: string | null;
  }> = [];

  for (const raw of input) {
    const memberId = stringOrNull(raw?.memberId);
    const decision = stringOrNull(raw?.decision)?.toLowerCase();
    const createdAt = stringOrNull(raw?.createdAt);
    if (memberId == null || createdAt == null) {
      continue;
    }
    if (decision !== 'approve' && decision !== 'reject') {
      continue;
    }
    votes.push({
      memberId,
      decision,
      createdAt,
      note: stringOrNull(raw?.note),
    });
  }
  return votes;
}

function resolveFinalDecisionReason(input: {
  status: 'approved' | 'rejected';
  latestNote: string | null;
  votes: Array<{
    memberId: string;
    decision: 'approve' | 'reject';
    createdAt: string;
    note: string | null;
  }>;
}): string | null {
  const latest = stringOrNull(input.latestNote);
  if (latest != null) {
    return latest;
  }

  const decision = input.status === 'approved' ? 'approve' : 'reject';
  for (let index = input.votes.length - 1; index >= 0; index -= 1) {
    const vote = input.votes[index];
    if (vote.decision !== decision) {
      continue;
    }
    const resolved = stringOrNull(vote.note);
    if (resolved != null) {
      return resolved;
    }
  }

  return null;
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

function requireDecision(data: unknown, key: string): 'approve' | 'reject' {
  const value = requireNonEmptyString(data, key).toLowerCase();
  if (value !== 'approve' && value !== 'reject') {
    throw new HttpsError('invalid-argument', `${key} must be approve or reject.`);
  }
  return value;
}

function normalizeFirestoreValue(value: unknown): unknown {
  if (value instanceof Timestamp) {
    return value.toDate().toISOString();
  }
  if (Array.isArray(value)) {
    return value.map((entry) => normalizeFirestoreValue(entry));
  }
  if (value != null && typeof value === 'object') {
    const normalized: Record<string, unknown> = {};
    for (const [key, entry] of Object.entries(value as DocumentData)) {
      normalized[key] = normalizeFirestoreValue(entry);
    }
    return normalized;
  }
  return value;
}
