import { FieldValue, Timestamp, type DocumentData } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';

import { APP_REGION, CALLABLE_ENFORCE_APP_CHECK } from '../config/runtime';
import { requireAuth } from '../shared/errors';
import { db } from '../shared/firestore';
import { logInfo } from '../shared/logger';
import {
  GOVERNANCE_ROLES,
  ensureAnyRole,
  ensureClaimedSession,
  ensureClanAccess,
  stringOrNull,
  tokenMemberId,
  tokenPrimaryRole,
} from '../shared/permissions';

type FundRecord = {
  clanId?: string | null;
  branchId?: string | null;
  name?: string | null;
  status?: string | null;
  currency?: string | null;
  balanceMinor?: number | null;
};

const fundsCollection = db.collection('funds');
const transactionsCollection = db.collection('transactions');
const APP_CHECK_CALLABLE_OPTIONS = {
  region: APP_REGION,
  enforceAppCheck: CALLABLE_ENFORCE_APP_CHECK,
} as const;

export const recordFundTransaction = onCall(
  APP_CHECK_CALLABLE_OPTIONS,
  async (request) => {
    const auth = requireAuth(request);
    ensureClaimedSession(auth.token);
    ensureAnyRole(
      auth.token,
      [
        GOVERNANCE_ROLES.superAdmin,
        GOVERNANCE_ROLES.clanAdmin,
        GOVERNANCE_ROLES.treasurer,
      ],
      'Only finance managers can record fund transactions.',
    );

    const fundId = requireNonEmptyString(request.data, 'fundId');
    const transactionType = requireTransactionType(request.data, 'transactionType');
    const amountMinor = requirePositiveInteger(request.data, 'amountMinor');
    const note = optionalString(request.data, 'note') ?? '';
    if (note.length > 280) {
      throw new HttpsError('invalid-argument', 'note must not exceed 280 characters.');
    }
    const memberId = optionalString(request.data, 'memberId');
    const externalReference = optionalString(request.data, 'externalReference');
    const receiptUrl = optionalString(request.data, 'receiptUrl');
    const occurredAt = optionalIsoDate(request.data, 'occurredAt') ?? new Date();
    if (occurredAt.getTime() > Date.now() + 5 * 60_000) {
      throw new HttpsError(
        'invalid-argument',
        'occurredAt cannot be more than 5 minutes in the future.',
      );
    }

    const actorId = tokenMemberId(auth.token) ?? auth.uid;
    const transactionResult = await db.runTransaction(async (transaction) => {
      const fundRef = fundsCollection.doc(fundId);
      const fundSnapshot = await transaction.get(fundRef);
      if (!fundSnapshot.exists || fundSnapshot.data() == null) {
        throw new HttpsError('not-found', 'fund_not_found');
      }

      const fund = fundSnapshot.data() as FundRecord;
      const clanId = stringOrNull(fund.clanId);
      if (clanId == null) {
        throw new HttpsError('failed-precondition', 'fund_missing_clan_context');
      }
      ensureClanAccess(auth.token, clanId);

      const normalizedFundStatus = stringOrNull(fund.status)?.toLowerCase();
      if (
        normalizedFundStatus === 'inactive' ||
        normalizedFundStatus === 'archived' ||
        normalizedFundStatus === 'deleted'
      ) {
        throw new HttpsError(
          'failed-precondition',
          'fund_inactive',
        );
      }

      const currency = normalizeCurrencyCode(fund.currency);
      const currentBalanceMinor = normalizeInteger(fund.balanceMinor);
      if (transactionType === 'expense' && amountMinor > currentBalanceMinor) {
        throw new HttpsError('failed-precondition', 'insufficient_fund_balance');
      }

      const signedAmount = transactionType === 'donation' ? amountMinor : -amountMinor;
      const nextBalanceMinor = currentBalanceMinor + signedAmount;

      const transactionRef = transactionsCollection.doc();
      transaction.set(transactionRef, {
        id: transactionRef.id,
        fundId,
        clanId,
        branchId: stringOrNull(fund.branchId),
        transactionType,
        amountMinor,
        currency,
        memberId,
        externalReference,
        occurredAt: Timestamp.fromDate(occurredAt),
        note,
        receiptUrl,
        createdAt: FieldValue.serverTimestamp(),
        createdBy: actorId,
      });
      transaction.set(
        fundRef,
        {
          balanceMinor: nextBalanceMinor,
          updatedAt: FieldValue.serverTimestamp(),
          updatedBy: actorId,
        },
        { merge: true },
      );

      return {
        fundId,
        clanId,
        branchId: stringOrNull(fund.branchId),
        transactionId: transactionRef.id,
        amountMinor,
        currency,
        transactionType,
        memberId,
        externalReference,
        occurredAtIso: occurredAt.toISOString(),
        note,
        receiptUrl,
        createdBy: actorId,
        balanceMinor: nextBalanceMinor,
      };
    });

    logInfo('recordFundTransaction succeeded', {
      uid: auth.uid,
      actorMemberId: tokenMemberId(auth.token),
      actorRole: tokenPrimaryRole(auth.token),
      clanId: transactionResult.clanId,
      fundId: transactionResult.fundId,
      transactionId: transactionResult.transactionId,
      transactionType: transactionResult.transactionType,
      amountMinor: transactionResult.amountMinor,
      balanceMinor: transactionResult.balanceMinor,
    });

    return {
      fundId: transactionResult.fundId,
      clanId: transactionResult.clanId,
      balanceMinor: transactionResult.balanceMinor,
      transaction: normalizeFirestoreValue({
        id: transactionResult.transactionId,
        fundId: transactionResult.fundId,
        clanId: transactionResult.clanId,
        branchId: transactionResult.branchId,
        transactionType: transactionResult.transactionType,
        amountMinor: transactionResult.amountMinor,
        currency: transactionResult.currency,
        memberId: transactionResult.memberId,
        externalReference: transactionResult.externalReference,
        occurredAt: transactionResult.occurredAtIso,
        note: transactionResult.note,
        receiptUrl: transactionResult.receiptUrl,
        createdAt: transactionResult.occurredAtIso,
        createdBy: transactionResult.createdBy,
      }),
    };
  },
);

