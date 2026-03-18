import 'dart:async';
import 'dart:typed_data';

import 'package:collection/collection.dart';

import '../../../core/services/debug_genealogy_store.dart';
import '../../../core/services/governance_role_matrix.dart';
import '../../auth/models/auth_session.dart';
import '../models/achievement_submission.dart';
import '../models/achievement_submission_draft.dart';
import '../models/award_level.dart';
import '../models/award_level_draft.dart';
import '../models/scholarship_approval_log_entry.dart';
import '../models/scholarship_program.dart';
import '../models/scholarship_program_draft.dart';
import '../models/scholarship_workspace_snapshot.dart';
import 'scholarship_repository.dart';

class DebugScholarshipRepository implements ScholarshipRepository {
  DebugScholarshipRepository._({
    required _DebugScholarshipStore store,
    required DebugGenealogyStore genealogyStore,
  }) : _store = store,
       _genealogyStore = genealogyStore;

  factory DebugScholarshipRepository.seeded() {
    return DebugScholarshipRepository._(
      store: _DebugScholarshipStore.seeded(),
      genealogyStore: DebugGenealogyStore.seeded(),
    );
  }

  factory DebugScholarshipRepository.shared() {
    return DebugScholarshipRepository._(
      store: _sharedStore,
      genealogyStore: DebugGenealogyStore.sharedSeeded(),
    );
  }

  static final _DebugScholarshipStore _sharedStore =
      _DebugScholarshipStore.seeded();

  final _DebugScholarshipStore _store;
  final DebugGenealogyStore _genealogyStore;

  @override
  bool get isSandbox => true;

  @override
  Future<ScholarshipWorkspaceSnapshot> loadWorkspace({
    required AuthSession session,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));

    final clanId = session.clanId;
    if (clanId == null || clanId.isEmpty) {
      return const ScholarshipWorkspaceSnapshot(
        programs: [],
        awardLevels: [],
        submissions: [],
        memberNamesById: {},
        approvalLogs: [],
        councilHeadMemberIds: [],
      );
    }

    final programs = _store.programs.values
        .where((program) => program.clanId == clanId)
        .sorted(
          (left, right) => right.year.compareTo(left.year) != 0
              ? right.year.compareTo(left.year)
              : left.title.toLowerCase().compareTo(right.title.toLowerCase()),
        )
        .toList(growable: false);

    final awards = _store.awardLevels.values
        .where((award) => award.clanId == clanId)
        .sortedBy<num>((award) => award.sortOrder)
        .toList(growable: false);

    final submissions = _store.submissions.values
        .where((submission) => submission.clanId == clanId)
        .sorted(
          (left, right) => right.updatedAtIso.compareTo(left.updatedAtIso) != 0
              ? right.updatedAtIso.compareTo(left.updatedAtIso)
              : left.title.toLowerCase().compareTo(right.title.toLowerCase()),
        )
        .toList(growable: false);

    final memberNamesById = {
      for (final member in _genealogyStore.members.values)
        if (member.clanId == clanId) member.id: member.fullName,
    };

    final councilHeadMemberIds = _activeCouncilHeadMemberIds(clanId);

    final approvalLogs = _store.approvalLogs.values
        .where((entry) => entry.clanId == clanId)
        .sorted(
          (left, right) => right.createdAtIso.compareTo(left.createdAtIso),
        )
        .toList(growable: false);

