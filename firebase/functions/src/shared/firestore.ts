import { getApps, initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';

const app = getApps()[0] ?? initializeApp();
const firestoreDatabaseId = process.env.FIRESTORE_DATABASE_ID?.trim() || '(default)';

export const db = getFirestore(app, firestoreDatabaseId);
export const FIRESTORE_DATABASE_ID = firestoreDatabaseId;
