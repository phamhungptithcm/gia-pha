import {
  FieldValue,
  type Transaction,
} from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';

import {
  resolveOwnerBillingPolicy,
  type OwnerBillingPolicySummary,
} from '../billing/store';
import { resolvePlanByMemberCount } from '../billing/pricing';
import { APP_REGION } from '../config/runtime';
import { requireAuth } from '../shared/errors';
import { db } from '../shared/firestore';
import { logWarn } from '../shared/logger';
import {
  ensureClaimedSession,
  tokenClanIds,
  type AuthToken,
} from '../shared/permissions';

const membersCollection = db.collection('members');
const branchesCollection = db.collection('branches');
const clansCollection = db.collection('clans');

const CLAN_MEMBER_MANAGER_ROLES = new Set([
  'SUPER_ADMIN',
  'CLAN_ADMIN',
  'CLAN_OWNER',
  'CLAN_LEADER',
  'ADMIN_SUPPORT',
]);
const BRANCH_ADMIN_ROLE = 'BRANCH_ADMIN';

type CreateClanMemberInput = {
  clanId: string;
  branchId: string | null;
  parentIds: Array<string>;
  fullName: string;
  nickName: string;
  gender: string | null;
  birthDate: string | null;
  deathDate: string | null;
  phoneE164: string | null;
  email: string | null;
  addressText: string | null;
  jobTitle: string | null;
  bio: string | null;
  siblingOrder: number | null;
  generation: number;
  socialLinks: Record<string, string | null>;
  primaryRole: string;
  status: string;
  isMinor: boolean;
};

type MemberCreateTransactionResult = {
  member: Record<string, unknown>;
  memberCountAfterCreate: number;
  maxMembersAllowed: number;
  parentIds: Array<string>;
  branchId: string;
};

type ClanOwnerScope = {
  ownerUid: string;
  ownerDisplayName: string;
};

type ActorRoleContext = {
  role: string;
  branchId: string | null;
};

export const createClanMember = onCall({ region: APP_REGION }, async (request) => {
  const auth = requireAuth(request);
  ensureClaimedSession(auth.token);

  const input = parseCreateClanMemberInput(auth.token, request.data);
  const actorUid = auth.uid;
  const actorId = normalizeString(auth.token.memberId) || actorUid;
  const now = new Date();
  const clanOwnerScope = await resolveClanOwnerScope(input.clanId);
  const ownerPolicy = await resolveOwnerBillingPolicy({
    ownerUid: clanOwnerScope.ownerUid,
    now,
  });
  const observedMemberCount = await countMembersForClan(input.clanId);
  const memberRef = membersCollection.doc();

  const created = await db.runTransaction(async (transaction) => createMemberInTransaction({
    transaction,
    authToken: auth.token,
    actorUid,
    actorId,
    input,
    clanOwnerScope,
    ownerPolicy,
    memberRefId: memberRef.id,
    observedMemberCount,
  }));

  if (created.parentIds.length > 0) {
    try {
      await syncSiblingOrder({
        clanId: input.clanId,
        parentIds: created.parentIds,
        actorId,
      });
    } catch (error) {
      logWarn('createClanMember sibling order sync failed', {
        clanId: input.clanId,
        memberId: memberRef.id,
        error: `${error}`,
      });
    }
  }

  try {
    await Promise.all([
      syncClanMemberCount({
        clanId: input.clanId,
        actorId,
      }),
      syncBranchMemberCount({
        clanId: input.clanId,
        branchId: created.branchId,
        actorId,
      }),
    ]);
  } catch (error) {
    logWarn('createClanMember count sync failed', {
      clanId: input.clanId,
      memberId: memberRef.id,
      error: `${error}`,
    });
  }

  return {
    member: created.member,
    memberCount: created.memberCountAfterCreate,
    maxMembersAllowed: created.maxMembersAllowed,
  };
});

