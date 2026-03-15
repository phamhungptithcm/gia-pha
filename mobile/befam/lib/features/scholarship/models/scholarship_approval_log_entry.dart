class ScholarshipApprovalLogEntry {
  const ScholarshipApprovalLogEntry({
    required this.id,
    required this.clanId,
    required this.submissionId,
    required this.action,
    required this.decision,
    required this.actorMemberId,
    required this.actorRole,
    required this.note,
    required this.createdAtIso,
  });

  final String id;
  final String clanId;
  final String submissionId;
  final String action;
  final String? decision;
  final String actorMemberId;
  final String actorRole;
  final String? note;
  final String createdAtIso;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'clanId': clanId,
      'submissionId': submissionId,
      'action': action,
      'decision': decision,
      'actorMemberId': actorMemberId,
      'actorRole': actorRole,
      'note': note,
      'createdAt': createdAtIso,
    };
  }

  factory ScholarshipApprovalLogEntry.fromJson(Map<String, dynamic> json) {
    final nowIso = DateTime.now().toIso8601String();
    return ScholarshipApprovalLogEntry(
      id: json['id'] as String? ?? '',
      clanId: json['clanId'] as String? ?? '',
      submissionId: json['submissionId'] as String? ?? '',
      action: json['action'] as String? ?? '',
      decision: json['decision'] as String?,
      actorMemberId: json['actorMemberId'] as String? ?? '',
      actorRole: json['actorRole'] as String? ?? '',
      note: json['note'] as String?,
      createdAtIso: _isoFromDynamic(json['createdAt']) ?? nowIso,
    );
  }
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
