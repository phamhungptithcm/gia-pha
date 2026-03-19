#!/usr/bin/env node

import { readFileSync } from 'node:fs';

import { applicationDefault, cert, initializeApp } from 'firebase-admin/app';
import { getFirestore, Timestamp } from 'firebase-admin/firestore';

const projectId =
  process.env.FIREBASE_PROJECT_ID ||
  process.env.GOOGLE_CLOUD_PROJECT ||
  process.env.GCLOUD_PROJECT ||
  '';
const serviceAccountJson = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;

if (!projectId) {
  throw new Error(
    "Missing FIREBASE_PROJECT_ID (or GOOGLE_CLOUD_PROJECT/GCLOUD_PROJECT) for seed script.",
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
const expiresAt = Timestamp.fromDate(
  new Date(Date.now() + 365 * 24 * 60 * 60 * 1000),
);
const clanId = 'clan_demo_001';
const clanOwnerUid = 'seed_uid_member_demo_parent_001';
const ownerBillingScopeId = `user_scope__${clanOwnerUid}`;
const ownerScopedBillingDocId = `${ownerBillingScopeId}__${clanOwnerUid}`;

function normalizeName(value) {
  return value.trim().toLowerCase().replace(/\s+/g, ' ');
}

function uniqueSorted(values) {
  return [...new Set(values.filter(Boolean))].sort();
}

function ts(value) {
  return Timestamp.fromDate(new Date(value));
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
  addressText = 'Việt Nam',
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
    bio: bio ?? `Thành viên mẫu ${fullName}.`,
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
    fullName: 'Lê Thành Công',
    nickName: 'Công',
    gender: 'male',
    birthDate: '1941-01-10',
    deathDate: '2021-11-02',
    phoneE164: '+84901110001',
    generation: 2,
    status: 'deceased',
    jobTitle: 'Tộc trưởng',
    bio: 'Tổ tiên truyền thống của dòng họ mẫu.',
  }),
  createMember({
    id: 'member_demo_ancestor_002',
    branchId: 'branch_demo_001',
    fullName: 'Phạm Hạnh Phúc',
    nickName: 'Phúc',
    gender: 'female',
    birthDate: '1944-04-18',
    deathDate: '2022-05-01',
    generation: 2,
    status: 'deceased',
    jobTitle: 'Nội trợ',
    bio: 'Tổ tiên đã mất, dùng để kiểm thử trạng thái đã mất.',
  }),
  createMember({
    id: 'member_demo_elder_001',
    branchId: 'branch_demo_001',
    fullName: 'Ông Bảo',
    nickName: '',
    gender: 'male',
    birthDate: '1960-11-01',
    phoneE164: '+84907770000',
    generation: 3,
    jobTitle: 'Cố vấn họ tộc',
    bio: 'Thành viên lớn tuổi hỗ trợ kiểm thử danh sách.',
  }),
  createMember({
    id: 'member_demo_elder_spouse_001',
    branchId: 'branch_demo_001',
    fullName: 'Bà Mai',
    nickName: 'Mai',
    gender: 'female',
    birthDate: '1962-03-14',
    deathDate: '2024-02-15',
    generation: 3,
    status: 'deceased',
    jobTitle: 'Cố vấn văn hóa',
  }),
  createMember({
    id: 'member_demo_parent_001',
    branchId: 'branch_demo_001',
    fullName: 'Nguyễn Minh',
    nickName: 'Minh',
    gender: 'male',
    birthDate: '1988-02-14',
    phoneE164: '+84901234567',
    email: 'minh@befam.vn',
    addressText: 'Đà Nẵng, Việt Nam',
    generation: 4,
    primaryRole: 'CLAN_ADMIN',
    jobTitle: 'Điều phối họ tộc',
    bio: 'Điều phối khởi tạo không gian họ tộc mẫu cho ứng dụng gia phả.',
  }),
  createMember({
    id: 'member_demo_spouse_001',
    branchId: 'branch_demo_001',
    fullName: 'Nguyễn Thị Giàu',
    nickName: 'Giàu',
    gender: 'female',
    birthDate: '1989-08-23',
    phoneE164: '+84901112233',
    generation: 4,
    jobTitle: 'Tài chính gia đình',
  }),
  createMember({
    id: 'member_demo_uncle_001',
    branchId: 'branch_demo_001',
    fullName: 'Lê Quốc Thắng',
    nickName: 'Quốc Thắng',
    gender: 'male',
    birthDate: '1978-05-17',
    phoneE164: '+84905550001',
    generation: 4,
    jobTitle: 'Doanh nhân vật liệu xây dựng',
  }),
  createMember({
    id: 'member_demo_uncle_spouse_001',
    branchId: 'branch_demo_001',
    fullName: 'Phạm Thị Sang',
    nickName: 'Sang',
    gender: 'female',
    birthDate: '1980-07-07',
    generation: 4,
    jobTitle: 'Giáo viên trung học',
  }),
  createMember({
    id: 'member_demo_parent_002',
    branchId: 'branch_demo_002',
    fullName: 'Trần Văn Long',
    nickName: 'Long',
    gender: 'male',
    birthDate: '1990-07-21',
    phoneE164: '+84908886655',
    email: 'long@befam.vn',
    addressText: 'Huế, Việt Nam',
    generation: 4,
    primaryRole: 'BRANCH_ADMIN',
    jobTitle: 'Trưởng chi phụ',
    bio: 'Trưởng chi phụ, điều phối hoạt động thành viên theo nam hệ.',
  }),
  createMember({
    id: 'member_demo_spouse_002',
    branchId: 'branch_demo_002',
    fullName: 'Phạm Thị Quyên',
    nickName: 'Quyên',
    gender: 'female',
    birthDate: '1989-10-01',
    phoneE164: '+84903334444',
    generation: 4,
    jobTitle: 'Kỹ sư',
  }),
  createMember({
    id: 'member_demo_aunt_001',
    branchId: 'branch_demo_002',
    fullName: 'Lê Thị Hoa',
    nickName: 'Hoa',
    gender: 'female',
    birthDate: '1980-06-19',
    phoneE164: '+84905550002',
    generation: 4,
    jobTitle: 'Điều dưỡng trưởng',
  }),
  createMember({
    id: 'member_demo_aunt_spouse_001',
    branchId: 'branch_demo_002',
    fullName: 'Lê Văn Vinh',
    nickName: 'Vinh',
    gender: 'male',
    birthDate: '1979-12-20',
    generation: 4,
    jobTitle: 'Kỹ sư cầu đường',
  }),
  createMember({
    id: 'member_demo_branch3_lead_001',
    branchId: 'branch_demo_003',
    fullName: 'Nguyễn Văn Đại',
    nickName: 'Đại',
    gender: 'male',
    birthDate: '1997-02-25',
    phoneE164: '+84906660001',
    generation: 5,
    primaryRole: 'BRANCH_ADMIN',
    jobTitle: 'Trưởng chi 3',
  }),
  createMember({
    id: 'member_demo_branch3_spouse_001',
    branchId: 'branch_demo_003',
    fullName: 'Phạm Thị Vy',
    nickName: 'Vy',
    gender: 'female',
    birthDate: '1997-11-11',
    generation: 5,
    jobTitle: 'Ban tổ chức',
  }),
  createMember({
    id: 'member_demo_branch4_lead_001',
    branchId: 'branch_demo_004',
    fullName: 'Nguyễn Văn Sử',
    nickName: 'Sử',
    gender: 'male',
    birthDate: '1997-04-16',
    phoneE164: '+84907770111',
    generation: 5,
    primaryRole: 'BRANCH_ADMIN',
    jobTitle: 'Trưởng chi 4',
  }),
  createMember({
    id: 'member_demo_branch4_spouse_001',
    branchId: 'branch_demo_004',
    fullName: 'Lê Thị Hoàng',
    nickName: 'Hoàng',
    gender: 'female',
    birthDate: '1998-09-04',
    generation: 5,
    jobTitle: 'Nội vụ',
  }),
  createMember({
    id: 'member_demo_child_001',
    branchId: 'branch_demo_001',
    fullName: 'Bé Minh',
    nickName: 'Minh nhỏ',
    gender: 'male',
    birthDate: '2017-04-12',
    generation: 6,
    isMinor: true,
    jobTitle: 'Học sinh',
    bio: 'Thành viên trẻ em dùng cho luồng OTP phụ huynh.',
  }),
  createMember({
    id: 'member_demo_child_002',
    branchId: 'branch_demo_002',
    fullName: 'Bé Lan',
    nickName: 'Lan nhỏ',
    gender: 'female',
    birthDate: '2016-09-09',
    generation: 6,
    isMinor: true,
    jobTitle: 'Học sinh',
    bio: 'Thành viên trẻ em mẫu cho kiểm thử quyền đọc.',
  }),
  createMember({
    id: 'member_demo_child_003',
    branchId: 'branch_demo_001',
    fullName: 'Nguyễn Thị Đinh',
    nickName: 'Đinh',
    gender: 'female',
    birthDate: '2015-03-22',
    generation: 6,
    isMinor: true,
    jobTitle: 'Học sinh',
  }),
  createMember({
    id: 'member_demo_child_004',
    branchId: 'branch_demo_002',
    fullName: 'Lê Văn Nhật',
    nickName: 'Nhật',
    gender: 'male',
    birthDate: '2014-07-14',
    generation: 6,
    isMinor: true,
    jobTitle: 'Học sinh',
  }),
  createMember({
    id: 'member_demo_cousin_001',
    branchId: 'branch_demo_001',
    fullName: 'Phạm Thị Lợi',
    nickName: 'Lợi',
    gender: 'female',
    birthDate: '2012-08-19',
    generation: 6,
    isMinor: true,
    jobTitle: 'Học sinh',
  }),
  createMember({
    id: 'member_demo_cousin_002',
    branchId: 'branch_demo_001',
    fullName: 'Nguyễn Thị Hồng',
    nickName: 'Hồng',
    gender: 'female',
    birthDate: '2011-12-09',
    generation: 6,
    isMinor: true,
    jobTitle: 'Học sinh',
  }),
  createMember({
    id: 'member_demo_cousin_003',
    branchId: 'branch_demo_002',
    fullName: 'Trần Văn An',
    nickName: 'An',
    gender: 'male',
    birthDate: '2010-06-03',
    generation: 6,
    isMinor: true,
    jobTitle: 'Học sinh',
  }),
  createMember({
    id: 'member_demo_branch3_member_001',
    branchId: 'branch_demo_003',
    fullName: 'Lê Văn Vũ',
    nickName: 'Vũ',
    gender: 'male',
    birthDate: '2002-10-18',
    generation: 6,
    isMinor: false,
    jobTitle: 'Công nhân cơ khí',
  }),
  createMember({
    id: 'member_demo_branch3_member_spouse_001',
    branchId: 'branch_demo_003',
    fullName: 'Trần Thị Tươi',
    nickName: 'Tươi',
    gender: 'female',
    birthDate: '2003-11-08',
    generation: 6,
    isMinor: false,
    jobTitle: 'Sinh viên năm cuối',
  }),
  createMember({
    id: 'member_demo_branch4_child_002',
    branchId: 'branch_demo_004',
    fullName: 'Nguyễn Thị Vân',
    nickName: 'Vân',
    gender: 'female',
    birthDate: '2015-10-01',
    generation: 6,
    isMinor: true,
    jobTitle: 'Học sinh',
  }),
  createMember({
    id: 'member_demo_branch3_child_001',
    branchId: 'branch_demo_003',
    fullName: 'Lê Văn Kỳ',
    nickName: 'Kỳ',
    gender: 'male',
    birthDate: '2021-05-20',
    generation: 7,
    isMinor: true,
    jobTitle: 'Trẻ em',
  }),
  createMember({
    id: 'member_demo_branch3_child_002',
    branchId: 'branch_demo_003',
    fullName: 'Lê Thị Diệu',
    nickName: 'Diệu',
    gender: 'female',
    birthDate: '2023-09-15',
    generation: 7,
    isMinor: true,
    jobTitle: 'Trẻ em',
  }),
  createMember({
    id: 'member_demo_branch4_child_001',
    branchId: 'branch_demo_004',
    fullName: 'Lê Văn Khoa',
    nickName: 'Khoa',
    gender: 'male',
    birthDate: '2020-01-30',
    generation: 7,
    isMinor: true,
    jobTitle: 'Trẻ em',
  }),
  createMember({
    id: 'member_demo_branch4_child_spouse_001',
    branchId: 'branch_demo_004',
    fullName: 'Nguyễn Thị Như',
    nickName: 'Như',
    gender: 'female',
    birthDate: '2020-03-12',
    generation: 7,
    isMinor: true,
    jobTitle: 'Trẻ em',
  }),
  createMember({
    id: 'member_demo_branch3_grandchild_001',
    branchId: 'branch_demo_003',
    fullName: 'Nguyễn Thị Anh',
    nickName: 'Anh',
    gender: 'female',
    birthDate: '2025-12-02',
    generation: 8,
    isMinor: true,
    jobTitle: 'Sơ sinh',
  }),
  createMember({
    id: 'member_demo_branch4_grandchild_001',
    branchId: 'branch_demo_004',
    fullName: 'Nguyễn Như Anh',
    nickName: 'Như Anh',
    gender: 'female',
    birthDate: '2026-01-04',
    generation: 9,
    isMinor: true,
    jobTitle: 'Sơ sinh',
  }),
];

