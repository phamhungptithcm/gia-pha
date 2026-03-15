import { onDocumentCreated } from 'firebase-functions/v2/firestore';

import { APP_REGION } from '../config/runtime';
import {
  deriveTransactionDeltaMinor,
  recalculateFundBalanceFromTransaction,
} from './fund-balance-recalculation';
import { logWarn } from '../shared/logger';

export const onTransactionCreated = onDocumentCreated(
  {
    document: 'transactions/{transactionId}',
    region: APP_REGION,
  },
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) {
      logWarn('transaction create trigger received no snapshot', {
        transactionId: event.params.transactionId,
      });
      return;
    }

    const data = snapshot.data();
    const derivedDeltaMinor = deriveTransactionDeltaMinor(data);
    await recalculateFundBalanceFromTransaction({
      transactionId: event.params.transactionId,
      transaction: data,
      source: 'function:onTransactionCreated',
    });

    if (derivedDeltaMinor == null) {
      logWarn('transaction trigger received unsupported transaction payload', {
        transactionId: event.params.transactionId,
        transactionType: data.transactionType ?? null,
        amountMinor: data.amountMinor ?? null,
      });
    }
  },
);
