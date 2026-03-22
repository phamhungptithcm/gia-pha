import { FieldValue } from 'firebase-admin/firestore';

import { db } from '../shared/firestore';
import { logInfo, logWarn } from '../shared/logger';

type TransactionRecord = {
  clanId?: string | null;
  fundId?: string | null;
  transactionType?: string | null;
  amountMinor?: number | null;
};

type FundRecord = {
  clanId?: string | null;
  balanceMinor?: number | null;
};

type RecalculationInput = {
  transactionId: string;
  transaction: TransactionRecord;
  source: string;
};

type RecalculationResult = {
  recalculated: boolean;
  reason?: string;
  clanId?: string;
  fundId?: string;
  deltaMinor?: number;
};

/**
 * Applies an incremental balance update for a single new transaction.
 * Uses FieldValue.increment to avoid reading the full transaction ledger —
 * O(1) reads+writes regardless of fund history size.
 *
 * Use fullRecalculateFundBalance() for admin reconciliation only.
 */
export async function recalculateFundBalanceFromTransaction(
  input: RecalculationInput,
): Promise<RecalculationResult> {
  const clanId = normalizeId(input.transaction.clanId);
  const fundId = normalizeId(input.transaction.fundId);
  if (clanId == null || fundId == null) {
    logWarn('fund balance update skipped due to malformed transaction', {
      source: input.source,
      transactionId: input.transactionId,
      clanId: input.transaction.clanId ?? null,
      fundId: input.transaction.fundId ?? null,
    });
    return { recalculated: false, reason: 'malformed_transaction' };
  }

  const delta = deriveTransactionDeltaMinor(input.transaction);
  if (delta == null) {
    logWarn('fund balance update skipped due to unsupported transaction type', {
      source: input.source,
      transactionId: input.transactionId,
      transactionType: input.transaction.transactionType ?? null,
      fundId,
      clanId,
    });
    return { recalculated: false, reason: 'unsupported_transaction_type', clanId, fundId };
  }

  const fundRef = db.collection('funds').doc(fundId);
  const fundSnapshot = await fundRef.get();
  if (!fundSnapshot.exists) {
    logWarn('fund balance update skipped because fund is missing', {
      source: input.source,
      transactionId: input.transactionId,
      fundId,
      clanId,
    });
    return { recalculated: false, reason: 'fund_not_found', clanId, fundId };
  }

  const fund = (fundSnapshot.data() ?? {}) as FundRecord;
  const fundClanId = normalizeId(fund.clanId);
  if (fundClanId != null && fundClanId !== clanId) {
    logWarn('fund balance update skipped due to clan mismatch', {
      source: input.source,
      transactionId: input.transactionId,
      transactionClanId: clanId,
      fundClanId,
      fundId,
    });
    return { recalculated: false, reason: 'clan_mismatch', clanId, fundId };
  }

  await fundRef.set(
    {
      balanceMinor: FieldValue.increment(delta),
      transactionCount: FieldValue.increment(1),
      updatedAt: FieldValue.serverTimestamp(),
      updatedBy: input.source,
      lastRecalculatedAt: FieldValue.serverTimestamp(),
      lastRecalculatedBy: input.source,
    },
    { merge: true },
  );

  logInfo('fund balance incremented', {
    source: input.source,
    transactionId: input.transactionId,
    clanId,
    fundId,
    deltaMinor: delta,
  });

  return { recalculated: true, clanId, fundId, deltaMinor: delta };
}

/**
 * Full ledger recompute for admin reconciliation only. Never call from triggers.
 * Reads every transaction for the fund — cost grows with history size.
 */
export async function fullRecalculateFundBalance(
  fundId: string,
  source: string,
): Promise<{ recalculated: boolean; reason?: string; transactionCount?: number; recomputedBalanceMinor?: number }> {
  const fundRef = db.collection('funds').doc(fundId);
  const fundSnapshot = await fundRef.get();
  if (!fundSnapshot.exists) {
    return { recalculated: false, reason: 'fund_not_found' };
  }

  const fund = (fundSnapshot.data() ?? {}) as FundRecord;
  const clanId = normalizeId(fund.clanId);

  const transactionSnapshot = await db
    .collection('transactions')
    .where('fundId', '==', fundId)
    .get();
  const ledger = transactionSnapshot.docs
    .map((doc) => doc.data() as TransactionRecord)
    .filter((entry) => normalizeId(entry.clanId) == null || normalizeId(entry.clanId) === clanId);

  const recomputedBalanceMinor = computeFundBalanceMinor(ledger);
  await fundRef.set(
    {
      balanceMinor: recomputedBalanceMinor,
      transactionCount: ledger.length,
      updatedAt: FieldValue.serverTimestamp(),
      updatedBy: source,
      lastRecalculatedAt: FieldValue.serverTimestamp(),
      lastRecalculatedBy: source,
    },
    { merge: true },
  );

  logInfo('fund balance fully recomputed', { source, fundId, transactionCount: ledger.length, recomputedBalanceMinor });
  return { recalculated: true, transactionCount: ledger.length, recomputedBalanceMinor };
}

export function computeFundBalanceMinor(
  transactions: Iterable<TransactionRecord>,
): number {
  let balance = 0;
  for (const transaction of transactions) {
    const delta = deriveTransactionDeltaMinor(transaction);
    if (delta != null) {
      balance += delta;
    }
  }
  return balance;
}

export function deriveTransactionDeltaMinor(
  transaction: TransactionRecord,
): number | null {
  const amountMinor = normalizeAmount(transaction.amountMinor);
  if (amountMinor <= 0) {
    return null;
  }

  if (transaction.transactionType === 'donation') {
    return amountMinor;
  }
  if (transaction.transactionType === 'expense') {
    return -amountMinor;
  }

  return null;
}

function normalizeId(value: unknown): string | null {
  if (typeof value !== 'string') {
    return null;
  }
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}

function normalizeAmount(value: unknown): number {
  return typeof value === 'number' && Number.isFinite(value)
    ? Math.trunc(value)
    : 0;
}
