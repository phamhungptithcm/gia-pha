import { initializeApp, applicationDefault } from 'firebase-admin/app';
import { FieldValue, getFirestore } from 'firebase-admin/firestore';

const projectId =
  process.env.FIREBASE_PROJECT_ID ||
  process.env.GOOGLE_CLOUD_PROJECT ||
  process.env.GCLOUD_PROJECT ||
  '';

if (!projectId) {
  throw new Error(
    'Missing FIREBASE_PROJECT_ID (or GOOGLE_CLOUD_PROJECT/GCLOUD_PROJECT).',
  );
}

initializeApp({
  credential: applicationDefault(),
  projectId,
});

const firestore = getFirestore();
const configCollection = readString('APP_RUNTIME_CONFIG_COLLECTION') || 'runtimeConfig';
const configDocId = readString('APP_RUNTIME_CONFIG_DOC_ID') || 'global';
const configPath = `${configCollection}/${configDocId}`;

const billing = {
  ...optionalStringEntry('cardCheckoutUrlBase', 'BILLING_CARD_CHECKOUT_URL_BASE'),
  ...optionalStringEntry('vnpayFallbackUrl', 'BILLING_VNPAY_FALLBACK_URL'),
  ...optionalStringEntry('vnpayGatewayBaseUrl', 'BILLING_VNPAY_GATEWAY_BASE_URL'),
  ...optionalStringEntry('vnpayReturnUrl', 'VNPAY_RETURN_URL'),
  ...optionalStringEntry('vnpayIpAddress', 'BILLING_VNPAY_IP_ADDRESS'),
  ...optionalStringEntry('vnpayLocale', 'BILLING_VNPAY_LOCALE'),
  ...optionalBoolEntry('qrCheckoutEnabled', 'BILLING_QR_CHECKOUT_ENABLED'),
  ...optionalStringEntry('qrImageBaseUrl', 'BILLING_QR_IMAGE_BASE_URL'),
  ...optionalStringEntry('qrImagePlusUrl', 'BILLING_QR_IMAGE_PLUS_URL'),
  ...optionalStringEntry('qrImageProUrl', 'BILLING_QR_IMAGE_PRO_URL'),
  ...optionalIntEntry('pendingTimeoutMinutes', 'BILLING_PENDING_TIMEOUT_MINUTES'),
  ...optionalIntEntry('pendingTimeoutLimit', 'BILLING_PENDING_TIMEOUT_LIMIT'),
};

if (Object.keys(billing).length === 0) {
  console.log(
    `No runtime override values found. Skipping Firestore sync for ${configPath}.`,
  );
  process.exit(0);
}

await firestore.collection(configCollection).doc(configDocId).set(
  {
    billing,
    updatedAt: FieldValue.serverTimestamp(),
    updatedBy: 'ci:deploy-firebase',
  },
  { merge: true },
);

console.log(`Synced runtime config document: ${configPath}`);

function readString(name) {
  const value = process.env[name];
  if (typeof value !== 'string') {
    return '';
  }
  return value.trim();
}

function optionalStringEntry(targetKey, sourceEnv) {
  const value = readString(sourceEnv);
  if (!value) {
    return {};
  }
  return { [targetKey]: value };
}

function optionalIntEntry(targetKey, sourceEnv) {
  const raw = readString(sourceEnv);
  if (!raw) {
    return {};
  }
  const parsed = Number.parseInt(raw, 10);
  if (!Number.isFinite(parsed)) {
    return {};
  }
  return { [targetKey]: parsed };
}

function optionalBoolEntry(targetKey, sourceEnv) {
  const raw = readString(sourceEnv);
  if (!raw) {
    return {};
  }
  const normalized = raw.toLowerCase();
  if (normalized === 'true' || normalized === '1' || normalized === 'yes') {
    return { [targetKey]: true };
  }
  if (normalized === 'false' || normalized === '0' || normalized === 'no') {
    return { [targetKey]: false };
  }
  return {};
}