const additionalMembers = [
  createMember({
    id: 'member_demo_b1_elder_001',
    branchId: 'branch_demo_001',
    fullName: 'Võ Văn Lợi',
    nickName: 'Ông Lợi',
    gender: 'male',
    birthDate: '1958-02-04',
    phoneE164: '+84901130001',
    addressText: 'Xã Hòa Châu, Hòa Vang, Đà Nẵng',
    generation: 3,
    jobTitle: 'Nông dân',
  }),
  createMember({
    id: 'member_demo_b1_elder_spouse_001',
    branchId: 'branch_demo_001',
    fullName: 'Đỗ Thị Mến',
    nickName: 'Bà Mến',
    gender: 'female',
    birthDate: '1961-09-12',
    addressText: 'Xã Hòa Châu, Hòa Vang, Đà Nẵng',
    generation: 3,
    jobTitle: 'Làm nông',
  }),
  createMember({
    id: 'member_demo_b1_parent_003',
    branchId: 'branch_demo_001',
    fullName: 'Võ Minh Thuận',
    nickName: 'Thuận',
    gender: 'male',
    birthDate: '1984-05-18',
    phoneE164: '+84901130002',
    email: 'vo.minh.thuan@giapha.vn',
    addressText: 'Phường Hòa Xuân, Cẩm Lệ, Đà Nẵng',
    generation: 4,
    jobTitle: 'Kỹ sư xây dựng',
  }),
  createMember({
    id: 'member_demo_b1_parent_spouse_003',
    branchId: 'branch_demo_001',
    fullName: 'Trịnh Thị Hà',
    nickName: 'Hà',
    gender: 'female',
    birthDate: '1986-01-20',
    phoneE164: '+84901130003',
    addressText: 'Phường Hòa Xuân, Cẩm Lệ, Đà Nẵng',
    generation: 4,
    jobTitle: 'Công nhân may',
  }),
  createMember({
    id: 'member_demo_b1_child_005',
    branchId: 'branch_demo_001',
    fullName: 'Võ Tuấn Kiệt',
    nickName: 'Kiệt',
    gender: 'male',
    birthDate: '2008-09-10',
    addressText: 'Phường Hòa Xuân, Cẩm Lệ, Đà Nẵng',
    generation: 6,
    isMinor: true,
    jobTitle: 'Học sinh',
  }),
  createMember({
    id: 'member_demo_b1_child_006',
    branchId: 'branch_demo_001',
    fullName: 'Võ Ngọc Diễm',
    nickName: 'Diễm',
    gender: 'female',
    birthDate: '2012-11-03',
    addressText: 'Phường Hòa Xuân, Cẩm Lệ, Đà Nẵng',
    generation: 6,
    isMinor: true,
    jobTitle: 'Học sinh',
  }),
  createMember({
    id: 'member_demo_b2_elder_001',
    branchId: 'branch_demo_002',
    fullName: 'Trần Hữu Tín',
    nickName: 'Ông Tín',
    gender: 'male',
    birthDate: '1955-04-09',
    phoneE164: '+84902240001',
    addressText: 'Xã Phong Hiền, Phong Điền, Huế',
    generation: 3,
    jobTitle: 'Chủ tịch xã',
  }),
  createMember({
    id: 'member_demo_b2_elder_spouse_001',
    branchId: 'branch_demo_002',
    fullName: 'Ngô Thị Lành',
    nickName: 'Bà Lành',
    gender: 'female',
    birthDate: '1957-08-26',
    addressText: 'Xã Phong Hiền, Phong Điền, Huế',
    generation: 3,
    jobTitle: 'Làm nông',
  }),
  createMember({
    id: 'member_demo_b2_parent_003',
    branchId: 'branch_demo_002',
    fullName: 'Trần Quốc Toàn',
    nickName: 'Toàn',
    gender: 'male',
    birthDate: '1983-10-06',
    phoneE164: '+84902240002',
    addressText: 'Phường Hương Sơ, Huế',
    generation: 4,
    jobTitle: 'Công nhân cơ khí',
  }),
  createMember({
    id: 'member_demo_b2_parent_spouse_003',
    branchId: 'branch_demo_002',
    fullName: 'Bùi Thị Mỹ Linh',
    nickName: 'Mỹ Linh',
    gender: 'female',
    birthDate: '1985-12-15',
    phoneE164: '+84902240003',
    addressText: 'Phường Hương Sơ, Huế',
    generation: 4,
    jobTitle: 'Quản lý đất đai xã',
  }),
  createMember({
    id: 'member_demo_b2_child_005',
    branchId: 'branch_demo_002',
    fullName: 'Trần Khánh Vy',
    nickName: 'Khánh Vy',
    gender: 'female',
    birthDate: '2006-07-09',
    addressText: 'Phường Hương Sơ, Huế',
    generation: 6,
    isMinor: false,
    jobTitle: 'Sinh viên',
  }),
  createMember({
    id: 'member_demo_b2_child_006',
    branchId: 'branch_demo_002',
    fullName: 'Trần Gia Bảo',
    nickName: 'Gia Bảo',
    gender: 'male',
    birthDate: '2014-03-23',
    addressText: 'Phường Hương Sơ, Huế',
    generation: 6,
    isMinor: true,
    jobTitle: 'Học sinh',
  }),
  createMember({
    id: 'member_demo_b3_parent_002',
    branchId: 'branch_demo_003',
    fullName: 'Lê Hoàng Phúc',
    nickName: 'Hoàng Phúc',
    gender: 'male',
    birthDate: '1978-06-02',
    phoneE164: '+84903350001',
    addressText: 'Phường Hòa Cường Bắc, Hải Châu, Đà Nẵng',
    generation: 5,
    jobTitle: 'Kỹ sư phần mềm',
  }),
  createMember({
    id: 'member_demo_b3_parent_spouse_002',
    branchId: 'branch_demo_003',
    fullName: 'Phan Thị Kim Ngân',
    nickName: 'Kim Ngân',
    gender: 'female',
    birthDate: '1980-02-27',
    addressText: 'Phường Hòa Cường Bắc, Hải Châu, Đà Nẵng',
    generation: 5,
    jobTitle: 'Giáo viên trung học',
  }),
  createMember({
    id: 'member_demo_b3_child_003',
    branchId: 'branch_demo_003',
    fullName: 'Lê Đình Minh Trí',
    nickName: 'Minh Trí',
    gender: 'male',
    birthDate: '2004-08-01',
    addressText: 'Phường Hòa Cường Bắc, Hải Châu, Đà Nẵng',
    generation: 6,
    isMinor: false,
    jobTitle: 'Sinh viên',
  }),
  createMember({
    id: 'member_demo_b3_child_spouse_003',
    branchId: 'branch_demo_003',
    fullName: 'Huỳnh Thảo Nhi',
    nickName: 'Thảo Nhi',
    gender: 'female',
    birthDate: '2005-01-14',
    addressText: 'Phường Hòa Cường Bắc, Hải Châu, Đà Nẵng',
    generation: 6,
    isMinor: false,
    jobTitle: 'Sinh viên',
  }),
  createMember({
    id: 'member_demo_b3_grandchild_002',
    branchId: 'branch_demo_003',
    fullName: 'Lê An Nhiên',
    nickName: 'Nhiên',
    gender: 'female',
    birthDate: '2024-06-19',
    addressText: 'Phường Hòa Cường Bắc, Hải Châu, Đà Nẵng',
    generation: 7,
    isMinor: true,
    jobTitle: 'Trẻ em',
  }),
  createMember({
    id: 'member_demo_b3_child_004',
    branchId: 'branch_demo_003',
    fullName: 'Lê Quốc Bảo',
    nickName: 'Quốc Bảo',
    gender: 'male',
    birthDate: '2009-04-05',
    addressText: 'Phường Hòa Cường Bắc, Hải Châu, Đà Nẵng',
    generation: 6,
    isMinor: true,
    jobTitle: 'Học sinh',
  }),
  createMember({
    id: 'member_demo_b4_parent_002',
    branchId: 'branch_demo_004',
    fullName: 'Nguyễn Công Thành',
    nickName: 'Công Thành',
    gender: 'male',
    birthDate: '1972-03-16',
    phoneE164: '+84904460001',
    addressText: 'Phường Đông Hải 1, Hải An, Hải Phòng',
    generation: 5,
    jobTitle: 'Chủ tịch tỉnh',
  }),
  createMember({
    id: 'member_demo_b4_parent_spouse_002',
    branchId: 'branch_demo_004',
    fullName: 'Trần Thị Phương Thảo',
    nickName: 'Phương Thảo',
    gender: 'female',
    birthDate: '1975-12-08',
    addressText: 'Phường Đông Hải 1, Hải An, Hải Phòng',
    generation: 5,
    jobTitle: 'Cán bộ y tế',
  }),
  createMember({
    id: 'member_demo_b4_child_003',
    branchId: 'branch_demo_004',
    fullName: 'Nguyễn Thành Nam',
    nickName: 'Thành Nam',
    gender: 'male',
    birthDate: '1998-07-30',
    phoneE164: '+84904460002',
    addressText: 'Phường Trại Cau, Lê Chân, Hải Phòng',
    generation: 6,
    isMinor: false,
    jobTitle: 'Kỹ sư phần mềm',
  }),
  createMember({
    id: 'member_demo_b4_child_spouse_003',
    branchId: 'branch_demo_004',
    fullName: 'Phạm Ngọc Hân',
    nickName: 'Ngọc Hân',
    gender: 'female',
    birthDate: '2000-05-21',
    addressText: 'Phường Trại Cau, Lê Chân, Hải Phòng',
    generation: 6,
    isMinor: false,
    jobTitle: 'Kỹ sư xây dựng',
  }),
  createMember({
    id: 'member_demo_b4_grandchild_002',
    branchId: 'branch_demo_004',
    fullName: 'Nguyễn Gia Hân',
    nickName: 'Gia Hân',
    gender: 'female',
    birthDate: '2022-09-11',
    addressText: 'Phường Trại Cau, Lê Chân, Hải Phòng',
    generation: 7,
    isMinor: true,
    jobTitle: 'Trẻ em',
  }),
  createMember({
    id: 'member_demo_b4_child_004',
    branchId: 'branch_demo_004',
    fullName: 'Nguyễn Đức Hải',
    nickName: 'Đức Hải',
    gender: 'male',
    birthDate: '2002-10-10',
    addressText: 'Phường Trại Cau, Lê Chân, Hải Phòng',
    generation: 6,
    isMinor: false,
    jobTitle: 'Phụ hồ',
  }),
];

