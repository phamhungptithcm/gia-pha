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
const clanId = 'clan_demo_001';

function normalizeName(value) {
  return value.trim().toLowerCase().replace(/\s+/g, ' ');
}

function uniqueSorted(values) {
  return [...new Set(values.filter(Boolean))].sort();
}

function createMember({
  id,
  branchId,
  fullName,
  nickName = '',
  gender = null,
  birthDate = null,
  deathDate = null,
  phoneE164 = null,
  email = null,
  addressText = 'Viet Nam',
  jobTitle = null,
  bio = null,
  generation,
  primaryRole = 'MEMBER',
  status = 'active',
  isMinor = false,
  authUid = null,
}) {
  return {
    id,
    clanId,
    branchId,
    fullName,
    normalizedFullName: normalizeName(fullName),
    nickName,
    gender,
    birthDate,
    deathDate,
    phoneE164,
    email,
    addressText,
    jobTitle,
    avatarUrl: null,
    bio: bio ?? `Thanh vien demo ${fullName}.`,
    socialLinks: {
      facebook: null,
      zalo: null,
      linkedin: null,
    },
    parentIds: [],
    childrenIds: [],
    spouseIds: [],
    generation,
    primaryRole,
    status,
    isMinor,
    authUid,
    claimedAt: null,
    createdAt: now,
    createdBy: 'seed-script',
    updatedAt: now,
    updatedBy: 'seed-script',
  };
}

function createParentChild(parentId, childId) {
  return {
    id: `rel_parent_child_${parentId}_${childId}`,
    clanId,
    personA: parentId,
    personB: childId,
    type: 'parent_child',
    direction: 'A_TO_B',
    status: 'active',
    source: 'seeded',
    createdBy: 'seed-script',
    createdAt: now,
    updatedAt: now,
  };
}

function createSpouse(leftId, rightId) {
  const pair = [leftId, rightId].sort();
  return {
    id: `rel_spouse_${pair[0]}_${pair[1]}`,
    clanId,
    personA: pair[0],
    personB: pair[1],
    type: 'spouse',
    direction: 'UNDIRECTED',
    status: 'active',
    source: 'seeded',
    createdBy: 'seed-script',
    createdAt: now,
    updatedAt: now,
  };
}

