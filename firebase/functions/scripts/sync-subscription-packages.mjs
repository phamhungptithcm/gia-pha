import { initializeApp, applicationDefault, getApps } from 'firebase-admin/app';
import { FieldValue, getFirestore } from 'firebase-admin/firestore';
import fs from 'node:fs/promises';
import path from 'node:path';
import process from 'node:process';
import { fileURLToPath } from 'node:url';

const REQUIRED_PLAN_ORDER = ['FREE', 'BASE', 'PLUS', 'PRO'];
const checkOnly = process.argv.includes('--check-only');
const apply = process.argv.includes('--apply') || !checkOnly;
const explicitCatalogPath = readArg('--catalog=');
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const defaultCatalogPath = path.resolve(
  __dirname,
  '..',
  'config',
  'subscription-packages.catalog.json',
);

const projectId =
  process.env.FIREBASE_PROJECT_ID ||
  process.env.GOOGLE_CLOUD_PROJECT ||
  process.env.GCLOUD_PROJECT ||
  '';
const firestoreDatabaseId = readEnvString('FIRESTORE_DATABASE_ID') || '(default)';

if (!projectId) {
  throw new Error(
    'Missing FIREBASE_PROJECT_ID (or GOOGLE_CLOUD_PROJECT/GCLOUD_PROJECT).',
  );
}

const app =
  getApps()[0] ??
  initializeApp({
    credential: applicationDefault(),
    projectId,
  });

const db = getFirestore(app, firestoreDatabaseId);
const collection = db.collection('subscriptionPackages');

try {
  if (apply) {
    const catalogPath = explicitCatalogPath
      ? path.resolve(process.cwd(), explicitCatalogPath)
      : defaultCatalogPath;
    const catalog = await loadCatalog(catalogPath);
    const normalizedCatalog = normalizeAndValidate(catalog, 'catalog');
    await upsertCatalog(normalizedCatalog, collection);
    console.log(
      `Synced ${normalizedCatalog.length} subscriptionPackages docs from ${catalogPath} (database: ${firestoreDatabaseId}).`,
    );
  }

  const activeDocs = await readActiveDocs(collection);
  const normalizedActiveDocs = normalizeAndValidate(activeDocs, 'firestore');
  console.log(
    `subscriptionPackages check passed (${normalizedActiveDocs.length} active plans, database: ${firestoreDatabaseId}).`,
  );
} catch (error) {
  const message = normalizeErrorMessage(error);
  console.error(message);
  process.exit(1);
}

function readArg(prefix) {
  const match = process.argv.find((arg) => arg.startsWith(prefix));
  return match ? match.slice(prefix.length) : '';
}

function readEnvString(name) {
  const value = process.env[name];
  if (typeof value !== 'string') {
    return '';
  }
  return value.trim();
}

async function loadCatalog(catalogPath) {
  const raw = await fs.readFile(catalogPath, 'utf8');
  const parsed = JSON.parse(raw);
  if (!Array.isArray(parsed)) {
    throw new Error('Catalog JSON must be an array of subscription packages.');
  }
  return parsed;
}

async function upsertCatalog(plans, collectionRef) {
  const batch = db.batch();
  for (const plan of plans) {
    const payload = {
      ...plan,
      updatedAt: FieldValue.serverTimestamp(),
      updatedBy: 'ci:sync-subscription-packages',
    };
    batch.set(collectionRef.doc(plan.id), payload, { merge: true });
  }
  await batch.commit();
}

async function readActiveDocs(collectionRef) {
  const activeSnapshot = await collectionRef.where('isActive', '==', true).get();
  if (!activeSnapshot.empty) {
    return activeSnapshot.docs.map((doc) => ({ id: doc.id, ...doc.data() }));
  }
  const fallbackSnapshot = await collectionRef.limit(50).get();
  return fallbackSnapshot.docs.map((doc) => ({ id: doc.id, ...doc.data() }));
}

function normalizeAndValidate(input, sourceLabel) {
  const entries = input.map((value) => normalizeEntry(value, sourceLabel));
  const activeEntries = entries.filter((entry) => entry.isActive);
  if (activeEntries.length === 0) {
    throw new Error(
      `${sourceLabel}: missing active subscriptionPackages docs. Required plans: ${REQUIRED_PLAN_ORDER.join(', ')}.`,
    );
  }

  const byPlan = new Map();
  for (const entry of activeEntries) {
    const existing = byPlan.get(entry.planCode);
    if (existing) {
      throw new Error(
        `${sourceLabel}: duplicate active planCode ${entry.planCode} (docs: ${existing.id}, ${entry.id}).`,
      );
    }
    byPlan.set(entry.planCode, entry);
  }

  const missingPlans = REQUIRED_PLAN_ORDER.filter((planCode) => !byPlan.has(planCode));
  if (missingPlans.length > 0) {
    throw new Error(
      `${sourceLabel}: missing active plans ${missingPlans.join(', ')} in subscriptionPackages.`,
    );
  }

  const ordered = REQUIRED_PLAN_ORDER.map((planCode) => byPlan.get(planCode));
  validateTierStructure(ordered, sourceLabel);
  return ordered;
}

