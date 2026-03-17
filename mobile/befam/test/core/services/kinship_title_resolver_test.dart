import 'package:befam/core/services/kinship_title_resolver.dart';
import 'package:befam/features/member/models/member_profile.dart';
import 'package:befam/features/member/models/member_social_links.dart';
import 'package:befam/l10n/generated/app_localizations_vi.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  MemberProfile member({
    required String id,
    required int generation,
    String? gender,
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
      gender: gender,
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

  Map<String, MemberProfile> directory(Iterable<MemberProfile> members) {
    return {for (final member in members) member.id: member};
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

  test('uses spouse title by gender', () {
    final l10n = AppLocalizationsVi();
    final viewer = member(
      id: 'viewer',
      generation: 8,
      spouseIds: const ['spouse_male', 'spouse_female'],
    );
    final spouseMale = member(
      id: 'spouse_male',
      generation: 8,
      gender: 'male',
      spouseIds: const ['viewer'],
    );
    final spouseFemale = member(
      id: 'spouse_female',
      generation: 8,
      gender: 'female',
      spouseIds: const ['viewer'],
    );
    final membersById = directory([viewer, spouseMale, spouseFemale]);

    expect(
      KinshipTitleResolver.resolve(
        l10n: l10n,
        viewer: viewer,
        member: spouseMale,
        membersById: membersById,
      ),
      'Chồng',
    );
    expect(
      KinshipTitleResolver.resolve(
        l10n: l10n,
        viewer: viewer,
        member: spouseFemale,
        membersById: membersById,
      ),
      'Vợ',
    );
  });

  test(
    'infers spouse title from viewer gender when spouse gender is missing',
    () {
      final l10n = AppLocalizationsVi();
      final viewerMale = member(
        id: 'viewer_male',
        generation: 8,
        gender: 'male',
        spouseIds: const ['spouse_unknown'],
      );
      final spouseUnknown = member(
        id: 'spouse_unknown',
        generation: 8,
        spouseIds: const ['viewer_male'],
      );
      final membersById = directory([viewerMale, spouseUnknown]);

      expect(
        KinshipTitleResolver.resolve(
          l10n: l10n,
          viewer: viewerMale,
          member: spouseUnknown,
          membersById: membersById,
        ),
        'Vợ',
      );
    },
  );

  test('labels descendant in-law titles and paternal/maternal lineage', () {
    final l10n = AppLocalizationsVi();
    final viewer = member(
      id: 'viewer',
      generation: 5,
      gender: 'male',
      childrenIds: const ['son', 'daughter'],
      parentIds: const ['father', 'mother'],
    );
    final son = member(
      id: 'son',
      generation: 6,
      gender: 'male',
      parentIds: const ['viewer'],
      spouseIds: const ['daughter_in_law'],
      childrenIds: const ['grandchild_noi'],
    );
    final daughter = member(
      id: 'daughter',
      generation: 6,
      gender: 'female',
      parentIds: const ['viewer'],
      spouseIds: const ['son_in_law'],
      childrenIds: const ['grandchild_ngoai'],
    );
    final daughterInLaw = member(
      id: 'daughter_in_law',
      generation: 6,
      gender: 'female',
      spouseIds: const ['son'],
    );
    final sonInLaw = member(
      id: 'son_in_law',
      generation: 6,
      gender: 'male',
      spouseIds: const ['daughter'],
    );
    final grandchildNoi = member(
      id: 'grandchild_noi',
      generation: 7,
      gender: 'female',
      parentIds: const ['son'],
      childrenIds: const ['great_noi'],
    );
    final grandchildNgoai = member(
      id: 'grandchild_ngoai',
      generation: 7,
      gender: 'male',
      parentIds: const ['daughter'],
      childrenIds: const ['great_ngoai'],
    );
    final greatNoi = member(
      id: 'great_noi',
      generation: 8,
      gender: 'male',
      parentIds: const ['grandchild_noi'],
      childrenIds: const ['great_great_noi'],
    );
    final greatNgoai = member(
      id: 'great_ngoai',
      generation: 8,
      gender: 'female',
      parentIds: const ['grandchild_ngoai'],
      childrenIds: const ['great_great_ngoai'],
    );
    final greatGreatNoi = member(
      id: 'great_great_noi',
      generation: 9,
      gender: 'male',
      parentIds: const ['great_noi'],
    );
    final greatGreatNgoai = member(
      id: 'great_great_ngoai',
      generation: 9,
      gender: 'female',
      parentIds: const ['great_ngoai'],
    );
    final father = member(
      id: 'father',
      generation: 4,
      gender: 'male',
      childrenIds: const ['viewer'],
      parentIds: const ['grandfather_noi'],
    );
    final mother = member(
      id: 'mother',
      generation: 4,
      gender: 'female',
      childrenIds: const ['viewer'],
      parentIds: const ['grandmother_ngoai'],
    );
    final grandfatherNoi = member(
      id: 'grandfather_noi',
      generation: 3,
      gender: 'male',
      childrenIds: const ['father'],
    );
    final grandmotherNgoai = member(
      id: 'grandmother_ngoai',
      generation: 3,
      gender: 'female',
      childrenIds: const ['mother'],
    );

    final membersById = directory([
      viewer,
      son,
      daughter,
      daughterInLaw,
      sonInLaw,
      grandchildNoi,
      grandchildNgoai,
      greatNoi,
      greatNgoai,
      greatGreatNoi,
      greatGreatNgoai,
      father,
      mother,
      grandfatherNoi,
      grandmotherNgoai,
    ]);

    expect(
      KinshipTitleResolver.resolve(
        l10n: l10n,
        viewer: viewer,
        member: daughterInLaw,
        membersById: membersById,
      ),
      'Con dâu',
    );
    expect(
      KinshipTitleResolver.resolve(
        l10n: l10n,
        viewer: viewer,
        member: sonInLaw,
        membersById: membersById,
      ),
      'Con rể',
    );
    expect(
      KinshipTitleResolver.resolve(
        l10n: l10n,
        viewer: viewer,
        member: grandchildNoi,
        membersById: membersById,
      ),
      'Cháu nội',
    );
    expect(
      KinshipTitleResolver.resolve(
        l10n: l10n,
        viewer: viewer,
        member: grandchildNgoai,
        membersById: membersById,
      ),
      'Cháu ngoại',
    );
    expect(
      KinshipTitleResolver.resolve(
        l10n: l10n,
        viewer: viewer,
        member: greatNoi,
        membersById: membersById,
      ),
      'Chắt nội',
    );
    expect(
      KinshipTitleResolver.resolve(
        l10n: l10n,
        viewer: viewer,
        member: greatNgoai,
        membersById: membersById,
      ),
      'Chắt ngoại',
    );
    expect(
      KinshipTitleResolver.resolve(
        l10n: l10n,
        viewer: viewer,
        member: greatGreatNoi,
        membersById: membersById,
      ),
      'Chít nội',
    );
    expect(
      KinshipTitleResolver.resolve(
        l10n: l10n,
        viewer: viewer,
        member: greatGreatNgoai,
        membersById: membersById,
      ),
      'Chít ngoại',
    );
    expect(
      KinshipTitleResolver.resolve(
        l10n: l10n,
        viewer: viewer,
        member: grandfatherNoi,
        membersById: membersById,
      ),
      'Ông nội',
    );
    expect(
      KinshipTitleResolver.resolve(
        l10n: l10n,
        viewer: viewer,
        member: grandmotherNgoai,
        membersById: membersById,
      ),
      'Bà ngoại',
    );
  });

  test('infers con dau/con re when in-law gender is missing', () {
    final l10n = AppLocalizationsVi();
    final viewer = member(
      id: 'viewer',
      generation: 5,
      gender: 'male',
      childrenIds: const ['son', 'daughter'],
    );
    final son = member(
      id: 'son',
      generation: 6,
      gender: 'male',
      parentIds: const ['viewer'],
      spouseIds: const ['in_law_unknown_1'],
    );
    final daughter = member(
      id: 'daughter',
      generation: 6,
      gender: 'female',
      parentIds: const ['viewer'],
      spouseIds: const ['in_law_unknown_2'],
    );
    final inLawUnknown1 = member(
      id: 'in_law_unknown_1',
      generation: 6,
      spouseIds: const ['son'],
    );
    final inLawUnknown2 = member(
      id: 'in_law_unknown_2',
      generation: 6,
      spouseIds: const ['daughter'],
    );
    final membersById = directory([
      viewer,
      son,
      daughter,
      inLawUnknown1,
      inLawUnknown2,
    ]);

    expect(
      KinshipTitleResolver.resolve(
        l10n: l10n,
        viewer: viewer,
        member: inLawUnknown1,
        membersById: membersById,
      ),
      'Con dâu',
    );
    expect(
      KinshipTitleResolver.resolve(
        l10n: l10n,
        viewer: viewer,
        member: inLawUnknown2,
        membersById: membersById,
      ),
      'Con rể',
    );
  });
}
