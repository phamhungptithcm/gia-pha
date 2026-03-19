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
    'Missing FIREBASE_PROJECT_ID (or GOOGLE_CLOUD_PROJECT/GCLOUD_PROJECT) for migration script.',
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
const dryRun = process.argv.includes('--dry-run');
const PAGE_SIZE = 300;

function normalizeString(value) {
  return typeof value === 'string' ? value.trim() : '';
}

async function run() {
  let processed = 0;
  let updated = 0;
  let backfilledOwnerUid = 0;
  let removedBillingOwnerUid = 0;
  let missingOwnerUid = 0;

  let lastDoc = null;

  while (true) {
    let query = db.collection('clans').orderBy('__name__').limit(PAGE_SIZE);
    if (lastDoc != null) {
      query = query.startAfter(lastDoc);
    }

    const snapshot = await query.get();
    if (snapshot.empty) {
      break;
    }

    const batch = db.batch();
    let pendingWrites = 0;

    for (const doc of snapshot.docs) {
      processed += 1;
      const data = doc.data() ?? {};
      const ownerUid = normalizeString(data.ownerUid);
      const legacyBillingOwnerUid = normalizeString(data.billingOwnerUid);

      if (ownerUid.length === 0 && legacyBillingOwnerUid.length === 0) {
        missingOwnerUid += 1;
      }

      const updates = {};
      if (ownerUid.length === 0 && legacyBillingOwnerUid.length > 0) {
        updates.ownerUid = legacyBillingOwnerUid;
        backfilledOwnerUid += 1;
      }
      if (Object.prototype.hasOwnProperty.call(data, 'billingOwnerUid')) {
        updates.billingOwnerUid = FieldValue.delete();
        removedBillingOwnerUid += 1;
      }

      if (Object.keys(updates).length > 0) {
        updates.updatedAt = FieldValue.serverTimestamp();
        updates.updatedBy = 'script:purge-billing-owner-column';
        if (!dryRun) {
          batch.set(doc.ref, updates, { merge: true });
          pendingWrites += 1;
        }
        updated += 1;
      }
    }

    if (!dryRun && pendingWrites > 0) {
      await batch.commit();
    }

    lastDoc = snapshot.docs[snapshot.docs.length - 1];
  }

  console.log(`Project: ${projectId}`);
  console.log(`Mode: ${dryRun ? 'DRY_RUN' : 'APPLY'}`);
  console.log(`Clans scanned: ${processed}`);
  console.log(`Clans updated: ${updated}`);
  console.log(`ownerUid backfilled: ${backfilledOwnerUid}`);
  console.log(`billingOwnerUid removed: ${removedBillingOwnerUid}`);
  console.log(`missing owner after scan: ${missingOwnerUid}`);
}

run().catch((error) => {
  console.error('Migration failed:', error);
  process.exitCode = 1;
});
