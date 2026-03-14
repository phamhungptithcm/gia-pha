import { getAuth } from 'firebase-admin/auth';
import {
  FieldValue,
  Timestamp,
  type DocumentReference,
  type DocumentSnapshot,
} from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';

import { APP_REGION } from '../config/runtime';
import { db } from '../shared/firestore';
import { requireAuth } from '../shared/errors';
import { logInfo, logWarn } from '../shared/logger';

type LoginMethod = 'phone' | 'child';
type MemberAccessMode = 'unlinked' | 'claimed' | 'child';

type MemberRecord = {
  clanId?: string;
  branchId?: string | null;
  fullName?: string | null;
  nickName?: string | null;
  phoneE164?: string | null;
  primaryRole?: string | null;
  authUid?: string | null;
  status?: string | null;
};

type InviteRecord = {
  clanId?: string | null;
  branchId?: string | null;
  memberId?: string | null;
  inviteType?: string | null;
  phoneE164?: string | null;
  childIdentifier?: string | null;
  status?: string | null;
  expiresAt?: Timestamp | null;
};

type ResolvedChildLoginContext = {
  childIdentifier: string;
  parentPhoneE164: string;
  maskedDestination: string;
  memberId: string;
  displayName: string;
  clanId: string;
  branchId: string;
  primaryRole: string;
};

type MemberSessionContext = {
  memberId: string | null;
  displayName: string | null;
  clanId: string | null;
  branchId: string | null;
  primaryRole: string | null;
  accessMode: MemberAccessMode;
  linkedAuthUid: boolean;
};

const membersCollection = db.collection('members');
const invitesCollection = db.collection('invites');
const auditLogsCollection = db.collection('auditLogs');

export const resolveChildLoginContext = onCall(
  { region: APP_REGION },
  async (request) => {
    const childIdentifier = requireNonEmptyString(
      request.data,
      'childIdentifier',
    ).trim().toUpperCase();

    const resolved = await findChildLoginContext(childIdentifier);

    logInfo('resolveChildLoginContext succeeded', {
      childIdentifier: resolved.childIdentifier,
      memberId: resolved.memberId,
      clanId: resolved.clanId,
    });

    return resolved;
  },
);

export const createInvite = onCall({ region: APP_REGION }, async (request) => {
  const auth = requireAuth(request);

  logInfo('createInvite requested', {
    uid: auth.uid,
    data: request.data,
  });

  throw new HttpsError(
    'unimplemented',
    'createInvite is scaffolded and awaits permission checks plus invite persistence logic.',
  );
});

export const claimMemberRecord = onCall({ region: APP_REGION }, async (request) => {
  const auth = requireAuth(request);
  const loginMethod = requireLoginMethod(request.data);

  logInfo('claimMemberRecord requested', {
    uid: auth.uid,
    loginMethod,
  });

  const authPhone = typeof auth.token.phone_number === 'string'
    ? auth.token.phone_number
    : '';

  if (loginMethod === 'child') {
    const childIdentifier = optionalString(request.data, 'childIdentifier')
      ?.trim()
      .toUpperCase();
    const providedMemberId = optionalString(request.data, 'memberId')?.trim();
    const resolved = childIdentifier != null
      ? await findChildLoginContext(childIdentifier)
      : await findChildLoginContextByMemberId(providedMemberId);

    if (authPhone.length === 0 || authPhone !== resolved.parentPhoneE164) {
      throw new HttpsError(
        'failed-precondition',
        'The verified phone number does not match the linked parent phone.',
      );
    }

    const context = buildMemberSessionContext(resolved.memberId, resolved, 'child', false);
    await applySessionClaims(auth.uid, context);
    await writeAuditLog({
      uid: auth.uid,
      memberId: resolved.memberId,
      clanId: resolved.clanId,
      action: 'child_access_granted',
      entityType: 'member',
      entityId: resolved.memberId,
      after: {
        accessMode: context.accessMode,
        childIdentifier: resolved.childIdentifier,
      },
    });

    return context;
  }

  const claimedMember = await resolvePhoneClaimMember({
    uid: auth.uid,
    authPhone,
    explicitMemberId: optionalString(request.data, 'memberId')?.trim(),
  });

  if (claimedMember == null) {
    const context: MemberSessionContext = {
      memberId: null,
      displayName: null,
      clanId: null,
      branchId: null,
      primaryRole: null,
      accessMode: 'unlinked',
      linkedAuthUid: false,
    };
    await applySessionClaims(auth.uid, context);

    logWarn('claimMemberRecord found no member match', {
      uid: auth.uid,
      phoneE164: authPhone,
    });

    return context;
  }

  const memberRef = membersCollection.doc(claimedMember.memberId);
  const consumeInviteRefs = await loadMatchingPhoneInviteRefs(
    claimedMember.phoneE164,
    claimedMember.memberId,
  );
  const didLinkAuthUid = await claimMemberTransaction({
    uid: auth.uid,
    memberRef,
    inviteRefs: consumeInviteRefs,
  });

  const context = buildMemberSessionContext(
    claimedMember.memberId,
    claimedMember.memberData,
    'claimed',
    true,
  );
  await applySessionClaims(auth.uid, context);
  await writeAuditLog({
    uid: auth.uid,
    memberId: claimedMember.memberId,
    clanId: context.clanId,
    action: didLinkAuthUid ? 'member_claimed' : 'member_session_refreshed',
    entityType: 'member',
    entityId: claimedMember.memberId,
    after: {
      accessMode: context.accessMode,
      linkedAuthUid: context.linkedAuthUid,
      phoneE164: claimedMember.phoneE164,
    },
  });

  return context;
});

