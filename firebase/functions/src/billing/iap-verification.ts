import { createHash } from 'node:crypto';

import { HttpsError } from 'firebase-functions/v2/https';
import { google } from 'googleapis';

import {
  BILLING_IAP_ANDROID_PRODUCT_IDS_BASE,
  BILLING_IAP_ANDROID_PRODUCT_IDS_PLUS,
  BILLING_IAP_ANDROID_PRODUCT_IDS_PRO,
  BILLING_IAP_APPLE_VERIFY_BACKOFF_MS,
  BILLING_IAP_APPLE_VERIFY_MAX_RETRIES,
  BILLING_IAP_APPLE_VERIFY_TIMEOUT_MS,
  BILLING_IAP_ALLOW_TEST_MOCK,
  BILLING_IAP_IOS_PRODUCT_IDS_BASE,
  BILLING_IAP_IOS_PRODUCT_IDS_PLUS,
  BILLING_IAP_IOS_PRODUCT_IDS_PRO,
  BILLING_IAP_PRODUCT_IDS_BASE,
  BILLING_IAP_PRODUCT_IDS_PLUS,
  BILLING_IAP_PRODUCT_IDS_PRO,
  getAppleSharedSecret,
  getGooglePlayPackageName,
} from '../config/runtime';
import type { BillingPlanCode } from './pricing';
import { logWarn } from '../shared/logger';

const APPLE_VERIFY_PRODUCTION_URL = 'https://buy.itunes.apple.com/verifyReceipt';
const APPLE_VERIFY_SANDBOX_URL = 'https://sandbox.itunes.apple.com/verifyReceipt';
const GOOGLE_PLAY_ANDROID_PUBLISHER_SCOPE =
  'https://www.googleapis.com/auth/androidpublisher';

export type IapPlatform = 'ios' | 'android';

export type VerifiedStorePurchase = {
  platform: IapPlatform;
  productId: string;
  planCode: BillingPlanCode;
  status: 'active' | 'expired';
  expiresAtMs: number;
  externalTransactionId: string;
  lineageKey: string;
  storeTransactionKey: string;
  idempotencyKey: string;
  sourcePayload: Record<string, unknown>;
};

export function normalizeIapPlatform(value: unknown): IapPlatform {
  const normalized = normalizeString(value).toLowerCase();
  if (normalized === 'ios' || normalized === 'apple') {
    return 'ios';
  }
  if (normalized === 'android' || normalized === 'google_play') {
    return 'android';
  }
  throw new HttpsError(
    'invalid-argument',
    'platform must be "ios" or "android".',
  );
}

export function resolvePlanCodeForIapProductId(
  productId: string,
  platform?: IapPlatform,
): BillingPlanCode | null {
  const normalized = normalizeProductId(productId);
  if (normalized.length === 0) {
    return null;
  }
  const catalog = loadIapProductCatalog();
  if (platform != null) {
    return catalog.productIdToPlanCodeByPlatform[platform][normalized] ?? null;
  }
  return (
    catalog.productIdToPlanCodeByPlatform.ios[normalized] ??
    catalog.productIdToPlanCodeByPlatform.android[normalized] ??
    null
  );
}

export function resolveStoreProductIdForPlanCode(
  planCode: BillingPlanCode,
  platform?: IapPlatform,
): string | null {
  const catalog = loadIapProductCatalog();
  if (platform != null) {
    return catalog.primaryProductIdByPlanByPlatform[platform][planCode] ?? null;
  }
  return (
    catalog.primaryProductIdByPlanByPlatform.ios[planCode] ??
    catalog.primaryProductIdByPlanByPlatform.android[planCode] ??
    null
  );
}

export function resolveStoreProductIdsByPlan(): Partial<
  Record<BillingPlanCode, { ios?: string; android?: string }>
> {
  const catalog = loadIapProductCatalog();
  const output: Partial<Record<BillingPlanCode, { ios?: string; android?: string }>> = {};
  for (const planCode of ['BASE', 'PLUS', 'PRO'] as const) {
    const ios = catalog.primaryProductIdByPlanByPlatform.ios[planCode];
    const android = catalog.primaryProductIdByPlanByPlatform.android[planCode];
    if (ios == null && android == null) {
      continue;
    }
    output[planCode] = {
      ...(ios != null ? { ios } : {}),
      ...(android != null ? { android } : {}),
    };
  }
  return output;
}