members.push(...additionalMembers);

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
  createParentChild(
    'member_demo_branch4_lead_001',
    'member_demo_branch4_child_spouse_001',
  ),
  createParentChild(
    'member_demo_branch4_spouse_001',
    'member_demo_branch4_child_spouse_001',
  ),
  createParentChild('member_demo_branch4_lead_001', 'member_demo_branch4_child_002'),
  createParentChild(
    'member_demo_branch4_spouse_001',
    'member_demo_branch4_child_002',
  ),
  createParentChild(
    'member_demo_branch4_lead_001',
    'member_demo_branch4_grandchild_001',
  ),
  createParentChild(
    'member_demo_branch4_spouse_001',
    'member_demo_branch4_grandchild_001',
  ),
];

const additionalRelationships = [
  createSpouse('member_demo_b1_elder_001', 'member_demo_b1_elder_spouse_001'),
  createSpouse('member_demo_b1_parent_003', 'member_demo_b1_parent_spouse_003'),
  createParentChild('member_demo_b1_elder_001', 'member_demo_b1_parent_003'),
  createParentChild(
    'member_demo_b1_elder_spouse_001',
    'member_demo_b1_parent_003',
  ),
  createParentChild('member_demo_b1_parent_003', 'member_demo_b1_child_005'),
  createParentChild(
    'member_demo_b1_parent_spouse_003',
    'member_demo_b1_child_005',
  ),
  createParentChild('member_demo_b1_parent_003', 'member_demo_b1_child_006'),
  createParentChild(
    'member_demo_b1_parent_spouse_003',
    'member_demo_b1_child_006',
  ),
  createSpouse('member_demo_b2_elder_001', 'member_demo_b2_elder_spouse_001'),
  createSpouse('member_demo_b2_parent_003', 'member_demo_b2_parent_spouse_003'),
  createParentChild('member_demo_b2_elder_001', 'member_demo_b2_parent_003'),
  createParentChild(
    'member_demo_b2_elder_spouse_001',
    'member_demo_b2_parent_003',
  ),
  createParentChild('member_demo_b2_parent_003', 'member_demo_b2_child_005'),
  createParentChild(
    'member_demo_b2_parent_spouse_003',
    'member_demo_b2_child_005',
  ),
  createParentChild('member_demo_b2_parent_003', 'member_demo_b2_child_006'),
  createParentChild(
    'member_demo_b2_parent_spouse_003',
    'member_demo_b2_child_006',
  ),
  createSpouse('member_demo_b3_parent_002', 'member_demo_b3_parent_spouse_002'),
  createSpouse('member_demo_b3_child_003', 'member_demo_b3_child_spouse_003'),
  createParentChild('member_demo_b3_parent_002', 'member_demo_b3_child_003'),
  createParentChild(
    'member_demo_b3_parent_spouse_002',
    'member_demo_b3_child_003',
  ),
  createParentChild('member_demo_b3_parent_002', 'member_demo_b3_child_004'),
  createParentChild(
    'member_demo_b3_parent_spouse_002',
    'member_demo_b3_child_004',
  ),
  createParentChild('member_demo_b3_child_003', 'member_demo_b3_grandchild_002'),
  createParentChild(
    'member_demo_b3_child_spouse_003',
    'member_demo_b3_grandchild_002',
  ),
  createSpouse('member_demo_b4_parent_002', 'member_demo_b4_parent_spouse_002'),
  createSpouse('member_demo_b4_child_003', 'member_demo_b4_child_spouse_003'),
  createParentChild('member_demo_b4_parent_002', 'member_demo_b4_child_003'),
  createParentChild(
    'member_demo_b4_parent_spouse_002',
    'member_demo_b4_child_003',
  ),
  createParentChild('member_demo_b4_parent_002', 'member_demo_b4_child_004'),
  createParentChild(
    'member_demo_b4_parent_spouse_002',
    'member_demo_b4_child_004',
  ),
  createParentChild('member_demo_b4_child_003', 'member_demo_b4_grandchild_002'),
  createParentChild(
    'member_demo_b4_child_spouse_003',
    'member_demo_b4_grandchild_002',
  ),
];

