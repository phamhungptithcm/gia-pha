import 'dart:async';

import 'package:collection/collection.dart';

import '../../../core/services/debug_genealogy_store.dart';
import '../../auth/models/auth_session.dart';
import '../../member/models/member_profile.dart';
import '../models/relationship_record.dart';
import 'relationship_permissions.dart';
import 'relationship_repository.dart';
import 'relationship_validation.dart';

class DebugRelationshipRepository implements RelationshipRepository {
  DebugRelationshipRepository({required DebugGenealogyStore store})
    : _store = store;

  factory DebugRelationshipRepository.seeded() {
    return DebugRelationshipRepository(store: DebugGenealogyStore.seeded());
  }

  factory DebugRelationshipRepository.shared() {
    return DebugRelationshipRepository(
      store: DebugGenealogyStore.sharedSeeded(),
    );
  }

  final DebugGenealogyStore _store;

  @override
  bool get isSandbox => true;

  @override
  Future<List<RelationshipRecord>> loadRelationshipsForMember({
    required AuthSession session,
    required String memberId,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    final clanId = session.clanId;
    if (clanId == null || clanId.isEmpty) {
      return const [];
    }

    return _store.relationships.values
        .where(
          (relationship) =>
              relationship.clanId == clanId &&
              relationship.involves(memberId) &&
              relationship.isActive,
        )
        .sortedBy(
          (relationship) => '${relationship.type.wireName}-${relationship.id}',
        )
        .toList(growable: false);
  }

  @override
  Future<RelationshipRecord> createParentChildRelationship({
    required AuthSession session,
    required String parentId,
    required String childId,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 160));
    final pair = _loadValidatedMembers(parentId, childId);
    _ensurePermission(session, pair.$1, pair.$2);

    try {
      validateParentChildRelationship(
        parentId: parentId,
        childId: childId,
        relationships: _store.relationships.values.where(
          (relationship) => relationship.clanId == pair.$1.clanId,
        ),
      );
    } on RelationshipValidationException catch (error) {
      throw _mapValidationError(error);
    }

    final record = RelationshipRecord(
      id: _parentChildRelationshipId(parentId, childId),
      clanId: pair.$1.clanId,
      personAId: parentId,
      personBId: childId,
      type: RelationshipType.parentChild,
      direction: RelationshipDirection.aToB,
      status: 'active',
      source: 'manual',
      createdBy: session.memberId ?? session.uid,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _store.relationships[record.id] = record;
    _store.reconcileRelationshipFields(pair.$1.clanId);

    return record;
  }

  @override
  Future<RelationshipRecord> createSpouseRelationship({
    required AuthSession session,
    required String memberId,
    required String spouseId,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 160));
    final pair = _loadValidatedMembers(memberId, spouseId);
    _ensurePermission(session, pair.$1, pair.$2);

    try {
      validateSpouseRelationship(
        memberId: memberId,
        spouseId: spouseId,
        relationships: _store.relationships.values.where(
          (relationship) => relationship.clanId == pair.$1.clanId,
        ),
      );
    } on RelationshipValidationException catch (error) {
      throw _mapValidationError(error);
    }

    final normalizedPair = [memberId, spouseId]..sort();
    final record = RelationshipRecord(
      id: _spouseRelationshipId(normalizedPair.first, normalizedPair.last),
      clanId: pair.$1.clanId,
      personAId: normalizedPair.first,
      personBId: normalizedPair.last,
      type: RelationshipType.spouse,
      direction: RelationshipDirection.undirected,
      status: 'active',
      source: 'manual',
      createdBy: session.memberId ?? session.uid,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _store.relationships[record.id] = record;
    _store.reconcileRelationshipFields(pair.$1.clanId);

    return record;
  }

  (MemberProfile, MemberProfile) _loadValidatedMembers(
    String firstId,
    String secondId,
  ) {
    final first = _store.members[firstId];
    final second = _store.members[secondId];
    if (first == null || second == null || first.clanId != second.clanId) {
      throw const RelationshipRepositoryException(
        RelationshipRepositoryErrorCode.memberNotFound,
      );
    }

    return (first, second);
  }

  void _ensurePermission(
    AuthSession session,
    MemberProfile first,
    MemberProfile second,
  ) {
    final permissions = RelationshipPermissions.forSession(session);
    if (!permissions.canMutateBetween(first, second)) {
      throw const RelationshipRepositoryException(
        RelationshipRepositoryErrorCode.permissionDenied,
      );
    }
  }
}

RelationshipRepositoryException _mapValidationError(
  RelationshipValidationException error,
) {
  return switch (error.code) {
    RelationshipValidationErrorCode.sameMember =>
      const RelationshipRepositoryException(
        RelationshipRepositoryErrorCode.sameMember,
      ),
    RelationshipValidationErrorCode.duplicateSpouse =>
      const RelationshipRepositoryException(
        RelationshipRepositoryErrorCode.duplicateSpouse,
      ),
    RelationshipValidationErrorCode.duplicateParentChild =>
      const RelationshipRepositoryException(
        RelationshipRepositoryErrorCode.duplicateParentChild,
      ),
    RelationshipValidationErrorCode.parentChildCycle =>
      const RelationshipRepositoryException(
        RelationshipRepositoryErrorCode.cycleDetected,
      ),
  };
}

String _parentChildRelationshipId(String parentId, String childId) {
  return 'rel_parent_child_${parentId}_$childId';
}

String _spouseRelationshipId(String firstId, String secondId) {
  return 'rel_spouse_${firstId}_$secondId';
}
