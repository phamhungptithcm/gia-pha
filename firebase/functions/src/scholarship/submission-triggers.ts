import { onDocumentUpdated } from 'firebase-functions/v2/firestore';

import { APP_REGION } from '../config/runtime';
import { logInfo, logWarn } from '../shared/logger';

export const onSubmissionReviewed = onDocumentUpdated(
  {
    document: 'achievementSubmissions/{submissionId}',
    region: APP_REGION,
  },
  async (event) => {
    const after = event.data?.after;
    const before = event.data?.before;

    if (!after || !before) {
      logWarn('submission review trigger missing before/after snapshot', {
        submissionId: event.params.submissionId,
      });
      return;
    }

    const beforeData = before.data();
    const afterData = after.data();

    if (beforeData.status === afterData.status) {
      return;
    }

    logInfo('submission status changed', {
      submissionId: event.params.submissionId,
      clanId: afterData.clanId ?? null,
      fromStatus: beforeData.status ?? null,
      toStatus: afterData.status ?? null,
    });
  },
);
