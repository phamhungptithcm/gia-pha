import { db } from '../shared/firestore';
import { logWarn } from '../shared/logger';
import {
  APP_RUNTIME_CONFIG_COLLECTION,
  APP_RUNTIME_CONFIG_DOC_ID,
  BILLING_CARD_CHECKOUT_URL_BASE,
  BILLING_PENDING_TIMEOUT_LIMIT,
  BILLING_PENDING_TIMEOUT_MINUTES,
  BILLING_VNPAY_FALLBACK_URL,
  BILLING_VNPAY_GATEWAY_BASE_URL,
  BILLING_VNPAY_IP_ADDRESS,
  BILLING_VNPAY_LOCALE,
  BILLING_VNPAY_RETURN_URL,
} from './runtime';

export type BillingRuntimeConfig = {
  cardCheckoutUrlBase: string;
  vnpayFallbackUrl: string;
  vnpayGatewayBaseUrl: string;
  vnpayReturnUrl: string;
  vnpayIpAddress: string;
  vnpayLocale: string;
  pendingTimeoutMinutes: number;
  pendingTimeoutLimit: number;
};

const runtimeConfigDocument = db
  .collection(APP_RUNTIME_CONFIG_COLLECTION)
  .doc(APP_RUNTIME_CONFIG_DOC_ID);
const CACHE_TTL_MS = 60_000;

let billingRuntimeConfigCache:
  | {
      loadedAtMs: number;
      value: BillingRuntimeConfig;
    }
  | null = null;

export async function loadBillingRuntimeConfig(): Promise<BillingRuntimeConfig> {
  const now = Date.now();
  if (
    billingRuntimeConfigCache != null &&
    now - billingRuntimeConfigCache.loadedAtMs <= CACHE_TTL_MS
  ) {
    return billingRuntimeConfigCache.value;
  }

  const defaults = buildBillingDefaults();
  let overrides: Partial<BillingRuntimeConfig> = {};

  try {
    const snapshot = await runtimeConfigDocument.get();
    if (snapshot.exists) {
      const data = asRecord(snapshot.data());
      if (data != null) {
        const billingSection = asRecord(data.billing) ?? data;
        overrides = {
          cardCheckoutUrlBase:
            normalizeUrl(readString(billingSection, 'cardCheckoutUrlBase')) ??
            normalizeUrl(readString(billingSection, 'billingCardCheckoutUrlBase')),
          vnpayFallbackUrl:
            normalizeUrl(readString(billingSection, 'vnpayFallbackUrl')) ??
            normalizeUrl(readString(billingSection, 'billingVnpayFallbackUrl')),
          vnpayGatewayBaseUrl:
            normalizeUrl(readString(billingSection, 'vnpayGatewayBaseUrl')) ??
            normalizeUrl(readString(billingSection, 'billingVnpayGatewayBaseUrl')),
          vnpayReturnUrl:
            normalizeUrl(readString(billingSection, 'vnpayReturnUrl')) ??
            normalizeUrl(readString(billingSection, 'billingVnpayReturnUrl')),
          vnpayIpAddress:
            normalizeIpAddress(readString(billingSection, 'vnpayIpAddress')) ??
            normalizeIpAddress(readString(billingSection, 'billingVnpayIpAddress')),
          vnpayLocale:
            normalizeLocale(readString(billingSection, 'vnpayLocale')) ??
            normalizeLocale(readString(billingSection, 'billingVnpayLocale')),
          pendingTimeoutMinutes:
            normalizePositiveInt(readNumber(billingSection, 'pendingTimeoutMinutes')) ??
            normalizePositiveInt(readNumber(billingSection, 'billingPendingTimeoutMinutes')),
          pendingTimeoutLimit:
            normalizePositiveInt(readNumber(billingSection, 'pendingTimeoutLimit')) ??
            normalizePositiveInt(readNumber(billingSection, 'billingPendingTimeoutLimit')),
        };
      }
    }
  } catch (error) {
    logWarn('Could not load runtimeConfig/global overrides from Firestore.', {
      error: `${error}`,
      path: `${APP_RUNTIME_CONFIG_COLLECTION}/${APP_RUNTIME_CONFIG_DOC_ID}`,
    });
  }

  const value: BillingRuntimeConfig = {
    cardCheckoutUrlBase: overrides.cardCheckoutUrlBase ?? defaults.cardCheckoutUrlBase,
    vnpayFallbackUrl: overrides.vnpayFallbackUrl ?? defaults.vnpayFallbackUrl,
    vnpayGatewayBaseUrl: overrides.vnpayGatewayBaseUrl ?? defaults.vnpayGatewayBaseUrl,
    vnpayReturnUrl: overrides.vnpayReturnUrl ?? defaults.vnpayReturnUrl,
    vnpayIpAddress: overrides.vnpayIpAddress ?? defaults.vnpayIpAddress,
    vnpayLocale: overrides.vnpayLocale ?? defaults.vnpayLocale,
    pendingTimeoutMinutes: clamp(
      overrides.pendingTimeoutMinutes ?? defaults.pendingTimeoutMinutes,
      5,
      240,
    ),
    pendingTimeoutLimit: clamp(
      overrides.pendingTimeoutLimit ?? defaults.pendingTimeoutLimit,
      50,
      5000,
    ),
  };

  billingRuntimeConfigCache = {
    loadedAtMs: now,
    value,
  };
  return value;
}

