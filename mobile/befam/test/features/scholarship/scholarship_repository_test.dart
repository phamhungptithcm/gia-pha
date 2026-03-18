import 'dart:typed_data';

import 'package:befam/features/auth/models/auth_entry_method.dart';
import 'package:befam/features/auth/models/auth_member_access_mode.dart';
import 'package:befam/features/auth/models/auth_session.dart';
import 'package:befam/features/scholarship/models/achievement_submission_draft.dart';
import 'package:befam/features/scholarship/models/award_level_draft.dart';
import 'package:befam/features/scholarship/models/scholarship_program_draft.dart';
import 'package:befam/features/scholarship/services/debug_scholarship_repository.dart';
import 'package:befam/features/scholarship/services/scholarship_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  AuthSession buildClanAdminSession() {
    return AuthSession(
      uid: 'debug:+84901234567',
      loginMethod: AuthEntryMethod.phone,
      phoneE164: '+84901234567',
      displayName: 'Nguyễn Minh',
      memberId: 'member_demo_parent_001',
      clanId: 'clan_demo_001',
      branchId: 'branch_demo_001',
      primaryRole: 'CLAN_ADMIN',
      accessMode: AuthMemberAccessMode.claimed,
      linkedAuthUid: true,
      isSandbox: true,
      signedInAtIso: DateTime(2026, 3, 14).toIso8601String(),
    );
  }

  AuthSession buildCouncilSession({
    required String memberId,
    required String phoneE164,
  }) {
    return AuthSession(
      uid: 'debug:$phoneE164',
      loginMethod: AuthEntryMethod.phone,
      phoneE164: phoneE164,
      displayName: 'Trưởng ban xét duyệt $memberId',
      memberId: memberId,
      clanId: 'clan_demo_001',
      branchId: 'branch_demo_001',
      primaryRole: 'SCHOLARSHIP_COUNCIL_HEAD',
      accessMode: AuthMemberAccessMode.claimed,
      linkedAuthUid: true,
      isSandbox: true,
      signedInAtIso: DateTime(2026, 3, 14).toIso8601String(),
    );
  }

  AuthSession buildMemberSession({
    required String memberId,
    required String phoneE164,
  }) {
    return AuthSession(
      uid: 'debug:$phoneE164',
      loginMethod: AuthEntryMethod.phone,
      phoneE164: phoneE164,
      displayName: 'Thành viên thường $memberId',
      memberId: memberId,
      clanId: 'clan_demo_001',
      branchId: 'branch_demo_001',
      primaryRole: 'MEMBER',
      accessMode: AuthMemberAccessMode.claimed,
      linkedAuthUid: true,
      isSandbox: true,
      signedInAtIso: DateTime(2026, 3, 14).toIso8601String(),
    );
  }

  test('loads seeded scholarship workspace', () async {
    final repository = DebugScholarshipRepository.seeded();
    final session = buildClanAdminSession();

    final snapshot = await repository.loadWorkspace(session: session);

    expect(snapshot.programs, isNotEmpty);
    expect(snapshot.awardLevels, isNotEmpty);
    expect(snapshot.submissions, isNotEmpty);
    expect(snapshot.councilHeadMemberIds, hasLength(3));
    expect(
      snapshot.submissions.any((submission) => submission.status == 'pending'),
      isTrue,
    );
  });

  test('creates program and award level for that program', () async {
    final repository = DebugScholarshipRepository.seeded();
    final session = buildClanAdminSession();

    final program = await repository.saveProgram(
      session: session,
      draft: const ScholarshipProgramDraft(
        title: '2027 Scholarship Program',
        description: 'Program for next academic year.',
        year: 2027,
        status: 'open',
        submissionOpenAtIso: '2027-03-01T00:00:00.000',
        submissionCloseAtIso: '2027-05-31T00:00:00.000',
        reviewCloseAtIso: '2027-06-30T00:00:00.000',
      ),
    );

    final awardLevel = await repository.saveAwardLevel(
      session: session,
      programId: program.id,
      draft: const AwardLevelDraft(
        name: 'International Medal',
        description: 'Recognize international medal achievements.',
        sortOrder: 10,
        rewardType: 'cash',
        rewardAmountMinor: 3000000,
        criteriaText: 'Attach certificate and event verification.',
        status: 'active',
      ),
    );

    expect(program.title, '2027 Scholarship Program');
    expect(awardLevel.programId, program.id);

    final snapshot = await repository.loadWorkspace(session: session);
    expect(snapshot.programs.any((item) => item.id == program.id), isTrue);
    expect(
      snapshot.awardLevels.any((item) => item.id == awardLevel.id),
      isTrue,
    );
  });

  test('uploads evidence and creates submission', () async {
    final repository = DebugScholarshipRepository.seeded();
    final session = buildClanAdminSession();
    final snapshot = await repository.loadWorkspace(session: session);

    final program = snapshot.programs.first;
    final awardLevel = snapshot.awardLevels.firstWhere(
      (item) => item.programId == program.id,
    );

    final evidenceUrl = await repository.uploadEvidenceFile(
      session: session,
      fileName: 'achievement-proof.txt',
      bytes: Uint8List.fromList(const [1, 2, 3, 4]),
      contentType: 'text/plain',
    );

    final submission = await repository.saveSubmission(
      session: session,
      draft: AchievementSubmissionDraft(
        programId: program.id,
        awardLevelId: awardLevel.id,
        studentName: 'Pham Gia Hung',
        title: 'Regional Science Contest',
        description: 'Won first place in regional science contest.',
        evidenceUrls: [evidenceUrl],
      ),
    );

    expect(
      evidenceUrl,
      startsWith('debug://clans/clan_demo_001/scholarship/evidence/'),
    );
    expect(evidenceUrl, contains('/member_demo_parent_001/'));
    expect(submission.evidenceUrls, contains(evidenceUrl));
    expect(submission.status, 'pending');
  });

  test('member can only see own scholarship submissions', () async {
    final repository = DebugScholarshipRepository.seeded();
    final memberSession = buildMemberSession(
      memberId: 'member_demo_child_001',
      phoneE164: '+84901111999',
    );

    final snapshot = await repository.loadWorkspace(session: memberSession);

    expect(snapshot.submissions, hasLength(1));
    expect(snapshot.submissions.first.memberId, 'member_demo_child_001');
    expect(
      snapshot.submissions.any(
        (submission) => submission.memberId == 'member_demo_child_002',
      ),
      isFalse,
    );
  });

  test('finalizes submissions with 2-of-3 council votes', () async {
    final repository = DebugScholarshipRepository.seeded();
    final clanAdminSession = buildClanAdminSession();
    final councilHeadA = buildCouncilSession(
      memberId: 'member_council_001',
      phoneE164: '+84901111001',
    );
    final councilHeadB = buildCouncilSession(
      memberId: 'member_council_002',
      phoneE164: '+84901111002',
    );
    final councilHeadC = buildCouncilSession(
      memberId: 'member_council_003',
      phoneE164: '+84901111003',
    );

    final snapshot = await repository.loadWorkspace(session: clanAdminSession);

    final pending = snapshot.submissions.firstWhere(
      (submission) => submission.status == 'pending',
    );

    final firstApprovalVote = await repository.reviewSubmission(
      session: councilHeadA,
      submissionId: pending.id,
      approved: true,
      reviewNote: 'First approval vote.',
    );

    expect(firstApprovalVote.status, 'pending');
    expect(firstApprovalVote.approvalCount, 1);
    expect(firstApprovalVote.rejectionCount, 0);

    final approved = await repository.reviewSubmission(
      session: councilHeadB,
      submissionId: pending.id,
      approved: true,
      reviewNote: 'Second approval vote.',
    );

    expect(approved.status, 'approved');
    expect(approved.approvalCount, 2);
    expect(approved.reviewNote, 'Second approval vote.');

    final program = snapshot.programs.first;
    final awardLevel = snapshot.awardLevels.firstWhere(
      (item) => item.programId == program.id,
    );
    final submissionForRejection = await repository.saveSubmission(
      session: clanAdminSession,
      draft: AchievementSubmissionDraft(
        programId: program.id,
        awardLevelId: awardLevel.id,
        studentName: 'Pham Gia Hung',
        title: 'Need Additional Documents',
        description: 'Pending evidence review.',
        evidenceUrls: const ['debug://seed/rejection-case.pdf'],
      ),
    );

    final firstRejectionVote = await repository.reviewSubmission(
      session: councilHeadA,
      submissionId: submissionForRejection.id,
      approved: false,
      reviewNote: 'First rejection vote.',
    );
    expect(firstRejectionVote.status, 'pending');
    expect(firstRejectionVote.approvalCount, 0);
    expect(firstRejectionVote.rejectionCount, 1);

    final rejected = await repository.reviewSubmission(
      session: councilHeadC,
      submissionId: submissionForRejection.id,
      approved: false,
      reviewNote: 'Second rejection vote.',
    );

    expect(rejected.status, 'rejected');
    expect(rejected.rejectionCount, 2);
    expect(rejected.reviewNote, 'Second rejection vote.');

    final refreshed = await repository.loadWorkspace(session: clanAdminSession);
    final rejectedLogs = refreshed.approvalLogs
        .where((entry) => entry.submissionId == submissionForRejection.id)
        .toList(growable: false);
    expect(rejectedLogs.where((entry) => entry.action == 'vote').length, 2);
    expect(
      rejectedLogs.where((entry) => entry.action == 'finalized').length,
      1,
    );
    expect(
      rejectedLogs.firstWhere((entry) => entry.action == 'finalized').note,
      'Second rejection vote.',
    );
  });

  test('prevents duplicate votes by the same council head', () async {
    final repository = DebugScholarshipRepository.seeded();
    final councilHead = buildCouncilSession(
      memberId: 'member_council_001',
      phoneE164: '+84901111001',
    );
    final snapshot = await repository.loadWorkspace(
      session: buildClanAdminSession(),
    );
    final pending = snapshot.submissions.firstWhere(
      (submission) => submission.status == 'pending',
    );

    await repository.reviewSubmission(
      session: councilHead,
      submissionId: pending.id,
      approved: true,
      reviewNote: 'Initial vote.',
    );

    expect(
      () => repository.reviewSubmission(
        session: councilHead,
        submissionId: pending.id,
        approved: true,
        reviewNote: 'Duplicate vote.',
      ),
      throwsA(
        isA<ScholarshipRepositoryException>().having(
          (error) => error.message,
          'message',
          'duplicate_vote',
        ),
      ),
    );
  });
}
