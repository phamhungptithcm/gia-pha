class ScholarshipDisbursementFund {
  const ScholarshipDisbursementFund({
    required this.id,
    required this.clanId,
    required this.name,
    required this.currency,
    required this.balanceMinor,
    required this.fundType,
    required this.status,
  });

  final String id;
  final String clanId;
  final String name;
  final String currency;
  final int balanceMinor;
  final String fundType;
  final String status;

  bool get isActive {
    final normalized = status.trim().toLowerCase();
    if (normalized.isEmpty) {
      return true;
    }
    return normalized != 'inactive' &&
        normalized != 'archived' &&
        normalized != 'deleted';
  }

  factory ScholarshipDisbursementFund.fromJson(Map<String, dynamic> json) {
    return ScholarshipDisbursementFund(
      id: (json['id'] as String? ?? '').trim(),
      clanId: (json['clanId'] as String? ?? '').trim(),
      name: (json['name'] as String? ?? '').trim(),
      currency: (json['currency'] as String? ?? 'VND').trim().toUpperCase(),
      balanceMinor: _asInt(json['balanceMinor']),
      fundType: (json['fundType'] as String? ?? 'custom').trim().toLowerCase(),
      status: (json['status'] as String? ?? 'active').trim(),
    );
  }
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
