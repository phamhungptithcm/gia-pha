#!/usr/bin/env node

import { readFileSync } from 'node:fs';

import { applicationDefault, cert, initializeApp } from 'firebase-admin/app';
import { getFirestore, Timestamp } from 'firebase-admin/firestore';

const projectId = process.env.FIREBASE_PROJECT_ID || 'be-fam-3ab23';
const serviceAccountJson = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;

const credential = serviceAccountJson
  ? cert(JSON.parse(readFileSync(serviceAccountJson, 'utf8')))
  : applicationDefault();

initializeApp({
  credential,
  projectId,
});

const db = getFirestore();
const now = Timestamp.now();
const expiresAt = Timestamp.fromDate(
  new Date(Date.now() + 365 * 24 * 60 * 60 * 1000),
);

const clan = {
  id: 'clan_demo_001',
  name: 'Ho toc BeFam',
  slug: 'ho-toc-befam',
  description:
    'Khong gian dieu phoi mau cho viec quan ly ho toc, cac chi, va vai tro dieu hanh.',
  countryCode: 'VN',
  founderName: 'Nguyen Minh to',
  logoUrl: '',
  status: 'active',
  memberCount: 5,
  branchCount: 2,
  createdAt: now,
  createdBy: 'seed-script',
  updatedAt: now,
  updatedBy: 'seed-script',
};

const branches = [
  {
    id: 'branch_demo_001',
    clanId: 'clan_demo_001',
    name: 'Chi Truong',
    code: 'CT01',
    leaderMemberId: 'member_demo_parent_001',
    viceLeaderMemberId: 'member_demo_parent_002',
    generationLevelHint: 3,
    status: 'active',
    memberCount: 3,
    createdAt: now,
    createdBy: 'seed-script',
    updatedAt: now,
    updatedBy: 'seed-script',
  },
  {
    id: 'branch_demo_002',
    clanId: 'clan_demo_001',
    name: 'Chi Phu',
    code: 'CP02',
    leaderMemberId: 'member_demo_parent_002',
    viceLeaderMemberId: 'member_demo_elder_001',
    generationLevelHint: 4,
    status: 'active',
    memberCount: 2,
    createdAt: now,
    createdBy: 'seed-script',
    updatedAt: now,
    updatedBy: 'seed-script',
  },
];

const members = [
  {
    id: 'member_demo_parent_001',
    clanId: 'clan_demo_001',
    branchId: 'branch_demo_001',
    fullName: 'Nguyen Minh',
    normalizedFullName: 'nguyen minh',
    nickName: 'Minh',
    gender: 'male',
    birthDate: '1988-02-14',
    deathDate: null,
    phoneE164: '+84901234567',
    email: 'minh@befam.vn',
    addressText: 'Da Nang, Viet Nam',
    jobTitle: 'Clan Coordinator',
    avatarUrl: null,
    bio: 'Dieu phoi khoi tao khong gian ho toc mau cho BeFam.',
    socialLinks: {
      facebook: 'https://facebook.com/minh',
      zalo: 'https://zalo.me/minh',
      linkedin: 'https://linkedin.com/in/minh',
    },
    parentIds: [],
    childrenIds: ['member_demo_child_001'],
    spouseIds: [],
    generation: 4,
    primaryRole: 'CLAN_ADMIN',
    status: 'active',
    isMinor: false,
    claimedAt: null,
    createdAt: now,
    createdBy: 'seed-script',
    updatedAt: now,
    updatedBy: 'seed-script',
  },
  {
    id: 'member_demo_parent_002',
    clanId: 'clan_demo_001',
    branchId: 'branch_demo_002',
    fullName: 'Tran Lan',
    normalizedFullName: 'tran lan',
    nickName: 'Lan',
    gender: 'female',
    birthDate: '1990-07-21',
    deathDate: null,
    phoneE164: '+84908886655',
    email: 'lan@befam.vn',
    addressText: 'Hue, Viet Nam',
    jobTitle: 'Branch Lead',
    avatarUrl: null,
    bio: 'Dieu phoi hoat dong thanh vien theo chi.',
    socialLinks: {
      facebook: 'https://facebook.com/lan',
      zalo: 'https://zalo.me/lan',
      linkedin: null,
    },
    parentIds: [],
    childrenIds: ['member_demo_child_002'],
    spouseIds: [],
    generation: 4,
    primaryRole: 'BRANCH_ADMIN',
    status: 'active',
    isMinor: false,
    claimedAt: null,
    createdAt: now,
    createdBy: 'seed-script',
    updatedAt: now,
    updatedBy: 'seed-script',
  },
  {
    id: 'member_demo_child_001',
    clanId: 'clan_demo_001',
    branchId: 'branch_demo_001',
    fullName: 'Be Minh',
    normalizedFullName: 'be minh',
    nickName: 'Minh nho',
    gender: 'male',
    birthDate: '2017-04-12',
    deathDate: null,
    phoneE164: null,
    email: null,
    addressText: 'Da Nang, Viet Nam',
    jobTitle: 'Hoc sinh',
    avatarUrl: null,
    bio: 'Thanh vien tre em dung cho luong OTP phu huynh.',
    socialLinks: {
      facebook: null,
      zalo: null,
      linkedin: null,
    },
    parentIds: ['member_demo_parent_001'],
    childrenIds: [],
    spouseIds: [],
    generation: 6,
    primaryRole: 'MEMBER',
    status: 'active',
    isMinor: true,
    claimedAt: null,
    createdAt: now,
    createdBy: 'seed-script',
    updatedAt: now,
    updatedBy: 'seed-script',
  },
  {
    id: 'member_demo_child_002',
    clanId: 'clan_demo_001',
    branchId: 'branch_demo_002',
    fullName: 'Be Lan',
    normalizedFullName: 'be lan',
    nickName: 'Lan nho',
    gender: 'female',
    birthDate: '2016-09-09',
    deathDate: null,
    phoneE164: null,
    email: null,
    addressText: 'Hue, Viet Nam',
    jobTitle: 'Hoc sinh',
    avatarUrl: null,
    bio: 'Thanh vien tre em mau cho kiem thu quyen doc.',
    socialLinks: {
      facebook: null,
      zalo: null,
      linkedin: null,
    },
    parentIds: ['member_demo_parent_002'],
    childrenIds: [],
    spouseIds: [],
    generation: 6,
    primaryRole: 'MEMBER',
    status: 'active',
    isMinor: true,
    claimedAt: null,
    createdAt: now,
    createdBy: 'seed-script',
    updatedAt: now,
    updatedBy: 'seed-script',
  },
  {
    id: 'member_demo_elder_001',
    clanId: 'clan_demo_001',
    branchId: 'branch_demo_001',
    fullName: 'Ong Bao',
    normalizedFullName: 'ong bao',
    nickName: '',
    gender: 'male',
    birthDate: '1960-11-01',
    deathDate: null,
    phoneE164: '+84907770000',
    email: null,
    addressText: 'Quang Nam, Viet Nam',
    jobTitle: 'Co van ho toc',
    avatarUrl: null,
    bio: 'Thanh vien lon tuoi ho tro kiem thu danh sach.',
    socialLinks: {
      facebook: null,
      zalo: null,
      linkedin: null,
    },
    parentIds: [],
    childrenIds: [],
    spouseIds: [],
    generation: 3,
    primaryRole: 'MEMBER',
    status: 'active',
    isMinor: false,
    claimedAt: null,
    createdAt: now,
    createdBy: 'seed-script',
    updatedAt: now,
    updatedBy: 'seed-script',
  },
];

