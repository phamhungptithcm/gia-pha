import '../models/fund_transaction.dart';
import 'currency_minor_units.dart';

enum FundTransactionValidationErrorCode {
  fundRequired,
  unsupportedCurrency,
  amountNotPositive,
  insufficientBalance,
  occurredAtInFuture,
  noteTooLong,
}

class FundTransactionValidationException implements Exception {
  const FundTransactionValidationException(this.code, [this.message]);

  final FundTransactionValidationErrorCode code;
  final String? message;

  @override
  String toString() => message ?? code.name;
}

void validateFundTransactionInput({
  required String fundId,
  required FundTransactionType transactionType,
  required int amountMinor,
  required int currentBalanceMinor,
  required String currency,
  required DateTime occurredAt,
  String? note,
  DateTime? now,
}) {
  if (fundId.trim().isEmpty) {
    throw const FundTransactionValidationException(
      FundTransactionValidationErrorCode.fundRequired,
    );
  }

  final normalizedCurrency = CurrencyMinorUnits.normalizeCurrencyCode(currency);
  if (!CurrencyMinorUnits.isValidCurrencyCode(normalizedCurrency)) {
    throw const FundTransactionValidationException(
      FundTransactionValidationErrorCode.unsupportedCurrency,
    );
  }

  if (amountMinor <= 0) {
    throw const FundTransactionValidationException(
      FundTransactionValidationErrorCode.amountNotPositive,
    );
  }

  if (transactionType == FundTransactionType.expense &&
      amountMinor > currentBalanceMinor) {
    throw const FundTransactionValidationException(
      FundTransactionValidationErrorCode.insufficientBalance,
    );
  }

  final currentTime = now?.toUtc() ?? DateTime.now().toUtc();
  if (occurredAt.toUtc().isAfter(currentTime.add(const Duration(minutes: 5)))) {
    throw const FundTransactionValidationException(
      FundTransactionValidationErrorCode.occurredAtInFuture,
    );
  }

  if ((note ?? '').trim().length > 280) {
    throw const FundTransactionValidationException(
      FundTransactionValidationErrorCode.noteTooLong,
    );
  }
}
