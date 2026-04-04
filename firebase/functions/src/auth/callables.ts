import { createHash } from "node:crypto";

import { getAuth } from "firebase-admin/auth";
import { getMessaging } from "firebase-admin/messaging";
import {
  FieldValue,
  Timestamp,
  type DocumentReference,
  type DocumentSnapshot,
} from "firebase-admin/firestore";
import {
  HttpsError,
  onCall,
  type CallableRequest,
} from "firebase-functions/v2/https";

import {
  APP_REGION,
  CALLABLE_ENFORCE_APP_CHECK,
  OTP_ALLOWED_DIAL_CODES,
  OTP_PROVIDER,
  OTP_REVIEW_BYPASS_ENABLED,
  OTP_REVIEW_BYPASS_PHONES,
  OTP_TWILIO_ACCOUNT_SID,
  OTP_TWILIO_BACKOFF_MS,
  OTP_TWILIO_MAX_RETRIES,
  OTP_TWILIO_TIMEOUT_MS,
  OTP_TWILIO_VERIFY_SERVICE_SID,
  getOtpReviewBypassCode,
  getOtpTwilioAuthToken,
} from "../config/runtime";
import { sendEventReminderRun } from "../events/event-triggers";
import { db } from "../shared/firestore";
import { requireAuth } from "../shared/errors";
import { logInfo, logWarn } from "../shared/logger";

type LoginMethod = "phone" | "child";
type MemberAccessMode = "unlinked" | "claimed" | "child";

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
  maskedDestination: string;
};

type InternalResolvedChildLoginContext = ResolvedChildLoginContext & {
  parentPhoneE164: string;
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
  ownerUid: string | null;
  ownerDisplayName: string | null;
  billingPlanCode: string | null;
  billingPlanStatus: string | null;
};

type ClanRecord = {
  name?: string | null;
  slug?: string | null;
  status?: string | null;
  founderName?: string | null;
  ownerUid?: string | null;
};

