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
  tokenClanIds,
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

    const assignmentResult = await db.runTransaction(async (transaction) => {
      const memberRef = membersCollection.doc(memberId);
      const memberSnapshot = await transaction.get(memberRef);
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

      const previousRole =
        stringOrNull(member.primaryRole)?.toUpperCase() ?? GOVERNANCE_ROLES.member;
      const isRoleChanged = previousRole !== nextRole;
      if (!isRoleChanged) {
        return {
          memberId,
          clanId,
          previousRole,
          nextRole,
          status: 'unchanged' as const,
        };
      }

      const isActiveMember = isActiveStatus(member.status);
      const isSeatTransition = (
        previousRole === GOVERNANCE_ROLES.scholarshipCouncilHead ||
        nextRole === GOVERNANCE_ROLES.scholarshipCouncilHead
      );

      if (isSeatTransition && isActiveMember) {
        const councilSnapshot = await transaction.get(
          membersCollection
            .where('clanId', '==', clanId)
            .where('primaryRole', '==', GOVERNANCE_ROLES.scholarshipCouncilHead),
        );

        const activeSeatCount = councilSnapshot.docs.filter((doc) => {
          return isActiveStatus((doc.data() as MemberRecord).status);
        }).length;

        const isCurrentlySeatHolder = previousRole === GOVERNANCE_ROLES.scholarshipCouncilHead;
        const isNextSeatHolder = nextRole === GOVERNANCE_ROLES.scholarshipCouncilHead;
        const projectedSeatCount = activeSeatCount + (
          isNextSeatHolder ? 1 : 0
        ) - (
          isCurrentlySeatHolder ? 1 : 0
        );

        if (projectedSeatCount > 3) {
          throw new HttpsError(
            'failed-precondition',
            'Scholarship Council Head seats are full. Maximum 3 active seats are allowed.',
          );
        }
      }

      transaction.set(
        memberRef,
        {
          primaryRole: nextRole,
          updatedAt: FieldValue.serverTimestamp(),
          updatedBy: actorMemberId,
        },
        { merge: true },
      );

      const assignmentRef = roleAssignmentsCollection.doc();
      transaction.set(assignmentRef, {
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
      transaction.set(auditRef, {
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

      return {
        memberId,
        clanId,
        previousRole,
        nextRole,
        status: 'updated' as const,
      };
    });

    logInfo('assignGovernanceRole succeeded', {
      uid: auth.uid,
      clanId: assignmentResult.clanId,
      memberId: assignmentResult.memberId,
      previousRole: assignmentResult.previousRole,
      nextRole: assignmentResult.nextRole,
      status: assignmentResult.status,
    });

    return assignmentResult;
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

    const clanId = resolveDashboardClanId({
      token: auth.token,
      requestedClanId: optionalNonEmptyString(request.data, 'clanId'),
    });
    if (clanId == null) {
      throw new HttpsError('failed-precondition', 'No clan context was found for this session.');
    }
    ensureClanAccess(auth.token, clanId);

    const [fundSnapshot, transactionSnapshot, submissionSnapshot] = await Promise.all([
      fundsCollection.where('clanId', '==', clanId).get(),
      loadTransactionsForDashboard(clanId),
      loadScholarshipRequestsForDashboard(clanId),
    ]);

    const funds = fundSnapshot.docs.map((doc) => normalizeFirestoreValue(doc.data()));
    const transactions = transactionSnapshot.docs
      .map((doc) => normalizeFirestoreValue(doc.data()))
      .filter(isPlainRecord)
      .sort((left, right) => compareDateDesc(left, right, 'occurredAt', { fallbackKey: 'createdAt' }));
    const submissions = submissionSnapshot.docs
      .map((doc) => normalizeFirestoreValue(doc.data()))
      .filter(isPlainRecord)
      .sort((left, right) => compareDateDesc(left, right, 'updatedAt', { fallbackKey: 'createdAt' }));
    const donationHistory = transactions
      .filter((entry) => stringOrNull(entry['transactionType'])?.toLowerCase() == 'donation')
      .slice();

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
      donationHistory,
      scholarshipRequests: submissions,
      scholarshipRequestHistory: submissions,
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

function optionalNonEmptyString(data: unknown, key: string): string | null {
  if (data == null || typeof data !== 'object') {
    return null;
  }
  const value = (data as Record<string, unknown>)[key];
  return stringOrNull(value);
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

function isActiveStatus(value: unknown): boolean {
  const normalized = stringOrNull(value)?.toLowerCase();
  return normalized == null || normalized === 'active';
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

function isPlainRecord(value: unknown): value is Record<string, unknown> {
  return value != null && typeof value === 'object' && !Array.isArray(value);
}

function resolveDashboardClanId({
  token,
  requestedClanId,
}: {
  token: Parameters<typeof tokenClanIds>[0];
  requestedClanId: string | null;
}): string | null {
  const clanIds = tokenClanIds(token);
  if (requestedClanId != null) {
    return requestedClanId;
  }
  const tokenRecord = token as Record<string, unknown>;
  const activeClanId =
    stringOrNull(tokenRecord.activeClanId) ??
    stringOrNull(tokenRecord.clanId);
  if (activeClanId != null && clanIds.includes(activeClanId)) {
    return activeClanId;
  }
  return clanIds[0] ?? null;
}

async function loadTransactionsForDashboard(
  clanId: string,
): Promise<FirebaseFirestore.QuerySnapshot<FirebaseFirestore.DocumentData>> {
  const query = transactionsCollection.where('clanId', '==', clanId);
  try {
    return await query.orderBy('occurredAt', 'desc').limit(400).get();
  } catch (error) {
    if (!isMissingCompositeIndexError(error)) {
      throw error;
    }
    return query.limit(1200).get();
  }
}

async function loadScholarshipRequestsForDashboard(
  clanId: string,
): Promise<FirebaseFirestore.QuerySnapshot<FirebaseFirestore.DocumentData>> {
  const query = submissionsCollection.where('clanId', '==', clanId);
  try {
    return await query.orderBy('updatedAt', 'desc').limit(240).get();
  } catch (error) {
    if (!isMissingCompositeIndexError(error)) {
      throw error;
    }
    return query.limit(800).get();
  }
}

function isMissingCompositeIndexError(error: unknown): boolean {
  if (error == null || typeof error !== 'object') {
    return false;
  }
  const message = String((error as { message?: unknown }).message ?? '').toLowerCase();
  const code = String((error as { code?: unknown }).code ?? '').toLowerCase();
  return code.includes('failed-precondition') && message.includes('index');
}

function compareDateDesc(
  left: Record<string, unknown>,
  right: Record<string, unknown>,
  key: string,
  options: { fallbackKey?: string } = {},
): number {
  const leftTime = readDateEpochMs(left[key]) || readDateEpochMs(left[options.fallbackKey ?? '']);
  const rightTime = readDateEpochMs(right[key]) || readDateEpochMs(right[options.fallbackKey ?? '']);
  return rightTime - leftTime;
}

function readDateEpochMs(value: unknown): number {
  if (value == null) {
    return 0;
  }
  if (value instanceof Date) {
    return value.getTime();
  }
  if (typeof value === 'string') {
    const parsed = Date.parse(value);
    return Number.isNaN(parsed) ? 0 : parsed;
  }
  if (typeof value === 'object' && 'toDate' in (value as object)) {
    try {
      const parsed = (value as { toDate: () => Date }).toDate();
      return parsed.getTime();
    } catch (_) {
      return 0;
    }
  }
  return 0;
}