const members = [
  createMember({
    id: 'member_demo_ancestor_001',
    branchId: 'branch_demo_001',
    fullName: 'Le Thanh Cong',
    nickName: 'Cong',
    gender: 'male',
    birthDate: '1941-01-10',
    deathDate: '2021-11-02',
    phoneE164: '+84901110001',
    generation: 2,
    status: 'deceased',
    jobTitle: 'To truong',
    bio: 'To tien truyen thong cua dong ho demo.',
  }),
  createMember({
    id: 'member_demo_ancestor_002',
    branchId: 'branch_demo_001',
    fullName: 'Pham Hanh Phuc',
    nickName: 'Phuc',
    gender: 'female',
    birthDate: '1944-04-18',
    deathDate: '2022-05-01',
    generation: 2,
    status: 'deceased',
    jobTitle: 'Noi tro',
    bio: 'To tien da mat, dung de demo trang thai da mat.',
  }),
  createMember({
    id: 'member_demo_elder_001',
    branchId: 'branch_demo_001',
    fullName: 'Ong Bao',
    nickName: '',
    gender: 'male',
    birthDate: '1960-11-01',
    phoneE164: '+84907770000',
    generation: 3,
    jobTitle: 'Co van ho toc',
    bio: 'Thanh vien lon tuoi ho tro kiem thu danh sach.',
  }),
  createMember({
    id: 'member_demo_elder_spouse_001',
    branchId: 'branch_demo_001',
    fullName: 'Ba Mai',
    nickName: 'Mai',
    gender: 'female',
    birthDate: '1962-03-14',
    deathDate: '2024-02-15',
    generation: 3,
    status: 'deceased',
    jobTitle: 'Co van van hoa',
  }),
  createMember({
    id: 'member_demo_parent_001',
    branchId: 'branch_demo_001',
    fullName: 'Nguyen Minh',
    nickName: 'Minh',
    gender: 'male',
    birthDate: '1988-02-14',
    phoneE164: '+84901234567',
    email: 'minh@befam.vn',
    addressText: 'Da Nang, Viet Nam',
    generation: 4,
    primaryRole: 'CLAN_ADMIN',
    jobTitle: 'Clan Coordinator',
    bio: 'Dieu phoi khoi tao khong gian ho toc mau cho BeFam.',
  }),
  createMember({
    id: 'member_demo_spouse_001',
    branchId: 'branch_demo_001',
    fullName: 'Nguyen Thi Giau',
    nickName: 'Giau',
    gender: 'female',
    birthDate: '1989-08-23',
    phoneE164: '+84901112233',
    generation: 4,
    jobTitle: 'Tai chinh gia dinh',
  }),
  createMember({
    id: 'member_demo_uncle_001',
    branchId: 'branch_demo_001',
    fullName: 'Le Dai Gia',
    nickName: 'Dai Gia',
    gender: 'male',
    birthDate: '1991-05-17',
    phoneE164: '+84905550001',
    generation: 4,
    jobTitle: 'Doanh nhan',
  }),
  createMember({
    id: 'member_demo_uncle_spouse_001',
    branchId: 'branch_demo_001',
    fullName: 'Pham Thi Sang',
    nickName: 'Sang',
    gender: 'female',
    birthDate: '1992-07-07',
    deathDate: '2025-07-07',
    generation: 4,
    status: 'deceased',
    jobTitle: 'Giao vien',
  }),
  createMember({
    id: 'member_demo_parent_002',
    branchId: 'branch_demo_002',
    fullName: 'Tran Lan',
    nickName: 'Lan',
    gender: 'female',
    birthDate: '1990-07-21',
    phoneE164: '+84908886655',
    email: 'lan@befam.vn',
    addressText: 'Hue, Viet Nam',
    generation: 4,
    primaryRole: 'BRANCH_ADMIN',
    jobTitle: 'Branch Lead',
    bio: 'Dieu phoi hoat dong thanh vien theo chi.',
  }),
  createMember({
    id: 'member_demo_spouse_002',
    branchId: 'branch_demo_002',
    fullName: 'Pham Van Quy',
    nickName: 'Quy',
    gender: 'male',
    birthDate: '1989-10-01',
    phoneE164: '+84903334444',
    generation: 4,
    jobTitle: 'Ky su',
  }),
  createMember({
    id: 'member_demo_aunt_001',
    branchId: 'branch_demo_002',
    fullName: 'Le Thi Hoa',
    nickName: 'Hoa',
    gender: 'female',
    birthDate: '1993-06-19',
    phoneE164: '+84905550002',
    generation: 4,
    jobTitle: 'Dieu duong',
  }),
  createMember({
    id: 'member_demo_aunt_spouse_001',
    branchId: 'branch_demo_002',
    fullName: 'Le Van Vinh',
    nickName: 'Vinh',
    gender: 'male',
    birthDate: '1992-12-20',
    generation: 4,
    jobTitle: 'Ke toan',
  }),
  createMember({
    id: 'member_demo_branch3_lead_001',
    branchId: 'branch_demo_003',
    fullName: 'Nguyen Van Dai',
    nickName: 'Dai',
    gender: 'male',
    birthDate: '1996-02-25',
    phoneE164: '+84906660001',
    generation: 5,
    primaryRole: 'BRANCH_ADMIN',
    jobTitle: 'Branch 3 Lead',
  }),
  createMember({
    id: 'member_demo_branch3_spouse_001',
    branchId: 'branch_demo_003',
    fullName: 'Pham Thi Vy',
    nickName: 'Vy',
    gender: 'female',
    birthDate: '1997-11-11',
    generation: 5,
    jobTitle: 'Ban to chuc',
  }),
  createMember({
    id: 'member_demo_branch4_lead_001',
    branchId: 'branch_demo_004',
    fullName: 'Nguyen Van Su',
    nickName: 'Su',
    gender: 'male',
    birthDate: '1997-04-16',
    phoneE164: '+84907770111',
    generation: 5,
    primaryRole: 'BRANCH_ADMIN',
    jobTitle: 'Branch 4 Lead',
  }),
  createMember({
    id: 'member_demo_branch4_spouse_001',
    branchId: 'branch_demo_004',
    fullName: 'Le Thi Hoang',
    nickName: 'Hoang',
    gender: 'female',
    birthDate: '1998-09-04',
    generation: 5,
    jobTitle: 'Noi vu',
  }),
  createMember({
    id: 'member_demo_child_001',
    branchId: 'branch_demo_001',
    fullName: 'Be Minh',
    nickName: 'Minh nho',
    gender: 'male',
    birthDate: '2017-04-12',
    generation: 6,
    isMinor: true,
    jobTitle: 'Hoc sinh',
    bio: 'Thanh vien tre em dung cho luong OTP phu huynh.',
  }),
  createMember({
    id: 'member_demo_child_002',
    branchId: 'branch_demo_002',
    fullName: 'Be Lan',
    nickName: 'Lan nho',
    gender: 'female',
    birthDate: '2016-09-09',
    generation: 6,
    isMinor: true,
    jobTitle: 'Hoc sinh',
    bio: 'Thanh vien tre em mau cho kiem thu quyen doc.',
  }),
  createMember({
    id: 'member_demo_child_003',
    branchId: 'branch_demo_001',
    fullName: 'Nguyen Thi Dinh',
    nickName: 'Dinh',
    gender: 'female',
    birthDate: '2015-03-22',
    generation: 6,
    isMinor: true,
    jobTitle: 'Hoc sinh',
  }),
  createMember({
    id: 'member_demo_child_004',
    branchId: 'branch_demo_002',
    fullName: 'Le Van Nhat',
    nickName: 'Nhat',
    gender: 'male',
    birthDate: '2014-07-14',
    generation: 6,
    isMinor: true,
    jobTitle: 'Hoc sinh',
  }),
  createMember({
    id: 'member_demo_cousin_001',
    branchId: 'branch_demo_001',
    fullName: 'Pham Thi Loi',
    nickName: 'Loi',
    gender: 'female',
    birthDate: '2012-08-19',
    generation: 6,
    isMinor: true,
    jobTitle: 'Hoc sinh',
  }),
  createMember({
    id: 'member_demo_cousin_002',
    branchId: 'branch_demo_001',
    fullName: 'Nguyen Thi Hong',
    nickName: 'Hong',
    gender: 'female',
    birthDate: '2011-12-09',
    generation: 6,
    isMinor: true,
    jobTitle: 'Hoc sinh',
  }),
  createMember({
    id: 'member_demo_cousin_003',
    branchId: 'branch_demo_002',
    fullName: 'Tran Van An',
    nickName: 'An',
    gender: 'male',
    birthDate: '2010-06-03',
    generation: 6,
    isMinor: true,
    jobTitle: 'Hoc sinh',
  }),
  createMember({
    id: 'member_demo_branch3_member_001',
    branchId: 'branch_demo_003',
    fullName: 'Le Van Vu',
    nickName: 'Vu',
    gender: 'male',
    birthDate: '2011-10-18',
    generation: 6,
    isMinor: true,
    jobTitle: 'Hoc sinh',
  }),
  createMember({
    id: 'member_demo_branch3_member_spouse_001',
    branchId: 'branch_demo_003',
    fullName: 'Tran Thi Tuoi',
    nickName: 'Tuoi',
    gender: 'female',
    birthDate: '2011-11-08',
    generation: 6,
    isMinor: true,
    jobTitle: 'Hoc sinh',
  }),
  createMember({
    id: 'member_demo_branch4_child_002',
    branchId: 'branch_demo_004',
    fullName: 'Nguyen Thi Van',
    nickName: 'Van',
    gender: 'female',
    birthDate: '2012-02-01',
    generation: 6,
    isMinor: true,
    jobTitle: 'Hoc sinh',
  }),
  createMember({
    id: 'member_demo_branch3_child_001',
    branchId: 'branch_demo_003',
    fullName: 'Le Van Ky',
    nickName: 'Ky',
    gender: 'male',
    birthDate: '2021-05-20',
    generation: 7,
    isMinor: true,
    jobTitle: 'Tre em',
  }),
  createMember({
    id: 'member_demo_branch3_child_002',
    branchId: 'branch_demo_003',
    fullName: 'Le Thi Dieu',
    nickName: 'Dieu',
    gender: 'female',
    birthDate: '2023-09-15',
    generation: 7,
    isMinor: true,
    jobTitle: 'Tre em',
  }),
  createMember({
    id: 'member_demo_branch4_child_001',
    branchId: 'branch_demo_004',
    fullName: 'Le Van Khoa',
    nickName: 'Khoa',
    gender: 'male',
    birthDate: '2020-01-30',
    generation: 7,
    isMinor: true,
    jobTitle: 'Tre em',
  }),
  createMember({
    id: 'member_demo_branch4_child_spouse_001',
    branchId: 'branch_demo_004',
    fullName: 'Nguyen Thi Nhu',
    nickName: 'Nhu',
    gender: 'female',
    birthDate: '2020-03-12',
    generation: 7,
    isMinor: true,
    jobTitle: 'Tre em',
  }),
  createMember({
    id: 'member_demo_branch3_grandchild_001',
    branchId: 'branch_demo_003',
    fullName: 'Nguyen Thi Anh',
    nickName: 'Anh',
    gender: 'female',
    birthDate: '2025-12-02',
    generation: 8,
    isMinor: true,
    jobTitle: 'So sinh',
  }),
  createMember({
    id: 'member_demo_branch4_grandchild_001',
    branchId: 'branch_demo_004',
    fullName: 'Nguyen Nhu Anh',
    nickName: 'Nhu Anh',
    gender: 'female',
    birthDate: '2026-01-04',
    generation: 9,
    isMinor: true,
    jobTitle: 'So sinh',
  }),
];

