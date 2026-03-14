import { onDocumentCreated } from 'firebase-functions/v2/firestore';

import { APP_REGION } from '../config/runtime';
import { logInfo, logWarn } from '../shared/logger';

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
    const delta =
      data.transactionType === 'donation'
        ? data.amountMinor ?? 0
        : -1 * (data.amountMinor ?? 0);

    logInfo('transaction created', {
      transactionId: event.params.transactionId,
      clanId: data.clanId ?? null,
      fundId: data.fundId ?? null,
      amountMinor: data.amountMinor ?? null,
      derivedDeltaMinor: delta,
    });
  },
);
