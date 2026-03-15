import assert from 'node:assert/strict';
import test from 'node:test';

import {
  computeFundBalanceMinor,
  deriveTransactionDeltaMinor,
} from '../funds/fund-balance-recalculation';

test('fund balance contract: derive signed delta from transaction type', () => {
  assert.equal(
    deriveTransactionDeltaMinor({
      transactionType: 'donation',
      amountMinor: 120000,
    }),
    120000,
  );
  assert.equal(
    deriveTransactionDeltaMinor({
      transactionType: 'expense',
      amountMinor: 30000,
    }),
    -30000,
  );
  assert.equal(
    deriveTransactionDeltaMinor({
      transactionType: 'unknown',
      amountMinor: 1000,
    }),
    null,
  );
});

test('fund balance contract: recompute balance from ledger transaction stream', () => {
  const balance = computeFundBalanceMinor([
    { transactionType: 'donation', amountMinor: 1_000_000 },
    { transactionType: 'expense', amountMinor: 250_000 },
    { transactionType: 'donation', amountMinor: 125_000 },
    { transactionType: 'expense', amountMinor: 25_000 },
  ]);

  assert.equal(balance, 850000);
});
