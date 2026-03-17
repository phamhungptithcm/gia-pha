import 'package:befam/core/services/kinship_title_resolver.dart';
import 'package:befam/features/member/models/member_profile.dart';
import 'package:befam/features/member/models/member_social_links.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  MemberProfile member({
    required String id,
    required int generation,
    List<String> parentIds = const [],
    List<String> childrenIds = const [],
    List<String> spouseIds = const [],
  }) {
    return MemberProfile(
      id: id,
      clanId: 'clan_demo',
      branchId: 'branch_demo',
      fullName: id,
      normalizedFullName: id.toLowerCase(),
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
      parentIds: parentIds,
      childrenIds: childrenIds,
      spouseIds: spouseIds,
      generation: generation,
      siblingOrder: null,
      primaryRole: 'MEMBER',
      status: 'active',
      isMinor: false,
      authUid: null,
    );
  }

  test('classifies self, spouse, and sibling correctly', () {
    final viewer = member(
      id: 'viewer',
      generation: 8,
      parentIds: const ['parent_1', 'parent_2'],
      spouseIds: const ['spouse_1'],
    );

    expect(
      KinshipTitleResolver.resolveRole(viewer: viewer, member: viewer),
      KinshipTitleRole.self,
    );
    expect(
      KinshipTitleResolver.resolveRole(
        viewer: viewer,
        member: member(
          id: 'spouse_1',
          generation: 8,
          spouseIds: const ['viewer'],
        ),
      ),
      KinshipTitleRole.spouse,
    );
    expect(
      KinshipTitleResolver.resolveRole(
        viewer: viewer,
        member: member(
          id: 'sibling_1',
          generation: 8,
          parentIds: const ['parent_1', 'parent_x'],
        ),
      ),
      KinshipTitleRole.sibling,
    );
  });

  test('distinguishes direct parent/child from collateral relatives', () {
    final viewer = member(
      id: 'viewer',
      generation: 8,
      parentIds: const ['parent_1'],
      childrenIds: const ['child_1'],
    );

    expect(
      KinshipTitleResolver.resolveRole(
        viewer: viewer,
        member: member(id: 'parent_1', generation: 7),
      ),
      KinshipTitleRole.parent,
    );
    expect(
      KinshipTitleResolver.resolveRole(
        viewer: viewer,
        member: member(id: 'uncle_1', generation: 7),
      ),
      KinshipTitleRole.elderRelativeOneGeneration,
    );

    expect(
      KinshipTitleResolver.resolveRole(
        viewer: viewer,
        member: member(id: 'child_1', generation: 9),
      ),
      KinshipTitleRole.child,
    );
    expect(
      KinshipTitleResolver.resolveRole(
        viewer: viewer,
        member: member(id: 'niece_1', generation: 9),
      ),
      KinshipTitleRole.youngerRelativeOneGeneration,
    );
  });

  test('keeps clamped generation rules for far ancestors/descendants', () {
    final viewer = member(id: 'viewer', generation: 8);

    expect(
      KinshipTitleResolver.resolveRole(
        viewer: viewer,
        member: member(id: 'far_ancestor', generation: 1),
      ),
      KinshipTitleRole.greatGreatGrandparent,
    );
    expect(
      KinshipTitleResolver.resolveRole(
        viewer: viewer,
        member: member(id: 'far_descendant', generation: 15),
      ),
      KinshipTitleRole.descendant,
    );
  });
}
