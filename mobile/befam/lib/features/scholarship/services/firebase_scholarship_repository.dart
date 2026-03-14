import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../../core/services/firebase_session_access_sync.dart';
import '../../../core/services/firebase_services.dart';
import '../../auth/models/auth_session.dart';
import '../models/achievement_submission.dart';
import '../models/achievement_submission_draft.dart';
import '../models/award_level.dart';
import '../models/award_level_draft.dart';
import '../models/scholarship_program.dart';
import '../models/scholarship_program_draft.dart';
import '../models/scholarship_workspace_snapshot.dart';
import 'scholarship_repository.dart';

class FirebaseScholarshipRepository implements ScholarshipRepository {
  FirebaseScholarshipRepository({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  }) : _firestore = firestore ?? FirebaseServices.firestore,
       _storage = storage ?? FirebaseServices.storage;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  CollectionReference<Map<String, dynamic>> get _programs =>
      _firestore.collection('scholarshipPrograms');

  CollectionReference<Map<String, dynamic>> get _awardLevels =>
      _firestore.collection('awardLevels');

  CollectionReference<Map<String, dynamic>> get _submissions =>
      _firestore.collection('achievementSubmissions');

  CollectionReference<Map<String, dynamic>> get _members =>
      _firestore.collection('members');

  @override
  bool get isSandbox => false;

  @override
  Future<ScholarshipWorkspaceSnapshot> loadWorkspace({
    required AuthSession session,
  }) async {
    await FirebaseSessionAccessSync.ensureUserSessionDocument(
      firestore: _firestore,
      session: session,
    );

    final clanId = session.clanId?.trim() ?? '';
    if (clanId.isEmpty) {
      return const ScholarshipWorkspaceSnapshot(
        programs: [],
        awardLevels: [],
        submissions: [],
        memberNamesById: {},
      );
    }

    final results = await Future.wait<QuerySnapshot<Map<String, dynamic>>>([
      _programs.where('clanId', isEqualTo: clanId).get(),
      _awardLevels.where('clanId', isEqualTo: clanId).get(),
      _submissions.where('clanId', isEqualTo: clanId).get(),
      _members.where('clanId', isEqualTo: clanId).get(),
    ]);

    final programs = results[0].docs
        .map((doc) => ScholarshipProgram.fromJson(doc.data()))
        .sorted(
          (left, right) => right.year.compareTo(left.year) != 0
              ? right.year.compareTo(left.year)
              : left.title.toLowerCase().compareTo(right.title.toLowerCase()),
        )
        .toList(growable: false);

    final awardLevels = results[1].docs
        .map((doc) => AwardLevel.fromJson(doc.data()))
        .sortedBy<num>((award) => award.sortOrder)
        .toList(growable: false);

    final submissions = results[2].docs
        .map((doc) => AchievementSubmission.fromJson(doc.data()))
        .sorted(
          (left, right) => right.updatedAtIso.compareTo(left.updatedAtIso) != 0
              ? right.updatedAtIso.compareTo(left.updatedAtIso)
              : left.title.toLowerCase().compareTo(right.title.toLowerCase()),
        )
        .toList(growable: false);

    final memberNamesById = <String, String>{
      for (final doc in results[3].docs)
        if ((doc.data()['id'] as String?)?.trim().isNotEmpty == true)
          (doc.data()['id'] as String):
              (doc.data()['fullName'] as String?)?.trim().isNotEmpty == true
              ? (doc.data()['fullName'] as String)
              : (doc.data()['id'] as String),
    };

    return ScholarshipWorkspaceSnapshot(
      programs: programs,
      awardLevels: awardLevels,
      submissions: submissions,
      memberNamesById: memberNamesById,
    );
  }

  @override
  Future<ScholarshipProgram> saveProgram({
    required AuthSession session,
    String? programId,
    required ScholarshipProgramDraft draft,
  }) async {
    await FirebaseSessionAccessSync.ensureUserSessionDocument(
      firestore: _firestore,
      session: session,
    );

    final clanId = session.clanId?.trim() ?? '';
    if (clanId.isEmpty) {
      throw const ScholarshipRepositoryException(
        ScholarshipRepositoryErrorCode.permissionDenied,
      );
    }

    final title = draft.title.trim();
    if (title.isEmpty) {
      throw const ScholarshipRepositoryException(
        ScholarshipRepositoryErrorCode.validationFailed,
        'Program title is required.',
      );
    }

    final year = draft.year > 0 ? draft.year : DateTime.now().year;
    final programRef = programId == null
        ? _programs.doc()
        : _programs.doc(programId);
    final existing = await programRef.get();
    if (programId != null && !existing.exists) {
      throw const ScholarshipRepositoryException(
        ScholarshipRepositoryErrorCode.programNotFound,
      );
    }

    final actor = session.memberId ?? session.uid;
    final payload = <String, dynamic>{
      'id': programRef.id,
      'clanId': clanId,
      'title': title,
      'description': draft.description.trim(),
      'year': year,
      'status': _statusOrDefault(draft.status),
      'submissionOpenAt': _timestampFromIso(draft.submissionOpenAtIso),
      'submissionCloseAt': _timestampFromIso(draft.submissionCloseAtIso),
      'reviewCloseAt': _timestampFromIso(draft.reviewCloseAtIso),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': actor,
      if (!existing.exists) 'createdAt': FieldValue.serverTimestamp(),
      if (!existing.exists) 'createdBy': actor,
    };

    await programRef.set(payload, SetOptions(merge: true));
    final updated = await programRef.get();
    return ScholarshipProgram.fromJson(updated.data()!);
  }

