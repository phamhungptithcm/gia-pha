class AwardLevel {
  const AwardLevel({
    required this.id,
    required this.programId,
    required this.clanId,
    required this.name,
    required this.description,
    required this.sortOrder,
    required this.rewardType,
    required this.rewardAmountMinor,
    required this.criteriaText,
    required this.status,
    required this.createdAtIso,
  });

  final String id;
  final String programId;
  final String clanId;
  final String name;
  final String description;
  final int sortOrder;
  final String rewardType;
  final int rewardAmountMinor;
  final String criteriaText;
  final String status;
  final String createdAtIso;

  AwardLevel copyWith({
    String? id,
    String? programId,
    String? clanId,
    String? name,
    String? description,
    int? sortOrder,
    String? rewardType,
    int? rewardAmountMinor,
    String? criteriaText,
    String? status,
    String? createdAtIso,
  }) {
    return AwardLevel(
      id: id ?? this.id,
      programId: programId ?? this.programId,
      clanId: clanId ?? this.clanId,
      name: name ?? this.name,
      description: description ?? this.description,
      sortOrder: sortOrder ?? this.sortOrder,
      rewardType: rewardType ?? this.rewardType,
      rewardAmountMinor: rewardAmountMinor ?? this.rewardAmountMinor,
      criteriaText: criteriaText ?? this.criteriaText,
      status: status ?? this.status,
      createdAtIso: createdAtIso ?? this.createdAtIso,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'programId': programId,
      'clanId': clanId,
      'name': name,
      'description': description,
      'sortOrder': sortOrder,
      'rewardType': rewardType,
      'rewardAmountMinor': rewardAmountMinor,
      'criteriaText': criteriaText,
      'status': status,
      'createdAt': createdAtIso,
    };
  }

  factory AwardLevel.fromJson(Map<String, dynamic> json) {
    return AwardLevel(
      id: json['id'] as String? ?? '',
      programId: json['programId'] as String? ?? '',
      clanId: json['clanId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      sortOrder: _parseInt(json['sortOrder']),
      rewardType: json['rewardType'] as String? ?? 'cash',
      rewardAmountMinor: _parseInt(json['rewardAmountMinor']),
      criteriaText: json['criteriaText'] as String? ?? '',
      status: json['status'] as String? ?? 'active',
      createdAtIso:
          _isoFromDynamic(json['createdAt']) ??
          DateTime.now().toIso8601String(),
    );
  }
}

int _parseInt(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value.trim()) ?? 0;
  }
  return 0;
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