    return ScholarshipWorkspaceSnapshot(
      programs: programs,
      awardLevels: awards,
      submissions: submissions,
      memberNamesById: memberNamesById,
      approvalLogs: approvalLogs,
      councilHeadMemberIds: councilHeadMemberIds,
    );
  }

  @override
  Future<ScholarshipProgram> saveProgram({
    required AuthSession session,
    String? programId,
    required ScholarshipProgramDraft draft,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 140));

    final clanId = session.clanId;
    if (clanId == null || clanId.isEmpty) {
      throw const ScholarshipRepositoryException(
        ScholarshipRepositoryErrorCode.permissionDenied,
      );
    }

    final title = draft.title.trim();
    if (title.isEmpty) {
      throw const ScholarshipRepositoryException(
        ScholarshipRepositoryErrorCode.validationFailed,
        'Tên chương trình là bắt buộc.',
      );
    }

    final year = draft.year > 0 ? draft.year : DateTime.now().year;
    final resolvedProgramId =
        programId ?? 'sp_demo_${_store.programSequence++}';
    final existing = _store.programs[resolvedProgramId];
    if (programId != null && existing == null) {
      throw const ScholarshipRepositoryException(
        ScholarshipRepositoryErrorCode.programNotFound,
      );
    }

    final payload = ScholarshipProgram(
      id: resolvedProgramId,
      clanId: clanId,
      title: title,
      description: draft.description.trim(),
      year: year,
      status: _statusOrDefault(draft.status),
      submissionOpenAtIso: _nullIfEmpty(draft.submissionOpenAtIso),
      submissionCloseAtIso: _nullIfEmpty(draft.submissionCloseAtIso),
      reviewCloseAtIso: _nullIfEmpty(draft.reviewCloseAtIso),
      createdAtIso: existing?.createdAtIso ?? DateTime.now().toIso8601String(),
      createdBy: existing?.createdBy ?? (session.memberId ?? session.uid),
    );

    _store.programs[resolvedProgramId] = payload;
    return payload;
  }

  @override
  Future<AwardLevel> saveAwardLevel({
    required AuthSession session,
    required String programId,
    String? awardLevelId,
    required AwardLevelDraft draft,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 140));

    final clanId = session.clanId;
    if (clanId == null || clanId.isEmpty) {
      throw const ScholarshipRepositoryException(
        ScholarshipRepositoryErrorCode.permissionDenied,
      );
    }

    final program = _store.programs[programId];
    if (program == null || program.clanId != clanId) {
      throw const ScholarshipRepositoryException(
        ScholarshipRepositoryErrorCode.programNotFound,
      );
    }

    final name = draft.name.trim();
    if (name.isEmpty) {
      throw const ScholarshipRepositoryException(
        ScholarshipRepositoryErrorCode.validationFailed,
        'Tên hạng mục giải thưởng là bắt buộc.',
      );
    }

    final resolvedAwardId =
        awardLevelId ?? 'award_demo_${_store.awardSequence++}';
    final existing = _store.awardLevels[resolvedAwardId];
    if (awardLevelId != null && existing == null) {
      throw const ScholarshipRepositoryException(
        ScholarshipRepositoryErrorCode.awardLevelNotFound,
      );
    }

    final payload = AwardLevel(
      id: resolvedAwardId,
      programId: programId,
      clanId: clanId,
      name: name,
      description: draft.description.trim(),
      sortOrder: draft.sortOrder,
      rewardType: _rewardTypeOrDefault(draft.rewardType),
      rewardAmountMinor: draft.rewardAmountMinor,
      criteriaText: draft.criteriaText.trim(),
      status: draft.status.trim().isEmpty ? 'active' : draft.status.trim(),
      createdAtIso: existing?.createdAtIso ?? DateTime.now().toIso8601String(),
    );

    _store.awardLevels[resolvedAwardId] = payload;
    return payload;
  }

  @override
  Future<AchievementSubmission> saveSubmission({
    required AuthSession session,
    String? submissionId,
    required AchievementSubmissionDraft draft,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));

    final clanId = session.clanId;
    if (clanId == null || clanId.isEmpty) {
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

    final program = _store.programs[draft.programId];
    if (program == null || program.clanId != clanId) {
      throw const ScholarshipRepositoryException(
        ScholarshipRepositoryErrorCode.programNotFound,
      );
    }

    final awardLevel = _store.awardLevels[draft.awardLevelId];
    if (awardLevel == null || awardLevel.programId != draft.programId) {
      throw const ScholarshipRepositoryException(
        ScholarshipRepositoryErrorCode.awardLevelNotFound,
      );
    }

    final title = draft.title.trim();
    if (title.isEmpty) {
      throw const ScholarshipRepositoryException(
        ScholarshipRepositoryErrorCode.validationFailed,
        'Tiêu đề hồ sơ là bắt buộc.',
      );
    }

    final resolvedSubmissionId =
        submissionId ?? 'sub_demo_${_store.submissionSequence++}';
    final existing = _store.submissions[resolvedSubmissionId];
    if (submissionId != null && existing == null) {
      throw const ScholarshipRepositoryException(
        ScholarshipRepositoryErrorCode.submissionNotFound,
      );
    }

    final nowIso = DateTime.now().toIso8601String();
    final payload = AchievementSubmission(
      id: resolvedSubmissionId,
      programId: draft.programId,
      awardLevelId: draft.awardLevelId,
      clanId: clanId,
      memberId: memberId,
      studentNameSnapshot: _studentNameOrDefault(
        draft.studentName,
        fallback: session.displayName,
      ),
      title: title,
      description: draft.description.trim(),
      evidenceUrls: _normalizeEvidenceUrls(draft.evidenceUrls),
      status: existing?.status ?? 'pending',
      reviewNote: existing?.reviewNote,
      reviewedBy: existing?.reviewedBy,
      reviewedAtIso: existing?.reviewedAtIso,
      createdAtIso: existing?.createdAtIso ?? nowIso,
      updatedAtIso: nowIso,
    );

    _store.submissions[resolvedSubmissionId] = payload;
    return payload;
  }

  @override
  Future<String> uploadEvidenceFile({
    required AuthSession session,
    required String fileName,
    required Uint8List bytes,
    String contentType = 'application/octet-stream',
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 90));

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
        'Tên tệp minh chứng là bắt buộc.',
      );
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'debug://clans/$clanId/scholarship/evidence/$timestamp-$safeFileName';
  }

  @override
  Future<AchievementSubmission> reviewSubmission({
    required AuthSession session,
    required String submissionId,
    required bool approved,
    String? reviewNote,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 100));

    final clanId = session.clanId?.trim() ?? '';
    if (clanId.isEmpty) {
      throw const ScholarshipRepositoryException(
        ScholarshipRepositoryErrorCode.permissionDenied,
      );
    }

    final role = session.primaryRole?.trim().toUpperCase() ?? '';
    if (role != GovernanceRoles.scholarshipCouncilHead) {
      throw const ScholarshipRepositoryException(
        ScholarshipRepositoryErrorCode.permissionDenied,
      );
    }

    final reviewerMemberId = session.memberId?.trim() ?? '';
    if (reviewerMemberId.isEmpty) {
      throw const ScholarshipRepositoryException(
        ScholarshipRepositoryErrorCode.permissionDenied,
      );
    }
    final councilHeadMemberIds = _activeCouncilHeadMemberIds(clanId);
    if (!councilHeadMemberIds.contains(reviewerMemberId)) {
      throw const ScholarshipRepositoryException(
        ScholarshipRepositoryErrorCode.permissionDenied,
      );
    }
    if (councilHeadMemberIds.length != 3) {
      throw const ScholarshipRepositoryException(
        ScholarshipRepositoryErrorCode.validationFailed,
        'council_configuration_invalid',
      );
    }

    final existing = _store.submissions[submissionId];
    if (existing == null || existing.clanId != clanId) {
      throw const ScholarshipRepositoryException(
        ScholarshipRepositoryErrorCode.submissionNotFound,
      );
    }

    if (!existing.isPending) {
      throw const ScholarshipRepositoryException(
        ScholarshipRepositoryErrorCode.validationFailed,
        'submission_not_pending',
      );
    }

    final hasExistingVote = existing.approvalVotes.any(
      (vote) => vote.memberId == reviewerMemberId,
    );
    if (hasExistingVote) {
      throw const ScholarshipRepositoryException(
        ScholarshipRepositoryErrorCode.validationFailed,
        'duplicate_vote',
      );
    }

    final nowIso = DateTime.now().toIso8601String();
    final trimmedNote = _nullIfEmpty(reviewNote);
    final updatedVotes = [
      ...existing.approvalVotes,
      ScholarshipApprovalVote(
        memberId: reviewerMemberId,
        decision: approved ? 'approve' : 'reject',
        createdAtIso: nowIso,
        note: trimmedNote,
      ),
    ];
    final approvalCount = updatedVotes.where((vote) => vote.isApprove).length;
    final rejectionCount = updatedVotes.where((vote) => vote.isReject).length;

    var status = 'pending';
    if (approvalCount >= 2) {
      status = 'approved';
    } else if (rejectionCount >= 2) {
      status = 'rejected';
    }

    final updated = existing.copyWith(
      status: status,
      reviewNote: status == 'pending' ? null : trimmedNote,
      clearReviewNote: status == 'pending' || trimmedNote == null,
      reviewedBy: status == 'pending' ? null : reviewerMemberId,
      clearReviewedBy: status == 'pending',
      reviewedAtIso: status == 'pending' ? null : nowIso,
      clearReviewedAtIso: status == 'pending',
      updatedAtIso: nowIso,
      approvalVotes: updatedVotes,
      finalDecisionReason: status == 'pending' ? null : trimmedNote,
      clearFinalDecisionReason: status == 'pending',
    );

    _store.submissions[submissionId] = updated;
    final voteLog = ScholarshipApprovalLogEntry(
      id: 'log_vote_${_store.logSequence++}',
      clanId: clanId,
      submissionId: submissionId,
      action: 'vote',
      decision: approved ? 'approve' : 'reject',
      actorMemberId: reviewerMemberId,
      actorRole: role,
      note: trimmedNote,
      createdAtIso: nowIso,
    );
    _store.approvalLogs[voteLog.id] = voteLog;
    if (status != 'pending') {
      final finalizeLog = ScholarshipApprovalLogEntry(
        id: 'log_final_${_store.logSequence++}',
        clanId: clanId,
        submissionId: submissionId,
        action: 'finalized',
        decision: status,
        actorMemberId: reviewerMemberId,
        actorRole: role,
        note: trimmedNote,
        createdAtIso: nowIso,
      );
      _store.approvalLogs[finalizeLog.id] = finalizeLog;
    }

    return updated;
  }

  List<String> _activeCouncilHeadMemberIds(String clanId) {
    return _genealogyStore.members.values
        .where(
          (member) =>
              member.clanId == clanId &&
              member.primaryRole.trim().toUpperCase() ==
                  GovernanceRoles.scholarshipCouncilHead &&
              member.status.trim().toLowerCase() == 'active',
        )
        .map((member) => member.id)
        .toList(growable: false);
  }
}