async function createMemberInTransaction({
  transaction,
  authToken,
  actorUid,
  actorId,
  input,
  clanOwnerScope,
  ownerPolicy,
  memberRefId,
  observedMemberCount,
}: {
  transaction: Transaction;
  authToken: AuthToken;
  actorUid: string;
  actorId: string;
  input: CreateClanMemberInput;
  clanOwnerScope: ClanOwnerScope;
  ownerPolicy: OwnerBillingPolicySummary;
  memberRefId: string;
  observedMemberCount: number;
}): Promise<MemberCreateTransactionResult> {
  const clanRef = clansCollection.doc(input.clanId);
  const memberRef = membersCollection.doc(memberRefId);
  const clanSnapshot = await transaction.get(clanRef);
  if (!clanSnapshot.exists) {
    throw new HttpsError('not-found', 'Clan was not found.');
  }

  const clanData = asRecord(clanSnapshot.data());
  if (clanData == null) {
    throw new HttpsError('not-found', 'Clan was not found.');
  }
  if (!isActiveMemberStatus(clanData.status)) {
    throw new HttpsError(
      'failed-precondition',
      'This clan is currently inactive. Contact the clan owner to reactivate billing before adding members.',
    );
  }

  const maxMembersAllowed = resolveOwnerMaxMembersAllowed(ownerPolicy);
  const trackedMemberCount = readPositiveInt(clanData.memberCount, observedMemberCount);
  const currentMemberCount = Math.max(trackedMemberCount, observedMemberCount);
  const observedClanMemberCountForPolicy =
    ownerPolicy.clans.find((clan) => clan.clanId == input.clanId)?.memberCount ??
    observedMemberCount;
  const ownerMemberCountBeforeCreate = Math.max(
    0,
    ownerPolicy.totalMemberCount - observedClanMemberCountForPolicy + currentMemberCount,
  );
  const projectedOwnerMemberCount = ownerMemberCountBeforeCreate + 1;
  if (projectedOwnerMemberCount > maxMembersAllowed) {
    const requiredTier = resolvePlanByMemberCount(projectedOwnerMemberCount);
    const ownerLabel = clanOwnerScope.ownerDisplayName;
    throw new HttpsError(
      'resource-exhausted',
      `Current owner plan ${ownerPolicy.highestActivePlanCode} allows up to ${maxMembersAllowed} members across owned clans. Contact ${ownerLabel} to upgrade to ${requiredTier.planCode} before adding more members.`,
      {
        reason: 'owner_plan_member_limit_exceeded',
        clanId: input.clanId,
        ownerUid: clanOwnerScope.ownerUid,
        ownerDisplayName: ownerLabel,
        currentPlanCode: ownerPolicy.highestActivePlanCode,
        requiredPlanCode: requiredTier.planCode,
        ownerTotalMemberCount: ownerMemberCountBeforeCreate,
        projectedOwnerMemberCount,
        allowedMemberLimit: maxMembersAllowed,
      },
    );
  }

  if (input.phoneE164 != null) {
    const sameClanSnapshot = await transaction.get(
      membersCollection.where('clanId', '==', input.clanId),
    );
    const hasDuplicatePhone = sameClanSnapshot.docs.some((doc) => {
      const data = asRecord(doc.data());
      const existingPhone = normalizeNullableString(data?.phoneE164);
      return phonesEquivalent(existingPhone, input.phoneE164);
    });
    if (hasDuplicatePhone) {
      throw new HttpsError(
        'already-exists',
        'A member with this phone number already exists in the clan.',
      );
    }
  }

  const normalizedParentIds = input.parentIds
    .filter((parentId) => parentId !== memberRef.id)
    .filter((parentId, index, list) => list.indexOf(parentId) == index);
  if (normalizedParentIds.length > 2) {
    throw new HttpsError(
      'invalid-argument',
      'Only up to two parents can be linked on create.',
    );
  }

  const parentSnapshots = await Promise.all(
    normalizedParentIds.map((parentId) => transaction.get(membersCollection.doc(parentId))),
  );

  let resolvedBranchId = input.branchId;
  let resolvedGeneration = input.generation;
  if (parentSnapshots.length > 0) {
    const primaryParentData = asRecord(parentSnapshots[0].data());
    if (!parentSnapshots[0].exists || primaryParentData == null) {
      throw new HttpsError('failed-precondition', 'Parent member was not found.');
    }
    if (normalizeString(primaryParentData.clanId) != input.clanId) {
      throw new HttpsError(
        'permission-denied',
        'Parent member belongs to a different clan.',
      );
    }

    const parentBranchId = normalizeString(primaryParentData.branchId);
    if (parentBranchId.length == 0) {
      throw new HttpsError(
        'failed-precondition',
        'Parent member does not belong to a valid branch.',
      );
    }
    resolvedBranchId = parentBranchId;
    resolvedGeneration = readPositiveInt(primaryParentData.generation, 1) + 1;

    for (const parentSnapshot of parentSnapshots) {
      const parentData = asRecord(parentSnapshot.data());
      if (!parentSnapshot.exists || parentData == null) {
        throw new HttpsError('failed-precondition', 'Parent member was not found.');
      }
      if (normalizeString(parentData.clanId) != input.clanId) {
        throw new HttpsError(
          'permission-denied',
          'Parent member belongs to a different clan.',
        );
      }
      if (normalizeString(parentData.branchId) != parentBranchId) {
        throw new HttpsError(
          'failed-precondition',
          'All selected parents must be in the same branch.',
        );
      }
    }
  }

  if (resolvedBranchId == null || resolvedBranchId.length == 0) {
    throw new HttpsError('invalid-argument', 'branchId is required.');
  }
  const actorRoleContext = await resolveActorRoleContextForClan({
    transaction,
    token: authToken,
    actorUid,
    clanId: input.clanId,
  });
  ensureCreateMemberRole({
    actorRoleContext,
    branchId: resolvedBranchId,
  });

  const branchRef = branchesCollection.doc(resolvedBranchId);
  const branchSnapshot = await transaction.get(branchRef);
  const branchData = asRecord(branchSnapshot.data());
  if (!branchSnapshot.exists || branchData == null) {
    throw new HttpsError('failed-precondition', 'Selected branch does not exist.');
  }
  if (normalizeString(branchData.clanId) != input.clanId) {
    throw new HttpsError(
      'permission-denied',
      'Selected branch belongs to a different clan.',
    );
  }

  const memberPayload: Record<string, unknown> = {
    id: memberRef.id,
    clanId: input.clanId,
    branchId: resolvedBranchId,
    householdId: null,
    fullName: input.fullName,
    normalizedFullName: input.fullName.toLowerCase(),
    nickName: input.nickName,
    gender: input.gender,
    birthDate: input.birthDate,
    deathDate: input.deathDate,
    phoneE164: input.phoneE164,
    email: input.email,
    addressText: input.addressText,
    jobTitle: input.jobTitle,
    avatarUrl: null,
    bio: input.bio,
    socialLinks: input.socialLinks,
    parentIds: normalizedParentIds,
    childrenIds: [],
    spouseIds: [],
    siblingOrder: normalizedParentIds.length == 0 ? null : input.siblingOrder,
    generation: resolvedGeneration,
    lineagePath: [input.clanId, resolvedBranchId],
    primaryRole: input.primaryRole,
    status: input.status,
    isMinor: input.isMinor,
    authUid: null,
    claimedAt: null,
    createdAt: FieldValue.serverTimestamp(),
    createdBy: actorUid,
    updatedAt: FieldValue.serverTimestamp(),
    updatedBy: actorId,
  };

  transaction.set(memberRef, memberPayload, { merge: true });

  for (const parentSnapshot of parentSnapshots) {
    transaction.set(
      parentSnapshot.ref,
      {
        childrenIds: FieldValue.arrayUnion(memberRef.id),
        updatedAt: FieldValue.serverTimestamp(),
        updatedBy: actorId,
      },
      { merge: true },
    );
  }

  transaction.set(
    clanRef,
    {
      memberCount: currentMemberCount + 1,
      updatedAt: FieldValue.serverTimestamp(),
      updatedBy: actorId,
    },
    { merge: true },
  );

  const existingBranchCount = readPositiveInt(branchData.memberCount, 0);
  transaction.set(
    branchRef,
    {
      memberCount: existingBranchCount + 1,
      updatedAt: FieldValue.serverTimestamp(),
      updatedBy: actorId,
    },
    { merge: true },
  );

  return {
    member: {
      id: memberRef.id,
      clanId: input.clanId,
      branchId: resolvedBranchId,
      fullName: input.fullName,
      normalizedFullName: input.fullName.toLowerCase(),
      nickName: input.nickName,
      gender: input.gender,
      birthDate: input.birthDate,
      deathDate: input.deathDate,
      phoneE164: input.phoneE164,
      email: input.email,
      addressText: input.addressText,
      jobTitle: input.jobTitle,
      avatarUrl: null,
      bio: input.bio,
      socialLinks: input.socialLinks,
      parentIds: normalizedParentIds,
      childrenIds: [],
      spouseIds: [],
      siblingOrder: normalizedParentIds.length == 0 ? null : input.siblingOrder,
      generation: resolvedGeneration,
      primaryRole: input.primaryRole,
      status: input.status,
      isMinor: input.isMinor,
      authUid: null,
    },
    memberCountAfterCreate: currentMemberCount + 1,
    maxMembersAllowed,
    parentIds: normalizedParentIds,
    branchId: resolvedBranchId,
  };
}

