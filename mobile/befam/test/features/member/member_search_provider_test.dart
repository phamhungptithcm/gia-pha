import 'package:befam/features/member/models/member_profile.dart';
import 'package:befam/features/member/models/member_social_links.dart';
import 'package:befam/features/member/services/member_search_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  MemberProfile buildMember({
    required String id,
    required String fullName,
    required String branchId,
    required int generation,
    String nickName = '',
    String? phone,
  }) {
    return MemberProfile(
      id: id,
      clanId: 'clan-1',
      branchId: branchId,
      fullName: fullName,
      normalizedFullName: fullName.toLowerCase(),
      nickName: nickName,
      gender: null,
      birthDate: null,
      deathDate: null,
      phoneE164: phone,
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

  final allMembers = [
    buildMember(
      id: 'm1',
      fullName: 'Nguyen An',
      nickName: 'An',
      branchId: 'b1',
      generation: 4,
      phone: '+84901111111',
    ),
    buildMember(
      id: 'm2',
      fullName: 'Tran Binh',
      nickName: 'Binh',
      branchId: 'b2',
      generation: 5,
      phone: '+84902222222',
    ),
    buildMember(
      id: 'm3',
      fullName: 'Le Chi',
      nickName: 'Chi',
      branchId: 'b1',
      generation: 5,
      phone: '+84903333333',
    ),
  ];

  test('filters by query, branch, and generation together', () async {
    const provider = LocalMemberSearchProvider(latency: Duration.zero);

    final results = await provider.search(
      members: allMembers,
      query: const MemberSearchQuery(
        query: 'chi',
        branchId: 'b1',
        generation: 5,
      ),
    );

    expect(results, hasLength(1));
    expect(results.first.id, 'm3');
  });

  test('matches phone query and returns sorted names', () async {
    const provider = LocalMemberSearchProvider(latency: Duration.zero);

    final results = await provider.search(
      members: allMembers,
      query: const MemberSearchQuery(query: '+84'),
    );

    expect(results.map((member) => member.fullName), [
      'Le Chi',
      'Nguyen An',
      'Tran Binh',
    ]);
  });
}
