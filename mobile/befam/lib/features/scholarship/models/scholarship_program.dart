class ScholarshipProgram {
  const ScholarshipProgram({
    required this.id,
    required this.clanId,
    required this.title,
    required this.description,
    required this.year,
    required this.status,
    required this.submissionOpenAtIso,
    required this.submissionCloseAtIso,
    required this.reviewCloseAtIso,
    required this.createdAtIso,
    required this.createdBy,
  });

  final String id;
  final String clanId;
  final String title;
  final String description;
  final int year;
  final String status;
  final String? submissionOpenAtIso;
  final String? submissionCloseAtIso;
  final String? reviewCloseAtIso;
  final String createdAtIso;
  final String createdBy;

  bool get isOpen => status.trim().toLowerCase() == 'open';

  ScholarshipProgram copyWith({
    String? id,
    String? clanId,
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
    String? createdAtIso,
    String? createdBy,
  }) {
    return ScholarshipProgram(
      id: id ?? this.id,
      clanId: clanId ?? this.clanId,
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
      createdAtIso: createdAtIso ?? this.createdAtIso,
      createdBy: createdBy ?? this.createdBy,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'clanId': clanId,
      'title': title,
      'description': description,
      'year': year,
      'status': status,
      'submissionOpenAt': submissionOpenAtIso,
      'submissionCloseAt': submissionCloseAtIso,
      'reviewCloseAt': reviewCloseAtIso,
      'createdAt': createdAtIso,
      'createdBy': createdBy,
    };
  }

  factory ScholarshipProgram.fromJson(Map<String, dynamic> json) {
    return ScholarshipProgram(
      id: json['id'] as String? ?? '',
      clanId: json['clanId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      year: _parseYear(json['year']),
      status: json['status'] as String? ?? 'open',
      submissionOpenAtIso: _isoFromDynamic(json['submissionOpenAt']),
      submissionCloseAtIso: _isoFromDynamic(json['submissionCloseAt']),
      reviewCloseAtIso: _isoFromDynamic(json['reviewCloseAt']),
      createdAtIso:
          _isoFromDynamic(json['createdAt']) ??
          DateTime.now().toIso8601String(),
      createdBy: json['createdBy'] as String? ?? '',
    );
  }
}

int _parseYear(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value.trim()) ?? DateTime.now().year;
  }
  return DateTime.now().year;
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
