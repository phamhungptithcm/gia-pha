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

  bool get isPending => status.trim().toLowerCase() == 'pending';
  bool get isApproved => status.trim().toLowerCase() == 'approved';
  bool get isRejected => status.trim().toLowerCase() == 'rejected';

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
