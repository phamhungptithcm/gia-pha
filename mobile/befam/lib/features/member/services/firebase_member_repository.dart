import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:collection/collection.dart';

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
    final clanId = session.clanId;
    if (clanId == null || clanId.isEmpty) {
      throw const MemberRepositoryException(
        MemberRepositoryErrorCode.permissionDenied,
      );
    }

    final normalizedPhone = _normalizePhoneOrNull(draft.phoneInput);
    await _ensureUniquePhone(normalizedPhone, memberId);

    final memberRef = memberId == null
        ? _members.doc()
        : _members.doc(memberId);
    final existing = await memberRef.get();
    final actor = session.memberId ?? session.uid;
    final previousBranchId = existing.data()?['branchId'] as String?;
    final branchId = draft.branchId ?? existing.data()?['branchId'] as String?;
    if (branchId == null || branchId.isEmpty) {
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
      'avatarUrl': existing.data()?['avatarUrl'],
      'bio': _nullableTrim(draft.bio),
      'socialLinks': draft.socialLinks.toJson(),
      'parentIds': existing.data()?['parentIds'] ?? const <String>[],
      'childrenIds': existing.data()?['childrenIds'] ?? const <String>[],
      'spouseIds': existing.data()?['spouseIds'] ?? const <String>[],
      'generation': draft.generation,
      'lineagePath': [clanId, branchId],
      'primaryRole': existing.data()?['primaryRole'] ?? draft.primaryRole,
      'status': existing.data()?['status'] ?? draft.status,
      'isMinor': draft.isMinor,
      'authUid': existing.data()?['authUid'],
      'claimedAt': existing.data()?['claimedAt'],
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': actor,
      if (!existing.exists) 'createdAt': FieldValue.serverTimestamp(),
      if (!existing.exists) 'createdBy': actor,
    };

    await memberRef.set(payload, SetOptions(merge: true));
    await _syncBranchCount(clanId, branchId, actor);
    if (previousBranchId != null &&
        previousBranchId.isNotEmpty &&
        previousBranchId != branchId) {
      await _syncBranchCount(clanId, previousBranchId, actor);
    }
    final updated = await memberRef.get();
    return MemberProfile.fromJson(updated.data()!);
  }

  @override
  Future<MemberProfile> uploadAvatar({
    required AuthSession session,
    required String memberId,
    required Uint8List bytes,
    required String fileName,
    String contentType = 'image/jpeg',
  }) async {
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

  Future<void> _ensureUniquePhone(String? phoneE164, String? memberId) async {
    if (phoneE164 == null) {
      return;
    }

    final duplicates = await _members
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
