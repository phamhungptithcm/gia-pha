import {
  FieldValue,
  type DocumentReference,
  type Transaction,
} from 'firebase-admin/firestore';

import { db } from '../shared/firestore';
import { logInfo, logWarn } from '../shared/logger';

export type RelationshipWriteAction = 'create' | 'delete';
export type RelationshipType = 'parent_child' | 'spouse';

type MemberRelationshipArrays = {
  parentIds: string[];
  childrenIds: string[];
  spouseIds: string[];
};

type RelationshipRecord = {
  clanId?: string | null;
  personA?: string | null;
  personB?: string | null;
  type?: string | null;
  status?: string | null;
};

type MemberRecord = {
  clanId?: string | null;
  parentIds?: unknown;
  childrenIds?: unknown;
  spouseIds?: unknown;
};

type ReconciliationInput = {
  relationshipId: string;
  action: RelationshipWriteAction;
  relationship: RelationshipRecord;
  source: string;
};

type ReconciliationResult = {
  reconciled: boolean;
  reason?: string;
  relationshipType?: RelationshipType;
  clanId?: string;
  personAId?: string;
  personBId?: string;
};

export async function reconcileRelationshipMembers(
  input: ReconciliationInput,
): Promise<ReconciliationResult> {
  const relationshipType = normalizeRelationshipType(input.relationship.type);
  const personAId = normalizeId(input.relationship.personA);
  const personBId = normalizeId(input.relationship.personB);
  const clanId = normalizeId(input.relationship.clanId);

  if (relationshipType == null || personAId == null || personBId == null) {
    logWarn('relationship reconciliation skipped due to malformed payload', {
      source: input.source,
      relationshipId: input.relationshipId,
      relationshipType: input.relationship.type ?? null,
      personA: input.relationship.personA ?? null,
      personB: input.relationship.personB ?? null,
    });
    return { reconciled: false, reason: 'malformed_payload' };
  }

  if (personAId === personBId) {
    logWarn('relationship reconciliation skipped because personA/personB are identical', {
      source: input.source,
      relationshipId: input.relationshipId,
      personAId,
    });
    return { reconciled: false, reason: 'self_relationship' };
  }

  if (
    input.action === 'create' &&
    normalizeStatus(input.relationship.status) !== 'active'
  ) {
    logInfo('relationship reconciliation skipped for non-active create', {
      source: input.source,
      relationshipId: input.relationshipId,
      status: input.relationship.status ?? null,
    });
    return {
      reconciled: false,
      reason: 'inactive_relationship',
      relationshipType,
      clanId: clanId ?? undefined,
      personAId,
      personBId,
    };
  }

  const personARef = db.collection('members').doc(personAId);
  const personBRef = db.collection('members').doc(personBId);

  await db.runTransaction(async (transaction) => {
    const [personASnapshot, personBSnapshot] = await Promise.all([
      transaction.get(personARef),
      transaction.get(personBRef),
    ]);

    if (!personASnapshot.exists && !personBSnapshot.exists) {
      logWarn('relationship reconciliation skipped because both members are missing', {
        source: input.source,
        relationshipId: input.relationshipId,
        personAId,
        personBId,
      });
      return;
    }

    const personA = (personASnapshot.data() ?? {}) as MemberRecord;
    const personB = (personBSnapshot.data() ?? {}) as MemberRecord;

    if (
      clanId != null &&
      ((personASnapshot.exists &&
        normalizeId(personA.clanId) != null &&
        normalizeId(personA.clanId) !== clanId) ||
        (personBSnapshot.exists &&
          normalizeId(personB.clanId) != null &&
          normalizeId(personB.clanId) !== clanId))
    ) {
      logWarn('relationship reconciliation skipped due to clan mismatch', {
        source: input.source,
        relationshipId: input.relationshipId,
        relationshipClanId: clanId,
        personAClanId: normalizeId(personA.clanId),
        personBClanId: normalizeId(personB.clanId),
      });
      return;
    }

    const {
      personAArrays: nextPersonAArrays,
      personBArrays: nextPersonBArrays,
    } = reconcileMemberArrays({
      action: input.action,
      relationshipType,
      personAId,
      personBId,
      personAArrays: normalizeMemberRelationshipArrays(personA),
      personBArrays: normalizeMemberRelationshipArrays(personB),
    });

    if (personASnapshot.exists) {
      mergeMemberRelationshipArrays(
        transaction,
        personARef,
        nextPersonAArrays,
        input.source,
      );
    } else {
      logWarn('relationship reconciliation missing personA member document', {
        source: input.source,
        relationshipId: input.relationshipId,
        personAId,
      });
    }

    if (personBSnapshot.exists) {
      mergeMemberRelationshipArrays(
        transaction,
        personBRef,
        nextPersonBArrays,
        input.source,
      );
    } else {
      logWarn('relationship reconciliation missing personB member document', {
        source: input.source,
        relationshipId: input.relationshipId,
        personBId,
      });
    }
  });

  logInfo('relationship reconciliation completed', {
    source: input.source,
    relationshipId: input.relationshipId,
    action: input.action,
    relationshipType,
    personAId,
    personBId,
    clanId: clanId ?? null,
  });

  return {
    reconciled: true,
    relationshipType,
    clanId: clanId ?? undefined,
    personAId,
    personBId,
  };
}

