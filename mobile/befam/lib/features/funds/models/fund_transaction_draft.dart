import 'fund_transaction.dart';

class FundTransactionDraft {
  const FundTransactionDraft({
    required this.fundId,
    required this.transactionType,
    required this.amountInput,
    required this.currency,
    required this.occurredAt,
    required this.note,
    this.memberId,
    this.externalReference,
    this.receiptUrl,
  });

  final String fundId;
  final FundTransactionType transactionType;
  final String amountInput;
  final String currency;
  final DateTime occurredAt;
  final String note;
  final String? memberId;
  final String? externalReference;
  final String? receiptUrl;

  factory FundTransactionDraft.empty({
    required String fundId,
    required FundTransactionType transactionType,
    required String currency,
  }) {
    return FundTransactionDraft(
      fundId: fundId,
      transactionType: transactionType,
      amountInput: '',
      currency: currency,
      occurredAt: DateTime.now(),
      note: '',
    );
  }

  FundTransactionDraft copyWith({
    String? fundId,
    FundTransactionType? transactionType,
    String? amountInput,
    String? currency,
    DateTime? occurredAt,
    String? note,
    String? memberId,
    bool clearMemberId = false,
    String? externalReference,
    bool clearExternalReference = false,
    String? receiptUrl,
    bool clearReceiptUrl = false,
  }) {
    return FundTransactionDraft(
      fundId: fundId ?? this.fundId,
      transactionType: transactionType ?? this.transactionType,
      amountInput: amountInput ?? this.amountInput,
      currency: currency ?? this.currency,
      occurredAt: occurredAt ?? this.occurredAt,
      note: note ?? this.note,
      memberId: clearMemberId ? null : (memberId ?? this.memberId),
      externalReference: clearExternalReference
          ? null
          : (externalReference ?? this.externalReference),
      receiptUrl: clearReceiptUrl ? null : (receiptUrl ?? this.receiptUrl),
    );
  }
}
