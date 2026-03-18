#!/usr/bin/env node

import { readFileSync } from 'node:fs';

import { applicationDefault, cert, initializeApp } from 'firebase-admin/app';
import { FieldValue, getFirestore } from 'firebase-admin/firestore';

const projectId =
  process.env.FIREBASE_PROJECT_ID ||
  process.env.GOOGLE_CLOUD_PROJECT ||
  process.env.GCLOUD_PROJECT ||
  '';
const serviceAccountJson = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;

if (!projectId) {
  throw new Error(
    'Missing FIREBASE_PROJECT_ID (or GOOGLE_CLOUD_PROJECT/GCLOUD_PROJECT).',
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
const BATCH_LIMIT = 400;

async function purgeDebugAuthColumns() {
  const summary = {
    debugLoginProfilesScanned: 0,
    debugLoginProfilesUpdated: 0,
    membersWithDebugAuthUidScanned: 0,
    membersWithDebugAuthUidUpdated: 0,
  };

  const profileSnapshot = await db.collection('debug_login_profiles').get();
  summary.debugLoginProfilesScanned = profileSnapshot.size;
  await runInBatches(profileSnapshot.docs, async (batch, doc) => {
    batch.set(
      doc.ref,
      {
        isTestUser: FieldValue.delete(),
        debugOtpCode: FieldValue.delete(),
        otpCode: FieldValue.delete(),
        autoOtpCode: FieldValue.delete(),
        updatedAt: FieldValue.serverTimestamp(),
        updatedBy: 'purge-debug-auth-columns',
      },
      { merge: true },
    );
    summary.debugLoginProfilesUpdated += 1;
  });

  const membersSnapshot = await db
    .collection('members')
    .where('authUid', '>=', 'debug_')
    .where('authUid', '<', 'debug_~')
    .get();
  summary.membersWithDebugAuthUidScanned = membersSnapshot.size;
  await runInBatches(membersSnapshot.docs, async (batch, doc) => {
    batch.set(
      doc.ref,
      {
        authUid: FieldValue.delete(),
        claimedAt: FieldValue.delete(),
        updatedAt: FieldValue.serverTimestamp(),
        updatedBy: 'purge-debug-auth-columns',
      },
      { merge: true },
    );
    summary.membersWithDebugAuthUidUpdated += 1;
  });

  return summary;
}

async function runInBatches(docs, addOperation) {
  let batch = db.batch();
  let writes = 0;
  for (const doc of docs) {
    await addOperation(batch, doc);
    writes += 1;
    if (writes >= BATCH_LIMIT) {
      await batch.commit();
      batch = db.batch();
      writes = 0;
    }
  }
  if (writes > 0) {
    await batch.commit();
  }
}

purgeDebugAuthColumns()
  .then((summary) => {
    console.log('Purged debug auth columns successfully.');
    console.log(`Project: ${projectId}`);
    console.log(
      `debug_login_profiles updated: ${summary.debugLoginProfilesUpdated}/${summary.debugLoginProfilesScanned}`,
    );
    console.log(
      `members authUid cleaned: ${summary.membersWithDebugAuthUidUpdated}/${summary.membersWithDebugAuthUidScanned}`,
    );
  })
  .catch((error) => {
    console.error('Failed to purge debug auth columns.');
    console.error(error);
    process.exit(1);
  });
