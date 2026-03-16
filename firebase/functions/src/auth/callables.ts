import { getAuth } from 'firebase-admin/auth';
import {
  FieldValue,
  Timestamp,
  type DocumentReference,
  type DocumentSnapshot,
} from 'firebase-admin/firestore';
import {
  HttpsError,
  onCall,
  type CallableRequest,
} from 'firebase-functions/v2/https';

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
  gender?: string | null;
  birthDate?: string | null;
  deathDate?: string | null;
  phoneE164?: string | null;
  email?: string | null;
  addressText?: string | null;
  jobTitle?: string | null;
  bio?: string | null;
  socialLinks?: Record<string, unknown> | null;
  isMinor?: boolean | null;
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

type LinkedClanContext = {
  clanId: string;
  clanName: string;
  memberId: string;
  branchId: string | null;
  primaryRole: string;
  displayName: string | null;
  status: string | null;
};

type ClanRecord = {
  name?: string | null;
  slug?: string | null;
  status?: string | null;
};

type DebugLoginProfileResponse = {
  scenarioKey: string;
  phoneE164: string;
  title: string;
  description: string;
  sortOrder: number;
  autoOtpCode: string | null;
};

type DebugProfileTokenResponse = {
  customToken: string;
  uid: string;
  phoneE164: string;
  memberId: string | null;
  displayName: string | null;
};

type LookupMemberProfileResponse = {
  found: boolean;
  profile: {
    memberId: string;
    clanId: string;
    branchId: string | null;
    fullName: string;
    nickName: string;
    gender: string | null;
    birthDate: string | null;
    deathDate: string | null;
    phoneE164: string;
    email: string | null;
    addressText: string | null;
    jobTitle: string | null;
    bio: string | null;
    isMinor: boolean;
    status: string | null;
    socialLinks: {
      facebook: string | null;
      zalo: string | null;
      linkedin: string | null;
    };
  } | null;
};

