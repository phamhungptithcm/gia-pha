class AchievementSubmissionDraft {
  const AchievementSubmissionDraft({
    required this.programId,
    required this.awardLevelId,
    required this.studentName,
    required this.title,
    required this.description,
    required this.evidenceUrls,
  });

  const AchievementSubmissionDraft.empty({required this.programId})
    : awardLevelId = '',
      studentName = '',
      title = '',
      description = '',
      evidenceUrls = const [];

  final String programId;
  final String awardLevelId;
  final String studentName;
  final String title;
  final String description;
  final List<String> evidenceUrls;

  AchievementSubmissionDraft copyWith({
    String? programId,
    String? awardLevelId,
    String? studentName,
    String? title,
    String? description,
    List<String>? evidenceUrls,
  }) {
    return AchievementSubmissionDraft(
      programId: programId ?? this.programId,
      awardLevelId: awardLevelId ?? this.awardLevelId,
      studentName: studentName ?? this.studentName,
      title: title ?? this.title,
      description: description ?? this.description,
      evidenceUrls: evidenceUrls ?? this.evidenceUrls,
    );
  }
}
