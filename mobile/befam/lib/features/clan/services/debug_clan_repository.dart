import 'dart:async';

import 'package:collection/collection.dart';

import '../../auth/models/auth_session.dart';
import '../models/branch_draft.dart';
import '../models/branch_profile.dart';
import '../models/clan_draft.dart';
import '../models/clan_member_summary.dart';
import '../models/clan_profile.dart';
import '../models/clan_workspace_snapshot.dart';
import 'clan_repository.dart';

class DebugClanRepository implements ClanRepository {
  DebugClanRepository({
    required Map<String, ClanProfile> clans,
    required Map<String, BranchProfile> branches,
    required Map<String, ClanMemberSummary> members,
  }) : _clans = clans,
       _branches = branches,
       _members = members;

  factory DebugClanRepository.seeded() {
    return DebugClanRepository(
      clans: {
        'clan_demo_001': const ClanProfile(
          id: 'clan_demo_001',
          name: 'Gia phả họ Nguyễn Văn Đà Nẵng',
          slug: 'gia-pha-ho-nguyen-van-da-nang',
          description:
              'Gia phả thử nghiệm nhiều thế hệ với dữ liệu gần thực tế để kiểm thử nghiệp vụ.',
          countryCode: 'VN',
          founderName: 'Nguyễn Minh',
          logoUrl: '',
          status: 'active',
          memberCount: 4,
          branchCount: 2,
        ),
      },
      branches: {
        'branch_demo_001': const BranchProfile(
          id: 'branch_demo_001',
          clanId: 'clan_demo_001',
          name: 'Chi Trưởng',
          code: 'CT01',
          leaderMemberId: 'member_demo_parent_001',
          viceLeaderMemberId: 'member_demo_parent_002',
          generationLevelHint: 3,
          status: 'active',
          memberCount: 2,
        ),
        'branch_demo_002': const BranchProfile(
          id: 'branch_demo_002',
          clanId: 'clan_demo_001',
          name: 'Chi Phụ',
          code: 'CP02',
          leaderMemberId: 'member_demo_parent_002',
          viceLeaderMemberId: 'member_demo_elder_001',
          generationLevelHint: 4,
          status: 'active',
          memberCount: 2,
        ),
      },
      members: {
        'member_demo_parent_001': const ClanMemberSummary(
          id: 'member_demo_parent_001',
          fullName: 'Nguyễn Minh',
          branchId: 'branch_demo_001',
          primaryRole: 'CLAN_ADMIN',
          phoneE164: '+84901234567',
        ),
        'member_demo_parent_002': const ClanMemberSummary(
          id: 'member_demo_parent_002',
          fullName: 'Trần Văn Long',
          branchId: 'branch_demo_002',
          primaryRole: 'BRANCH_ADMIN',
          phoneE164: '+84908886655',
        ),
        'member_demo_child_001': const ClanMemberSummary(
          id: 'member_demo_child_001',
          fullName: 'Bé Minh',
          branchId: 'branch_demo_001',
          primaryRole: 'MEMBER',
          phoneE164: null,
        ),
        'member_demo_child_002': const ClanMemberSummary(
          id: 'member_demo_child_002',
          fullName: 'Bé Lan',
          branchId: 'branch_demo_002',
          primaryRole: 'MEMBER',
          phoneE164: null,
        ),
        'member_demo_elder_001': const ClanMemberSummary(
          id: 'member_demo_elder_001',
          fullName: 'Ông Bảo',
          branchId: 'branch_demo_001',
          primaryRole: 'MEMBER',
          phoneE164: '+84907770000',
        ),
      },
    );
  }

  factory DebugClanRepository.empty() {
    return DebugClanRepository(clans: {}, branches: {}, members: {});
  }

  final Map<String, ClanProfile> _clans;
  final Map<String, BranchProfile> _branches;
  final Map<String, ClanMemberSummary> _members;

  int _branchSequence = 900;

  @override
  bool get isSandbox => true;

  @override
  Future<ClanWorkspaceSnapshot> loadWorkspace({
    required AuthSession session,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    final clanId = session.clanId;
    if (clanId == null || clanId.isEmpty) {
      return const ClanWorkspaceSnapshot(clan: null, branches: [], members: []);
    }

    final clan = _clans[clanId];
    final branches = _branches.values
        .where((branch) => branch.clanId == clanId)
        .sortedBy((branch) => branch.name.toLowerCase());
    final members = _members.values
        .where((member) {
          return clanId == 'clan_demo_001'
              ? true
              : member.id.startsWith(clanId);
        })
        .sortedBy((member) => member.fullName.toLowerCase());

    return ClanWorkspaceSnapshot(
      clan: clan,
      branches: List.unmodifiable(branches),
      members: List.unmodifiable(members),
    );
  }

  @override
  Future<void> saveClan({
    required AuthSession session,
    required ClanDraft draft,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    final clanId = session.clanId;
    if (clanId == null || clanId.isEmpty) {
      throw StateError('Cần có ngữ cảnh gia phả trước khi lưu thông tin họ tộc.');
    }

    final branchCount = _branches.values
        .where((branch) => branch.clanId == clanId)
        .length;
    final memberCount = _members.values.length;
    final existing = _clans[clanId];

    _clans[clanId] = ClanProfile(
      id: clanId,
      name: draft.name,
      slug: draft.slug,
      description: draft.description,
      countryCode: draft.countryCode,
      founderName: draft.founderName,
      logoUrl: draft.logoUrl,
      status: draft.status,
      memberCount: existing?.memberCount ?? memberCount,
      branchCount: existing?.branchCount ?? branchCount,
    );
  }

  @override
  Future<BranchProfile> saveBranch({
    required AuthSession session,
    String? branchId,
    required BranchDraft draft,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    final clanId = session.clanId;
    if (clanId == null || clanId.isEmpty) {
      throw StateError('Cần có ngữ cảnh gia phả trước khi lưu thông tin chi.');
    }

    final resolvedBranchId = branchId ?? 'branch_demo_${_branchSequence++}';
    final existing = _branches[resolvedBranchId];
    final memberCount = _members.values
        .where((member) => member.branchId == resolvedBranchId)
        .length;

    final branch = BranchProfile(
      id: resolvedBranchId,
      clanId: clanId,
      name: draft.name,
      code: draft.code,
      leaderMemberId: draft.leaderMemberId,
      viceLeaderMemberId: draft.viceLeaderMemberId,
      generationLevelHint: draft.generationLevelHint,
      status: draft.status,
      memberCount: existing?.memberCount ?? memberCount,
    );

    _branches[resolvedBranchId] = branch;
    final clan = _clans[clanId];
    if (clan != null) {
      final branchCount = _branches.values
          .where((candidate) => candidate.clanId == clanId)
          .length;
      _clans[clanId] = clan.copyWith(branchCount: branchCount);
    }

    return branch;
  }
}