export async function verifyInAppStorePurchase({
  platform,
  payload,
}: {
  platform: IapPlatform;
  payload: Record<string, unknown>;
}): Promise<VerifiedStorePurchase> {
  if (BILLING_IAP_ALLOW_TEST_MOCK && readBoolean(payload.mock, false)) {
    return buildMockPurchase(platform, payload);
  }

  if (platform === 'ios') {
    return verifyApplePurchase(payload);
  }
  return verifyGooglePlayPurchase(payload);
}

async function verifyGooglePlayPurchase(
  payload: Record<string, unknown>,
): Promise<VerifiedStorePurchase> {
  const purchaseToken =
    normalizeString(payload.purchaseToken) ||
    normalizeString(payload.verificationData) ||
    normalizeString(payload.token);
  if (purchaseToken.length === 0) {
    throw new HttpsError(
      'invalid-argument',
      'Google Play purchaseToken is required.',
    );
  }

  const productId = normalizeProductId(
    normalizeString(payload.productId) || normalizeString(payload.subscriptionId),
  );
  if (productId.length === 0) {
    throw new HttpsError(
      'invalid-argument',
      'Google Play productId is required.',
    );
  }
  const planCode = resolvePlanCodeForIapProductId(productId, 'android');
  if (planCode == null) {
    throw new HttpsError(
      'failed-precondition',
      `Unsupported Google Play productId "${productId}".`,
    );
  }

  const configuredPackageName = getGooglePlayPackageName();
  if (configuredPackageName.length === 0) {
    throw new HttpsError(
      'failed-precondition',
      'GOOGLE_PLAY_PACKAGE_NAME is missing.',
    );
  }
  const payloadPackageName = normalizeString(payload.packageName);
  if (
    payloadPackageName.length > 0 &&
    payloadPackageName !== configuredPackageName
  ) {
    throw new HttpsError(
      'invalid-argument',
      'Google Play packageName does not match configured package.',
    );
  }
  const packageName = configuredPackageName;

  try {
    const auth = new google.auth.GoogleAuth({
      scopes: [GOOGLE_PLAY_ANDROID_PUBLISHER_SCOPE],
    });
    const androidPublisher = google.androidpublisher({
      version: 'v3',
      auth,
    });
    const response = await androidPublisher.purchases.subscriptions.get({
      packageName,
      subscriptionId: productId,
      token: purchaseToken,
    });
    const expiresAtMs = toPositiveNumber(response.data.expiryTimeMillis);
    const status: VerifiedStorePurchase['status'] =
      expiresAtMs > Date.now() ? 'active' : 'expired';
    const externalTransactionId =
      normalizeString(response.data.orderId) ||
      normalizeString(payload.purchaseId) ||
      purchaseToken.slice(0, 32);
    const lineageKey = stableHash(`google_play:${productId}:${purchaseToken}`);
    const storeTransactionKey = stableHash(
      `google_play:${productId}:${externalTransactionId}`,
    );
    return {
      platform: 'android',
      productId,
      planCode,
      status,
      expiresAtMs,
      externalTransactionId,
      lineageKey,
      storeTransactionKey,
      idempotencyKey: stableHash(
        `google_play:${productId}:${purchaseToken}:${externalTransactionId}`,
      ),
      sourcePayload: {
        packageName,
        paymentState: response.data.paymentState ?? null,
        expiryTimeMillis: response.data.expiryTimeMillis ?? null,
        cancelReason: response.data.cancelReason ?? null,
        orderId: response.data.orderId ?? null,
        purchaseTokenHash: stableHash(`purchaseToken:${purchaseToken}`),
      },
    };
  } catch (error) {
    logWarn('Google Play receipt verification failed', {
      error: `${error}`,
      productId,
    });
    throw new HttpsError(
      'failed-precondition',
      'Google Play verification failed. Please retry shortly.',
    );
  }
}

