import 'package:firebase_core/firebase_core.dart';

import '../../auth/models/auth_session.dart';
import '../models/relationship_record.dart';
import 'firebase_relationship_repository.dart';

enum RelationshipRepositoryErrorCode {
  duplicateSpouse,
  duplicateParentChild,
  cycleDetected,
  permissionDenied,
  memberNotFound,
  sameMember,
}

class RelationshipRepositoryException implements Exception {
  const RelationshipRepositoryException(this.code, [this.message]);

  final RelationshipRepositoryErrorCode code;
  final String? message;

  @override
  String toString() => message ?? code.name;
}

abstract interface class RelationshipRepository {
  bool get isSandbox;

  Future<List<RelationshipRecord>> loadRelationshipsForMember({
    required AuthSession session,
    required String memberId,
  });

  Future<RelationshipRecord> createParentChildRelationship({
    required AuthSession session,
    required String parentId,
    required String childId,
  });

  Future<RelationshipRecord> createSpouseRelationship({
    required AuthSession session,
    required String memberId,
    required String spouseId,
  });
}

RelationshipRepository createDefaultRelationshipRepository({
  AuthSession? session,
}) {
  if (Firebase.apps.isEmpty) {
    return const _UnavailableRelationshipRepository();
  }
  return FirebaseRelationshipRepository();
}

class _UnavailableRelationshipRepository implements RelationshipRepository {
  const _UnavailableRelationshipRepository();

  static const RelationshipRepositoryException
  _unavailableError = RelationshipRepositoryException(
    RelationshipRepositoryErrorCode.permissionDenied,
    'Relationship repository is unavailable before Firebase is initialized.',
  );

  @override
  bool get isSandbox => true;

  @override
  Future<RelationshipRecord> createParentChildRelationship({
    required AuthSession session,
    required String parentId,
    required String childId,
  }) {
    throw _unavailableError;
  }

  @override
  Future<RelationshipRecord> createSpouseRelationship({
    required AuthSession session,
    required String memberId,
    required String spouseId,
  }) {
    throw _unavailableError;
  }

  @override
  Future<List<RelationshipRecord>> loadRelationshipsForMember({
    required AuthSession session,
    required String memberId,
  }) async {
    return const <RelationshipRecord>[];
  }
}
