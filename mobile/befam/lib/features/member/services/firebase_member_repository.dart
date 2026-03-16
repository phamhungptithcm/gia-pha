import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:collection/collection.dart';

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
  }) : _firestore = firestore ?? FirebaseServices.firestore,
       _storage = storage ?? FirebaseServices.storage;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

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

    final results = await Future.wait<QuerySnapshot<Map<String, dynamic>>>([
      _members.where('clanId', isEqualTo: clanId).get(),
      _branches.where('clanId', isEqualTo: clanId).get(),
    ]);

    final memberSnapshot = results[0];
    final branchSnapshot = results[1];

    final members = memberSnapshot.docs
        .map((doc) => MemberProfile.fromJson(doc.data()))
        .sortedBy((member) => member.fullName.toLowerCase())
        .toList(growable: false);
    final branches = branchSnapshot.docs
        .map((doc) => BranchProfile.fromJson(doc.data()))
        .sortedBy((branch) => branch.name.toLowerCase())
        .toList(growable: false);

    return MemberWorkspaceSnapshot(members: members, branches: branches);
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
    await _ensureUniquePhone(
      clanId: clanId,
      phoneE164: normalizedPhone,
      memberId: memberId,
    );

    final memberRef = memberId == null
        ? _members.doc()
        : _members.doc(memberId);
    final existing = await memberRef.get();
    final existingData = existing.data() ?? const <String, dynamic>{};
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
      'lineagePath': [clanId, branchId],
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
    final updated = await memberRef.get();
    return MemberProfile.fromJson(updated.data()!);
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

    try {
      final storageRef = _storage.ref(
        'clans/$clanId/members/$memberId/avatar/${DateTime.now().millisecondsSinceEpoch}-$fileName',
      );
      final snapshot = await storageRef.putData(
        bytes,
        SettableMetadata(contentType: contentType),
      );
      final url = await snapshot.ref.getDownloadURL();
      await memberRef.set({
        'avatarUrl': url,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': session.memberId ?? session.uid,
      }, SetOptions(merge: true));

      final updated = await memberRef.get();
      return MemberProfile.fromJson(updated.data()!);
    } catch (error) {
      throw MemberRepositoryException(
        MemberRepositoryErrorCode.avatarUploadFailed,
        error.toString(),
      );
    }
  }

  Future<void> _ensureUniquePhone({
    required String clanId,
    required String? phoneE164,
    required String? memberId,
  }) async {
    if (phoneE164 == null) {
      return;
    }

    final duplicates = await _members
        .where('clanId', isEqualTo: clanId)
        .where('phoneE164', isEqualTo: phoneE164)
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

  Future<void> _syncBranchCount(
    String clanId,
    String branchId,
    String actor,
  ) async {
    final count = (await _members.where('branchId', isEqualTo: branchId).get())
        .docs
        .length;
    await _branches.doc(branchId).set({
      'id': branchId,
      'clanId': clanId,
      'memberCount': count,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': actor,
    }, SetOptions(merge: true));
  }
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
