import {
  FieldValue,
  type Query,
  type QueryDocumentSnapshot,
  type Transaction,
} from 'firebase-admin/firestore';
import {
  HttpsError,
  onCall,
  type CallableRequest,
} from 'firebase-functions/v2/https';

import { APP_REGION, CALLABLE_ENFORCE_APP_CHECK } from '../config/runtime';
import { requireAuth } from '../shared/errors';
import { db } from '../shared/firestore';
import { logInfo } from '../shared/logger';

type MemberRecord = {
  clanId?: string | null;
  branchId?: string | null;
  fullName?: string | null;
  nickName?: string | null;
};

type RelationshipRecord = {
  clanId?: string | null;
  personA?: string | null;
  personB?: string | null;
  type?: string | null;
  status?: string | null;
};

type AuthToken = NonNullable<CallableRequest<unknown>['auth']>['token'];

const membersCollection = db.collection('members');
const relationshipsCollection = db.collection('relationships');
const auditLogsCollection = db.collection('auditLogs');
const APP_CHECK_CALLABLE_OPTIONS = {
  region: APP_REGION,
  enforceAppCheck: CALLABLE_ENFORCE_APP_CHECK,
} as const;

export const createParentChildRelationship = onCall(
  APP_CHECK_CALLABLE_OPTIONS,
  async (request) => {
    const auth = requireAuth(request);
    const parentId = requireNonEmptyString(request.data, 'parentId');
    const childId = requireNonEmptyString(request.data, 'childId');
    if (parentId === childId) {
      throw new HttpsError(
        'invalid-argument',
        'A relationship cannot target the same member.',
      );
    }

    const [parentSnapshot, childSnapshot] = await Promise.all([
      membersCollection.doc(parentId).get(),
      membersCollection.doc(childId).get(),
    ]);
    const parent = requireMember(parentSnapshot, parentId);
    const child = requireMember(childSnapshot, childId);
    const clanId = requireSharedClan(parent, child);

    ensureSensitiveRelationshipPermission(auth.token, clanId, parent, child);

    const existingRelationship = await relationshipsCollection
      .doc(parentChildRelationshipId(parentId, childId))
      .get();
    if (existingRelationship.exists && isActiveRelationship(existingRelationship.data() as RelationshipRecord)) {
      throw new HttpsError(
        'already-exists',
        'That parent-child relationship already exists.',
      );
    }

    const clanRelationships = await relationshipsCollection
      .where('clanId', '==', clanId)
      .where('type', '==', 'parent_child')
      .where('status', '==', 'active')
      .get();
    ensureNoParentChildCycle(parentId, childId, clanRelationships.docs);

    const actor = auth.token.memberId ?? auth.uid;
    const now = new Date();
    const relationshipId = parentChildRelationshipId(parentId, childId);

    await db.runTransaction(async (transaction) => {
      const relationshipRef = relationshipsCollection.doc(relationshipId);
      transaction.set(relationshipRef, {
        id: relationshipId,
        clanId,
        personA: parentId,
        personB: childId,
        type: 'parent_child',
        direction: 'A_TO_B',
        status: 'active',
        source: 'manual',
        createdAt: FieldValue.serverTimestamp(),
        createdBy: actor,
        updatedAt: FieldValue.serverTimestamp(),
        updatedBy: actor,
      });

      const [parentChildrenIds, childParentIds] = await Promise.all([
        loadParentChildrenIds(transaction, clanId, parentId, childId),
        loadChildParentIds(transaction, clanId, childId, parentId),
      ]);

      transaction.set(parentSnapshot.ref, {
        childrenIds: parentChildrenIds,
        updatedAt: FieldValue.serverTimestamp(),
        updatedBy: actor,
      }, { merge: true });
      transaction.set(childSnapshot.ref, {
        parentIds: childParentIds,
        updatedAt: FieldValue.serverTimestamp(),
        updatedBy: actor,
      }, { merge: true });

      writeAuditLog(transaction, {
        uid: auth.uid,
        memberId: stringOrNull(auth.token.memberId),
        clanId,
        action: 'relationship_created',
        entityType: 'relationship',
        entityId: relationshipId,
        after: {
          type: 'parent_child',
          personA: parentId,
          personB: childId,
        },
      });
    });

    logInfo('createParentChildRelationship succeeded', {
      uid: auth.uid,
      relationshipId,
      clanId,
      parentId,
      childId,
    });

    return {
      id: relationshipId,
      clanId,
      personA: parentId,
      personB: childId,
      type: 'parent_child',
      direction: 'A_TO_B',
      status: 'active',
      source: 'manual',
      createdBy: actor,
      createdAt: now.toISOString(),
      updatedAt: now.toISOString(),
    };
  },
);

