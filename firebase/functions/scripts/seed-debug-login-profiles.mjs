#!/usr/bin/env node

import { applicationDefault, cert, initializeApp } from 'firebase-admin/app';
import { getFirestore, Timestamp } from 'firebase-admin/firestore';
import { readFileSync } from 'node:fs';

const args = new Set(process.argv.slice(2));
const validateOnly = args.has('--validate-only');

const projectId =
  process.env.FIREBASE_PROJECT_ID ||
  process.env.GOOGLE_CLOUD_PROJECT ||
  process.env.GCLOUD_PROJECT ||
  '';
const serviceAccountJson = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
const allowTestSeed =
  process.env.ALLOW_TEST_DATA_SEED === 'true' || args.has('--force-test-seed');

if (!projectId) {
  throw new Error(
    'Missing FIREBASE_PROJECT_ID (or GOOGLE_CLOUD_PROJECT / GCLOUD_PROJECT).',
  );
}

if (!allowTestSeed) {
  throw new Error(
    [
      'Refusing to seed debug_login_profiles without explicit test-env consent.',
      'Set ALLOW_TEST_DATA_SEED=true (or pass --force-test-seed) to continue.',
    ].join(' '),
  );
}

if (
  /(prod|production|live)/i.test(projectId) &&
  !/(test|staging|sandbox|dev|qa|demo)/i.test(projectId)
) {
  throw new Error(
    `Refusing to run against likely production project "${projectId}".`,
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

const debugProfiles = [
  {
    id: '+84901234567',
    phoneE164: '+84901234567',
    displayName: 'Nguyễn Minh',
    memberId: 'member_seed_parent_001',
    clanId: 'clan_seed_001',
    branchId: 'branch_seed_001',
    primaryRole: 'CLAN_ADMIN',
    accessMode: 'claimed',
    linkedAuthUid: true,
    isActive: true,
    isTestUser: true,
    scenarioCode: 'SCENARIO_01_CLAN_LEADER_HAS_GENEALOGY',
    scenarioLabel: 'Clan leader with existing genealogy',
  },
  {
    id: '+84908886655',
    phoneE164: '+84908886655',
    displayName: 'Trần Văn Long',
    memberId: 'member_seed_parent_002',
    clanId: 'clan_seed_001',
    branchId: 'branch_seed_002',
    primaryRole: 'BRANCH_ADMIN',
    accessMode: 'claimed',
    linkedAuthUid: true,
    isActive: true,
    isTestUser: true,
    scenarioCode: 'SCENARIO_02_BRANCH_LEADER_HAS_GENEALOGY',
    scenarioLabel: 'Branch leader with existing genealogy',
  },
  {
    id: '+84907770011',
    phoneE164: '+84907770011',
    displayName: 'Ông Bảo',
    memberId: 'member_seed_elder_001',
    clanId: 'clan_seed_001',
    branchId: 'branch_seed_001',
    primaryRole: 'MEMBER',
    accessMode: 'claimed',
    linkedAuthUid: true,
    isActive: true,
    isTestUser: true,
    scenarioCode: 'SCENARIO_03_MEMBER_LINKED',
    scenarioLabel: 'Normal member already linked',
  },
  {
    id: '+84906660022',
    phoneE164: '+84906660022',
    displayName: 'Khách mới',
    memberId: null,
    clanId: null,
    branchId: null,
    primaryRole: 'GUEST',
    accessMode: 'unlinked',
    linkedAuthUid: false,
    isActive: true,
    isTestUser: true,
    scenarioCode: 'SCENARIO_04_USER_UNLINKED',
    scenarioLabel: 'User not linked to any genealogy',
  },
  {
    id: '+84905550033',
    phoneE164: '+84905550033',
    displayName: 'Trưởng chi chưa gắn gia phả',
    memberId: null,
    clanId: null,
    branchId: null,
    primaryRole: 'BRANCH_ADMIN',
    accessMode: 'unlinked',
    linkedAuthUid: false,
    isActive: true,
    isTestUser: true,
    scenarioCode: 'SCENARIO_05_BRANCH_LEADER_NO_GENEALOGY_LINK',
    scenarioLabel: 'Branch leader role but no genealogy linked',
  },
  {
    id: '+84909990001',
    phoneE164: '+84909990001',
    displayName: 'Trưởng tộc chưa tạo gia phả',
    memberId: null,
    clanId: null,
    branchId: null,
    primaryRole: 'CLAN_ADMIN',
    accessMode: 'unlinked',
    linkedAuthUid: false,
    isActive: true,
    isTestUser: true,
    scenarioCode: 'SCENARIO_06_CLAN_LEADER_NO_GENEALOGY_CREATED',
    scenarioLabel: 'Clan leader role but no genealogy created',
  },
];

async function validateProfileReferences(profile) {
  const missingRefs = [];

  if (profile.memberId) {
    const memberSnapshot = await db.collection('members').doc(profile.memberId).get();
    if (!memberSnapshot.exists) {
      missingRefs.push(`member:${profile.memberId}`);
    }
  }
  if (profile.clanId) {
    const clanSnapshot = await db.collection('clans').doc(profile.clanId).get();
    if (!clanSnapshot.exists) {
      missingRefs.push(`clan:${profile.clanId}`);
    }
  }
  if (profile.branchId) {
    const branchSnapshot = await db.collection('branches').doc(profile.branchId).get();
    if (!branchSnapshot.exists) {
      missingRefs.push(`branch:${profile.branchId}`);
    }
  }

  return missingRefs;
}

async function seedOrValidateProfiles() {
  let seededCount = 0;
  let validCount = 0;
  const invalidEntries = [];

  for (const profile of debugProfiles) {
    const missingRefs = await validateProfileReferences(profile);
    if (missingRefs.length > 0) {
      invalidEntries.push({
        phone: profile.phoneE164,
        scenarioCode: profile.scenarioCode,
        missingRefs,
      });
      continue;
    }
    validCount += 1;

    if (validateOnly) {
      continue;
    }

    const now = Timestamp.now();
    const payload = {
      ...profile,
      id: profile.id,
      updatedAt: now,
      createdAt: now,
      source: 'seed-debug-login-profiles.mjs',
    };
    await db.collection('debug_login_profiles').doc(profile.id).set(payload, {
      merge: true,
    });
    seededCount += 1;
  }

  if (invalidEntries.length > 0) {
    console.error('Invalid debug profile references were detected:');
    for (const entry of invalidEntries) {
      console.error(
        `- ${entry.scenarioCode} (${entry.phone}) missing: ${entry.missingRefs.join(', ')}`,
      );
    }
    throw new Error(
      `Validation failed for ${invalidEntries.length} debug profile(s).`,
    );
  }

  if (validateOnly) {
    console.log(
      `Validated ${validCount}/${debugProfiles.length} debug_login_profiles in project "${projectId}".`,
    );
    return;
  }

  console.log(
    [
      'Seeded debug_login_profiles successfully.',
      `Project: ${projectId}`,
      `Profiles: ${seededCount}`,
      `Scenarios: ${debugProfiles.length}`,
    ].join('\n'),
  );
}

seedOrValidateProfiles().catch((error) => {
  console.error('debug_login_profiles seed/validation failed.');
  console.error(error);
  process.exit(1);
});
