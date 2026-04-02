#!/usr/bin/env node

import { readFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import { applicationDefault, cert, initializeApp } from 'firebase-admin/app';
import { getFirestore, Timestamp } from 'firebase-admin/firestore';

const args = process.argv.slice(2);
const checkOnly = args.includes('--check-only');
const allowProduction = args.includes('--allow-production');
const scriptDir = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(scriptDir, '../../..');

const defaultFlowFile = path.join(
  repoRoot,
  'mobile/befam/config/onboarding/sample_onboarding_flows.json',
);

const flowFilePath = path.resolve(readOption('--file') ?? defaultFlowFile);
const collectionName =
  readOption('--collection') ||
  process.env.ONBOARDING_FLOW_COLLECTION ||
  'onboardingFlows';

const rawFlows = readJsonFile(flowFilePath);
const flows = validateFlowCatalog(rawFlows, flowFilePath);

if (checkOnly) {
  console.log(
    [
      'Validated onboarding flow catalog.',
      `File: ${path.relative(repoRoot, flowFilePath)}`,
      `Collection: ${collectionName}`,
      `Flow versions: ${flows.length}`,
    ].join('\n'),
  );
  process.exit(0);
}

const projectId =
  process.env.FIREBASE_PROJECT_ID ||
  process.env.GOOGLE_CLOUD_PROJECT ||
  process.env.GCLOUD_PROJECT ||
  '';
const serviceAccountJson = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;

if (!projectId) {
  throw new Error(
    'Missing FIREBASE_PROJECT_ID (or GOOGLE_CLOUD_PROJECT / GCLOUD_PROJECT).',
  );
}

if (
  !allowProduction &&
  /(prod|production|live)/i.test(projectId) &&
  !/(test|staging|sandbox|dev|qa|demo)/i.test(projectId)
) {
  throw new Error(
    [
      `Refusing to seed onboarding flows into likely production project "${projectId}".`,
      'Pass --allow-production to override intentionally.',
    ].join(' '),
  );
}

const credential = serviceAccountJson
  ? cert(JSON.parse(readFileSync(serviceAccountJson, 'utf8')))
  : applicationDefault();

initializeApp({
  credential,
  projectId,
});

const db = getFirestore();
const now = Timestamp.now();
let upsertedCount = 0;

for (const flow of flows) {
  const documentId = `${flow.id}__v${flow.version}`;
  await db.collection(collectionName).doc(documentId).set(
    {
      ...flow,
      documentId,
      source: 'seed-onboarding-flows.mjs',
      seededAt: now,
      updatedAt: now,
    },
    { merge: true },
  );
  upsertedCount += 1;
}

console.log(
  [
    'Seeded onboarding flows successfully.',
    `Project: ${projectId}`,
    `Collection: ${collectionName}`,
    `Flow versions: ${upsertedCount}`,
    `Catalog file: ${path.relative(repoRoot, flowFilePath)}`,
  ].join('\n'),
);

function readOption(name) {
  const exactIndex = args.indexOf(name);
  if (exactIndex >= 0) {
    const value = args[exactIndex + 1];
    if (!value || value.startsWith('--')) {
      throw new Error(`Missing value for ${name}.`);
    }
    return value;
  }

  const prefix = `${name}=`;
  const matched = args.find((entry) => entry.startsWith(prefix));
  if (!matched) {
    return null;
  }
  return matched.slice(prefix.length);
}

function readJsonFile(filePath) {
  try {
    return JSON.parse(readFileSync(filePath, 'utf8'));
  } catch (error) {
    throw new Error(`Could not parse JSON from ${filePath}: ${error.message}`);
  }
}

function validateFlowCatalog(rawCatalog, filePath) {
  if (!Array.isArray(rawCatalog)) {
    throw new Error(`Expected an array of flows in ${filePath}.`);
  }

  const seenVersions = new Set();
  return rawCatalog.map((rawFlow, index) => {
    const flow = validateFlow(rawFlow, index);
    const versionKey = `${flow.id}::${flow.version}`;
    if (seenVersions.has(versionKey)) {
      throw new Error(
        `Duplicate onboarding flow version "${versionKey}" in ${filePath}.`,
      );
    }
    seenVersions.add(versionKey);
    return flow;
  });
}

function validateFlow(rawFlow, index) {
  const location = `flow[${index}]`;
  const flow = expectRecord(rawFlow, location);
  const id = expectNonEmptyString(flow.id, `${location}.id`);
  const triggerId = expectNonEmptyString(flow.triggerId, `${location}.triggerId`);
  const version = expectPositiveInteger(flow.version, `${location}.version`);
  const enabled = expectBoolean(flow.enabled, `${location}.enabled`);
  const steps = expectArray(flow.steps, `${location}.steps`);

  if (steps.length === 0) {
    throw new Error(`${location}.steps must contain at least one step.`);
  }

  const validatedSteps = steps.map((rawStep, stepIndex) =>
    validateStep(rawStep, `${location}.steps[${stepIndex}]`),
  );

  return {
    id,
    triggerId,
    version,
    enabled,
    priority: optionalInteger(flow.priority, `${location}.priority`),
    maxDisplays: optionalInteger(flow.maxDisplays, `${location}.maxDisplays`),
    cooldownHours: optionalInteger(
      flow.cooldownHours,
      `${location}.cooldownHours`,
    ),
    resumeTtlHours: optionalInteger(
      flow.resumeTtlHours,
      `${location}.resumeTtlHours`,
    ),
    platforms: optionalStringArray(flow.platforms, `${location}.platforms`),
    steps: validatedSteps,
  };
}

function validateStep(rawStep, location) {
  const step = expectRecord(rawStep, location);
  const placement = optionalString(step.placement, `${location}.placement`);
  if (
    placement != null &&
    !['above', 'below', 'left', 'right', 'center'].includes(placement)
  ) {
    throw new Error(
      `${location}.placement must be one of above, below, left, right, center.`,
    );
  }

  return {
    id: expectNonEmptyString(step.id, `${location}.id`),
    anchorId: expectNonEmptyString(step.anchorId, `${location}.anchorId`),
    title: validateLocaleMap(step.title, `${location}.title`),
    body: validateLocaleMap(step.body, `${location}.body`),
    placement,
    barrierDismissible: optionalBoolean(
      step.barrierDismissible,
      `${location}.barrierDismissible`,
    ),
  };
}

function validateLocaleMap(rawValue, location) {
  const record = expectRecord(rawValue, location);
  const keys = Object.keys(record);
  if (keys.length === 0) {
    throw new Error(`${location} must contain at least one locale entry.`);
  }

  const normalized = {};
  for (const key of keys) {
    normalized[key] = expectNonEmptyString(record[key], `${location}.${key}`);
  }
  return normalized;
}

function expectRecord(value, location) {
  if (value == null || Array.isArray(value) || typeof value !== 'object') {
    throw new Error(`${location} must be an object.`);
  }
  return value;
}

function expectArray(value, location) {
  if (!Array.isArray(value)) {
    throw new Error(`${location} must be an array.`);
  }
  return value;
}

function expectNonEmptyString(value, location) {
  if (typeof value !== 'string' || value.trim().length === 0) {
    throw new Error(`${location} must be a non-empty string.`);
  }
  return value.trim();
}

function optionalString(value, location) {
  if (value == null) {
    return null;
  }
  return expectNonEmptyString(value, location);
}

function expectBoolean(value, location) {
  if (typeof value !== 'boolean') {
    throw new Error(`${location} must be a boolean.`);
  }
  return value;
}

function optionalBoolean(value, location) {
  if (value == null) {
    return null;
  }
  return expectBoolean(value, location);
}

function expectPositiveInteger(value, location) {
  const integer = optionalInteger(value, location);
  if (integer == null || integer <= 0) {
    throw new Error(`${location} must be a positive integer.`);
  }
  return integer;
}

function optionalInteger(value, location) {
  if (value == null) {
    return null;
  }
  if (typeof value !== 'number' || !Number.isInteger(value)) {
    throw new Error(`${location} must be an integer.`);
  }
  return value;
}

function optionalStringArray(value, location) {
  if (value == null) {
    return null;
  }
  const items = expectArray(value, location);
  return items.map((entry, index) =>
    expectNonEmptyString(entry, `${location}[${index}]`),
  );
}