relationships.push(...additionalRelationships);

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
    name: 'Chi Trưởng',
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
    name: 'Chi Phụ',
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
    name: 'Chi Thành Đạt',
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
    name: 'Chi Hạnh Phúc',
    code: 'CHP04',
    leaderMemberId: 'member_demo_branch4_lead_001',
    viceLeaderMemberId: 'member_demo_aunt_spouse_001',
    generationLevelHint: 5,
    status: 'active',
    memberCount: 0,
    createdAt: now,
    createdBy: 'seed-script',
    updatedAt: now,
    updatedBy: 'seed-script',
  },
];

function assertMaleLineConstraints({ members, branches }) {
  const maleOnlyRoles = new Set([
    'CLAN_ADMIN',
    'BRANCH_ADMIN',
    'CLAN_LEADER',
    'VICE_LEADER',
    'SUPPORTER_OF_LEADER',
  ]);
  const maleTitlePatterns = [
    /to truong/i,
    /truong toc/i,
    /truong chi/i,
    /dich ton/i,
    /tộc trưởng/i,
    /trưởng tộc/i,
    /trưởng chi/i,
    /đích tôn/i,
  ];
  const memberById = new Map(members.map((member) => [member.id, member]));
  const violations = [];

  for (const member of members) {
    const gender = (member.gender ?? '').toLowerCase();
    const primaryRole = (member.primaryRole ?? '').toUpperCase();
    const leadershipText = `${member.jobTitle ?? ''} ${member.bio ?? ''}`;
    const hasMaleLeadershipRole = maleOnlyRoles.has(primaryRole);
    const hasMaleOnlyLeadershipTitle = maleTitlePatterns.some((pattern) =>
      pattern.test(leadershipText),
    );
    if ((hasMaleLeadershipRole || hasMaleOnlyLeadershipTitle) && gender !== 'male') {
      violations.push(
        `member:${member.id} role:${primaryRole || 'none'} gender:${member.gender ?? 'null'}`,
      );
    }
  }

  for (const branch of branches) {
    for (const roleField of ['leaderMemberId', 'viceLeaderMemberId']) {
      const memberId = branch[roleField];
      if (memberId == null) {
        continue;
      }
      const member = memberById.get(memberId);
      if (member == null) {
        violations.push(`branch:${branch.id} ${roleField}:${memberId} missing-member`);
        continue;
      }
      const gender = (member.gender ?? '').toLowerCase();
      if (gender !== 'male') {
        violations.push(
          `branch:${branch.id} ${roleField}:${memberId} gender:${member.gender ?? 'null'}`,
        );
      }
    }
  }

  if (violations.length > 0) {
    throw new Error(
      `Male-line leadership constraint violated:\\n${violations.join('\\n')}`,
    );
  }
}

function parseDateOnly(value) {
  if (typeof value !== 'string' || value.trim() === '') {
    return null;
  }
  const date = new Date(`${value.trim()}T00:00:00.000Z`);
  return Number.isNaN(date.getTime()) ? null : date;
}