function requireNonEmptyString(data: unknown, key: string): string {
  if (data == null || typeof data !== 'object') {
    throw new HttpsError('invalid-argument', `${key} is required.`);
  }
  const value = (data as Record<string, unknown>)[key];
  if (typeof value !== 'string' || value.trim().length === 0) {
    throw new HttpsError('invalid-argument', `${key} is required.`);
  }
  return value.trim();
}

function optionalString(data: unknown, key: string): string | null {
  if (data == null || typeof data !== 'object') {
    return null;
  }
  return stringOrNull((data as Record<string, unknown>)[key]);
}

function requireTransactionType(
  data: unknown,
  key: string,
): 'donation' | 'expense' {
  const value = requireNonEmptyString(data, key).toLowerCase();
  if (value !== 'donation' && value !== 'expense') {
    throw new HttpsError(
      'invalid-argument',
      `${key} must be either donation or expense.`,
    );
  }
  return value;
}

function requirePositiveInteger(data: unknown, key: string): number {
  if (data == null || typeof data !== 'object') {
    throw new HttpsError('invalid-argument', `${key} is required.`);
  }
  const value = (data as Record<string, unknown>)[key];
  if (typeof value !== 'number' || !Number.isFinite(value)) {
    throw new HttpsError('invalid-argument', `${key} must be a number.`);
  }
  const normalized = Math.trunc(value);
  if (normalized <= 0) {
    throw new HttpsError('invalid-argument', `${key} must be greater than zero.`);
  }
  return normalized;
}

function optionalIsoDate(data: unknown, key: string): Date | null {
  const value = optionalString(data, key);
  if (value == null) {
    return null;
  }
  const parsed = new Date(value);
  if (Number.isNaN(parsed.getTime())) {
    throw new HttpsError('invalid-argument', `${key} must be an ISO datetime string.`);
  }
  return parsed;
}

function normalizeCurrencyCode(value: unknown): string {
  const resolved = stringOrNull(value)?.toUpperCase();
  return resolved == null ? 'VND' : resolved;
}

function normalizeInteger(value: unknown): number {
  return typeof value === 'number' && Number.isFinite(value)
    ? Math.trunc(value)
    : 0;
}

function normalizeFirestoreValue(value: unknown): unknown {
  if (value instanceof Timestamp) {
    return value.toDate().toISOString();
  }
  if (Array.isArray(value)) {
    return value.map((entry) => normalizeFirestoreValue(entry));
  }
  if (value != null && typeof value === 'object') {
    const normalized: Record<string, unknown> = {};
    for (const [key, entry] of Object.entries(value as DocumentData)) {
      normalized[key] = normalizeFirestoreValue(entry);
    }
    return normalized;
  }
  return value;
}
