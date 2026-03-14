import 'achievement_submission.dart';
import 'award_level.dart';
import 'scholarship_program.dart';

class ScholarshipWorkspaceSnapshot {
  const ScholarshipWorkspaceSnapshot({
    required this.programs,
    required this.awardLevels,
    required this.submissions,
    required this.memberNamesById,
  });

  final List<ScholarshipProgram> programs;
  final List<AwardLevel> awardLevels;
  final List<AchievementSubmission> submissions;
  final Map<String, String> memberNamesById;
}
