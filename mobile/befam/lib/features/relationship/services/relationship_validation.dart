import '../models/relationship_record.dart';

enum RelationshipValidationErrorCode {
  sameMember,
  duplicateSpouse,
  duplicateParentChild,
  parentChildCycle,
}

class RelationshipValidationException implements Exception {
  const RelationshipValidationException(this.code, [this.message]);

  final RelationshipValidationErrorCode code;
  final String? message;

  @override
  String toString() => message ?? code.name;
}

void validateSpouseRelationship({
  required String memberId,
  required String spouseId,
  required Iterable<RelationshipRecord> relationships,
}) {
  if (memberId == spouseId) {
    throw const RelationshipValidationException(
      RelationshipValidationErrorCode.sameMember,
    );
  }

  final duplicate = relationships.any(
    (relationship) =>
        relationship.isActive &&
        relationship.type == RelationshipType.spouse &&
        _sameUnorderedPair(
          relationship.personAId,
          relationship.personBId,
          memberId,
          spouseId,
        ),
  );
  if (duplicate) {
    throw const RelationshipValidationException(
      RelationshipValidationErrorCode.duplicateSpouse,
    );
  }
}

void validateParentChildRelationship({
  required String parentId,
  required String childId,
  required Iterable<RelationshipRecord> relationships,
}) {
  if (parentId == childId) {
    throw const RelationshipValidationException(
      RelationshipValidationErrorCode.sameMember,
    );
  }

  final activeParentChild = relationships
      .where(
        (relationship) =>
            relationship.isActive &&
            relationship.type == RelationshipType.parentChild,
      )
      .toList(growable: false);

  final duplicate = activeParentChild.any(
    (relationship) =>
        relationship.personAId == parentId && relationship.personBId == childId,
  );
  if (duplicate) {
    throw const RelationshipValidationException(
      RelationshipValidationErrorCode.duplicateParentChild,
    );
  }

  final childMap = <String, Set<String>>{};
  for (final relationship in activeParentChild) {
    childMap
        .putIfAbsent(relationship.personAId, () => <String>{})
        .add(relationship.personBId);
  }

  final frontier = <String>[childId];
  final visited = <String>{childId};
  while (frontier.isNotEmpty) {
    final current = frontier.removeLast();
    if (current == parentId) {
      throw const RelationshipValidationException(
        RelationshipValidationErrorCode.parentChildCycle,
      );
    }

    for (final nextChild in childMap[current] ?? const <String>{}) {
      if (visited.add(nextChild)) {
        frontier.add(nextChild);
      }
    }
  }
}

bool _sameUnorderedPair(
  String leftA,
  String leftB,
  String rightA,
  String rightB,
) {
  return (leftA == rightA && leftB == rightB) ||
      (leftA == rightB && leftB == rightA);
}