async function verifyApplePurchase(
  payload: Record<string, unknown>,
): Promise<VerifiedStorePurchase> {
  const receiptData =
    normalizeString(payload.receiptData) ||
    normalizeString(payload.receipt) ||
    normalizeString(payload.verificationData);
  if (receiptData.length === 0) {
    throw new HttpsError(
      'invalid-argument',
      'Apple receipt data is required.',
    );
  }
  const sharedSecret = getAppleSharedSecret();
  if (sharedSecret.length === 0) {
    throw new HttpsError(
      'failed-precondition',
      'APPLE_SHARED_SECRET is missing.',
    );
  }

  const basePayload = {
    'receipt-data': receiptData,
    password: sharedSecret,
    'exclude-old-transactions': true,
  };
  try {
    let verification = await postAppleReceipt(
      APPLE_VERIFY_PRODUCTION_URL,
      basePayload,
    );
    if (toNumber(verification.status) === 21007) {
      verification = await postAppleReceipt(APPLE_VERIFY_SANDBOX_URL, basePayload);
    }

    const receiptInfo = selectLatestAppleReceiptInfo(verification);
    const responseProductId = normalizeProductId(
      normalizeString(receiptInfo.product_id),
    );
    const payloadProductId = normalizeProductId(normalizeString(payload.productId));
    const productId = responseProductId || payloadProductId;
    if (productId.length === 0) {
      throw new HttpsError(
        'failed-precondition',
        'Could not resolve Apple productId from receipt.',
      );
    }
    const planCode = resolvePlanCodeForIapProductId(productId, 'ios');
    if (planCode == null) {
      throw new HttpsError(
        'failed-precondition',
        `Unsupported Apple productId "${productId}".`,
      );
    }

    const expiresAtMs = toPositiveNumber(receiptInfo.expires_date_ms);
    const status: VerifiedStorePurchase['status'] =
      expiresAtMs > Date.now() ? 'active' : 'expired';
    const externalTransactionId =
      normalizeString(receiptInfo.original_transaction_id) ||
      normalizeString(receiptInfo.transaction_id) ||
      stableHash(`ios:${productId}:${receiptData}`).slice(0, 32);
    const lineageSource =
      normalizeString(receiptInfo.original_transaction_id) ||
      externalTransactionId;
    const storeTransactionSource =
      normalizeString(receiptInfo.transaction_id) ||
      normalizeString(receiptInfo.original_transaction_id) ||
      externalTransactionId;

    return {
      platform: 'ios',
      productId,
      planCode,
      status,
      expiresAtMs,
      externalTransactionId,
      lineageKey: stableHash(`apple_iap:${productId}:${lineageSource}`),
      storeTransactionKey: stableHash(
        `apple_iap:${productId}:${storeTransactionSource}`,
      ),
      idempotencyKey: stableHash(
        `apple_iap:${productId}:${externalTransactionId}:${expiresAtMs}`,
      ),
      sourcePayload: {
        environment: normalizeString(verification.environment),
        status: toNumber(verification.status),
        transactionId: normalizeString(receiptInfo.transaction_id),
        originalTransactionId: normalizeString(
          receiptInfo.original_transaction_id,
        ),
        expiresDateMs: receiptInfo.expires_date_ms,
      },
    };
  } catch (error) {
    if (error instanceof HttpsError) {
      throw error;
    }
    logWarn('Apple receipt verification failed', {
      error: `${error}`,
    });
    throw new HttpsError(
      'failed-precondition',
      'Apple verification failed. Please retry shortly.',
    );
  }
}

async function postAppleReceipt(
  url: string,
  payload: Record<string, unknown>,
): Promise<Record<string, unknown>> {
  const bodyText = JSON.stringify(payload);
  const maxRetries = Math.max(0, BILLING_IAP_APPLE_VERIFY_MAX_RETRIES);
  let attempt = 0;
  let lastError: unknown = null;
  while (attempt <= maxRetries) {
    const controller = new AbortController();
    const timeout = setTimeout(
      () => controller.abort(),
      BILLING_IAP_APPLE_VERIFY_TIMEOUT_MS,
    );
    try {
      const response = await fetch(url, {
        method: 'POST',
        headers: {
          'content-type': 'application/json',
        },
        body: bodyText,
        signal: controller.signal,
      });
      if (!response.ok) {
        if (attempt < maxRetries && response.status >= 500) {
          attempt += 1;
          await sleep(BILLING_IAP_APPLE_VERIFY_BACKOFF_MS * attempt);
          continue;
        }
        throw new Error(`Apple verifyReceipt failed with HTTP ${response.status}`);
      }
      const body = (await response.json()) as Record<string, unknown>;
      return body;
    } catch (error) {
      lastError = error;
      if (attempt >= maxRetries || !isRetriableNetworkError(error)) {
        break;
      }
      attempt += 1;
      await sleep(BILLING_IAP_APPLE_VERIFY_BACKOFF_MS * attempt);
    } finally {
      clearTimeout(timeout);
    }
  }
  throw new Error(`Apple verifyReceipt unavailable: ${lastError}`);
}

