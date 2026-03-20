const DEFAULT_REGION = 'asia-southeast1';
const DEFAULT_TIMEZONE = 'Asia/Ho_Chi_Minh';

function readEnvString(name: string, fallback = ''): string {
  const value = process.env[name];
  if (typeof value !== 'string') {
    return fallback;
  }
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : fallback;
}

function readEnvInt(
  name: string,
  fallback: number,
  constraints?: { min?: number; max?: number },
): number {
  const raw = readEnvString(name);
  if (raw.length === 0) {
    return fallback;
  }
  const parsed = Number.parseInt(raw, 10);
  if (!Number.isFinite(parsed)) {
    return fallback;
  }
  let value = parsed;
  if (constraints?.min != null && value < constraints.min) {
    value = constraints.min;
  }
  if (constraints?.max != null && value > constraints.max) {
    value = constraints.max;
  }
  return value;
}

function readEnvBoolean(name: string, fallback: boolean): boolean {
  const raw = readEnvString(name, '');
  if (raw.length === 0) {
    return fallback;
  }
  const normalized = raw.trim().toLowerCase();
  if (normalized === 'true' || normalized === '1' || normalized === 'yes') {
    return true;
  }
  if (normalized === 'false' || normalized === '0' || normalized === 'no') {
    return false;
  }
  return fallback;
}

function readEnvIntList(
  name: string,
  fallback: Array<number>,
  constraints?: { min?: number; max?: number },
): Array<number> {
  const raw = readEnvString(name, '');
  const source = raw.length > 0 ? raw : fallback.join(',');
  const normalized = source
    .split(',')
    .map((part) => Number.parseInt(part.trim(), 10))
    .filter((value) => Number.isFinite(value))
    .map((value) => {
      let current = value;
      if (constraints?.min != null && current < constraints.min) {
        current = constraints.min;
      }
      if (constraints?.max != null && current > constraints.max) {
        current = constraints.max;
      }
      return current;
    })
    .filter((value) => value > 0);
  if (normalized.length === 0) {
    return [...fallback];
  }
  return [...new Set(normalized)];
}

function readEnvStringList(name: string, fallback: Array<string> = []): Array<string> {
  const raw = readEnvString(name, '');
  const source = raw.length > 0 ? raw : fallback.join(',');
  const normalized = source
    .split(',')
    .map((part) => part.trim().toLowerCase())
    .filter((part) => part.length > 0);
  if (normalized.length === 0) {
    return [];
  }
  return [...new Set(normalized)];
}

export const APP_REGION = readEnvString(
  'APP_REGION',
  readEnvString('FIREBASE_FUNCTIONS_REGION', DEFAULT_REGION),
);
export const APP_TIMEZONE = readEnvString('APP_TIMEZONE', DEFAULT_TIMEZONE);
export const APP_RUNTIME_CONFIG_COLLECTION = readEnvString(
  'APP_RUNTIME_CONFIG_COLLECTION',
  'runtimeConfig',
);
export const APP_RUNTIME_CONFIG_DOC_ID = readEnvString(
  'APP_RUNTIME_CONFIG_DOC_ID',
  'global',
);

