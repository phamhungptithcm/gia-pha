import 'package:befam/features/relationship/models/relationship_record.dart';
import 'package:befam/features/relationship/services/relationship_validation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const existingParentChild = RelationshipRecord(
    id: 'rel_parent_child_parent_child',
    clanId: 'clan_demo_001',
    personAId: 'member_parent',
    personBId: 'member_child',
    type: RelationshipType.parentChild,
    direction: RelationshipDirection.aToB,
    status: 'active',
    source: 'manual',
  );

  const existingSpouse = RelationshipRecord(
    id: 'rel_spouse_pair',
    clanId: 'clan_demo_001',
    personAId: 'member_a',
    personBId: 'member_b',
    type: RelationshipType.spouse,
    direction: RelationshipDirection.undirected,
    status: 'active',
    source: 'manual',
  );

  test('rejects duplicate spouse links for the same pair', () {
    expect(
      () => validateSpouseRelationship(
        memberId: 'member_b',
        spouseId: 'member_a',
        relationships: const [existingSpouse],
      ),
      throwsA(
        isA<RelationshipValidationException>().having(
          (error) => error.code,
          'code',
          RelationshipValidationErrorCode.duplicateSpouse,
        ),
      ),
    );
  });

  test('rejects duplicate parent-child links', () {
    expect(
      () => validateParentChildRelationship(
        parentId: 'member_parent',
        childId: 'member_child',
        relationships: const [existingParentChild],
      ),
      throwsA(
        isA<RelationshipValidationException>().having(
          (error) => error.code,
          'code',
          RelationshipValidationErrorCode.duplicateParentChild,
        ),
      ),
    );
  });

  test('rejects parent-child links that create cycles', () {
    const relationships = [
      RelationshipRecord(
        id: 'rel_1',
        clanId: 'clan_demo_001',
        personAId: 'member_root',
        personBId: 'member_parent',
        type: RelationshipType.parentChild,
        direction: RelationshipDirection.aToB,
        status: 'active',
        source: 'manual',
      ),
      RelationshipRecord(
        id: 'rel_2',
        clanId: 'clan_demo_001',
        personAId: 'member_parent',
        personBId: 'member_child',
        type: RelationshipType.parentChild,
        direction: RelationshipDirection.aToB,
        status: 'active',
        source: 'manual',
      ),
    ];

    expect(
      () => validateParentChildRelationship(
        parentId: 'member_child',
        childId: 'member_root',
        relationships: relationships,
      ),
      throwsA(
        isA<RelationshipValidationException>().having(
          (error) => error.code,
          'code',
          RelationshipValidationErrorCode.parentChildCycle,
        ),
      ),
    );
  });

  test('rejects same-member relationships', () {
    expect(
      () => validateSpouseRelationship(
        memberId: 'member_x',
        spouseId: 'member_x',
        relationships: const [],
      ),
      throwsA(
        isA<RelationshipValidationException>().having(
          (error) => error.code,
          'code',
          RelationshipValidationErrorCode.sameMember,
        ),
      ),
    );
  });
}
