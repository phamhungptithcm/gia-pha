import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:collection/collection.dart';

import '../../../core/services/app_environment.dart';
import '../../../core/services/firebase_session_access_sync.dart';
import '../../../core/services/firebase_services.dart';
import '../../auth/models/auth_session.dart';
import '../../auth/services/phone_number_formatter.dart';
import '../../clan/models/branch_profile.dart';
import '../models/member_draft.dart';
import '../models/member_profile.dart';
import '../models/member_workspace_snapshot.dart';
import 'member_repository.dart';

class FirebaseMemberRepository implements MemberRepository {
  FirebaseMemberRepository({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    FirebaseFunctions? functions,
  }) : _firestore = firestore ?? FirebaseServices.firestore,
       _storage = storage ?? FirebaseServices.storage,
       _functions =
           functions ??
           FirebaseFunctions.instanceFor(
             region: AppEnvironment.firebaseFunctionsRegion,
           );

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final FirebaseFunctions _functions;

  CollectionReference<Map<String, dynamic>> get _members =>
      _firestore.collection('members');

  CollectionReference<Map<String, dynamic>> get _branches =>
      _firestore.collection('branches');

  @override
  bool get isSandbox => false;

  @override
  Future<MemberWorkspaceSnapshot> loadWorkspace({
    required AuthSession session,
  }) async {
    await FirebaseSessionAccessSync.ensureUserSessionDocument(
      firestore: _firestore,
      session: session,
    );

    final clanId = session.clanId;
    if (clanId == null || clanId.isEmpty) {
      return const MemberWorkspaceSnapshot(members: [], branches: []);
    }

    final results =
        await Future.wait<List<QueryDocumentSnapshot<Map<String, dynamic>>>>([
          _fetchPagedDocuments(_members.where('clanId', isEqualTo: clanId)),
          _fetchPagedDocuments(_branches.where('clanId', isEqualTo: clanId)),
        ]);

    final members = results[0]
        .map((doc) => MemberProfile.fromJson(doc.data()))
        .sortedBy((member) => member.fullName.toLowerCase())
        .toList(growable: false);
    final branches = results[1]
        .map((doc) => BranchProfile.fromJson(doc.data()))
        .sortedBy((branch) => branch.name.toLowerCase())
        .toList(growable: false);

    return MemberWorkspaceSnapshot(members: members, branches: branches);
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  _fetchPagedDocuments(
    Query<Map<String, dynamic>> baseQuery, {
    int pageSize = 200,
    int maxDocuments = 1500,
  }) async {
    final docs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    QueryDocumentSnapshot<Map<String, dynamic>>? cursor;
    while (docs.length < maxDocuments) {
      final query = cursor == null
          ? baseQuery.limit(pageSize)
          : baseQuery.limit(pageSize).startAfterDocument(cursor);
      final snapshot = await query.get();
      if (snapshot.docs.isEmpty) {
        break;
      }
      docs.addAll(snapshot.docs);
      if (snapshot.docs.length < pageSize) {
        break;
      }
      cursor = snapshot.docs.last;
    }
    if (docs.length > maxDocuments) {
      return docs.take(maxDocuments).toList(growable: false);
    }
    return docs;
  }

  @override
  Future<MemberProfile> saveMember({
    required AuthSession session,
    String? memberId,
    required MemberDraft draft,
  }) async {
    await FirebaseSessionAccessSync.ensureUserSessionDocument(
      firestore: _firestore,
      session: session,
    );

    final clanId = session.clanId;
    if (clanId == null || clanId.isEmpty) {
      throw const MemberRepositoryException(
        MemberRepositoryErrorCode.permissionDenied,
      );
    }

    final normalizedPhone = _normalizePhoneOrNull(draft.phoneInput);
    if (memberId == null) {
      return _createMemberViaCallable(
        session: session,
        clanId: clanId,
        draft: draft,
        normalizedPhone: normalizedPhone,
      );
    }

    await _ensureUniquePhone(
      clanId: clanId,
      phoneE164: normalizedPhone,
      memberId: memberId,
    );

    final memberRef = _members.doc(memberId);
    final existing = await memberRef.get();
    if (!existing.exists || existing.data() == null) {
      throw const MemberRepositoryException(
        MemberRepositoryErrorCode.memberNotFound,
      );
    }
    final existingData = existing.data()!;
    final existingClanId = (existingData['clanId'] as String?)?.trim() ?? '';
    if (existingClanId != clanId) {
      throw const MemberRepositoryException(
        MemberRepositoryErrorCode.permissionDenied,
      );
    }
    final actor = session.memberId ?? session.uid;
    final previousBranchId = existingData['branchId'] as String?;
    final previousParentIds = _stringList(existingData['parentIds']);
    var resolvedParentIds = _normalizeParentIds(
      draft.parentIds,
    ).where((id) => id != memberRef.id).toList(growable: false);
    var branchId = draft.branchId ?? existingData['branchId'] as String?;
    var generation = draft.generation;

    if (resolvedParentIds.isNotEmpty) {
      final primaryParentSnapshot = await _members
          .doc(resolvedParentIds.first)
          .get();
      final primaryParentData = primaryParentSnapshot.data();
      if (!primaryParentSnapshot.exists ||
          primaryParentData == null ||
          primaryParentData['clanId'] != clanId) {
        throw const MemberRepositoryException(
          MemberRepositoryErrorCode.permissionDenied,
        );
      }
      final derivedBranchId = (primaryParentData['branchId'] as String?)
          ?.trim();
      if (derivedBranchId == null || derivedBranchId.isEmpty) {
        throw const MemberRepositoryException(
          MemberRepositoryErrorCode.permissionDenied,
        );
      }
      branchId = derivedBranchId;
      generation =
          _asPositiveInt(primaryParentData['generation'], fallback: 1) + 1;
    }

    if (branchId == null || branchId.isEmpty || generation <= 0) {
      throw const MemberRepositoryException(
        MemberRepositoryErrorCode.permissionDenied,
      );
    }

    final payload = {
      'id': memberRef.id,
      'clanId': clanId,
      'branchId': branchId,
      'householdId': existing.data()?['householdId'],
      'fullName': draft.fullName.trim(),
      'normalizedFullName': draft.fullName.trim().toLowerCase(),
      'nickName': draft.nickName.trim(),
      'gender': _nullableTrim(draft.gender),
      'birthDate': draft.birthDate,
      'deathDate': draft.deathDate,
      'phoneE164': normalizedPhone,
      'email': _nullableTrim(draft.email),
      'addressText': _nullableTrim(draft.addressText),
      'jobTitle': _nullableTrim(draft.jobTitle),
      'avatarUrl': existingData['avatarUrl'],
      'bio': _nullableTrim(draft.bio),
      'socialLinks': draft.socialLinks.toJson(),
      'parentIds': resolvedParentIds,
      'childrenIds': existingData['childrenIds'] ?? const <String>[],
      'spouseIds': existingData['spouseIds'] ?? const <String>[],
      'siblingOrder': resolvedParentIds.isEmpty
          ? null
          : existingData['siblingOrder'] ?? draft.siblingOrder,
      'generation': generation,
      'primaryRole': existingData['primaryRole'] ?? draft.primaryRole,
      'status': existingData['status'] ?? draft.status,
      'isMinor': draft.isMinor,
      'authUid': existingData['authUid'],
      'claimedAt': existingData['claimedAt'],
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': actor,
      if (!existing.exists) 'createdAt': FieldValue.serverTimestamp(),
      if (!existing.exists) 'createdBy': actor,
    };

    final isNew = !existing.exists;
    await memberRef.set(payload, SetOptions(merge: true));
    await _syncParentLinks(
      clanId: clanId,
      memberId: memberRef.id,
      previousParentIds: previousParentIds,
      nextParentIds: resolvedParentIds,
      actor: actor,
    );
    await _syncSiblingOrder(
      clanId: clanId,
      parentIds: {...previousParentIds, ...resolvedParentIds},
      actor: actor,
    );
    await _syncBranchCount(clanId, branchId, actor);
    if (previousBranchId != null &&
        previousBranchId.isNotEmpty &&
        previousBranchId != branchId) {
      await _syncBranchCount(clanId, previousBranchId, actor);
    }

    // Build the response without an extra read: substitute FieldValue sentinels
    // with local timestamps (within milliseconds of the server timestamp).
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final responsePayload = Map<String, dynamic>.from(payload)
      ..['updatedAt'] = nowIso
      ..['id'] = memberRef.id;
    if (isNew) responsePayload['createdAt'] = nowIso;
    return MemberProfile.fromJson(responsePayload);
  }

  Future<MemberProfile> _createMemberViaCallable({
    required AuthSession session,
    required String clanId,
    required MemberDraft draft,
    required String? normalizedPhone,
  }) async {
    final callable = _functions.httpsCallable('createClanMember');
    try {
      final response = await callable.call(<String, dynamic>{
        'clanId': clanId,
        'branchId': draft.branchId,
        'parentIds': draft.parentIds,
        'fullName': draft.fullName.trim(),
        'nickName': draft.nickName.trim(),
        'gender': _nullableTrim(draft.gender),
        'birthDate': _nullableTrim(draft.birthDate),
        'deathDate': _nullableTrim(draft.deathDate),
        'phoneE164': normalizedPhone,
        'email': _nullableTrim(draft.email),
        'addressText': _nullableTrim(draft.addressText),
        'jobTitle': _nullableTrim(draft.jobTitle),
        'bio': _nullableTrim(draft.bio),
        'siblingOrder': draft.siblingOrder,
        'generation': draft.generation,
        'socialLinks': draft.socialLinks.toJson(),
        'primaryRole': draft.primaryRole,
        'status': draft.status,
        'isMinor': draft.isMinor,
      });

      final data = response.data;
      if (data is Map) {
        final member = data['member'];
        if (member is Map) {
          return MemberProfile.fromJson(Map<String, dynamic>.from(member));
        }
      }
      throw const MemberRepositoryException(
        MemberRepositoryErrorCode.permissionDenied,
      );
    } on FirebaseFunctionsException catch (error) {
      if (error.code == 'already-exists') {
        throw const MemberRepositoryException(
          MemberRepositoryErrorCode.duplicatePhone,
        );
      }
      if (error.code == 'resource-exhausted') {
        throw MemberRepositoryException(
          MemberRepositoryErrorCode.planLimitExceeded,
          _resolvePlanLimitErrorMessage(error),
        );
      }
      if (error.code == 'permission-denied') {
        throw const MemberRepositoryException(
          MemberRepositoryErrorCode.permissionDenied,
        );
      }
      throw MemberRepositoryException(
        MemberRepositoryErrorCode.permissionDenied,
        error.message,
      );
    }
  }

  Future<void> _syncSiblingOrder({
    required String clanId,
    required Set<String> parentIds,
    required String actor,
  }) async {
    for (final parentId in parentIds) {
      if (parentId.trim().isEmpty) {
        continue;
      }
      final parentSnapshot = await _members.doc(parentId).get();
      final parentData = parentSnapshot.data();
      if (!parentSnapshot.exists ||
          parentData == null ||
          parentData['clanId'] != clanId) {
        continue;
      }

      final childIds = _stringList(parentData['childrenIds']);
      if (childIds.isEmpty) {
        continue;
      }

      final childSnapshots = await Future.wait(
        childIds.map((childId) => _members.doc(childId).get()),
      );
      final rankableChildren =
          childSnapshots
              .where((snapshot) => snapshot.exists && snapshot.data() != null)
              .map((snapshot) => _SiblingRankEntry.fromSnapshot(snapshot))
              .where((entry) => entry.clanId == clanId)
              .toList(growable: false)
            ..sort(_compareSiblingRankEntry);
      if (rankableChildren.isEmpty) {
        continue;
      }

      final batch = _firestore.batch();
      var hasWrites = false;
      for (var index = 0; index < rankableChildren.length; index++) {
        final entry = rankableChildren[index];
        final nextOrder = index + 1;
        if (entry.currentSiblingOrder == nextOrder) {
          continue;
        }
        hasWrites = true;
        batch.set(_members.doc(entry.memberId), {
          'siblingOrder': nextOrder,
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedBy': actor,
        }, SetOptions(merge: true));
      }
      if (hasWrites) {
        await batch.commit();
      }
    }
  }

  Future<void> _syncParentLinks({
    required String clanId,
    required String memberId,
    required List<String> previousParentIds,
    required List<String> nextParentIds,
    required String actor,
  }) async {
    final previous = previousParentIds.toSet();
    final next = nextParentIds.toSet();
    final parentsToAdd = next.difference(previous);
    final parentsToRemove = previous.difference(next);

    await Future.wait<void>([
      for (final parentId in parentsToAdd)
        _updateParentChildLink(
          clanId: clanId,
          parentId: parentId,
          memberId: memberId,
          addChild: true,
          actor: actor,
        ),
      for (final parentId in parentsToRemove)
        _updateParentChildLink(
          clanId: clanId,
          parentId: parentId,
          memberId: memberId,
          addChild: false,
          actor: actor,
        ),
    ]);
  }

  Future<void> _updateParentChildLink({
    required String clanId,
    required String parentId,
    required String memberId,
    required bool addChild,
    required String actor,
  }) async {
    final parentRef = _members.doc(parentId);
    final parentSnapshot = await parentRef.get();
    final data = parentSnapshot.data();
    if (!parentSnapshot.exists || data == null || data['clanId'] != clanId) {
      return;
    }

    await parentRef.set({
      'childrenIds': addChild
          ? FieldValue.arrayUnion([memberId])
          : FieldValue.arrayRemove([memberId]),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': actor,
    }, SetOptions(merge: true));
  }

  @override
  Future<MemberProfile> uploadAvatar({
    required AuthSession session,
    required String memberId,
    required Uint8List bytes,
    required String fileName,
    String contentType = 'image/jpeg',
  }) async {
    await FirebaseSessionAccessSync.ensureUserSessionDocument(
      firestore: _firestore,
      session: session,
    );

    final clanId = session.clanId;
    if (clanId == null || clanId.isEmpty) {
      throw const MemberRepositoryException(
        MemberRepositoryErrorCode.permissionDenied,
      );
    }

    final memberRef = _members.doc(memberId);
    final existing = await memberRef.get();
    if (!existing.exists || existing.data() == null) {
      throw const MemberRepositoryException(
        MemberRepositoryErrorCode.memberNotFound,
      );
    }
    final memberClanId = (existing.data()!['clanId'] as String?)?.trim() ?? '';
    if (memberClanId != clanId) {
      throw const MemberRepositoryException(
        MemberRepositoryErrorCode.permissionDenied,
      );
    }

    try {
      final storageRef = _storage.ref(
        'clans/$clanId/members/$memberId/avatar/${DateTime.now().millisecondsSinceEpoch}-$fileName',
      );
      final snapshot = await storageRef.putData(
        bytes,
        SettableMetadata(contentType: contentType),
      );
      final url = await snapshot.ref.getDownloadURL();
      final actor = session.memberId ?? session.uid;
      await memberRef.set({
        'avatarUrl': url,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': actor,
      }, SetOptions(merge: true));

      // Build response from the already-fetched doc — avoids an extra read.
      final responseData = Map<String, dynamic>.from(existing.data()!);
      responseData['avatarUrl'] = url;
      responseData['updatedAt'] = DateTime.now().toUtc().toIso8601String();
      responseData['updatedBy'] = actor;
      return MemberProfile.fromJson(responseData);
    } catch (error) {
      throw MemberRepositoryException(
        MemberRepositoryErrorCode.avatarUploadFailed,
        error.toString(),
      );
    }
  }

  @override
  Future<void> updateMemberLiveLocation({
    required AuthSession session,
    required String memberId,
    required bool sharingEnabled,
    double? latitude,
    double? longitude,
    double? accuracyMeters,
  }) async {
    await FirebaseSessionAccessSync.ensureUserSessionDocument(
      firestore: _firestore,
      session: session,
    );

    final clanId = (session.clanId ?? '').trim();
    final normalizedMemberId = memberId.trim();
    if (clanId.isEmpty || normalizedMemberId.isEmpty) {
      throw const MemberRepositoryException(
        MemberRepositoryErrorCode.permissionDenied,
      );
    }

    final hasValidCoordinates =
        latitude != null &&
        longitude != null &&
        _isValidLatitude(latitude) &&
        _isValidLongitude(longitude);
    final shouldShare = sharingEnabled && hasValidCoordinates;
    final normalizedAccuracy = accuracyMeters != null && accuracyMeters.isFinite
        ? accuracyMeters
        : null;
    final capturedAt = DateTime.now().toUtc().toIso8601String();
    final actor = session.memberId ?? session.uid;

    await _members.doc(normalizedMemberId).set({
      'locationSharingEnabled': shouldShare,
      'locationLatitude': shouldShare ? latitude : null,
      'locationLongitude': shouldShare ? longitude : null,
      'locationAccuracyMeters': shouldShare ? normalizedAccuracy : null,
      'locationUpdatedAt': shouldShare ? capturedAt : null,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': actor,
    }, SetOptions(merge: true));
  }

  Future<void> _ensureUniquePhone({
    required String clanId,
    required String? phoneE164,
    required String? memberId,
  }) async {
    if (phoneE164 == null) {
      return;
    }

    final variants = PhoneNumberFormatter.lookupVariants(phoneE164);
    for (final variant in variants) {
      final duplicates = await _members
          .where('clanId', isEqualTo: clanId)
          .where('phoneE164', isEqualTo: variant)
          .limit(3)
          .get();
      final conflict = duplicates.docs.firstWhereOrNull(
        (doc) => doc.id != memberId,
      );
      if (conflict != null) {
        throw const MemberRepositoryException(
          MemberRepositoryErrorCode.duplicatePhone,
        );
      }
    }

  }

  Future<void> _syncBranchCount(
    String clanId,
    String branchId,
    String actor,
  ) async {
    // COUNT aggregate: O(1) index read regardless of member count.
    final aggregate = await _members
        .where('clanId', isEqualTo: clanId)
        .where('branchId', isEqualTo: branchId)
        .count()
        .get();
    final count = aggregate.count ?? 0;
    await _branches.doc(branchId).set({
      'id': branchId,
      'clanId': clanId,
      'memberCount': count,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': actor,
    }, SetOptions(merge: true));
  }
}

String? _resolvePlanLimitErrorMessage(FirebaseFunctionsException error) {
  final direct = error.message?.trim();
  if (direct != null && direct.isNotEmpty) {
    return direct;
  }
  final details = error.details;
  if (details is Map) {
    final ownerDisplayName = details['ownerDisplayName'];
    final requiredPlanCode = details['requiredPlanCode'];
    final currentPlanCode = details['currentPlanCode'];
    final allowedMemberLimit = details['allowedMemberLimit'];
    final projectedOwnerMemberCount = details['projectedOwnerMemberCount'];
    final ownerLabel =
        ownerDisplayName is String && ownerDisplayName.trim().isNotEmpty
        ? ownerDisplayName.trim()
        : 'the clan owner';
    final requiredPlan =
        requiredPlanCode is String && requiredPlanCode.trim().isNotEmpty
        ? requiredPlanCode.trim().toUpperCase()
        : 'the required plan';
    final currentPlan =
        currentPlanCode is String && currentPlanCode.trim().isNotEmpty
        ? currentPlanCode.trim().toUpperCase()
        : 'the current plan';
    if (allowedMemberLimit is num && projectedOwnerMemberCount is num) {
      return 'Current owner plan $currentPlan allows up to '
          '${allowedMemberLimit.toInt()} members across owned clans. '
          'Projected total is ${projectedOwnerMemberCount.toInt()}. '
          'Contact $ownerLabel to upgrade to $requiredPlan.';
    }
    return 'This clan has reached member capacity for the current owner plan. '
        'Contact $ownerLabel to upgrade to $requiredPlan.';
  }
  return null;
}

String? _normalizePhoneOrNull(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) {
    return null;
  }