export const EXPIRE_INVITES_JOB_SCHEDULE = readEnvString(
  'EXPIRE_INVITES_JOB_SCHEDULE',
  '0 * * * *',
);
export const BILLING_SUBSCRIPTION_REMINDER_JOB_SCHEDULE = readEnvString(
  'BILLING_SUBSCRIPTION_REMINDER_JOB_SCHEDULE',
  '0 7 * * *',
);
export const BILLING_PENDING_TIMEOUT_JOB_SCHEDULE = readEnvString(
  'BILLING_PENDING_TIMEOUT_JOB_SCHEDULE',
  '*/5 * * * *',
);
export const BILLING_DELINQUENCY_JOB_SCHEDULE = readEnvString(
  'BILLING_DELINQUENCY_JOB_SCHEDULE',
  '0 8 * * *',
);
export const BILLING_CONTACT_NOTICE_JOB_SCHEDULE = readEnvString(
  'BILLING_CONTACT_NOTICE_JOB_SCHEDULE',
  '*/10 * * * *',
);
export const BILLING_PENDING_TIMEOUT_MINUTES = readEnvInt(
  'BILLING_PENDING_TIMEOUT_MINUTES',
  20,
  { min: 5, max: 240 },
);
export const BILLING_PENDING_TIMEOUT_LIMIT = readEnvInt(
  'BILLING_PENDING_TIMEOUT_LIMIT',
  800,
  { min: 50, max: 5000 },
);
export const BILLING_DELINQUENCY_GRACE_DAYS = readEnvInt(
  'BILLING_DELINQUENCY_GRACE_DAYS',
  7,
  { min: 1, max: 30 },
);
export const BILLING_DELINQUENCY_LIMIT = readEnvInt(
  'BILLING_DELINQUENCY_LIMIT',
  800,
  { min: 50, max: 5000 },
);
export const BILLING_CONTACT_NOTICE_BATCH_LIMIT = readEnvInt(
  'BILLING_CONTACT_NOTICE_BATCH_LIMIT',
  200,
  { min: 10, max: 1000 },
);
export const BILLING_DELINQUENCY_REMINDER_DAYS = readEnvIntList(
  'BILLING_DELINQUENCY_REMINDER_DAYS',
  [7, 3, 1],
  { min: 1, max: 30 },
);
export const BILLING_ALLOW_MANUAL_SETTLEMENT = readEnvBoolean(
  'BILLING_ALLOW_MANUAL_SETTLEMENT',
  false,
);
export const BILLING_QR_CHECKOUT_ENABLED = readEnvBoolean(
  'BILLING_QR_CHECKOUT_ENABLED',
  false,
);
export const BILLING_IAP_ALLOW_TEST_MOCK = readEnvBoolean(
  'BILLING_IAP_ALLOW_TEST_MOCK',
  readEnvString('FUNCTIONS_EMULATOR', 'false').toLowerCase() === 'true',
);
export const BILLING_IAP_APPLE_VERIFY_TIMEOUT_MS = readEnvInt(
  'BILLING_IAP_APPLE_VERIFY_TIMEOUT_MS',
  5000,
  { min: 1000, max: 30000 },
);
export const BILLING_IAP_APPLE_VERIFY_MAX_RETRIES = readEnvInt(
  'BILLING_IAP_APPLE_VERIFY_MAX_RETRIES',
  2,
  { min: 0, max: 6 },
);
export const BILLING_IAP_APPLE_VERIFY_BACKOFF_MS = readEnvInt(
  'BILLING_IAP_APPLE_VERIFY_BACKOFF_MS',
  350,
  { min: 50, max: 5000 },
);

export function getBillingWebhookSecret(): string {
  return readEnvString('BILLING_WEBHOOK_SECRET');
}

export function getCardWebhookSecret(): string {
  return readEnvString('CARD_WEBHOOK_SECRET', getBillingWebhookSecret());
}

export function getVnpayTmnCode(): string {
  return readEnvString('VNPAY_TMNCODE');
}

export function getVnpayHashSecret(): string {
  return readEnvString('VNPAY_HASH_SECRET');
}

export function getAppleSharedSecret(): string {
  return readEnvString('APPLE_SHARED_SECRET');
}

export function getAppleIapWebhookBearerToken(): string {
  return readEnvString('APPLE_IAP_WEBHOOK_BEARER_TOKEN', getBillingWebhookSecret());
}

export function getGooglePlayPackageName(): string {
  return readEnvString(
    'GOOGLE_PLAY_PACKAGE_NAME',
    readEnvString('PACKAGE_NAME'),
  );
}

export function getGoogleIapWebhookBearerToken(): string {
  return readEnvString('GOOGLE_IAP_WEBHOOK_BEARER_TOKEN', getBillingWebhookSecret());
}

export function getGoogleIapRtdnAudience(): string {
  return readEnvString('GOOGLE_IAP_RTDN_AUDIENCE');
}

export function getGoogleIapRtdnServiceAccountEmail(): string {
  return readEnvString('GOOGLE_IAP_RTDN_SERVICE_ACCOUNT_EMAIL').toLowerCase();
}

