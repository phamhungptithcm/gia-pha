import 'package:befam/core/services/app_environment.dart';
import 'package:befam/features/clan/models/branch_profile.dart';
import 'package:befam/features/events/models/event_record.dart';
import 'package:befam/features/events/models/event_type.dart';
import 'package:befam/features/funds/models/fund_profile.dart';
import 'package:befam/features/funds/models/fund_transaction.dart';
import 'package:befam/features/member/models/member_profile.dart';
import 'package:befam/features/member/models/member_social_links.dart';
import 'package:befam/features/relationship/models/relationship_record.dart';

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
    const clanId = 'clan_demo_001';
    final members = <String, MemberProfile>{
      'member_demo_parent_001': const MemberProfile(
        id: 'member_demo_parent_001',
        clanId: clanId,
        branchId: 'branch_demo_001',
        fullName: 'Nguyễn Minh',
        normalizedFullName: 'nguyễn minh',
        nickName: 'Minh',
        gender: 'male',
        birthDate: '1992-02-14',
        deathDate: null,
        phoneE164: '+84901234567',
        email: 'nguyen.minh@befam.vn',
        addressText: 'Đà Nẵng, Việt Nam',
        jobTitle: 'Kỹ sư phần mềm',
        avatarUrl: null,
        bio: 'Trưởng tộc hiện tại, đang quản lý gia phả và quỹ khuyến học.',
        socialLinks: MemberSocialLinks(
          facebook: 'https://facebook.com/minh',
          zalo: 'https://zalo.me/minh',
          linkedin: 'https://linkedin.com/in/minh',
        ),
        parentIds: [],
        childrenIds: [],
        spouseIds: [],
        generation: 8,
        primaryRole: 'CLAN_ADMIN',
        status: 'active',
        isMinor: false,
        authUid: 'debug:+84901234567',
      ),
      'member_demo_parent_002': const MemberProfile(
        id: 'member_demo_parent_002',
        clanId: clanId,
        branchId: 'branch_demo_002',
        fullName: 'Trần Văn Long',
        normalizedFullName: 'trần văn long',
        nickName: 'Long',
        gender: 'male',
        birthDate: '1991-07-21',
        deathDate: null,
        phoneE164: '+84908886655',
        email: 'tran.long@befam.vn',
        addressText: 'Huế, Việt Nam',
        jobTitle: 'Kỹ sư xây dựng',
        avatarUrl: null,
        bio: 'Trưởng chi phụ, phụ trách điều phối nhân sự và lịch sinh hoạt.',
        socialLinks: MemberSocialLinks(
          facebook: 'https://facebook.com/long',
          zalo: 'https://zalo.me/long',
        ),
        parentIds: [],
        childrenIds: [],
        spouseIds: [],
        generation: 8,
        primaryRole: 'BRANCH_ADMIN',
        status: 'active',
        isMinor: false,
        authUid: 'debug:+84908886655',
      ),
      'member_demo_child_001': const MemberProfile(
        id: 'member_demo_child_001',
        clanId: clanId,
        branchId: 'branch_demo_001',
        fullName: 'Bé Minh',
        normalizedFullName: 'bé minh',
        nickName: 'Minh nhỏ',
        gender: 'male',
        birthDate: '2017-04-12',
        deathDate: null,
        phoneE164: null,
        email: null,
        addressText: 'Đà Nẵng, Việt Nam',
        jobTitle: 'Học sinh',
        avatarUrl: null,
        bio: 'Thành viên học sinh dùng để kiểm thử luồng OTP phụ huynh.',
        socialLinks: MemberSocialLinks(),
        parentIds: [],
        childrenIds: [],
        spouseIds: [],
        generation: 9,
        primaryRole: 'MEMBER',
        status: 'active',
        isMinor: true,
        authUid: null,
      ),
      'member_demo_child_002': const MemberProfile(
        id: 'member_demo_child_002',
        clanId: clanId,
        branchId: 'branch_demo_002',
        fullName: 'Bé Lan',
        normalizedFullName: 'bé lan',
        nickName: 'Lan nhỏ',
        gender: 'female',
        birthDate: '2016-09-09',
        deathDate: null,
        phoneE164: null,
        email: null,
        addressText: 'Huế, Việt Nam',
        jobTitle: 'Học sinh',
        avatarUrl: null,
        bio: 'Thành viên học sinh mẫu cho kiểm thử quyền xem hồ sơ.',
        socialLinks: MemberSocialLinks(),
        parentIds: [],
        childrenIds: [],
        spouseIds: [],
        generation: 9,
        primaryRole: 'MEMBER',
        status: 'active',
        isMinor: true,
        authUid: null,
      ),
      'member_demo_elder_001': const MemberProfile(
        id: 'member_demo_elder_001',
        clanId: clanId,
        branchId: 'branch_demo_001',
        fullName: 'Ông Bảo',
        normalizedFullName: 'ông bảo',
        nickName: 'Bảo',
        gender: 'male',
        birthDate: '1972-11-01',
        deathDate: null,
        phoneE164: '+84907770011',
        email: null,
        addressText: 'Quảng Nam, Việt Nam',
        jobTitle: 'Cố vấn họ tộc',
        avatarUrl: null,
        bio: 'Thành viên lớn tuổi hỗ trợ cố vấn quy ước và nghi lễ gia tộc.',
        socialLinks: MemberSocialLinks(),
        parentIds: [],
        childrenIds: [],
        spouseIds: [],
        generation: 7,
        primaryRole: 'MEMBER',
        status: 'active',
        isMinor: false,
        authUid: null,
      ),
      'member_council_001': const MemberProfile(
        id: 'member_council_001',
        clanId: clanId,
        branchId: 'branch_demo_001',
        fullName: 'Phạm Thành Nam',
        normalizedFullName: 'phạm thành nam',
        nickName: 'Nam',
        gender: 'male',
        birthDate: '1986-03-18',
        deathDate: null,
        phoneE164: '+84901111001',
        email: 'pham.thanh.nam@befam.vn',
        addressText: 'Đà Nẵng, Việt Nam',
        jobTitle: 'Kỹ sư xây dựng',
        avatarUrl: null,
        bio:
            'Thành viên hội đồng học bổng phụ trách đánh giá hồ sơ khối kỹ thuật.',
        socialLinks: MemberSocialLinks(),
        parentIds: [],
        childrenIds: [],
        spouseIds: [],
        generation: 8,
        primaryRole: 'SCHOLARSHIP_COUNCIL_HEAD',
        status: 'active',
        isMinor: false,
        authUid: 'debug:+84901111001',
      ),
      'member_council_002': const MemberProfile(
        id: 'member_council_002',
        clanId: clanId,
        branchId: 'branch_demo_002',
        fullName: 'Nguyễn Thu Hà',
        normalizedFullName: 'nguyễn thu hà',
        nickName: 'Hà',
        gender: 'female',
        birthDate: '1988-09-11',
        deathDate: null,
        phoneE164: '+84901111002',
        email: 'nguyen.thu.ha@befam.vn',
        addressText: 'Huế, Việt Nam',
        jobTitle: 'Giáo viên trung học',
        avatarUrl: null,
        bio: 'Thành viên hội đồng học bổng phụ trách xét tiêu chí học thuật.',
        socialLinks: MemberSocialLinks(),
        parentIds: [],
        childrenIds: [],
        spouseIds: [],
        generation: 8,
        primaryRole: 'SCHOLARSHIP_COUNCIL_HEAD',
        status: 'active',
        isMinor: false,
        authUid: 'debug:+84901111002',
      ),
      'member_council_003': const MemberProfile(
        id: 'member_council_003',
        clanId: clanId,
        branchId: 'branch_demo_003',
        fullName: 'Lê Quốc Bảo',
        normalizedFullName: 'lê quốc bảo',
        nickName: 'Bảo',
        gender: 'male',
        birthDate: '1985-12-05',
        deathDate: null,
        phoneE164: '+84901111003',
        email: 'le.quoc.bao@befam.vn',
        addressText: 'Quảng Nam, Việt Nam',
        jobTitle: 'Chuyên viên quản lý đất đai xã',
        avatarUrl: null,
        bio:
            'Thành viên hội đồng học bổng phụ trách thẩm định hồ sơ minh chứng.',
        socialLinks: MemberSocialLinks(),
        parentIds: [],
        childrenIds: [],
        spouseIds: [],
        generation: 8,
        primaryRole: 'SCHOLARSHIP_COUNCIL_HEAD',
        status: 'active',
        isMinor: false,
        authUid: 'debug:+84901111003',
      ),
    };
    final branches = <String, BranchProfile>{
      'branch_demo_001': const BranchProfile(
        id: 'branch_demo_001',
        clanId: clanId,
        name: 'Chi Trưởng',
        code: 'CT01',
        leaderMemberId: 'member_demo_parent_001',
        viceLeaderMemberId: 'member_demo_parent_002',
        generationLevelHint: 8,
        status: 'active',
        memberCount: 0,
      ),
      'branch_demo_002': const BranchProfile(
        id: 'branch_demo_002',
        clanId: clanId,
        name: 'Chi Phụ',
        code: 'CP02',
        leaderMemberId: 'member_demo_parent_002',
        viceLeaderMemberId: 'member_demo_elder_001',
        generationLevelHint: 8,
        status: 'active',
        memberCount: 0,
      ),
      'branch_demo_003': const BranchProfile(
        id: 'branch_demo_003',
        clanId: clanId,
        name: 'Chi Thành Đạt',
        code: 'CT03',
        leaderMemberId: 'member_prod_a_g8_a',
        viceLeaderMemberId: 'member_prod_a_g7_a',
        generationLevelHint: 8,
        status: 'active',
        memberCount: 0,
      ),
      'branch_demo_004': const BranchProfile(
        id: 'branch_demo_004',
        clanId: clanId,
        name: 'Chi Hạnh Phúc',
        code: 'CP04',
        leaderMemberId: 'member_prod_b_g8_a',
        viceLeaderMemberId: 'member_prod_b_g7_a',
        generationLevelHint: 8,
        status: 'active',
        memberCount: 0,
      ),
      'branch_demo_005': const BranchProfile(
        id: 'branch_demo_005',
        clanId: clanId,
        name: 'Chi An Bình',
        code: 'CA05',
        leaderMemberId: 'member_prod_c_g8_a',
        viceLeaderMemberId: 'member_prod_c_g7_a',
        generationLevelHint: 8,
        status: 'active',
        memberCount: 0,
      ),
    };
    final funds = <String, FundProfile>{
      'fund_demo_scholarship': const FundProfile(
        id: 'fund_demo_scholarship',
        clanId: clanId,
        branchId: null,
        name: 'Quỹ Khuyến học',
        description: 'Hỗ trợ hậu duệ bằng học bổng thường niên.',
        fundType: 'scholarship',
        currency: 'VND',
        balanceMinor: 2500000,
        status: 'active',
      ),
      'fund_demo_operations': const FundProfile(
        id: 'fund_demo_operations',
        clanId: clanId,
        branchId: null,
        name: 'Quỹ Vận hành họ tộc',
        description: 'Chi trả nghi lễ và hoạt động chung của họ tộc.',
        fundType: 'operations',
        currency: 'VND',
        balanceMinor: 850000,
        status: 'active',
      ),
    };
    final transactions = <String, FundTransaction>{
      'txn_demo_001': FundTransaction(
        id: 'txn_demo_001',
        fundId: 'fund_demo_scholarship',
        clanId: clanId,
        branchId: null,
        transactionType: FundTransactionType.donation,
        amountMinor: 3000000,
        currency: 'VND',
        memberId: 'member_demo_parent_001',
        externalReference: null,
        occurredAt: DateTime.utc(2026, 1, 12, 2, 0),
        note: 'Chiến dịch đóng góp Tết',
        receiptUrl: null,
        createdAt: DateTime.utc(2026, 1, 12, 2, 5),
        createdBy: 'member_demo_parent_001',
      ),
      'txn_demo_002': FundTransaction(
        id: 'txn_demo_002',
        fundId: 'fund_demo_scholarship',
        clanId: clanId,
        branchId: null,
        transactionType: FundTransactionType.expense,
        amountMinor: 500000,
        currency: 'VND',
        memberId: 'member_demo_parent_001',
        externalReference: null,
        occurredAt: DateTime.utc(2026, 2, 10, 7, 0),
        note: 'Chi học bổng đợt 1',
        receiptUrl: null,
        createdAt: DateTime.utc(2026, 2, 10, 7, 2),
        createdBy: 'member_demo_parent_001',
      ),
      'txn_demo_003': FundTransaction(
        id: 'txn_demo_003',
        fundId: 'fund_demo_operations',
        clanId: clanId,
        branchId: null,
        transactionType: FundTransactionType.donation,
        amountMinor: 1000000,
        currency: 'VND',
        memberId: 'member_demo_parent_002',
        externalReference: 'OPS-2026-01',
        occurredAt: DateTime.utc(2026, 1, 20, 3, 0),
        note: 'Đóng góp quỹ vận hành',
        receiptUrl: null,
        createdAt: DateTime.utc(2026, 1, 20, 3, 1),
        createdBy: 'member_demo_parent_002',
      ),
      'txn_demo_004': FundTransaction(
        id: 'txn_demo_004',
        fundId: 'fund_demo_operations',
        clanId: clanId,
        branchId: null,
        transactionType: FundTransactionType.expense,
        amountMinor: 150000,
        currency: 'VND',
        memberId: 'member_demo_parent_002',
        externalReference: null,
        occurredAt: DateTime.utc(2026, 2, 1, 8, 0),
        note: 'Chi hậu cần lễ giỗ',
        receiptUrl: null,
        createdAt: DateTime.utc(2026, 2, 1, 8, 1),
        createdBy: 'member_demo_parent_002',
      ),
    };
    final relationships = <String, RelationshipRecord>{
      'rel_spouse_member_demo_parent_001_member_demo_parent_002':
          const RelationshipRecord(
            id: 'rel_spouse_member_demo_parent_001_member_demo_parent_002',
            clanId: clanId,
            personAId: 'member_demo_parent_001',
            personBId: 'member_demo_parent_002',
            type: RelationshipType.spouse,
            direction: RelationshipDirection.undirected,
            status: 'active',
            source: 'manual',
            createdBy: 'debug:+84901234567',
          ),
      'rel_parent_child_member_demo_parent_001_member_demo_child_001':
          const RelationshipRecord(
            id: 'rel_parent_child_member_demo_parent_001_member_demo_child_001',
            clanId: clanId,
            personAId: 'member_demo_parent_001',
            personBId: 'member_demo_child_001',
            type: RelationshipType.parentChild,
            direction: RelationshipDirection.aToB,
            status: 'active',
            source: 'manual',
            createdBy: 'debug:+84901234567',
          ),
      'rel_parent_child_member_demo_parent_002_member_demo_child_001':
          const RelationshipRecord(
            id: 'rel_parent_child_member_demo_parent_002_member_demo_child_001',
            clanId: clanId,
            personAId: 'member_demo_parent_002',
            personBId: 'member_demo_child_001',
            type: RelationshipType.parentChild,
            direction: RelationshipDirection.aToB,
            status: 'active',
            source: 'manual',
            createdBy: 'debug:+84908886655',
          ),
      'rel_parent_child_member_demo_parent_001_member_demo_child_002':
          const RelationshipRecord(
            id: 'rel_parent_child_member_demo_parent_001_member_demo_child_002',
            clanId: clanId,
            personAId: 'member_demo_parent_001',
            personBId: 'member_demo_child_002',
            type: RelationshipType.parentChild,
            direction: RelationshipDirection.aToB,
            status: 'active',
            source: 'manual',
            createdBy: 'debug:+84901234567',
          ),
      'rel_parent_child_member_demo_parent_002_member_demo_child_002':
          const RelationshipRecord(
            id: 'rel_parent_child_member_demo_parent_002_member_demo_child_002',
            clanId: clanId,
            personAId: 'member_demo_parent_002',
            personBId: 'member_demo_child_002',
            type: RelationshipType.parentChild,
            direction: RelationshipDirection.aToB,
            status: 'active',
            source: 'manual',
            createdBy: 'debug:+84908886655',
          ),
    };
    final events = <String, EventRecord>{
      'event_demo_memorial_001': EventRecord(
        id: 'event_demo_memorial_001',
        clanId: clanId,
        branchId: 'branch_demo_001',
        title: 'Giỗ cụ tổ mùa xuân',
        description:
            'Lễ giỗ thường niên tại từ đường chi trưởng, chuẩn bị lễ vật trước 2 giờ.',
        eventType: EventType.deathAnniversary,
        targetMemberId: 'member_demo_elder_001',
        locationName: 'Từ đường chi trưởng',
        locationAddress: 'Quảng Nam, Việt Nam',
        startsAt: DateTime.utc(2026, 4, 4, 2, 0),
        endsAt: DateTime.utc(2026, 4, 4, 5, 30),
        timezone: AppEnvironment.defaultTimezone,
        isRecurring: true,
        recurrenceRule: 'FREQ=YEARLY',
        reminderOffsetsMinutes: [10080, 1440, 120],
        visibility: 'clan',
        status: 'scheduled',
        ritualKey: null,
        ritualPreset: null,
        isAutoGenerated: false,
      ),
      'event_demo_gathering_001': EventRecord(
        id: 'event_demo_gathering_001',
        clanId: clanId,
        branchId: 'branch_demo_002',
        title: 'Họp mặt đầu hè',
        description:
            'Họp mặt toàn chi để cập nhật kế hoạch học bổng và quỹ đóng góp.',
        eventType: EventType.clanGathering,
        targetMemberId: null,
        locationName: 'Nhà văn hóa chi phụ',
        locationAddress: 'Huế, Việt Nam',
        startsAt: DateTime.utc(2026, 5, 12, 1, 0),
        endsAt: DateTime.utc(2026, 5, 12, 4, 0),
        timezone: AppEnvironment.defaultTimezone,
        isRecurring: false,
        recurrenceRule: null,
        reminderOffsetsMinutes: [1440, 120],
        visibility: 'clan',
        status: 'scheduled',
        ritualKey: null,
        ritualPreset: null,
        isAutoGenerated: false,
      ),
    };

    _seedProductionLikeLineages(
      clanId: clanId,
      members: members,
      relationships: relationships,
    );

    relationships['rel_parent_child_member_prod_a_g7_a_member_demo_parent_001'] =
        const RelationshipRecord(
          id: 'rel_parent_child_member_prod_a_g7_a_member_demo_parent_001',
          clanId: clanId,
          personAId: 'member_prod_a_g7_a',
          personBId: 'member_demo_parent_001',
          type: RelationshipType.parentChild,
          direction: RelationshipDirection.aToB,
          status: 'active',
          source: 'seeded',
        );
    relationships['rel_parent_child_member_prod_a_g7_b_member_demo_parent_001'] =
        const RelationshipRecord(
          id: 'rel_parent_child_member_prod_a_g7_b_member_demo_parent_001',
          clanId: clanId,
          personAId: 'member_prod_a_g7_b',
          personBId: 'member_demo_parent_001',
          type: RelationshipType.parentChild,
          direction: RelationshipDirection.aToB,
          status: 'active',
          source: 'seeded',
        );
    relationships['rel_parent_child_member_prod_b_g7_a_member_demo_parent_002'] =
        const RelationshipRecord(
          id: 'rel_parent_child_member_prod_b_g7_a_member_demo_parent_002',
          clanId: clanId,
          personAId: 'member_prod_b_g7_a',
          personBId: 'member_demo_parent_002',
          type: RelationshipType.parentChild,
          direction: RelationshipDirection.aToB,
          status: 'active',
          source: 'seeded',
        );
    relationships['rel_parent_child_member_prod_b_g7_b_member_demo_parent_002'] =
        const RelationshipRecord(
          id: 'rel_parent_child_member_prod_b_g7_b_member_demo_parent_002',
          clanId: clanId,
          personAId: 'member_prod_b_g7_b',
          personBId: 'member_demo_parent_002',
          type: RelationshipType.parentChild,
          direction: RelationshipDirection.aToB,
          status: 'active',
          source: 'seeded',
        );

    final store = DebugGenealogyStore(
      members: members,
      branches: branches,
      funds: funds,
      transactions: transactions,
      relationships: relationships,
      events: events,
    );
    store.reconcileRelationshipFields(clanId);
    store.recountBranchMembers(clanId);
    store.recountFundBalances(clanId);
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

