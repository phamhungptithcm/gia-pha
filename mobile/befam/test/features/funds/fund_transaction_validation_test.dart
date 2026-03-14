import 'package:befam/features/funds/models/fund_transaction.dart';
import 'package:befam/features/funds/services/fund_transaction_validation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('rejects non-positive amounts', () {
    expect(
      () => validateFundTransactionInput(
        fundId: 'fund_demo_001',
        transactionType: FundTransactionType.donation,
        amountMinor: 0,
        currentBalanceMinor: 500000,
        currency: 'VND',
        occurredAt: DateTime.utc(2026, 3, 14),
        now: DateTime.utc(2026, 3, 14, 0, 30),
      ),
      throwsA(
        isA<FundTransactionValidationException>().having(
          (error) => error.code,
          'code',
          FundTransactionValidationErrorCode.amountNotPositive,
        ),
      ),
    );
  });

  test('rejects expense over current balance', () {
    expect(
      () => validateFundTransactionInput(
        fundId: 'fund_demo_001',
        transactionType: FundTransactionType.expense,
        amountMinor: 900000,
        currentBalanceMinor: 100000,
        currency: 'VND',
        occurredAt: DateTime.utc(2026, 3, 14),
        now: DateTime.utc(2026, 3, 14, 0, 30),
      ),
      throwsA(
        isA<FundTransactionValidationException>().having(
          (error) => error.code,
          'code',
          FundTransactionValidationErrorCode.insufficientBalance,
        ),
      ),
    );
  });

  test('rejects transactions in the future', () {
    expect(
      () => validateFundTransactionInput(
        fundId: 'fund_demo_001',
        transactionType: FundTransactionType.donation,
        amountMinor: 100000,
        currentBalanceMinor: 100000,
        currency: 'VND',
        occurredAt: DateTime.utc(2026, 3, 15, 1, 0),
        now: DateTime.utc(2026, 3, 14, 1, 0),
      ),
      throwsA(
        isA<FundTransactionValidationException>().having(
          (error) => error.code,
          'code',
          FundTransactionValidationErrorCode.occurredAtInFuture,
        ),
      ),
    );
  });
}