function fullYearsBetween(earlier, later) {
  let years = later.getUTCFullYear() - earlier.getUTCFullYear();
  const monthDelta = later.getUTCMonth() - earlier.getUTCMonth();
  const dayDelta = later.getUTCDate() - earlier.getUTCDate();
  if (monthDelta < 0 || (monthDelta === 0 && dayDelta < 0)) {
    years -= 1;
  }
  return years;
}

function ageFromBirthDate(birthDateIso, nowDate = new Date()) {
  const birthDate = parseDateOnly(birthDateIso);
  if (birthDate == null) {
    return null;
  }
  return fullYearsBetween(birthDate, nowDate);
}

function assertDemographicQuality({ members, relationships, creatorId }) {
  const memberById = new Map(members.map((member) => [member.id, member]));
  const violations = [];

  const creator = memberById.get(creatorId);
  if (creator == null) {
    violations.push(`creator_missing:${creatorId}`);
  } else {
    const creatorAge = ageFromBirthDate(creator.birthDate);
    const creatorAlive =
      creator.status === 'active' &&
      (creator.deathDate == null || `${creator.deathDate}`.trim() === '');
    if (!creatorAlive) {
      violations.push(`creator_not_alive:${creator.id}`);
    }
    if (creatorAge == null || creatorAge < 25 || creatorAge > 70) {
      violations.push(`creator_age_out_of_range:${creator.id}:${creatorAge ?? 'null'}`);
    }
  }

  const roleTermsByAge = [
    { maxAge: 17, pattern: /(học sinh|trẻ em|sơ sinh)/i },
    { minAge: 18, maxAge: 22, pattern: /sinh viên/i },
  ];
  const forbiddenAdultTerms = /(học sinh|trẻ em|sơ sinh)/i;
  const requiredJobPatterns = [
    /nông/i,
    /công nhân/i,
    /kỹ sư phần mềm/i,
    /kỹ sư xây dựng/i,
    /phụ hồ/i,
    /chủ tịch xã/i,
    /chủ tịch tỉnh/i,
    /quản lý đất đai xã/i,
  ];
  const jobCatalog = members
    .map((member) => `${member.jobTitle ?? ''}`.toLowerCase())
    .join(' | ');

  for (const member of members) {
    const age = ageFromBirthDate(member.birthDate);
    if (age == null) {
      continue;
    }
    const jobTitle = `${member.jobTitle ?? ''}`.trim();
    const isAlive =
      member.status === 'active' &&
      (member.deathDate == null || `${member.deathDate}`.trim() === '');
    if (isAlive && age > 100) {
      violations.push(`alive_over_100:${member.id}:${age}`);
    }

    for (const rule of roleTermsByAge) {
      const inRange =
        (rule.minAge == null || age >= rule.minAge) &&
        (rule.maxAge == null || age <= rule.maxAge);
      if (!inRange) {
        continue;
      }
      if (!rule.pattern.test(jobTitle)) {
        violations.push(`job_age_mismatch:${member.id}:age_${age}:job_${jobTitle}`);
      }
    }

    if (age >= 23 && forbiddenAdultTerms.test(jobTitle)) {
      violations.push(`adult_has_minor_job:${member.id}:age_${age}:job_${jobTitle}`);
    }
  }

  for (const pattern of requiredJobPatterns) {
    if (!pattern.test(jobCatalog)) {
      violations.push(`missing_required_job_pattern:${pattern}`);
    }
  }

  for (const relationship of relationships) {
    if (relationship.type !== 'parent_child') {
      continue;
    }
    const parent = memberById.get(relationship.personA);
    const child = memberById.get(relationship.personB);
    if (parent == null || child == null) {
      continue;
    }
    const parentBirth = parseDateOnly(parent.birthDate);
    const childBirth = parseDateOnly(child.birthDate);
    if (parentBirth == null || childBirth == null) {
      continue;
    }
    const parentAgeAtChildBirth = fullYearsBetween(parentBirth, childBirth);
    if (parentAgeAtChildBirth < 16 || parentAgeAtChildBirth > 75) {
      violations.push(
        `parent_child_age_gap_invalid:${relationship.id}:parent_age_at_birth_${parentAgeAtChildBirth}`,
      );
    }
  }

  if (violations.length > 0) {
    throw new Error(`Demographic quality constraints violated:\\n${violations.join('\\n')}`);
  }
}

assertMaleLineConstraints({ members: normalizedMembers, branches });
assertDemographicQuality({
  members: normalizedMembers,
  relationships,
  creatorId: 'member_demo_parent_001',
});

for (const branch of branches) {
  branch.memberCount = normalizedMembers.filter(
    (member) => member.branchId === branch.id,
  ).length;
}

