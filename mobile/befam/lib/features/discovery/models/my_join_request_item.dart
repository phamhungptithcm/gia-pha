class MyJoinRequestItem {
  const MyJoinRequestItem({
    required this.id,
    required this.clanId,
    required this.status,
    required this.submittedAtEpochMs,
    this.reviewedAtEpochMs,
    this.canceledAtEpochMs,
    required this.canCancel,
  });

  final String id;
  final String clanId;
  final String status;
  final int submittedAtEpochMs;
  final int? reviewedAtEpochMs;
  final int? canceledAtEpochMs;
  final bool canCancel;

  bool get isPending => status.trim().toLowerCase() == 'pending';

  factory MyJoinRequestItem.fromJson(Map<String, dynamic> json) {
    final id = (json['id'] as String? ?? '').trim();
    return MyJoinRequestItem(
      id: id,
      clanId: (json['clanId'] as String? ?? '').trim(),
      status: (json['status'] as String? ?? 'pending').trim().toLowerCase(),
      submittedAtEpochMs: _parseEpochMs(json['submittedAtEpochMs']) ?? 0,
      reviewedAtEpochMs: _parseEpochMs(json['reviewedAtEpochMs']),
      canceledAtEpochMs: _parseEpochMs(json['canceledAtEpochMs']),
      canCancel: json['canCancel'] == true,
    );
  }
}

int? _parseEpochMs(Object? rawValue) {
  if (rawValue == null) {
    return null;
  }
  if (rawValue is int) {
    return rawValue;
  }
  if (rawValue is num) {
    return rawValue.toInt();
  }
  if (rawValue is String) {
    final parsedInt = int.tryParse(rawValue);
    if (parsedInt != null) {
      return parsedInt;
    }
    final parsedDate = DateTime.tryParse(rawValue);
    return parsedDate?.millisecondsSinceEpoch;
  }
  return null;
}
