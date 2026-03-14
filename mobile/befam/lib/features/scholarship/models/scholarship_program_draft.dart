class ScholarshipProgramDraft {
  const ScholarshipProgramDraft({
    required this.title,
    required this.description,
    required this.year,
    required this.status,
    required this.submissionOpenAtIso,
    required this.submissionCloseAtIso,
    required this.reviewCloseAtIso,
  });

  const ScholarshipProgramDraft.empty()
    : title = '',
      description = '',
      year = 0,
      status = 'open',
      submissionOpenAtIso = null,
      submissionCloseAtIso = null,
      reviewCloseAtIso = null;

  final String title;
  final String description;
  final int year;
  final String status;
  final String? submissionOpenAtIso;
  final String? submissionCloseAtIso;
  final String? reviewCloseAtIso;

  ScholarshipProgramDraft copyWith({
    String? title,
    String? description,
    int? year,
    String? status,
    String? submissionOpenAtIso,
    bool clearSubmissionOpenAtIso = false,
    String? submissionCloseAtIso,
    bool clearSubmissionCloseAtIso = false,
    String? reviewCloseAtIso,
    bool clearReviewCloseAtIso = false,
  }) {
    return ScholarshipProgramDraft(
      title: title ?? this.title,
      description: description ?? this.description,
      year: year ?? this.year,
      status: status ?? this.status,
      submissionOpenAtIso: clearSubmissionOpenAtIso
          ? null
          : (submissionOpenAtIso ?? this.submissionOpenAtIso),
      submissionCloseAtIso: clearSubmissionCloseAtIso
          ? null
          : (submissionCloseAtIso ?? this.submissionCloseAtIso),
      reviewCloseAtIso: clearReviewCloseAtIso
          ? null
          : (reviewCloseAtIso ?? this.reviewCloseAtIso),
    );
  }
}