function selectLatestAppleReceiptInfo(
  response: Record<string, unknown>,
): Record<string, unknown> {
  const latestReceiptInfo = Array.isArray(response.latest_receipt_info)
    ? response.latest_receipt_info
    : [];
  const candidates = latestReceiptInfo
    .filter((entry): entry is Record<string, unknown> => isRecord(entry))
    .map((entry) => ({
      entry,
      expiresAtMs: toPositiveNumber(entry.expires_date_ms),
    }))
    .sort((left, right) => right.expiresAtMs - left.expiresAtMs);
  if (candidates.length > 0) {
    return candidates[0].entry;
  }
  const receipt = isRecord(response.receipt) ? response.receipt : {};
  const inApp = Array.isArray(receipt.in_app) ? receipt.in_app : [];
  const inAppCandidates = inApp
    .filter((entry): entry is Record<string, unknown> => isRecord(entry))
    .map((entry) => ({
      entry,
      expiresAtMs: toPositiveNumber(entry.expires_date_ms),
    }))
    .sort((left, right) => right.expiresAtMs - left.expiresAtMs);
  return inAppCandidates[0]?.entry ?? {};
}

function buildMockPurchase(
  platform: IapPlatform,
  payload: Record<string, unknown>,
): VerifiedStorePurchase {
  const productId = normalizeProductId(normalizeString(payload.productId));
  const planCode = resolvePlanCodeForIapProductId(productId, platform);
  if (planCode == null) {
    throw new HttpsError(
      'invalid-argument',
      `mock productId "${productId}" is not supported.`,
    );
  }
  const expiresAtMs = Date.now() + 365 * 24 * 60 * 60 * 1000;
  const externalTransactionId =
    normalizeString(payload.purchaseId) ||
    `mock-${platform}-${productId}-${Date.now()}`;
  return {
    platform,
    productId,
    planCode,
    status: 'active',
    expiresAtMs,
    externalTransactionId,
    lineageKey: stableHash(`mock:${platform}:${productId}:lineage`),
    storeTransactionKey: stableHash(
      `mock:${platform}:${productId}:${externalTransactionId}`,
    ),
    idempotencyKey: stableHash(
      `mock:${platform}:${productId}:${externalTransactionId}`,
    ),
    sourcePayload: {
      mock: true,
    },
  };
}

function normalizeProductId(value: string): string {
  return value.trim().toLowerCase();
}

function normalizeString(value: unknown): string {
  if (typeof value !== 'string') {
    return '';
  }
  return value.trim();
}

function readBoolean(value: unknown, fallback: boolean): boolean {
  if (typeof value === 'boolean') {
    return value;
  }
  if (typeof value === 'string') {
    const normalized = value.trim().toLowerCase();
    if (normalized === 'true' || normalized === '1' || normalized === 'yes') {
      return true;
    }
    if (normalized === 'false' || normalized === '0' || normalized === 'no') {
      return false;
    }
  }
  return fallback;
}

function isRetriableNetworkError(error: unknown): boolean {
  const message = `${error}`.toLowerCase();
  return (
    message.includes('timeout') ||
    message.includes('aborted') ||
    message.includes('network') ||
    message.includes('fetch failed') ||
    message.includes('econnreset') ||
    message.includes('etimedout')
  );
}

async function sleep(ms: number): Promise<void> {
  await new Promise((resolve) => setTimeout(resolve, Math.max(0, ms)));
}

function stableHash(source: string): string {
  return createHash('sha256').update(source).digest('hex');
}

function toNumber(value: unknown): number {
  if (typeof value === 'number' && Number.isFinite(value)) {
    return value;
  }
  if (typeof value === 'string') {
    const parsed = Number(value);
    if (Number.isFinite(parsed)) {
      return parsed;
    }
  }
  return 0;
}

function toPositiveNumber(value: unknown): number {
  return Math.max(0, Math.trunc(toNumber(value)));
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return value != null && typeof value === 'object' && !Array.isArray(value);
}

