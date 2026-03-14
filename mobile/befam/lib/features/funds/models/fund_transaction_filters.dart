import 'fund_transaction.dart';

class FundTransactionFilters {
  const FundTransactionFilters({
    this.query = '',
    this.transactionType,
    this.from,
    this.to,
  });

  final String query;
  final FundTransactionType? transactionType;
  final DateTime? from;
  final DateTime? to;

  FundTransactionFilters copyWith({
    String? query,
    FundTransactionType? transactionType,
    bool clearTransactionType = false,
    DateTime? from,
    bool clearFrom = false,
    DateTime? to,
    bool clearTo = false,
  }) {
    return FundTransactionFilters(
      query: query ?? this.query,
      transactionType: clearTransactionType
          ? null
          : (transactionType ?? this.transactionType),
      from: clearFrom ? null : (from ?? this.from),
      to: clearTo ? null : (to ?? this.to),
    );
  }
}