function parseCreateClanMemberInput(token: AuthToken, data: unknown): CreateClanMemberInput {
  const payload = asRecord(data);
  if (payload == null) {
    throw new HttpsError('invalid-argument', 'Payload is required.');
  }

  const clanId = resolveClanId(token, normalizeString(payload.clanId));
  const fullName = normalizeString(payload.fullName);
  if (fullName.length == 0) {
    throw new HttpsError('invalid-argument', 'fullName is required.');
  }

  return {
    clanId,
    branchId: normalizeNullableString(payload.branchId),
    parentIds: normalizeStringList(payload.parentIds),
    fullName,
    nickName: normalizeString(payload.nickName),
    gender: normalizeNullableString(payload.gender),
    birthDate: normalizeNullableString(payload.birthDate),
    deathDate: normalizeNullableString(payload.deathDate),
    phoneE164: normalizeNullablePhone(payload.phoneE164),
    email: normalizeNullableString(payload.email),
    addressText: normalizeNullableString(payload.addressText),
    jobTitle: normalizeNullableString(payload.jobTitle),
    bio: normalizeNullableString(payload.bio),
    siblingOrder: readNullablePositiveInt(payload.siblingOrder),
    generation: readPositiveInt(payload.generation, 1),
    socialLinks: normalizeSocialLinks(payload.socialLinks),
    primaryRole: normalizeString(payload.primaryRole) || 'MEMBER',
    status: normalizeString(payload.status) || 'active',
    isMinor: Boolean(payload.isMinor),
  };
}