class _DebugScholarshipStore {
  _DebugScholarshipStore({
    required this.programs,
    required this.awardLevels,
    required this.submissions,
    required this.approvalLogs,
  });

  factory _DebugScholarshipStore.seeded() {
    const clanId = 'clan_demo_001';
    const createdBy = 'member_demo_parent_001';
    final now = DateTime(2026, 3, 14, 10, 30).toIso8601String();

    return _DebugScholarshipStore(
      programs: {
        'sp_demo_2026': ScholarshipProgram(
          id: 'sp_demo_2026',
          clanId: clanId,
          title: 'Chương trình học bổng năm 2026',
          description:
              'Chương trình học bổng thường niên cho học sinh, sinh viên có thành tích nổi bật.',
          year: 2026,
          status: 'open',
          submissionOpenAtIso: DateTime(2026, 3, 1).toIso8601String(),
          submissionCloseAtIso: DateTime(2026, 5, 31).toIso8601String(),
          reviewCloseAtIso: DateTime(2026, 6, 30).toIso8601String(),
          createdAtIso: now,
          createdBy: createdBy,
        ),
      },
      awardLevels: {
        'award_demo_001': AwardLevel(
          id: 'award_demo_001',
          programId: 'sp_demo_2026',
          clanId: clanId,
          name: 'Thành tích cấp quốc gia',
          description: 'Vinh danh thành tích học tập hoặc thi cử cấp quốc gia.',
          sortOrder: 10,
          rewardType: 'cash',
          rewardAmountMinor: 2000000,
          criteriaText: 'Bắt buộc đính kèm giấy chứng nhận hợp lệ.',
          status: 'active',
          createdAtIso: now,
        ),
        'award_demo_002': AwardLevel(
          id: 'award_demo_002',
          programId: 'sp_demo_2026',
          clanId: clanId,
          name: 'Thành tích cấp tỉnh',
          description: 'Vinh danh thành tích học tập hoặc thi cử cấp tỉnh.',
          sortOrder: 20,
          rewardType: 'cash',
          rewardAmountMinor: 1000000,
          criteriaText: 'Bắt buộc đính kèm kết quả đã xác minh.',
          status: 'active',
          createdAtIso: now,
        ),
      },
      submissions: {
        'sub_demo_001': AchievementSubmission(
          id: 'sub_demo_001',
          programId: 'sp_demo_2026',
          awardLevelId: 'award_demo_001',
          clanId: clanId,
          memberId: 'member_demo_child_001',
          studentNameSnapshot: 'Bé Minh',
          title: 'Olympic Toán cấp quốc gia',
          description: 'Đạt giải Nhì kỳ thi Olympic Toán cấp quốc gia.',
          evidenceUrls: const ['debug://seed/chung-chi-toan-cap-quoc-gia.pdf'],
          status: 'pending',
          reviewNote: null,
          reviewedBy: null,
          reviewedAtIso: null,
          createdAtIso: now,
          updatedAtIso: now,
        ),
        'sub_demo_002': AchievementSubmission(
          id: 'sub_demo_002',
          programId: 'sp_demo_2026',
          awardLevelId: 'award_demo_002',
          clanId: clanId,
          memberId: 'member_demo_child_002',
          studentNameSnapshot: 'Bé Lan',
          title: 'Kỳ thi Ngữ văn cấp tỉnh',
          description: 'Đạt giải Nhất kỳ thi Ngữ văn cấp tỉnh.',
          evidenceUrls: const ['debug://seed/chung-chi-ngu-van-cap-tinh.jpg'],
          status: 'approved',
          reviewNote: 'Hồ sơ minh chứng đầy đủ, hợp lệ.',
          reviewedBy: createdBy,
          reviewedAtIso: now,
          createdAtIso: now,
          updatedAtIso: now,
        ),
      },
      approvalLogs: {},
    );
  }

