import '../../features/clan/models/branch_profile.dart';
import '../../features/member/models/member_profile.dart';
import '../../features/member/models/member_social_links.dart';
import '../../features/relationship/models/relationship_record.dart';

class DebugGenealogyStore {
  DebugGenealogyStore({
    required this.members,
    required this.branches,
    required this.relationships,
    this.memberSequence = 1000,
  });

  factory DebugGenealogyStore.seeded() {
    final store = DebugGenealogyStore(
      members: {
        'member_demo_parent_001': const MemberProfile(
          id: 'member_demo_parent_001',
          clanId: 'clan_demo_001',
          branchId: 'branch_demo_001',
          fullName: 'Nguyễn Minh',
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
          bio: 'Điều phối khởi tạo không gian họ tộc mẫu cho BeFam.',
          socialLinks: MemberSocialLinks(
            facebook: 'https://facebook.com/minh',
            zalo: 'https://zalo.me/minh',
            linkedin: 'https://linkedin.com/in/minh',
          ),
          parentIds: [],
          childrenIds: [],
          spouseIds: [],
          generation: 4,
          primaryRole: 'CLAN_ADMIN',
          status: 'active',
          isMinor: false,
          authUid: 'debug:+84901234567',
        ),
        'member_demo_parent_002': const MemberProfile(
          id: 'member_demo_parent_002',
          clanId: 'clan_demo_001',
          branchId: 'branch_demo_002',
          fullName: 'Trần Lan',
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
          bio: 'Điều phối hoạt động thành viên theo chi.',
          socialLinks: MemberSocialLinks(
            facebook: 'https://facebook.com/lan',
            zalo: 'https://zalo.me/lan',
          ),
          parentIds: [],
          childrenIds: [],
          spouseIds: [],
          generation: 4,
          primaryRole: 'BRANCH_ADMIN',
          status: 'active',
          isMinor: false,
          authUid: 'debug:+84908886655',
        ),
        'member_demo_child_001': const MemberProfile(
          id: 'member_demo_child_001',
          clanId: 'clan_demo_001',
          branchId: 'branch_demo_001',
          fullName: 'Bé Minh',
          normalizedFullName: 'be minh',
          nickName: 'Minh nhỏ',
          gender: 'male',
          birthDate: '2017-04-12',
          deathDate: null,
          phoneE164: null,
          email: null,
          addressText: 'Da Nang, Viet Nam',
          jobTitle: 'Học sinh',
          avatarUrl: null,
          bio: 'Thành viên trẻ em dùng cho luồng OTP phụ huynh.',
          socialLinks: MemberSocialLinks(),
          parentIds: [],
          childrenIds: [],
          spouseIds: [],
          generation: 6,
          primaryRole: 'MEMBER',
          status: 'active',
          isMinor: true,
          authUid: null,
        ),
        'member_demo_child_002': const MemberProfile(
          id: 'member_demo_child_002',
          clanId: 'clan_demo_001',
          branchId: 'branch_demo_002',
          fullName: 'Bé Lan',
          normalizedFullName: 'be lan',
          nickName: 'Lan nhỏ',
          gender: 'female',
          birthDate: '2016-09-09',
          deathDate: null,
          phoneE164: null,
          email: null,
          addressText: 'Hue, Viet Nam',
          jobTitle: 'Học sinh',
          avatarUrl: null,
          bio: 'Thành viên trẻ em mẫu cho kiểm thử quyền đọc.',
          socialLinks: MemberSocialLinks(),
          parentIds: [],
          childrenIds: [],
          spouseIds: [],
          generation: 6,
          primaryRole: 'MEMBER',
          status: 'active',
          isMinor: true,
          authUid: null,
        ),
        'member_demo_elder_001': const MemberProfile(
          id: 'member_demo_elder_001',
          clanId: 'clan_demo_001',
          branchId: 'branch_demo_001',
          fullName: 'Ông Bảo',
          normalizedFullName: 'ong bao',
          nickName: '',
          gender: 'male',
          birthDate: '1960-11-01',
          deathDate: null,
          phoneE164: '+84907770000',
          email: null,
          addressText: 'Quang Nam, Viet Nam',
          jobTitle: 'Cố vấn họ tộc',
          avatarUrl: null,
          bio: 'Thành viên lớn tuổi hỗ trợ kiểm thử danh sách.',
          socialLinks: MemberSocialLinks(),
          parentIds: [],
          childrenIds: [],
          spouseIds: [],
          generation: 3,
          primaryRole: 'MEMBER',
          status: 'active',
          isMinor: false,
          authUid: null,
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
          memberCount: 3,
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
      relationships: {
        'rel_parent_child_member_demo_parent_001_member_demo_child_001':
            const RelationshipRecord(
              id: 'rel_parent_child_member_demo_parent_001_member_demo_child_001',
              clanId: 'clan_demo_001',
              personAId: 'member_demo_parent_001',
              personBId: 'member_demo_child_001',
              type: RelationshipType.parentChild,
              direction: RelationshipDirection.aToB,
              status: 'active',
              source: 'manual',
              createdBy: 'debug:+84901234567',
            ),
        'rel_parent_child_member_demo_parent_002_member_demo_child_002':
            const RelationshipRecord(
              id: 'rel_parent_child_member_demo_parent_002_member_demo_child_002',
              clanId: 'clan_demo_001',
              personAId: 'member_demo_parent_002',
              personBId: 'member_demo_child_002',
              type: RelationshipType.parentChild,
              direction: RelationshipDirection.aToB,
              status: 'active',
              source: 'manual',
              createdBy: 'debug:+84908886655',
            ),
      },
    );
    store.reconcileRelationshipFields('clan_demo_001');
    store.recountBranchMembers('clan_demo_001');
    return store;
  }

  static final DebugGenealogyStore _sharedSeeded = DebugGenealogyStore.seeded();

  static DebugGenealogyStore sharedSeeded() => _sharedSeeded;

  final Map<String, MemberProfile> members;
  final Map<String, BranchProfile> branches;
  final Map<String, RelationshipRecord> relationships;
  int memberSequence;

  void recountBranchMembers(String clanId) {
    for (final entry in branches.entries) {
      if (entry.value.clanId != clanId) {
        continue;
      }

      final count = members.values
          .where(
            (member) => member.clanId == clanId && member.branchId == entry.key,
          )
          .length;
      branches[entry.key] = entry.value.copyWith(memberCount: count);
    }
  }

  void reconcileRelationshipFields(String clanId) {
    final clanMemberIds = members.values
        .where((member) => member.clanId == clanId)
        .map((member) => member.id)
        .toSet();

    for (final memberId in clanMemberIds) {
      final existing = members[memberId];
      if (existing == null) {
        continue;
      }
      members[memberId] = existing.copyWith(
        parentIds: const [],
        childrenIds: const [],
        spouseIds: const [],
      );
    }

    final parentIdsByChild = <String, Set<String>>{};
    final childIdsByParent = <String, Set<String>>{};
    final spouseIdsByMember = <String, Set<String>>{};

    for (final relationship in relationships.values.where(
      (relationship) => relationship.clanId == clanId && relationship.isActive,
    )) {
      switch (relationship.type) {
        case RelationshipType.parentChild:
          childIdsByParent
              .putIfAbsent(relationship.personAId, () => <String>{})
              .add(relationship.personBId);
          parentIdsByChild
              .putIfAbsent(relationship.personBId, () => <String>{})
              .add(relationship.personAId);
        case RelationshipType.spouse:
          spouseIdsByMember
              .putIfAbsent(relationship.personAId, () => <String>{})
              .add(relationship.personBId);
          spouseIdsByMember
              .putIfAbsent(relationship.personBId, () => <String>{})
              .add(relationship.personAId);
      }
    }

    for (final memberId in clanMemberIds) {
      final existing = members[memberId];
      if (existing == null) {
        continue;
      }

      final parentIds = List<String>.from(
        parentIdsByChild[memberId] ?? const <String>{},
      );
      final childIds = List<String>.from(
        childIdsByParent[memberId] ?? const <String>{},
      );
      final spouseIds = List<String>.from(
        spouseIdsByMember[memberId] ?? const <String>{},
      );

      parentIds.sort();
      childIds.sort();
      spouseIds.sort();

      members[memberId] = existing.copyWith(
        parentIds: parentIds,
        childrenIds: childIds,
        spouseIds: spouseIds,
      );
    }
  }
}
