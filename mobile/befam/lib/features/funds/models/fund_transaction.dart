enum FundTransactionType {
  donation,
  expense;

  String get jsonValue => name;

  String get label {
    return switch (this) {
      FundTransactionType.donation => 'Donation',
      FundTransactionType.expense => 'Expense',
    };
  }

  static FundTransactionType fromJsonValue(String? value) {
    return switch (value?.trim().toLowerCase()) {
      'expense' => FundTransactionType.expense,
      _ => FundTransactionType.donation,
    };
  }
}

class FundTransaction {
  const FundTransaction({
    required this.id,
    required this.fundId,
    required this.clanId,
    this.branchId,
    required this.transactionType,
    required this.amountMinor,
    required this.currency,
    this.memberId,
    this.externalReference,
    required this.occurredAt,
    required this.note,
    this.receiptUrl,
    this.createdAt,
    this.createdBy,
  });

  final String id;
  final String fundId;
  final String clanId;
  final String? branchId;
  final FundTransactionType transactionType;
  final int amountMinor;
  final String currency;
  final String? memberId;
  final String? externalReference;
  final DateTime occurredAt;
  final String note;
  final String? receiptUrl;
  final DateTime? createdAt;
  final String? createdBy;

  bool get isDonation => transactionType == FundTransactionType.donation;
  bool get isExpense => transactionType == FundTransactionType.expense;

  int get signedAmountMinor => isDonation ? amountMinor : -amountMinor;

  FundTransaction copyWith({
    String? id,
    String? fundId,
    String? clanId,
    String? branchId,
    bool clearBranchId = false,
    FundTransactionType? transactionType,
    int? amountMinor,
    String? currency,
    String? memberId,
    bool clearMemberId = false,
    String? externalReference,
    bool clearExternalReference = false,
    DateTime? occurredAt,
    String? note,
    String? receiptUrl,
    bool clearReceiptUrl = false,
    DateTime? createdAt,
    bool clearCreatedAt = false,
    String? createdBy,
    bool clearCreatedBy = false,
  }) {
    return FundTransaction(
      id: id ?? this.id,
      fundId: fundId ?? this.fundId,
      clanId: clanId ?? this.clanId,
      branchId: clearBranchId ? null : (branchId ?? this.branchId),
      transactionType: transactionType ?? this.transactionType,
      amountMinor: amountMinor ?? this.amountMinor,
      currency: currency ?? this.currency,
      memberId: clearMemberId ? null : (memberId ?? this.memberId),
      externalReference: clearExternalReference
          ? null
          : (externalReference ?? this.externalReference),
      occurredAt: occurredAt ?? this.occurredAt,
      note: note ?? this.note,
      receiptUrl: clearReceiptUrl ? null : (receiptUrl ?? this.receiptUrl),
      createdAt: clearCreatedAt ? null : (createdAt ?? this.createdAt),
      createdBy: clearCreatedBy ? null : (createdBy ?? this.createdBy),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fundId': fundId,
      'clanId': clanId,
      'branchId': branchId,
      'transactionType': transactionType.jsonValue,
      'amountMinor': amountMinor,
      'currency': currency,
      'memberId': memberId,
      'externalReference': externalReference,
      'occurredAt': occurredAt.toUtc().toIso8601String(),
      'note': note,
      'receiptUrl': receiptUrl,
      'createdAt': createdAt?.toUtc().toIso8601String(),
      'createdBy': createdBy,
    };
  }

  factory FundTransaction.fromJson(Map<String, dynamic> json) {
    return FundTransaction(
      id: json['id'] as String? ?? '',
      fundId: json['fundId'] as String? ?? '',
      clanId: json['clanId'] as String? ?? '',
      branchId: _nullableString(json['branchId']),
      transactionType: FundTransactionType.fromJsonValue(
        json['transactionType'] as String?,
      ),
      amountMinor: _asInt(json['amountMinor']),
      currency: (json['currency'] as String? ?? 'VND').trim().toUpperCase(),
      memberId: _nullableString(json['memberId']),
      externalReference: _nullableString(json['externalReference']),
      occurredAt: _parseDateTime(
        json['occurredAt'],
        fallback: DateTime.now().toUtc(),
      ),
      note: json['note'] as String? ?? '',
      receiptUrl: _nullableString(json['receiptUrl']),
      createdAt: _parseNullableDateTime(json['createdAt']),
      createdBy: _nullableString(json['createdBy']),
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

DateTime? _parseNullableDateTime(Object? value) {
  if (value == null) {
    return null;
  }
  return _parseDateTime(value, fallback: DateTime.now().toUtc());
}

DateTime _parseDateTime(Object? value, {required DateTime fallback}) {
  if (value is DateTime) {
    return value.toUtc();
  }
  if (value is String) {
    final parsed = DateTime.tryParse(value);
    if (parsed != null) {
      return parsed.toUtc();
    }
  }
  return fallback;
}
