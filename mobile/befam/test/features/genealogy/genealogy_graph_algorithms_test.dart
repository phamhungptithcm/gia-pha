import 'package:befam/features/genealogy/services/genealogy_graph_algorithms.dart';
import 'package:befam/features/member/models/member_profile.dart';
import 'package:befam/features/member/models/member_social_links.dart';
import 'package:befam/features/relationship/models/relationship_record.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  MemberProfile member({
    required String id,
    required String name,
    required int generation,
  }) {
    return MemberProfile(
      id: id,
      clanId: 'clan_demo_001',
      branchId: 'branch_demo_001',
      fullName: name,
      normalizedFullName: name.toLowerCase(),
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

  test('builds adjacency maps and traversal helpers from relationships', () {
    final members = [
      member(id: 'grandparent', name: 'Grand Parent', generation: 3),
      member(id: 'parent', name: 'Parent', generation: 4),
      member(id: 'spouse', name: 'Parent Spouse', generation: 4),
      member(id: 'child_a', name: 'Child A', generation: 5),
      member(id: 'child_b', name: 'Child B', generation: 5),
    ];
    final relationships = [
      const RelationshipRecord(
        id: 'rel_parent_child_grandparent_parent',
        clanId: 'clan_demo_001',
        personAId: 'grandparent',
        personBId: 'parent',
        type: RelationshipType.parentChild,
        direction: RelationshipDirection.aToB,
        status: 'active',
        source: 'manual',
      ),
      const RelationshipRecord(
        id: 'rel_parent_child_parent_child_a',
        clanId: 'clan_demo_001',
        personAId: 'parent',
        personBId: 'child_a',
        type: RelationshipType.parentChild,
        direction: RelationshipDirection.aToB,
        status: 'active',
        source: 'manual',
      ),
      const RelationshipRecord(
        id: 'rel_parent_child_parent_child_b',
        clanId: 'clan_demo_001',
        personAId: 'parent',
        personBId: 'child_b',
        type: RelationshipType.parentChild,
        direction: RelationshipDirection.aToB,
        status: 'active',
        source: 'manual',
      ),
      const RelationshipRecord(
        id: 'rel_spouse_parent_spouse',
        clanId: 'clan_demo_001',
        personAId: 'parent',
        personBId: 'spouse',
        type: RelationshipType.spouse,
        direction: RelationshipDirection.undirected,
        status: 'active',
        source: 'manual',
      ),
    ];

    final graph = GenealogyGraphAlgorithms.buildAdjacencyMap(
      members: members,
      relationships: relationships,
      focusMemberId: 'child_a',
    );

    expect(graph.parentsOf('child_a'), ['parent']);
    expect(graph.childrenOf('parent'), ['child_a', 'child_b']);
    expect(graph.spousesOf('parent'), ['spouse']);
    expect(graph.siblingsOf('child_a'), ['child_b']);

    expect(
      GenealogyGraphAlgorithms.buildAncestryPath(
        graph: graph,
        memberId: 'child_a',
      ),
      ['child_a', 'parent', 'grandparent'],
    );

    expect(
      GenealogyGraphAlgorithms.buildDescendantsTraversal(
        graph: graph,
        memberId: 'grandparent',
        maxDepth: 2,
      ),
      ['parent', 'child_a', 'child_b'],
    );

    expect(graph.generationLabels['child_a']?.absoluteGeneration, 5);
    expect(graph.generationLabels['child_a']?.relativeLevel, 0);
    expect(graph.generationLabels['parent']?.relativeLevel, -1);
    expect(graph.generationLabels['grandparent']?.relativeLevel, -2);
    expect(graph.generationLabels['child_b']?.relativeLevel, 0);
  });
}