const relationships = [
  createSpouse('member_demo_ancestor_001', 'member_demo_ancestor_002'),
  createSpouse('member_demo_elder_001', 'member_demo_elder_spouse_001'),
  createSpouse('member_demo_parent_001', 'member_demo_spouse_001'),
  createSpouse('member_demo_parent_002', 'member_demo_spouse_002'),
  createSpouse('member_demo_uncle_001', 'member_demo_uncle_spouse_001'),
  createSpouse('member_demo_aunt_001', 'member_demo_aunt_spouse_001'),
  createSpouse('member_demo_branch3_lead_001', 'member_demo_branch3_spouse_001'),
  createSpouse(
    'member_demo_branch3_member_001',
    'member_demo_branch3_member_spouse_001',
  ),
  createSpouse('member_demo_branch4_lead_001', 'member_demo_branch4_spouse_001'),
  createSpouse(
    'member_demo_branch4_child_001',
    'member_demo_branch4_child_spouse_001',
  ),
  createParentChild('member_demo_ancestor_001', 'member_demo_elder_001'),
  createParentChild('member_demo_ancestor_002', 'member_demo_elder_001'),
  createParentChild('member_demo_elder_001', 'member_demo_parent_001'),
  createParentChild('member_demo_elder_spouse_001', 'member_demo_parent_001'),
  createParentChild('member_demo_elder_001', 'member_demo_parent_002'),
  createParentChild('member_demo_elder_spouse_001', 'member_demo_parent_002'),
  createParentChild('member_demo_elder_001', 'member_demo_uncle_001'),
  createParentChild('member_demo_elder_spouse_001', 'member_demo_uncle_001'),
  createParentChild('member_demo_elder_001', 'member_demo_aunt_001'),
  createParentChild('member_demo_elder_spouse_001', 'member_demo_aunt_001'),
  createParentChild('member_demo_parent_001', 'member_demo_child_001'),
  createParentChild('member_demo_spouse_001', 'member_demo_child_001'),
  createParentChild('member_demo_parent_001', 'member_demo_child_003'),
  createParentChild('member_demo_spouse_001', 'member_demo_child_003'),
  createParentChild('member_demo_parent_002', 'member_demo_child_002'),
  createParentChild('member_demo_spouse_002', 'member_demo_child_002'),
  createParentChild('member_demo_parent_002', 'member_demo_child_004'),
  createParentChild('member_demo_spouse_002', 'member_demo_child_004'),
  createParentChild('member_demo_uncle_001', 'member_demo_cousin_001'),
  createParentChild('member_demo_uncle_spouse_001', 'member_demo_cousin_001'),
  createParentChild('member_demo_uncle_001', 'member_demo_cousin_002'),
  createParentChild('member_demo_uncle_spouse_001', 'member_demo_cousin_002'),
  createParentChild('member_demo_uncle_001', 'member_demo_branch3_lead_001'),
  createParentChild(
    'member_demo_uncle_spouse_001',
    'member_demo_branch3_lead_001',
  ),
  createParentChild('member_demo_aunt_001', 'member_demo_cousin_003'),
  createParentChild('member_demo_aunt_spouse_001', 'member_demo_cousin_003'),
  createParentChild('member_demo_aunt_001', 'member_demo_branch4_lead_001'),
  createParentChild('member_demo_aunt_spouse_001', 'member_demo_branch4_lead_001'),
  createParentChild('member_demo_branch3_lead_001', 'member_demo_branch3_child_001'),
  createParentChild(
    'member_demo_branch3_spouse_001',
    'member_demo_branch3_child_001',
  ),
  createParentChild('member_demo_branch3_lead_001', 'member_demo_branch3_child_002'),
  createParentChild(
    'member_demo_branch3_spouse_001',
    'member_demo_branch3_child_002',
  ),
  createParentChild('member_demo_branch3_member_001', 'member_demo_branch3_grandchild_001'),
  createParentChild(
    'member_demo_branch3_member_spouse_001',
    'member_demo_branch3_grandchild_001',
  ),
  createParentChild('member_demo_branch4_lead_001', 'member_demo_branch4_child_001'),
  createParentChild(
    'member_demo_branch4_spouse_001',
    'member_demo_branch4_child_001',
  ),
  createParentChild('member_demo_branch4_lead_001', 'member_demo_branch4_child_002'),
  createParentChild(
    'member_demo_branch4_spouse_001',
    'member_demo_branch4_child_002',
  ),
  createParentChild(
    'member_demo_branch4_child_001',
    'member_demo_branch4_grandchild_001',
  ),
  createParentChild(
    'member_demo_branch4_child_spouse_001',
    'member_demo_branch4_grandchild_001',
  ),
];