function mergeMemberRelationshipArrays(
  transaction: Transaction,
  memberRef: DocumentReference,
  arrays: MemberRelationshipArrays,
  source: string,
) {
  transaction.set(
    memberRef,
    {
      parentIds: arrays.parentIds,
      childrenIds: arrays.childrenIds,
      spouseIds: arrays.spouseIds,
      updatedAt: FieldValue.serverTimestamp(),
      updatedBy: source,
    },
    { merge: true },
  );
}

type ReconcileArraysInput = {
  action: RelationshipWriteAction;
  relationshipType: RelationshipType;
  personAId: string;
  personBId: string;
  personAArrays: MemberRelationshipArrays;
  personBArrays: MemberRelationshipArrays;
};

type ReconcileArraysOutput = {
  personAArrays: MemberRelationshipArrays;
  personBArrays: MemberRelationshipArrays;
};

export function reconcileMemberArrays(
  input: ReconcileArraysInput,
): ReconcileArraysOutput {
  const personAArrays = cloneArrays(input.personAArrays);
  const personBArrays = cloneArrays(input.personBArrays);

  if (input.relationshipType === 'parent_child') {
    if (input.action === 'create') {
      personAArrays.childrenIds = addUniqueSorted(
        personAArrays.childrenIds,
        input.personBId,
      );
      personBArrays.parentIds = addUniqueSorted(
        personBArrays.parentIds,
        input.personAId,
      );
    } else {
      personAArrays.childrenIds = removeValue(
        personAArrays.childrenIds,
        input.personBId,
      );
      personBArrays.parentIds = removeValue(
        personBArrays.parentIds,
        input.personAId,
      );
    }
  } else {
    if (input.action === 'create') {
      personAArrays.spouseIds = addUniqueSorted(
        personAArrays.spouseIds,
        input.personBId,
      );
      personBArrays.spouseIds = addUniqueSorted(
        personBArrays.spouseIds,
        input.personAId,
      );
    } else {
      personAArrays.spouseIds = removeValue(
        personAArrays.spouseIds,
        input.personBId,
      );
      personBArrays.spouseIds = removeValue(
        personBArrays.spouseIds,
        input.personAId,
      );
    }
  }

  return { personAArrays, personBArrays };
}

export function normalizeMemberRelationshipArrays(
  record: Partial<MemberRecord>,
): MemberRelationshipArrays {
  return {
    parentIds: normalizeIdList(record.parentIds),
    childrenIds: normalizeIdList(record.childrenIds),
    spouseIds: normalizeIdList(record.spouseIds),
  };
}

function cloneArrays(input: MemberRelationshipArrays): MemberRelationshipArrays {
  return {
    parentIds: [...input.parentIds],
    childrenIds: [...input.childrenIds],
    spouseIds: [...input.spouseIds],
  };
}

function normalizeRelationshipType(value: unknown): RelationshipType | null {
  if (value !== 'parent_child' && value !== 'spouse') {
    return null;
  }
  return value;
}

function normalizeStatus(value: unknown): string {
  return typeof value === 'string' ? value.trim().toLowerCase() : 'active';
}

function normalizeId(value: unknown): string | null {
  if (typeof value !== 'string') {
    return null;
  }

  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}

function normalizeIdList(value: unknown): string[] {
  if (!Array.isArray(value)) {
    return [];
  }

  const unique = new Set<string>();
  for (const entry of value) {
    const normalized = normalizeId(entry);
    if (normalized != null) {
      unique.add(normalized);
    }
  }

  return [...unique].sort();
}

function addUniqueSorted(list: string[], value: string): string[] {
  const normalized = normalizeId(value);
  if (normalized == null) {
    return list;
  }

  return [...new Set<string>([...list, normalized])].sort();
}

function removeValue(list: string[], value: string): string[] {
  const normalized = normalizeId(value);
  if (normalized == null) {
    return list;
  }

  return list.filter((entry) => entry !== normalized).sort();
}