function resolveClanId(token: AuthToken, requestedClanId: string): string {
  const clans = tokenClanIds(token);
  if (requestedClanId.length > 0) {
    if (!clans.includes(requestedClanId)) {
      throw new HttpsError(
        'permission-denied',
        'This session does not have access to the requested clan.',
      );
    }
    return requestedClanId;
  }
  if (clans.length == 0) {
    throw new HttpsError(
      'permission-denied',
      'This session is not linked to any clan.',
    );
  }
  return clans[0];
}

function ensureCreateMemberRole({
  actorRoleContext,
  branchId,
}: {
  actorRoleContext: ActorRoleContext;
  branchId: string;
}): void {
  const role = actorRoleContext.role;
  if (CLAN_MEMBER_MANAGER_ROLES.has(role)) {
    return;
  }
  if (role == BRANCH_ADMIN_ROLE) {
    const scopedBranchId = actorRoleContext.branchId ?? '';
    if (scopedBranchId.length > 0 && scopedBranchId == branchId) {
      return;
    }
  }
  throw new HttpsError(
    'permission-denied',
    'This role cannot add members to the requested branch.',
  );
}

function resolveOwnerMaxMembersAllowed(policy: OwnerBillingPolicySummary): number {
  const maxMembers = policy.highestActiveTier.maxMembers;
  return maxMembers == null ? Number.MAX_SAFE_INTEGER : maxMembers;
}

async function resolveClanOwnerScope(clanId: string): Promise<ClanOwnerScope> {
  const clanSnapshot = await clansCollection.doc(clanId).get();
  if (!clanSnapshot.exists) {
    throw new HttpsError('not-found', 'Clan was not found.');
  }
  const clanData = asRecord(clanSnapshot.data());
  if (clanData == null) {
    throw new HttpsError('not-found', 'Clan was not found.');
  }
  const ownerUid = normalizeString(clanData.ownerUid);
  if (ownerUid.length == 0) {
    throw new HttpsError(
      'failed-precondition',
      'Clan owner is missing.',
    );
  }

  let ownerDisplayName = normalizeString(clanData.founderName);
  if (ownerDisplayName.length == 0) {
    const ownerMemberSnapshot = await membersCollection
      .where('clanId', '==', clanId)
      .where('authUid', '==', ownerUid)
      .limit(1)
      .get();
    if (!ownerMemberSnapshot.empty) {
      const ownerMemberData = asRecord(ownerMemberSnapshot.docs[0]?.data());
      ownerDisplayName =
        normalizeString(ownerMemberData?.fullName) ||
        normalizeString(ownerMemberData?.nickName);
    }
  }
  return {
    ownerUid,
    ownerDisplayName: ownerDisplayName.length > 0 ? ownerDisplayName : ownerUid,
  };
}