export const createSpouseRelationship = onCall(
  APP_CHECK_CALLABLE_OPTIONS,
  async (request) => {
    const auth = requireAuth(request);
    const memberId = requireNonEmptyString(request.data, 'memberId');
    const spouseId = requireNonEmptyString(request.data, 'spouseId');
    if (memberId === spouseId) {
      throw new HttpsError(
        'invalid-argument',
        'A relationship cannot target the same member.',
      );
    }

    const [firstSnapshot, secondSnapshot] = await Promise.all([
      membersCollection.doc(memberId).get(),
      membersCollection.doc(spouseId).get(),
    ]);
    const first = requireMember(firstSnapshot, memberId);
    const second = requireMember(secondSnapshot, spouseId);
    const clanId = requireSharedClan(first, second);

    ensureSensitiveRelationshipPermission(auth.token, clanId, first, second);

    const normalizedPair = [memberId, spouseId].sort();
    const [firstId, secondId] = normalizedPair;
    const relationshipId = spouseRelationshipId(firstId, secondId);
    const existingRelationship = await relationshipsCollection.doc(relationshipId).get();
    if (existingRelationship.exists && isActiveRelationship(existingRelationship.data() as RelationshipRecord)) {
      throw new HttpsError(
        'already-exists',
        'That spouse relationship already exists.',
      );
    }

    const actor = auth.token.memberId ?? auth.uid;
    const now = new Date();

    await db.runTransaction(async (transaction) => {
      const relationshipRef = relationshipsCollection.doc(relationshipId);
      transaction.set(relationshipRef, {
        id: relationshipId,
        clanId,
        personA: firstId,
        personB: secondId,
        type: 'spouse',
        direction: 'UNDIRECTED',
        status: 'active',
        source: 'manual',
        createdAt: FieldValue.serverTimestamp(),
        createdBy: actor,
        updatedAt: FieldValue.serverTimestamp(),
        updatedBy: actor,
      });

      const [firstSpouseIds, secondSpouseIds] = await Promise.all([
        loadSpouseIds(transaction, clanId, memberId, spouseId),
        loadSpouseIds(transaction, clanId, spouseId, memberId),
      ]);

      transaction.set(firstSnapshot.ref, {
        spouseIds: firstSpouseIds,
        updatedAt: FieldValue.serverTimestamp(),
        updatedBy: actor,
      }, { merge: true });
      transaction.set(secondSnapshot.ref, {
        spouseIds: secondSpouseIds,
        updatedAt: FieldValue.serverTimestamp(),
        updatedBy: actor,
      }, { merge: true });

      writeAuditLog(transaction, {
        uid: auth.uid,
        memberId: stringOrNull(auth.token.memberId),
        clanId,
        action: 'relationship_created',
        entityType: 'relationship',
        entityId: relationshipId,
        after: {
          type: 'spouse',
          personA: firstId,
          personB: secondId,
        },
      });
    });

    logInfo('createSpouseRelationship succeeded', {
      uid: auth.uid,
      relationshipId,
      clanId,
      memberId,
      spouseId,
    });

    return {
      id: relationshipId,
      clanId,
      personA: firstId,
      personB: secondId,
      type: 'spouse',
      direction: 'UNDIRECTED',
      status: 'active',
      source: 'manual',
      createdBy: actor,
      createdAt: now.toISOString(),
      updatedAt: now.toISOString(),
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

function requireMember(
  snapshot: FirebaseFirestore.DocumentSnapshot<FirebaseFirestore.DocumentData>,
  memberId: string,
): MemberRecord {
  const member = snapshot.data() as MemberRecord | undefined;
  if (!snapshot.exists || member == null) {
    throw new HttpsError('not-found', `Member ${memberId} was not found.`);
  }

  return member;
}

function requireSharedClan(first: MemberRecord, second: MemberRecord): string {
  if (
    first.clanId == null ||
    second.clanId == null ||
    first.clanId.length === 0 ||
    first.clanId !== second.clanId
  ) {
    throw new HttpsError(
      'not-found',
      'Members must belong to the same clan for relationship edits.',
    );
  }

  return first.clanId;
}

function ensureSensitiveRelationshipPermission(
  token: AuthToken,
  clanId: string,
  first: MemberRecord,
  second: MemberRecord,
): void {
  const role = stringOrNull(token.primaryRole)?.toUpperCase() ?? '';
  const accessMode = stringOrNull(token.memberAccessMode);
  const branchId = stringOrNull(token.branchId);
  const clanIds = Array.isArray(token.clanIds)
    ? token.clanIds.filter(
        (value: unknown): value is string => typeof value === 'string',
      )
    : [];

  if (accessMode !== 'claimed' || !clanIds.includes(clanId)) {
    throw new HttpsError(
      'permission-denied',
      'This session cannot perform sensitive relationship edits.',
    );
  }

  if (role === 'SUPER_ADMIN' || role === 'CLAN_ADMIN') {
    return;
  }

  if (
    role === 'BRANCH_ADMIN' &&
    branchId != null &&
    first.branchId === branchId &&
    second.branchId === branchId
  ) {
    return;
  }

  throw new HttpsError(
    'permission-denied',
    'This session cannot perform sensitive relationship edits.',
  );
}

function ensureNoParentChildCycle(
  parentId: string,
  childId: string,
  relationships: QueryDocumentSnapshot[],
): void {
  const childMap = new Map<string, Set<string>>();

  for (const snapshot of relationships) {
    const relationship = snapshot.data() as RelationshipRecord;
    const source = stringOrNull(relationship.personA);
    const target = stringOrNull(relationship.personB);
    if (source == null || target == null) {
      continue;
    }

    const next = childMap.get(source) ?? new Set<string>();
    next.add(target);
    childMap.set(source, next);
  }

  const frontier = [childId];
  const visited = new Set<string>(frontier);

  while (frontier.length > 0) {
    const current = frontier.pop();
    if (!current) {
      continue;
    }

    if (current === parentId) {
      throw new HttpsError(
        'failed-precondition',
        'That parent-child link would create a cycle.',
      );
    }

    for (const nextChild of childMap.get(current) ?? []) {
      if (!visited.has(nextChild)) {
        visited.add(nextChild);
        frontier.push(nextChild);
      }
    }
  }
}

async function loadParentChildrenIds(
  transaction: Transaction,
  clanId: string,
  parentId: string,
  extraChildId: string,
): Promise<string[]> {
  const snapshot = await transaction.get(
    activeRelationshipQuery()
      .where('clanId', '==', clanId)
      .where('type', '==', 'parent_child')
      .where('personA', '==', parentId),
  );

  const ids = new Set<string>([extraChildId]);
  for (const doc of snapshot.docs) {
    const relationship = doc.data() as RelationshipRecord;
    const childId = stringOrNull(relationship.personB);
    if (childId != null) {
      ids.add(childId);
    }
  }

  return [...ids].sort();
}

async function loadChildParentIds(
  transaction: Transaction,
  clanId: string,
  childId: string,
  extraParentId: string,
): Promise<string[]> {
  const snapshot = await transaction.get(
    activeRelationshipQuery()
      .where('clanId', '==', clanId)
      .where('type', '==', 'parent_child')
      .where('personB', '==', childId),
  );

  const ids = new Set<string>([extraParentId]);
  for (const doc of snapshot.docs) {
    const relationship = doc.data() as RelationshipRecord;
    const parentId = stringOrNull(relationship.personA);
    if (parentId != null) {
      ids.add(parentId);
    }
  }

  return [...ids].sort();
}

async function loadSpouseIds(
  transaction: Transaction,
  clanId: string,
  memberId: string,
  extraSpouseId: string,
): Promise<string[]> {
  const [asPersonA, asPersonB] = await Promise.all([
    transaction.get(
      activeRelationshipQuery()
        .where('clanId', '==', clanId)
        .where('type', '==', 'spouse')
        .where('personA', '==', memberId),
    ),
    transaction.get(
      activeRelationshipQuery()
        .where('clanId', '==', clanId)
        .where('type', '==', 'spouse')
        .where('personB', '==', memberId),
    ),
  ]);

  const ids = new Set<string>([extraSpouseId]);
  for (const doc of [...asPersonA.docs, ...asPersonB.docs]) {
    const relationship = doc.data() as RelationshipRecord;
    const spouseId = relationship.personA === memberId
      ? stringOrNull(relationship.personB)
      : stringOrNull(relationship.personA);
    if (spouseId != null) {
      ids.add(spouseId);
    }
  }

  return [...ids].sort();
}

function activeRelationshipQuery(): Query {
  return relationshipsCollection.where('status', '==', 'active');
}

function isActiveRelationship(relationship: RelationshipRecord | undefined): boolean {
  return relationship?.status === 'active';
}

function writeAuditLog(
  transaction: Transaction,
  params: {
    uid: string;
    memberId: string | null;
    clanId: string;
    action: string;
    entityType: string;
    entityId: string;
    after: Record<string, unknown>;
  },
): void {
  transaction.set(auditLogsCollection.doc(), {
    clanId: params.clanId,
    actorUid: params.uid,
    actorMemberId: params.memberId,
    entityType: params.entityType,
    entityId: params.entityId,
    action: params.action,
    before: null,
    after: params.after,
    createdAt: FieldValue.serverTimestamp(),
  });
}

function parentChildRelationshipId(parentId: string, childId: string): string {
  return `rel_parent_child_${parentId}_${childId}`;
}

function spouseRelationshipId(firstId: string, secondId: string): string {
  return `rel_spouse_${firstId}_${secondId}`;
}

function stringOrNull(value: unknown): string | null {
  return typeof value === 'string' && value.trim().length > 0 ? value : null;
}
