import { onDocumentCreated } from 'firebase-functions/v2/firestore';

import { APP_REGION } from '../config/runtime';
import { recalculateFundBalanceFromTransaction } from './fund-balance-recalculation';
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

    await recalculateFundBalanceFromTransaction({
      transactionId: event.params.transactionId,
      transaction: snapshot.data(),
      source: 'function:onTransactionCreated',
    });
  },
);
