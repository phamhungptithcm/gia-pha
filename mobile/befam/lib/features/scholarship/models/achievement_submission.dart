class ScholarshipApprovalVote {
  const ScholarshipApprovalVote({
    required this.memberId,
    required this.decision,
    required this.createdAtIso,
    this.note,
  });

  final String memberId;
  final String decision;
  final String createdAtIso;
  final String? note;

  bool get isApprove => decision.trim().toLowerCase() == 'approve';
  bool get isReject => decision.trim().toLowerCase() == 'reject';

  Map<String, dynamic> toJson() {
    return {
      'memberId': memberId,
      'decision': decision,
      'createdAt': createdAtIso,
      'note': note,
    };
  }

  factory ScholarshipApprovalVote.fromJson(Map<String, dynamic> json) {
    final nowIso = DateTime.now().toIso8601String();
    return ScholarshipApprovalVote(
      memberId: json['memberId'] as String? ?? '',
      decision: json['decision'] as String? ?? '',
      createdAtIso: _isoFromDynamic(json['createdAt']) ?? nowIso,
      note: json['note'] as String?,
    );
  }
}

class AchievementSubmission {
  const AchievementSubmission({
    required this.id,
    required this.programId,
    required this.awardLevelId,
    required this.clanId,
    required this.memberId,
    required this.studentNameSnapshot,
    required this.title,
    required this.description,
    required this.evidenceUrls,
    required this.status,
    required this.reviewNote,
    required this.reviewedBy,
    required this.reviewedAtIso,
    required this.createdAtIso,
    required this.updatedAtIso,
    this.approvalVotes = const [],
    this.finalDecisionReason,
  });

  final String id;
  final String programId;
  final String awardLevelId;
  final String clanId;
  final String memberId;
  final String studentNameSnapshot;
  final String title;
  final String description;
  final List<String> evidenceUrls;
  final String status;
  final String? reviewNote;
  final String? reviewedBy;
  final String? reviewedAtIso;
  final String createdAtIso;
  final String updatedAtIso;
  final List<ScholarshipApprovalVote> approvalVotes;
  final String? finalDecisionReason;

  bool get isPending => status.trim().toLowerCase() == 'pending';
  bool get isApproved => status.trim().toLowerCase() == 'approved';
  bool get isRejected => status.trim().toLowerCase() == 'rejected';

  int get approvalCount => approvalVotes.where((vote) => vote.isApprove).length;
  int get rejectionCount => approvalVotes.where((vote) => vote.isReject).length;

  AchievementSubmission copyWith({
    String? id,
    String? programId,
    String? awardLevelId,
    String? clanId,
    String? memberId,
    String? studentNameSnapshot,
    String? title,
    String? description,
    List<String>? evidenceUrls,
    String? status,
    String? reviewNote,
    bool clearReviewNote = false,
    String? reviewedBy,
    bool clearReviewedBy = false,
    String? reviewedAtIso,
    bool clearReviewedAtIso = false,
    String? createdAtIso,
    String? updatedAtIso,
    List<ScholarshipApprovalVote>? approvalVotes,
    String? finalDecisionReason,
    bool clearFinalDecisionReason = false,
  }) {
    return AchievementSubmission(
      id: id ?? this.id,
      programId: programId ?? this.programId,
      awardLevelId: awardLevelId ?? this.awardLevelId,
      clanId: clanId ?? this.clanId,
      memberId: memberId ?? this.memberId,
      studentNameSnapshot: studentNameSnapshot ?? this.studentNameSnapshot,
      title: title ?? this.title,
      description: description ?? this.description,
      evidenceUrls: evidenceUrls ?? this.evidenceUrls,
      status: status ?? this.status,
      reviewNote: clearReviewNote ? null : (reviewNote ?? this.reviewNote),
      reviewedBy: clearReviewedBy ? null : (reviewedBy ?? this.reviewedBy),
      reviewedAtIso: clearReviewedAtIso
          ? null
          : (reviewedAtIso ?? this.reviewedAtIso),
      createdAtIso: createdAtIso ?? this.createdAtIso,
      updatedAtIso: updatedAtIso ?? this.updatedAtIso,
      approvalVotes: approvalVotes ?? this.approvalVotes,
      finalDecisionReason: clearFinalDecisionReason
          ? null
          : (finalDecisionReason ?? this.finalDecisionReason),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'programId': programId,
      'awardLevelId': awardLevelId,
      'clanId': clanId,
      'memberId': memberId,
      'studentNameSnapshot': studentNameSnapshot,
      'title': title,
      'description': description,
      'evidenceUrls': evidenceUrls,
      'status': status,
      'reviewNote': reviewNote,
      'reviewedBy': reviewedBy,
      'reviewedAt': reviewedAtIso,
      'approvalVotes': approvalVotes.map((vote) => vote.toJson()).toList(
        growable: false,
      ),
      'finalDecisionReason': finalDecisionReason,
      'createdAt': createdAtIso,
      'updatedAt': updatedAtIso,
    };
  }

  factory AchievementSubmission.fromJson(Map<String, dynamic> json) {
    final nowIso = DateTime.now().toIso8601String();
    return AchievementSubmission(
      id: json['id'] as String? ?? '',
      programId: json['programId'] as String? ?? '',
      awardLevelId: json['awardLevelId'] as String? ?? '',
      clanId: json['clanId'] as String? ?? '',
      memberId: json['memberId'] as String? ?? '',
      studentNameSnapshot: json['studentNameSnapshot'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      evidenceUrls: _asStringList(json['evidenceUrls']),
      status: json['status'] as String? ?? 'pending',
      reviewNote: json['reviewNote'] as String?,
      reviewedBy: json['reviewedBy'] as String?,
      reviewedAtIso: _isoFromDynamic(json['reviewedAt']),
      approvalVotes: _asApprovalVotes(json['approvalVotes']),
      finalDecisionReason: json['finalDecisionReason'] as String?,
      createdAtIso: _isoFromDynamic(json['createdAt']) ?? nowIso,
      updatedAtIso: _isoFromDynamic(json['updatedAt']) ?? nowIso,
    );
  }
}

List<String> _asStringList(dynamic value) {
  if (value is! List) {
    return const [];
  }

  return value
      .whereType<String>()
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

List<ScholarshipApprovalVote> _asApprovalVotes(dynamic value) {
  if (value is! List) {
    return const [];
  }

  final votes = <ScholarshipApprovalVote>[];
  for (final entry in value) {
    if (entry is Map<String, dynamic>) {
      votes.add(ScholarshipApprovalVote.fromJson(entry));
      continue;
    }
    if (entry is Map) {
      votes.add(
        ScholarshipApprovalVote.fromJson(
          entry.map(
            (key, raw) => MapEntry(key.toString(), raw),
          ),
        ),
      );
    }
  }
  return votes;
}

String? _isoFromDynamic(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is DateTime) {
    return value.toIso8601String();
  }

  final dynamic rawValue = value;
  if (rawValue.runtimeType.toString() == 'Timestamp') {
    try {
      final dateTime = rawValue.toDate() as DateTime;
      return dateTime.toIso8601String();
    } catch (_) {
      return null;
    }
  }

  if (value is String) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  return null;
}
