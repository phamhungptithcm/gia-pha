import { initializeApp, applicationDefault } from 'firebase-admin/app';
import { FieldValue, getFirestore } from 'firebase-admin/firestore';

const projectId =
  process.env.FIREBASE_PROJECT_ID ||
  process.env.GOOGLE_CLOUD_PROJECT ||
  process.env.GCLOUD_PROJECT ||
  '';
const firestoreDatabaseId = readString('FIRESTORE_DATABASE_ID') || '(default)';

if (!projectId) {
  throw new Error(
    'Missing FIREBASE_PROJECT_ID (or GOOGLE_CLOUD_PROJECT/GCLOUD_PROJECT).',
  );
}

const app = initializeApp({
  credential: applicationDefault(),
  projectId,
});

const firestore = getFirestore(app, firestoreDatabaseId);
const configCollection = readString('APP_RUNTIME_CONFIG_COLLECTION') || 'runtimeConfig';
const configDocId = readString('APP_RUNTIME_CONFIG_DOC_ID') || 'global';
const configPath = `${configCollection}/${configDocId}`;

const billing = {
  ...optionalStringEntry('cardCheckoutUrlBase', 'BILLING_CARD_CHECKOUT_URL_BASE'),
  ...optionalIntEntry('pendingTimeoutMinutes', 'BILLING_PENDING_TIMEOUT_MINUTES'),
  ...optionalIntEntry('pendingTimeoutLimit', 'BILLING_PENDING_TIMEOUT_LIMIT'),
  ...optionalIntEntry('delinquencyGraceDays', 'BILLING_DELINQUENCY_GRACE_DAYS'),
  ...optionalIntEntry('delinquencyLimit', 'BILLING_DELINQUENCY_LIMIT'),
  ...optionalIntListEntry(
    'delinquencyReminderDays',
    'BILLING_DELINQUENCY_REMINDER_DAYS',
  ),
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

console.log(
  `Synced runtime config document: ${configPath} (database: ${firestoreDatabaseId}).`,
);

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

function optionalIntListEntry(targetKey, sourceEnv) {
  const raw = readString(sourceEnv);
  if (!raw) {
    return {};
  }
  const values = raw
    .split(',')
    .map((entry) => Number.parseInt(entry.trim(), 10))
    .filter((entry) => Number.isFinite(entry) && entry > 0);
  if (values.length === 0) {
    return {};
  }
  return { [targetKey]: [...new Set(values)] };
}
