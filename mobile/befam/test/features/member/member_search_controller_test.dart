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
  AuthSession buildSession() {
    return AuthSession(
      uid: 'uid-1',
      loginMethod: AuthEntryMethod.phone,
      phoneE164: '+84901111111',
      displayName: 'Tester',
      memberId: 'm1',
      clanId: 'c1',
      branchId: 'b1',
      primaryRole: 'CLAN_ADMIN',
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

    final controller = MemberController(
      repository: repository,
      session: buildSession(),
      searchProvider: searchProvider,
      searchAnalyticsService: const NoopMemberSearchAnalyticsService(),
    );

    await controller.initialize();
    expect(controller.searchError, 'search_failed');
    expect(controller.filteredMembers, isEmpty);

    await controller.retrySearch();
    expect(controller.searchError, isNull);
    expect(controller.filteredMembers.map((member) => member.id), ['m1', 'm2']);
  });
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
