import { createHash, timingSafeEqual, X509Certificate } from 'node:crypto';

import { FieldValue } from 'firebase-admin/firestore';
import { onRequest } from 'firebase-functions/v2/https';
import { OAuth2Client } from 'google-auth-library';
import { compactVerify, decodeProtectedHeader, importX509 } from 'jose';

import {
  APP_REGION,
  getAppleIapWebhookBearerToken,
  getGoogleIapRtdnAudience,
  getGoogleIapRtdnServiceAccountEmail,
  getGoogleIapWebhookBearerToken,
} from '../config/runtime';
import type { BillingPlanCode } from './pricing';
import {
  refreshIapProductCatalogFromFirestore,
  resolvePlanCodeForIapProductId,
  verifyInAppStorePurchase,
  type IapPlatform,
} from './iap-verification';
import { refreshBillingPricingTiers } from './pricing';
import { db } from '../shared/firestore';
import { logError, logInfo, logWarn } from '../shared/logger';
import {
  applyPaymentResult,
  recordPaymentWebhookEvent,
  resolveTierByPlanCode,
} from './store';

type StoreLifecycleState = 'active' | 'canceled' | 'refunded' | 'expired';

const subscriptionsCollection = db.collection('subscriptions');
const iapPurchaseLineagesCollection = db.collection('iapPurchaseLineages');
const iapPurchaseVerificationsCollection = db.collection(
  'iapPurchaseVerifications',
);
const googleOidcClient = new OAuth2Client();
const APPLE_ROOT_CA_G3_SHA256 =
  '63343abfb89a6a03ebb57e9b3f5fa7be7c4f5c756f3017b3a8c488c3653e9179';
const APPLE_WWDR_G6_SHA256 =
  'bdd4ed6e74691f0c2bfd01be0296197af1379e0418e2d300efa9c3bef642ca30';