async function resolveActorRoleContextForClan({
  transaction,
  token,
  actorUid,
  clanId,
}: {
  transaction: Transaction;
  token: AuthToken;
  actorUid: string;
  clanId: string;
}): Promise<ActorRoleContext> {
  const normalizedTokenRole = normalizeString(token.primaryRole).toUpperCase();
  if (normalizedTokenRole == 'SUPER_ADMIN') {
    return {
      role: 'SUPER_ADMIN',
      branchId: null,
    };
  }

  const tokenMemberId = normalizeString(token.memberId);
  if (tokenMemberId.length > 0) {
    const tokenMemberSnapshot = await transaction.get(membersCollection.doc(tokenMemberId));
    const tokenMemberData = asRecord(tokenMemberSnapshot.data());
    if (
      tokenMemberSnapshot.exists &&
      tokenMemberData != null &&
      normalizeString(tokenMemberData.clanId) == clanId &&
      normalizeString(tokenMemberData.authUid) == actorUid &&
      isActiveMemberStatus(tokenMemberData.status)
    ) {
      return {
        role: normalizeString(tokenMemberData.primaryRole).toUpperCase() || 'MEMBER',
        branchId: normalizeNullableString(tokenMemberData.branchId),
      };
    }
  }

  const actorMembershipSnapshot = await transaction.get(
    membersCollection
      .where('clanId', '==', clanId)
      .where('authUid', '==', actorUid)
      .limit(5),
  );
  if (actorMembershipSnapshot.empty) {
    throw new HttpsError(
      'permission-denied',
      'This session does not have a member role in the target clan.',
    );
  }

  const candidateRoles = actorMembershipSnapshot.docs
    .map((doc) => asRecord(doc.data()))
    .filter((data): data is Record<string, unknown> => data != null)
    .filter((data) => isActiveMemberStatus(data.status))
    .map((data) => ({
      role: normalizeString(data.primaryRole).toUpperCase() || 'MEMBER',
      branchId: normalizeNullableString(data.branchId),
    }))
    .sort((left, right) => rolePriority(right.role) - rolePriority(left.role));

  const bestRole = candidateRoles[0];
  if (bestRole == null) {
    throw new HttpsError(
      'permission-denied',
      'This session does not have an active role in the target clan.',
    );
  }
  return bestRole;
}

function isActiveMemberStatus(value: unknown): boolean {
  const normalized = normalizeString(value).toLowerCase();
  return normalized.length == 0 || normalized == 'active';
}

function rolePriority(role: string): number {
  const normalized = role.trim().toUpperCase();
  switch (normalized) {
    case 'SUPER_ADMIN':
      return 100;
    case 'CLAN_ADMIN':
      return 95;
    case 'CLAN_OWNER':
      return 90;
    case 'CLAN_LEADER':
      return 85;
    case 'ADMIN_SUPPORT':
      return 80;
    case 'BRANCH_ADMIN':
      return 70;
    default:
      return 10;
  }
}

async function syncSiblingOrder({
  clanId,
  parentIds,
  actorId,
}: {
  clanId: string;
  parentIds: Array<string>;
  actorId: string;
}): Promise<void> {
  for (const parentId of parentIds) {
    if (parentId.trim().length == 0) {
      continue;
    }

    const parentSnapshot = await membersCollection.doc(parentId).get();
    const parentData = asRecord(parentSnapshot.data());
    if (!parentSnapshot.exists || parentData == null) {
      continue;
    }
    if (normalizeString(parentData.clanId) != clanId) {
      continue;
    }

    const childIds = normalizeStringList(parentData.childrenIds);
    if (childIds.length == 0) {
      continue;
    }

    const childSnapshots = await Promise.all(
      childIds.map((childId) => membersCollection.doc(childId).get()),
    );
    const entries = childSnapshots
      .filter((snapshot) => snapshot.exists)
      .map((snapshot) => buildSiblingEntry(snapshot))
      .filter((entry) => entry.clanId == clanId)
      .sort(compareSiblingEntries);

    if (entries.length == 0) {
      continue;
    }

    const batch = db.batch();
    let hasWrites = false;
    for (let index = 0; index < entries.length; index += 1) {
      const nextOrder = index + 1;
      if (entries[index].siblingOrder == nextOrder) {
        continue;
      }
      hasWrites = true;
      batch.set(
        membersCollection.doc(entries[index].memberId),
        {
          siblingOrder: nextOrder,
          updatedAt: FieldValue.serverTimestamp(),
          updatedBy: actorId,
        },
        { merge: true },
      );
    }
    if (hasWrites) {
      await batch.commit();
    }
  }
}