type IapProductCatalog = {
  productIdToPlanCodeByPlatform: Record<IapPlatform, Record<string, BillingPlanCode>>;
  primaryProductIdByPlanByPlatform: Record<
    IapPlatform,
    Partial<Record<BillingPlanCode, string>>
  >;
};

let cachedCatalog: IapProductCatalog | null = null;
let cachedCatalogSignature: string | null = null;

function loadIapProductCatalog(): IapProductCatalog {
  const sourceSignature = [
    BILLING_IAP_IOS_PRODUCT_IDS_BASE.join(','),
    BILLING_IAP_IOS_PRODUCT_IDS_PLUS.join(','),
    BILLING_IAP_IOS_PRODUCT_IDS_PRO.join(','),
    BILLING_IAP_ANDROID_PRODUCT_IDS_BASE.join(','),
    BILLING_IAP_ANDROID_PRODUCT_IDS_PLUS.join(','),
    BILLING_IAP_ANDROID_PRODUCT_IDS_PRO.join(','),
    BILLING_IAP_PRODUCT_IDS_BASE.join(','),
    BILLING_IAP_PRODUCT_IDS_PLUS.join(','),
    BILLING_IAP_PRODUCT_IDS_PRO.join(','),
  ].join('|');
  if (cachedCatalog != null && cachedCatalogSignature === sourceSignature) {
    return cachedCatalog;
  }
  const productIdToPlanCodeByPlatform: Record<
    IapPlatform,
    Record<string, BillingPlanCode>
  > = {
    ios: {},
    android: {},
  };
  const primaryProductIdByPlanByPlatform: Record<
    IapPlatform,
    Partial<Record<BillingPlanCode, string>>
  > = {
    ios: {},
    android: {},
  };

  registerPlanProductIds('ios', 'BASE', BILLING_IAP_IOS_PRODUCT_IDS_BASE);
  registerPlanProductIds('ios', 'PLUS', BILLING_IAP_IOS_PRODUCT_IDS_PLUS);
  registerPlanProductIds('ios', 'PRO', BILLING_IAP_IOS_PRODUCT_IDS_PRO);

  registerPlanProductIds('android', 'BASE', BILLING_IAP_ANDROID_PRODUCT_IDS_BASE);
  registerPlanProductIds('android', 'PLUS', BILLING_IAP_ANDROID_PRODUCT_IDS_PLUS);
  registerPlanProductIds('android', 'PRO', BILLING_IAP_ANDROID_PRODUCT_IDS_PRO);

  // Backward compatibility for old shared product-id env variables.
  registerPlanProductIds('ios', 'BASE', BILLING_IAP_PRODUCT_IDS_BASE);
  registerPlanProductIds('ios', 'PLUS', BILLING_IAP_PRODUCT_IDS_PLUS);
  registerPlanProductIds('ios', 'PRO', BILLING_IAP_PRODUCT_IDS_PRO);
  registerPlanProductIds('android', 'BASE', BILLING_IAP_PRODUCT_IDS_BASE);
  registerPlanProductIds('android', 'PLUS', BILLING_IAP_PRODUCT_IDS_PLUS);
  registerPlanProductIds('android', 'PRO', BILLING_IAP_PRODUCT_IDS_PRO);

  cachedCatalog = {
    productIdToPlanCodeByPlatform,
    primaryProductIdByPlanByPlatform,
  };
  cachedCatalogSignature = sourceSignature;
  return cachedCatalog;

  function registerPlanProductIds(
    platform: IapPlatform,
    planCode: BillingPlanCode,
    productIds: Array<string>,
  ): void {
    const normalizedIds = productIds
      .map((entry) => normalizeProductId(entry))
      .filter((entry) => entry.length > 0);
    if (normalizedIds.length === 0) {
      return;
    }
    if (primaryProductIdByPlanByPlatform[platform][planCode] == null) {
      primaryProductIdByPlanByPlatform[platform][planCode] = normalizedIds[0];
    }
    for (const productId of normalizedIds) {
      const existingPlanCode =
        productIdToPlanCodeByPlatform[platform][productId];
      if (existingPlanCode != null && existingPlanCode !== planCode) {
        throw new HttpsError(
          'failed-precondition',
          `IAP ${platform} productId "${productId}" is mapped to multiple plans (${existingPlanCode}, ${planCode}).`,
        );
      }
      productIdToPlanCodeByPlatform[platform][productId] = planCode;
    }
  }
}