type DiscoveryIndexRecord = {
  clanId?: string | null;
  genealogyName?: string | null;
  genealogyNameNormalized?: string | null;
  leaderName?: string | null;
  leaderNameNormalized?: string | null;
  provinceCity?: string | null;
  provinceCityNormalized?: string | null;
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

type MaskedMemberCandidate = {
  memberId: string;
  displayName: string;
  displayNameMasked: string;
  birthHint: string | null;
  clanLabel: string | null;
  roleLabel: string | null;
  memberStatus: string | null;
  selectable: boolean;
  blockedReason: "member_linked_other_account" | "member_inactive" | null;
};

type VerificationQuestionOption = {
  id: string;
  label: string;
};

type VerificationQuestion = {
  id: string;
  category: "personal" | "clan";
  prompt: string;
  options: Array<VerificationQuestionOption>;
  answerOptionId: string;
};

type VerificationSessionRecord = {
  uid: string;
  memberId: string;
  phoneE164: string;
  deviceTokenHash: string;
  status: "pending" | "passed" | "failed" | "locked" | "expired";
  maxAttempts: number;
  attemptsUsed: number;
  questions: Array<{
    id: string;
    category: "personal" | "clan";
    prompt: string;
    options: Array<VerificationQuestionOption>;
    answerOptionId: string;
  }>;
  createdAt?: Timestamp | null;
  updatedAt?: Timestamp | null;
  expiresAt?: Timestamp | null;
  passedAt?: Timestamp | null;
  lastScore?: number | null;
};

type MemberVerificationGuardRecord = {
  uid?: string | null;
  memberId?: string | null;
  failedAttempts?: number | null;
  windowStartedAt?: Timestamp | null;
  lockedUntil?: Timestamp | null;
  lockCount?: number | null;
  lastLockedAt?: Timestamp | null;
  updatedAt?: Timestamp | null;
};

type SupportedLanguageCode = "vi" | "en";

type UserSessionProfileRecord = {
  memberId?: string | null;
  clanId?: string | null;
  clanIds?: Array<string> | null;
  branchId?: string | null;
  primaryRole?: string | null;
  accessMode?: string | null;
  linkedAuthUid?: boolean | null;
  normalizedPhone?: string | null;
};

type TrustedDeviceRecord = {
  uid?: string | null;
  memberId?: string | null;
  deviceTokenHash?: string | null;
  trustStatus?: string | null;
  expiresAt?: Timestamp | null;
};

type OtpChallengeSessionRecord = {
  provider?: string | null;
  status?: string | null;
  loginMethod?: LoginMethod | string | null;
  phoneE164?: string | null;
  maskedDestination?: string | null;
  childIdentifier?: string | null;
  memberId?: string | null;
  displayName?: string | null;
  appId?: string | null;
  fingerprintHash?: string | null;
  twilioVerificationSid?: string | null;
  reviewBypassEligible?: boolean | null;
  verifyAttempts?: number | null;
  maxVerifyAttempts?: number | null;
  expiresAt?: Timestamp | null;
  uid?: string | null;
  createdAt?: Timestamp | null;
  updatedAt?: Timestamp | null;
  approvedAt?: Timestamp | null;
  failedAt?: Timestamp | null;
  failureCode?: string | null;
  failureReason?: string | null;
};

const membersCollection = db.collection("members");
const branchesCollection = db.collection("branches");
const clansCollection = db.collection("clans");
const invitesCollection = db.collection("invites");
const auditLogsCollection = db.collection("auditLogs");
const authEventLogsCollection = db.collection("authEventLogs");
const usersCollection = db.collection("users");
const genealogyDiscoveryCollection = db.collection("genealogyDiscoveryIndex");
const authRateLimitsCollection = db.collection("authRateLimits");
const trustedDevicesCollection = db.collection("trustedDevices");
const memberVerificationSessionsCollection = db.collection(
  "memberVerificationSessions",
);
const memberVerificationGuardsCollection = db.collection(
  "memberVerificationGuards",
);
const authOtpSessionsCollection = db.collection("authOtpSessions");
const phoneAuthIdentitiesCollection = db.collection("phoneAuthIdentities");
const subscriptionsCollection = db.collection("subscriptions");
const CHILD_LOOKUP_WINDOW_MS = 5 * 60 * 1000;
const CHILD_LOOKUP_MAX_REQUESTS = 8;
const OTP_REQUEST_WINDOW_MS = 10 * 60 * 1000;
const OTP_REQUEST_MAX_REQUESTS = 6;
const OTP_CHALLENGE_TTL_MS = 10 * 60 * 1000;
const OTP_CHALLENGE_MAX_VERIFY_ATTEMPTS = 6;
const TRUSTED_DEVICE_TTL_MS = 90 * 24 * 60 * 60 * 1000;
const MEMBER_VERIFICATION_SESSION_TTL_MS = 15 * 60 * 1000;
const MEMBER_VERIFICATION_MAX_ATTEMPTS = 3;
const MEMBER_VERIFICATION_TOTAL_QUESTIONS = 4;
const MEMBER_VERIFICATION_REQUIRED_CORRECT = 3;
const MEMBER_VERIFICATION_LOCK_WINDOW_MS = 30 * 60 * 1000;
const AUTH_ABUSE_LOCK_RESET_WINDOW_MS = 7 * 24 * 60 * 60 * 1000;
const AUTH_ABUSE_LOCK_DURATIONS_MS = [
  30 * 60 * 1000,
  60 * 60 * 1000,
  24 * 60 * 60 * 1000,
] as const;
const APP_CHECK_CALLABLE_OPTIONS = {
  region: APP_REGION,
  enforceAppCheck: CALLABLE_ENFORCE_APP_CHECK,
} as const;
const SELF_TEST_NOTIFICATION_CALLABLE_OPTIONS = {
  region: APP_REGION,
  enforceAppCheck: false,
} as const;
const SUPPORTED_PHONE_DIAL_CODES = [
  "886",
  "84",
  "82",
  "81",
  "65",
  "61",
  "49",
  "44",
  "33",
  "1",
];
const OTP_REVIEW_BYPASS_PHONE_SET = buildOtpReviewBypassPhoneSet();
const SELF_TEST_NOTIFICATION_INVALID_TOKEN_CODES = new Set([
  "messaging/invalid-registration-token",
  "messaging/registration-token-not-registered",
]);

function personalBillingScopeId(uid: string): string {
  return `user_scope__${uid.trim()}`;
}

function ownerBillingSubscriptionDocId(ownerUid: string): string {
  const scopeId = personalBillingScopeId(ownerUid);
  return `${scopeId}__${ownerUid.trim()}`;
}

export const resolveChildLoginContext = onCall(
  APP_CHECK_CALLABLE_OPTIONS,
  async (request) => {
    const childIdentifier = requireNonEmptyString(
      request.data,
      "childIdentifier",
    )
      .trim()
      .toUpperCase();
    await enforceChildLookupRateLimit(request, childIdentifier);

    let resolved: InternalResolvedChildLoginContext;
    try {
      resolved = await findChildLoginContext(childIdentifier);
    } catch (error) {
      if (error instanceof HttpsError && error.code === "resource-exhausted") {
        throw error;
      }
      logWarn("resolveChildLoginContext failed", {
        childIdentifierHash: hashValueForLog(childIdentifier),
        appId: request.app?.appId ?? null,
        code: error instanceof HttpsError ? error.code : "unknown",
      });
      throw new HttpsError(
        "not-found",
        "Child login context is unavailable. Please verify and try again.",
      );
    }

    logInfo("resolveChildLoginContext succeeded", {
      childIdentifierHash: hashValueForLog(resolved.childIdentifier),
      maskedDestination: resolved.maskedDestination,
      appId: request.app?.appId ?? null,
    });

    return {
      childIdentifier: resolved.childIdentifier,
      maskedDestination: resolved.maskedDestination,
    };
  },
);

export const requestOtpChallenge = onCall(
  APP_CHECK_CALLABLE_OPTIONS,
  async (request) => {
    const loginMethod = requireLoginMethod(request.data);
    const languageCode = resolvePreferredLanguageCode(request.data);

    let phoneE164 = "";
    let childIdentifier: string | null = null;
    let memberId: string | null = null;
    let displayName: string | null = null;
    if (loginMethod === "child") {
      childIdentifier = requireNonEmptyString(request.data, "childIdentifier")
        .trim()
        .toUpperCase();
      await enforceChildLookupRateLimit(request, childIdentifier);
      const resolved = await findChildLoginContext(childIdentifier);
      phoneE164 = normalizePhoneE164(resolved.parentPhoneE164);
      memberId = resolved.memberId;
      displayName = resolved.displayName;
    } else {
      phoneE164 = normalizePhoneE164(
        requireNonEmptyString(request.data, "phoneE164"),
      );
      memberId = optionalString(request.data, "memberId")?.trim() ?? null;
      displayName = optionalString(request.data, "displayName")?.trim() ?? null;
    }

    assertOtpDialCodeAllowed(phoneE164);
    await enforceOtpRequestRateLimit(request, phoneE164);

    const reviewBypassEligible = shouldUseOtpReviewBypass(phoneE164);
    if (!reviewBypassEligible) {
      ensureTwilioOtpEnabled();
    }
    const providerResponse = reviewBypassEligible
      ? null
      : await requestTwilioOtp({
          phoneE164,
          languageCode,
        });
    const sessionRef = authOtpSessionsCollection.doc();
    const fingerprint = resolveOtpRequestFingerprint(request, phoneE164);
    await sessionRef.set(
      {
        id: sessionRef.id,
        provider: "twilio",
        status: "pending",
        loginMethod,
        phoneE164,
        maskedDestination: maskPhone(phoneE164),
        childIdentifier,
        memberId,
        displayName,
        appId: request.app?.appId ?? null,
        fingerprintHash: hashValueForLog(fingerprint),
        twilioVerificationSid: providerResponse?.sid ?? null,
        reviewBypassEligible,
        verifyAttempts: 0,
        maxVerifyAttempts: OTP_CHALLENGE_MAX_VERIFY_ATTEMPTS,
        expiresAt: Timestamp.fromMillis(Date.now() + OTP_CHALLENGE_TTL_MS),
        updatedAt: FieldValue.serverTimestamp(),
        createdAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    logInfo("requestOtpChallenge dispatched", {
      loginMethod,
      challengeId: sessionRef.id,
      phoneMasked: maskPhone(phoneE164),
      appId: request.app?.appId ?? null,
      reviewBypassEligible,
    });

    return {
      provider: "twilio",
      verificationId: sessionRef.id,
      maskedDestination: maskPhone(phoneE164),
      loginMethod,
      childIdentifier,
      memberId,
      displayName,
      expiresInSeconds: Math.floor(OTP_CHALLENGE_TTL_MS / 1000),
    };
  },
);

export const verifyOtpChallenge = onCall(
  APP_CHECK_CALLABLE_OPTIONS,
  async (request) => {
    const verificationId = requireNonEmptyString(
      request.data,
      "verificationId",
    ).trim();
    const smsCode = requireNonEmptyString(request.data, "smsCode").trim();
    if (!/^\d{4,10}$/.test(smsCode)) {
      throw new HttpsError(
        "invalid-argument",
        "The verification code is invalid.",
        { reason: "otp_invalid_code" },
      );
    }

    const sessionRef = authOtpSessionsCollection.doc(verificationId);
    const sessionSnapshot = await sessionRef.get();
    if (!sessionSnapshot.exists) {
      throw new HttpsError(
        "not-found",
        "The verification session no longer exists.",
        { reason: "verification_session_not_found" },
      );
    }
    const session = sessionSnapshot.data() as OtpChallengeSessionRecord;
    const phoneE164 = optionalTrimmedRecordString(session.phoneE164);
    if (phoneE164 == null) {
      throw new HttpsError(
        "failed-precondition",
        "The verification session has an invalid phone number.",
        { reason: "verification_session_phone_missing" },
      );
    }
    const status = (session.status ?? "pending").trim().toLowerCase();
    const expiresAtMs = session.expiresAt?.toMillis() ?? 0;
    if (expiresAtMs > 0 && expiresAtMs <= Date.now()) {
      await sessionRef.set(
        {
          status: "expired",
          failedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
          failureCode: "session_expired",
        },
        { merge: true },
      );
      throw new HttpsError(
        "not-found",
        "The verification session has expired.",
        { reason: "verification_session_not_found" },
      );
    }

    if (status === "approved") {
      const uid = optionalTrimmedRecordString(session.uid);
      if (uid == null) {
        throw new HttpsError(
          "failed-precondition",
          "The verification session is missing user context.",
          { reason: "verification_session_inactive" },
        );
      }
      const customToken = await issuePhoneCustomToken(uid, phoneE164);
      return buildOtpApprovedResponse({
        customToken,
        uid,
        phoneE164,
        session,
      });
    }
    if (status !== "pending") {
      throw new HttpsError(
        "failed-precondition",
        "The verification session is no longer active.",
        { reason: "verification_session_inactive" },
      );
    }

    await enforceOtpVerifyRateLimit({ request, session });

    const verifyAttempts = Math.max(Math.trunc(session.verifyAttempts ?? 0), 0);
    const maxVerifyAttempts = Math.max(
      Math.trunc(
        session.maxVerifyAttempts ?? OTP_CHALLENGE_MAX_VERIFY_ATTEMPTS,
      ),
      1,
    );
    if (verifyAttempts >= maxVerifyAttempts) {
      await sessionRef.set(
        {
          status: "failed",
          failedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
          failureCode: "attempt_limit",
        },
        { merge: true },
      );
      throw new HttpsError(
        "resource-exhausted",
        "Too many verification attempts. Request a new OTP and try again.",
        { reason: "otp_verify_attempt_limit" },
      );
    }

    await sessionRef.set(
      {
        verifyAttempts: FieldValue.increment(1),
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    const reviewBypassEligible =
      session.reviewBypassEligible == true &&
      shouldUseOtpReviewBypass(phoneE164);
    let isApproved = false;
    let failureReason = "";
    if (reviewBypassEligible) {
      isApproved = isOtpReviewBypassCodeValid(smsCode);
      failureReason = isApproved ? "approved" : "invalid_code";
      if (isApproved) {
        logInfo("verifyOtpChallenge review bypass approved", {
          challengeId: verificationId,
          phoneMasked: maskPhone(phoneE164),
          loginMethod: session.loginMethod ?? "phone",
        });
      }
    } else {
      ensureTwilioOtpEnabled();
      const verification = await verifyTwilioOtpCode({
        phoneE164,
        smsCode,
      });
      isApproved = verification.approved;
      failureReason = verification.status;
    }

    if (!isApproved) {
      const exhausted = verifyAttempts + 1 >= maxVerifyAttempts;
      await sessionRef.set(
        {
          status: exhausted ? "failed" : "pending",
          failedAt: exhausted ? FieldValue.serverTimestamp() : null,
          updatedAt: FieldValue.serverTimestamp(),
          failureCode: exhausted ? "attempt_limit" : "invalid_code",
          failureReason,
        },
        { merge: true },
      );
      if (exhausted) {
        await registerOtpVerifyAttemptLimit({
          request,
          session,
          phoneE164,
        });
      }
      throw new HttpsError(
        exhausted ? "resource-exhausted" : "invalid-argument",
        exhausted
          ? "Too many verification attempts. Please wait before trying again."
          : "The verification code is invalid or expired.",
        {
          reason: exhausted ? "otp_verify_attempt_limit" : "otp_invalid_code",
        },
      );
    }

    const identity = await ensurePhoneAuthIdentity({
      phoneE164,
      displayName: optionalTrimmedRecordString(session.displayName),
    });
    const customToken = await issuePhoneCustomToken(identity.uid, phoneE164);
    await usersCollection.doc(identity.uid).set(
      {
        uid: identity.uid,
        normalizedPhone: phoneE164,
        updatedAt: FieldValue.serverTimestamp(),
        createdAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
    await sessionRef.set(
      {
        status: "approved",
        approvedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
        uid: identity.uid,
        failureCode: null,
        failureReason: null,
      },
      { merge: true },
    );

    logInfo("verifyOtpChallenge approved", {
      challengeId: verificationId,
      uid: identity.uid,
      phoneMasked: maskPhone(phoneE164),
      loginMethod: session.loginMethod ?? "phone",
      isNewIdentity: identity.isNew,
    });

    return buildOtpApprovedResponse({
      customToken,
      uid: identity.uid,
      phoneE164,
      session,
    });
  },
);

export const createInvite = onCall(
  APP_CHECK_CALLABLE_OPTIONS,
  async (request) => {
    const auth = requireAuth(request);

    logInfo("createInvite requested", {
      uid: auth.uid,
      payloadKeys: extractPayloadKeys(request.data),
    });

    throw new HttpsError(
      "unimplemented",
      "createInvite is scaffolded and awaits permission checks plus invite persistence logic.",
    );
  },
);

export const claimMemberRecord = onCall(
  APP_CHECK_CALLABLE_OPTIONS,
  async (request) => {
    const auth = requireAuth(request);
    const loginMethod = requireLoginMethod(request.data);

    logInfo("claimMemberRecord requested", {
      uid: auth.uid,
      loginMethod,
    });

    const verifiedPhoneE164 = await resolveVerifiedPhoneForAuth(auth);

    if (loginMethod === "child") {
      const childIdentifier = optionalString(request.data, "childIdentifier")
        ?.trim()
        .toUpperCase();
      const providedMemberId = optionalString(request.data, "memberId")?.trim();
      const resolved =
        childIdentifier != null
          ? await findChildLoginContext(childIdentifier)
          : await findChildLoginContextByMemberId(providedMemberId);

      if (
        normalizePhoneE164(verifiedPhoneE164) !==
        normalizePhoneE164(resolved.parentPhoneE164)
      ) {
        throw new HttpsError(
          "failed-precondition",
          "The verified phone number does not match the linked parent phone.",
        );
      }

      const context = buildMemberSessionContext(
        resolved.memberId,
        resolved,
        "child",
        false,
      );
      await applySessionClaims(auth.uid, context);
      await writeAuditLog({
        uid: auth.uid,
        memberId: resolved.memberId,
        clanId: resolved.clanId,
        action: "child_access_granted",
        entityType: "member",
        entityId: resolved.memberId,
        after: {
          accessMode: context.accessMode,
          childIdentifier: resolved.childIdentifier,
        },
      });

      return context;
    }

    const explicitMemberId = optionalString(request.data, "memberId")?.trim();
    const claimedMember = await resolvePhoneClaimMember({
      uid: auth.uid,
      authPhone: verifiedPhoneE164,
      explicitMemberId,
    });

    if (claimedMember == null) {
      const context: MemberSessionContext = {
        memberId: null,
        displayName: null,
        clanId: null,
        branchId: null,
        primaryRole: null,
        accessMode: "unlinked",
        linkedAuthUid: false,
      };
      await applySessionClaims(auth.uid, context);

      logWarn("claimMemberRecord found no member match", {
        uid: auth.uid,
        maskedPhoneE164: maskPhone(verifiedPhoneE164),
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
      "claimed",
      true,
    );
    await applySessionClaims(auth.uid, context);
    await writeAuditLog({
      uid: auth.uid,
      memberId: claimedMember.memberId,
      clanId: context.clanId,
      action: didLinkAuthUid ? "member_claimed" : "member_session_refreshed",
      entityType: "member",
      entityId: claimedMember.memberId,
      after: {
        accessMode: context.accessMode,
        linkedAuthUid: context.linkedAuthUid,
        maskedPhoneE164: maskPhone(claimedMember.phoneE164),
      },
    });

    return context;
  },
);

export const resolvePhoneIdentityAfterOtp = onCall(
  APP_CHECK_CALLABLE_OPTIONS,
  async (request) => {
    const auth = requireAuth(request);
    const languageCode = resolvePreferredLanguageCode(request.data);
    const deviceToken = requireNonEmptyString(
      request.data,
      "deviceToken",
    ).trim();
    if (deviceToken.length < 16) {
      throw new HttpsError("invalid-argument", "deviceToken is invalid.");
    }
    const deviceTokenHash = hashDeviceToken(deviceToken);
    const phoneE164 = await resolveVerifiedPhoneForAuth(auth);
    const trustedDeviceActive = await isTrustedDeviceActive(
      auth.uid,
      deviceTokenHash,
    );
    let candidatesFromTrustedUnlinked: Array<MaskedMemberCandidate> | null =
      null;
    let hasSelectableCandidateFromTrustedUnlinked = false;

    const contexts = await loadLinkedClanContextsForUid(auth.uid);
    const activeContext = resolveActiveClanContext({
      contexts,
      requestedClanId: null,
      token: auth.token,
    });
    if (activeContext != null) {
      if (!trustedDeviceActive) {
        const linkedCandidate = await loadMaskedMemberCandidateById(
          activeContext.memberId,
          auth.uid,
          languageCode,
        );
        const fallbackCandidates =
          linkedCandidate == null
            ? await loadMaskedMemberCandidatesForPhone(
                phoneE164,
                auth.uid,
                languageCode,
              )
            : [];
        const candidates =
          linkedCandidate == null ? fallbackCandidates : [linkedCandidate];
        const hasSelectableCandidate = candidates.some(
          (candidate) => candidate.selectable,
        );
        await writeAuthEvent({
          uid: auth.uid,
          action: "phone_identity_step_up_required",
          phoneE164,
          memberId: activeContext.memberId,
          metadata: {
            candidateCount: candidates.length,
            trustedDevice: false,
          },
        });
        return {
          status: hasSelectableCandidate
            ? "needs_selection"
            : "create_new_only",
          trustedDevice: false,
          allowCreateNew: false,
          phoneE164,
          context: null,
          candidates,
        };
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
        accessMode: "claimed",
        linkedAuthUid: true,
      };
      await applySessionClaims(auth.uid, memberContext, {
        clanIds: orderedClanIds,
      });
      await upsertUserSessionProfile(auth.uid, memberContext, {
        clanIds: orderedClanIds,
        normalizedPhone: phoneE164,
      });
      await upsertTrustedDevice({
        uid: auth.uid,
        memberId: memberContext.memberId,
        deviceTokenHash,
        trustStatus: "active",
      });
      await writeAuthEvent({
        uid: auth.uid,
        action: "phone_identity_resolved_existing_link",
        phoneE164,
        memberId: memberContext.memberId,
        metadata: {
          activeClanId: memberContext.clanId,
          clanIds: orderedClanIds,
        },
      });
      return {
        status: "resolved",
        trustedDevice: true,
        allowCreateNew: false,
        phoneE164,
        context: serializeMemberSessionContext(memberContext),
        candidates: [] as Array<MaskedMemberCandidate>,
      };
    }

    if (trustedDeviceActive) {
      const userProfileSnapshot = await usersCollection.doc(auth.uid).get();
      if (userProfileSnapshot.exists) {
        const profile = userProfileSnapshot.data() as UserSessionProfileRecord;
        const profileMemberId = optionalTrimmedRecordString(profile.memberId);
        const profileClanId = optionalTrimmedRecordString(profile.clanId);
        const profilePhone = optionalTrimmedRecordString(
          profile.normalizedPhone,
        );
        const profileAccessMode = (profile.accessMode ?? "")
          .trim()
          .toLowerCase();
        let phoneMatches = true;
        if (profilePhone != null) {
          try {
            phoneMatches = normalizePhoneE164(profilePhone) == phoneE164;
          } catch {
            phoneMatches = false;
          }
        }
        if (
          phoneMatches &&
          profileMemberId == null &&
          profileClanId == null &&
          (profileAccessMode.length == 0 || profileAccessMode == "unlinked")
        ) {
          candidatesFromTrustedUnlinked =
            await loadMaskedMemberCandidatesForPhone(
              phoneE164,
              auth.uid,
              languageCode,
            );
          hasSelectableCandidateFromTrustedUnlinked =
            candidatesFromTrustedUnlinked.some(
              (candidate) => candidate.selectable,
            );
          if (hasSelectableCandidateFromTrustedUnlinked) {
            await writeAuthEvent({
              uid: auth.uid,
              action: "phone_identity_candidates_found_trusted_unlinked",
              phoneE164,
              memberId: null,
              metadata: {
                candidateCount: candidatesFromTrustedUnlinked.length,
                trustedDevice: true,
              },
            });
            return {
              status: "needs_selection",
              trustedDevice: true,
              allowCreateNew: true,
              phoneE164,
              context: null,
              candidates: candidatesFromTrustedUnlinked,
            };
          }
          const context: MemberSessionContext = {
            memberId: null,
            displayName: optionalString(auth.token, "name")?.trim() ?? null,
            clanId: null,
            branchId: null,
            primaryRole: "GUEST",
            accessMode: "unlinked",
            linkedAuthUid: false,
          };
          await applySessionClaims(auth.uid, context, { clanIds: [] });
          await upsertUserSessionProfile(auth.uid, context, {
            clanIds: [],
            normalizedPhone: phoneE164,
          });
          await writeAuthEvent({
            uid: auth.uid,
            action: "phone_identity_resolved_trusted_unlinked",
            phoneE164,
            memberId: null,
            metadata: {},
          });
          return {
            status: "resolved",
            trustedDevice: true,
            allowCreateNew: true,
            phoneE164,
            context: serializeMemberSessionContext(context),
            candidates: [] as Array<MaskedMemberCandidate>,
          };
        }
      }
    }

    const candidates =
      candidatesFromTrustedUnlinked ??
      (await loadMaskedMemberCandidatesForPhone(
        phoneE164,
        auth.uid,
        languageCode,
      ));
    const hasSelectableCandidate = candidates.some(
      (candidate) => candidate.selectable,
    );
    await writeAuthEvent({
      uid: auth.uid,
      action: hasSelectableCandidate
        ? "phone_identity_candidates_found"
        : "phone_identity_candidates_not_selectable",
      phoneE164,
      memberId: null,
      metadata: {
        candidateCount: candidates.length,
      },
    });

    return {
      status: hasSelectableCandidate ? "needs_selection" : "create_new_only",
      trustedDevice: false,
      allowCreateNew: true,
      phoneE164,
      context: null,
      candidates,
    };
  },
);

export const createUnlinkedPhoneIdentity = onCall(
  APP_CHECK_CALLABLE_OPTIONS,
  async (request) => {
    const auth = requireAuth(request);
    const deviceToken = requireNonEmptyString(
      request.data,
      "deviceToken",
    ).trim();
    if (deviceToken.length < 16) {
      throw new HttpsError("invalid-argument", "deviceToken is invalid.");
    }
    const deviceTokenHash = hashDeviceToken(deviceToken);
    const phoneE164 = await resolveVerifiedPhoneForAuth(auth);
    const linkedContexts = await loadLinkedClanContextsForUid(auth.uid);
    if (linkedContexts.length > 0) {
      throw new HttpsError(
        "failed-precondition",
        "This account is already linked to a member profile and cannot switch to create-new mode.",
        { reason: "member_already_linked" },
      );
    }
    const context: MemberSessionContext = {
      memberId: null,
      displayName: optionalString(auth.token, "name")?.trim() ?? null,
      clanId: null,
      branchId: null,
      primaryRole: "GUEST",
      accessMode: "unlinked",
      linkedAuthUid: false,
    };
    await applySessionClaims(auth.uid, context, { clanIds: [] });
    await upsertUserSessionProfile(auth.uid, context, {
      clanIds: [],
      normalizedPhone: phoneE164,
    });
    await upsertTrustedDevice({
      uid: auth.uid,
      memberId: null,
      deviceTokenHash,
      trustStatus: "active",
    });
    await writeAuthEvent({
      uid: auth.uid,
      action: "phone_identity_create_new_confirmed",
      phoneE164,
      memberId: null,
      metadata: {},
    });
    return {
      status: "resolved",
      trustedDevice: true,
      phoneE164,
      context: serializeMemberSessionContext(context),
    };
  },
);

export const startMemberIdentityVerification = onCall(
  APP_CHECK_CALLABLE_OPTIONS,
  async (request) => {
    const auth = requireAuth(request);
    const languageCode = resolvePreferredLanguageCode(request.data);
    const memberId = requireNonEmptyString(request.data, "memberId").trim();
    const deviceToken = requireNonEmptyString(
      request.data,
      "deviceToken",
    ).trim();
    if (deviceToken.length < 16) {
      throw new HttpsError("invalid-argument", "deviceToken is invalid.");
    }
    const deviceTokenHash = hashDeviceToken(deviceToken);
    const phoneE164 = await resolveVerifiedPhoneForAuth(auth);
    const verificationGuard = await readMemberVerificationGuard(
      auth.uid,
      memberId,
    );
    if (verificationGuard.locked) {
      await writeAuthEvent({
        uid: auth.uid,
        action: "member_identity_verification_locked",
        phoneE164,
        memberId,
        metadata: {
          lockReason: "window_attempts",
        },
      });
      throw new HttpsError(
        "failed-precondition",
        "Verification is temporarily locked. Please wait and try again.",
        { reason: "member_verification_locked" },
      );
    }
    const attemptsUsedFromWindow = Math.max(
      MEMBER_VERIFICATION_MAX_ATTEMPTS - verificationGuard.remainingAttempts,
      0,
    );
    const existingLinks = await membersCollection
      .where("authUid", "==", auth.uid)
      .limit(5)
      .get();
    if (existingLinks.docs.some((doc) => doc.id != memberId)) {
      throw new HttpsError(
        "failed-precondition",
        "This account is already linked to another member profile.",
        { reason: "member_already_linked" },
      );
    }

    const memberSnapshot = await membersCollection.doc(memberId).get();
    if (!memberSnapshot.exists) {
      throw new HttpsError(
        "not-found",
        "The selected member profile no longer exists.",
      );
    }
    const memberData = memberSnapshot.data() as MemberRecord;
    if (isMemberInactiveStatus(memberData.status)) {
      throw new HttpsError(
        "failed-precondition",
        "The selected member profile is inactive and cannot be linked automatically.",
        { reason: "member_inactive" },
      );
    }
    const currentAuthUid = optionalTrimmedRecordString(memberData.authUid);
    if (currentAuthUid != null && currentAuthUid != auth.uid) {
      throw new HttpsError(
        "already-exists",
        "This member profile is already linked to another account.",
        { reason: "member_already_linked" },
      );
    }

    const memberPhone = optionalTrimmedRecordString(memberData.phoneE164);
    if (memberPhone != null) {
      const normalizedMemberPhone = normalizePhoneE164(memberPhone);
      if (normalizedMemberPhone != phoneE164 && currentAuthUid != auth.uid) {
        throw new HttpsError(
          "failed-precondition",
          "The verified phone number does not match the selected member profile.",
          { reason: "parent_verification_mismatch" },
        );
      }
    }

    const questions = await buildMemberVerificationQuestions({
      memberId,
      memberData,
      phoneE164,
      languageCode,
    });
    if (questions.length < 3) {
      throw new HttpsError(
        "failed-precondition",
        "Verification data is not sufficient for automatic linking.",
        { reason: "member_verification_data_unavailable" },
      );
    }

    const sessionRef = memberVerificationSessionsCollection.doc();
    await sessionRef.set(
      {
        uid: auth.uid,
        memberId,
        phoneE164,
        deviceTokenHash,
        status: "pending",
        maxAttempts: MEMBER_VERIFICATION_MAX_ATTEMPTS,
        attemptsUsed: attemptsUsedFromWindow,
        questions: questions.map((question) => ({
          id: question.id,
          category: question.category,
          prompt: question.prompt,
          options: question.options,
          answerOptionId: question.answerOptionId,
        })),
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
        expiresAt: Timestamp.fromMillis(
          Date.now() + MEMBER_VERIFICATION_SESSION_TTL_MS,
        ),
      },
      { merge: true },
    );

    await writeAuthEvent({
      uid: auth.uid,
      action: "member_identity_verification_started",
      phoneE164,
      memberId,
      metadata: {
        verificationSessionId: sessionRef.id,
        questionCount: questions.length,
      },
    });

    return {
      verificationSessionId: sessionRef.id,
      memberId,
      maxAttempts: MEMBER_VERIFICATION_MAX_ATTEMPTS,
      remainingAttempts: verificationGuard.remainingAttempts,
      questionCount: questions.length,
      questions: questions.map((question) => ({
        id: question.id,
        category: question.category,
        prompt: question.prompt,
        options: question.options,
      })),
    };
  },
);

export const submitMemberIdentityVerification = onCall(
  APP_CHECK_CALLABLE_OPTIONS,
  async (request) => {
    const auth = requireAuth(request);
    const verificationSessionId = requireNonEmptyString(
      request.data,
      "verificationSessionId",
    ).trim();
    const answers = requireStringMap(request.data, "answers");
    const sessionRef = memberVerificationSessionsCollection.doc(
      verificationSessionId,
    );
    const snapshot = await sessionRef.get();
    if (!snapshot.exists) {
      throw new HttpsError("not-found", "Verification session was not found.");
    }

    const session = snapshot.data() as VerificationSessionRecord;
    if (session.uid != auth.uid) {
      throw new HttpsError(
        "permission-denied",
        "This verification session belongs to another account.",
        { reason: "member_verification_forbidden" },
      );
    }
    const expiresAtMs = session.expiresAt?.toMillis() ?? 0;
    if (expiresAtMs > 0 && expiresAtMs < Date.now()) {
      await sessionRef.set(
        {
          status: "expired",
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
      throw new HttpsError(
        "failed-precondition",
        "Verification session has expired. Please start again.",
        { reason: "member_verification_expired" },
      );
    }
    if (session.status !== "pending" && session.status !== "failed") {
      throw new HttpsError(
        "failed-precondition",
        "Verification session is no longer active.",
        { reason: "member_verification_locked" },
      );
    }
    const verificationGuard = await readMemberVerificationGuard(
      auth.uid,
      session.memberId,
    );
    if (verificationGuard.locked) {
      await sessionRef.set(
        {
          status: "locked",
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
      await writeAuthEvent({
        uid: auth.uid,
        action: "member_identity_verification_locked",
        phoneE164: session.phoneE164,
        memberId: session.memberId,
        metadata: {
          verificationSessionId,
          lockReason: "window_attempts",
        },
      });
      throw new HttpsError(
        "failed-precondition",
        "Verification is temporarily locked. Please wait and try again.",
        { reason: "member_verification_locked" },
      );
    }

    const questions = session.questions ?? [];
    if (questions.length < 3) {
      throw new HttpsError(
        "failed-precondition",
        "Verification session is invalid. Please start again.",
        { reason: "member_verification_data_unavailable" },
      );
    }
    const totalQuestions = questions.length;
    let correctAnswers = 0;
    let clanQuestionCount = 0;
    let clanCorrectAnswers = 0;
    for (const question of questions) {
      const provided = answers[question.id]?.trim() ?? "";
      const expected = question.answerOptionId.trim();
      const isCorrect = provided.length > 0 && provided == expected;
      if (isCorrect) {
        correctAnswers += 1;
      }
      if (question.category == "clan") {
        clanQuestionCount += 1;
        if (isCorrect) {
          clanCorrectAnswers += 1;
        }
      }
    }

    const requiredCorrect =
      totalQuestions >= 4
        ? MEMBER_VERIFICATION_REQUIRED_CORRECT
        : totalQuestions;
    const passed =
      correctAnswers >= requiredCorrect &&
      (clanQuestionCount == 0 || clanCorrectAnswers >= 1);

    if (!passed) {
      const attemptsUsed = (session.attemptsUsed ?? 0) + 1;
      const maxAttempts =
        session.maxAttempts ?? MEMBER_VERIFICATION_MAX_ATTEMPTS;
      const guardState = await registerMemberVerificationFailure({
        uid: auth.uid,
        memberId: session.memberId,
      });
      const lockedBySession = attemptsUsed >= maxAttempts;
      const locked = lockedBySession || guardState.locked;
      await sessionRef.set(
        {
          attemptsUsed,
          status: locked ? "locked" : "pending",
          lastScore: correctAnswers,
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
      await writeAuthEvent({
        uid: auth.uid,
        action: locked
          ? "member_identity_verification_locked"
          : "member_identity_verification_failed",
        phoneE164: session.phoneE164,
        memberId: session.memberId,
        metadata: {
          verificationSessionId,
          attemptsUsed,
          maxAttempts,
          score: correctAnswers,
          questionCount: totalQuestions,
          lockReason: lockedBySession
            ? "session_attempts"
            : guardState.locked
              ? "window_attempts"
              : null,
        },
      });

      return {
        passed: false,
        locked,
        remainingAttempts: locked
          ? 0
          : Math.max(
              Math.min(
                maxAttempts - attemptsUsed,
                guardState.remainingAttempts,
              ),
              0,
            ),
        score: correctAnswers,
        requiredCorrect,
      };
    }

    const memberRef = membersCollection.doc(session.memberId);
    const inviteRefs = await loadMatchingPhoneInviteRefs(
      session.phoneE164,
      session.memberId,
    );
    const didLinkAuthUid = await claimMemberTransaction({
      uid: auth.uid,
      memberRef,
      inviteRefs,
    });
    const memberSnapshot = await memberRef.get();
    if (!memberSnapshot.exists) {
      throw new HttpsError(
        "not-found",
        "The selected member profile no longer exists.",
      );
    }
    const memberData = memberSnapshot.data() as MemberRecord;
    const context = buildMemberSessionContext(
      memberSnapshot.id,
      memberData,
      "claimed",
      true,
    );
    await applySessionClaims(auth.uid, context);
    await upsertUserSessionProfile(auth.uid, context, {
      clanIds: context.clanId == null ? [] : [context.clanId],
      normalizedPhone: session.phoneE164,
    });
    await upsertTrustedDevice({
      uid: auth.uid,
      memberId: context.memberId,
      deviceTokenHash: session.deviceTokenHash,
      trustStatus: "active",
    });
    await clearMemberVerificationGuard({
      uid: auth.uid,
      memberId: session.memberId,
    });
    await sessionRef.set(
      {
        status: "passed",
        passedAt: FieldValue.serverTimestamp(),
        attemptsUsed: session.attemptsUsed ?? 0,
        lastScore: correctAnswers,
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    await writeAuditLog({
      uid: auth.uid,
      memberId: context.memberId,
      clanId: context.clanId,
      action: didLinkAuthUid
        ? "member_claimed_verified"
        : "member_session_refreshed",
      entityType: "member",
      entityId: context.memberId ?? memberSnapshot.id,
      after: {
        accessMode: context.accessMode,
        linkedAuthUid: context.linkedAuthUid,
        verificationSessionId,
      },
    });
    await writeAuthEvent({
      uid: auth.uid,
      action: "member_identity_verification_passed",
      phoneE164: session.phoneE164,
      memberId: session.memberId,
      metadata: {
        verificationSessionId,
        score: correctAnswers,
        questionCount: totalQuestions,
      },
    });

    return {
      passed: true,
      locked: false,
      remainingAttempts:
        (session.maxAttempts ?? MEMBER_VERIFICATION_MAX_ATTEMPTS) -
        (session.attemptsUsed ?? 0),
      score: correctAnswers,
      requiredCorrect,
      context: serializeMemberSessionContext(context),
    };
  },
);

export const lookupMemberProfileByPhone = onCall(
  APP_CHECK_CALLABLE_OPTIONS,
  async (request): Promise<LookupMemberProfileResponse> => {
    const auth = requireAuth(request);
    const role = normalizeRoleClaim(auth.token.primaryRole);
    if (!isLookupRoleAllowed(role)) {
      throw new HttpsError(
        "permission-denied",
        "This session cannot lookup member profiles across the system.",
      );
    }
    const allowCrossClanLookup = role === "SUPER_ADMIN";
    const scopedClanIds = new Set(extractTokenClanIds(auth.token));
    const activeClanId = optionalString(auth.token, "clanId")?.trim() ?? "";
    if (activeClanId.length > 0) {
      scopedClanIds.add(activeClanId);
    }
    if (!allowCrossClanLookup && scopedClanIds.size === 0) {
      throw new HttpsError(
        "permission-denied",
        "This session has no clan scope for member profile lookup.",
      );
    }

    const phoneInput = requireNonEmptyString(request.data, "phoneE164");
    const phoneE164 = normalizePhoneE164(phoneInput);
    const memberSnapshots = await loadPhoneMemberSnapshots(phoneE164);

    if (memberSnapshots.length === 0) {
      return { found: false, profile: null };
    }

    const candidate = memberSnapshots
      .map((doc) => ({ id: doc.id, data: doc.data() as MemberRecord }))
      .filter(({ data }) => {
        if (allowCrossClanLookup) {
          return true;
        }
        const candidateClanId = optionalTrimmedRecordString(data.clanId);
        return candidateClanId != null && scopedClanIds.has(candidateClanId);
      })
      .sort((left, right) => {
        const byScore =
          memberLookupScore(right.data) - memberLookupScore(left.data);
        if (byScore !== 0) {
          return byScore;
        }
        return left.id.localeCompare(right.id);
      })[0];
    if (candidate == null) {
      return { found: false, profile: null };
    }

    return {
      found: true,
      profile: {
        memberId: candidate.id,
        clanId: optionalTrimmedRecordString(candidate.data.clanId) ?? "",
        branchId: optionalTrimmedRecordString(candidate.data.branchId),
        fullName: optionalTrimmedRecordString(candidate.data.fullName) ?? "",
        nickName: optionalTrimmedRecordString(candidate.data.nickName) ?? "",
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
          facebook: optionalTrimmedRecordString(
            candidate.data.socialLinks?.facebook,
          ),
          zalo: optionalTrimmedRecordString(candidate.data.socialLinks?.zalo),
          linkedin: optionalTrimmedRecordString(
            candidate.data.socialLinks?.linkedin,
          ),
        },
      },
    };
  },
);

export const bootstrapClanWorkspace = onCall(
  APP_CHECK_CALLABLE_OPTIONS,
  async (request) => {
    const auth = requireAuth(request);
    const tokenClanIds = extractTokenClanIds(auth.token);
    const allowExistingClan =
      request.data != null &&
      typeof request.data === "object" &&
      (request.data as Record<string, unknown>).allowExistingClan === true;
    if (tokenClanIds.length > 0 && !allowExistingClan) {
      throw new HttpsError(
        "failed-precondition",
        "This account is already linked to a clan.",
      );
    }
    const activeClanIdFromToken =
      optionalString(auth.token, "activeClanId")?.trim() ??
      optionalString(auth.token, "clanId")?.trim() ??
      null;
    const activeMemberIdFromToken =
      optionalString(auth.token, "memberId")?.trim() ?? null;
    const activeBranchIdFromToken =
      optionalString(auth.token, "branchId")?.trim() ?? null;
    const activeRoleFromToken = normalizeRoleClaim(
      optionalString(auth.token, "primaryRole"),
    );
    const activeDisplayNameFromToken =
      optionalString(auth.token, "name")?.trim() ?? null;
    const keepExistingActiveContext =
      allowExistingClan &&
      tokenClanIds.length > 0 &&
      activeClanIdFromToken != null &&
      activeClanIdFromToken.length > 0 &&
      activeMemberIdFromToken != null &&
      activeMemberIdFromToken.length > 0;

    const role = normalizeRoleClaim(auth.token.primaryRole);
    const clanName = requireNonEmptyString(request.data, "name");
    const requestedSlug = optionalString(request.data, "slug");
    const slug = normalizeSlug(requestedSlug ?? clanName);
    const duplicateOverride =
      request.data != null &&
      typeof request.data === "object" &&
      (request.data as Record<string, unknown>).duplicateOverride === true;
    const provinceCityHint = optionalString(request.data, "provinceCity") ?? "";
    if (slug.length < 3) {
      throw new HttpsError(
        "invalid-argument",
        "slug must contain at least 3 alphanumeric characters.",
      );
    }

    const existingSlug = await clansCollection
      .where("slug", "==", slug)
      .limit(1)
      .get();
    if (!existingSlug.empty) {
      throw new HttpsError(
        "already-exists",
        "That clan slug is already in use. Please choose another slug.",
      );
    }

    const description = optionalString(request.data, "description") ?? "";
    const countryCode = normalizeCountryCode(
      optionalString(request.data, "countryCode"),
    );
    const founderName = normalizeFounderName(request, clanName);
    const logoUrl = optionalString(request.data, "logoUrl") ?? "";
    const ownerDisplayName =
      founderName.length > 0
        ? founderName
        : deriveFallbackDisplayName(auth.uid);
    const ownerRole = resolveOwnerRole(role);
    const ownerPhone = optionalString(auth.token, "phone_number");
    const normalizedFullName = ownerDisplayName.trim().toLowerCase();
    let duplicateCandidates: Array<{
      clanId: string;
      genealogyName: string;
      leaderName: string;
      provinceCity: string;
      score: number;
    }> = [];
    if (allowExistingClan) {
      try {
        duplicateCandidates = await findPotentialDuplicateGenealogies({
          genealogyName: clanName,
          leaderName: ownerDisplayName,
          provinceCity: provinceCityHint,
        });
      } catch (error) {
        logWarn(
          "bootstrapClanWorkspace duplicate check failed; continue without block",
          {
            uid: auth.uid,
            clanName,
            errorMessage:
              error instanceof Error ? error.message : String(error),
          },
        );
      }
    }
    if (duplicateCandidates.length > 0 && !duplicateOverride) {
      await writeAuditLog({
        uid: auth.uid,
        memberId: activeMemberIdFromToken,
        clanId: activeClanIdFromToken,
        action: "clan_workspace_duplicate_blocked",
        entityType: "clan",
        entityId: "bootstrap",
        after: {
          requestedName: clanName,
          requestedFounderName: ownerDisplayName,
          requestedProvinceCity: provinceCityHint,
          candidateCount: duplicateCandidates.length,
          candidateIds: duplicateCandidates.map(
            (candidate) => candidate.clanId,
          ),
        },
      });

      throw new HttpsError(
        "already-exists",
        "Potential duplicate genealogy detected. Review candidates before creating a new clan.",
        {
          reason: "potential_duplicate_genealogy",
          candidates: duplicateCandidates,
        },
      );
    }
    if (duplicateCandidates.length > 0 && duplicateOverride) {
      await writeAuditLog({
        uid: auth.uid,
        memberId: activeMemberIdFromToken,
        clanId: activeClanIdFromToken,
        action: "clan_workspace_duplicate_override",
        entityType: "clan",
        entityId: "bootstrap",
        after: {
          requestedName: clanName,
          requestedFounderName: ownerDisplayName,
          requestedProvinceCity: provinceCityHint,
          candidateCount: duplicateCandidates.length,
          candidateIds: duplicateCandidates.map(
            (candidate) => candidate.clanId,
          ),
        },
      });
    }

    const clanRef = clansCollection.doc();
    const branchRef = branchesCollection.doc();
    const memberRef = membersCollection.doc();
    const userRef = usersCollection.doc(auth.uid);
    const discoveryRef = genealogyDiscoveryCollection.doc(clanRef.id);
    const clanIdsAfterCreate = [
      activeClanIdFromToken,
      ...tokenClanIds,
      clanRef.id,
    ]
      .filter((entry): entry is string => typeof entry === "string")
      .map((entry) => entry.trim())
      .filter(
        (entry, index, source) =>
          entry.length > 0 && source.indexOf(entry) === index,
      );
    const now = FieldValue.serverTimestamp();

    await db.runTransaction(async (transaction) => {
      transaction.set(
        clanRef,
        {
          id: clanRef.id,
          name: clanName,
          slug,
          description,
          countryCode,
          founderName,
          logoUrl,
          status: "active",
          memberCount: 1,
          branchCount: 1,
          ownerUid: auth.uid,
          createdAt: now,
          createdBy: auth.uid,
          updatedAt: now,
          updatedBy: auth.uid,
        },
        { merge: true },
      );

      transaction.set(
        branchRef,
        {
          id: branchRef.id,
          clanId: clanRef.id,
          name: "Main Branch",
          code: "MAIN",
          leaderMemberId: memberRef.id,
          viceLeaderMemberId: null,
          generationLevelHint: 1,
          status: "active",
          memberCount: 1,
          createdAt: now,
          createdBy: auth.uid,
          updatedAt: now,
          updatedBy: auth.uid,
        },
        { merge: true },
      );

      transaction.set(
        memberRef,
        {
          id: memberRef.id,
          clanId: clanRef.id,
          branchId: branchRef.id,
          fullName: ownerDisplayName,
          normalizedFullName,
          nickName: "",
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
          status: "active",
          isMinor: false,
          authUid: auth.uid,
          claimedAt: now,
          createdAt: now,
          createdBy: auth.uid,
          updatedAt: now,
          updatedBy: auth.uid,
        },
        { merge: true },
      );

      transaction.set(
        userRef,
        {
          uid: auth.uid,
          memberId: keepExistingActiveContext
            ? activeMemberIdFromToken
            : memberRef.id,
          clanId: keepExistingActiveContext
            ? activeClanIdFromToken
            : clanRef.id,
          clanIds: clanIdsAfterCreate,
          branchId: keepExistingActiveContext
            ? (activeBranchIdFromToken ?? "")
            : branchRef.id,
          primaryRole: keepExistingActiveContext
            ? activeRoleFromToken || ownerRole
            : ownerRole,
          accessMode: "claimed",
          linkedAuthUid: true,
          updatedAt: now,
          createdAt: now,
        },
        { merge: true },
      );

      transaction.set(
        discoveryRef,
        {
          id: clanRef.id,
          clanId: clanRef.id,
          genealogyName: clanName,
          genealogyNameNormalized: normalizeSearch(clanName),
          leaderName: ownerDisplayName,
          leaderNameNormalized: normalizeSearch(ownerDisplayName),
          provinceCity: provinceCityHint,
          provinceCityNormalized: normalizeSearch(provinceCityHint),
          summary: description,
          memberCount: 1,
          branchCount: 1,
          isPublic: false,
          createdAt: now,
          updatedAt: now,
        },
        { merge: true },
      );
    });

    const context: MemberSessionContext = keepExistingActiveContext
      ? {
          memberId: activeMemberIdFromToken,
          displayName: activeDisplayNameFromToken ?? ownerDisplayName,
          clanId: activeClanIdFromToken,
          branchId: activeBranchIdFromToken,
          primaryRole: activeRoleFromToken || ownerRole,
          accessMode: "claimed",
          linkedAuthUid: true,
        }
      : {
          memberId: memberRef.id,
          displayName: ownerDisplayName,
          clanId: clanRef.id,
          branchId: branchRef.id,
          primaryRole: ownerRole,
          accessMode: "claimed",
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
        ? "clan_workspace_created_additional"
        : "clan_workspace_bootstrapped",
      entityType: "clan",
      entityId: clanRef.id,
      after: {
        branchId: branchRef.id,
        memberId: memberRef.id,
        primaryRole: ownerRole,
        createdAsAdditional: keepExistingActiveContext,
      },
    });

    logInfo("bootstrapClanWorkspace succeeded", {
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
      accessMode: "claimed",
      activeClanId: context.clanId,
      switchedActiveClan: context.clanId === clanRef.id,
      clanIds: clanIdsAfterCreate,
    };
  },
);

export const registerDeviceToken = onCall(
  APP_CHECK_CALLABLE_OPTIONS,
  async (request) => {
    const auth = requireAuth(request);
    const token = requireNonEmptyString(request.data, "token").trim();
    if (token.length > 4096) {
      throw new HttpsError("invalid-argument", "token is too long.");
    }

    const requestPlatform = optionalString(request.data, "platform")
      ?.trim()
      .toLowerCase();
    const platform =
      requestPlatform != null && requestPlatform.length > 0
        ? requestPlatform.slice(0, 32)
        : "unknown";

    const memberIdFromClaim =
      typeof auth.token.memberId === "string" ? auth.token.memberId.trim() : "";
    const branchIdFromClaim =
      typeof auth.token.branchId === "string" ? auth.token.branchId.trim() : "";
    const roleFromClaim =
      typeof auth.token.primaryRole === "string"
        ? auth.token.primaryRole.trim()
        : "";
    const claimClanIdsRaw = Array.isArray(auth.token.clanIds)
      ? auth.token.clanIds
      : [];
    const claimClanIds = claimClanIdsRaw
      .filter((value): value is string => typeof value === "string")
      .map((value) => value.trim())
      .filter((value) => value.length > 0);

    const fallbackMemberId =
      optionalString(request.data, "memberId")?.trim() ?? "";
    const fallbackBranchId =
      optionalString(request.data, "branchId")?.trim() ?? "";
    const fallbackClanId = optionalString(request.data, "clanId")?.trim() ?? "";
    const fallbackAccessMode =
      optionalString(request.data, "accessMode")?.trim() ?? "";

    const memberId =
      memberIdFromClaim.length > 0 ? memberIdFromClaim : fallbackMemberId;
    const branchId =
      branchIdFromClaim.length > 0 ? branchIdFromClaim : fallbackBranchId;
    const clanId = claimClanIds.length > 0 ? claimClanIds[0] : fallbackClanId;
    const accessMode =
      typeof auth.token.memberAccessMode === "string"
        ? auth.token.memberAccessMode.trim()
        : fallbackAccessMode;

    logInfo("registerDeviceToken requested", {
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
      .collection("users")
      .doc(auth.uid)
      .collection("deviceTokens")
      .doc(token)
      .set(
        {
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
        },
        { merge: true },
      );

    return {
      status: "registered",
      token,
    };
  },
);

// Intentionally skips App Check so QA and debug builds can verify
// real-device push delivery even when App Check is not wired yet.
export const sendSelfTestNotification = onCall(
  SELF_TEST_NOTIFICATION_CALLABLE_OPTIONS,
  async (request) => {
    const auth = requireAuth(request);
    const delaySeconds = readSelfTestDelaySeconds(request.data);
    const title = sanitizeSelfTestText(
      optionalString(request.data, "title"),
      "BeFam test notification",
      120,
    );
    const body = sanitizeSelfTestText(
      optionalString(request.data, "body"),
      "Tap to open BeFam and verify notification delivery on this device.",
      240,
    );
    const targetId = `self_test_${Date.now()}`;
    const resolvedContext = await resolveSelfTestMemberContext({
      uid: auth.uid,
      memberId: optionalString(request.data, "memberId"),
      clanId: optionalString(request.data, "clanId"),
      authToken: auth.token as Record<string, unknown>,
    });

    const tokenSnapshot = await db
      .collection("users")
      .doc(auth.uid)
      .collection("deviceTokens")
      .limit(20)
      .get();

    const tokenDocs = tokenSnapshot.docs
      .map((doc) => {
        const token =
          optionalString(doc.data(), "token")?.trim() ?? doc.id.trim();
        if (token.length === 0) {
          return null;
        }
        return { documentId: doc.id, token };
      })
      .filter(
        (value): value is { documentId: string; token: string } =>
          value != null,
      );

    if (tokenDocs.length === 0) {
      throw new HttpsError(
        "failed-precondition",
        "No registered device token was found for this user.",
      );
    }

    if (delaySeconds > 0) {
      await sleepForMillis(delaySeconds * 1000);
    }

    const response = await getMessaging().sendEachForMulticast({
      tokens: tokenDocs.map((record) => record.token),
      notification: {
        title,
        body,
      },
      data: {
        target: "billing",
        id: targetId,
        type: "self_test_notification",
        source: "self_test_notification",
      },
      android: {
        priority: "high",
      },
      apns: {
        headers: {
          "apns-priority": "10",
        },
        payload: {
          aps: {
            sound: "default",
          },
        },
      },
    });

    const invalidTokenDeletes: Array<Promise<unknown>> = [];
    for (let index = 0; index < response.responses.length; index += 1) {
      const sendResponse = response.responses[index];
      if (sendResponse.success) {
        continue;
      }
      const errorCode = sendResponse.error?.code ?? "";
      if (!SELF_TEST_NOTIFICATION_INVALID_TOKEN_CODES.has(errorCode)) {
        continue;
      }
      const tokenDoc = tokenDocs[index];
      invalidTokenDeletes.push(
        db
          .collection("users")
          .doc(auth.uid)
          .collection("deviceTokens")
          .doc(tokenDoc.documentId)
          .delete()
          .catch(() => null),
      );
    }
    await Promise.all(invalidTokenDeletes);

    let notificationId: string | null = null;
    if (
      response.successCount > 0 &&
      resolvedContext.memberId != null &&
      resolvedContext.clanId != null
    ) {
      const notificationRef = db.collection("notifications").doc();
      await notificationRef.set({
        id: notificationRef.id,
        memberId: resolvedContext.memberId,
        clanId: resolvedContext.clanId,
        type: "self_test_notification",
        title,
        body,
        data: {
          target: "billing",
          id: targetId,
          source: "self_test_notification",
        },
        isRead: false,
        sentAt: FieldValue.serverTimestamp(),
        createdAt: FieldValue.serverTimestamp(),
      });
      notificationId = notificationRef.id;
    }

    logInfo("sendSelfTestNotification completed", {
      uid: auth.uid,
      tokenCount: tokenDocs.length,
      sentCount: response.successCount,
      failedCount: response.failureCount,
      delaySeconds,
      memberId: resolvedContext.memberId,
      clanId: resolvedContext.clanId,
      notificationId,
      appId: request.app?.appId ?? null,
    });

    return {
      tokenCount: tokenDocs.length,
      sentCount: response.successCount,
      failedCount: response.failureCount,
      delaySeconds,
      notificationId,
    };
  },
);

export const sendSelfTestEventReminder = onCall(
  SELF_TEST_NOTIFICATION_CALLABLE_OPTIONS,
  async (request) => {
    const auth = requireAuth(request);
    const delaySeconds = readSelfTestDelaySeconds(request.data);
    const title = sanitizeSelfTestText(
      optionalString(request.data, "title"),
      "Sự kiện thử từ BeFam",
      120,
    );
    const description = sanitizeSelfTestText(
      optionalString(request.data, "body"),
      "BeFam sẽ nhắc bạn mở lại app để kiểm tra event reminder trên máy thật.",
      240,
    );
    const resolvedContext = await resolveSelfTestMemberContext({
      uid: auth.uid,
      memberId: optionalString(request.data, "memberId"),
      clanId: optionalString(request.data, "clanId"),
      authToken: auth.token as Record<string, unknown>,
    });

    if (resolvedContext.memberId == null || resolvedContext.clanId == null) {
      throw new HttpsError(
        "failed-precondition",
        "Event reminder self-test requires an active clan member context.",
      );
    }

    const memberSnapshot = await db
      .collection("members")
      .doc(resolvedContext.memberId)
      .get();
    if (!memberSnapshot.exists) {
      throw new HttpsError(
        "failed-precondition",
        "Active member record was not found for this event reminder test.",
      );
    }

    const memberData = memberSnapshot.data() as MemberRecord | undefined;
    const branchId = optionalString(memberData, "branchId")?.trim() ?? "";
    const visibility = branchId.length > 0 ? "branch" : "clan";
    const reminderAt = new Date(Date.now() + delaySeconds * 1000);
    const startsAt = new Date(reminderAt.getTime() + 60 * 1000);
    const endsAt = new Date(startsAt.getTime() + 30 * 60 * 1000);
    const eventId = `self_test_event_${Date.now()}`;
    const reminderOffsetMinutes = 1;
    const dispatchId = buildSelfTestEventReminderDispatchId({
      eventId,
      reminderAt,
      offsetMinutes: reminderOffsetMinutes,
    });

    await db
      .collection("events")
      .doc(eventId)
      .set({
        id: eventId,
        clanId: resolvedContext.clanId,
        branchId: branchId.length > 0 ? branchId : null,
        title,
        description,
        eventType: "other",
        targetMemberId: null,
        locationName: "BeFam QA",
        locationAddress: "",
        startsAt: Timestamp.fromDate(startsAt),
        endsAt: Timestamp.fromDate(endsAt),
        timezone: "UTC",
        isRecurring: false,
        recurrenceRule: null,
        reminderOffsetsMinutes: [reminderOffsetMinutes],
        visibility,
        status: "scheduled",
        ritualKey: null,
        ritualPreset: null,
        isAutoGenerated: true,
        nextReminderAt: Timestamp.fromDate(reminderAt),
        nextReminderOffsetMinutes: reminderOffsetMinutes,
        nextReminderOccurrenceStartsAt: Timestamp.fromDate(startsAt),
        reminderCursorVersion: 1,
        reminderCursorUpdatedAt: FieldValue.serverTimestamp(),
        reminderCursorSource: "callable:sendSelfTestEventReminder",
        createdAt: FieldValue.serverTimestamp(),
        createdBy: auth.uid,
        updatedAt: FieldValue.serverTimestamp(),
        updatedBy: auth.uid,
      });

    if (delaySeconds > 0) {
      await sleepForMillis(delaySeconds * 1000);
    }

    const reminderRun = await sendEventReminderRun({
      source: "callable:sendSelfTestEventReminder",
      now: new Date(),
    });
    const dispatchSnapshot = await db
      .collection("eventReminderDispatches")
      .doc(dispatchId)
      .get();
    const dispatchData = dispatchSnapshot.data() as
      | Record<string, unknown>
      | undefined;
    const dispatchStatus = optionalString(dispatchData, "status")?.trim() ?? "";

    logInfo("sendSelfTestEventReminder completed", {
      uid: auth.uid,
      memberId: resolvedContext.memberId,
      clanId: resolvedContext.clanId,
      eventId,
      delaySeconds,
      dispatchId,
      dispatchStatus: dispatchStatus || null,
      ...reminderRun,
      appId: request.app?.appId ?? null,
    });

    return {
      eventId,
      delaySeconds,
      sentCount: dispatchStatus === "sent" ? 1 : 0,
      dispatchStatus,
      remindersSent: reminderRun.remindersSent,
    };
  },
);

export const listUserClanContexts = onCall(
  APP_CHECK_CALLABLE_OPTIONS,
  async (request) => {
    const auth = requireAuth(request);
    const contexts = await loadLinkedClanContextsForUid(auth.uid);
    const activeContext = resolveActiveClanContext({
      contexts,
      requestedClanId: null,
      token: auth.token,
    });

    return {
      accessMode: contexts.length > 0 ? "claimed" : "unlinked",
      activeClanId: activeContext?.clanId ?? null,
      contexts: contexts.map(serializeLinkedClanContext),
    };
  },
);

export const switchActiveClanContext = onCall(
  APP_CHECK_CALLABLE_OPTIONS,
  async (request) => {
    const auth = requireAuth(request);
    const requestedClanId = requireNonEmptyString(request.data, "clanId");
    const contexts = await loadLinkedClanContextsForUid(auth.uid);
    if (contexts.length == 0) {
      throw new HttpsError(
        "failed-precondition",
        "This account is not linked to any clan membership yet.",
      );
    }

    const requestedContext = contexts.find(
      (context) => context.clanId == requestedClanId,
    );
    if (requestedContext == null) {
      throw new HttpsError(
        "permission-denied",
        "The requested clan is not linked to this account.",
      );
    }
    if (!isActiveClanContext(requestedContext)) {
      throw new HttpsError(
        "failed-precondition",
        "The requested clan is currently inactive. Contact the clan owner to reactivate billing.",
      );
    }
    const activeContext = requestedContext;

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
      accessMode: "claimed",
      linkedAuthUid: true,
    };

    await applySessionClaims(auth.uid, memberContext, {
      clanIds: orderedClanIds,
    });

    await usersCollection.doc(auth.uid).set(
      {
        uid: auth.uid,
        memberId: activeContext.memberId,
        clanId: activeContext.clanId,
        clanIds: orderedClanIds,
        branchId: activeContext.branchId ?? "",
        primaryRole: activeContext.primaryRole,
        accessMode: "claimed",
        linkedAuthUid: true,
        updatedAt: FieldValue.serverTimestamp(),
        createdAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    await writeAuditLog({
      uid: auth.uid,
      memberId: activeContext.memberId,
      clanId: activeContext.clanId,
      action: "active_clan_context_switched",
      entityType: "clan",
      entityId: activeContext.clanId,
      after: {
        clanId: activeContext.clanId,
        memberId: activeContext.memberId,
        primaryRole: activeContext.primaryRole,
        clanIds: orderedClanIds,
      },
    });

    return {
      accessMode: "claimed",
      activeClanId: activeContext.clanId,
      activeContext: serializeLinkedClanContext(activeContext),
      contexts: contexts.map(serializeLinkedClanContext),
    };
  },
);

function requireNonEmptyString(data: unknown, key: string): string {
  const value = optionalString(data, key)?.trim();
  if (value == null || value.length === 0) {
    throw new HttpsError("invalid-argument", `${key} is required.`);
  }

  return value;
}

function normalizePhoneE164(input: string): string {
  const trimmed = input.trim();
  const digitsAndPlus = trimmed.replace(/[^0-9+]/g, "");
  if (digitsAndPlus.length === 0) {
    throw new HttpsError("invalid-argument", "phoneE164 has invalid format.");
  }
  const digitsOnly = digitsAndPlus.replace(/[^0-9]/g, "");
  let normalized = "";

  if (digitsAndPlus.startsWith("+")) {
    normalized = `+${digitsAndPlus.slice(1).replace(/[^0-9]/g, "")}`;
  } else if (digitsAndPlus.startsWith("00")) {
    normalized = `+${digitsAndPlus.slice(2).replace(/[^0-9]/g, "")}`;
  } else if (digitsOnly.startsWith("0")) {
    normalized = `+84${digitsOnly.slice(1)}`;
  } else if (looksLikeInternationalPhoneDigits(digitsOnly, "84")) {
    normalized = `+${digitsOnly}`;
  } else {
    normalized = `+84${digitsOnly}`;
  }

  if (normalized.startsWith("+840")) {
    normalized = `+84${normalized.slice(4)}`;
  }
  if (
    normalized.startsWith("+84") &&
    normalized.length > 3 &&
    normalized[3] === "0"
  ) {
    normalized = `+84${normalized.slice(4)}`;
  }

  if (!/^\+[1-9]\d{8,14}$/.test(normalized)) {
    throw new HttpsError("invalid-argument", "phoneE164 has invalid format.");
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
  if (
    digits.startsWith(fallbackDialCode) &&
    digits.length > fallbackDialCode.length + 6
  ) {
    return true;
  }
  const matchedDialCode = findPhoneDialCodePrefix(digits);
  if (matchedDialCode == null) {
    return false;
  }
  return digits.length > matchedDialCode.length + 6;
}

function findPhoneDialCodePrefix(digits: string): string | null {
  for (const dialCode of SUPPORTED_PHONE_DIAL_CODES) {
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
  const digits = phoneE164.startsWith("+") ? phoneE164.slice(1) : phoneE164;
  const dialCode = findPhoneDialCodePrefix(digits);
  if (dialCode == null) {
    return null;
  }
  const nationalDigits = digits.slice(dialCode.length);
  if (nationalDigits.length === 0) {
    return null;
  }
  return { dialCode, nationalDigits };
}

function optionalTrimmedRecordString(value: unknown): string | null {
  if (typeof value !== "string") {
    return null;
  }
  const normalized = value.trim();
  return normalized.length > 0 ? normalized : null;
}

function isLookupRoleAllowed(role: string): boolean {
  return (
    role === "SUPER_ADMIN" ||
    role === "CLAN_ADMIN" ||
    role === "CLAN_OWNER" ||
    role === "CLAN_LEADER" ||
    role === "BRANCH_ADMIN" ||
    role === "ADMIN_SUPPORT"
  );
}

function memberLookupScore(member: MemberRecord): number {
  let score = 0;
  if ((member.status ?? "").toLowerCase() === "active") {
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
  if (data == null || typeof data !== "object") {
    return null;
  }

  const value = (data as Record<string, unknown>)[key];
  return typeof value === "string" ? value : null;
}

async function resolveVerifiedPhoneForAuth(
  auth: NonNullable<CallableRequest<unknown>["auth"]>,
): Promise<string> {
  const tokenPhoneCandidates = [
    optionalString(auth.token, "phone_number"),
    optionalString(auth.token, "phoneE164Verified"),
    optionalString(auth.token, "phoneE164"),
    optionalString(auth.token, "phone_e164"),
    optionalString(auth.token, "normalizedPhone"),
  ]
    .map((value) => value?.trim() ?? "")
    .filter((value) => value.length > 0);

  for (const candidate of tokenPhoneCandidates) {
    try {
      return normalizePhoneE164(candidate);
    } catch {
      // Continue with the next candidate.
    }
  }

  const userSnapshot = await usersCollection.doc(auth.uid).get();
  if (userSnapshot.exists) {
    const userData = userSnapshot.data() as UserSessionProfileRecord;
    const profilePhone = optionalTrimmedRecordString(userData.normalizedPhone);
    if (profilePhone != null) {
      try {
        return normalizePhoneE164(profilePhone);
      } catch {
        // Continue with Auth user fallback.
      }
    }
  }

  try {
    const authUser = await getAuth().getUser(auth.uid);
    const authPhone = optionalTrimmedRecordString(authUser.phoneNumber);
    if (authPhone != null) {
      return normalizePhoneE164(authPhone);
    }
  } catch {
    // Ignore and throw canonical precondition below.
  }

  throw new HttpsError(
    "failed-precondition",
    "A verified phone number is required before continuing.",
    { reason: "verified_phone_missing" },
  );
}

function asNullableTrimmedString(value: unknown): string | null {
  if (typeof value !== "string") {
    return null;
  }
  const normalized = value.trim();
  return normalized.length > 0 ? normalized : null;
}

function resolveMemberDisplayName(member: MemberRecord): string | null {
  const fullName = member.fullName?.trim() ?? "";
  if (fullName.length > 0) {
    return fullName;
  }
  const nickName = member.nickName?.trim() ?? "";
  if (nickName.length > 0) {
    return nickName;
  }
  return null;
}

function normalizeRoleClaim(value: unknown): string {
  if (typeof value !== "string") {
    return "";
  }
  return value.trim().toUpperCase();
}

function extractTokenClanIds(token: unknown): Array<string> {
  if (token == null || typeof token !== "object") {
    return [];
  }
  const raw = (token as Record<string, unknown>).clanIds;
  if (!Array.isArray(raw)) {
    return [];
  }
  return raw
    .filter((entry): entry is string => typeof entry === "string")
    .map((entry) => entry.trim())
    .filter((entry) => entry.length > 0);
}

function normalizeSlug(value: string): string {
  return value
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");
}

function normalizeSearch(value: string): string {
  return value.trim().toLowerCase().replace(/\s+/g, " ");
}

async function findPotentialDuplicateGenealogies(input: {
  genealogyName: string;
  leaderName: string;
  provinceCity: string;
}): Promise<
  Array<{
    clanId: string;
    genealogyName: string;
    leaderName: string;
    provinceCity: string;
    score: number;
  }>
> {
  const name = normalizeDiscoveryText(input.genealogyName);
  const leader = normalizeDiscoveryText(input.leaderName);
  const location = normalizeDiscoveryText(input.provinceCity);
  if (name.length === 0 || leader.length === 0) {
    return [];
  }

  const candidatesById = new Map<string, DocumentSnapshot>();
  const lookupQueries = [
    genealogyDiscoveryCollection
      .where("isPublic", "==", true)
      .where("genealogyNameNormalized", "==", name)
      .limit(80)
      .get(),
    genealogyDiscoveryCollection
      .where("isPublic", "==", true)
      .where("leaderNameNormalized", "==", leader)
      .limit(80)
      .get(),
    ...(location.length > 0
      ? [
          genealogyDiscoveryCollection
            .where("isPublic", "==", true)
            .where("provinceCityNormalized", "==", location)
            .limit(80)
            .get(),
        ]
      : []),
  ];
  const snapshots = await Promise.all(lookupQueries);
  for (const snapshot of snapshots) {
    for (const doc of snapshot.docs) {
      candidatesById.set(doc.id, doc);
    }
  }
  if (candidatesById.size < 40) {
    const fallbackSnapshot = await genealogyDiscoveryCollection
      .where("isPublic", "==", true)
      .limit(120)
      .get();
    for (const doc of fallbackSnapshot.docs) {
      if (candidatesById.size >= 180) {
        break;
      }
      candidatesById.set(doc.id, doc);
    }
  }

  return [...candidatesById.values()]
    .map((doc) => ({ id: doc.id, ...(doc.data() as DiscoveryIndexRecord) }))
    .map((entry) => ({
      clanId: optionalTrimmedRecordString(entry.clanId) ?? entry.id,
      genealogyName:
        optionalTrimmedRecordString(entry.genealogyName) ?? "Unnamed genealogy",
      leaderName:
        optionalTrimmedRecordString(entry.leaderName) ?? "Unknown leader",
      provinceCity: optionalTrimmedRecordString(entry.provinceCity) ?? "",
      score: duplicateScore(
        {
          genealogyName: normalizeDiscoveryText(
            optionalTrimmedRecordString(entry.genealogyNameNormalized) ??
              optionalTrimmedRecordString(entry.genealogyName) ??
              "",
          ),
          leaderName: normalizeDiscoveryText(
            optionalTrimmedRecordString(entry.leaderNameNormalized) ??
              optionalTrimmedRecordString(entry.leaderName) ??
              "",
          ),
          provinceCity: normalizeDiscoveryText(
            optionalTrimmedRecordString(entry.provinceCityNormalized) ??
              optionalTrimmedRecordString(entry.provinceCity) ??
              "",
          ),
        },
        {
          genealogyName: name,
          leaderName: leader,
          provinceCity: location,
        },
      ),
    }))
    .filter((candidate) => candidate.score >= 55)
    .sort((left, right) => right.score - left.score)
    .slice(0, 10);
}

function duplicateScore(
  entry: {
    genealogyName: string;
    leaderName: string;
    provinceCity: string;
  },
  input: {
    genealogyName: string;
    leaderName: string;
    provinceCity: string;
  },
): number {
  let score = 0;
  if (entry.genealogyName === input.genealogyName) {
    score += 60;
  } else if (
    entry.genealogyName.includes(input.genealogyName) ||
    input.genealogyName.includes(entry.genealogyName)
  ) {
    score += 40;
  } else {
    score += overlapTokenScore(entry.genealogyName, input.genealogyName, 32);
  }

  if (entry.leaderName === input.leaderName) {
    score += 25;
  } else if (
    entry.leaderName.includes(input.leaderName) ||
    input.leaderName.includes(entry.leaderName)
  ) {
    score += 15;
  }

  if (entry.provinceCity.length > 0 && input.provinceCity.length > 0) {
    if (entry.provinceCity === input.provinceCity) {
      score += 20;
    } else if (
      entry.provinceCity.includes(input.provinceCity) ||
      input.provinceCity.includes(entry.provinceCity)
    ) {
      score += 10;
    }
  }
  return score;
}

function overlapTokenScore(
  left: string,
  right: string,
  maxScore: number,
): number {
  const leftTokens = new Set(left.split(" ").filter(Boolean));
  const rightTokens = new Set(right.split(" ").filter(Boolean));
  if (leftTokens.size === 0 || rightTokens.size === 0) {
    return 0;
  }
  let overlap = 0;
  for (const token of leftTokens) {
    if (rightTokens.has(token)) {
      overlap += 1;
    }
  }
  const ratio = overlap / Math.max(leftTokens.size, rightTokens.size);
  return Math.round(ratio * maxScore);
}

function normalizeDiscoveryText(value: string): string {
  return (value ?? "")
    .toLowerCase()
    .trim()
    .replace(/[àáạảãăằắặẳẵâầấậẩẫ]/g, "a")
    .replace(/[èéẹẻẽêềếệểễ]/g, "e")
    .replace(/[ìíịỉĩ]/g, "i")
    .replace(/[òóọỏõôồốộổỗơờớợởỡ]/g, "o")
    .replace(/[ùúụủũưừứựửữ]/g, "u")
    .replace(/[ỳýỵỷỹ]/g, "y")
    .replace(/đ/g, "d")
    .replace(/\s+/g, " ");
}

function normalizeCountryCode(value: string | null): string {
  const normalized = (value ?? "VN").trim().toUpperCase();
  if (normalized.length < 2 || normalized.length > 3) {
    return "VN";
  }
  return normalized;
}

function normalizeFounderName(
  request: CallableRequest<unknown>,
  fallbackName: string,
): string {
  const fromRequest = optionalString(request.data, "founderName");
  if (fromRequest != null && fromRequest.trim().length > 0) {
    return fromRequest.trim();
  }

  const fromToken = optionalString(request.auth?.token, "name");
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
  if (
    role === "SUPER_ADMIN" ||
    role === "CLAN_ADMIN" ||
    role === "ADMIN_SUPPORT"
  ) {
    return role;
  }
  if (role === "CLAN_OWNER" || role === "CLAN_LEADER") {
    return "CLAN_OWNER";
  }
  return "CLAN_OWNER";
}

function requireLoginMethod(data: unknown): LoginMethod {
  const loginMethod = optionalString(data, "loginMethod");
  if (loginMethod === "phone" || loginMethod === "child") {
    return loginMethod;
  }

  throw new HttpsError(
    "invalid-argument",
    'loginMethod must be either "phone" or "child".',
  );
}

function maskPhone(phoneE164: string): string {
  if (phoneE164.trim().length === 0) {
    return "";
  }
  const visiblePrefix = phoneE164.startsWith("+84")
    ? "+84"
    : phoneE164.slice(0, 2);
  const visibleSuffix = phoneE164.slice(-2);
  const hiddenLength = Math.max(
    phoneE164.length - visiblePrefix.length - visibleSuffix.length,
    4,
  );
  return `${visiblePrefix}${"*".repeat(hiddenLength)}${visibleSuffix}`;
}

function hashValueForLog(value: string): string {
  return createHash("sha256").update(value).digest("hex").slice(0, 16);
}

function hashDeviceToken(deviceToken: string): string {
  return createHash("sha256").update(deviceToken).digest("hex");
}

function requireStringMap(data: unknown, key: string): Record<string, string> {
  if (data == null || typeof data !== "object") {
    throw new HttpsError("invalid-argument", `${key} must be an object.`);
  }
  const value = (data as Record<string, unknown>)[key];
  if (value == null || typeof value !== "object") {
    throw new HttpsError("invalid-argument", `${key} must be an object.`);
  }
  const output: Record<string, string> = {};
  for (const [entryKey, entryValue] of Object.entries(
    value as Record<string, unknown>,
  )) {
    if (typeof entryValue !== "string") {
      continue;
    }
    const normalizedKey = entryKey.trim();
    const normalizedValue = entryValue.trim();
    if (normalizedKey.length == 0 || normalizedValue.length == 0) {
      continue;
    }
    output[normalizedKey] = normalizedValue;
  }
  return output;
}

function extractPayloadKeys(data: unknown): Array<string> {
  if (data == null || typeof data !== "object") {
    return [];
  }
  return Object.keys(data as Record<string, unknown>).sort();
}

function readLockCount(value: unknown): number {
  if (typeof value !== "number" || !Number.isFinite(value)) {
    return 0;
  }
  return Math.max(Math.trunc(value), 0);
}

function readMillisValue(value: unknown): number {
  if (typeof value === "number" && Number.isFinite(value)) {
    return Math.max(Math.trunc(value), 0);
  }
  if (value instanceof Timestamp) {
    return Math.max(value.toMillis(), 0);
  }
  if (value instanceof Date) {
    return Math.max(value.getTime(), 0);
  }
  if (
    typeof value === "object" &&
    value != null &&
    "toMillis" in value &&
    typeof (value as { toMillis?: unknown }).toMillis === "function"
  ) {
    try {
      return Math.max(
        Math.trunc((value as { toMillis: () => number }).toMillis()),
        0,
      );
    } catch {
      return 0;
    }
  }
  return 0;
}

function resolveEscalatingLock(input: {
  existingLockCount: unknown;
  lastLockedAtMs: number;
  nowMs: number;
}): {
  durationMs: number;
  lockCount: number;
  lockedUntilMs: number;
} {
  const previousLockCount =
    input.lastLockedAtMs > 0 &&
    input.nowMs - input.lastLockedAtMs <= AUTH_ABUSE_LOCK_RESET_WINDOW_MS
      ? readLockCount(input.existingLockCount)
      : 0;
  const lockCount = previousLockCount + 1;
  const durationMs =
    AUTH_ABUSE_LOCK_DURATIONS_MS[
      Math.min(lockCount, AUTH_ABUSE_LOCK_DURATIONS_MS.length) - 1
    ];
  return {
    durationMs,
    lockCount,
    lockedUntilMs: input.nowMs + durationMs,
  };
}

async function enforceChildLookupRateLimit(
  request: CallableRequest<unknown>,
  childIdentifier: string,
): Promise<void> {
  const nowMs = Date.now();
  const currentWindowStartMs = nowMs - (nowMs % CHILD_LOOKUP_WINDOW_MS);
  const fingerprint = resolveChildLookupFingerprint(request);
  const docId = `child_lookup_${hashValueForLog(fingerprint)}`;
  const rateLimitRef = authRateLimitsCollection.doc(docId);

  await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(rateLimitRef);
    const existing = snapshot.data() as
      | {
          windowStartMs?: number | null;
          requestCount?: number | null;
        }
      | undefined;

    const existingWindowStartMs =
      typeof existing?.windowStartMs === "number"
        ? Math.trunc(existing.windowStartMs)
        : null;
    const existingRequestCount =
      typeof existing?.requestCount === "number"
        ? Math.trunc(existing.requestCount)
        : 0;

    const isCurrentWindow = existingWindowStartMs === currentWindowStartMs;
    const nextCount = isCurrentWindow ? existingRequestCount + 1 : 1;
    if (isCurrentWindow && existingRequestCount >= CHILD_LOOKUP_MAX_REQUESTS) {
      logWarn("resolveChildLoginContext rate limit exceeded", {
        childIdentifierHash: hashValueForLog(childIdentifier),
        fingerprint: hashValueForLog(fingerprint),
        appId: request.app?.appId ?? null,
      });
      throw new HttpsError(
        "resource-exhausted",
        "Too many lookup attempts. Please wait a few minutes and try again.",
      );
    }

    transaction.set(
      rateLimitRef,
      {
        id: docId,
        type: "child_lookup",
        fingerprintHash: hashValueForLog(fingerprint),
        windowStartMs: currentWindowStartMs,
        requestCount: nextCount,
        sampleChildIdentifierHash: hashValueForLog(childIdentifier),
        updatedAt: FieldValue.serverTimestamp(),
        expiresAt: Timestamp.fromMillis(nowMs + CHILD_LOOKUP_WINDOW_MS * 2),
      },
      { merge: true },
    );
  });
}

function ensureTwilioOtpEnabled(): void {
  if (OTP_PROVIDER !== "twilio") {
    throw new HttpsError(
      "unimplemented",
      "Server-side OTP provider is not enabled for this environment.",
      { reason: "otp_provider_unavailable" },
    );
  }
  if (
    OTP_TWILIO_ACCOUNT_SID.length === 0 ||
    OTP_TWILIO_VERIFY_SERVICE_SID.length === 0 ||
    getOtpTwilioAuthToken().length === 0
  ) {
    throw new HttpsError(
      "failed-precondition",
      "Twilio OTP provider is not configured.",
      { reason: "otp_provider_misconfigured" },
    );
  }
}

function shouldUseOtpReviewBypass(phoneE164: string): boolean {
  if (!OTP_REVIEW_BYPASS_ENABLED) {
    return false;
  }
  if (OTP_REVIEW_BYPASS_PHONE_SET.size === 0) {
    return false;
  }
  return OTP_REVIEW_BYPASS_PHONE_SET.has(normalizePhoneE164(phoneE164));
}

function isOtpReviewBypassCodeValid(smsCode: string): boolean {
  if (!OTP_REVIEW_BYPASS_ENABLED) {
    return false;
  }
  const expectedCode = getOtpReviewBypassCode().trim();
  if (expectedCode.length === 0) {
    logWarn(
      "OTP review bypass is enabled but OTP_REVIEW_BYPASS_CODE is empty.",
    );
    return false;
  }
  return smsCode.trim() === expectedCode;
}

function buildOtpReviewBypassPhoneSet(): Set<string> {
  const normalizedPhones = new Set<string>();
  for (const rawPhone of OTP_REVIEW_BYPASS_PHONES) {
    const trimmed = rawPhone.trim();
    if (trimmed.length === 0) {
      continue;
    }
    try {
      normalizedPhones.add(normalizePhoneE164(trimmed));
    } catch {
      logWarn("Ignoring invalid OTP_REVIEW_BYPASS_PHONES entry.", {
        phoneHash: hashValueForLog(trimmed),
      });
    }
  }
  return normalizedPhones;
}

function assertOtpDialCodeAllowed(phoneE164: string): void {
  const allowedDialCodes = OTP_ALLOWED_DIAL_CODES.map((value) =>
    value.replace(/[^0-9]/g, ""),
  ).filter((value) => value.length > 0);
  if (allowedDialCodes.length === 0) {
    return;
  }
  const split = splitPhoneCountryAndNational(phoneE164);
  const dialCode = split?.dialCode ?? null;
  if (dialCode == null || !allowedDialCodes.includes(dialCode)) {
    throw new HttpsError(
      "failed-precondition",
      "OTP delivery is not enabled for this destination country.",
      { reason: "otp_country_not_allowed" },
    );
  }
}

async function enforceOtpRequestRateLimit(
  request: CallableRequest<unknown>,
  phoneE164: string,
): Promise<void> {
  const nowMs = Date.now();
  const currentWindowStartMs = nowMs - (nowMs % OTP_REQUEST_WINDOW_MS);
  const fingerprint = resolveOtpRequestFingerprint(request, phoneE164);
  const docId = `otp_request_${hashValueForLog(fingerprint)}`;
  const rateLimitRef = authRateLimitsCollection.doc(docId);

  await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(rateLimitRef);
    const existing = snapshot.data() as
      | {
          windowStartMs?: number | null;
          requestCount?: number | null;
          lockCount?: number | null;
          lastLockedAtMs?: number | null;
          lockedUntilMs?: number | null;
        }
      | undefined;
    const lockedUntilMs = readMillisValue(existing?.lockedUntilMs);
    if (lockedUntilMs > nowMs) {
      throw new HttpsError(
        "resource-exhausted",
        "Too many OTP requests. Please wait before trying again.",
        { reason: "otp_request_rate_limited" },
      );
    }
    const existingWindowStartMs =
      typeof existing?.windowStartMs === "number"
        ? Math.trunc(existing.windowStartMs)
        : null;
    const existingRequestCount =
      typeof existing?.requestCount === "number"
        ? Math.trunc(existing.requestCount)
        : 0;
    const isCurrentWindow = existingWindowStartMs === currentWindowStartMs;
    const nextCount = isCurrentWindow ? existingRequestCount + 1 : 1;
    if (isCurrentWindow && existingRequestCount >= OTP_REQUEST_MAX_REQUESTS) {
      const nextLock = resolveEscalatingLock({
        existingLockCount: existing?.lockCount,
        lastLockedAtMs: readMillisValue(existing?.lastLockedAtMs),
        nowMs,
      });
      transaction.set(
        rateLimitRef,
        {
          id: docId,
          type: "otp_request",
          fingerprintHash: hashValueForLog(fingerprint),
          phoneHash: hashValueForLog(phoneE164),
          windowStartMs: currentWindowStartMs,
          requestCount: existingRequestCount,
          lockCount: nextLock.lockCount,
          lastLockedAtMs: nowMs,
          lockedUntilMs: nextLock.lockedUntilMs,
          updatedAt: FieldValue.serverTimestamp(),
          expiresAt: Timestamp.fromMillis(
            nextLock.lockedUntilMs + OTP_REQUEST_WINDOW_MS,
          ),
        },
        { merge: true },
      );
      throw new HttpsError(
        "resource-exhausted",
        "Too many OTP requests. Please wait before trying again.",
        { reason: "otp_request_rate_limited" },
      );
    }

    transaction.set(
      rateLimitRef,
      {
        id: docId,
        type: "otp_request",
        fingerprintHash: hashValueForLog(fingerprint),
        phoneHash: hashValueForLog(phoneE164),
        windowStartMs: currentWindowStartMs,
        requestCount: nextCount,
        updatedAt: FieldValue.serverTimestamp(),
        expiresAt: Timestamp.fromMillis(nowMs + OTP_REQUEST_WINDOW_MS * 2),
      },
      { merge: true },
    );
  });
}

function resolveOtpRequestFingerprint(
  request: CallableRequest<unknown>,
  phoneE164: string,
): string {
  return `${resolveChildLookupFingerprint(request)}|phone:${hashValueForLog(phoneE164)}`;
}

function resolveOtpVerifyFingerprintHash(
  request: CallableRequest<unknown>,
  session: OtpChallengeSessionRecord,
): string {
  return (
    optionalTrimmedRecordString(session.fingerprintHash) ??
    hashValueForLog(resolveChildLookupFingerprint(request))
  );
}

async function enforceOtpVerifyRateLimit(input: {
  request: CallableRequest<unknown>;
  session: OtpChallengeSessionRecord;
}): Promise<void> {
  const fingerprintHash = resolveOtpVerifyFingerprintHash(
    input.request,
    input.session,
  );
  const snapshot = await authRateLimitsCollection
    .doc(`otp_verify_${fingerprintHash}`)
    .get();
  const lockedUntilMs = readMillisValue(snapshot.data()?.lockedUntilMs);
  if (lockedUntilMs > Date.now()) {
    throw new HttpsError(
      "resource-exhausted",
      "Too many verification attempts. Please wait before trying again.",
      { reason: "otp_verify_attempt_limit" },
    );
  }
}

async function registerOtpVerifyAttemptLimit(input: {
  request: CallableRequest<unknown>;
  session: OtpChallengeSessionRecord;
  phoneE164: string;
}): Promise<void> {
  const nowMs = Date.now();
  const fingerprintHash = resolveOtpVerifyFingerprintHash(
    input.request,
    input.session,
  );
  const rateLimitRef = authRateLimitsCollection.doc(
    `otp_verify_${fingerprintHash}`,
  );

  await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(rateLimitRef);
    const existing = snapshot.data() as
      | {
          lockCount?: number | null;
          lastLockedAtMs?: number | null;
        }
      | undefined;
    const nextLock = resolveEscalatingLock({
      existingLockCount: existing?.lockCount,
      lastLockedAtMs: readMillisValue(existing?.lastLockedAtMs),
      nowMs,
    });
    transaction.set(
      rateLimitRef,
      {
        id: `otp_verify_${fingerprintHash}`,
        type: "otp_verify",
        fingerprintHash,
        phoneHash: hashValueForLog(input.phoneE164),
        lockCount: nextLock.lockCount,
        lastLockedAtMs: nowMs,
        lockedUntilMs: nextLock.lockedUntilMs,
        updatedAt: FieldValue.serverTimestamp(),
        expiresAt: Timestamp.fromMillis(
          nextLock.lockedUntilMs + OTP_CHALLENGE_TTL_MS,
        ),
      },
      { merge: true },
    );
  });
}

async function requestTwilioOtp(input: {
  phoneE164: string;
  languageCode: SupportedLanguageCode;
}): Promise<{ sid: string; status: string }> {
  const payload = new URLSearchParams({
    To: input.phoneE164,
    Channel: "sms",
    Locale: input.languageCode == "en" ? "en" : "vi",
  });
  const response = await callTwilioVerifyApi("/Verifications", payload);
  const sid = readTwilioResponseString(response, "sid");
  const status = readTwilioResponseString(response, "status");
  if (sid.length === 0) {
    throw new HttpsError(
      "unavailable",
      "OTP provider did not return a verification identifier.",
      { reason: "otp_provider_unavailable" },
    );
  }
  return { sid, status };
}

async function verifyTwilioOtpCode(input: {
  phoneE164: string;
  smsCode: string;
}): Promise<{ approved: boolean; status: string }> {
  const payload = new URLSearchParams({
    To: input.phoneE164,
    Code: input.smsCode,
  });
  const response = await callTwilioVerifyApi("/VerificationCheck", payload);
  const status = readTwilioResponseString(response, "status").toLowerCase();
  return {
    approved: status === "approved",
    status,
  };
}

async function callTwilioVerifyApi(
  path: string,
  payload: URLSearchParams,
): Promise<Record<string, unknown>> {
  const servicePath = `/v2/Services/${encodeURIComponent(OTP_TWILIO_VERIFY_SERVICE_SID)}${path}`;
  const endpoint = `https://verify.twilio.com${servicePath}`;
  const authToken = getOtpTwilioAuthToken();
  const authHeader = Buffer.from(
    `${OTP_TWILIO_ACCOUNT_SID}:${authToken}`,
    "utf8",
  ).toString("base64");
  const maxRetries = Math.max(0, OTP_TWILIO_MAX_RETRIES);
  const maxAttempts = maxRetries + 1;
  let attempt = 0;
  while (attempt < maxAttempts) {
    attempt += 1;
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), OTP_TWILIO_TIMEOUT_MS);
    try {
      const response = await fetch(endpoint, {
        method: "POST",
        headers: {
          authorization: `Basic ${authHeader}`,
          "content-type": "application/x-www-form-urlencoded",
        },
        body: payload.toString(),
        signal: controller.signal,
      });
      const body = await parseTwilioJsonBody(response);
      if (response.ok) {
        return body;
      }
      const retryable = response.status >= 500 || response.status === 429;
      if (retryable && attempt < maxAttempts) {
        const sleepMs = Math.min(
          OTP_TWILIO_BACKOFF_MS * Math.pow(2, attempt - 1),
          10000,
        );
        await waitMs(sleepMs);
        continue;
      }
      throw mapTwilioHttpError(response.status, body);
    } catch (error) {
      const retryable = isRetryableTwilioNetworkError(error);
      if (retryable && attempt < maxAttempts) {
        const sleepMs = Math.min(
          OTP_TWILIO_BACKOFF_MS * Math.pow(2, attempt - 1),
          10000,
        );
        await waitMs(sleepMs);
        continue;
      }
      if (error instanceof HttpsError) {
        throw error;
      }
      throw new HttpsError(
        retryable ? "unavailable" : "internal",
        retryable
          ? "OTP provider is temporarily unavailable. Please retry."
          : "OTP provider request failed.",
        {
          reason: retryable ? "otp_provider_unavailable" : "otp_provider_error",
        },
      );
    } finally {
      clearTimeout(timeout);
    }
  }
  throw new HttpsError(
    "unavailable",
    "OTP provider is temporarily unavailable. Please retry.",
    { reason: "otp_provider_unavailable" },
  );
}

function readTwilioResponseString(
  data: Record<string, unknown>,
  key: string,
): string {
  const value = data[key];
  if (typeof value !== "string") {
    return "";
  }
  return value.trim();
}

async function parseTwilioJsonBody(
  response: Response,
): Promise<Record<string, unknown>> {
  const contentType = response.headers.get("content-type") ?? "";
  if (!contentType.toLowerCase().includes("application/json")) {
    const rawText = await response.text();
    return {
      rawText: rawText.slice(0, 500),
    };
  }
  try {
    const parsed = await response.json();
    if (parsed != null && typeof parsed === "object") {
      return parsed as Record<string, unknown>;
    }
  } catch {
    // Ignore parse failures and return empty payload.
  }
  return {};
}

function mapTwilioHttpError(
  status: number,
  body: Record<string, unknown>,
): HttpsError {
  const providerCode =
    typeof body.code === "number" ? Math.trunc(body.code) : null;
  const providerMessage =
    typeof body.message === "string" ? body.message.trim().slice(0, 240) : "";
  if (status === 400 || status === 404) {
    if (providerCode === 60200 || providerCode === 20404) {
      return new HttpsError(
        "invalid-argument",
        "The verification code is invalid or expired.",
        { reason: "otp_invalid_code" },
      );
    }
    return new HttpsError(
      "invalid-argument",
      "The phone number or verification payload is invalid.",
      {
        reason: "otp_invalid_payload",
        providerCode,
      },
    );
  }
  if (status === 401 || status === 403) {
    return new HttpsError(
      "failed-precondition",
      "OTP provider credentials are invalid or missing permissions.",
      { reason: "otp_provider_auth_failed" },
    );
  }
  if (status === 429) {
    return new HttpsError(
      "resource-exhausted",
      "Too many OTP attempts. Please try again later.",
      { reason: "otp_request_rate_limited" },
    );
  }
  if (status >= 500) {
    return new HttpsError(
      "unavailable",
      "OTP provider is temporarily unavailable.",
      { reason: "otp_provider_unavailable" },
    );
  }
  return new HttpsError(
    "internal",
    providerMessage.length > 0
      ? `OTP provider error: ${providerMessage}`
      : "OTP provider error.",
    {
      reason: "otp_provider_error",
      providerCode,
    },
  );
}

function isRetryableTwilioNetworkError(error: unknown): boolean {
  const message = `${error ?? ""}`.toLowerCase();
  return (
    message.includes("abort") ||
    message.includes("timeout") ||
    message.includes("timed out") ||
    message.includes("econnreset") ||
    message.includes("ecconnreset") ||
    message.includes("econnrefused") ||
    message.includes("enotfound") ||
    message.includes("eai_again") ||
    message.includes("network")
  );
}

function waitMs(ms: number): Promise<void> {
  return new Promise((resolve) => {
    setTimeout(resolve, ms);
  });
}

function phoneIdentityDocId(phoneE164: string): string {
  return createHash("sha256").update(phoneE164).digest("hex");
}

async function ensurePhoneAuthIdentity(input: {
  phoneE164: string;
  displayName: string | null;
}): Promise<{ uid: string; isNew: boolean }> {
  const phoneE164 = normalizePhoneE164(input.phoneE164);
  const docId = phoneIdentityDocId(phoneE164);
  const identityRef = phoneAuthIdentitiesCollection.doc(docId);
  const identitySnapshot = await identityRef.get();
  const mappedUid = optionalTrimmedRecordString(identitySnapshot.data()?.uid);
  const authAdmin = getAuth();

  if (mappedUid != null) {
    try {
      await syncAuthUserPhoneProfile({
        uid: mappedUid,
        phoneE164,
        displayName: input.displayName,
      });
      await writePhoneAuthIdentity(identityRef, phoneE164, mappedUid);
      return { uid: mappedUid, isNew: false };
    } catch {
      // Continue with fallback resolution when mapped UID is stale.
    }
  }

  const existingByPhoneUid = await findAuthUidByPhone(phoneE164);
  if (existingByPhoneUid != null) {
    await syncAuthUserPhoneProfile({
      uid: existingByPhoneUid,
      phoneE164,
      displayName: input.displayName,
    });
    await writePhoneAuthIdentity(identityRef, phoneE164, existingByPhoneUid);
    return { uid: existingByPhoneUid, isNew: false };
  }

  const deterministicUid = `phone_${createHash("sha256")
    .update(phoneE164)
    .digest("hex")
    .slice(0, 28)}`;
  let created = false;
  try {
    await authAdmin.createUser({
      uid: deterministicUid,
      phoneNumber: phoneE164,
      displayName: input.displayName ?? undefined,
    });
    created = true;
  } catch (error) {
    const code = resolveAuthAdminErrorCode(error);
    if (code === "uid-already-exists") {
      created = false;
    } else if (code === "phone-number-already-exists") {
      const existingUid = await findAuthUidByPhone(phoneE164);
      if (existingUid == null) {
        throw error;
      }
      await syncAuthUserPhoneProfile({
        uid: existingUid,
        phoneE164,
        displayName: input.displayName,
      });
      await writePhoneAuthIdentity(identityRef, phoneE164, existingUid);
      return { uid: existingUid, isNew: false };
    } else {
      throw error;
    }
  }

  await syncAuthUserPhoneProfile({
    uid: deterministicUid,
    phoneE164,
    displayName: input.displayName,
  });
  await writePhoneAuthIdentity(identityRef, phoneE164, deterministicUid);
  return { uid: deterministicUid, isNew: created };
}

async function findAuthUidByPhone(phoneE164: string): Promise<string | null> {
  const authAdmin = getAuth();
  try {
    const user = await authAdmin.getUserByPhoneNumber(phoneE164);
    return user.uid;
  } catch (error) {
    const code = resolveAuthAdminErrorCode(error);
    if (code === "user-not-found") {
      return null;
    }
    throw error;
  }
}

async function syncAuthUserPhoneProfile(input: {
  uid: string;
  phoneE164: string;
  displayName: string | null;
}): Promise<void> {
  const authAdmin = getAuth();
  const user = await authAdmin.getUser(input.uid);
  const updates: {
    phoneNumber?: string;
    displayName?: string;
  } = {};
  if (user.phoneNumber !== input.phoneE164) {
    updates.phoneNumber = input.phoneE164;
  }
  const desiredDisplayName = input.displayName?.trim() ?? "";
  if (
    desiredDisplayName.length > 0 &&
    (user.displayName ?? "").trim().length === 0
  ) {
    updates.displayName = desiredDisplayName;
  }
  if (Object.keys(updates).length > 0) {
    await authAdmin.updateUser(input.uid, updates);
  }
}

async function writePhoneAuthIdentity(
  identityRef: DocumentReference,
  phoneE164: string,
  uid: string,
): Promise<void> {
  await identityRef.set(
    {
      id: identityRef.id,
      provider: "twilio",
      phoneE164,
      uid,
      lastVerifiedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
      createdAt: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
}

function resolveAuthAdminErrorCode(error: unknown): string {
  if (error == null || typeof error !== "object") {
    return "";
  }
  const source = error as { code?: unknown };
  if (typeof source.code !== "string") {
    return "";
  }
  const code = source.code.trim().toLowerCase();
  if (code.startsWith("auth/")) {
    return code.slice(5);
  }
  return code;
}

async function issuePhoneCustomToken(
  uid: string,
  phoneE164: string,
): Promise<string> {
  const authAdmin = getAuth();
  const user = await authAdmin.getUser(uid);
  const existingClaims = user.customClaims ?? {};
  const nextClaims = {
    ...existingClaims,
    phoneE164Verified: phoneE164,
  };
  await authAdmin.setCustomUserClaims(uid, nextClaims);
  return authAdmin.createCustomToken(uid, {
    phoneE164Verified: phoneE164,
  });
}

function buildOtpApprovedResponse(input: {
  customToken: string;
  uid: string;
  phoneE164: string;
  session: OtpChallengeSessionRecord;
}) {
  const loginMethod = input.session.loginMethod === "child" ? "child" : "phone";
  return {
    status: "approved",
    provider: "twilio",
    customToken: input.customToken,
    uid: input.uid,
    phoneE164: input.phoneE164,
    loginMethod,
    childIdentifier: optionalTrimmedRecordString(input.session.childIdentifier),
    memberId: optionalTrimmedRecordString(input.session.memberId),
    displayName: optionalTrimmedRecordString(input.session.displayName),
  };
}

function resolveChildLookupFingerprint(
  request: CallableRequest<unknown>,
): string {
  const appId = request.app?.appId?.trim();
  const rawRequest = request.rawRequest as
    | {
        ip?: string;
        headers?: { [key: string]: unknown };
      }
    | undefined;
  const ipFromRequest = rawRequest?.ip?.trim();
  const xForwardedFor =
    rawRequest?.headers != null &&
    typeof rawRequest.headers["x-forwarded-for"] === "string"
      ? rawRequest.headers["x-forwarded-for"].trim()
      : "";
  const ip =
    ipFromRequest && ipFromRequest.length > 0
      ? ipFromRequest
      : xForwardedFor.split(",")[0]?.trim();

  if (appId != null && appId.length > 0 && ip != null && ip.length > 0) {
    return `app:${appId}|ip:${ip}`;
  }
  if (appId != null && appId.length > 0) {
    return `app:${appId}`;
  }
  if (ip != null && ip.length > 0) {
    return `ip:${ip}`;
  }
  return "anonymous";
}

function inviteIsActive(invite: InviteRecord): boolean {
  const status = invite.status ?? "pending";
  if (!["pending", "active"].includes(status)) {
    return false;
  }

  if (invite.expiresAt == null) {
    return true;
  }

  return invite.expiresAt.toMillis() >= Date.now();
}

async function findChildLoginContext(
  childIdentifier: string,
): Promise<InternalResolvedChildLoginContext> {
  const inviteSnapshot = await invitesCollection
    .where("childIdentifier", "==", childIdentifier)
    .limit(5)
    .get();

  const inviteDoc = inviteSnapshot.docs.find((doc) =>
    inviteIsActive(doc.data() as InviteRecord),
  );
  if (inviteDoc != null) {
    const invite = inviteDoc.data() as InviteRecord;
    const parentPhoneE164 = invite.phoneE164?.trim();
    const memberId = invite.memberId?.trim();
    if (
      parentPhoneE164 == null ||
      parentPhoneE164.length === 0 ||
      memberId == null ||
      memberId.length === 0
    ) {
      throw new HttpsError(
        "failed-precondition",
        "This child identifier is not fully linked to a parent phone and member profile yet.",
      );
    }

    const memberSnapshot = await membersCollection.doc(memberId).get();
    if (!memberSnapshot.exists) {
      throw new HttpsError(
        "not-found",
        "The child member profile could not be found.",
      );
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
      return buildResolvedChildContext(
        childIdentifier,
        phoneE164,
        memberSnapshot,
      );
    }
  }

  throw new HttpsError(
    "not-found",
    "No child login context matches that identifier.",
  );
}

async function findChildLoginContextByMemberId(
  memberId: string | null | undefined,
): Promise<InternalResolvedChildLoginContext> {
  if (memberId == null || memberId.length === 0) {
    throw new HttpsError(
      "invalid-argument",
      "memberId is required when childIdentifier is not provided.",
    );
  }

  const memberSnapshot = await membersCollection.doc(memberId).get();
  if (!memberSnapshot.exists) {
    throw new HttpsError(
      "not-found",
      "The child member profile could not be found.",
    );
  }

  const inviteSnapshot = await invitesCollection
    .where("memberId", "==", memberId)
    .limit(5)
    .get();
  const inviteDoc = inviteSnapshot.docs.find((doc) => {
    const invite = doc.data() as InviteRecord;
    return (
      inviteIsActive(invite) &&
      typeof invite.childIdentifier === "string" &&
      invite.childIdentifier.trim().length > 0
    );
  });
  if (inviteDoc == null) {
    throw new HttpsError(
      "failed-precondition",
      "This child member record is not linked to a parent OTP flow yet.",
    );
  }

  const invite = inviteDoc.data() as InviteRecord;
  const phoneE164 = invite.phoneE164?.trim();
  const childIdentifier = invite.childIdentifier?.trim().toUpperCase();
  if (
    phoneE164 == null ||
    phoneE164.length === 0 ||
    childIdentifier == null ||
    childIdentifier.length === 0
  ) {
    throw new HttpsError(
      "failed-precondition",
      "This child member record is not linked to a parent OTP flow yet.",
    );
  }

  return buildResolvedChildContext(childIdentifier, phoneE164, memberSnapshot);
}

function buildResolvedChildContext(
  childIdentifier: string,
  parentPhoneE164: string,
  memberSnapshot: DocumentSnapshot,
): InternalResolvedChildLoginContext {
  const memberId = memberSnapshot.id;
  const member = memberSnapshot.data() as MemberRecord | undefined;
  if (member == null || member.clanId == null || member.branchId == null) {
    throw new HttpsError(
      "failed-precondition",
      "The child member record is missing clan or branch context.",
    );
  }

  return {
    childIdentifier,
    parentPhoneE164,
    maskedDestination: maskPhone(parentPhoneE164),
    memberId,
    displayName: member.fullName ?? member.nickName ?? "BeFam Member",
    clanId: member.clanId,
    branchId: member.branchId,
    primaryRole: member.primaryRole ?? "MEMBER",
  };
}

function buildPhoneLookupVariants(phoneE164: string): Array<string> {
  const normalized = normalizePhoneE164(phoneE164);
  const variants = new Set<string>([normalized]);
  const digitsOnly = normalized.startsWith("+")
    ? normalized.slice(1)
    : normalized;
  variants.add(digitsOnly);
  const split = splitPhoneCountryAndNational(normalized);
  if (split != null) {
    variants.add(split.nationalDigits);
    if (!split.nationalDigits.startsWith("0")) {
      variants.add(`0${split.nationalDigits}`);
    }
    variants.add(`${split.dialCode}${split.nationalDigits}`);
    variants.add(`+${split.dialCode}${split.nationalDigits}`);
  }
  return [...variants].filter((entry) => entry.trim().length > 0);
}

async function loadPhoneMemberSnapshots(
  phoneE164: string,
): Promise<Array<DocumentSnapshot>> {
  const variants = buildPhoneLookupVariants(phoneE164);
  const byId = new Map<string, DocumentSnapshot>();
  for (const variant of variants) {
    const snapshot = await membersCollection
      .where("phoneE164", "==", variant)
      .limit(10)
      .get();
    for (const doc of snapshot.docs) {
      byId.set(doc.id, doc);
    }
  }
  return [...byId.values()];
}

async function loadPhoneInviteSnapshots(
  phoneE164: string,
): Promise<Array<DocumentSnapshot>> {
  const variants = buildPhoneLookupVariants(phoneE164);
  const byId = new Map<string, DocumentSnapshot>();
  for (const variant of variants) {
    const snapshot = await invitesCollection
      .where("phoneE164", "==", variant)
      .limit(20)
      .get();
    for (const doc of snapshot.docs) {
      byId.set(doc.id, doc);
    }
  }
  return [...byId.values()];
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
      "failed-precondition",
      "A verified phone number is required before a member record can be claimed.",
    );
  }
  const normalizedAuthPhone = normalizePhoneE164(authPhone);

  if (explicitMemberId != null && explicitMemberId.length > 0) {
    const explicitSnapshot = await membersCollection
      .doc(explicitMemberId)
      .get();
    if (!explicitSnapshot.exists) {
      throw new HttpsError(
        "not-found",
        "The requested member profile does not exist.",
      );
    }

    const member = explicitSnapshot.data() as MemberRecord;
    if (member.phoneE164 != null && member.phoneE164.length > 0) {
      const memberPhone = normalizePhoneE164(member.phoneE164);
      if (memberPhone != normalizedAuthPhone) {
        throw new HttpsError(
          "failed-precondition",
          "The verified phone number does not match the selected member profile.",
        );
      }
    }

    return {
      memberId: explicitSnapshot.id,
      memberData: member,
      phoneE164: normalizedAuthPhone,
    };
  }

  const inviteSnapshots = await loadPhoneInviteSnapshots(normalizedAuthPhone);
  const phoneInvite = inviteSnapshots.find((doc) => {
    const invite = doc.data() as InviteRecord;
    return (
      inviteIsActive(invite) &&
      invite.inviteType === "phone_claim" &&
      typeof invite.memberId === "string" &&
      invite.memberId.trim().length > 0
    );
  });
  if (phoneInvite != null) {
    const invite = phoneInvite.data() as InviteRecord;
    const memberSnapshot = await membersCollection
      .doc(invite.memberId as string)
      .get();
    if (memberSnapshot.exists) {
      return {
        memberId: memberSnapshot.id,
        memberData: memberSnapshot.data() as MemberRecord,
        phoneE164: normalizedAuthPhone,
      };
    }
  }

  const memberDocs = await loadPhoneMemberSnapshots(normalizedAuthPhone);
  if (memberDocs.length === 0) {
    return null;
  }

  if (memberDocs.length === 1) {
    return {
      memberId: memberDocs[0].id,
      memberData: memberDocs[0].data() as MemberRecord,
      phoneE164: normalizedAuthPhone,
    };
  }

  const currentLink = memberDocs.find(
    (doc) => (doc.data() as MemberRecord).authUid === uid,
  );
  if (currentLink != null) {
    return {
      memberId: currentLink.id,
      memberData: currentLink.data() as MemberRecord,
      phoneE164: normalizedAuthPhone,
    };
  }

  throw new HttpsError(
    "failed-precondition",
    "Multiple member profiles share this phone number. Please contact a clan administrator.",
  );
}

async function loadMatchingPhoneInviteRefs(
  phoneE164: string,
  memberId: string,
): Promise<Array<DocumentReference>> {
  const snapshots = await loadPhoneInviteSnapshots(phoneE164);
  return snapshots
    .filter((doc) => {
      const invite = doc.data() as InviteRecord;
      return inviteIsActive(invite) && invite.memberId === memberId;
    })
    .map((doc) => doc.ref);
}

async function loadMaskedMemberCandidatesForPhone(
  phoneE164: string,
  uid: string,
  languageCode: SupportedLanguageCode,
): Promise<Array<MaskedMemberCandidate>> {
  const memberDocs = await loadPhoneMemberSnapshots(phoneE164);
  if (memberDocs.length === 0) {
    return [];
  }

  const clanIds = [
    ...new Set(
      memberDocs
        .map((doc) =>
          optionalTrimmedRecordString((doc.data() as MemberRecord).clanId),
        )
        .filter((entry): entry is string => entry != null),
    ),
  ];
  const clanNameById = new Map<string, string>();
  if (clanIds.length > 0) {
    const clanSnapshots = await Promise.all(
      clanIds.map((clanId) => clansCollection.doc(clanId).get()),
    );
    for (const clanSnapshot of clanSnapshots) {
      if (!clanSnapshot.exists) {
        continue;
      }
      const clanData = clanSnapshot.data() as ClanRecord | undefined;
      clanNameById.set(
        clanSnapshot.id,
        asNullableTrimmedString(clanData?.name) ?? clanSnapshot.id,
      );
    }
  }

  return memberDocs
    .map((doc) =>
      buildMaskedMemberCandidate({
        memberId: doc.id,
        member: doc.data() as MemberRecord,
        uid,
        clanNameById,
        languageCode,
      }),
    )
    .sort((left, right) => left.memberId.localeCompare(right.memberId));
}

async function loadMaskedMemberCandidateById(
  memberId: string,
  uid: string,
  languageCode: SupportedLanguageCode,
): Promise<MaskedMemberCandidate | null> {
  const snapshot = await membersCollection.doc(memberId).get();
  if (!snapshot.exists) {
    return null;
  }
  const member = snapshot.data() as MemberRecord;
  const clanId = optionalTrimmedRecordString(member.clanId);
  const clanNameById = new Map<string, string>();
  if (clanId != null) {
    const clanSnapshot = await clansCollection.doc(clanId).get();
    if (clanSnapshot.exists) {
      const clanData = clanSnapshot.data() as ClanRecord | undefined;
      clanNameById.set(
        clanId,
        asNullableTrimmedString(clanData?.name) ?? clanId,
      );
    }
  }
  return buildMaskedMemberCandidate({
    memberId,
    member,
    uid,
    clanNameById,
    languageCode,
  });
}

function buildMaskedMemberCandidate(input: {
  memberId: string;
  member: MemberRecord;
  uid: string;
  clanNameById: Map<string, string>;
  languageCode: SupportedLanguageCode;
}): MaskedMemberCandidate {
  const memberStatus =
    asNullableTrimmedString(input.member.status)?.toLowerCase() ?? null;
  const linkedAuthUid = optionalTrimmedRecordString(input.member.authUid);
  const blockedReason =
    linkedAuthUid != null && linkedAuthUid !== input.uid
      ? "member_linked_other_account"
      : isMemberInactiveStatus(memberStatus)
        ? "member_inactive"
        : null;
  const clanId = optionalTrimmedRecordString(input.member.clanId);
  const clanLabel =
    clanId == null ? null : (input.clanNameById.get(clanId) ?? clanId);
  const displayName =
    resolveMemberDisplayName(input.member) ??
    memberFallbackDisplayName(input.languageCode);
  return {
    memberId: input.memberId,
    displayName,
    displayNameMasked: maskMemberDisplayName(displayName),
    birthHint: buildMaskedBirthHint(input.member.birthDate ?? null),
    clanLabel: clanLabel == null ? null : maskClanLabel(clanLabel),
    roleLabel: roleLabelFromClaim(
      normalizeRoleClaim(input.member.primaryRole),
      input.languageCode,
    ),
    memberStatus,
    selectable: blockedReason == null,
    blockedReason,
  } satisfies MaskedMemberCandidate;
}

function isMemberInactiveStatus(status: string | null | undefined): boolean {
  const normalized = (status ?? "").trim().toLowerCase();
  return (
    normalized == "inactive" ||
    normalized == "deactivated" ||
    normalized == "archived" ||
    normalized == "deleted"
  );
}

function maskMemberDisplayName(name: string): string {
  const normalized = name.trim();
  if (normalized.length == 0) {
    return "***";
  }
  return normalized
    .split(/\s+/)
    .filter((part) => part.length > 0)
    .map((part) => {
      if (part.length <= 1) {
        return "*";
      }
      return `${part[0]}${"*".repeat(Math.max(part.length - 1, 1))}`;
    })
    .join(" ");
}

function maskClanLabel(clanLabel: string): string {
  return maskMemberDisplayName(clanLabel);
}

function memberFallbackDisplayName(
  languageCode: SupportedLanguageCode,
): string {
  return languageCode == "en" ? "BeFam member" : "Thành viên BeFam";
}

function buildMaskedBirthHint(birthDate: string | null): string | null {
  const normalized = (birthDate ?? "").trim();
  if (normalized.length == 0) {
    return null;
  }

  const yyyyMmDd = /^(\d{4})-(\d{2})-(\d{2})$/.exec(normalized);
  if (yyyyMmDd != null) {
    return `${yyyyMmDd[2]}/${yyyyMmDd[1]}`;
  }
  const ddMmYyyy = /^(\d{2})\/(\d{2})\/(\d{4})$/.exec(normalized);
  if (ddMmYyyy != null) {
    return `${ddMmYyyy[2]}/${ddMmYyyy[3]}`;
  }
  const yyyyOnly = /^(\d{4})$/.exec(normalized);
  if (yyyyOnly != null) {
    return yyyyOnly[1];
  }
  return normalized.length >= 4
    ? normalized.substring(normalized.length - 4)
    : null;
}

function serializeMemberSessionContext(context: MemberSessionContext) {
  return {
    memberId: context.memberId,
    displayName: context.displayName,
    clanId: context.clanId,
    branchId: context.branchId,
    primaryRole: context.primaryRole,
    accessMode: context.accessMode,
    linkedAuthUid: context.linkedAuthUid,
  };
}

async function upsertUserSessionProfile(
  uid: string,
  context: MemberSessionContext,
  options?: {
    clanIds?: Array<string>;
    normalizedPhone?: string | null;
  },
): Promise<void> {
  const clanIds =
    options?.clanIds != null
      ? options.clanIds
      : context.clanId == null
        ? []
        : [context.clanId];
  const normalizedClanIds = [
    ...new Set(
      clanIds.map((entry) => entry.trim()).filter((entry) => entry.length > 0),
    ),
  ];
  await usersCollection.doc(uid).set(
    {
      uid,
      memberId: context.memberId ?? "",
      clanId: context.clanId ?? "",
      clanIds: normalizedClanIds,
      branchId: context.branchId ?? "",
      primaryRole: context.primaryRole ?? "GUEST",
      accessMode: context.accessMode,
      linkedAuthUid: context.linkedAuthUid,
      normalizedPhone: options?.normalizedPhone ?? null,
      updatedAt: FieldValue.serverTimestamp(),
      createdAt: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
}

async function upsertTrustedDevice(input: {
  uid: string;
  memberId: string | null;
  deviceTokenHash: string;
  trustStatus: "active" | "revoked";
}): Promise<void> {
  const uid = input.uid.trim();
  const tokenHash = input.deviceTokenHash.trim();
  if (uid.length == 0 || tokenHash.length == 0) {
    return;
  }
  const docId = trustedDeviceDocId(uid, tokenHash);
  await trustedDevicesCollection.doc(docId).set(
    {
      id: docId,
      uid,
      memberId: input.memberId,
      deviceTokenHash: tokenHash,
      trustStatus: input.trustStatus,
      trustedAt: FieldValue.serverTimestamp(),
      lastSeenAt: FieldValue.serverTimestamp(),
      expiresAt: Timestamp.fromMillis(Date.now() + TRUSTED_DEVICE_TTL_MS),
      updatedAt: FieldValue.serverTimestamp(),
      createdAt: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
}

async function isTrustedDeviceActive(
  uid: string,
  deviceTokenHash: string,
): Promise<boolean> {
  const normalizedUid = uid.trim();
  const normalizedTokenHash = deviceTokenHash.trim();
  if (normalizedUid.length == 0 || normalizedTokenHash.length == 0) {
    return false;
  }
  const docId = trustedDeviceDocId(normalizedUid, normalizedTokenHash);
  const snapshot = await trustedDevicesCollection.doc(docId).get();
  if (!snapshot.exists) {
    return false;
  }
  const record = snapshot.data() as TrustedDeviceRecord;
  const trustStatus = (record.trustStatus ?? "").trim().toLowerCase();
  const storedTokenHash = (record.deviceTokenHash ?? "").trim();
  const expiresAtMs = record.expiresAt?.toMillis() ?? 0;
  if (
    trustStatus != "active" ||
    storedTokenHash.length == 0 ||
    storedTokenHash != normalizedTokenHash
  ) {
    return false;
  }
  if (expiresAtMs > 0 && expiresAtMs < Date.now()) {
    await trustedDevicesCollection.doc(docId).set(
      {
        trustStatus: "revoked",
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
    return false;
  }
  await trustedDevicesCollection.doc(docId).set(
    {
      lastSeenAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
  return true;
}

function trustedDeviceDocId(uid: string, deviceTokenHash: string): string {
  return `${uid.trim()}_${deviceTokenHash.trim().slice(0, 32)}`;
}

function resolvePreferredLanguageCode(data: unknown): SupportedLanguageCode {
  if (data == null || typeof data !== "object") {
    return "vi";
  }
  const record = data as Record<string, unknown>;
  const candidate =
    typeof record.languageCode === "string"
      ? record.languageCode
      : typeof record.locale === "string"
        ? record.locale
        : "";
  const normalized = candidate.trim().toLowerCase();
  return normalized.startsWith("en") ? "en" : "vi";
}

function memberVerificationGuardDocId(uid: string, memberId: string): string {
  return `${uid.trim()}_${memberId.trim()}`;
}

async function readMemberVerificationGuard(
  uid: string,
  memberId: string,
): Promise<{ locked: boolean; remainingAttempts: number }> {
  const guardRef = memberVerificationGuardsCollection.doc(
    memberVerificationGuardDocId(uid, memberId),
  );
  const snapshot = await guardRef.get();
  if (!snapshot.exists) {
    return {
      locked: false,
      remainingAttempts: MEMBER_VERIFICATION_MAX_ATTEMPTS,
    };
  }
  const guard = snapshot.data() as MemberVerificationGuardRecord;
  const nowMs = Date.now();
  const lockedUntilMs = readMillisValue(guard.lockedUntil);
  if (lockedUntilMs > 0 && lockedUntilMs > nowMs) {
    return {
      locked: true,
      remainingAttempts: 0,
    };
  }
  const windowStartMs = readMillisValue(guard.windowStartedAt);
  const withinWindow =
    windowStartMs > 0 &&
    nowMs - windowStartMs <= MEMBER_VERIFICATION_LOCK_WINDOW_MS;
  const failedAttempts = withinWindow
    ? Math.max(guard.failedAttempts ?? 0, 0)
    : 0;
  return {
    locked: false,
    remainingAttempts: Math.max(
      MEMBER_VERIFICATION_MAX_ATTEMPTS - failedAttempts,
      0,
    ),
  };
}

async function registerMemberVerificationFailure(input: {
  uid: string;
  memberId: string;
}): Promise<{ locked: boolean; remainingAttempts: number }> {
  const uid = input.uid.trim();
  const memberId = input.memberId.trim();
  if (uid.length == 0 || memberId.length == 0) {
    return {
      locked: false,
      remainingAttempts: MEMBER_VERIFICATION_MAX_ATTEMPTS,
    };
  }
  const guardRef = memberVerificationGuardsCollection.doc(
    memberVerificationGuardDocId(uid, memberId),
  );
  const nowMs = Date.now();
  const result = await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(guardRef);
    const guard = snapshot.exists
      ? (snapshot.data() as MemberVerificationGuardRecord)
      : null;
    const lockedUntilMs = readMillisValue(guard?.lockedUntil);
    if (lockedUntilMs > nowMs) {
      return {
        locked: true,
        remainingAttempts: 0,
      };
    }
    const windowStartMs = readMillisValue(guard?.windowStartedAt);
    const sameWindow =
      windowStartMs > 0 &&
      nowMs - windowStartMs <= MEMBER_VERIFICATION_LOCK_WINDOW_MS;
    const nextAttempts = sameWindow ? (guard?.failedAttempts ?? 0) + 1 : 1;
    const windowStartedAtMs = sameWindow ? windowStartMs : nowMs;
    const locked = nextAttempts >= MEMBER_VERIFICATION_MAX_ATTEMPTS;
    const lastLockedAtMs = readMillisValue(guard?.lastLockedAt);
    const retainsEscalation =
      lastLockedAtMs > 0 &&
      nowMs - lastLockedAtMs <= AUTH_ABUSE_LOCK_RESET_WINDOW_MS;
    const retainedLockCount = retainsEscalation
      ? readLockCount(guard?.lockCount)
      : 0;
    const nextLock = locked
      ? resolveEscalatingLock({
          existingLockCount: retainedLockCount,
          lastLockedAtMs,
          nowMs,
        })
      : null;
    transaction.set(
      guardRef,
      {
        uid,
        memberId,
        failedAttempts: nextAttempts,
        windowStartedAt: Timestamp.fromMillis(windowStartedAtMs),
        lockedUntil: locked
          ? Timestamp.fromMillis(nextLock!.lockedUntilMs)
          : null,
        lockCount: locked ? nextLock!.lockCount : retainedLockCount,
        lastLockedAt: locked
          ? Timestamp.fromMillis(nowMs)
          : retainsEscalation
            ? (guard?.lastLockedAt ?? null)
            : null,
        updatedAt: FieldValue.serverTimestamp(),
        createdAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
    return {
      locked,
      remainingAttempts: locked
        ? 0
        : Math.max(MEMBER_VERIFICATION_MAX_ATTEMPTS - nextAttempts, 0),
    };
  });
  return result;
}

async function clearMemberVerificationGuard(input: {
  uid: string;
  memberId: string;
}): Promise<void> {
  const uid = input.uid.trim();
  const memberId = input.memberId.trim();
  if (uid.length == 0 || memberId.length == 0) {
    return;
  }
  await memberVerificationGuardsCollection
    .doc(memberVerificationGuardDocId(uid, memberId))
    .set(
      {
        failedAttempts: 0,
        windowStartedAt: null,
        lockedUntil: null,
        lockCount: 0,
        lastLockedAt: null,
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
}

async function buildMemberVerificationQuestions(input: {
  memberId: string;
  memberData: MemberRecord;
  phoneE164: string;
  languageCode: SupportedLanguageCode;
}): Promise<Array<VerificationQuestion>> {
  const questions: Array<VerificationQuestion> = [];
  const languageCode = input.languageCode;
  const clanId = optionalTrimmedRecordString(input.memberData.clanId);
  const clanSnapshot =
    clanId == null ? null : await clansCollection.doc(clanId).get();
  const clanName =
    clanSnapshot != null && clanSnapshot.exists
      ? asNullableTrimmedString(
          (clanSnapshot.data() as ClanRecord | undefined)?.name,
        )
      : null;

  const gender = asNullableTrimmedString(
    input.memberData.gender,
  )?.toLowerCase();
  if (gender != null) {
    const normalizedGender = gender.startsWith("n")
      ? "male"
      : gender.startsWith("f")
        ? "female"
        : gender;
    const options = shuffleOptions([
      { id: "gender_male", label: languageCode == "en" ? "Male" : "Nam" },
      { id: "gender_female", label: languageCode == "en" ? "Female" : "Nữ" },
      {
        id: "gender_other",
        label:
          languageCode == "en" ? "Other / Unknown" : "Khác / Không xác định",
      },
    ]);
    const answerOptionId =
      normalizedGender == "male"
        ? "gender_male"
        : normalizedGender == "female"
          ? "gender_female"
          : "gender_other";
    questions.push({
      id: "gender",
      category: "personal",
      prompt:
        languageCode == "en"
          ? "What is the gender listed on this profile?"
          : "Giới tính trong hồ sơ này là gì?",
      options,
      answerOptionId,
    });
  }

  const birthHint = buildMaskedBirthHint(input.memberData.birthDate ?? null);
  if (birthHint != null) {
    const options = shuffleOptions([
      { id: "birth_correct", label: birthHint },
      { id: "birth_noise_a", label: makeBirthNoiseOption(birthHint, 1) },
      { id: "birth_noise_b", label: makeBirthNoiseOption(birthHint, 2) },
      { id: "birth_noise_c", label: makeBirthNoiseOption(birthHint, 3) },
    ]);
    questions.push({
      id: "birth_hint",
      category: "personal",
      prompt:
        languageCode == "en"
          ? "Which month/year of birth is the closest match for this profile?"
          : "Tháng/năm sinh gần đúng của hồ sơ này là gì?",
      options,
      answerOptionId: "birth_correct",
    });
  }

  if (clanName != null && clanName.trim().length > 0) {
    const trimmedClanName = clanName.trim();
    const options = shuffleOptions([
      { id: "clan_correct", label: trimmedClanName },
      {
        id: "clan_noise_a",
        label:
          languageCode == "en"
            ? `${trimmedClanName} (Sub-branch)`
            : `${trimmedClanName} (Nhánh phụ)`,
      },
      {
        id: "clan_noise_b",
        label:
          languageCode == "en"
            ? "Another clan in the system"
            : "Gia tộc khác trong hệ thống",
      },
      {
        id: "clan_noise_c",
        label:
          languageCode == "en"
            ? "Not linked to any clan yet"
            : "Chưa tham gia họ tộc nào",
      },
    ]);
    questions.push({
      id: "clan_name",
      category: "clan",
      prompt:
        languageCode == "en"
          ? "Which clan does this profile belong to?"
          : "Hồ sơ này thuộc dòng tộc nào?",
      options,
      answerOptionId: "clan_correct",
    });
  }

  const role = normalizeRoleClaim(input.memberData.primaryRole);
  if (role.length > 0) {
    const options = shuffleOptions([
      { id: "role_correct", label: roleLabelFromClaim(role, languageCode) },
      {
        id: "role_noise_a",
        label: languageCode == "en" ? "New member" : "Thành viên mới",
      },
      {
        id: "role_noise_b",
        label: languageCode == "en" ? "Unlinked guest" : "Khách chưa liên kết",
      },
      {
        id: "role_noise_c",
        label: languageCode == "en" ? "Unknown role" : "Vai trò không xác định",
      },
    ]);
    questions.push({
      id: "role",
      category:
        role.includes("CLAN") || role.includes("BRANCH") ? "clan" : "personal",
      prompt:
        languageCode == "en"
          ? "Which role is the closest match for this profile in the clan?"
          : "Vai trò gần đúng của hồ sơ này trong họ tộc là gì?",
      options,
      answerOptionId: "role_correct",
    });
  }

  return questions.slice(0, MEMBER_VERIFICATION_TOTAL_QUESTIONS);
}

function roleLabelFromClaim(
  role: string,
  languageCode: SupportedLanguageCode = "vi",
): string {
  switch (normalizeRoleClaim(role)) {
    case "SUPER_ADMIN":
      return languageCode == "en" ? "System admin" : "Quản trị hệ thống";
    case "CLAN_ADMIN":
      return languageCode == "en" ? "Clan admin" : "Quản trị họ tộc";
    case "CLAN_OWNER":
      return languageCode == "en" ? "Clan owner" : "Chủ tộc";
    case "CLAN_LEADER":
      return languageCode == "en" ? "Clan leader" : "Trưởng tộc";
    case "BRANCH_ADMIN":
      return languageCode == "en" ? "Branch admin" : "Quản trị chi";
    case "MEMBER":
      return languageCode == "en" ? "Member" : "Thành viên";
    default:
      return languageCode == "en" ? "Member" : "Thành viên";
  }
}

function makeBirthNoiseOption(seed: string, offset: number): string {
  const yyyy = /(\d{4})$/.exec(seed)?.[1];
  if (yyyy != null) {
    const year = Number.parseInt(yyyy, 10);
    if (Number.isFinite(year)) {
      const nextYear = String(year + offset).padStart(4, "0");
      if (seed.includes("/")) {
        const month = seed.split("/")[0];
        return `${month}/${nextYear}`;
      }
      return nextYear;
    }
  }
  return `${seed}-${offset}`;
}

function shuffleOptions(
  options: Array<VerificationQuestionOption>,
): Array<VerificationQuestionOption> {
  const copied = [...options];
  for (let index = copied.length - 1; index > 0; index -= 1) {
    const swapIndex = Math.floor(Math.random() * (index + 1));
    const current = copied[index];
    copied[index] = copied[swapIndex];
    copied[swapIndex] = current;
  }
  return copied;
}

async function writeAuthEvent(input: {
  uid: string;
  action: string;
  phoneE164: string;
  memberId: string | null;
  metadata: Record<string, unknown>;
}): Promise<void> {
  await authEventLogsCollection.add({
    uid: input.uid,
    action: input.action,
    phoneE164Masked: maskPhone(input.phoneE164),
    memberId: input.memberId,
    metadata: input.metadata,
    createdAt: FieldValue.serverTimestamp(),
  });
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
      throw new HttpsError("not-found", "The member record no longer exists.");
    }

    const member = memberSnapshot.data() as MemberRecord;
    if (
      member.authUid != null &&
      member.authUid.length > 0 &&
      member.authUid !== uid
    ) {
      throw new HttpsError(
        "already-exists",
        "This member profile is already linked to another account.",
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
        status: "consumed",
        claimedAt: now,
        claimedBy: uid,
      });
    }

    return shouldLinkAuthUid;
  });
}

function buildMemberSessionContext(
  memberId: string,
  source: MemberRecord | InternalResolvedChildLoginContext,
  accessMode: MemberAccessMode,
  linkedAuthUid: boolean,
): MemberSessionContext {
  if ("parentPhoneE164" in source) {
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
    displayName: source.fullName ?? source.nickName ?? "BeFam Member",
    clanId: source.clanId ?? null,
    branchId: source.branchId ?? null,
    primaryRole: source.primaryRole ?? "MEMBER",
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
    .filter(
      (entry, index, source) =>
        entry.length > 0 && source.indexOf(entry) == index,
    );
  const clanIds =
    normalizedClanIds.length > 0
      ? normalizedClanIds
      : context.clanId == null
        ? []
        : [context.clanId];
  const activeClanId = context.clanId ?? clanIds[0] ?? "";

  // Embed the primary clan's current status so security rules can skip
  // the isClanActive DB read on every operation for the primary clan.
  let clanStatus = "";
  if (activeClanId.length > 0) {
    const clanSnap = await db.collection("clans").doc(activeClanId).get();
    const status = clanSnap.exists
      ? ((clanSnap.data() as ClanRecord | undefined)?.status ?? "active")
      : "";
    clanStatus = typeof status === "string" ? status.trim() : "";
  }

  await auth.setCustomUserClaims(uid, {
    ...existingClaims,
    clanIds: clanIds,
    clanId: activeClanId,
    activeClanId,
    memberId: context.memberId ?? "",
    branchId: context.branchId ?? "",
    primaryRole: context.primaryRole ?? "GUEST",
    memberAccessMode: context.accessMode,
    clanStatus,
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
    ownerUid: context.ownerUid,
    ownerDisplayName: context.ownerDisplayName,
    billingPlanCode: context.billingPlanCode,
    billingPlanStatus: context.billingPlanStatus,
  };
}

async function loadLinkedClanContextsForUid(
  uid: string,
): Promise<Array<LinkedClanContext>> {
  const snapshot = await membersCollection
    .where("authUid", "==", uid)
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

    const role = normalizeRoleClaim(data.primaryRole) || "MEMBER";
    const displayName = resolveMemberDisplayName(data);
    const branchId = asNullableTrimmedString(data.branchId);
    const candidate: LinkedClanContext = {
      clanId,
      clanName: clanId,
      memberId: doc.id,
      branchId,
      primaryRole: role,
      displayName,
      status: null,
      ownerUid: null,
      ownerDisplayName: null,
      billingPlanCode: null,
      billingPlanStatus: null,
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
  const clanMetadataById = new Map<
    string,
    {
      clanName: string;
      clanStatus: string | null;
      ownerUid: string | null;
      ownerDisplayName: string | null;
    }
  >();
  for (const snapshot of clanSnapshots) {
    const data = snapshot.data() as ClanRecord | undefined;
    const clanName = asNullableTrimmedString(data?.name) ?? snapshot.id;
    const clanStatus =
      asNullableTrimmedString(data?.status)?.toLowerCase() ?? null;
    const ownerUid = asNullableTrimmedString(data?.ownerUid);
    const ownerDisplayName = asNullableTrimmedString(data?.founderName);
    clanMetadataById.set(snapshot.id, {
      clanName,
      clanStatus,
      ownerUid,
      ownerDisplayName,
    });
  }

  const ownerNameByClanId = new Map<string, string>();
  await Promise.all(
    clanIds.map(async (clanId) => {
      const metadata = clanMetadataById.get(clanId);
      if (
        metadata == null ||
        metadata.ownerUid == null ||
        metadata.ownerDisplayName != null
      ) {
        return;
      }
      const ownerMemberSnapshot = await membersCollection
        .where("clanId", "==", clanId)
        .where("authUid", "==", metadata.ownerUid)
        .limit(1)
        .get();
      if (ownerMemberSnapshot.empty) {
        return;
      }
      const ownerMember = ownerMemberSnapshot.docs[0]?.data() as
        | MemberRecord
        | undefined;
      const ownerLabel = resolveMemberDisplayName(ownerMember ?? {});
      if (ownerLabel != null && ownerLabel.trim().length > 0) {
        ownerNameByClanId.set(clanId, ownerLabel.trim());
      }
    }),
  );

  const subscriptionDocIds = new Set<string>();
  for (const clanId of clanIds) {
    const metadata = clanMetadataById.get(clanId);
    if (metadata?.ownerUid != null) {
      subscriptionDocIds.add(ownerBillingSubscriptionDocId(metadata.ownerUid));
      subscriptionDocIds.add(`${clanId}__${metadata.ownerUid}`);
    }
    subscriptionDocIds.add(clanId);
  }
  const subscriptionSnapshots = await Promise.all(
    [...subscriptionDocIds].map((docId) =>
      subscriptionsCollection.doc(docId).get(),
    ),
  );
  const subscriptionByDocId = new Map<
    string,
    { planCode: string | null; status: string | null }
  >();
  for (const subscriptionSnapshot of subscriptionSnapshots) {
    if (!subscriptionSnapshot.exists) {
      continue;
    }
    const data = subscriptionSnapshot.data() as
      | Record<string, unknown>
      | undefined;
    const planCode = normalizeBillingPlanCode(data?.planCode);
    const billingStatus =
      asNullableTrimmedString(data?.status)?.toLowerCase() ?? null;
    subscriptionByDocId.set(subscriptionSnapshot.id, {
      planCode,
      status: billingStatus,
    });
  }

  for (const clanId of clanIds) {
    const context = dedupByClan.get(clanId);
    if (context == null) {
      continue;
    }
    const metadata = clanMetadataById.get(clanId);
    const ownerUid = metadata?.ownerUid ?? null;
    const ownerScopedSubscription =
      ownerUid == null
        ? null
        : subscriptionByDocId.get(ownerBillingSubscriptionDocId(ownerUid));
    const scopedSubscription =
      ownerUid == null
        ? null
        : subscriptionByDocId.get(`${clanId}__${ownerUid}`);
    const legacySubscription = subscriptionByDocId.get(clanId);
    const subscription =
      ownerScopedSubscription ??
      scopedSubscription ??
      legacySubscription ??
      null;
    dedupByClan.set(clanId, {
      ...context,
      clanName: metadata?.clanName ?? context.clanName,
      status: metadata?.clanStatus ?? context.status,
      ownerUid,
      ownerDisplayName:
        metadata?.ownerDisplayName ?? ownerNameByClanId.get(clanId) ?? null,
      billingPlanCode: subscription?.planCode ?? null,
      billingPlanStatus: subscription?.status ?? null,
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
  const activeContexts = contexts.filter((context) =>
    isActiveClanContext(context),
  );
  if (activeContexts.length === 0) {
    return null;
  }
  const requested = requestedClanId?.trim();
  if (requested != null && requested.length > 0) {
    return (
      activeContexts.find((context) => context.clanId == requested) ?? null
    );
  }

  const activeFromToken =
    optionalString(token, "activeClanId")?.trim() ??
    optionalString(token, "clanId")?.trim();
  if (activeFromToken != null && activeFromToken.length > 0) {
    const matched = activeContexts.find(
      (context) => context.clanId == activeFromToken,
    );
    if (matched != null) {
      return matched;
    }
  }

  return activeContexts[0] ?? null;
}

function isActiveClanContext(context: LinkedClanContext): boolean {
  const status = (context.status ?? "active").trim().toLowerCase();
  return status != "inactive" && status != "archived" && status != "deleted";
}

function normalizeBillingPlanCode(value: unknown): string | null {
  const normalized = asNullableTrimmedString(value)?.toUpperCase() ?? null;
  if (normalized == null) {
    return null;
  }
  if (
    normalized == "FREE" ||
    normalized == "BASE" ||
    normalized == "PLUS" ||
    normalized == "PRO"
  ) {
    return normalized;
  }
  return null;
}

function preferredClanContext(
  candidate: LinkedClanContext,
  current: LinkedClanContext,
): boolean {
  const candidateRank = rolePriority(candidate.primaryRole);
  const currentRank = rolePriority(current.primaryRole);
  if (candidateRank != currentRank) {
    return candidateRank > currentRank;
  }

  const candidateActive = (candidate.status ?? "active") == "active";
  const currentActive = (current.status ?? "active") == "active";
  if (candidateActive != currentActive) {
    return candidateActive;
  }

  return candidate.memberId.localeCompare(current.memberId) < 0;
}

function rolePriority(role: string): number {
  const normalized = normalizeRoleClaim(role);
  switch (normalized) {
    case "SUPER_ADMIN":
      return 100;
    case "CLAN_ADMIN":
      return 95;
    case "CLAN_OWNER":
      return 90;
    case "CLAN_LEADER":
      return 85;
    case "VICE_LEADER":
      return 80;
    case "SUPPORTER_OF_LEADER":
      return 75;
    case "BRANCH_ADMIN":
      return 70;
    case "ADMIN_SUPPORT":
      return 65;
    case "TREASURER":
      return 60;
    case "SCHOLARSHIP_COUNCIL_HEAD":
      return 55;
    case "MEMBER":
      return 30;
    default:
      return 10;
  }
}

async function resolveSelfTestMemberContext({
  uid,
  memberId,
  clanId,
  authToken,
}: {
  uid: string;
  memberId?: string | null;
  clanId?: string | null;
  authToken: Record<string, unknown>;
}): Promise<{ memberId: string | null; clanId: string | null }> {
  const requestedMemberId = memberId?.trim() ?? "";
  const requestedClanId = clanId?.trim() ?? "";
  if (requestedMemberId.length > 0) {
    const memberSnapshot = await db
      .collection("members")
      .doc(requestedMemberId)
      .get();
    if (memberSnapshot.exists) {
      const memberData = memberSnapshot.data() as MemberRecord | undefined;
      const linkedUid = optionalString(memberData, "authUid")?.trim() ?? "";
      const memberClanId = optionalString(memberData, "clanId")?.trim() ?? "";
      if (
        linkedUid === uid &&
        memberClanId.length > 0 &&
        (requestedClanId.length === 0 || requestedClanId === memberClanId)
      ) {
        return {
          memberId: requestedMemberId,
          clanId: memberClanId,
        };
      }
    }
  }

  const tokenMemberId = optionalString(authToken, "memberId")?.trim() ?? "";
  const tokenClanIds = Array.isArray(authToken.clanIds)
    ? authToken.clanIds
        .filter((value): value is string => typeof value === "string")
        .map((value) => value.trim())
        .filter((value) => value.length > 0)
    : [];
  return {
    memberId: tokenMemberId.length > 0 ? tokenMemberId : null,
    clanId: tokenClanIds.length > 0 ? tokenClanIds[0] : null,
  };
}

function readSelfTestDelaySeconds(data: unknown): number {
  const rawValue =
    data != null && typeof data === "object"
      ? (data as Record<string, unknown>).delaySeconds
      : null;
  const parsedValue =
    typeof rawValue === "number"
      ? Math.trunc(rawValue)
      : typeof rawValue === "string"
        ? Number.parseInt(rawValue, 10)
        : Number.NaN;
  if (!Number.isFinite(parsedValue)) {
    return 8;
  }
  return Math.max(0, Math.min(30, parsedValue));
}

function sanitizeSelfTestText(
  value: string | null | undefined,
  fallback: string,
  maxLength: number,
): string {
  const normalized = value?.trim() ?? "";
  if (normalized.length === 0) {
    return fallback;
  }
  if (normalized.length <= maxLength) {
    return normalized;
  }
  return normalized.substring(0, maxLength).trimEnd();
}

function buildSelfTestEventReminderDispatchId(input: {
  eventId: string;
  reminderAt: Date;
  offsetMinutes: number;
}): string {
  const fingerprint = createHash("sha256")
    .update(
      `${input.eventId}:${input.reminderAt.toISOString()}:${input.offsetMinutes}`,
    )
    .digest("hex")
    .slice(0, 32);
  return `evt_reminder_${fingerprint}`;
}

function sleepForMillis(durationMs: number): Promise<void> {
  return new Promise((resolve) => {
    setTimeout(resolve, durationMs);
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