void _seedProductionLikeLineages({
  required String clanId,
  required Map<String, MemberProfile> members,
  required Map<String, RelationshipRecord> relationships,
}) {
  const lineages = <_LineageSeedConfig>[
    _LineageSeedConfig(
      key: 'a',
      branchId: 'branch_demo_003',
      addressText: 'Đà Nẵng, Việt Nam',
      maleNames: [
        'Nguyễn Hữu Phúc',
        'Nguyễn Văn Khang',
        'Nguyễn Thành An',
        'Nguyễn Đức Bình',
        'Nguyễn Quang Hiếu',
        'Nguyễn Minh Duy',
        'Nguyễn Trọng Nam',
        'Nguyễn Quốc Long',
        'Nguyễn Gia Bảo',
        'Nguyễn Nhật Minh',
      ],
      femaleNames: [
        'Phạm Thị Lành',
        'Trần Thị Hảo',
        'Lê Thị Cúc',
        'Đỗ Thị Mai',
        'Bùi Thị Thanh',
        'Võ Thị Thu',
        'Ngô Thị Lan',
        'Phan Thị Hương',
        'Huỳnh Thị Anh',
        'Đặng Khánh Linh',
      ],
      maleJobs: [
        'Nông dân',
        'Thợ mộc',
        'Công nhân xưởng',
        'Chủ nhiệm hợp tác xã',
        'Cán bộ xã',
        'Chủ tịch xã',
        'Quản lý đất đai xã',
        'Kỹ sư phần mềm',
        'Sinh viên',
        'Học sinh',
      ],
      femaleJobs: [
        'Làm nông',
        'Buôn bán nhỏ',
        'Công nhân may',
        'Y tá xã',
        'Giáo viên tiểu học',
        'Phó chủ tịch xã',
        'Kế toán hợp tác xã',
        'Kỹ sư xây dựng',
        'Sinh viên',
        'Học sinh',
      ],
    ),
    _LineageSeedConfig(
      key: 'b',
      branchId: 'branch_demo_004',
      addressText: 'Huế, Việt Nam',
      maleNames: [
        'Trần Công Bách',
        'Trần Đình Sơn',
        'Trần Quang Lực',
        'Trần Văn Chinh',
        'Trần Minh Toàn',
        'Trần Hoàng Vũ',
        'Trần Đức Tín',
        'Trần Thành Đạt',
        'Trần Gia Huy',
        'Trần Anh Khoa',
      ],
      femaleNames: [
        'Nguyễn Thị Điệp',
        'Phạm Thị Uyên',
        'Lâm Thị Vân',
        'Tạ Thị Yến',
        'Đoàn Thị My',
        'Hoàng Thị Ngân',
        'Lý Thị Hà',
        'Dương Thị Khánh',
        'Mai Thị Nhi',
        'Trịnh Bảo Ngọc',
      ],
      maleJobs: [
        'Nông dân',
        'Thợ rèn',
        'Công nhân cơ khí',
        'Tổ trưởng sản xuất',
        'Cán bộ thủy lợi',
        'Chủ tịch tỉnh',
        'Kỹ sư xây dựng',
        'Quản lý dự án dân dụng',
        'Sinh viên',
        'Học sinh',
      ],
      femaleJobs: [
        'Làm nông',
        'Nội trợ',
        'Công nhân chế biến',
        'Cán bộ dân số',
        'Giáo viên trung học',
        'Quản lý đất đai xã',
        'Điều dưỡng',
        'Kỹ sư phần mềm',
        'Sinh viên',
        'Học sinh',
      ],
    ),
    _LineageSeedConfig(
      key: 'c',
      branchId: 'branch_demo_005',
      addressText: 'Hải Phòng, Việt Nam',
      maleNames: [
        'Lê Văn Trác',
        'Lê Hồng Lâm',
        'Lê Quốc Hưng',
        'Lê Thanh Phong',
        'Lê Đình Vinh',
        'Lê Khắc Tài',
        'Lê Ngọc Quân',
        'Lê Minh Khoa',
        'Lê Thiên Ân',
        'Lê Quốc Khải',
      ],
      femaleNames: [
        'Trần Thị Sửu',
        'Nguyễn Thị Hòa',
        'Phạm Thị Bích',
        'Đinh Thị Sen',
        'Huỳnh Thị Mơ',
        'Vũ Thị Liên',
        'Phùng Thị Ánh',
        'Đặng Thị Quyên',
        'Bạch Thị Nhiên',
        'Lê Thảo Chi',
      ],
      maleJobs: [
        'Nông dân',
        'Ngư dân',
        'Phụ hồ',
        'Công nhân cảng',
        'Đội trưởng xây dựng',
        'Trưởng thôn',
        'Kỹ sư cầu đường',
        'Kỹ sư phần mềm',
        'Sinh viên',
        'Học sinh',
      ],
      femaleJobs: [
        'Làm nông',
        'Buôn bán hải sản',
        'Công nhân đóng gói',
        'Tạp vụ trường học',
        'Nhân viên văn phòng',
        'Cán bộ y tế',
        'Giáo viên mầm non',
        'Kế toán doanh nghiệp',
        'Sinh viên',
        'Học sinh',
      ],
    ),
  ];

  for (var index = 0; index < lineages.length; index += 1) {
    final config = lineages[index];
    for (var generation = 1; generation <= 10; generation += 1) {
      final maleId = _lineageMemberId(config.key, generation, 'a');
      final femaleId = _lineageMemberId(config.key, generation, 'b');
      final maleBirthYear = 1880 + ((generation - 1) * 16) + index;
      final femaleBirthYear = maleBirthYear + 1;

      final maleDeathDate = generation <= 5
          ? _isoDate(maleBirthYear + 68, 11, 3)
          : null;
      final femaleDeathDate = generation <= 5
          ? _isoDate(femaleBirthYear + 70, 5, 18)
          : null;

      final maleIsMinor = generation >= 9;
      final femaleIsMinor = generation >= 9;

      final maleFullName = config.maleNames[generation - 1];
      final femaleFullName = config.femaleNames[generation - 1];
      final maleRole = generation == 8 ? 'BRANCH_ADMIN' : 'MEMBER';

      members[maleId] = MemberProfile(
        id: maleId,
        clanId: clanId,
        branchId: config.branchId,
        fullName: maleFullName,
        normalizedFullName: maleFullName.toLowerCase(),
        nickName: _nickNameFromFullName(maleFullName),
        gender: 'male',
        birthDate: _isoDate(maleBirthYear, 2, 12),
        deathDate: maleDeathDate,
        phoneE164: generation == 8
            ? '+84${(901100000 + (index * 2000) + generation).toString()}'
            : null,
        email: generation == 8
            ? _emailFromName(maleFullName)
            : (generation == 7 ? _emailFromName(maleFullName) : null),
        addressText: config.addressText,
        jobTitle: config.maleJobs[generation - 1],
        avatarUrl: null,
        bio:
            'Thành viên đời $generation của ${config.branchId}, dữ liệu kiểm thử gần với thực tế.',
        socialLinks: const MemberSocialLinks(),
        parentIds: const [],
        childrenIds: const [],
        spouseIds: const [],
        generation: generation,
        primaryRole: maleRole,
        status: maleDeathDate == null ? 'active' : 'deceased',
        isMinor: maleIsMinor,
        authUid: null,
      );
      members[femaleId] = MemberProfile(
        id: femaleId,
        clanId: clanId,
        branchId: config.branchId,
        fullName: femaleFullName,
        normalizedFullName: femaleFullName.toLowerCase(),
        nickName: _nickNameFromFullName(femaleFullName),
        gender: 'female',
        birthDate: _isoDate(femaleBirthYear, 8, 24),
        deathDate: femaleDeathDate,
        phoneE164: generation == 8
            ? '+84${(901200000 + (index * 2000) + generation).toString()}'
            : null,
        email: generation == 8 ? _emailFromName(femaleFullName) : null,
        addressText: config.addressText,
        jobTitle: config.femaleJobs[generation - 1],
        avatarUrl: null,
        bio:
            'Thành viên đời $generation của ${config.branchId}, hồ sơ dùng để kiểm thử quy mô lớn.',
        socialLinks: const MemberSocialLinks(),
        parentIds: const [],
        childrenIds: const [],
        spouseIds: const [],
        generation: generation,
        primaryRole: generation == 8 ? 'MEMBER' : 'MEMBER',
        status: femaleDeathDate == null ? 'active' : 'deceased',
        isMinor: femaleIsMinor,
        authUid: null,
      );

      if (generation <= 8) {
        final spouseId = 'rel_spouse_${maleId}_$femaleId';
        relationships[spouseId] = RelationshipRecord(
          id: spouseId,
          clanId: clanId,
          personAId: maleId,
          personBId: femaleId,
          type: RelationshipType.spouse,
          direction: RelationshipDirection.undirected,
          status: 'active',
          source: 'seeded',
        );
      }

      if (generation < 10) {
        final childId = _lineageMemberId(config.key, generation + 1, 'a');
        final fatherRelationId = 'rel_parent_child_${maleId}_$childId';
        final motherRelationId = 'rel_parent_child_${femaleId}_$childId';

        relationships[fatherRelationId] = RelationshipRecord(
          id: fatherRelationId,
          clanId: clanId,
          personAId: maleId,
          personBId: childId,
          type: RelationshipType.parentChild,
          direction: RelationshipDirection.aToB,
          status: 'active',
          source: 'seeded',
        );
        relationships[motherRelationId] = RelationshipRecord(
          id: motherRelationId,
          clanId: clanId,
          personAId: femaleId,
          personBId: childId,
          type: RelationshipType.parentChild,
          direction: RelationshipDirection.aToB,
          status: 'active',
          source: 'seeded',
        );
      }
    }
  }
}

