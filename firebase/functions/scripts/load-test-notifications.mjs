import { performance } from 'node:perf_hooks';

import { initializeApp } from 'firebase-admin/app';
import { FieldValue, getFirestore } from 'firebase-admin/firestore';

process.env.NOTIFICATION_PUSH_ENABLED = 'false';
process.env.NOTIFICATION_EMAIL_ENABLED = 'false';
process.env.NOTIFICATION_EVENT_MAX_AUDIENCE = '20000';

const app = initializeApp({
  projectId: process.env.GCLOUD_PROJECT ?? 'demo-notification-load-test',
});
const firestore = getFirestore(app);
const clanId = 'clan_load_perf_001';
const totalMembers = Number.parseInt(
  process.env.LOAD_TEST_TOTAL_MEMBERS ?? '8000',
  10,
);
const memberIds = [];

const { notifyMembers, resolveAudienceMemberIdsByEventScope } = await import(
  '../lib/notifications/push-delivery.js'
);

console.log(`[load-test] preparing ${totalMembers} active members...`);
const prepareStartedAt = performance.now();
for (let start = 0; start < totalMembers; start += 450) {
  const batch = firestore.batch();
  const chunkEnd = Math.min(totalMembers, start + 450);
  for (let index = start; index < chunkEnd; index += 1) {
    const memberId = `member_load_${index.toString().padStart(5, '0')}`;
    memberIds.push(memberId);
    batch.set(firestore.collection('members').doc(memberId), {
      id: memberId,
      clanId,
      branchId: index % 2 === 0 ? 'branch_a' : 'branch_b',
      authUid: `uid_load_${index.toString().padStart(5, '0')}`,
      status: 'active',
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
  }
  await batch.commit();
}
const prepareMs = performance.now() - prepareStartedAt;
console.log(
  `[load-test] member preparation complete in ${prepareMs.toFixed(1)}ms`,
);

const audienceStartedAt = performance.now();
const audience = await resolveAudienceMemberIdsByEventScope({
  clanId,
  branchId: null,
  visibility: 'clan',
  maxAudience: 20000,
});
const audienceMs = performance.now() - audienceStartedAt;
console.log(
  `[load-test] audience resolved ${audience.length} members in ${audienceMs.toFixed(1)}ms`,
);

const notifyStartedAt = performance.now();
const result = await notifyMembers({
  clanId,
  memberIds: audience,
  type: 'system_load_test',
  title: 'Load test notification',
  body: 'Synthetic run for notification throughput validation.',
  target: 'generic',
  targetId: `load_test_${Date.now()}`,
  extraData: {
    loadTest: 'true',
  },
});
const notifyMs = performance.now() - notifyStartedAt;

const notificationsSnapshot = await firestore
  .collection('notifications')
  .where('clanId', '==', clanId)
  .where('type', '==', 'system_load_test')
  .count()
  .get();
const notificationsCount = notificationsSnapshot.data().count ?? 0;

console.log('[load-test] notifyMembers result:', JSON.stringify(result, null, 2));
console.log(
  `[load-test] notification writes=${notificationsCount} elapsed=${notifyMs.toFixed(1)}ms ` +
    `throughput=${(notificationsCount / Math.max(1, notifyMs / 1000)).toFixed(1)} docs/s`,
);
