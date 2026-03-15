import { FieldValue } from 'firebase-admin/firestore';
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

type MemberRecord = {
  clanId?: string | null;
  primaryRole?: string | null;
  status?: string | null;
};

const membersCollection = db.collection('members');
const fundsCollection = db.collection('funds');
const transactionsCollection = db.collection('transactions');
const submissionsCollection = db.collection('achievementSubmissions');
const roleAssignmentsCollection = db.collection('governanceRoleAssignments');
const auditLogsCollection = db.collection('auditLogs');

const supportedGovernanceRoles = new Set<string>([
  GOVERNANCE_ROLES.treasurer,
  GOVERNANCE_ROLES.scholarshipCouncilHead,
  GOVERNANCE_ROLES.adminSupport,
  GOVERNANCE_ROLES.branchAdmin,
  GOVERNANCE_ROLES.member,
]);

export const assignGovernanceRole = onCall(
  { region: APP_REGION },
  async (request) => {
    const auth = requireAuth(request);
    ensureClaimedSession(auth.token);
    ensureAnyRole(
      auth.token,
      [GOVERNANCE_ROLES.superAdmin, GOVERNANCE_ROLES.clanAdmin],
      'Only Clan Admin or Super Admin can assign governance roles.',
    );

    const actorMemberId = tokenMemberId(auth.token) ?? auth.uid;
    const memberId = requireNonEmptyString(request.data, 'memberId');
    const nextRole = requireSupportedRole(request.data, 'role');
    const reason = stringOrNull((request.data as Record<string, unknown>)?.reason);

    const memberSnapshot = await membersCollection.doc(memberId).get();
    if (!memberSnapshot.exists || memberSnapshot.data() == null) {
      throw new HttpsError('not-found', 'Target member was not found.');
    }
    const member = memberSnapshot.data() as MemberRecord;
    const clanId = stringOrNull(member.clanId);
    if (clanId == null) {
      throw new HttpsError(
        'failed-precondition',
        'Target member does not belong to a clan context.',
      );
    }
    ensureClanAccess(auth.token, clanId);

    const previousRole = stringOrNull(member.primaryRole)?.toUpperCase() ?? GOVERNANCE_ROLES.member;

    if (
      nextRole === GOVERNANCE_ROLES.scholarshipCouncilHead &&
      previousRole !== GOVERNANCE_ROLES.scholarshipCouncilHead
    ) {
      const councilSnapshot = await membersCollection
        .where('clanId', '==', clanId)
        .where('primaryRole', '==', GOVERNANCE_ROLES.scholarshipCouncilHead)
        .limit(4)
        .get();
      const activeSeats = councilSnapshot.docs.filter((doc) => {
        const status = stringOrNull((doc.data() as MemberRecord).status)?.toLowerCase();
        return status == null || status === 'active';
      }).length;
      if (activeSeats >= 3) {
        throw new HttpsError(
          'failed-precondition',
          'Scholarship Council Head seats are full (max 3 active).',
        );
      }
    }

    await membersCollection.doc(memberId).set(
      {
        primaryRole: nextRole,
        updatedAt: FieldValue.serverTimestamp(),
        updatedBy: actorMemberId,
      },
      { merge: true },
    );

    const assignmentRef = roleAssignmentsCollection.doc();
    await assignmentRef.set({
      id: assignmentRef.id,
      clanId,
      memberId,
      previousRole,
      nextRole,
      actorMemberId,
      actorRole: tokenPrimaryRole(auth.token),
      reason,
      createdAt: FieldValue.serverTimestamp(),
    });

    const auditRef = auditLogsCollection.doc();
    await auditRef.set({
      id: auditRef.id,
      clanId,
      action: 'governance_role_assigned',
      entityType: 'member',
      entityId: memberId,
      uid: auth.uid,
      memberId: actorMemberId,
      before: { primaryRole: previousRole },
      after: { primaryRole: nextRole },
      reason,
      createdAt: FieldValue.serverTimestamp(),
    });

    logInfo('assignGovernanceRole succeeded', {
      uid: auth.uid,
      clanId,
      memberId,
      previousRole,
      nextRole,
    });

    return {
      memberId,
      clanId,
      previousRole,
      nextRole,
      status: 'updated',
    };
  },
);