async function syncClanMemberCount({
  clanId,
  actorId,
}: {
  clanId: string;
  actorId: string;
}): Promise<void> {
  const count = await countMembersForClan(clanId);
  await clansCollection.doc(clanId).set(
    {
      memberCount: count,
      updatedAt: FieldValue.serverTimestamp(),
      updatedBy: actorId,
    },
    { merge: true },
  );
}

async function syncBranchMemberCount({
  clanId,
  branchId,
  actorId,
}: {
  clanId: string;
  branchId: string;
  actorId: string;
}): Promise<void> {
  const countSnapshot = await membersCollection.where('branchId', '==', branchId).count().get();
  const count = Number(countSnapshot.data().count ?? 0);
  await branchesCollection.doc(branchId).set(
    {
      clanId,
      memberCount: count,
      updatedAt: FieldValue.serverTimestamp(),
      updatedBy: actorId,
    },
    { merge: true },
  );
}

async function countMembersForClan(clanId: string): Promise<number> {
  const snapshot = await membersCollection.where('clanId', '==', clanId).count().get();
  return Number(snapshot.data().count ?? 0);
}

type SiblingEntry = {
  memberId: string;
  clanId: string;
  fullName: string;
  generation: number;
  birthDate: Date | null;
  siblingOrder: number | null;
};

function buildSiblingEntry(
  snapshot: FirebaseFirestore.DocumentSnapshot<FirebaseFirestore.DocumentData>,
): SiblingEntry {
  const data = asRecord(snapshot.data());
  return {
    memberId: snapshot.id,
    clanId: normalizeString(data?.clanId),
    fullName: normalizeString(data?.fullName) || snapshot.id,
    generation: readPositiveInt(data?.generation, 1),
    birthDate: parseIsoDate(normalizeNullableString(data?.birthDate)),
    siblingOrder: readNullablePositiveInt(data?.siblingOrder),
  };
}

function compareSiblingEntries(left: SiblingEntry, right: SiblingEntry): number {
  const byBirthDate = compareNullableDate(left.birthDate, right.birthDate);
  if (byBirthDate != 0) {
    return byBirthDate;
  }
  const byGeneration = left.generation - right.generation;
  if (byGeneration != 0) {
    return byGeneration;
  }
  const byName = left.fullName.toLowerCase().localeCompare(right.fullName.toLowerCase());
  if (byName != 0) {
    return byName;
  }
  return left.memberId.localeCompare(right.memberId);
}

function compareNullableDate(left: Date | null, right: Date | null): number {
  if (left == null && right == null) {
    return 0;
  }
  if (left == null) {
    return 1;
  }
  if (right == null) {
    return -1;
  }
  return left.getTime() - right.getTime();
}

function parseIsoDate(value: string | null): Date | null {
  if (value == null) {
    return null;
  }
  const parsed = new Date(value);
  return Number.isFinite(parsed.getTime()) ? parsed : null;
}

function normalizeSocialLinks(value: unknown): Record<string, string | null> {
  const data = asRecord(value);
  if (data == null) {
    return {};
  }
  const output: Record<string, string | null> = {};
  for (const [key, raw] of Object.entries(data)) {
    if (typeof raw != 'string') {
      output[key] = null;
      continue;
    }
    const trimmed = raw.trim();
    output[key] = trimmed.length > 0 ? trimmed : null;
  }
  return output;
}

function asRecord(value: unknown): Record<string, unknown> | null {
  if (value == null || typeof value != 'object' || Array.isArray(value)) {
    return null;
  }
  return value as Record<string, unknown>;
}

function normalizeString(value: unknown): string {
  return typeof value == 'string' ? value.trim() : '';
}

function normalizeNullableString(value: unknown): string | null {
  const normalized = normalizeString(value);
  return normalized.length > 0 ? normalized : null;
}

const supportedPhoneDialCodes = ['886', '84', '82', '81', '65', '61', '49', '44', '33', '1'];

function normalizeNullablePhone(value: unknown): string | null {
  const normalized = normalizeNullableString(value);
  if (normalized == null) {
    return null;
  }
  return normalizePhoneE164(normalized);
}