  return PhoneNumberFormatter.parse(trimmed).e164;
}

String? _nullableTrim(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

List<String> _normalizeParentIds(List<String> parentIds) {
  return parentIds
      .map((id) => id.trim())
      .where((id) => id.isNotEmpty)
      .toSet()
      .toList(growable: false);
}

List<String> _stringList(dynamic value) {
  if (value is! List) {
    return const [];
  }

  return value
      .whereType<String>()
      .map((entry) => entry.trim())
      .where((entry) => entry.isNotEmpty)
      .toSet()
      .toList(growable: false);
}

int _asPositiveInt(dynamic value, {required int fallback}) {
  if (value is int && value > 0) {
    return value;
  }
  return fallback;
}

int? _asPositiveIntOrNull(dynamic value) {
  if (value is int && value > 0) {
    return value;
  }
  return null;
}

bool _isValidLatitude(double value) {
  return value.isFinite && value >= -90 && value <= 90;
}

bool _isValidLongitude(double value) {
  return value.isFinite && value >= -180 && value <= 180;
}

DateTime? _tryParseIsoDate(String? value) {
  final trimmed = value?.trim() ?? '';
  if (trimmed.isEmpty) {
    return null;
  }
  return DateTime.tryParse(trimmed);
}

int _compareSiblingRankEntry(_SiblingRankEntry left, _SiblingRankEntry right) {
  final byBirthDate = _compareNullableDate(left.birthDate, right.birthDate);
  if (byBirthDate != 0) {
    return byBirthDate;
  }
  final byGeneration = left.generation.compareTo(right.generation);
  if (byGeneration != 0) {
    return byGeneration;
  }
  final byName = left.fullName.toLowerCase().compareTo(
    right.fullName.toLowerCase(),
  );
  if (byName != 0) {
    return byName;
  }
  return left.memberId.compareTo(right.memberId);
}

int _compareNullableDate(DateTime? left, DateTime? right) {
  if (left == null && right == null) {
    return 0;
  }
  if (left == null) {
    return 1;
  }
  if (right == null) {
    return -1;
  }
  return left.compareTo(right);
}

class _SiblingRankEntry {
  const _SiblingRankEntry({
    required this.memberId,
    required this.clanId,
    required this.fullName,
    required this.generation,
    required this.birthDate,
    required this.currentSiblingOrder,
  });

  final String memberId;
  final String clanId;
  final String fullName;
  final int generation;
  final DateTime? birthDate;
  final int? currentSiblingOrder;

  factory _SiblingRankEntry.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? const <String, dynamic>{};
    return _SiblingRankEntry(
      memberId: snapshot.id,
      clanId: (data['clanId'] as String?)?.trim() ?? '',
      fullName: (data['fullName'] as String?)?.trim() ?? snapshot.id,
      generation: _asPositiveInt(data['generation'], fallback: 1),
      birthDate: _tryParseIsoDate(data['birthDate'] as String?),
      currentSiblingOrder: _asPositiveIntOrNull(data['siblingOrder']),
    );
  }
}