const clan = {
  id: clanId,
  name: 'Gia phả họ Nguyễn Văn Đà Nẵng',
  slug: 'gia-pha-ho-nguyen-van-da-nang',
  description:
    'Gia phả mẫu nhiều thế hệ với dữ liệu gần thực tế để kiểm thử trên quy mô lớn.',
  countryCode: 'VN',
  founderName: 'Nguyễn Minh',
  ownerUid: clanOwnerUid,
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

const fundTransactions = [
  {
    id: 'txn_demo_001',
    fundId: 'fund_demo_scholarship',
    clanId,
    branchId: null,
    transactionType: 'donation',
    amountMinor: 3000000,
    currency: 'VND',
    memberId: 'member_demo_parent_001',
    externalReference: null,
    occurredAt: ts('2026-01-12T02:00:00.000Z'),
    note: 'Chiến dịch đóng góp Tết',
    receiptUrl: null,
    createdAt: ts('2026-01-12T02:05:00.000Z'),
    createdBy: 'member_demo_parent_001',
    updatedAt: now,
    updatedBy: 'seed-script',
  },
  {
    id: 'txn_demo_002',
    fundId: 'fund_demo_scholarship',
    clanId,
    branchId: null,
    transactionType: 'expense',
    amountMinor: 500000,
    currency: 'VND',
    memberId: 'member_demo_parent_001',
    externalReference: null,
    occurredAt: ts('2026-02-10T07:00:00.000Z'),
    note: 'Đợt chi học bổng lần 1',
    receiptUrl: null,
    createdAt: ts('2026-02-10T07:02:00.000Z'),
    createdBy: 'member_demo_parent_001',
    updatedAt: now,
    updatedBy: 'seed-script',
  },
  {
    id: 'txn_demo_003',
    fundId: 'fund_demo_operations',
    clanId,
    branchId: null,
    transactionType: 'donation',
    amountMinor: 1000000,
    currency: 'VND',
    memberId: 'member_demo_parent_002',
    externalReference: 'OPS-2026-01',
    occurredAt: ts('2026-01-20T03:00:00.000Z'),
    note: 'Đóng góp quỹ vận hành',
    receiptUrl: null,
    createdAt: ts('2026-01-20T03:01:00.000Z'),
    createdBy: 'member_demo_parent_002',
    updatedAt: now,
    updatedBy: 'seed-script',
  },
  {
    id: 'txn_demo_004',
    fundId: 'fund_demo_operations',
    clanId,
    branchId: null,
    transactionType: 'expense',
    amountMinor: 150000,
    currency: 'VND',
    memberId: 'member_demo_parent_002',
    externalReference: null,
    occurredAt: ts('2026-02-01T08:00:00.000Z'),
    note: 'Chi phí hậu cần lễ giỗ',
    receiptUrl: null,
    createdAt: ts('2026-02-01T08:01:00.000Z'),
    createdBy: 'member_demo_parent_002',
    updatedAt: now,
    updatedBy: 'seed-script',
  },
];

const fundBalanceById = new Map();
for (const transaction of fundTransactions) {
  const signedAmount =
    transaction.transactionType === 'expense'
      ? -transaction.amountMinor
      : transaction.amountMinor;
  fundBalanceById.set(
    transaction.fundId,
    (fundBalanceById.get(transaction.fundId) ?? 0) + signedAmount,
  );
}

const funds = [
  {
    id: 'fund_demo_scholarship',
    clanId,
    branchId: null,
    appliedMemberIds: [
      'member_demo_child_001',
      'member_demo_child_002',
      'member_demo_child_003',
      'member_demo_child_004',
    ],
    treasurerMemberIds: ['member_demo_parent_001', 'member_demo_parent_002'],
    name: 'Quỹ Khuyến học',
    description: 'Hỗ trợ hậu duệ với học bổng thường niên.',
    fundType: 'scholarship',
    currency: 'VND',
    balanceMinor: fundBalanceById.get('fund_demo_scholarship') ?? 0,
    status: 'active',
    createdAt: now,
    createdBy: 'seed-script',
    updatedAt: now,
    updatedBy: 'seed-script',
  },
  {
    id: 'fund_demo_operations',
    clanId,
    branchId: null,
    appliedMemberIds: [],
    treasurerMemberIds: ['member_demo_parent_002'],
    name: 'Quỹ Vận hành họ tộc',
    description: 'Chi trả nghi lễ và hoạt động chung của họ tộc.',
    fundType: 'operations',
    currency: 'VND',
    balanceMinor: fundBalanceById.get('fund_demo_operations') ?? 0,
    status: 'active',
    createdAt: now,
    createdBy: 'seed-script',
    updatedAt: now,
    updatedBy: 'seed-script',
  },
];

const events = [
  {
    id: 'event_demo_memorial_001',
    clanId,
    branchId: 'branch_demo_001',
    title: 'Giỗ cụ tổ mùa xuân',
    description: 'Lễ giỗ thường niên tại từ đường chi trưởng.',
    eventType: 'death_anniversary',
    targetMemberId: 'member_demo_elder_001',
    locationName: 'Từ đường chi trưởng',
    locationAddress: 'Quảng Nam, Việt Nam',
    startsAt: ts('2026-04-04T02:00:00.000Z'),
    endsAt: ts('2026-04-04T05:30:00.000Z'),
    timezone: 'Asia/Ho_Chi_Minh',
    isRecurring: true,
    recurrenceRule: 'FREQ=YEARLY',
    reminderOffsetsMinutes: [10080, 1440, 120],
    visibility: 'clan',
    status: 'scheduled',
    createdAt: now,
    createdBy: 'seed-script',
    updatedAt: now,
    updatedBy: 'seed-script',
  },
  {
    id: 'event_demo_gathering_001',
    clanId,
    branchId: 'branch_demo_002',
    title: 'Họp mặt đầu hè',
    description: 'Họp mặt toàn chi để cập nhật kế hoạch học bổng và quỹ.',
    eventType: 'clan_gathering',
    targetMemberId: null,
    locationName: 'Nhà văn hóa chi phụ',
    locationAddress: 'Huế, Việt Nam',
    startsAt: ts('2026-05-12T01:00:00.000Z'),
    endsAt: ts('2026-05-12T04:00:00.000Z'),
    timezone: 'Asia/Ho_Chi_Minh',
    isRecurring: false,
    recurrenceRule: null,
    reminderOffsetsMinutes: [1440, 120],
    visibility: 'clan',
    status: 'scheduled',
    createdAt: now,
    createdBy: 'seed-script',
    updatedAt: now,
    updatedBy: 'seed-script',
  },
  {
    id: 'event_demo_lunar_birthday_001',
    clanId,
    branchId: 'branch_demo_001',
    title: 'Sinh nhật bà nội (âm lịch)',
    description: 'Sự kiện lặp lại theo âm lịch để kiểm thử lịch âm dương.',
    eventType: 'birthday',
    targetMemberId: 'member_demo_elder_spouse_001',
    locationName: 'Nhà trưởng chi',
    locationAddress: 'Đà Nẵng, Việt Nam',
    startsAt: ts('2026-07-19T11:00:00.000Z'),
    endsAt: ts('2026-07-19T13:00:00.000Z'),
    timezone: 'Asia/Ho_Chi_Minh',
    isRecurring: true,
    recurrenceRule: 'FREQ=YEARLY',
    reminderOffsetsMinutes: [10080, 1440],
    visibility: 'clan',
    status: 'scheduled',
    dateType: 'lunar',
    lunarMonth: 6,
    lunarDay: 5,
    isLeapMonth: false,
    createdAt: now,
    createdBy: 'seed-script',
    updatedAt: now,
    updatedBy: 'seed-script',
  },
];

const scholarshipPrograms = [
  {
    id: 'scholarship_program_demo_2026',
    clanId,
    title: 'Học bổng hậu duệ 2026',
    description: 'Chương trình học bổng thường niên cho hậu duệ đạt thành tích.',
    year: 2026,
    status: 'open',
    submissionOpenAt: ts('2026-01-01T00:00:00.000Z'),
    submissionCloseAt: ts('2026-08-31T23:59:59.000Z'),
    reviewCloseAt: ts('2026-09-30T23:59:59.000Z'),
    createdAt: now,
    createdBy: 'seed-script',
    updatedAt: now,
    updatedBy: 'seed-script',
  },
];

const awardLevels = [
  {
    id: 'award_level_demo_gold',
    programId: 'scholarship_program_demo_2026',
    clanId,
    name: 'Giải Vàng',
    description: 'Dành cho thành tích xuất sắc cấp tỉnh trở lên.',
    sortOrder: 10,
    rewardType: 'cash',
    rewardAmountMinor: 5000000,
    criteriaText:
      'Điểm trung bình từ 3.8/4.0 trở lên hoặc đạt giải học sinh giỏi cấp tỉnh/quốc gia.',
    status: 'active',
    createdAt: now,
    updatedAt: now,
  },
  {
    id: 'award_level_demo_silver',
    programId: 'scholarship_program_demo_2026',
    clanId,
    name: 'Giải Bạc',
    description: 'Dành cho thành tích học tập tốt cấp trường.',
    sortOrder: 20,
    rewardType: 'cash',
    rewardAmountMinor: 3000000,
    criteriaText: 'Điểm trung bình từ 3.4/4.0 trở lên và hạnh kiểm tốt.',
    status: 'active',
    createdAt: now,
    updatedAt: now,
  },
];

const achievementSubmissions = [
  {
    id: 'submission_demo_001',
    programId: 'scholarship_program_demo_2026',
    awardLevelId: 'award_level_demo_gold',
    clanId,
    memberId: 'member_demo_parent_001',
    studentNameSnapshot: 'Bé Minh',
    title: 'Thành tích học kỳ I',
    description: 'Hồ sơ đề nghị học bổng cho học kỳ I năm học 2026.',
    evidenceUrls: ['https://du-lieu.giapha.vn/minh-hoc-ky-1.pdf'],
    status: 'pending',
    reviewNote: null,
    reviewedBy: null,
    reviewedAt: null,
    approvalVotes: [],
    finalDecisionReason: null,
    createdAt: ts('2026-02-12T03:00:00.000Z'),
    createdBy: 'member_demo_parent_001',
    updatedAt: ts('2026-02-12T03:00:00.000Z'),
    updatedBy: 'member_demo_parent_001',
  },
  {
    id: 'submission_demo_002',
    programId: 'scholarship_program_demo_2026',
    awardLevelId: 'award_level_demo_silver',
    clanId,
    memberId: 'member_demo_parent_002',
    studentNameSnapshot: 'Bé Lan',
    title: 'Thành tích cuối năm',
    description: 'Đề nghị học bổng cho kết quả cuối năm 2026.',
    evidenceUrls: ['https://du-lieu.giapha.vn/lan-cuoi-nam.pdf'],
    status: 'approved',
    reviewNote: 'Hồ sơ đầy đủ và đạt tiêu chí.',
    reviewedBy: 'member_demo_parent_001',
    reviewedAt: ts('2026-03-05T10:15:00.000Z'),
    approvalVotes: [
      {
        memberId: 'member_demo_parent_001',
        decision: 'approve',
        note: 'Đồng ý',
        createdAt: ts('2026-03-05T10:00:00.000Z'),
      },
    ],
    finalDecisionReason: 'Đạt đủ phiếu chấp thuận.',
    createdAt: ts('2026-02-28T08:00:00.000Z'),
    createdBy: 'member_demo_parent_002',
    updatedAt: ts('2026-03-05T10:15:00.000Z'),
    updatedBy: 'member_demo_parent_001',
  },
];

const scholarshipApprovalLogs = [
  {
    id: 'sch_log_demo_001',
    clanId,
    submissionId: 'submission_demo_002',
    action: 'submission_reviewed',
    decision: 'approve',
    actorMemberId: 'member_demo_parent_001',
    actorRole: 'CLAN_ADMIN',
    note: 'Đủ điều kiện cấp học bổng.',
    createdAt: ts('2026-03-05T10:15:00.000Z'),
  },
  {
    id: 'sch_log_demo_002',
    clanId,
    submissionId: 'submission_demo_001',
    action: 'submission_created',
    decision: null,
    actorMemberId: 'member_demo_parent_001',
    actorRole: 'CLAN_ADMIN',
    note: 'Hồ sơ mới được nộp.',
    createdAt: ts('2026-02-12T03:00:00.000Z'),
  },
];

const billingSettingsDocs = [
  {
    id: ownerScopedBillingDocId,
    clanId: ownerBillingScopeId,
    ownerUid: clanOwnerUid,
    paymentMode: 'manual',
    autoRenew: false,
    reminderDaysBefore: [30, 14, 7, 3, 1],
    updatedAt: now,
    updatedBy: 'seed-script',
    createdAt: now,
    createdBy: 'seed-script',
  },
];

const subscriptions = [
  {
    id: ownerScopedBillingDocId,
    clanId: ownerBillingScopeId,
    ownerUid: clanOwnerUid,
    planCode: 'BASE',
    status: 'active',
    memberCount: normalizedMembers.length,
    amountVndYear: 49000,
    vatIncluded: true,
    paymentMode: 'manual',
    autoRenew: false,
    showAds: true,
    adFree: false,
    startsAt: ts('2026-01-01T00:00:00.000Z'),
    expiresAt: ts('2027-01-01T00:00:00.000Z'),
    nextPaymentDueAt: ts('2027-01-01T00:00:00.000Z'),
    graceEndsAt: null,
    lastPaymentMethod: 'vnpay',
    lastTransactionId: 'paytxn_demo_001',
    lastInvoiceId: 'invoice_demo_001',
    updatedAt: now,
    updatedBy: 'seed-script',
    createdAt: now,
    createdBy: 'seed-script',
  },
];

if (
  normalizedMembers.length > 50 &&
  !subscriptions.some((subscription) => subscription.planCode === 'BASE')
) {
  throw new Error(
    `Expected BASE plan for dataset larger than 50 members, got "${subscriptions.map((entry) => entry.planCode).join(',')}".`,
  );
}

const paymentTransactions = [
  {
    id: 'paytxn_demo_001',
    clanId,
    subscriptionOwnerUid: clanOwnerUid,
    subscriptionId: ownerScopedBillingDocId,
    invoiceId: 'invoice_demo_001',
    paymentMethod: 'vnpay',
    paymentStatus: 'succeeded',
    planCode: 'BASE',
    memberCount: normalizedMembers.length,
    amountVnd: 49000,
    vatIncluded: true,
    currency: 'VND',
    gatewayReference: 'VNPAY-DEMO-001',
    gatewayPayloadHash: null,
    provider: 'vnpay',
    createdAt: ts('2026-01-01T00:01:00.000Z'),
    paidAt: ts('2026-01-01T00:03:00.000Z'),
    failedAt: null,
    updatedAt: now,
    updatedBy: 'seed-script',
    createdBy: 'seed-script',
  },
];

const subscriptionInvoices = [
  {
    id: 'invoice_demo_001',
    clanId,
    subscriptionOwnerUid: clanOwnerUid,
    subscriptionId: ownerScopedBillingDocId,
    transactionId: 'paytxn_demo_001',
    planCode: 'BASE',
    amountVnd: 49000,
    vatIncluded: true,
    currency: 'VND',
    status: 'paid',
    periodStart: ts('2026-01-01T00:00:00.000Z'),
    periodEnd: ts('2027-01-01T00:00:00.000Z'),
    issuedAt: ts('2026-01-01T00:01:00.000Z'),
    paidAt: ts('2026-01-01T00:03:00.000Z'),
    createdAt: ts('2026-01-01T00:01:00.000Z'),
    updatedAt: now,
    updatedBy: 'seed-script',
    createdBy: 'seed-script',
  },
];

const billingAuditLogs = [
  {
    id: 'billing_audit_demo_bootstrap',
    clanId,
    actorUid: 'seed-script',
    action: 'subscription_bootstrapped',
    entityType: 'subscription',
    entityId: ownerScopedBillingDocId,
    before: null,
    after: {
      planCode: 'BASE',
      status: 'active',
      memberCount: normalizedMembers.length,
    },
    createdAt: ts('2026-01-01T00:00:00.000Z'),
  },
  {
    id: 'billing_audit_demo_payment',
    clanId,
    actorUid: 'seed-script',
    action: 'payment_succeeded',
    entityType: 'paymentTransaction',
    entityId: 'paytxn_demo_001',
    before: { status: 'pending' },
    after: { status: 'succeeded', provider: 'vnpay' },
    createdAt: ts('2026-01-01T00:03:00.000Z'),
  },
];

const notifications = [
  {
    id: 'notif_demo_event_001',
    clanId,
    memberId: 'member_demo_parent_001',
    type: 'event_reminder',
    title: 'Sự kiện sắp diễn ra',
    body: 'Lễ giỗ cụ tổ sẽ bắt đầu vào ngày mai.',
    isRead: false,
    createdAt: ts('2026-04-03T02:00:00.000Z'),
    data: {
      target: 'event',
      eventId: 'event_demo_memorial_001',
      id: 'event_demo_memorial_001',
    },
  },
  {
    id: 'notif_demo_scholarship_001',
    clanId,
    memberId: 'member_demo_parent_002',
    type: 'scholarship_review',
    title: 'Hồ sơ học bổng đã được duyệt',
    body: 'Hồ sơ thành tích cuối năm đã được phê duyệt.',
    isRead: false,
    createdAt: ts('2026-03-05T10:20:00.000Z'),
    data: {
      target: 'scholarship',
      submissionId: 'submission_demo_002',
      id: 'submission_demo_002',
    },
  },
  {
    id: 'notif_demo_billing_001',
    clanId,
    memberId: 'member_demo_parent_001',
    type: 'billing_payment_succeeded',
    title: 'Thanh toán gói dịch vụ thành công',
    body: 'Gói BASE đã được gia hạn đến 2027-01-01.',
    isRead: true,
    createdAt: ts('2026-01-01T00:05:00.000Z'),
    data: {
      target: 'generic',
      transactionId: 'paytxn_demo_001',
      result: 'success',
    },
  },
];

const lunarHolidays = [
  {
    id: 'lunar_holiday_new_year',
    name: 'Tết Nguyên Đán',
    lunarMonth: 1,
    lunarDay: 1,
    regions: ['CN', 'VN', 'KR'],
    colorHex: '#EF5350',
    createdAt: now,
    updatedAt: now,
  },
  {
    id: 'lunar_holiday_lantern',
    name: 'Rằm tháng Giêng',
    lunarMonth: 1,
    lunarDay: 15,
    regions: ['CN', 'VN', 'KR'],
    colorHex: '#FFA726',
    createdAt: now,
    updatedAt: now,
  },
  {
    id: 'lunar_holiday_dragon_boat',
    name: 'Tết Đoan Ngọ',
    lunarMonth: 5,
    lunarDay: 5,
    regions: ['CN', 'VN', 'KR'],
    colorHex: '#43A047',
    createdAt: now,
    updatedAt: now,
  },
  {
    id: 'lunar_holiday_mid_autumn',
    name: 'Tết Trung Thu',
    lunarMonth: 8,
    lunarDay: 15,
    regions: ['CN', 'VN', 'KR'],
    colorHex: '#5C6BC0',
    createdAt: now,
    updatedAt: now,
  },
];

const discoveryEntries = [
  {
    id: clanId,
    clanId,
    genealogyName: clan.name,
    genealogyNameNormalized: normalizeName(clan.name),
    leaderName: 'Nguyễn Minh',
    leaderNameNormalized: normalizeName('Nguyễn Minh'),
    provinceCity: 'Đà Nẵng',
    provinceCityNormalized: normalizeName('Đà Nẵng'),
    summary: clan.description,
    memberCount: normalizedMembers.length,
    branchCount: branches.length,
    isPublic: true,
    createdAt: now,
    updatedAt: now,
  },
];

const governanceRoleAssignments = [
  {
    id: 'governance_assignment_demo_001',
    clanId,
    memberId: 'member_demo_parent_002',
    previousRole: 'MEMBER',
    nextRole: 'BRANCH_ADMIN',
    actorMemberId: 'member_demo_parent_001',
    actorRole: 'CLAN_ADMIN',
    reason: 'Khởi tạo phân quyền mẫu để kiểm thử quản trị.',
    createdAt: now,
  },
];

const subscriptionPackages = [
  {
    id: 'FREE',
    planCode: 'FREE',
    displayName: 'Miễn phí',
    minMembers: 0,
    maxMembers: 10,
    priceVndYear: 0,
    currency: 'VND',
    billingCycle: 'yearly',
    vatIncluded: true,
    showAds: true,
    adFree: false,
    isActive: true,
    sortOrder: 1,
    source: 'seed-demo',
    createdAt: now,
    updatedAt: now,
  },
  {
    id: 'BASE',
    planCode: 'BASE',
    displayName: 'Cơ bản',
    minMembers: 11,
    maxMembers: 200,
    priceVndYear: 49000,
    currency: 'VND',
    billingCycle: 'yearly',
    vatIncluded: true,
    showAds: true,
    adFree: false,
    isActive: true,
    sortOrder: 2,
    source: 'seed-demo',
    createdAt: now,
    updatedAt: now,
  },
  {
    id: 'PLUS',
    planCode: 'PLUS',
    displayName: 'Nâng cao',
    minMembers: 201,
    maxMembers: 700,
    priceVndYear: 89000,
    currency: 'VND',
    billingCycle: 'yearly',
    vatIncluded: true,
    showAds: false,
    adFree: true,
    isActive: true,
    sortOrder: 3,
    source: 'seed-demo',
    createdAt: now,
    updatedAt: now,
  },
  {
    id: 'PRO',
    planCode: 'PRO',
    displayName: 'Chuyên nghiệp',
    minMembers: 701,
    maxMembers: null,
    priceVndYear: 119000,
    currency: 'VND',
    billingCycle: 'yearly',
    vatIncluded: true,
    showAds: false,
    adFree: true,
    isActive: true,
    sortOrder: 4,
    source: 'seed-demo',
    createdAt: now,
    updatedAt: now,
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

  for (const fund of funds) {
    const ref = db.collection('funds').doc(fund.id);
    batch.set(ref, fund, { merge: true });
  }

  for (const transaction of fundTransactions) {
    const ref = db.collection('transactions').doc(transaction.id);
    batch.set(ref, transaction, { merge: true });
  }

  for (const event of events) {
    const ref = db.collection('events').doc(event.id);
    batch.set(ref, event, { merge: true });
  }

  for (const program of scholarshipPrograms) {
    const ref = db.collection('scholarshipPrograms').doc(program.id);
    batch.set(ref, program, { merge: true });
  }

  for (const awardLevel of awardLevels) {
    const ref = db.collection('awardLevels').doc(awardLevel.id);
    batch.set(ref, awardLevel, { merge: true });
  }

  for (const submission of achievementSubmissions) {
    const ref = db.collection('achievementSubmissions').doc(submission.id);
    batch.set(ref, submission, { merge: true });
  }

  for (const entry of scholarshipApprovalLogs) {
    const ref = db.collection('scholarshipApprovalLogs').doc(entry.id);
    batch.set(ref, entry, { merge: true });
  }

  for (const settings of billingSettingsDocs) {
    const ref = db.collection('billingSettings').doc(settings.id);
    batch.set(ref, settings, { merge: true });
  }

  for (const subscription of subscriptions) {
    const ref = db.collection('subscriptions').doc(subscription.id);
    batch.set(ref, subscription, { merge: true });
  }

  for (const transaction of paymentTransactions) {
    const ref = db.collection('paymentTransactions').doc(transaction.id);
    batch.set(ref, transaction, { merge: true });
  }

  for (const invoice of subscriptionInvoices) {
    const ref = db.collection('subscriptionInvoices').doc(invoice.id);
    batch.set(ref, invoice, { merge: true });
  }

  for (const log of billingAuditLogs) {
    const ref = db.collection('billingAuditLogs').doc(log.id);
    batch.set(ref, log, { merge: true });
  }

  for (const notification of notifications) {
    const ref = db.collection('notifications').doc(notification.id);
    batch.set(ref, notification, { merge: true });
  }

  for (const holiday of lunarHolidays) {
    const ref = db.collection('lunar_holidays').doc(holiday.id);
    batch.set(ref, holiday, { merge: true });
  }

  for (const entry of discoveryEntries) {
    const ref = db.collection('genealogyDiscoveryIndex').doc(entry.id);
    batch.set(ref, entry, { merge: true });
  }

  for (const assignment of governanceRoleAssignments) {
    const ref = db.collection('governanceRoleAssignments').doc(assignment.id);
    batch.set(ref, assignment, { merge: true });
  }

  for (const plan of subscriptionPackages) {
    const ref = db.collection('subscriptionPackages').doc(plan.id);
    batch.set(ref, plan, { merge: true });
  }

  await batch.commit();

  console.log('Đã seed dữ liệu gia phả mẫu mở rộng thành công.');
  console.log(`Project: ${projectId}`);
  console.log(`Clan: ${clan.id}`);
  console.log(`Members: ${normalizedMembers.length}`);
  console.log(`Branches: ${branches.length}`);
  console.log(`Relationships: ${relationships.length}`);
  console.log(`Invites: ${invites.length}`);
  console.log(`Funds: ${funds.length}`);
  console.log(`Fund transactions: ${fundTransactions.length}`);
  console.log(`Events: ${events.length}`);
  console.log(`Scholarship programs: ${scholarshipPrograms.length}`);
  console.log(`Award levels: ${awardLevels.length}`);
  console.log(`Achievement submissions: ${achievementSubmissions.length}`);
  console.log(`Scholarship approval logs: ${scholarshipApprovalLogs.length}`);
  console.log(`Billing settings docs: ${billingSettingsDocs.length}`);
  console.log(`Subscriptions: ${subscriptions.length}`);
  console.log(`Payment transactions: ${paymentTransactions.length}`);
  console.log(`Subscription invoices: ${subscriptionInvoices.length}`);
  console.log(`Billing audit logs: ${billingAuditLogs.length}`);
  console.log(`Notifications: ${notifications.length}`);
  console.log(`Lunar holidays: ${lunarHolidays.length}`);
  console.log(`Discovery entries: ${discoveryEntries.length}`);
  console.log(`Governance role assignments: ${governanceRoleAssignments.length}`);
  console.log(`Subscription packages: ${subscriptionPackages.length}`);
}

seed().catch((error) => {
  console.error('Seed dữ liệu mẫu thất bại.');
  console.error(error);
  process.exit(1);
});
