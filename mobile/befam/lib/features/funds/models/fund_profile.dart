class FundProfile {
  const FundProfile({
    required this.id,
    required this.clanId,
    this.branchId,
    this.appliedMemberIds = const [],
    this.treasurerMemberIds = const [],
    required this.name,
    required this.description,
    required this.fundType,
    required this.currency,
    required this.balanceMinor,
    required this.status,
  });

  final String id;
  final String clanId;
  final String? branchId;
  final List<String> appliedMemberIds;
  final List<String> treasurerMemberIds;
  final String name;
  final String description;
  final String fundType;
  final String currency;
  final int balanceMinor;
  final String status;

  bool get isActive => status.trim().toLowerCase() == 'active';

  FundProfile copyWith({
    String? id,
    String? clanId,
    String? branchId,
    bool clearBranchId = false,
    List<String>? appliedMemberIds,
    List<String>? treasurerMemberIds,
    String? name,
    String? description,
    String? fundType,
    String? currency,
    int? balanceMinor,
    String? status,
  }) {
    return FundProfile(
      id: id ?? this.id,
      clanId: clanId ?? this.clanId,
      branchId: clearBranchId ? null : (branchId ?? this.branchId),
      appliedMemberIds: appliedMemberIds == null
          ? this.appliedMemberIds
          : List<String>.unmodifiable(appliedMemberIds),
      treasurerMemberIds: treasurerMemberIds == null
          ? this.treasurerMemberIds
          : List<String>.unmodifiable(treasurerMemberIds),
      name: name ?? this.name,
      description: description ?? this.description,
      fundType: fundType ?? this.fundType,
      currency: currency ?? this.currency,
      balanceMinor: balanceMinor ?? this.balanceMinor,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'clanId': clanId,
      'branchId': branchId,
      'appliedMemberIds': appliedMemberIds,
      'treasurerMemberIds': treasurerMemberIds,
      'name': name,
      'description': description,
      'fundType': fundType,
      'currency': currency,
      'balanceMinor': balanceMinor,
      'status': status,
    };
  }

  factory FundProfile.fromJson(Map<String, dynamic> json) {
    return FundProfile(
      id: json['id'] as String? ?? '',
      clanId: json['clanId'] as String? ?? '',
      branchId: _nullableString(json['branchId']),
      appliedMemberIds: _asStringList(json['appliedMemberIds']),
      treasurerMemberIds: _asStringList(json['treasurerMemberIds']),
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      fundType: json['fundType'] as String? ?? 'custom',
      currency: (json['currency'] as String? ?? 'VND').trim().toUpperCase(),
      balanceMinor: _asInt(json['balanceMinor']),
      status: json['status'] as String? ?? 'active',
    );
  }
}

String? _nullableString(Object? value) {
  final text = value is String ? value.trim() : '';
  return text.isEmpty ? null : text;
}

int _asInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is double) {
    return value.round();
  }
  if (value is String) {
    return int.tryParse(value) ?? 0;
  }
  return 0;
}

List<String> _asStringList(Object? value) {
  if (value is! List) {
    return const [];
  }
  return value
      .whereType<String>()
      .map((entry) => entry.trim())
      .where((entry) => entry.isNotEmpty)
      .toList(growable: false);
}