export const BILLING_IAP_PRODUCT_IDS_BASE = readEnvStringList(
  'BILLING_IAP_PRODUCT_IDS_BASE',
);
export const BILLING_IAP_PRODUCT_IDS_PLUS = readEnvStringList(
  'BILLING_IAP_PRODUCT_IDS_PLUS',
);
export const BILLING_IAP_PRODUCT_IDS_PRO = readEnvStringList(
  'BILLING_IAP_PRODUCT_IDS_PRO',
);
export const BILLING_IAP_IOS_PRODUCT_IDS_BASE = readEnvStringList(
  'BILLING_IAP_IOS_PRODUCT_IDS_BASE',
  BILLING_IAP_PRODUCT_IDS_BASE,
);
export const BILLING_IAP_IOS_PRODUCT_IDS_PLUS = readEnvStringList(
  'BILLING_IAP_IOS_PRODUCT_IDS_PLUS',
  BILLING_IAP_PRODUCT_IDS_PLUS,
);
export const BILLING_IAP_IOS_PRODUCT_IDS_PRO = readEnvStringList(
  'BILLING_IAP_IOS_PRODUCT_IDS_PRO',
  BILLING_IAP_PRODUCT_IDS_PRO,
);
export const BILLING_IAP_ANDROID_PRODUCT_IDS_BASE = readEnvStringList(
  'BILLING_IAP_ANDROID_PRODUCT_IDS_BASE',
  BILLING_IAP_PRODUCT_IDS_BASE,
);
export const BILLING_IAP_ANDROID_PRODUCT_IDS_PLUS = readEnvStringList(
  'BILLING_IAP_ANDROID_PRODUCT_IDS_PLUS',
  BILLING_IAP_PRODUCT_IDS_PLUS,
);
export const BILLING_IAP_ANDROID_PRODUCT_IDS_PRO = readEnvStringList(
  'BILLING_IAP_ANDROID_PRODUCT_IDS_PRO',
  BILLING_IAP_PRODUCT_IDS_PRO,
);

export const BILLING_CARD_CHECKOUT_URL_BASE = readEnvString(
  'BILLING_CARD_CHECKOUT_URL_BASE',
);
export const BILLING_VNPAY_FALLBACK_URL = readEnvString(
  'BILLING_VNPAY_FALLBACK_URL',
);
export const BILLING_VNPAY_GATEWAY_BASE_URL = readEnvString(
  'BILLING_VNPAY_GATEWAY_BASE_URL',
  'https://sandbox.vnpayment.vn/paymentv2/vpcpay.html',
);
export const BILLING_VNPAY_RETURN_URL = readEnvString('VNPAY_RETURN_URL');
export const BILLING_VNPAY_IP_ADDRESS = readEnvString(
  'BILLING_VNPAY_IP_ADDRESS',
  '127.0.0.1',
);
export const BILLING_VNPAY_LOCALE = readEnvString('BILLING_VNPAY_LOCALE', 'vn');
export const BILLING_QR_IMAGE_BASE_URL = readEnvString(
  'BILLING_QR_IMAGE_BASE_URL',
);
export const BILLING_QR_IMAGE_PLUS_URL = readEnvString(
  'BILLING_QR_IMAGE_PLUS_URL',
);
export const BILLING_QR_IMAGE_PRO_URL = readEnvString(
  'BILLING_QR_IMAGE_PRO_URL',
);
export const BILLING_CONTACT_SMS_WEBHOOK_URL = readEnvString(
  'BILLING_CONTACT_SMS_WEBHOOK_URL',
);
export const BILLING_CONTACT_EMAIL_WEBHOOK_URL = readEnvString(
  'BILLING_CONTACT_EMAIL_WEBHOOK_URL',
);

export function getBillingContactNoticeWebhookToken(): string {
  return readEnvString('BILLING_CONTACT_NOTICE_WEBHOOK_TOKEN');
}

export const CALLABLE_ENFORCE_APP_CHECK = readEnvBoolean(
  'CALLABLE_ENFORCE_APP_CHECK',
  readEnvString('FUNCTIONS_EMULATOR', 'false').toLowerCase() !== 'true',
);