export const appleIapWebhook = onRequest(
  { region: APP_REGION },
  async (request, response) => {
    if (request.method !== 'POST') {
      response.status(405).json({ ok: false, message: 'Method not allowed' });
      return;
    }
    try {
      const expectedToken = getAppleIapWebhookBearerToken();
      if (!isAuthorizedWithSharedBearer(request, expectedToken)) {
        response.status(401).json({ ok: false, message: 'Unauthorized' });
        return;
      }

      const body = normalizeRequestBody(request.body);
      const signedPayload = normalizeString(body.signedPayload);
      if (signedPayload.length === 0) {
        response
          .status(400)
          .json({ ok: false, message: 'signedPayload is required' });
        return;
      }

      const notificationPayload = await verifySignedAppleJws(signedPayload);
      const notificationType = normalizeString(
        notificationPayload.notificationType,
      ).toUpperCase();
      const notificationSubtype = normalizeString(
        notificationPayload.subtype,
      ).toUpperCase();
      const notificationUuid =
        normalizeString(notificationPayload.notificationUUID) ||
        stableHash(`apple-iap:${signedPayload}`).slice(0, 32);
      const data = readRecord(notificationPayload.data);
      const signedTransactionInfo = normalizeString(data?.signedTransactionInfo);
      const signedRenewalInfo = normalizeString(data?.signedRenewalInfo);

      if (signedTransactionInfo.length === 0) {
        response
          .status(400)
          .json({ ok: false, message: 'signedTransactionInfo is required' });
        return;
      }
      const transactionInfo = await verifySignedAppleJws(signedTransactionInfo);
      const renewalInfo =
        signedRenewalInfo.length > 0
          ? await verifySignedAppleJws(signedRenewalInfo)
          : {};
      await refreshIapProductCatalogFromFirestore();
      const productId = normalizeString(transactionInfo.productId).toLowerCase();
      if (productId.length === 0) {
        response
          .status(400)
          .json({ ok: false, message: 'Apple transaction productId is missing' });
        return;
      }
      const planCode = resolvePlanCodeForIapProductId(productId, 'ios');
      if (planCode == null) {
        response.status(400).json({
          ok: false,
          message: `Unsupported Apple productId "${productId}"`,
        });
        return;
      }
      const originalTransactionId = normalizeString(
        transactionInfo.originalTransactionId,
      );
      const transactionId = normalizeString(transactionInfo.transactionId);
      const lineageSource = originalTransactionId || transactionId;
      if (lineageSource.length === 0) {
        response.status(400).json({
          ok: false,
          message: 'Apple transaction lineage identifier is missing',
        });
        return;
      }
      const externalTransactionId =
        originalTransactionId || transactionId || notificationUuid;
      const storeTransactionSource =
        transactionId || originalTransactionId || notificationUuid;
      const lineageKey = stableHash(`apple_iap:${productId}:${lineageSource}`);
      const storeTransactionKey = stableHash(
        `apple_iap:${productId}:${storeTransactionSource}`,
      );
      const expiresAtMs = toPositiveNumber(
        transactionInfo.expiresDate ?? transactionInfo.expiresDateMs,
      );
      const revocationDateMs = toPositiveNumber(
        transactionInfo.revocationDate ?? transactionInfo.revocationDateMs,
      );
      const autoRenewStatus = toPositiveNumber(renewalInfo.autoRenewStatus);
      const state = resolveAppleLifecycleState({
        notificationType,
        notificationSubtype,
        expiresAtMs,
        revocationDateMs,
        autoRenewStatus,
      });

      const payloadHash = sha256(
        JSON.stringify({
          notificationPayload,
          transactionInfo,
          renewalInfo,
        }),
      );
      const webhookEvent = await recordPaymentWebhookEvent({
        provider: 'apple_iap',
        externalEventId: notificationUuid,
        transactionId: storeTransactionKey,
        payloadHash,
        validSignature: true,
        rawPayload: {
          notificationType,
          notificationSubtype,
          notificationUuid,
          productId,
          transactionId,
          originalTransactionId,
          state,
        },
      });
      if (webhookEvent.alreadyProcessed) {
        response.status(200).json({ ok: true, idempotent: true });
        return;
      }

      await applyStoreLifecycleSync({
        platform: 'ios',
        lineageKey,
        storeTransactionKey,
        externalTransactionId,
        planCode,
        expiresAtMs,
        state,
        sourcePayload: {
          notificationType,
          notificationSubtype,
          notificationUuid,
          transactionId,
          originalTransactionId,
        },
      });

      logInfo('appleIapWebhook processed', {
        notificationUuid,
        notificationType,
        state,
        planCode,
      });
      response.status(200).json({ ok: true });
    } catch (error) {
      logError('appleIapWebhook failed', { error: `${error}` });
      response.status(500).json({
        ok: false,
        message: 'Could not process Apple IAP webhook',
      });
    }
  },
);

