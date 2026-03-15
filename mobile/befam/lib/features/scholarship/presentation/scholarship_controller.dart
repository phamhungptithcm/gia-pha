import 'package:flutter/foundation.dart';

import '../../auth/models/auth_session.dart';
import '../models/achievement_submission.dart';
import '../models/achievement_submission_draft.dart';
import '../models/award_level.dart';
import '../models/award_level_draft.dart';
import '../models/scholarship_approval_log_entry.dart';
import '../models/scholarship_program.dart';
import '../models/scholarship_program_draft.dart';
import '../services/scholarship_permissions.dart';
import '../services/scholarship_repository.dart';

class ScholarshipController extends ChangeNotifier {
  ScholarshipController({
    required ScholarshipRepository repository,
    required AuthSession session,
  }) : _repository = repository,
       _session = session,
       permissions = ScholarshipPermissions.forSession(session);

  final ScholarshipRepository _repository;
  final AuthSession _session;
  final ScholarshipPermissions permissions;

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isUploadingEvidence = false;
  bool _isReviewing = false;
  String? _errorMessage;
  List<ScholarshipProgram> _programs = const [];
  List<AwardLevel> _awardLevels = const [];
  List<AchievementSubmission> _submissions = const [];
  List<ScholarshipApprovalLogEntry> _approvalLogs = const [];
  List<String> _councilHeadMemberIds = const [];
  Map<String, String> _memberNamesById = const {};
  String? _selectedProgramId;

  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  bool get isUploadingEvidence => _isUploadingEvidence;
  bool get isReviewing => _isReviewing;
  String? get errorMessage => _errorMessage;
  List<ScholarshipProgram> get programs => _programs;
  List<AwardLevel> get awardLevels => _awardLevels;
  List<AchievementSubmission> get submissions => _submissions;
  List<ScholarshipApprovalLogEntry> get approvalLogs => _approvalLogs;
  List<String> get councilHeadMemberIds => _councilHeadMemberIds;
  String? get selectedProgramId => _selectedProgramId;

  ScholarshipProgram? get selectedProgram {
    final id = _selectedProgramId;
    if (id == null || id.isEmpty) {
      return null;
    }

    for (final program in _programs) {
      if (program.id == id) {
        return program;
      }
    }

    return null;
  }

  List<AwardLevel> get selectedProgramAwardLevels {
    final id = _selectedProgramId;
    if (id == null || id.isEmpty) {
      return const [];
    }

    return _awardLevels
        .where((awardLevel) => awardLevel.programId == id)
        .toList(growable: false);
  }

  List<AchievementSubmission> get selectedProgramSubmissions {
    final id = _selectedProgramId;
    if (id == null || id.isEmpty) {
      return const [];
    }

    return _submissions
        .where((submission) => submission.programId == id)
        .toList(growable: false);
  }

  List<AchievementSubmission> get reviewQueue {
    return _submissions
        .where((submission) => submission.isPending)
        .toList(growable: false);
  }

  bool get canCreatePrograms => permissions.canManagePrograms;
  bool get canCreateAwardLevels => permissions.canManagePrograms;
  bool get canSubmitAchievements => permissions.canSubmitSubmissions;
  bool get canReviewSubmissions => permissions.canReviewQueue;
  bool get canViewApprovalHistory => permissions.canViewApprovalHistory;

  bool hasCurrentReviewerVoted(AchievementSubmission submission) {
    final memberId = _session.memberId?.trim() ?? '';
    if (memberId.isEmpty) {
      return false;
    }
    return submission.approvalVotes.any((vote) => vote.memberId == memberId);
  }

  String memberName(String memberId) {
    final resolved = _memberNamesById[memberId];
    if (resolved == null || resolved.trim().isEmpty) {
      return memberId;
    }

    return resolved;
  }

  AwardLevel? awardLevelById(String awardLevelId) {
    for (final awardLevel in _awardLevels) {
      if (awardLevel.id == awardLevelId) {
        return awardLevel;
      }
    }

    return null;
  }

  ScholarshipProgram? programById(String programId) {
    for (final program in _programs) {
      if (program.id == programId) {
        return program;
      }
    }

    return null;
  }

  Future<void> initialize() async {
    await refresh();
  }

  Future<void> refresh() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final snapshot = await _repository.loadWorkspace(session: _session);
      _programs = snapshot.programs;
      _awardLevels = snapshot.awardLevels;
      _submissions = snapshot.submissions;
      _approvalLogs = snapshot.approvalLogs;
      _councilHeadMemberIds = snapshot.councilHeadMemberIds;
      _memberNamesById = snapshot.memberNamesById;

      final currentSelected = _selectedProgramId;
      if (currentSelected != null &&
          _programs.any((program) => program.id == currentSelected)) {
        _selectedProgramId = currentSelected;
      } else {
        _selectedProgramId = _programs.isNotEmpty ? _programs.first.id : null;
      }
    } catch (error) {
      _errorMessage = error.toString();
      _programs = const [];
      _awardLevels = const [];
      _submissions = const [];
      _approvalLogs = const [];
      _councilHeadMemberIds = const [];
      _memberNamesById = const {};
      _selectedProgramId = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void selectProgram(String? programId) {
    final resolved = programId?.trim();
    if (resolved == null || resolved.isEmpty) {
      _selectedProgramId = null;
      notifyListeners();
      return;
    }

    if (!_programs.any((program) => program.id == resolved)) {
      return;
    }

    _selectedProgramId = resolved;
    notifyListeners();
  }

  Future<ScholarshipRepositoryErrorCode?> createProgram({
    required ScholarshipProgramDraft draft,
  }) async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final created = await _repository.saveProgram(
        session: _session,
        draft: draft,
      );
      await refresh();
      _selectedProgramId = created.id;
      notifyListeners();
      return null;
    } on ScholarshipRepositoryException catch (error) {
      _errorMessage = error.toString();
      return error.code;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<ScholarshipRepositoryErrorCode?> createAwardLevel({
    required String programId,
    required AwardLevelDraft draft,
  }) async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.saveAwardLevel(
        session: _session,
        programId: programId,
        draft: draft,
      );
      await refresh();
      return null;
    } on ScholarshipRepositoryException catch (error) {
      _errorMessage = error.toString();
      return error.code;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<ScholarshipRepositoryErrorCode?> createSubmission({
    required AchievementSubmissionDraft draft,
  }) async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.saveSubmission(session: _session, draft: draft);
      await refresh();
      return null;
    } on ScholarshipRepositoryException catch (error) {
      _errorMessage = error.toString();
      return error.code;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<String?> uploadEvidence({
    required String fileName,
    required Uint8List bytes,
    String contentType = 'application/octet-stream',
  }) async {
    _isUploadingEvidence = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final url = await _repository.uploadEvidenceFile(
        session: _session,
        fileName: fileName,
        bytes: bytes,
        contentType: contentType,
      );
      return url;
    } on ScholarshipRepositoryException catch (error) {
      _errorMessage = error.toString();
      return null;
    } finally {
      _isUploadingEvidence = false;
      notifyListeners();
    }
  }

  Future<ScholarshipRepositoryErrorCode?> reviewSubmission({
    required String submissionId,
    required bool approved,
    String? reviewNote,
  }) async {
    _isReviewing = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.reviewSubmission(
        session: _session,
        submissionId: submissionId,
        approved: approved,
        reviewNote: reviewNote,
      );
      await refresh();
      return null;
    } on ScholarshipRepositoryException catch (error) {
      _errorMessage = error.toString();
      return error.code;
    } finally {
      _isReviewing = false;
      notifyListeners();
    }
  }
}