  @override
  Future<AwardLevel> saveAwardLevel({
    required AuthSession session,
    required String programId,
    String? awardLevelId,
    required AwardLevelDraft draft,
  }) async {
    await FirebaseSessionAccessSync.ensureUserSessionDocument(
      firestore: _firestore,
      session: session,
    );

    final clanId = session.clanId?.trim() ?? '';
    if (clanId.isEmpty) {
      throw const ScholarshipRepositoryException(
        ScholarshipRepositoryErrorCode.permissionDenied,
      );
    }

    final program = await _programs.doc(programId).get();
    if (!program.exists || program.data()?['clanId'] != clanId) {
      throw const ScholarshipRepositoryException(
        ScholarshipRepositoryErrorCode.programNotFound,
      );
    }

    final name = draft.name.trim();
    if (name.isEmpty) {
      throw const ScholarshipRepositoryException(
        ScholarshipRepositoryErrorCode.validationFailed,
        'Award level name is required.',
      );
    }

    final awardRef = awardLevelId == null
        ? _awardLevels.doc()
        : _awardLevels.doc(awardLevelId);
    final existing = await awardRef.get();
    if (awardLevelId != null && !existing.exists) {
      throw const ScholarshipRepositoryException(
        ScholarshipRepositoryErrorCode.awardLevelNotFound,
      );
    }

    final payload = <String, dynamic>{
      'id': awardRef.id,
      'programId': programId,
      'clanId': clanId,
      'name': name,
      'description': draft.description.trim(),
      'sortOrder': draft.sortOrder,
      'rewardType': _rewardTypeOrDefault(draft.rewardType),
      'rewardAmountMinor': draft.rewardAmountMinor,
      'criteriaText': draft.criteriaText.trim(),
      'status': draft.status.trim().isEmpty ? 'active' : draft.status.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
      if (!existing.exists) 'createdAt': FieldValue.serverTimestamp(),
    };

    await awardRef.set(payload, SetOptions(merge: true));
    final updated = await awardRef.get();
    return AwardLevel.fromJson(updated.data()!);
  }

  @override
  Future<AchievementSubmission> saveSubmission({
    required AuthSession session,
    String? submissionId,
    required AchievementSubmissionDraft draft,
  }) async {
    await FirebaseSessionAccessSync.ensureUserSessionDocument(
      firestore: _firestore,
      session: session,
    );

    final clanId = session.clanId?.trim() ?? '';
    if (clanId.isEmpty) {
      throw const ScholarshipRepositoryException(
        ScholarshipRepositoryErrorCode.permissionDenied,
      );
    }

    final memberId = session.memberId?.trim() ?? '';
    if (memberId.isEmpty) {
      throw const ScholarshipRepositoryException(
        ScholarshipRepositoryErrorCode.permissionDenied,
      );
    }

    final program = await _programs.doc(draft.programId).get();
    if (!program.exists || program.data()?['clanId'] != clanId) {
      throw const ScholarshipRepositoryException(
        ScholarshipRepositoryErrorCode.programNotFound,
      );
    }

    final awardLevel = await _awardLevels.doc(draft.awardLevelId).get();
    if (!awardLevel.exists ||
        awardLevel.data()?['programId'] != draft.programId ||
        awardLevel.data()?['clanId'] != clanId) {
      throw const ScholarshipRepositoryException(
        ScholarshipRepositoryErrorCode.awardLevelNotFound,
      );
    }

    final title = draft.title.trim();
    if (title.isEmpty) {
      throw const ScholarshipRepositoryException(
        ScholarshipRepositoryErrorCode.validationFailed,
        'Submission title is required.',
      );
    }

    final submissionRef = submissionId == null
        ? _submissions.doc()
        : _submissions.doc(submissionId);
    final existing = await submissionRef.get();
    if (submissionId != null && !existing.exists) {
      throw const ScholarshipRepositoryException(
        ScholarshipRepositoryErrorCode.submissionNotFound,
      );
    }

    final actor = session.memberId ?? session.uid;
    final existingData = existing.data();
    final payload = <String, dynamic>{
      'id': submissionRef.id,
      'programId': draft.programId,
      'awardLevelId': draft.awardLevelId,
      'clanId': clanId,
      'memberId': memberId,
      'studentNameSnapshot': _studentNameOrDefault(
        draft.studentName,
        fallback: session.displayName,
      ),
      'title': title,
      'description': draft.description.trim(),
      'evidenceUrls': _normalizeEvidenceUrls(draft.evidenceUrls),
      'status': existingData?['status'] ?? 'pending',
      'reviewNote': existingData?['reviewNote'],
      'reviewedBy': existingData?['reviewedBy'],
      'reviewedAt': existingData?['reviewedAt'],
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': actor,
      if (!existing.exists) 'createdAt': FieldValue.serverTimestamp(),
      if (!existing.exists) 'createdBy': actor,
    };

    await submissionRef.set(payload, SetOptions(merge: true));
    final updated = await submissionRef.get();
    return AchievementSubmission.fromJson(updated.data()!);
  }

