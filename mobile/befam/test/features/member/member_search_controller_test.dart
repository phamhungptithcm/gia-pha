import 'dart:typed_data';

import 'package:befam/features/auth/models/auth_entry_method.dart';
import 'package:befam/features/auth/models/auth_member_access_mode.dart';
import 'package:befam/features/auth/models/auth_session.dart';
import 'package:befam/features/clan/models/branch_profile.dart';
import 'package:befam/features/member/models/member_draft.dart';
import 'package:befam/features/member/models/member_profile.dart';
import 'package:befam/features/member/models/member_social_links.dart';
import 'package:befam/features/member/models/member_workspace_snapshot.dart';
import 'package:befam/features/member/presentation/member_controller.dart';
import 'package:befam/features/member/services/member_repository.dart';
import 'package:befam/features/member/services/member_search_analytics_service.dart';
import 'package:befam/features/member/services/member_search_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  AuthSession buildSession({
    String primaryRole = 'CLAN_ADMIN',
    String memberId = 'm1',
    String branchId = 'b1',
  }) {
    return AuthSession(
      uid: 'uid-1',
      loginMethod: AuthEntryMethod.phone,
      phoneE164: '+84901111111',
      displayName: 'Tester',
      memberId: memberId,
      clanId: 'c1',
      branchId: branchId,
      primaryRole: primaryRole,
      accessMode: AuthMemberAccessMode.claimed,
      linkedAuthUid: true,
      isSandbox: false,
      signedInAtIso: DateTime(2026, 3, 14).toIso8601String(),
    );
  }

  MemberProfile buildMember({
    required String id,
    required String fullName,
    required String branchId,
    required int generation,
  }) {
    return MemberProfile(
      id: id,
      clanId: 'c1',
      branchId: branchId,
      fullName: fullName,
      normalizedFullName: fullName.toLowerCase(),
      nickName: '',
      gender: null,
      birthDate: null,
      deathDate: null,
      phoneE164: null,
      email: null,
      addressText: null,
      jobTitle: null,
      avatarUrl: null,
      bio: null,
      socialLinks: const MemberSocialLinks(),
      parentIds: const [],
      childrenIds: const [],
      spouseIds: const [],
      generation: generation,
      primaryRole: 'MEMBER',
      status: 'active',
      isMinor: false,
      authUid: null,
    );
  }

  Future<void> waitForSearch(MemberController controller) async {
    for (var attempt = 0; attempt < 60; attempt++) {
      if (!controller.isSearching) {
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  }

  test('tracks search submitted analytics after query updates', () async {
    final members = [
      buildMember(
        id: 'm1',
        fullName: 'Nguyen An',
        branchId: 'b1',
        generation: 4,
      ),
      buildMember(
        id: 'm2',
        fullName: 'Tran Binh',
        branchId: 'b2',
        generation: 5,
      ),
    ];
    final repository = _FakeMemberRepository(members: members);
    final analytics = _RecordingSearchAnalyticsService();

    final controller = MemberController(
      repository: repository,
      session: buildSession(),
      searchProvider: const LocalMemberSearchProvider(latency: Duration.zero),
      searchAnalyticsService: analytics,
    );

    await controller.initialize();
    controller.updateSearchQuery('nguyen');
    await waitForSearch(controller);

    expect(analytics.searchSubmittedEvents, hasLength(1));
    expect(analytics.searchSubmittedEvents.first.queryLength, 6);
    expect(analytics.searchSubmittedEvents.first.hasBranchFilter, isFalse);
    expect(analytics.searchSubmittedEvents.first.hasGenerationFilter, isFalse);
    expect(analytics.searchSubmittedEvents.first.resultCount, 1);
  });

  test(
    'tracks filter updates when branch and generation filters change',
    () async {
      final members = [
        buildMember(
          id: 'm1',
          fullName: 'Nguyen An',
          branchId: 'b1',
          generation: 4,
        ),
        buildMember(
          id: 'm2',
          fullName: 'Tran Binh',
          branchId: 'b2',
          generation: 5,
        ),
      ];
      final repository = _FakeMemberRepository(members: members);
      final analytics = _RecordingSearchAnalyticsService();

      final controller = MemberController(
        repository: repository,
        session: buildSession(),
        searchProvider: const LocalMemberSearchProvider(latency: Duration.zero),
        searchAnalyticsService: analytics,
      );

      await controller.initialize();

      controller.updateBranchFilter('b2');
      await waitForSearch(controller);
      controller.updateGenerationFilter(5);
      await waitForSearch(controller);

      expect(analytics.filterUpdatedEvents, hasLength(2));
      expect(analytics.filterUpdatedEvents.first.hasBranchFilter, isTrue);
      expect(analytics.filterUpdatedEvents.first.hasGenerationFilter, isFalse);
      expect(analytics.filterUpdatedEvents.last.hasBranchFilter, isTrue);
      expect(analytics.filterUpdatedEvents.last.hasGenerationFilter, isTrue);
    },
  );

  test('tracks failed searches for analytics instrumentation', () async {
    final repository = _FakeMemberRepository(
      members: [
        buildMember(
          id: 'm1',
          fullName: 'Nguyen An',
          branchId: 'b1',
          generation: 4,
        ),
      ],
    );
    final analytics = _RecordingSearchAnalyticsService();

    final controller = MemberController(
      repository: repository,
      session: buildSession(),
      searchProvider: _AlwaysFailSearchProvider(),
      searchAnalyticsService: analytics,
    );

    await controller.initialize();
    controller.updateSearchQuery('ng');
    await waitForSearch(controller);

    expect(controller.searchError, 'search_failed');
    expect(analytics.searchFailedEvents, hasLength(1));
    expect(analytics.searchFailedEvents.first.queryLength, 2);
  });

  test('supports retry after a failed search run', () async {
    final members = [
      buildMember(
        id: 'm1',
        fullName: 'Nguyen An',
        branchId: 'b1',
        generation: 4,
      ),
      buildMember(
        id: 'm2',
        fullName: 'Tran Binh',
        branchId: 'b2',
        generation: 5,
      ),
    ];
    final repository = _FakeMemberRepository(members: members);
    final searchProvider = _FlakySearchProvider();
    final analytics = _RecordingSearchAnalyticsService();

    final controller = MemberController(
      repository: repository,
      session: buildSession(),
      searchProvider: searchProvider,
      searchAnalyticsService: analytics,
    );

    await controller.initialize();
    expect(controller.searchError, 'search_failed');
    expect(controller.filteredMembers, isEmpty);

    await controller.retrySearch();
    expect(controller.searchError, isNull);
    expect(controller.filteredMembers.map((member) => member.id), ['m1', 'm2']);
    expect(analytics.retryRequestedEvents, hasLength(1));
    expect(analytics.searchSubmittedEvents, hasLength(1));
  });

  test(
    'allows manual role selection when creator has assignment permission',
    () async {
      final repository = _FakeMemberRepository(
        members: [
          buildMember(
            id: 'leader-1',
            fullName: 'Clan Leader',
            branchId: 'b1',
            generation: 1,
          ),
        ],
      );

      final controller = MemberController(
        repository: repository,
        session: buildSession(),
        searchProvider: const LocalMemberSearchProvider(latency: Duration.zero),
        searchAnalyticsService: _RecordingSearchAnalyticsService(),
      );

      await controller.initialize();
      final draft = MemberDraft.empty(
        defaultBranchId: 'b1',
      ).copyWith(generation: 3, primaryRole: 'TREASURER');

      expect(controller.resolveCreateRoleForDraft(draft), 'TREASURER');
    },
  );

  test('auto-assigns member role when parent node is selected', () async {
    final repository = _FakeMemberRepository(
      members: [
        buildMember(
          id: 'parent-1',
          fullName: 'Parent',
          branchId: 'b1',
          generation: 4,
        ),
      ],
    );

    final controller = MemberController(
      repository: repository,
      session: buildSession(
        primaryRole: 'BRANCH_ADMIN',
        memberId: 'parent-1',
        branchId: 'b1',
      ),
      searchProvider: const LocalMemberSearchProvider(latency: Duration.zero),
      searchAnalyticsService: _RecordingSearchAnalyticsService(),
    );

    await controller.initialize();
    final draft = MemberDraft.empty(
      defaultBranchId: 'b1',
    ).copyWith(parentIds: const ['parent-1'], primaryRole: 'CLAN_LEADER');

    expect(controller.resolveCreateRoleForDraft(draft), 'MEMBER');
  });

  test(
    'auto-assigns clan leader for first root node when no leadership exists',
    () async {
      final repository = _FakeMemberRepository(
        members: [
          buildMember(
            id: 'member-1',
            fullName: 'Regular Member',
            branchId: 'b1',
            generation: 3,
          ),
        ],
      );

      final controller = MemberController(
        repository: repository,
        session: buildSession(
          primaryRole: 'BRANCH_ADMIN',
          memberId: 'member-1',
          branchId: 'b1',
        ),
        searchProvider: const LocalMemberSearchProvider(latency: Duration.zero),
        searchAnalyticsService: _RecordingSearchAnalyticsService(),
      );

      await controller.initialize();
      final draft = MemberDraft.empty(
        defaultBranchId: 'b1',
      ).copyWith(generation: 1);

      expect(controller.resolveCreateRoleForDraft(draft), 'CLAN_LEADER');
    },
  );
}

class _FakeMemberRepository implements MemberRepository {
  _FakeMemberRepository({required this.members});

  final List<MemberProfile> members;

  @override
  bool get isSandbox => false;

  @override
  Future<MemberWorkspaceSnapshot> loadWorkspace({
    required AuthSession session,
  }) async {
    return MemberWorkspaceSnapshot(
      members: members,
      branches: const [
        BranchProfile(
          id: 'b1',
          clanId: 'c1',
          name: 'Branch 1',
          code: 'B1',
          leaderMemberId: null,
          viceLeaderMemberId: null,
          generationLevelHint: 1,
          status: 'active',
          memberCount: 1,
        ),
        BranchProfile(
          id: 'b2',
          clanId: 'c1',
          name: 'Branch 2',
          code: 'B2',
          leaderMemberId: null,
          viceLeaderMemberId: null,
          generationLevelHint: 1,
          status: 'active',
          memberCount: 1,
        ),
      ],
    );
  }

  @override
  Future<MemberProfile> saveMember({
    required AuthSession session,
    String? memberId,
    required MemberDraft draft,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<MemberProfile> uploadAvatar({
    required AuthSession session,
    required String memberId,
    required Uint8List bytes,
    required String fileName,
    String contentType = 'image/jpeg',
  }) {
    throw UnimplementedError();
  }
}

class _FlakySearchProvider implements MemberSearchProvider {
  int _calls = 0;

  @override
  Future<List<MemberProfile>> search({
    required List<MemberProfile> members,
    required MemberSearchQuery query,
  }) async {
    _calls += 1;
    if (_calls == 1) {
      throw Exception('search failed');
    }
    return members;
  }
}

class _AlwaysFailSearchProvider implements MemberSearchProvider {
  @override
  Future<List<MemberProfile>> search({
    required List<MemberProfile> members,
    required MemberSearchQuery query,
  }) async {
    throw Exception('search failed');
  }
}

class _SearchEventData {
  const _SearchEventData({
    required this.queryLength,
    required this.hasBranchFilter,
    required this.hasGenerationFilter,
    this.resultCount,
  });

  final int queryLength;
  final bool hasBranchFilter;
  final bool hasGenerationFilter;
  final int? resultCount;
}

class _RecordingSearchAnalyticsService implements MemberSearchAnalyticsService {
  final List<_SearchEventData> searchSubmittedEvents = [];
  final List<_SearchEventData> searchFailedEvents = [];
  final List<_SearchEventData> filterUpdatedEvents = [];
  final List<_SearchEventData> retryRequestedEvents = [];

  @override
  Future<void> trackFiltersUpdated({
    required int queryLength,
    required bool hasBranchFilter,
    required bool hasGenerationFilter,
  }) async {
    filterUpdatedEvents.add(
      _SearchEventData(
        queryLength: queryLength,
        hasBranchFilter: hasBranchFilter,
        hasGenerationFilter: hasGenerationFilter,
      ),
    );
  }

  @override
  Future<void> trackResultOpened({
    required String memberId,
    required String branchId,
    required int generation,
  }) async {}

  @override
  Future<void> trackRetryRequested({
    required int queryLength,
    required bool hasBranchFilter,
    required bool hasGenerationFilter,
  }) async {
    retryRequestedEvents.add(
      _SearchEventData(
        queryLength: queryLength,
        hasBranchFilter: hasBranchFilter,
        hasGenerationFilter: hasGenerationFilter,
      ),
    );
  }

  @override
  Future<void> trackSearchFailed({
    required int queryLength,
    required bool hasBranchFilter,
    required bool hasGenerationFilter,
  }) async {
    searchFailedEvents.add(
      _SearchEventData(
        queryLength: queryLength,
        hasBranchFilter: hasBranchFilter,
        hasGenerationFilter: hasGenerationFilter,
      ),
    );
  }

  @override
  Future<void> trackSearchSubmitted({
    required int queryLength,
    required bool hasBranchFilter,
    required bool hasGenerationFilter,
    required int resultCount,
  }) async {
    searchSubmittedEvents.add(
      _SearchEventData(
        queryLength: queryLength,
        hasBranchFilter: hasBranchFilter,
        hasGenerationFilter: hasGenerationFilter,
        resultCount: resultCount,
      ),
    );
  }
}