export const getTreasurerDashboard = onCall(
  { region: APP_REGION },
  async (request) => {
    const auth = requireAuth(request);
    ensureClaimedSession(auth.token);
    ensureAnyRole(
      auth.token,
      [
        GOVERNANCE_ROLES.superAdmin,
        GOVERNANCE_ROLES.clanAdmin,
        GOVERNANCE_ROLES.branchAdmin,
        GOVERNANCE_ROLES.treasurer,
      ],
      'Finance dashboard is available to finance governance roles only.',
    );

    const clanIdsRaw = Array.isArray(auth.token.clanIds) ? auth.token.clanIds : [];
    const clanIds = clanIdsRaw
      .filter((entry): entry is string => typeof entry === 'string')
      .map((entry) => entry.trim())
      .filter((entry) => entry.length > 0);
    const clanId = clanIds[0] ?? null;
    if (clanId == null) {
      throw new HttpsError('failed-precondition', 'No clan context was found for this session.');
    }

    const [fundSnapshot, transactionSnapshot, submissionSnapshot] = await Promise.all([
      fundsCollection.where('clanId', '==', clanId).get(),
      transactionsCollection
        .where('clanId', '==', clanId)
        .orderBy('occurredAt', 'desc')
        .limit(200)
        .get(),
      submissionsCollection
        .where('clanId', '==', clanId)
        .orderBy('updatedAt', 'desc')
        .limit(100)
        .get(),
    ]);

    const funds = fundSnapshot.docs.map((doc) => normalizeFirestoreValue(doc.data()));
    const transactions = transactionSnapshot.docs.map((doc) => normalizeFirestoreValue(doc.data()));
    const submissions = submissionSnapshot.docs.map((doc) => normalizeFirestoreValue(doc.data()));

    const totalBalanceMinor = fundSnapshot.docs.reduce((sum, doc) => {
      const balance = doc.data().balanceMinor;
      return sum + (typeof balance === 'number' ? Math.trunc(balance) : 0);
    }, 0);

    const totalDonationsMinor = transactionSnapshot.docs.reduce((sum, doc) => {
      const data = doc.data();
      const type = stringOrNull(data.transactionType)?.toLowerCase();
      const amount = data.amountMinor;
      if (type !== 'donation' || typeof amount !== 'number') {
        return sum;
      }
      return sum + Math.trunc(amount);
    }, 0);

    const totalExpensesMinor = transactionSnapshot.docs.reduce((sum, doc) => {
      const data = doc.data();
      const type = stringOrNull(data.transactionType)?.toLowerCase();
      const amount = data.amountMinor;
      if (type !== 'expense' || typeof amount !== 'number') {
        return sum;
      }
      return sum + Math.trunc(amount);
    }, 0);

    const reportSummary = [
      `Finance summary for clan ${clanId}`,
      `Total balance: ${totalBalanceMinor} minor units`,
      `Donations tracked: ${totalDonationsMinor} minor units`,
      `Expenses tracked: ${totalExpensesMinor} minor units`,
      `Scholarship requests tracked: ${submissionSnapshot.size}`,
      `Generated at: ${new Date().toISOString()}`,
    ].join('\n');

    logInfo('getTreasurerDashboard succeeded', {
      uid: auth.uid,
      clanId,
      funds: fundSnapshot.size,
      transactions: transactionSnapshot.size,
      submissions: submissionSnapshot.size,
    });

    return {
      clanId,
      totals: {
        totalBalanceMinor,
        totalDonationsMinor,
        totalExpensesMinor,
      },
      funds,
      transactions,
      scholarshipRequests: submissions,
      reportSummary,
    };
  },
);

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

function requireSupportedRole(data: unknown, key: string): string {
  const value = requireNonEmptyString(data, key).toUpperCase();
  if (!supportedGovernanceRoles.has(value)) {
    throw new HttpsError(
      'invalid-argument',
      `${key} is not a supported governance role.`,
    );
  }
  return value;
}

function normalizeFirestoreValue(value: unknown): unknown {
  if (value instanceof Date) {
    return value.toISOString();
  }
  if (value != null && typeof value === 'object') {
    const normalized: Record<string, unknown> = {};
    for (const [key, entry] of Object.entries(value as Record<string, unknown>)) {
      if (entry != null && typeof entry === 'object' && 'toDate' in (entry as object)) {
        try {
          const dateValue = (entry as { toDate: () => Date }).toDate();
          normalized[key] = dateValue.toISOString();
          continue;
        } catch (_) {
          normalized[key] = null;
          continue;
        }
      }
      normalized[key] = normalizeFirestoreValue(entry);
    }
    return normalized;
  }
  return value;
}