const memberById = new Map(
  members.map((member) => [
    member.id,
    {
      ...member,
      parentIds: [],
      childrenIds: [],
      spouseIds: [],
    },
  ]),
);

for (const relationship of relationships) {
  const personA = memberById.get(relationship.personA);
  const personB = memberById.get(relationship.personB);
  if (personA == null || personB == null) {
    continue;
  }

  if (relationship.type === 'parent_child') {
    personA.childrenIds.push(personB.id);
    personB.parentIds.push(personA.id);
    continue;
  }

  if (relationship.type === 'spouse') {
    personA.spouseIds.push(personB.id);
    personB.spouseIds.push(personA.id);
  }
}

const normalizedMembers = [...memberById.values()].map((member) => ({
  ...member,
  parentIds: uniqueSorted(member.parentIds),
  childrenIds: uniqueSorted(member.childrenIds),
  spouseIds: uniqueSorted(member.spouseIds),
}));

const branches = [
  {
    id: 'branch_demo_001',
    clanId,
    name: 'Chi Truong',
    code: 'CT01',
    leaderMemberId: 'member_demo_parent_001',
    viceLeaderMemberId: 'member_demo_parent_002',
    generationLevelHint: 3,
    status: 'active',
    memberCount: 0,
    createdAt: now,
    createdBy: 'seed-script',
    updatedAt: now,
    updatedBy: 'seed-script',
  },
  {
    id: 'branch_demo_002',
    clanId,
    name: 'Chi Phu',
    code: 'CP02',
    leaderMemberId: 'member_demo_parent_002',
    viceLeaderMemberId: 'member_demo_elder_001',
    generationLevelHint: 4,
    status: 'active',
    memberCount: 0,
    createdAt: now,
    createdBy: 'seed-script',
    updatedAt: now,
    updatedBy: 'seed-script',
  },
  {
    id: 'branch_demo_003',
    clanId,
    name: 'Chi Thanh Dat',
    code: 'CTD03',
    leaderMemberId: 'member_demo_branch3_lead_001',
    viceLeaderMemberId: 'member_demo_uncle_001',
    generationLevelHint: 5,
    status: 'active',
    memberCount: 0,
    createdAt: now,
    createdBy: 'seed-script',
    updatedAt: now,
    updatedBy: 'seed-script',
  },
  {
    id: 'branch_demo_004',
    clanId,
    name: 'Chi Hanh Phuc',
    code: 'CHP04',
    leaderMemberId: 'member_demo_branch4_lead_001',
    viceLeaderMemberId: 'member_demo_aunt_001',
    generationLevelHint: 5,
    status: 'active',
    memberCount: 0,
    createdAt: now,
    createdBy: 'seed-script',
    updatedAt: now,
    updatedBy: 'seed-script',
  },
];

