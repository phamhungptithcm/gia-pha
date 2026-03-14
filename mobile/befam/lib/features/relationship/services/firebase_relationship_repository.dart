import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:collection/collection.dart';

import '../../../core/services/firebase_services.dart';
import '../../auth/models/auth_session.dart';
import '../models/relationship_record.dart';
import 'relationship_repository.dart';

class FirebaseRelationshipRepository implements RelationshipRepository {
  FirebaseRelationshipRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) : _firestore = firestore ?? FirebaseServices.firestore,
       _functions = functions ?? FirebaseServices.functions;

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  CollectionReference<Map<String, dynamic>> get _relationships =>
      _firestore.collection('relationships');

  @override
  bool get isSandbox => false;

  @override
  Future<List<RelationshipRecord>> loadRelationshipsForMember({
    required AuthSession session,
    required String memberId,
  }) async {
    final clanId = session.clanId;
    if (clanId == null || clanId.isEmpty) {
      return const [];
    }

    final results = await Future.wait([
      _relationships
          .where('clanId', isEqualTo: clanId)
          .where('personA', isEqualTo: memberId)
          .get(),
      _relationships
          .where('clanId', isEqualTo: clanId)
          .where('personB', isEqualTo: memberId)
          .get(),
    ]);

    final records = <String, RelationshipRecord>{};
    for (final result in results) {
      for (final doc in result.docs) {
        records[doc.id] = RelationshipRecord.fromJson(doc.data());
      }
    }

    return records.values
        .where((relationship) => relationship.isActive)
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
    final callable = _functions.httpsCallable('createParentChildRelationship');
    try {
      final result = await callable.call(<String, dynamic>{
        'parentId': parentId,
        'childId': childId,
      });
      final payload = (result.data as Map).map(
        (key, value) => MapEntry(key.toString(), value),
      );
      return RelationshipRecord.fromJson(payload);
    } on FirebaseFunctionsException catch (error) {
      throw _mapFunctionsError(error);
    }
  }

  @override
  Future<RelationshipRecord> createSpouseRelationship({
    required AuthSession session,
    required String memberId,
    required String spouseId,
  }) async {
    final callable = _functions.httpsCallable('createSpouseRelationship');
    try {
      final result = await callable.call(<String, dynamic>{
        'memberId': memberId,
        'spouseId': spouseId,
      });
      final payload = (result.data as Map).map(
        (key, value) => MapEntry(key.toString(), value),
      );
      return RelationshipRecord.fromJson(payload);
    } on FirebaseFunctionsException catch (error) {
      throw _mapFunctionsError(error);
    }
  }
}

RelationshipRepositoryException _mapFunctionsError(
  FirebaseFunctionsException error,
) {
  final message = error.message?.toLowerCase() ?? '';

  if (error.code == 'already-exists') {
    if (message.contains('spouse')) {
      return const RelationshipRepositoryException(
        RelationshipRepositoryErrorCode.duplicateSpouse,
      );
    }
    return const RelationshipRepositoryException(
      RelationshipRepositoryErrorCode.duplicateParentChild,
    );
  }

  if (error.code == 'failed-precondition') {
    return const RelationshipRepositoryException(
      RelationshipRepositoryErrorCode.cycleDetected,
    );
  }

  if (error.code == 'permission-denied') {
    return const RelationshipRepositoryException(
      RelationshipRepositoryErrorCode.permissionDenied,
    );
  }

  if (error.code == 'not-found') {
    return const RelationshipRepositoryException(
      RelationshipRepositoryErrorCode.memberNotFound,
    );
  }

  if (message.contains('same member')) {
    return const RelationshipRepositoryException(
      RelationshipRepositoryErrorCode.sameMember,
    );
  }

  return RelationshipRepositoryException(
    RelationshipRepositoryErrorCode.permissionDenied,
    error.message,
  );
}
