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
  transactionCount?: number;
  previousBalanceMinor?: number;
  recomputedBalanceMinor?: number;
};

export async function recalculateFundBalanceFromTransaction(
  input: RecalculationInput,
): Promise<RecalculationResult> {
  const clanId = normalizeId(input.transaction.clanId);
  const fundId = normalizeId(input.transaction.fundId);
  if (clanId == null || fundId == null) {
    logWarn('fund balance recalculation skipped due to malformed transaction', {
      source: input.source,
      transactionId: input.transactionId,
      clanId: input.transaction.clanId ?? null,
      fundId: input.transaction.fundId ?? null,
    });
    return { recalculated: false, reason: 'malformed_transaction' };
  }

  const fundRef = db.collection('funds').doc(fundId);
  const fundSnapshot = await fundRef.get();
  if (!fundSnapshot.exists) {
    logWarn('fund balance recalculation skipped because fund is missing', {
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
    logWarn('fund balance recalculation skipped due to clan mismatch', {
      source: input.source,
      transactionId: input.transactionId,
      transactionClanId: clanId,
      fundClanId,
      fundId,
    });
    return { recalculated: false, reason: 'clan_mismatch', clanId, fundId };
  }

  const transactionSnapshot = await db
    .collection('transactions')
    .where('fundId', '==', fundId)
    .get();
  const ledger = transactionSnapshot.docs
    .map((doc) => doc.data() as TransactionRecord)
    .filter(
      (entry) => normalizeId(entry.clanId) == null || normalizeId(entry.clanId) === clanId,
    );

  const recomputedBalanceMinor = computeFundBalanceMinor(ledger);
  const previousBalanceMinor = normalizeAmount(fund.balanceMinor);
  await fundRef.set(
    {
      balanceMinor: recomputedBalanceMinor,
      updatedAt: FieldValue.serverTimestamp(),
      updatedBy: input.source,
      lastRecalculatedAt: FieldValue.serverTimestamp(),
      lastRecalculatedBy: input.source,
      transactionCount: ledger.length,
    },
    { merge: true },
  );

  logInfo('fund balance recalculated', {
    source: input.source,
    transactionId: input.transactionId,
    clanId,
    fundId,
    transactionCount: ledger.length,
    previousBalanceMinor,
    recomputedBalanceMinor,
  });

  return {
    recalculated: true,
    clanId,
    fundId,
    transactionCount: ledger.length,
    previousBalanceMinor,
    recomputedBalanceMinor,
  };
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