export const registerDeviceToken = onCall({ region: APP_REGION }, async (request) => {
  const auth = requireAuth(request);

  logInfo('registerDeviceToken requested', {
    uid: auth.uid,
    data: request.data,
  });

  throw new HttpsError(
    'unimplemented',
    'registerDeviceToken is scaffolded and awaits token upsert logic.',
  );
});

function requireNonEmptyString(data: unknown, key: string): string {
  const value = optionalString(data, key)?.trim();
  if (value == null || value.length === 0) {
    throw new HttpsError('invalid-argument', `${key} is required.`);
  }

  return value;
}

function optionalString(data: unknown, key: string): string | null {
  if (data == null || typeof data !== 'object') {
    return null;
  }

  const value = (data as Record<string, unknown>)[key];
  return typeof value === 'string' ? value : null;
}

function requireLoginMethod(data: unknown): LoginMethod {
  const loginMethod = optionalString(data, 'loginMethod');
  if (loginMethod === 'phone' || loginMethod === 'child') {
    return loginMethod;
  }

  throw new HttpsError(
    'invalid-argument',
    'loginMethod must be either "phone" or "child".',
  );
}

function maskPhone(phoneE164: string): string {
  const visiblePrefix = phoneE164.startsWith('+84') ? '+84' : phoneE164.slice(0, 2);
  const visibleSuffix = phoneE164.slice(-2);
  const hiddenLength = Math.max(phoneE164.length - visiblePrefix.length - visibleSuffix.length, 4);
  return `${visiblePrefix}${'*'.repeat(hiddenLength)}${visibleSuffix}`;
}

function inviteIsActive(invite: InviteRecord): boolean {
  const status = invite.status ?? 'pending';
  if (!['pending', 'active'].includes(status)) {
    return false;
  }

  if (invite.expiresAt == null) {
    return true;
  }

  return invite.expiresAt.toMillis() >= Date.now();
}

async function findChildLoginContext(
  childIdentifier: string,
): Promise<ResolvedChildLoginContext> {
  const inviteSnapshot = await invitesCollection
    .where('childIdentifier', '==', childIdentifier)
    .limit(5)
    .get();

  const inviteDoc = inviteSnapshot.docs.find((doc) => inviteIsActive(doc.data() as InviteRecord));
  if (inviteDoc != null) {
    const invite = inviteDoc.data() as InviteRecord;
    const parentPhoneE164 = invite.phoneE164?.trim();
    const memberId = invite.memberId?.trim();
    if (parentPhoneE164 == null || parentPhoneE164.length === 0 || memberId == null || memberId.length === 0) {
      throw new HttpsError(
        'failed-precondition',
        'This child identifier is not fully linked to a parent phone and member profile yet.',
      );
    }

    const memberSnapshot = await membersCollection.doc(memberId).get();
    if (!memberSnapshot.exists) {
      throw new HttpsError('not-found', 'The child member profile could not be found.');
    }

    return buildResolvedChildContext(
      childIdentifier,
      parentPhoneE164,
      memberSnapshot,
    );
  }

  const memberSnapshot = await membersCollection.doc(childIdentifier).get();
  if (memberSnapshot.exists) {
    const member = memberSnapshot.data() as MemberRecord;
    const phoneE164 = member.phoneE164?.trim();
    if (phoneE164 != null && phoneE164.length > 0) {
      return buildResolvedChildContext(childIdentifier, phoneE164, memberSnapshot);
    }
  }

  throw new HttpsError('not-found', 'No child login context matches that identifier.');
}

