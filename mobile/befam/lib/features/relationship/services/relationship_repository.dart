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
  return FirebaseRelationshipRepository();
}