const membersCollection = db.collection('members');
const branchesCollection = db.collection('branches');
const clansCollection = db.collection('clans');
const invitesCollection = db.collection('invites');
const auditLogsCollection = db.collection('auditLogs');
const debugLoginProfilesCollection = db.collection('debug_login_profiles');
const usersCollection = db.collection('users');
const genealogyDiscoveryCollection = db.collection('genealogyDiscoveryIndex');
const customTokenSignerServiceAccount =
  'firebase-adminsdk-fbsvc@be-fam-3ab23.iam.gserviceaccount.com';

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
  const debugPhone = optionalString(auth.token, 'debugPhoneE164')?.trim() ?? '';
  const effectiveAuthPhone = authPhone.length > 0 ? authPhone : debugPhone;

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

  const explicitMemberId = optionalString(request.data, 'memberId')?.trim();
  const claimedMember = await resolvePhoneClaimMember({
    uid: auth.uid,
    authPhone: effectiveAuthPhone,
    explicitMemberId,
  });

  if (claimedMember == null) {
    const debugContext = extractDebugMemberSessionContext(auth.token);
    if (debugContext != null) {
      await applySessionClaims(auth.uid, debugContext);

      logInfo('claimMemberRecord resolved via debug context', {
        uid: auth.uid,
        memberId: debugContext.memberId,
        clanId: debugContext.clanId,
        primaryRole: debugContext.primaryRole,
      });

      return debugContext;
    }

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
      phoneE164: effectiveAuthPhone,
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

export const lookupMemberProfileByPhone = onCall(
  { region: APP_REGION },
  async (request): Promise<LookupMemberProfileResponse> => {
    const auth = requireAuth(request);
    const role = normalizeRoleClaim(auth.token.primaryRole);
    if (!isLookupRoleAllowed(role)) {
      throw new HttpsError(
        'permission-denied',
        'This session cannot lookup member profiles across the system.',
      );
    }

    const phoneInput = requireNonEmptyString(request.data, 'phoneE164');
    const phoneE164 = normalizePhoneE164(phoneInput);
    const snapshot = await membersCollection
      .where('phoneE164', '==', phoneE164)
      .limit(10)
      .get();

    if (snapshot.empty) {
      return { found: false, profile: null };
    }

    const candidate = [...snapshot.docs]
      .map((doc) => ({ id: doc.id, data: doc.data() as MemberRecord }))
      .sort((left, right) => {
        const byScore = memberLookupScore(right.data) - memberLookupScore(left.data);
        if (byScore !== 0) {
          return byScore;
        }
        return left.id.localeCompare(right.id);
      })[0];

    return {
      found: true,
      profile: {
        memberId: candidate.id,
        clanId: optionalTrimmedRecordString(candidate.data.clanId) ?? '',
        branchId: optionalTrimmedRecordString(candidate.data.branchId),
        fullName: optionalTrimmedRecordString(candidate.data.fullName) ?? '',
        nickName: optionalTrimmedRecordString(candidate.data.nickName) ?? '',
        gender: optionalTrimmedRecordString(candidate.data.gender),
        birthDate: optionalTrimmedRecordString(candidate.data.birthDate),
        deathDate: optionalTrimmedRecordString(candidate.data.deathDate),
        phoneE164,
        email: optionalTrimmedRecordString(candidate.data.email),
        addressText: optionalTrimmedRecordString(candidate.data.addressText),
        jobTitle: optionalTrimmedRecordString(candidate.data.jobTitle),
        bio: optionalTrimmedRecordString(candidate.data.bio),
        isMinor: candidate.data.isMinor === true,
        status: optionalTrimmedRecordString(candidate.data.status),
        socialLinks: {
          facebook: optionalTrimmedRecordString(candidate.data.socialLinks?.facebook),
          zalo: optionalTrimmedRecordString(candidate.data.socialLinks?.zalo),
          linkedin: optionalTrimmedRecordString(candidate.data.socialLinks?.linkedin),
        },
      },
    };
  },
);

export const bootstrapClanWorkspace = onCall(
  { region: APP_REGION },
  async (request) => {
    const auth = requireAuth(request);
    const tokenClanIds = extractTokenClanIds(auth.token);
    const allowExistingClan = request.data != null &&
      typeof request.data === 'object' &&
      (request.data as Record<string, unknown>).allowExistingClan === true;
    if (tokenClanIds.length > 0 && !allowExistingClan) {
      throw new HttpsError(
        'failed-precondition',
        'This account is already linked to a clan.',
      );
    }
    const activeClanIdFromToken = optionalString(auth.token, 'activeClanId')?.trim() ??
      optionalString(auth.token, 'clanId')?.trim() ??
      null;
    const activeMemberIdFromToken = optionalString(auth.token, 'memberId')?.trim() ?? null;
    const activeBranchIdFromToken = optionalString(auth.token, 'branchId')?.trim() ?? null;
    const activeRoleFromToken = normalizeRoleClaim(optionalString(auth.token, 'primaryRole'));
    const activeDisplayNameFromToken = optionalString(auth.token, 'name')?.trim() ??
      optionalString(auth.token, 'debugDisplayName')?.trim() ??
      null;
    const keepExistingActiveContext = allowExistingClan &&
      tokenClanIds.length > 0 &&
      activeClanIdFromToken != null &&
      activeClanIdFromToken.length > 0 &&
      activeMemberIdFromToken != null &&
      activeMemberIdFromToken.length > 0;

    const role = normalizeRoleClaim(auth.token.primaryRole);
    const clanName = requireNonEmptyString(request.data, 'name');
    const requestedSlug = optionalString(request.data, 'slug');
    const slug = normalizeSlug(requestedSlug ?? clanName);
    if (slug.length < 3) {
      throw new HttpsError(
        'invalid-argument',
        'slug must contain at least 3 alphanumeric characters.',
      );
    }

    const existingSlug = await clansCollection.where('slug', '==', slug).limit(1).get();
    if (!existingSlug.empty) {
      throw new HttpsError(
        'already-exists',
        'That clan slug is already in use. Please choose another slug.',
      );
    }

    const description = optionalString(request.data, 'description') ?? '';
    const countryCode = normalizeCountryCode(optionalString(request.data, 'countryCode'));
    const founderName = normalizeFounderName(request, clanName);
    const logoUrl = optionalString(request.data, 'logoUrl') ?? '';
    const ownerDisplayName = founderName.length > 0 ? founderName : deriveFallbackDisplayName(auth.uid);
    const ownerRole = resolveOwnerRole(role);
    const ownerPhone = optionalString(auth.token, 'phone_number');
    const normalizedFullName = ownerDisplayName.trim().toLowerCase();

    const clanRef = clansCollection.doc();
    const branchRef = branchesCollection.doc();
    const memberRef = membersCollection.doc();
    const userRef = usersCollection.doc(auth.uid);
    const discoveryRef = genealogyDiscoveryCollection.doc(clanRef.id);
    const clanIdsAfterCreate = [activeClanIdFromToken, ...tokenClanIds, clanRef.id]
      .filter((entry): entry is string => typeof entry === 'string')
      .map((entry) => entry.trim())
      .filter((entry, index, source) => entry.length > 0 && source.indexOf(entry) === index);
    const now = FieldValue.serverTimestamp();

    await db.runTransaction(async (transaction) => {
      transaction.set(clanRef, {
        id: clanRef.id,
        name: clanName,
        slug,
        description,
        countryCode,
        founderName,
        logoUrl,
        status: 'active',
        memberCount: 1,
        branchCount: 1,
        ownerUid: auth.uid,
        billingOwnerUid: auth.uid,
        createdAt: now,
        createdBy: auth.uid,
        updatedAt: now,
        updatedBy: auth.uid,
      }, { merge: true });

      transaction.set(branchRef, {
        id: branchRef.id,
        clanId: clanRef.id,
        name: 'Main Branch',
        code: 'MAIN',
        leaderMemberId: memberRef.id,
        viceLeaderMemberId: null,
        generationLevelHint: 1,
        status: 'active',
        memberCount: 1,
        createdAt: now,
        createdBy: auth.uid,
        updatedAt: now,
        updatedBy: auth.uid,
      }, { merge: true });

      transaction.set(memberRef, {
        id: memberRef.id,
        clanId: clanRef.id,
        branchId: branchRef.id,
        fullName: ownerDisplayName,
        normalizedFullName,
        nickName: '',
        gender: null,
        birthDate: null,
        deathDate: null,
        phoneE164: ownerPhone,
        email: null,
        addressText: null,
        jobTitle: null,
        avatarUrl: null,
        bio: null,
        socialLinks: {},
        parentIds: [],
        childrenIds: [],
        spouseIds: [],
        generation: 1,
        primaryRole: ownerRole,
        status: 'active',
        isMinor: false,
        authUid: auth.uid,
        claimedAt: now,
        createdAt: now,
        createdBy: auth.uid,
        updatedAt: now,
        updatedBy: auth.uid,
      }, { merge: true });

      transaction.set(userRef, {
        uid: auth.uid,
        memberId: keepExistingActiveContext ? activeMemberIdFromToken : memberRef.id,
        clanId: keepExistingActiveContext ? activeClanIdFromToken : clanRef.id,
        clanIds: clanIdsAfterCreate,
        branchId: keepExistingActiveContext ? (activeBranchIdFromToken ?? '') : branchRef.id,
        primaryRole: keepExistingActiveContext
          ? (activeRoleFromToken || ownerRole)
          : ownerRole,
        accessMode: 'claimed',
        linkedAuthUid: true,
        updatedAt: now,
        createdAt: now,
      }, { merge: true });

      transaction.set(discoveryRef, {
        id: clanRef.id,
        clanId: clanRef.id,
        genealogyName: clanName,
        genealogyNameNormalized: normalizeSearch(clanName),
        leaderName: ownerDisplayName,
        leaderNameNormalized: normalizeSearch(ownerDisplayName),
        provinceCity: '',
        provinceCityNormalized: '',
        summary: description,
        memberCount: 1,
        branchCount: 1,
        isPublic: false,
        createdAt: now,
        updatedAt: now,
      }, { merge: true });
    });

    const context: MemberSessionContext = keepExistingActiveContext
      ? {
        memberId: activeMemberIdFromToken,
        displayName: activeDisplayNameFromToken ?? ownerDisplayName,
        clanId: activeClanIdFromToken,
        branchId: activeBranchIdFromToken,
        primaryRole: activeRoleFromToken || ownerRole,
        accessMode: 'claimed',
        linkedAuthUid: true,
      }
      : {
        memberId: memberRef.id,
        displayName: ownerDisplayName,
        clanId: clanRef.id,
        branchId: branchRef.id,
        primaryRole: ownerRole,
        accessMode: 'claimed',
        linkedAuthUid: true,
      };
    await applySessionClaims(auth.uid, context, {
      clanIds: clanIdsAfterCreate,
    });
    await writeAuditLog({
      uid: auth.uid,
      memberId: memberRef.id,
      clanId: clanRef.id,
      action: keepExistingActiveContext
        ? 'clan_workspace_created_additional'
        : 'clan_workspace_bootstrapped',
      entityType: 'clan',
      entityId: clanRef.id,
      after: {
        branchId: branchRef.id,
        memberId: memberRef.id,
        primaryRole: ownerRole,
        createdAsAdditional: keepExistingActiveContext,
      },
    });

    logInfo('bootstrapClanWorkspace succeeded', {
      uid: auth.uid,
      clanId: clanRef.id,
      branchId: branchRef.id,
      memberId: memberRef.id,
      ownerRole,
      keepExistingActiveContext,
    });

    return {
      clanId: clanRef.id,
      branchId: branchRef.id,
      memberId: memberRef.id,
      primaryRole: ownerRole,
      accessMode: 'claimed',
      activeClanId: context.clanId,
      switchedActiveClan: context.clanId === clanRef.id,
      clanIds: clanIdsAfterCreate,
    };
  },
);

export const registerDeviceToken = onCall({ region: APP_REGION }, async (request) => {
  const auth = requireAuth(request);
  const token = requireNonEmptyString(request.data, 'token').trim();
  if (token.length > 4096) {
    throw new HttpsError('invalid-argument', 'token is too long.');
  }

  const requestPlatform = optionalString(request.data, 'platform')?.trim().toLowerCase();
  const platform = requestPlatform != null && requestPlatform.length > 0
    ? requestPlatform.slice(0, 32)
    : 'unknown';

  const memberIdFromClaim = typeof auth.token.memberId === 'string'
    ? auth.token.memberId.trim()
    : '';
  const branchIdFromClaim = typeof auth.token.branchId === 'string'
    ? auth.token.branchId.trim()
    : '';
  const roleFromClaim = typeof auth.token.primaryRole === 'string'
    ? auth.token.primaryRole.trim()
    : '';
  const claimClanIdsRaw = Array.isArray(auth.token.clanIds) ? auth.token.clanIds : [];
  const claimClanIds = claimClanIdsRaw
    .filter((value): value is string => typeof value === 'string')
    .map((value) => value.trim())
    .filter((value) => value.length > 0);

  const fallbackMemberId = optionalString(request.data, 'memberId')?.trim() ?? '';
  const fallbackBranchId = optionalString(request.data, 'branchId')?.trim() ?? '';
  const fallbackClanId = optionalString(request.data, 'clanId')?.trim() ?? '';
  const fallbackAccessMode = optionalString(request.data, 'accessMode')?.trim() ?? '';

  const memberId = memberIdFromClaim.length > 0 ? memberIdFromClaim : fallbackMemberId;
  const branchId = branchIdFromClaim.length > 0 ? branchIdFromClaim : fallbackBranchId;
  const clanId = claimClanIds.length > 0
    ? claimClanIds[0]
    : fallbackClanId;
  const accessMode = typeof auth.token.memberAccessMode === 'string'
    ? auth.token.memberAccessMode.trim()
    : fallbackAccessMode;

  logInfo('registerDeviceToken requested', {
    uid: auth.uid,
    tokenLength: token.length,
    platform,
    memberId,
    clanId,
    branchId,
    primaryRole: roleFromClaim,
    accessMode,
  });

  await db
    .collection('users')
    .doc(auth.uid)
    .collection('deviceTokens')
    .doc(token)
    .set({
      token,
      uid: auth.uid,
      platform,
      memberId: memberId.length > 0 ? memberId : null,
      clanId: clanId.length > 0 ? clanId : null,
      branchId: branchId.length > 0 ? branchId : null,
      primaryRole: roleFromClaim.length > 0 ? roleFromClaim : null,
      accessMode: accessMode.length > 0 ? accessMode : null,
      updatedAt: FieldValue.serverTimestamp(),
      lastSeenAt: FieldValue.serverTimestamp(),
      createdAt: FieldValue.serverTimestamp(),
    }, { merge: true });

  return {
    status: 'registered',
    token,
  };
});

export const listDebugLoginProfiles = onCall(
  { region: APP_REGION },
  async (request): Promise<{ profiles: Array<DebugLoginProfileResponse> }> => {
    const snapshot = await debugLoginProfilesCollection.limit(25).get();
    const profiles = snapshot.docs
      .map((doc) => sanitizeDebugLoginProfile(doc.id, doc.data() as Record<string, unknown>))
      .filter((profile): profile is DebugLoginProfileResponse => profile != null)
      .sort((left, right) => left.sortOrder - right.sortOrder);

    logInfo('listDebugLoginProfiles succeeded', {
      count: profiles.length,
      hasAuth: request.auth != null,
      appId: request.app?.appId ?? null,
    });

    return { profiles };
  },
);

export const listUserClanContexts = onCall(
  { region: APP_REGION },
  async (request) => {
    const auth = requireAuth(request);
    const contexts = await loadLinkedClanContextsForUid(auth.uid);
    const activeContext = resolveActiveClanContext({
      contexts,
      requestedClanId: null,
      token: auth.token,
    });

    return {
      accessMode: contexts.length > 0 ? 'claimed' : 'unlinked',
      activeClanId: activeContext?.clanId ?? null,
      contexts: contexts.map(serializeLinkedClanContext),
    };
  },
);

export const switchActiveClanContext = onCall(
  { region: APP_REGION },
  async (request) => {
    const auth = requireAuth(request);
    const requestedClanId = requireNonEmptyString(request.data, 'clanId');
    const contexts = await loadLinkedClanContextsForUid(auth.uid);
    if (contexts.length == 0) {
      throw new HttpsError(
        'failed-precondition',
        'This account is not linked to any clan membership yet.',
      );
    }

    const activeContext = resolveActiveClanContext({
      contexts,
      requestedClanId,
      token: auth.token,
    });
    if (activeContext == null || activeContext.clanId !== requestedClanId) {
      throw new HttpsError(
        'permission-denied',
        'The requested clan is not linked to this account.',
      );
    }

    const orderedClanIds = [
      activeContext.clanId,
      ...contexts
        .map((context) => context.clanId)
        .filter((clanId) => clanId != activeContext.clanId),
    ];

    const memberContext: MemberSessionContext = {
      memberId: activeContext.memberId,
      displayName: activeContext.displayName,
      clanId: activeContext.clanId,
      branchId: activeContext.branchId,
      primaryRole: activeContext.primaryRole,
      accessMode: 'claimed',
      linkedAuthUid: true,
    };

    await applySessionClaims(auth.uid, memberContext, {
      clanIds: orderedClanIds,
    });

    await usersCollection.doc(auth.uid).set({
      uid: auth.uid,
      memberId: activeContext.memberId,
      clanId: activeContext.clanId,
      clanIds: orderedClanIds,
      branchId: activeContext.branchId ?? '',
      primaryRole: activeContext.primaryRole,
      accessMode: 'claimed',
      linkedAuthUid: true,
      updatedAt: FieldValue.serverTimestamp(),
      createdAt: FieldValue.serverTimestamp(),
    }, { merge: true });

    await writeAuditLog({
      uid: auth.uid,
      memberId: activeContext.memberId,
      clanId: activeContext.clanId,
      action: 'active_clan_context_switched',
      entityType: 'clan',
      entityId: activeContext.clanId,
      after: {
        clanId: activeContext.clanId,
        memberId: activeContext.memberId,
        primaryRole: activeContext.primaryRole,
        clanIds: orderedClanIds,
      },
    });

    return {
      accessMode: 'claimed',
      activeClanId: activeContext.clanId,
      activeContext: serializeLinkedClanContext(activeContext),
      contexts: contexts.map(serializeLinkedClanContext),
    };
  },
);

export const issueDebugProfileCustomToken = onCall(
  {
    region: APP_REGION,
    serviceAccount: customTokenSignerServiceAccount,
  },
  async (request): Promise<DebugProfileTokenResponse> => {
    const phoneE164 = requireNonEmptyString(request.data, 'phoneE164').trim();
    const snapshot = await debugLoginProfilesCollection.doc(phoneE164).get();
    if (!snapshot.exists) {
      throw new HttpsError(
        'not-found',
        'No debug login profile exists for that phone number.',
      );
    }

    const rawData = snapshot.data() as Record<string, unknown>;
    const profile = sanitizeDebugLoginProfile(snapshot.id, rawData);
    if (profile == null) {
      throw new HttpsError(
        'permission-denied',
        'This profile is not enabled for debug sign-in.',
      );
    }

    const memberId = asNullableTrimmedString(rawData.memberId);
    const clanId = asNullableTrimmedString(rawData.clanId);
    const branchId = asNullableTrimmedString(rawData.branchId);
    const primaryRole = asNullableTrimmedString(rawData.primaryRole);
    const linkedAuthUid = rawData.linkedAuthUid === true;

    const accessModeRaw = asTrimmedString(rawData.accessMode).toLowerCase();
    const accessMode: MemberAccessMode = accessModeRaw === 'claimed'
      ? 'claimed'
      : accessModeRaw === 'child'
        ? 'child'
        : 'unlinked';

    let memberData: MemberRecord | null = null;
    let memberUid = '';
    if (memberId != null) {
      const memberSnapshot = await membersCollection.doc(memberId).get();
      if (memberSnapshot.exists) {
        memberData = memberSnapshot.data() as MemberRecord;
        memberUid = memberData.authUid?.trim() ?? '';
      }
    }

    const profileUid = asTrimmedString(rawData.authUid);
    const uid = buildDebugAuthUid(profileUid || memberUid || phoneE164);
    const profileDisplayName = asNullableTrimmedString(rawData.displayName);
    const displayName = profileDisplayName ??
      (memberData != null ? resolveMemberDisplayName(memberData) : null) ??
      profile.title;

    const additionalClaims: Record<string, string | boolean> = {
      debugProfile: true,
      debugPhoneE164: phoneE164,
      debugLinkedAuthUid: linkedAuthUid,
      debugAccessMode: accessMode,
    };
    if (memberId != null) {
      additionalClaims.debugMemberId = memberId;
    }
    if (displayName.length > 0) {
      additionalClaims.debugDisplayName = displayName;
    }
    if (clanId != null) {
      additionalClaims.debugClanId = clanId;
    }
    if (branchId != null) {
      additionalClaims.debugBranchId = branchId;
    }
    if (primaryRole != null) {
      additionalClaims.debugPrimaryRole = primaryRole;
    }

    const customToken = await getAuth().createCustomToken(uid, additionalClaims);

    logInfo('issueDebugProfileCustomToken succeeded', {
      uid,
      phoneE164,
      scenarioKey: profile.scenarioKey,
      memberId,
      hasAuth: request.auth != null,
      appId: request.app?.appId ?? null,
    });

    return {
      customToken,
      uid,
      phoneE164,
      memberId,
      displayName: displayName.length > 0 ? displayName : null,
    };
  },
);

function requireNonEmptyString(data: unknown, key: string): string {
  const value = optionalString(data, key)?.trim();
  if (value == null || value.length === 0) {
    throw new HttpsError('invalid-argument', `${key} is required.`);
  }

  return value;
}

function normalizePhoneE164(input: string): string {
  const trimmed = input.trim();
  const digitsAndPlus = trimmed.replace(/[^0-9+]/g, '');
  let normalized = '';

  if (digitsAndPlus.startsWith('+')) {
    normalized = `+${digitsAndPlus.slice(1).replace(/[^0-9]/g, '')}`;
  } else if (digitsAndPlus.startsWith('00')) {
    normalized = `+${digitsAndPlus.slice(2)}`;
  } else if (digitsAndPlus.startsWith('0')) {
    normalized = `+84${digitsAndPlus.slice(1)}`;
  } else {
    normalized = `+${digitsAndPlus}`;
  }

  if (!/^\+[1-9]\d{8,14}$/.test(normalized)) {
    throw new HttpsError('invalid-argument', 'phoneE164 has invalid format.');
  }

  return normalized;
}

function optionalTrimmedRecordString(value: unknown): string | null {
  if (typeof value !== 'string') {
    return null;
  }
  const normalized = value.trim();
  return normalized.length > 0 ? normalized : null;
}

function isLookupRoleAllowed(role: string): boolean {
  return role === 'SUPER_ADMIN' ||
    role === 'CLAN_ADMIN' ||
    role === 'CLAN_OWNER' ||
    role === 'CLAN_LEADER' ||
    role === 'BRANCH_ADMIN' ||
    role === 'ADMIN_SUPPORT';
}

function memberLookupScore(member: MemberRecord): number {
  let score = 0;
  if ((member.status ?? '').toLowerCase() === 'active') {
    score += 30;
  }
  if (optionalTrimmedRecordString(member.authUid) != null) {
    score += 20;
  }
  if (optionalTrimmedRecordString(member.fullName) != null) {
    score += 10;
  }
  if (optionalTrimmedRecordString(member.birthDate) != null) {
    score += 6;
  }
  if (optionalTrimmedRecordString(member.email) != null) {
    score += 4;
  }
  if (optionalTrimmedRecordString(member.addressText) != null) {
    score += 2;
  }
  return score;
}

function optionalString(data: unknown, key: string): string | null {
  if (data == null || typeof data !== 'object') {
    return null;
  }

  const value = (data as Record<string, unknown>)[key];
  return typeof value === 'string' ? value : null;
}

function sanitizeDebugLoginProfile(
  docId: string,
  data: Record<string, unknown>,
): DebugLoginProfileResponse | null {
  if (data.isActive === false) {
    return null;
  }
  if (data.isTestUser !== true) {
    return null;
  }

  const phoneFromData = asTrimmedString(data.phoneE164);
  const phoneE164 = (phoneFromData.length > 0 ? phoneFromData : docId).trim();
  if (phoneE164.length === 0) {
    return null;
  }

  const scenarioKey = asTrimmedString(data.scenarioKey, docId);
  const title = asTrimmedString(data.title, scenarioKey);
  const description = asTrimmedString(data.description, phoneE164);
  const sortOrder = typeof data.sortOrder === 'number' ? data.sortOrder : 9999;

  const rawOtp = asTrimmedString(data.debugOtpCode, asTrimmedString(data.otpCode));
  const digitsOnlyOtp = rawOtp.replace(/[^\d]/g, '');
  const autoOtpCode = digitsOnlyOtp.length === 6 ? digitsOnlyOtp : null;

  return {
    scenarioKey,
    phoneE164,
    title,
    description,
    sortOrder,
    autoOtpCode,
  };
}

function asTrimmedString(value: unknown, fallback = ''): string {
  if (typeof value !== 'string') {
    return fallback.trim();
  }
  return value.trim();
}

function asNullableTrimmedString(value: unknown): string | null {
  if (typeof value !== 'string') {
    return null;
  }
  const normalized = value.trim();
  return normalized.length > 0 ? normalized : null;
}

function buildDebugAuthUid(seed: string): string {
  const raw = seed.trim();
  const digits = raw.replace(/[^\d]/g, '');
  const base = digits.length > 0
    ? `debug_phone_${digits}`
    : `debug_profile_${raw.toLowerCase().replace(/[^a-z0-9]+/g, '_')}`;
  const compact = base.replace(/^_+|_+$/g, '');
  if (compact.length <= 120) {
    return compact;
  }
  return compact.slice(0, 120);
}

function resolveMemberDisplayName(member: MemberRecord): string | null {
  const fullName = member.fullName?.trim() ?? '';
  if (fullName.length > 0) {
    return fullName;
  }
  const nickName = member.nickName?.trim() ?? '';
  if (nickName.length > 0) {
    return nickName;
  }
  return null;
}

function extractDebugMemberSessionContext(token: unknown): MemberSessionContext | null {
  if (token == null || typeof token !== 'object') {
    return null;
  }
  const claims = token as Record<string, unknown>;
  if (claims.debugProfile !== true) {
    return null;
  }

  const memberId = asNullableTrimmedString(claims.debugMemberId);
  const displayName = asNullableTrimmedString(claims.debugDisplayName);
  const clanId = asNullableTrimmedString(claims.debugClanId);
  const branchId = asNullableTrimmedString(claims.debugBranchId);
  const primaryRole = asNullableTrimmedString(claims.debugPrimaryRole);
  const linkedAuthUid = claims.debugLinkedAuthUid === true;

  const rawAccessMode = asTrimmedString(claims.debugAccessMode).toLowerCase();
  const accessMode: MemberAccessMode = rawAccessMode === 'claimed'
    ? 'claimed'
    : rawAccessMode === 'child'
      ? 'child'
      : 'unlinked';

  if (
    memberId == null &&
    displayName == null &&
    clanId == null &&
    branchId == null &&
    primaryRole == null
  ) {
    return null;
  }

  return {
    memberId,
    displayName,
    clanId,
    branchId,
    primaryRole,
    accessMode,
    linkedAuthUid,
  };
}

function normalizeRoleClaim(value: unknown): string {
  if (typeof value !== 'string') {
    return '';
  }
  return value.trim().toUpperCase();
}

function extractTokenClanIds(token: unknown): Array<string> {
  if (token == null || typeof token !== 'object') {
    return [];
  }
  const raw = (token as Record<string, unknown>).clanIds;
  if (!Array.isArray(raw)) {
    return [];
  }
  return raw
    .filter((entry): entry is string => typeof entry === 'string')
    .map((entry) => entry.trim())
    .filter((entry) => entry.length > 0);
}

function normalizeSlug(value: string): string {
  return value
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '');
}