for (const branch of branches) {
  branch.memberCount = normalizedMembers.filter(
    (member) => member.branchId === branch.id,
  ).length;
}

const clan = {
  id: clanId,
  name: 'Ho toc BeFam',
  slug: 'ho-toc-befam',
  description:
    'Khong gian demo nhieu the he de kiem thu kham pha cay gia pha tren du lieu lon.',
  countryCode: 'VN',
  founderName: 'Nguyen Minh to',
  logoUrl: '',
  status: 'active',
  memberCount: normalizedMembers.length,
  branchCount: branches.length,
  createdAt: now,
  createdBy: 'seed-script',
  updatedAt: now,
  updatedBy: 'seed-script',
};

const invites = [
  {
    id: 'invite_phone_claim_parent_001',
    clanId,
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
    clanId,
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
    id: 'invite_phone_claim_branch3_lead',
    clanId,
    branchId: 'branch_demo_003',
    memberId: 'member_demo_branch3_lead_001',
    inviteType: 'phone_claim',
    phoneE164: '+84906660001',
    childIdentifier: null,
    status: 'pending',
    expiresAt,
    createdAt: now,
    createdBy: 'seed-script',
  },
  {
    id: 'invite_phone_claim_branch4_lead',
    clanId,
    branchId: 'branch_demo_004',
    memberId: 'member_demo_branch4_lead_001',
    inviteType: 'phone_claim',
    phoneE164: '+84907770111',
    childIdentifier: null,
    status: 'pending',
    expiresAt,
    createdAt: now,
    createdBy: 'seed-script',
  },
  {
    id: 'invite_child_001',
    clanId,
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
    clanId,
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
  {
    id: 'invite_child_003',
    clanId,
    branchId: 'branch_demo_001',
    memberId: 'member_demo_child_003',
    inviteType: 'child_access',
    phoneE164: '+84901234567',
    childIdentifier: 'BEFAM-CHILD-003',
    status: 'pending',
    expiresAt,
    createdAt: now,
    createdBy: 'seed-script',
  },
  {
    id: 'invite_child_004',
    clanId,
    branchId: 'branch_demo_002',
    memberId: 'member_demo_child_004',
    inviteType: 'child_access',
    phoneE164: '+84908886655',
    childIdentifier: 'BEFAM-CHILD-004',
    status: 'pending',
    expiresAt,
    createdAt: now,
    createdBy: 'seed-script',
  },
];

const debugLoginProfiles = [
  {
    phoneE164: '+84901234567',
    scenarioKey: 'clan_admin_existing',
    title: 'Trưởng tộc đã có gia phả',
    description: 'CLAN_ADMIN đã liên kết thành viên và có dữ liệu gia phả.',
    memberId: 'member_demo_parent_001',
    clanId: 'clan_demo_001',
    branchId: 'branch_demo_001',
    primaryRole: 'CLAN_ADMIN',
    accessMode: 'claimed',
    linkedAuthUid: true,
    sortOrder: 10,
    isActive: true,
    updatedAt: now,
    createdAt: now,
  },
  {
    phoneE164: '+84908886655',
    scenarioKey: 'branch_admin_existing',
    title: 'Trưởng chi đã có gia phả',
    description: 'BRANCH_ADMIN đã liên kết và quản lý một chi hiện có.',
    memberId: 'member_demo_parent_002',
    clanId: 'clan_demo_001',
    branchId: 'branch_demo_002',
    primaryRole: 'BRANCH_ADMIN',
    accessMode: 'claimed',
    linkedAuthUid: true,
    sortOrder: 20,
    isActive: true,
    updatedAt: now,
    createdAt: now,
  },
  {
    phoneE164: '+84907770011',
    scenarioKey: 'member_existing',
    title: 'Thành viên thường đã vào gia phả',
    description: 'MEMBER đã liên kết hồ sơ để kiểm thử quyền người dùng thường.',
    memberId: 'member_demo_elder_001',
    clanId: 'clan_demo_001',
    branchId: 'branch_demo_001',
    primaryRole: 'MEMBER',
    accessMode: 'claimed',
    linkedAuthUid: true,
    sortOrder: 30,
    isActive: true,
    updatedAt: now,
    createdAt: now,
  },
  {
    phoneE164: '+84906660022',
    scenarioKey: 'user_unlinked',
    title: 'User chưa vào gia phả nào',
    description: 'Tài khoản chưa liên kết member/clan để kiểm thử onboarding.',
    memberId: null,
    clanId: null,
    branchId: null,
    primaryRole: null,
    accessMode: 'unlinked',
    linkedAuthUid: false,
    sortOrder: 40,
    isActive: true,
    updatedAt: now,
    createdAt: now,
  },
  {
    phoneE164: '+84905550033',
    scenarioKey: 'branch_admin_unlinked',
    title: 'Trưởng chi chưa gắn gia phả',
    description:
      'Role BRANCH_ADMIN nhưng chưa gắn clan/branch để kiểm thử phân quyền.',
    memberId: null,
    clanId: null,
    branchId: null,
    primaryRole: 'BRANCH_ADMIN',
    accessMode: 'unlinked',
    linkedAuthUid: false,
    sortOrder: 50,
    isActive: true,
    updatedAt: now,
    createdAt: now,
  },
  {
    phoneE164: '+84909990001',
    scenarioKey: 'clan_admin_uninitialized',
    title: 'Trưởng tộc chưa tạo gia phả',
    description: 'CLAN_ADMIN có context tạo clan mới nhưng chưa có dữ liệu.',
    memberId: null,
    clanId: 'clan_onboarding_001',
    branchId: null,
    primaryRole: 'CLAN_ADMIN',
    accessMode: 'claimed',
    linkedAuthUid: true,
    sortOrder: 60,
    isActive: true,
    updatedAt: now,
    createdAt: now,
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

  for (const member of normalizedMembers) {
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

  for (const profile of debugLoginProfiles) {
    const ref = db.collection('debug_login_profiles').doc(profile.phoneE164);
    batch.set(ref, profile, { merge: true });
  }

  await batch.commit();

  console.log('Seeded extended demo clan data successfully.');
  console.log(`Project: ${projectId}`);
  console.log(`Clan: ${clan.id}`);
  console.log(`Members: ${normalizedMembers.length}`);
  console.log(`Branches: ${branches.length}`);
  console.log(`Relationships: ${relationships.length}`);
  console.log(`Invites: ${invites.length}`);
  console.log(`Debug login profiles: ${debugLoginProfiles.length}`);
}

seed().catch((error) => {
  console.error('Failed to seed demo data.');
  console.error(error);
  process.exit(1);
});