async function findChildLoginContextByMemberId(
  memberId: string | null | undefined,
): Promise<ResolvedChildLoginContext> {
  if (memberId == null || memberId.length === 0) {
    throw new HttpsError(
      'invalid-argument',
      'memberId is required when childIdentifier is not provided.',
    );
  }

  const memberSnapshot = await membersCollection.doc(memberId).get();
  if (!memberSnapshot.exists) {
    throw new HttpsError('not-found', 'The child member profile could not be found.');
  }

  const inviteSnapshot = await invitesCollection
    .where('memberId', '==', memberId)
    .limit(5)
    .get();
  const inviteDoc = inviteSnapshot.docs.find((doc) => {
    const invite = doc.data() as InviteRecord;
    return inviteIsActive(invite) && typeof invite.childIdentifier === 'string' && invite.childIdentifier.trim().length > 0;
  });
  if (inviteDoc == null) {
    throw new HttpsError(
      'failed-precondition',
      'This child member record is not linked to a parent OTP flow yet.',
    );
  }

  const invite = inviteDoc.data() as InviteRecord;
  const phoneE164 = invite.phoneE164?.trim();
  const childIdentifier = invite.childIdentifier?.trim().toUpperCase();
  if (phoneE164 == null || phoneE164.length === 0 || childIdentifier == null || childIdentifier.length === 0) {
    throw new HttpsError(
      'failed-precondition',
      'This child member record is not linked to a parent OTP flow yet.',
    );
  }

  return buildResolvedChildContext(childIdentifier, phoneE164, memberSnapshot);
}

function buildResolvedChildContext(
  childIdentifier: string,
  parentPhoneE164: string,
  memberSnapshot: DocumentSnapshot,
): ResolvedChildLoginContext {
  const memberId = memberSnapshot.id;
  const member = memberSnapshot.data() as MemberRecord | undefined;
  if (member == null || member.clanId == null || member.branchId == null) {
    throw new HttpsError(
      'failed-precondition',
      'The child member record is missing clan or branch context.',
    );
  }

  return {
    childIdentifier,
    parentPhoneE164,
    maskedDestination: maskPhone(parentPhoneE164),
    memberId,
    displayName: member.fullName ?? member.nickName ?? 'BeFam Member',
    clanId: member.clanId,
    branchId: member.branchId,
    primaryRole: member.primaryRole ?? 'MEMBER',
  };
}

async function resolvePhoneClaimMember({
  uid,
  authPhone,
  explicitMemberId,
}: {
  uid: string;
  authPhone: string;
  explicitMemberId?: string | null;
}): Promise<{
  memberId: string;
  memberData: MemberRecord;
  phoneE164: string;
} | null> {
  if (authPhone.length === 0) {
    throw new HttpsError(
      'failed-precondition',
      'A verified phone number is required before a member record can be claimed.',
    );
  }

  if (explicitMemberId != null && explicitMemberId.length > 0) {
    const explicitSnapshot = await membersCollection.doc(explicitMemberId).get();
    if (!explicitSnapshot.exists) {
      throw new HttpsError('not-found', 'The requested member profile does not exist.');
    }

    const member = explicitSnapshot.data() as MemberRecord;
    if (member.phoneE164 != null && member.phoneE164.length > 0 && member.phoneE164 !== authPhone) {
      throw new HttpsError(
        'failed-precondition',
        'The verified phone number does not match the selected member profile.',
      );
    }

    return {
      memberId: explicitSnapshot.id,
      memberData: member,
      phoneE164: authPhone,
    };
  }

  const inviteSnapshot = await invitesCollection.where('phoneE164', '==', authPhone).limit(5).get();
  const phoneInvite = inviteSnapshot.docs.find((doc) => {
    const invite = doc.data() as InviteRecord;
    return inviteIsActive(invite) && invite.inviteType === 'phone_claim' && typeof invite.memberId === 'string' && invite.memberId.trim().length > 0;
  });
  if (phoneInvite != null) {
    const invite = phoneInvite.data() as InviteRecord;
    const memberSnapshot = await membersCollection.doc(invite.memberId as string).get();
    if (memberSnapshot.exists) {
      return {
        memberId: memberSnapshot.id,
        memberData: memberSnapshot.data() as MemberRecord,
        phoneE164: authPhone,
      };
    }
  }

  const memberSnapshot = await membersCollection.where('phoneE164', '==', authPhone).limit(3).get();
  if (memberSnapshot.docs.length === 0) {
    return null;
  }

  if (memberSnapshot.docs.length === 1) {
    return {
      memberId: memberSnapshot.docs[0].id,
      memberData: memberSnapshot.docs[0].data() as MemberRecord,
      phoneE164: authPhone,
    };
  }

  const currentLink = memberSnapshot.docs.find(
    (doc) => (doc.data() as MemberRecord).authUid === uid,
  );
  if (currentLink != null) {
    return {
      memberId: currentLink.id,
      memberData: currentLink.data() as MemberRecord,
      phoneE164: authPhone,
    };
  }

  throw new HttpsError(
    'failed-precondition',
    'Multiple member profiles share this phone number. Please contact a clan administrator.',
  );
}