function normalizeSearch(value: string): string {
  return value.trim().toLowerCase().replace(/\s+/g, ' ');
}

function normalizeCountryCode(value: string | null): string {
  const normalized = (value ?? 'VN').trim().toUpperCase();
  if (normalized.length < 2 || normalized.length > 3) {
    return 'VN';
  }
  return normalized;
}

function normalizeFounderName(
  request: CallableRequest<unknown>,
  fallbackName: string,
): string {
  const fromRequest = optionalString(request.data, 'founderName');
  if (fromRequest != null && fromRequest.trim().length > 0) {
    return fromRequest.trim();
  }

  const fromToken = optionalString(request.auth?.token, 'name');
  if (fromToken != null && fromToken.trim().length > 0) {
    return fromToken.trim();
  }

  return fallbackName.trim();
}

function deriveFallbackDisplayName(uid: string): string {
  const safeUid = uid.trim();
  if (safeUid.length <= 8) {
    return `Clan Owner ${safeUid}`;
  }
  return `Clan Owner ${safeUid.slice(0, 8)}`;
}

function resolveOwnerRole(role: string): string {
  if (role === 'SUPER_ADMIN' || role === 'CLAN_ADMIN' || role === 'ADMIN_SUPPORT') {
    return role;
  }
  if (role === 'CLAN_OWNER' || role === 'CLAN_LEADER') {
    return role;
  }
  return 'CLAN_LEADER';
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

async function applySessionClaims(
  uid: string,
  context: MemberSessionContext,
  options?: { clanIds?: Array<string> },
): Promise<void> {
  const auth = getAuth();
  const userRecord = await auth.getUser(uid);
  const existingClaims = userRecord.customClaims ?? {};
  const explicitClanIds = options?.clanIds ?? [];
  const normalizedClanIds = explicitClanIds
    .map((entry) => entry.trim())
    .filter((entry, index, source) => entry.length > 0 && source.indexOf(entry) == index);
  const clanIds = normalizedClanIds.length > 0
    ? normalizedClanIds
    : context.clanId == null
      ? []
      : [context.clanId];
  const activeClanId = context.clanId ?? clanIds[0] ?? '';

  await auth.setCustomUserClaims(uid, {
    ...existingClaims,
    clanIds: clanIds,
    clanId: activeClanId,
    activeClanId,
    memberId: context.memberId ?? '',
    branchId: context.branchId ?? '',
    primaryRole: context.primaryRole ?? 'GUEST',
    memberAccessMode: context.accessMode,
  });
}

function serializeLinkedClanContext(context: LinkedClanContext) {
  return {
    clanId: context.clanId,
    clanName: context.clanName,
    memberId: context.memberId,
    branchId: context.branchId,
    primaryRole: context.primaryRole,
    displayName: context.displayName,
    status: context.status,
  };
}

async function loadLinkedClanContextsForUid(uid: string): Promise<Array<LinkedClanContext>> {
  const snapshot = await membersCollection
    .where('authUid', '==', uid)
    .limit(300)
    .get();

  if (snapshot.empty) {
    return [];
  }

  const dedupByClan = new Map<string, LinkedClanContext>();
  for (const doc of snapshot.docs) {
    const data = doc.data() as MemberRecord;
    const clanId = asNullableTrimmedString(data.clanId);
    if (clanId == null) {
      continue;
    }

    const role = normalizeRoleClaim(data.primaryRole) || 'MEMBER';
    const displayName = resolveMemberDisplayName(data);
    const branchId = asNullableTrimmedString(data.branchId);
    const status = asNullableTrimmedString(data.status)?.toLowerCase() ?? null;
    const candidate: LinkedClanContext = {
      clanId,
      clanName: clanId,
      memberId: doc.id,
      branchId,
      primaryRole: role,
      displayName,
      status,
    };

    const existing = dedupByClan.get(clanId);
    if (existing == null || preferredClanContext(candidate, existing)) {
      dedupByClan.set(clanId, candidate);
    }
  }

  if (dedupByClan.size == 0) {
    return [];
  }

  const clanIds = [...dedupByClan.keys()];
  const clanSnapshots = await Promise.all(
    clanIds.map((clanId) => clansCollection.doc(clanId).get()),
  );
  const clanNameById = new Map<string, string>();
  for (const snapshot of clanSnapshots) {
    const data = snapshot.data() as ClanRecord | undefined;
    const clanName = asNullableTrimmedString(data?.name) ?? snapshot.id;
    clanNameById.set(snapshot.id, clanName);
  }

  for (const clanId of clanIds) {
    const context = dedupByClan.get(clanId);
    if (context == null) {
      continue;
    }
    dedupByClan.set(clanId, {
      ...context,
      clanName: clanNameById.get(clanId) ?? context.clanName,
    });
  }

  return [...dedupByClan.values()].sort((left, right) => {
    const clanCompare = left.clanName
      .toLowerCase()
      .localeCompare(right.clanName.toLowerCase());
    if (clanCompare !== 0) {
      return clanCompare;
    }
    return left.clanId.localeCompare(right.clanId);
  });
}

function resolveActiveClanContext({
  contexts,
  requestedClanId,
  token,
}: {
  contexts: Array<LinkedClanContext>;
  requestedClanId: string | null;
  token: Record<string, unknown>;
}): LinkedClanContext | null {
  if (contexts.length === 0) {
    return null;
  }
  const requested = requestedClanId?.trim();
  if (requested != null && requested.length > 0) {
    return contexts.find((context) => context.clanId == requested) ?? null;
  }

  const activeFromToken = optionalString(token, 'activeClanId')?.trim() ??
    optionalString(token, 'clanId')?.trim();
  if (activeFromToken != null && activeFromToken.length > 0) {
    const matched = contexts.find((context) => context.clanId == activeFromToken);
    if (matched != null) {
      return matched;
    }
  }

  return contexts[0] ?? null;
}

function preferredClanContext(candidate: LinkedClanContext, current: LinkedClanContext): boolean {
  const candidateRank = rolePriority(candidate.primaryRole);
  const currentRank = rolePriority(current.primaryRole);
  if (candidateRank != currentRank) {
    return candidateRank > currentRank;
  }

  const candidateActive = (candidate.status ?? 'active') == 'active';
  const currentActive = (current.status ?? 'active') == 'active';
  if (candidateActive != currentActive) {
    return candidateActive;
  }

  return candidate.memberId.localeCompare(current.memberId) < 0;
}

function rolePriority(role: string): number {
  const normalized = normalizeRoleClaim(role);
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