String _lineageMemberId(String lineage, int generation, String suffix) {
  return 'member_prod_${lineage}_g${generation}_$suffix';
}

String _nickNameFromFullName(String value) {
  final tokens = value
      .trim()
      .split(RegExp(r'\s+'))
      .where((token) => token.isNotEmpty)
      .toList(growable: false);
  if (tokens.isEmpty) {
    return '';
  }
  return tokens.last;
}

String _emailFromName(String value) {
  final normalized = value
      .toLowerCase()
      .replaceAll('đ', 'd')
      .replaceAll('ă', 'a')
      .replaceAll('â', 'a')
      .replaceAll('á', 'a')
      .replaceAll('à', 'a')
      .replaceAll('ả', 'a')
      .replaceAll('ã', 'a')
      .replaceAll('ạ', 'a')
      .replaceAll('ấ', 'a')
      .replaceAll('ầ', 'a')
      .replaceAll('ẩ', 'a')
      .replaceAll('ẫ', 'a')
      .replaceAll('ậ', 'a')
      .replaceAll('ắ', 'a')
      .replaceAll('ằ', 'a')
      .replaceAll('ẳ', 'a')
      .replaceAll('ẵ', 'a')
      .replaceAll('ặ', 'a')
      .replaceAll('é', 'e')
      .replaceAll('è', 'e')
      .replaceAll('ẻ', 'e')
      .replaceAll('ẽ', 'e')
      .replaceAll('ẹ', 'e')
      .replaceAll('ê', 'e')
      .replaceAll('ế', 'e')
      .replaceAll('ề', 'e')
      .replaceAll('ể', 'e')
      .replaceAll('ễ', 'e')
      .replaceAll('ệ', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ì', 'i')
      .replaceAll('ỉ', 'i')
      .replaceAll('ĩ', 'i')
      .replaceAll('ị', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ò', 'o')
      .replaceAll('ỏ', 'o')
      .replaceAll('õ', 'o')
      .replaceAll('ọ', 'o')
      .replaceAll('ô', 'o')
      .replaceAll('ố', 'o')
      .replaceAll('ồ', 'o')
      .replaceAll('ổ', 'o')
      .replaceAll('ỗ', 'o')
      .replaceAll('ộ', 'o')
      .replaceAll('ơ', 'o')
      .replaceAll('ớ', 'o')
      .replaceAll('ờ', 'o')
      .replaceAll('ở', 'o')
      .replaceAll('ỡ', 'o')
      .replaceAll('ợ', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ù', 'u')
      .replaceAll('ủ', 'u')
      .replaceAll('ũ', 'u')
      .replaceAll('ụ', 'u')
      .replaceAll('ư', 'u')
      .replaceAll('ứ', 'u')
      .replaceAll('ừ', 'u')
      .replaceAll('ử', 'u')
      .replaceAll('ữ', 'u')
      .replaceAll('ự', 'u')
      .replaceAll('ý', 'y')
      .replaceAll('ỳ', 'y')
      .replaceAll('ỷ', 'y')
      .replaceAll('ỹ', 'y')
      .replaceAll('ỵ', 'y');
  final slug = normalized
      .replaceAll(RegExp(r'[^a-z0-9]+'), '.')
      .replaceAll(RegExp(r'\.+'), '.')
      .replaceAll(RegExp(r'^\.|\.$'), '');
  return '$slug@giapha.vn';
}

String _isoDate(int year, int month, int day) {
  return '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}';
}

class _LineageSeedConfig {
  const _LineageSeedConfig({
    required this.key,
    required this.branchId,
    required this.addressText,
    required this.maleNames,
    required this.femaleNames,
    required this.maleJobs,
    required this.femaleJobs,
  });

  final String key;
  final String branchId;
  final String addressText;
  final List<String> maleNames;
  final List<String> femaleNames;
  final List<String> maleJobs;
  final List<String> femaleJobs;
}