async function loadMatchingPhoneInviteRefs(
  phoneE164: string,
  memberId: string,
): Promise<Array<DocumentReference>> {
  const snapshot = await invitesCollection.where('phoneE164', '==', phoneE164).limit(10).get();
  return snapshot.docs
    .filter((doc) => {
      const invite = doc.data() as InviteRecord;
      return inviteIsActive(invite) && invite.memberId === memberId;
    })
    .map((doc) => doc.ref);
}

async function claimMemberTransaction({
  uid,
  memberRef,
  inviteRefs,
}: {
  uid: string;
  memberRef: DocumentReference;
  inviteRefs: Array<DocumentReference>;
}): Promise<boolean> {
  return db.runTransaction(async (transaction) => {
    const memberSnapshot = await transaction.get(memberRef);
    if (!memberSnapshot.exists) {
      throw new HttpsError('not-found', 'The member record no longer exists.');
    }

    const member = memberSnapshot.data() as MemberRecord;
    if (member.authUid != null && member.authUid.length > 0 && member.authUid !== uid) {
      throw new HttpsError(
        'already-exists',
        'This member profile is already linked to another account.',
      );
    }

    const shouldLinkAuthUid = member.authUid !== uid;
    const now = FieldValue.serverTimestamp();

    if (shouldLinkAuthUid) {
      transaction.update(memberRef, {
        authUid: uid,
        claimedAt: now,
        updatedAt: now,
        updatedBy: uid,
      });
    } else {
      transaction.update(memberRef, {
        updatedAt: now,
        updatedBy: uid,
      });
    }

    for (const inviteRef of inviteRefs) {
      transaction.update(inviteRef, {
        status: 'consumed',
        claimedAt: now,
        claimedBy: uid,
      });
    }

    return shouldLinkAuthUid;
  });
}

function buildMemberSessionContext(
  memberId: string,
  source: MemberRecord | ResolvedChildLoginContext,
  accessMode: MemberAccessMode,
  linkedAuthUid: boolean,
): MemberSessionContext {
  if ('parentPhoneE164' in source) {
    return {
      memberId,
      displayName: source.displayName,
      clanId: source.clanId,
      branchId: source.branchId,
      primaryRole: source.primaryRole,
      accessMode,
      linkedAuthUid,
    };
  }

  return {
    memberId,
    displayName: source.fullName ?? source.nickName ?? 'BeFam Member',
    clanId: source.clanId ?? null,
    branchId: source.branchId ?? null,
    primaryRole: source.primaryRole ?? 'MEMBER',
    accessMode,
    linkedAuthUid,
  };
}

async function applySessionClaims(uid: string, context: MemberSessionContext): Promise<void> {
  const auth = getAuth();
  const userRecord = await auth.getUser(uid);
  const existingClaims = userRecord.customClaims ?? {};

  await auth.setCustomUserClaims(uid, {
    ...existingClaims,
    clanIds: context.clanId == null ? [] : [context.clanId],
    memberId: context.memberId ?? '',
    branchId: context.branchId ?? '',
    primaryRole: context.primaryRole ?? 'GUEST',
    memberAccessMode: context.accessMode,
  });
}

async function writeAuditLog({
  uid,
  memberId,
  clanId,
  action,
  entityType,
  entityId,
  after,
}: {
  uid: string;
  memberId: string | null;
  clanId: string | null;
  action: string;
  entityType: string;
  entityId: string;
  after: Record<string, unknown>;
}): Promise<void> {
  if (clanId == null || clanId.length === 0) {
    return;
  }

  await auditLogsCollection.add({
    clanId,
    actorUid: uid,
    actorMemberId: memberId,
    entityType,
    entityId,
    action,
    before: null,
    after,
    createdAt: FieldValue.serverTimestamp(),
  });
}