function buildBillingDefaults(): BillingRuntimeConfig {
  return {
    cardCheckoutUrlBase: normalizeUrl(BILLING_CARD_CHECKOUT_URL_BASE) ?? '',
    vnpayFallbackUrl: normalizeUrl(BILLING_VNPAY_FALLBACK_URL) ?? '',
    vnpayGatewayBaseUrl:
      normalizeUrl(BILLING_VNPAY_GATEWAY_BASE_URL) ??
      'https://sandbox.vnpayment.vn/paymentv2/vpcpay.html',
    vnpayReturnUrl: normalizeUrl(BILLING_VNPAY_RETURN_URL) ?? '',
    vnpayIpAddress: normalizeIpAddress(BILLING_VNPAY_IP_ADDRESS) ?? '127.0.0.1',
    vnpayLocale: normalizeLocale(BILLING_VNPAY_LOCALE) ?? 'vn',
    pendingTimeoutMinutes: clamp(BILLING_PENDING_TIMEOUT_MINUTES, 5, 240),
    pendingTimeoutLimit: clamp(BILLING_PENDING_TIMEOUT_LIMIT, 50, 5000),
  };
}

function asRecord(value: unknown): Record<string, unknown> | null {
  if (value == null || typeof value !== 'object') {
    return null;
  }
  return value as Record<string, unknown>;
}

function readString(data: Record<string, unknown>, key: string): string | null {
  const value = data[key];
  if (typeof value !== 'string') {
    return null;
  }
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}

function readNumber(data: Record<string, unknown>, key: string): number | null {
  const value = data[key];
  if (typeof value === 'number' && Number.isFinite(value)) {
    return value;
  }
  if (typeof value === 'string') {
    const parsed = Number.parseInt(value.trim(), 10);
    return Number.isFinite(parsed) ? parsed : null;
  }
  return null;
}

function normalizeUrl(value: string | null): string | undefined {
  if (value == null) {
    return undefined;
  }
  try {
    const url = new URL(value);
    if (url.protocol !== 'https:' && url.protocol !== 'http:') {
      return undefined;
    }
    return url.toString();
  } catch {
    return undefined;
  }
}

function normalizeIpAddress(value: string | null): string | undefined {
  if (value == null) {
    return undefined;
  }
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : undefined;
}

function normalizeLocale(value: string | null): string | undefined {
  if (value == null) {
    return undefined;
  }
  const normalized = value.trim().toLowerCase();
  if (normalized.length < 2) {
    return undefined;
  }
  return normalized;
}

function normalizePositiveInt(value: number | null): number | undefined {
  if (value == null) {
    return undefined;
  }
  const normalized = Math.trunc(value);
  if (!Number.isFinite(normalized) || normalized <= 0) {
    return undefined;
  }
  return normalized;
}

function clamp(value: number, min: number, max: number): number {
  if (value < min) {
    return min;
  }
  if (value > max) {
    return max;
  }
  return value;
}
