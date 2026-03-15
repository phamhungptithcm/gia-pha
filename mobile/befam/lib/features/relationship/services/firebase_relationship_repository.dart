import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:collection/collection.dart';

import '../../../core/services/firebase_session_access_sync.dart';
import '../../../core/services/firebase_services.dart';
import '../../../core/services/governance_role_matrix.dart';
import '../../auth/models/auth_session.dart';
import '../models/relationship_record.dart';
import 'relationship_repository.dart';
import 'relationship_validation.dart';

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

  CollectionReference<Map<String, dynamic>> get _members =>
      _firestore.collection('members');

  @override
  bool get isSandbox => false;

  @override
  Future<List<RelationshipRecord>> loadRelationshipsForMember({
    required AuthSession session,
    required String memberId,
  }) async {
    await FirebaseSessionAccessSync.ensureUserSessionDocument(
      firestore: _firestore,
      session: session,
    );

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
    await FirebaseSessionAccessSync.ensureUserSessionDocument(
      firestore: _firestore,
      session: session,
    );

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
      if (_shouldFallbackToFirestore(error.code)) {
        return _createParentChildRelationshipWithFirestore(
          session: session,
          parentId: parentId,
          childId: childId,
        );
      }
      throw _mapFunctionsError(error);
    }
  }

  @override
  Future<RelationshipRecord> createSpouseRelationship({
    required AuthSession session,
    required String memberId,
    required String spouseId,
  }) async {
    await FirebaseSessionAccessSync.ensureUserSessionDocument(
      firestore: _firestore,
      session: session,
    );

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
      if (_shouldFallbackToFirestore(error.code)) {
        return _createSpouseRelationshipWithFirestore(
          session: session,
          memberId: memberId,
          spouseId: spouseId,
        );
      }
      throw _mapFunctionsError(error);
    }
  }

  Future<RelationshipRecord> _createParentChildRelationshipWithFirestore({
    required AuthSession session,
    required String parentId,
    required String childId,
  }) async {
    final normalizedParentId = parentId.trim();
    final normalizedChildId = childId.trim();
    if (normalizedParentId.isEmpty || normalizedChildId.isEmpty) {
      throw const RelationshipRepositoryException(
        RelationshipRepositoryErrorCode.memberNotFound,
      );
    }
    if (normalizedParentId == normalizedChildId) {
      throw const RelationshipRepositoryException(
        RelationshipRepositoryErrorCode.sameMember,
      );
    }

    final clanId = session.clanId?.trim();
    if (clanId == null || clanId.isEmpty) {
      throw const RelationshipRepositoryException(
        RelationshipRepositoryErrorCode.permissionDenied,
      );
    }

    final members = await Future.wait([
      _members.doc(normalizedParentId).get(),
      _members.doc(normalizedChildId).get(),
    ]);
    final parentSnapshot = members[0];
    final childSnapshot = members[1];
    final parentData = parentSnapshot.data();
    final childData = childSnapshot.data();
    if (parentData == null || childData == null) {
      throw const RelationshipRepositoryException(
        RelationshipRepositoryErrorCode.memberNotFound,
      );
    }

    final parentClanId = (parentData['clanId'] as String?)?.trim() ?? '';
    final childClanId = (childData['clanId'] as String?)?.trim() ?? '';
    if (parentClanId != clanId || childClanId != clanId) {
      throw const RelationshipRepositoryException(
        RelationshipRepositoryErrorCode.memberNotFound,
      );
    }

    _ensureSensitiveEditPermission(
      session: session,
      firstBranchId: (parentData['branchId'] as String?)?.trim(),
      secondBranchId: (childData['branchId'] as String?)?.trim(),
    );

    final activeParentChildSnapshot = await _relationships
        .where('clanId', isEqualTo: clanId)
        .where('type', isEqualTo: RelationshipType.parentChild.wireName)
        .where('status', isEqualTo: 'active')
        .get();
    final activeParentChild = activeParentChildSnapshot.docs
        .map((doc) => RelationshipRecord.fromJson(doc.data()))
        .toList(growable: false);

    try {
      validateParentChildRelationship(
        parentId: normalizedParentId,
        childId: normalizedChildId,
        relationships: activeParentChild,
      );
    } on RelationshipValidationException catch (error) {
      throw _mapValidationError(error);
    }

    final relationshipId = _parentChildRelationshipId(
      normalizedParentId,
      normalizedChildId,
    );
    final actor = session.memberId ?? session.uid;
    await _firestore.runTransaction((transaction) async {
      final relationshipRef = _relationships.doc(relationshipId);
      final existingRelationship = await transaction.get(relationshipRef);
      final existingData = existingRelationship.data();
      if (existingData != null &&
          RelationshipRecord.fromJson(existingData).isActive) {
        throw const RelationshipRepositoryException(
          RelationshipRepositoryErrorCode.duplicateParentChild,
        );
      }

      final transactionalParent = await transaction.get(
        _members.doc(normalizedParentId),
      );
      final transactionalChild = await transaction.get(
        _members.doc(normalizedChildId),
      );
      if (!transactionalParent.exists || !transactionalChild.exists) {
        throw const RelationshipRepositoryException(
          RelationshipRepositoryErrorCode.memberNotFound,
        );
      }

      final nextParentChildren = _stringSetFromDynamic(
        transactionalParent.data()?['childrenIds'],
      )..add(normalizedChildId);
      final nextChildParents = _stringSetFromDynamic(
        transactionalChild.data()?['parentIds'],
      )..add(normalizedParentId);

      transaction.set(relationshipRef, {
        'id': relationshipId,
        'clanId': clanId,
        'personA': normalizedParentId,
        'personB': normalizedChildId,
        'type': RelationshipType.parentChild.wireName,
        'direction': RelationshipDirection.aToB.wireName,
        'status': 'active',
        'source': 'manual',
        'createdBy': actor,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': actor,
      }, SetOptions(merge: true));

      transaction.set(_members.doc(normalizedParentId), {
        'childrenIds': nextParentChildren.toList(growable: false),
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': actor,
      }, SetOptions(merge: true));
      transaction.set(_members.doc(normalizedChildId), {
        'parentIds': nextChildParents.toList(growable: false),
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': actor,
      }, SetOptions(merge: true));
    });

    final now = DateTime.now();
    return RelationshipRecord(
      id: relationshipId,
      clanId: clanId,
      personAId: normalizedParentId,
      personBId: normalizedChildId,
      type: RelationshipType.parentChild,
      direction: RelationshipDirection.aToB,
      status: 'active',
      source: 'manual',
      createdBy: actor,
      createdAt: now,
      updatedAt: now,
    );
  }

  Future<RelationshipRecord> _createSpouseRelationshipWithFirestore({
    required AuthSession session,
    required String memberId,
    required String spouseId,
  }) async {
    final normalizedMemberId = memberId.trim();
    final normalizedSpouseId = spouseId.trim();
    if (normalizedMemberId.isEmpty || normalizedSpouseId.isEmpty) {
      throw const RelationshipRepositoryException(
        RelationshipRepositoryErrorCode.memberNotFound,
      );
    }
    if (normalizedMemberId == normalizedSpouseId) {
      throw const RelationshipRepositoryException(
        RelationshipRepositoryErrorCode.sameMember,
      );
    }

    final clanId = session.clanId?.trim();
    if (clanId == null || clanId.isEmpty) {
      throw const RelationshipRepositoryException(
        RelationshipRepositoryErrorCode.permissionDenied,
      );
    }

    final members = await Future.wait([
      _members.doc(normalizedMemberId).get(),
      _members.doc(normalizedSpouseId).get(),
    ]);
    final firstSnapshot = members[0];
    final secondSnapshot = members[1];
    final firstData = firstSnapshot.data();
    final secondData = secondSnapshot.data();
    if (firstData == null || secondData == null) {
      throw const RelationshipRepositoryException(
        RelationshipRepositoryErrorCode.memberNotFound,
      );
    }

    final firstClanId = (firstData['clanId'] as String?)?.trim() ?? '';
    final secondClanId = (secondData['clanId'] as String?)?.trim() ?? '';
    if (firstClanId != clanId || secondClanId != clanId) {
      throw const RelationshipRepositoryException(
        RelationshipRepositoryErrorCode.memberNotFound,
      );
    }

    _ensureSensitiveEditPermission(
      session: session,
      firstBranchId: (firstData['branchId'] as String?)?.trim(),
      secondBranchId: (secondData['branchId'] as String?)?.trim(),
    );

    final activeRelationshipsSnapshot = await _relationships
        .where('clanId', isEqualTo: clanId)
        .where('status', isEqualTo: 'active')
        .get();
    final activeRelationships = activeRelationshipsSnapshot.docs
        .map((doc) => RelationshipRecord.fromJson(doc.data()))
        .toList(growable: false);
    try {
      validateSpouseRelationship(
        memberId: normalizedMemberId,
        spouseId: normalizedSpouseId,
        relationships: activeRelationships,
      );
    } on RelationshipValidationException catch (error) {
      throw _mapValidationError(error);
    }

    final normalizedPair = [normalizedMemberId, normalizedSpouseId]..sort();
    final relationshipId = _spouseRelationshipId(
      normalizedPair.first,
      normalizedPair.last,
    );
    final actor = session.memberId ?? session.uid;
    await _firestore.runTransaction((transaction) async {
      final relationshipRef = _relationships.doc(relationshipId);
      final existingRelationship = await transaction.get(relationshipRef);
      final existingData = existingRelationship.data();
      if (existingData != null &&
          RelationshipRecord.fromJson(existingData).isActive) {
        throw const RelationshipRepositoryException(
          RelationshipRepositoryErrorCode.duplicateSpouse,
        );
      }

      final transactionalFirst = await transaction.get(
        _members.doc(normalizedMemberId),
      );
      final transactionalSecond = await transaction.get(
        _members.doc(normalizedSpouseId),
      );
      if (!transactionalFirst.exists || !transactionalSecond.exists) {
        throw const RelationshipRepositoryException(
          RelationshipRepositoryErrorCode.memberNotFound,
        );
      }

      final firstSpouses = _stringSetFromDynamic(
        transactionalFirst.data()?['spouseIds'],
      )..add(normalizedSpouseId);
      final secondSpouses = _stringSetFromDynamic(
        transactionalSecond.data()?['spouseIds'],
      )..add(normalizedMemberId);

      transaction.set(relationshipRef, {
        'id': relationshipId,
        'clanId': clanId,
        'personA': normalizedPair.first,
        'personB': normalizedPair.last,
        'type': RelationshipType.spouse.wireName,
        'direction': RelationshipDirection.undirected.wireName,
        'status': 'active',
        'source': 'manual',
        'createdBy': actor,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': actor,
      }, SetOptions(merge: true));

      transaction.set(_members.doc(normalizedMemberId), {
        'spouseIds': firstSpouses.toList(growable: false),
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': actor,
      }, SetOptions(merge: true));
      transaction.set(_members.doc(normalizedSpouseId), {
        'spouseIds': secondSpouses.toList(growable: false),
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': actor,
      }, SetOptions(merge: true));
    });

    final now = DateTime.now();
    return RelationshipRecord(
      id: relationshipId,
      clanId: clanId,
      personAId: normalizedPair.first,
      personBId: normalizedPair.last,
      type: RelationshipType.spouse,
      direction: RelationshipDirection.undirected,
      status: 'active',
      source: 'manual',
      createdBy: actor,
      createdAt: now,
      updatedAt: now,
    );
  }

  void _ensureSensitiveEditPermission({
    required AuthSession session,
    required String? firstBranchId,
    required String? secondBranchId,
  }) {
    final role = GovernanceRoleMatrix.normalizeRole(session.primaryRole);
    if (role == GovernanceRoles.superAdmin ||
        role == GovernanceRoles.clanAdmin ||
        role == GovernanceRoles.adminSupport) {
      return;
    }

    if (role == GovernanceRoles.branchAdmin) {
      final sessionBranchId = session.branchId?.trim() ?? '';
      if (sessionBranchId.isNotEmpty &&
          firstBranchId == sessionBranchId &&
          secondBranchId == sessionBranchId) {
        return;
      }
    }

    throw const RelationshipRepositoryException(
      RelationshipRepositoryErrorCode.permissionDenied,
    );
  }
}

bool _shouldFallbackToFirestore(String code) {
  return code == 'not-found' ||
      code == 'unimplemented' ||
      code == 'unavailable';
}

Set<String> _stringSetFromDynamic(dynamic value) {
  if (value is! List) {
    return <String>{};
  }
  return value
      .whereType<String>()
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toSet();
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
