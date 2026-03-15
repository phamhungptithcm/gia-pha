import 'achievement_submission.dart';
import 'award_level.dart';
import 'scholarship_approval_log_entry.dart';
import 'scholarship_program.dart';

class ScholarshipWorkspaceSnapshot {
  const ScholarshipWorkspaceSnapshot({
    required this.programs,
    required this.awardLevels,
    required this.submissions,
    required this.memberNamesById,
    required this.approvalLogs,
    required this.councilHeadMemberIds,
  });

  final List<ScholarshipProgram> programs;
  final List<AwardLevel> awardLevels;
  final List<AchievementSubmission> submissions;
  final Map<String, String> memberNamesById;
  final List<ScholarshipApprovalLogEntry> approvalLogs;
  final List<String> councilHeadMemberIds;
}