export const googleIapWebhook = onRequest(
  { region: APP_REGION },
  async (request, response) => {
    if (request.method !== 'POST') {
      response.status(405).json({ ok: false, message: 'Method not allowed' });
      return;
    }
    try {
      const authorized = await isAuthorizedGoogleRtdnRequest(request);
      if (!authorized) {
        response.status(401).json({ ok: false, message: 'Unauthorized' });
        return;
      }

      const body = normalizeRequestBody(request.body);
      const message = readRecord(body.message);
      const messageId = normalizeString(message?.messageId);
      const encodedData = normalizeString(message?.data);
      if (encodedData.length === 0) {
        response
          .status(400)
          .json({ ok: false, message: 'message.data is required' });
        return;
      }
      const decodedData = decodeBase64Json(encodedData);
      const subscriptionNotification = readRecord(
        decodedData.subscriptionNotification,
      );
      if (subscriptionNotification == null) {
        response.status(400).json({
          ok: false,
          message: 'subscriptionNotification is required',
        });
        return;
      }
      const packageName = normalizeString(decodedData.packageName);
      const purchaseToken = normalizeString(
        subscriptionNotification.purchaseToken,
      );
      const productId = normalizeString(subscriptionNotification.subscriptionId);
      const notificationType = toPositiveNumber(
        subscriptionNotification.notificationType,
      );
      if (
        packageName.length === 0 ||
        purchaseToken.length === 0 ||
        productId.length === 0
      ) {
        response.status(400).json({
          ok: false,
          message: 'Invalid Google RTDN payload (packageName/token/productId).',
        });
        return;
      }

      const verifiedPurchase = await verifyInAppStorePurchase({
        platform: 'android',
        payload: {
          packageName,
          purchaseToken,
          productId,
        },
      });
      const state = resolveGoogleLifecycleState(
        notificationType,
        verifiedPurchase.status,
      );
      const externalEventId =
        messageId ||
        stableHash(`google-rtdn:${purchaseToken}:${notificationType}`).slice(
          0,
          32,
        );
      const payloadHash = sha256(
        JSON.stringify({
          decodedData,
          verifiedPurchase: {
            productId: verifiedPurchase.productId,
            externalTransactionId: verifiedPurchase.externalTransactionId,
            expiresAtMs: verifiedPurchase.expiresAtMs,
            status: verifiedPurchase.status,
          },
        }),
      );

      const webhookEvent = await recordPaymentWebhookEvent({
        provider: 'google_play',
        externalEventId,
        transactionId: verifiedPurchase.storeTransactionKey,
        payloadHash,
        validSignature: true,
        rawPayload: {
          messageId,
          packageName,
          productId,
          notificationType,
          state,
        },
      });
      if (webhookEvent.alreadyProcessed) {
        response.status(200).json({ ok: true, idempotent: true });
        return;
      }

      await applyStoreLifecycleSync({
        platform: 'android',
        lineageKey: verifiedPurchase.lineageKey,
        storeTransactionKey: verifiedPurchase.storeTransactionKey,
        externalTransactionId: verifiedPurchase.externalTransactionId,
        planCode: verifiedPurchase.planCode,
        expiresAtMs: verifiedPurchase.expiresAtMs,
        state,
        sourcePayload: {
          notificationType,
          packageName,
          productId,
          messageId,
        },
      });

      logInfo('googleIapWebhook processed', {
        messageId,
        notificationType,
        state,
        productId,
      });
      response.status(200).json({ ok: true });
    } catch (error) {
      logError('googleIapWebhook failed', { error: `${error}` });
      response.status(500).json({
        ok: false,
        message: 'Could not process Google IAP webhook',
      });
    }
  },
);

