import 'app_environment.dart';
import '../../features/clan/models/branch_profile.dart';
import '../../features/events/models/event_record.dart';
import '../../features/events/models/event_type.dart';
import '../../features/funds/models/fund_profile.dart';
import '../../features/funds/models/fund_transaction.dart';
import '../../features/member/models/member_profile.dart';
import '../../features/member/models/member_social_links.dart';
import '../../features/relationship/models/relationship_record.dart';

class DebugGenealogyStore {
  DebugGenealogyStore({
    required this.members,
    required this.branches,
    required this.funds,
    required this.transactions,
    required this.relationships,
    required this.events,
    this.memberSequence = 1000,
    this.eventSequence = 100,
    this.fundSequence = 1000,
    this.transactionSequence = 1000,
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
          fullName: 'Trần Văn Long',
          normalizedFullName: 'tran van long',
          nickName: 'Long',
          gender: 'male',
          birthDate: '1990-07-21',
          deathDate: null,
          phoneE164: '+84908886655',
          email: 'long@befam.vn',
          addressText: 'Hue, Viet Nam',
          jobTitle: 'Branch Patriarch',
          avatarUrl: null,
          bio: 'Trưởng chi phụ, điều phối hoạt động thành viên theo nam hệ.',
          socialLinks: MemberSocialLinks(
            facebook: 'https://facebook.com/long',
            zalo: 'https://zalo.me/long',
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
      funds: {
        'fund_demo_scholarship': const FundProfile(
          id: 'fund_demo_scholarship',
          clanId: 'clan_demo_001',
          branchId: null,
          name: 'Scholarship Fund',
          description: 'Supports descendants with annual scholarships.',
          fundType: 'scholarship',
          currency: 'VND',
          balanceMinor: 2500000,
          status: 'active',
        ),
        'fund_demo_operations': const FundProfile(
          id: 'fund_demo_operations',
          clanId: 'clan_demo_001',
          branchId: null,
          name: 'Clan Operations Fund',
          description: 'Covers ceremonies and shared operations.',
          fundType: 'operations',
          currency: 'VND',
          balanceMinor: 850000,
          status: 'active',
        ),
      },
      transactions: {
        'txn_demo_001': FundTransaction(
          id: 'txn_demo_001',
          fundId: 'fund_demo_scholarship',
          clanId: 'clan_demo_001',
          branchId: null,
          transactionType: FundTransactionType.donation,
          amountMinor: 3000000,
          currency: 'VND',
          memberId: 'member_demo_parent_001',
          externalReference: null,
          occurredAt: DateTime.utc(2026, 1, 12, 2, 0),
          note: 'Tet contribution campaign',
          receiptUrl: null,
          createdAt: DateTime.utc(2026, 1, 12, 2, 5),
          createdBy: 'member_demo_parent_001',
        ),
        'txn_demo_002': FundTransaction(
          id: 'txn_demo_002',
          fundId: 'fund_demo_scholarship',
          clanId: 'clan_demo_001',
          branchId: null,
          transactionType: FundTransactionType.expense,
          amountMinor: 500000,
          currency: 'VND',
          memberId: 'member_demo_parent_001',
          externalReference: null,
          occurredAt: DateTime.utc(2026, 2, 10, 7, 0),
          note: 'Scholarship disbursement batch 1',
          receiptUrl: null,
          createdAt: DateTime.utc(2026, 2, 10, 7, 2),
          createdBy: 'member_demo_parent_001',
        ),
        'txn_demo_003': FundTransaction(
          id: 'txn_demo_003',
          fundId: 'fund_demo_operations',
          clanId: 'clan_demo_001',
          branchId: null,
          transactionType: FundTransactionType.donation,
          amountMinor: 1000000,
          currency: 'VND',
          memberId: 'member_demo_parent_002',
          externalReference: 'OPS-2026-01',
          occurredAt: DateTime.utc(2026, 1, 20, 3, 0),
          note: 'Operations contribution',
          receiptUrl: null,
          createdAt: DateTime.utc(2026, 1, 20, 3, 1),
          createdBy: 'member_demo_parent_002',
        ),
        'txn_demo_004': FundTransaction(
          id: 'txn_demo_004',
          fundId: 'fund_demo_operations',
          clanId: 'clan_demo_001',
          branchId: null,
          transactionType: FundTransactionType.expense,
          amountMinor: 150000,
          currency: 'VND',
          memberId: 'member_demo_parent_002',
          externalReference: null,
          occurredAt: DateTime.utc(2026, 2, 1, 8, 0),
          note: 'Memorial logistics supplies',
          receiptUrl: null,
          createdAt: DateTime.utc(2026, 2, 1, 8, 1),
          createdBy: 'member_demo_parent_002',
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
      events: {
        'event_demo_memorial_001': EventRecord(
          id: 'event_demo_memorial_001',
          clanId: 'clan_demo_001',
          branchId: 'branch_demo_001',
          title: 'Giỗ cụ tổ mùa xuân',
          description:
              'Lễ giỗ thường niên tại từ đường chi trưởng, chuẩn bị lễ vật trước 2 giờ.',
          eventType: EventType.deathAnniversary,
          targetMemberId: 'member_demo_elder_001',
          locationName: 'Từ đường chi trưởng',
          locationAddress: 'Quang Nam, Viet Nam',
          startsAt: DateTime.utc(2026, 4, 4, 2, 0),
          endsAt: DateTime.utc(2026, 4, 4, 5, 30),
          timezone: AppEnvironment.defaultTimezone,
          isRecurring: true,
          recurrenceRule: 'FREQ=YEARLY',
          reminderOffsetsMinutes: [10080, 1440, 120],
          visibility: 'clan',
          status: 'scheduled',
        ),
        'event_demo_gathering_001': EventRecord(
          id: 'event_demo_gathering_001',
          clanId: 'clan_demo_001',
          branchId: 'branch_demo_002',
          title: 'Họp mặt đầu hè',
          description:
              'Họp mặt toàn chi để cập nhật kế hoạch học bổng và quỹ đóng góp.',
          eventType: EventType.clanGathering,
          targetMemberId: null,
          locationName: 'Nhà văn hóa chi phụ',
          locationAddress: 'Hue, Viet Nam',
          startsAt: DateTime.utc(2026, 5, 12, 1, 0),
          endsAt: DateTime.utc(2026, 5, 12, 4, 0),
          timezone: AppEnvironment.defaultTimezone,
          isRecurring: false,
          recurrenceRule: null,
          reminderOffsetsMinutes: [1440, 120],
          visibility: 'clan',
          status: 'scheduled',
        ),
      },
    );
    store.reconcileRelationshipFields('clan_demo_001');
    store.recountBranchMembers('clan_demo_001');
    store.recountFundBalances('clan_demo_001');
    return store;
  }

  static final DebugGenealogyStore _sharedSeeded = DebugGenealogyStore.seeded();

  static DebugGenealogyStore sharedSeeded() => _sharedSeeded;

  final Map<String, MemberProfile> members;
  final Map<String, BranchProfile> branches;
  final Map<String, FundProfile> funds;
  final Map<String, FundTransaction> transactions;
  final Map<String, RelationshipRecord> relationships;
  final Map<String, EventRecord> events;
  int memberSequence;
  int eventSequence;
  int fundSequence;
  int transactionSequence;

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

  void recountFundBalances(String clanId) {
    for (final entry in funds.entries) {
      final fund = entry.value;
      if (fund.clanId != clanId) {
        continue;
      }

      var balance = 0;
      for (final transaction in transactions.values.where(
        (candidate) =>
            candidate.clanId == clanId && candidate.fundId == fund.id,
      )) {
        balance += transaction.signedAmountMinor;
      }

      funds[entry.key] = fund.copyWith(balanceMinor: balance);
    }
  }
}