const relationships = [
  {
    id: 'rel_parent_child_member_demo_parent_001_member_demo_child_001',
    clanId: 'clan_demo_001',
    personA: 'member_demo_parent_001',
    personB: 'member_demo_child_001',
    type: 'parent_child',
    direction: 'A_TO_B',
    status: 'active',
    source: 'manual',
    createdBy: 'seed-script',
    createdAt: now,
    updatedAt: now,
  },
  {
    id: 'rel_parent_child_member_demo_parent_002_member_demo_child_002',
    clanId: 'clan_demo_001',
    personA: 'member_demo_parent_002',
    personB: 'member_demo_child_002',
    type: 'parent_child',
    direction: 'A_TO_B',
    status: 'active',
    source: 'manual',
    createdBy: 'seed-script',
    createdAt: now,
    updatedAt: now,
  },
];

const invites = [
  {
    id: 'invite_phone_claim_parent_001',
    clanId: 'clan_demo_001',
    branchId: 'branch_demo_001',
    memberId: 'member_demo_parent_001',
    inviteType: 'phone_claim',
    phoneE164: '+84901234567',
    childIdentifier: null,
    status: 'pending',
    expiresAt,
    createdAt: now,
    createdBy: 'seed-script',
  },
  {
    id: 'invite_phone_claim_parent_002',
    clanId: 'clan_demo_001',
    branchId: 'branch_demo_002',
    memberId: 'member_demo_parent_002',
    inviteType: 'phone_claim',
    phoneE164: '+84908886655',
    childIdentifier: null,
    status: 'pending',
    expiresAt,
    createdAt: now,
    createdBy: 'seed-script',
  },
  {
    id: 'invite_child_001',
    clanId: 'clan_demo_001',
    branchId: 'branch_demo_001',
    memberId: 'member_demo_child_001',
    inviteType: 'child_access',
    phoneE164: '+84901234567',
    childIdentifier: 'BEFAM-CHILD-001',
    status: 'pending',
    expiresAt,
    createdAt: now,
    createdBy: 'seed-script',
  },
  {
    id: 'invite_child_002',
    clanId: 'clan_demo_001',
    branchId: 'branch_demo_002',
    memberId: 'member_demo_child_002',
    inviteType: 'child_access',
    phoneE164: '+84908886655',
    childIdentifier: 'BEFAM-CHILD-002',
    status: 'pending',
    expiresAt,
    createdAt: now,
    createdBy: 'seed-script',
  },
];

async function seed() {
  const batch = db.batch();

  const clanRef = db.collection('clans').doc(clan.id);
  batch.set(clanRef, clan, { merge: true });

  for (const branch of branches) {
    const ref = db.collection('branches').doc(branch.id);
    batch.set(ref, branch, { merge: true });
  }

  for (const member of members) {
    const ref = db.collection('members').doc(member.id);
    batch.set(ref, member, { merge: true });
  }

  for (const relationship of relationships) {
    const ref = db.collection('relationships').doc(relationship.id);
    batch.set(ref, relationship, { merge: true });
  }

  for (const invite of invites) {
    const ref = db.collection('invites').doc(invite.id);
    batch.set(ref, invite, { merge: true });
  }

  await batch.commit();

  console.log('Seeded demo clan data successfully.');
  console.log(`Project: ${projectId}`);
  console.log(`Clan: ${clan.id}`);
  console.log(`Members: ${members.length}`);
  console.log(`Branches: ${branches.length}`);
  console.log(`Relationships: ${relationships.length}`);
  console.log(`Invites: ${invites.length}`);
}

seed().catch((error) => {
  console.error('Failed to seed demo data.');
  console.error(error);
  process.exit(1);
});