async function applyStoreLifecycleSync({
  platform,
  lineageKey,
  storeTransactionKey,
  externalTransactionId,
  planCode,
  expiresAtMs,
  state,
  sourcePayload,
}: {
  platform: IapPlatform;
  lineageKey: string;
  storeTransactionKey: string;
  externalTransactionId: string;
  planCode: BillingPlanCode;
  expiresAtMs: number;
  state: StoreLifecycleState;
  sourcePayload: Record<string, unknown>;
}): Promise<void> {
  const lineageRef = iapPurchaseLineagesCollection.doc(lineageKey);
  const lineageSnapshot = await lineageRef.get();
  if (!lineageSnapshot.exists) {
    logWarn('IAP webhook ignored: lineage not found', {
      platform,
      lineageKey,
      storeTransactionKey,
      planCode,
    });
    return;
  }
  const lineage = lineageSnapshot.data() ?? {};
  const clanId = normalizeString(lineage.clanId);
  const ownerUid = normalizeString(lineage.ownerUid);
  if (clanId.length === 0 || ownerUid.length === 0) {
    logWarn('IAP webhook ignored: lineage scope missing', {
      platform,
      lineageKey,
    });
    return;
  }
  await refreshBillingPricingTiers();
  const tier = resolveTierByPlanCode(planCode);
  const now = new Date();
  const subscriptionStatus = resolveSubscriptionStatus(state, expiresAtMs, now);
  const paymentStatus = resolvePaymentStatusFromStoreState(state);
  const subscriptionRef = subscriptionsCollection.doc(ownerBillingDocId(ownerUid));
  const expiresAtDate = expiresAtMs > 0 ? new Date(expiresAtMs) : null;

  await subscriptionRef.set(
    {
      id: ownerBillingDocId(ownerUid),
      clanId: personalBillingScopeId(ownerUid),
      ownerUid,
      planCode,
      status: subscriptionStatus,
      amountVndYear: tier.priceVndYear,
      vatIncluded: tier.vatIncluded,
      showAds: tier.showAds,
      adFree: tier.adFree,
      autoRenew: state === 'active',
      lastPaymentMethod: iapPlatformToPaymentMethod(platform),
      expiresAt: expiresAtDate,
      nextPaymentDueAt:
        state === 'active' && expiresAtDate != null ? expiresAtDate : null,
      updatedAt: FieldValue.serverTimestamp(),
      updatedBy: `system:${platform}_iap_webhook`,
    },
    { merge: true },
  );

  const trackedTransactionId = normalizeString(lineage.lastTransactionId);
  if (trackedTransactionId.length > 0 && paymentStatus != null) {
    try {
      await applyPaymentResult({
        transactionId: trackedTransactionId,
        provider: iapPlatformToPaymentMethod(platform),
        gatewayReference: externalTransactionId,
        paymentStatus,
        payloadHash: storeTransactionKey,
        actorUid: `system:${platform}_iap_webhook`,
        now,
      });
    } catch (error) {
      logWarn('IAP webhook payment state sync skipped', {
        platform,
        lineageKey,
        transactionId: trackedTransactionId,
        paymentStatus,
        error: `${error}`,
      });
    }
  }

  const verificationId = normalizeString(lineage.lastVerificationId);
  await Promise.all([
    lineageRef.set(
      {
        platform,
        planCode,
        clanId,
        ownerUid,
        lastStoreState: state,
        lastStoreTransactionKey: storeTransactionKey,
        lastExternalTransactionId: externalTransactionId,
        verifiedExpiresAtMs: expiresAtMs,
        lastWebhookPayload: sourcePayload,
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    ),
    verificationId.length > 0
      ? iapPurchaseVerificationsCollection.doc(verificationId).set(
          {
            latestStoreState: state,
            latestStoreTransactionKey: storeTransactionKey,
            latestExternalTransactionId: externalTransactionId,
            latestWebhookPayload: sourcePayload,
            verifiedExpiresAtMs: expiresAtMs,
            updatedAt: FieldValue.serverTimestamp(),
          },
          { merge: true },
        )
      : Promise.resolve(),
  ]);
}

function resolveAppleLifecycleState({
  notificationType,
  notificationSubtype,
  expiresAtMs,
  revocationDateMs,
  autoRenewStatus,
}: {
  notificationType: string;
  notificationSubtype: string;
  expiresAtMs: number;
  revocationDateMs: number;
  autoRenewStatus: number;
}): StoreLifecycleState {
  if (revocationDateMs > 0) {
    return 'refunded';
  }
  if (notificationType === 'REFUND' || notificationType === 'REVOKE') {
    return 'refunded';
  }
  if (notificationType === 'EXPIRED') {
    return 'expired';
  }
  if (
    notificationType === 'DID_CHANGE_RENEWAL_STATUS' &&
    autoRenewStatus === 0 &&
    notificationSubtype === 'AUTO_RENEW_DISABLED'
  ) {
    return 'canceled';
  }
  if (expiresAtMs > Date.now()) {
    return 'active';
  }
  return 'expired';
}

function resolveGoogleLifecycleState(
  notificationType: number,
  verifiedStatus: 'active' | 'expired',
): StoreLifecycleState {
  if (notificationType === 12) {
    return 'refunded';
  }
  if (
    notificationType === 3 ||
    notificationType === 5 ||
    notificationType === 10 ||
    notificationType === 11 ||
    notificationType === 20
  ) {
    return 'canceled';
  }
  if (notificationType === 13) {
    return 'expired';
  }
  return verifiedStatus === 'active' ? 'active' : 'expired';
}

function resolveSubscriptionStatus(
  state: StoreLifecycleState,
  expiresAtMs: number,
  now: Date,
): 'active' | 'expired' | 'canceled' {
  if (state === 'active') {
    return expiresAtMs > now.getTime() ? 'active' : 'expired';
  }
  if (state === 'canceled') {
    return expiresAtMs > now.getTime() ? 'active' : 'canceled';
  }
  if (state === 'refunded') {
    return 'canceled';
  }
  return 'expired';
}

function resolvePaymentStatusFromStoreState(
  state: StoreLifecycleState,
): 'succeeded' | 'failed' | 'canceled' | null {
  if (state === 'active') {
    return 'succeeded';
  }
  if (state === 'refunded') {
    return 'failed';
  }
  if (state === 'canceled' || state === 'expired') {
    return 'canceled';
  }
  return null;
}

function iapPlatformToPaymentMethod(
  platform: IapPlatform,
): 'apple_iap' | 'google_play' {
  return platform === 'ios' ? 'apple_iap' : 'google_play';
}

async function verifySignedAppleJws(
  compactJws: string,
): Promise<Record<string, unknown>> {
  const header = decodeProtectedHeader(compactJws);
  const x5c = Array.isArray(header.x5c) ? header.x5c : [];
  const chainDer = x5c.filter(
    (entry): entry is string => typeof entry === 'string' && entry.length > 0,
  );
  if (header.alg !== 'ES256' || chainDer.length === 0) {
    throw new Error('Apple signed payload header is invalid.');
  }
  const leafPem = derBase64ToPem(chainDer[0]);
  const chain = chainDer.map((entry) => new X509Certificate(derBase64ToPem(entry)));
  const now = Date.now();
  for (const cert of chain) {
    assertCertValidity(cert, now);
  }
  const leaf = chain[0];
  const intermediate = chain[1];
  if (intermediate == null) {
    throw new Error('Apple signed payload certificate chain is incomplete.');
  }
  if (!leaf.checkIssued(intermediate) || !leaf.verify(intermediate.publicKey)) {
    throw new Error('Apple signed payload leaf certificate is not trusted.');
  }
  const intermediateFingerprint = fingerprintSha256(intermediate);
  if (intermediateFingerprint !== APPLE_WWDR_G6_SHA256) {
    throw new Error('Apple signed payload intermediate certificate is not trusted.');
  }
  const root = chain[2];
  if (root != null) {
    if (!intermediate.checkIssued(root) || !intermediate.verify(root.publicKey)) {
      throw new Error('Apple signed payload chain is not trusted.');
    }
    if (!root.checkIssued(root) || !root.verify(root.publicKey)) {
      throw new Error('Apple root certificate is invalid.');
    }
    const rootFingerprint = fingerprintSha256(root);
    if (rootFingerprint !== APPLE_ROOT_CA_G3_SHA256) {
      throw new Error('Apple root certificate is not trusted.');
    }
  }
  const key = await importX509(leafPem, 'ES256');
  const result = await compactVerify(compactJws, key, {
    algorithms: ['ES256'],
  });
  const payloadText = new TextDecoder().decode(result.payload);
  const payload = safeJsonParse(payloadText);
  if (!isRecord(payload)) {
    throw new Error('Apple signed payload JSON is invalid.');
  }
  return payload;
}

async function isAuthorizedGoogleRtdnRequest(request: {
  headers: Record<string, unknown>;
}): Promise<boolean> {
  const audience = getGoogleIapRtdnAudience();
  if (audience.length === 0) {
    const fallbackToken = getGoogleIapWebhookBearerToken();
    return isAuthorizedWithSharedBearer(request, fallbackToken);
  }
  const bearer = readBearerToken(request.headers);
  if (bearer == null) {
    return false;
  }
  try {
    const ticket = await googleOidcClient.verifyIdToken({
      idToken: bearer,
      audience,
    });
    const payload = ticket.getPayload();
    if (payload == null) {
      return false;
    }
    const issuer = normalizeString(payload.iss).toLowerCase();
    if (
      issuer !== 'accounts.google.com' &&
      issuer !== 'https://accounts.google.com'
    ) {
      return false;
    }
    const expectedEmail = getGoogleIapRtdnServiceAccountEmail();
    if (expectedEmail.length > 0) {
      const tokenEmail = normalizeString(payload.email).toLowerCase();
      const emailVerified = payload.email_verified === true;
      if (!emailVerified || tokenEmail !== expectedEmail) {
        return false;
      }
    }
    return true;
  } catch (error) {
    logWarn('Google RTDN token verification failed', { error: `${error}` });
    return false;
  }
}

function isAuthorizedWithSharedBearer(
  request: { headers: Record<string, unknown> },
  expectedToken: string,
): boolean {
  const normalizedExpected = expectedToken.trim();
  if (normalizedExpected.length === 0) {
    logWarn('IAP webhook bearer token is not configured; rejecting request.');
    return false;
  }
  const bearer = readBearerToken(request.headers);
  if (bearer == null) {
    return false;
  }
  return secureStringEqual(bearer, normalizedExpected);
}

function readBearerToken(headers: Record<string, unknown>): string | null {
  const authHeader = headers.authorization;
  if (typeof authHeader !== 'string') {
    return null;
  }
  const [scheme, token] = authHeader.trim().split(/\s+/, 2);
  if (scheme?.toLowerCase() !== 'bearer') {
    return null;
  }
  const normalizedToken = normalizeString(token);
  return normalizedToken.length > 0 ? normalizedToken : null;
}

function secureStringEqual(left: string, right: string): boolean {
  const leftBuffer = Buffer.from(left);
  const rightBuffer = Buffer.from(right);
  if (leftBuffer.length !== rightBuffer.length) {
    return false;
  }
  return timingSafeEqual(leftBuffer, rightBuffer);
}

function normalizeRequestBody(body: unknown): Record<string, unknown> {
  if (isRecord(body)) {
    return body;
  }
  if (typeof body === 'string') {
    const parsed = safeJsonParse(body);
    return isRecord(parsed) ? parsed : {};
  }
  return {};
}

function decodeBase64Json(base64Payload: string): Record<string, unknown> {
  const decoded = Buffer.from(base64Payload, 'base64').toString('utf8');
  const parsed = safeJsonParse(decoded);
  if (!isRecord(parsed)) {
    throw new Error('Invalid Pub/Sub RTDN message payload.');
  }
  return parsed;
}

function safeJsonParse(value: string): unknown {
  try {
    return JSON.parse(value);
  } catch {
    return null;
  }
}

function readRecord(value: unknown): Record<string, unknown> | null {
  return isRecord(value) ? value : null;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return value != null && typeof value === 'object' && !Array.isArray(value);
}

function normalizeString(value: unknown): string {
  return typeof value === 'string' ? value.trim() : '';
}

function toPositiveNumber(value: unknown): number {
  if (typeof value === 'number' && Number.isFinite(value)) {
    return Math.max(0, Math.trunc(value));
  }
  if (typeof value === 'string') {
    const parsed = Number(value);
    if (Number.isFinite(parsed)) {
      return Math.max(0, Math.trunc(parsed));
    }
  }
  return 0;
}

function personalBillingScopeId(uid: string): string {
  return `user_scope__${uid.trim()}`;
}

function ownerBillingDocId(ownerUid: string): string {
  const ownerScopeId = personalBillingScopeId(ownerUid);
  return `${ownerScopeId}__${ownerUid.trim()}`;
}

function derBase64ToPem(derBase64: string): string {
  const chunks = derBase64.match(/.{1,64}/g) ?? [derBase64];
  return `-----BEGIN CERTIFICATE-----\n${chunks.join('\n')}\n-----END CERTIFICATE-----`;
}

function stableHash(source: string): string {
  return createHash('sha256').update(source).digest('hex');
}

function sha256(source: string): string {
  return createHash('sha256').update(source).digest('hex');
}

function assertCertValidity(cert: X509Certificate, now: number): void {
  const notBefore = Date.parse(cert.validFrom);
  const notAfter = Date.parse(cert.validTo);
  if (!Number.isFinite(notBefore) || !Number.isFinite(notAfter)) {
    throw new Error('Apple signing certificate validity is invalid.');
  }
  if (now < notBefore || now > notAfter) {
    throw new Error('Apple signing certificate is expired or not yet valid.');
  }
}

function fingerprintSha256(cert: X509Certificate): string {
  return createHash('sha256').update(cert.raw).digest('hex');
}