  final Map<String, ScholarshipProgram> programs;
  final Map<String, AwardLevel> awardLevels;
  final Map<String, AchievementSubmission> submissions;
  final Map<String, ScholarshipApprovalLogEntry> approvalLogs;
  int programSequence = 2027;
  int awardSequence = 100;
  int submissionSequence = 1000;
  int logSequence = 1000;
}

String _statusOrDefault(String status) {
  final trimmed = status.trim().toLowerCase();
  if (trimmed.isEmpty) {
    return 'open';
  }

  return trimmed;
}

String _rewardTypeOrDefault(String rewardType) {
  final trimmed = rewardType.trim().toLowerCase();
  if (trimmed.isEmpty) {
    return 'cash';
  }

  return trimmed;
}

String? _nullIfEmpty(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

String _studentNameOrDefault(String input, {required String fallback}) {
  final trimmed = input.trim();
  if (trimmed.isNotEmpty) {
    return trimmed;
  }

  final fallbackTrimmed = fallback.trim();
  return fallbackTrimmed.isEmpty ? 'Học sinh chưa xác định' : fallbackTrimmed;
}

List<String> _normalizeEvidenceUrls(List<String> values) {
  return values
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toSet()
      .toList(growable: false);
}

String _sanitizeFileName(String fileName) {
  final trimmed = fileName.trim();
  if (trimmed.isEmpty) {
    return '';
  }

  final replaced = trimmed.replaceAll(RegExp(r'\s+'), '-');
  return replaced.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
}