  @override
  Future<String> uploadEvidenceFile({
    required AuthSession session,
    required String fileName,
    required Uint8List bytes,
    String contentType = 'application/octet-stream',
  }) async {
    await FirebaseSessionAccessSync.ensureUserSessionDocument(
      firestore: _firestore,
      session: session,
    );

    final clanId = session.clanId?.trim() ?? '';
    if (clanId.isEmpty) {
      throw const ScholarshipRepositoryException(
        ScholarshipRepositoryErrorCode.permissionDenied,
      );
    }

    final safeFileName = _sanitizeFileName(fileName);
    if (safeFileName.isEmpty) {
      throw const ScholarshipRepositoryException(
        ScholarshipRepositoryErrorCode.validationFailed,
        'Evidence file name is required.',
      );
    }

    final objectPath =
        'clans/$clanId/scholarship/evidence/${DateTime.now().millisecondsSinceEpoch}-$safeFileName';

    try {
      final storageRef = _storage.ref(objectPath);
      final snapshot = await storageRef.putData(
        bytes,
        SettableMetadata(contentType: contentType),
      );
      return snapshot.ref.getDownloadURL();
    } catch (error) {
      throw ScholarshipRepositoryException(
        ScholarshipRepositoryErrorCode.uploadFailed,
        error.toString(),
      );
    }
  }

  @override
  Future<AchievementSubmission> reviewSubmission({
    required AuthSession session,
    required String submissionId,
    required bool approved,
    String? reviewNote,
  }) async {
    await FirebaseSessionAccessSync.ensureUserSessionDocument(
      firestore: _firestore,
      session: session,
    );

    final clanId = session.clanId?.trim() ?? '';
    if (clanId.isEmpty) {
      throw const ScholarshipRepositoryException(
        ScholarshipRepositoryErrorCode.permissionDenied,
      );
    }

    final submissionRef = _submissions.doc(submissionId);
    final existing = await submissionRef.get();
    final data = existing.data();
    if (!existing.exists || data == null || data['clanId'] != clanId) {
      throw const ScholarshipRepositoryException(
        ScholarshipRepositoryErrorCode.submissionNotFound,
      );
    }

    await submissionRef.set({
      'status': approved ? 'approved' : 'rejected',
      'reviewNote': _nullIfEmpty(reviewNote),
      'reviewedBy': session.memberId ?? session.uid,
      'reviewedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': session.memberId ?? session.uid,
    }, SetOptions(merge: true));

    final updated = await submissionRef.get();
    return AchievementSubmission.fromJson(updated.data()!);
  }
}

String _statusOrDefault(String status) {
  final trimmed = status.trim().toLowerCase();
  return trimmed.isEmpty ? 'open' : trimmed;
}

String _rewardTypeOrDefault(String rewardType) {
  final trimmed = rewardType.trim().toLowerCase();
  return trimmed.isEmpty ? 'cash' : trimmed;
}

String _studentNameOrDefault(String input, {required String fallback}) {
  final trimmed = input.trim();
  if (trimmed.isNotEmpty) {
    return trimmed;
  }

  final fallbackTrimmed = fallback.trim();
  return fallbackTrimmed.isEmpty ? 'Unknown student' : fallbackTrimmed;
}

String _sanitizeFileName(String fileName) {
  final trimmed = fileName.trim();
  if (trimmed.isEmpty) {
    return '';
  }

  final replaced = trimmed.replaceAll(RegExp(r'\s+'), '-');
  return replaced.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
}

List<String> _normalizeEvidenceUrls(List<String> values) {
  return values
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toSet()
      .toList(growable: false);
}

String? _nullIfEmpty(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

Timestamp? _timestampFromIso(String? value) {
  final iso = value?.trim();
  if (iso == null || iso.isEmpty) {
    return null;
  }

  final parsed = DateTime.tryParse(iso);
  if (parsed == null) {
    return null;
  }

  return Timestamp.fromDate(parsed);
}