function normalizePhoneE164(input: string): string {
  const trimmed = input.trim();
  const digitsAndPlus = trimmed.replace(/[^0-9+]/g, '');
  if (digitsAndPlus.length == 0) {
    throw new HttpsError('invalid-argument', 'phoneE164 has invalid format.');
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
  if (normalized.startsWith('+84') && normalized.length > 3 && normalized[3] == '0') {
    normalized = `+84${normalized.slice(4)}`;
  }

  if (!/^\+[1-9]\d{8,14}$/.test(normalized)) {
    throw new HttpsError('invalid-argument', 'phoneE164 has invalid format.');
  }
  return normalized;
}

function looksLikeInternationalPhoneDigits(
  digits: string,
  fallbackDialCode: string,
): boolean {
  if (digits.length == 0) {
    return false;
  }
  if (digits.startsWith(fallbackDialCode) && digits.length > fallbackDialCode.length + 6) {
    return true;
  }
  const matchedDialCode = findPhoneDialCodePrefix(digits);
  if (matchedDialCode == null) {
    return false;
  }
  return digits.length > matchedDialCode.length + 6;
}

function findPhoneDialCodePrefix(digits: string): string | null {
  for (const dialCode of supportedPhoneDialCodes) {
    if (digits.startsWith(dialCode) && digits.length > dialCode.length) {
      return dialCode;
    }
  }
  return null;
}

function splitPhoneCountryAndNational(phoneE164: string): {
  dialCode: string;
  nationalDigits: string;
} | null {
  const digits = phoneE164.startsWith('+') ? phoneE164.slice(1) : phoneE164;
  const dialCode = findPhoneDialCodePrefix(digits);
  if (dialCode == null) {
    return null;
  }
  const nationalDigits = digits.slice(dialCode.length);
  if (nationalDigits.length == 0) {
    return null;
  }
  return { dialCode, nationalDigits };
}

function phoneComparisonKeys(phone: string): Set<string> {
  const keys = new Set<string>();
  const normalized = normalizePhoneE164(phone);
  keys.add(normalized);
  keys.add(normalized.slice(1));
  const split = splitPhoneCountryAndNational(normalized);
  if (split != null) {
    keys.add(split.nationalDigits);
    if (!split.nationalDigits.startsWith('0')) {
      keys.add(`0${split.nationalDigits}`);
    }
    keys.add(`${split.dialCode}${split.nationalDigits}`);
  }
  const rawDigits = phone.replace(/[^0-9]/g, '');
  if (rawDigits.length > 0) {
    keys.add(rawDigits);
  }
  return keys;
}

function phonesEquivalent(left: string | null, right: string | null): boolean {
  if (left == null || right == null) {
    return false;
  }

  const leftKeys = new Set<string>();
  const rightKeys = new Set<string>();
  try {
    for (const key of phoneComparisonKeys(left)) {
      leftKeys.add(key);
    }
  } catch {
    const digits = left.replace(/[^0-9]/g, '');
    if (digits.length > 0) {
      leftKeys.add(digits);
    }
  }
  try {
    for (const key of phoneComparisonKeys(right)) {
      rightKeys.add(key);
    }
  } catch {
    const digits = right.replace(/[^0-9]/g, '');
    if (digits.length > 0) {
      rightKeys.add(digits);
    }
  }

  if (leftKeys.size == 0 || rightKeys.size == 0) {
    return false;
  }
  for (const key of leftKeys) {
    if (rightKeys.has(key)) {
      return true;
    }
  }
  return false;
}

function normalizeStringList(value: unknown): Array<string> {
  if (!Array.isArray(value)) {
    return [];
  }
  return value
    .filter((entry): entry is string => typeof entry == 'string')
    .map((entry) => entry.trim())
    .filter((entry) => entry.length > 0);
}

function readPositiveInt(value: unknown, fallback: number): number {
  if (typeof value == 'number' && Number.isFinite(value)) {
    const normalized = Math.trunc(value);
    return normalized > 0 ? normalized : fallback;
  }
  if (typeof value == 'string') {
    const parsed = Number.parseInt(value.trim(), 10);
    if (Number.isFinite(parsed) && parsed > 0) {
      return parsed;
    }
  }
  return fallback;
}

function readNullablePositiveInt(value: unknown): number | null {
  const normalized = readPositiveInt(value, 0);
  return normalized > 0 ? normalized : null;
}