function normalizeEntry(raw, sourceLabel) {
  const id = normalizeString(raw.id || raw.planCode);
  const planCode = normalizePlanCode(raw.planCode, sourceLabel, id);
  const minMembers = toNonNegativeInt(raw.minMembers, `${sourceLabel}:${id}.minMembers`);
  const maxMembers = toNullableNonNegativeInt(
    raw.maxMembers,
    `${sourceLabel}:${id}.maxMembers`,
  );
  const priceVndYear = toNonNegativeInt(
    raw.priceVndYear,
    `${sourceLabel}:${id}.priceVndYear`,
  );
  const vatIncluded = toBoolean(raw.vatIncluded, `${sourceLabel}:${id}.vatIncluded`);
  const showAds = toBoolean(raw.showAds, `${sourceLabel}:${id}.showAds`);
  const adFree = toBoolean(raw.adFree, `${sourceLabel}:${id}.adFree`);
  const isActive = raw.isActive == null ? true : toBoolean(raw.isActive, `${sourceLabel}:${id}.isActive`);

  if (showAds === adFree) {
    throw new Error(
      `${sourceLabel}:${id} must set showAds/adFree consistently (one true, one false).`,
    );
  }

  const normalized = {
    ...raw,
    id,
    planCode,
    minMembers,
    maxMembers,
    priceVndYear,
    vatIncluded,
    showAds,
    adFree,
    isActive,
    currency: normalizeString(raw.currency || 'VND') || 'VND',
    billingCycle: normalizeString(raw.billingCycle || 'yearly') || 'yearly',
  };

  return normalized;
}

function validateTierStructure(ordered, sourceLabel) {
  for (let i = 0; i < ordered.length; i += 1) {
    const current = ordered[i];
    if (i === ordered.length - 1) {
      if (current.maxMembers != null && current.maxMembers < current.minMembers) {
        throw new Error(
          `${sourceLabel}:${current.id} maxMembers must be >= minMembers or null for terminal plan.`,
        );
      }
      continue;
    }

    const next = ordered[i + 1];
    if (current.maxMembers == null) {
      throw new Error(
        `${sourceLabel}:${current.id} maxMembers cannot be null before terminal plan.`,
      );
    }
    if (current.maxMembers < current.minMembers) {
      throw new Error(
        `${sourceLabel}:${current.id} maxMembers must be >= minMembers.`,
      );
    }
    if (next.minMembers !== current.maxMembers + 1) {
      throw new Error(
        `${sourceLabel}: tier gap/overlap between ${current.planCode} and ${next.planCode}. Expected ${next.planCode}.minMembers=${current.maxMembers + 1}, received ${next.minMembers}.`,
      );
    }
  }
}

function normalizePlanCode(value, sourceLabel, id) {
  const code = normalizeString(value).toUpperCase();
  if (!REQUIRED_PLAN_ORDER.includes(code)) {
    throw new Error(
      `${sourceLabel}:${id} invalid planCode "${value}". Allowed: ${REQUIRED_PLAN_ORDER.join(', ')}.`,
    );
  }
  return code;
}

function normalizeString(value) {
  if (typeof value !== 'string') {
    return '';
  }
  return value.trim();
}

function toNonNegativeInt(value, fieldPath) {
  if (typeof value === 'number' && Number.isFinite(value)) {
    const normalized = Math.trunc(value);
    if (normalized < 0) {
      throw new Error(`${fieldPath} must be >= 0.`);
    }
    return normalized;
  }
  if (typeof value === 'string' && value.trim().length > 0) {
    const parsed = Number.parseInt(value.trim(), 10);
    if (Number.isFinite(parsed) && parsed >= 0) {
      return parsed;
    }
  }
  throw new Error(`${fieldPath} must be a non-negative integer.`);
}

function toNullableNonNegativeInt(value, fieldPath) {
  if (value == null) {
    return null;
  }
  return toNonNegativeInt(value, fieldPath);
}

function toBoolean(value, fieldPath) {
  if (typeof value === 'boolean') {
    return value;
  }
  throw new Error(`${fieldPath} must be boolean.`);
}

function normalizeErrorMessage(error) {
  const raw = `${error?.message ?? error}`;
  if (raw.includes('5 NOT_FOUND')) {
    return [
      raw,
      `Firestore database "${firestoreDatabaseId}" is missing or inaccessible for this project.`,
      'Create that database in Firestore (Native mode), then rerun preflight/deploy.',
    ].join(' ');
  }
  if (raw.includes('PERMISSION_DENIED') || raw.includes('7 PERMISSION_DENIED')) {
    return [
      raw,
      'Service account lacks Firestore read/write permissions for subscriptionPackages.',
    ].join(' ');
  }
  return raw;
}
