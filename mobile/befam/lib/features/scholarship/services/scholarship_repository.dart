import 'dart:typed_data';

import '../../../core/services/runtime_mode.dart';
import '../../auth/models/auth_session.dart';
import '../models/achievement_submission.dart';
import '../models/achievement_submission_draft.dart';
import '../models/award_level.dart';
import '../models/award_level_draft.dart';
import '../models/scholarship_program.dart';
import '../models/scholarship_program_draft.dart';
import '../models/scholarship_workspace_snapshot.dart';
import 'debug_scholarship_repository.dart';
import 'firebase_scholarship_repository.dart';

enum ScholarshipRepositoryErrorCode {
  permissionDenied,
  programNotFound,
  awardLevelNotFound,
  submissionNotFound,
  validationFailed,
  uploadFailed,
}

class ScholarshipRepositoryException implements Exception {
  const ScholarshipRepositoryException(this.code, [this.message]);

  final ScholarshipRepositoryErrorCode code;
  final String? message;

  @override
  String toString() => message ?? code.name;
}

abstract interface class ScholarshipRepository {
  bool get isSandbox;

  Future<ScholarshipWorkspaceSnapshot> loadWorkspace({
    required AuthSession session,
  });

  Future<ScholarshipProgram> saveProgram({
    required AuthSession session,
    String? programId,
    required ScholarshipProgramDraft draft,
  });

  Future<AwardLevel> saveAwardLevel({
    required AuthSession session,
    required String programId,
    String? awardLevelId,
    required AwardLevelDraft draft,
  });

  Future<AchievementSubmission> saveSubmission({
    required AuthSession session,
    String? submissionId,
    required AchievementSubmissionDraft draft,
  });

  Future<String> uploadEvidenceFile({
    required AuthSession session,
    required String fileName,
    required Uint8List bytes,
    String contentType = 'application/octet-stream',
  });

  Future<AchievementSubmission> reviewSubmission({
    required AuthSession session,
    required String submissionId,
    required bool approved,
    String? reviewNote,
  });
}

ScholarshipRepository createDefaultScholarshipRepository({
  AuthSession? session,
}) {
  final useMockBackend = session?.isSandbox ?? RuntimeMode.shouldUseMockBackend;
  if (useMockBackend) {
    return DebugScholarshipRepository.shared();
  }

  return FirebaseScholarshipRepository();
}
