import { onDocumentUpdated } from 'firebase-functions/v2/firestore';

import { APP_REGION } from '../config/runtime';
import { notifyMembers } from '../notifications/push-delivery';
import { logInfo, logWarn } from '../shared/logger';

type SubmissionRecord = {
  clanId?: string | null;
  memberId?: string | null;
  status?: string | null;
  title?: string | null;
  reviewNote?: string | null;
  programId?: string | null;
};

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

    const beforeData = before.data() as SubmissionRecord;
    const afterData = after.data() as SubmissionRecord;

    if (beforeData.status === afterData.status) {
      return;
    }

    const toStatus = (afterData.status ?? '').trim().toLowerCase();
    if (!['approved', 'rejected'].includes(toStatus)) {
      return;
    }

    const clanId = afterData.clanId?.trim() ?? '';
    const memberId = afterData.memberId?.trim() ?? '';
    if (clanId.length === 0 || memberId.length === 0) {
      logWarn('submission status changed without clan/member context', {
        submissionId: event.params.submissionId,
        clanId: afterData.clanId ?? null,
        memberId: afterData.memberId ?? null,
        toStatus,
      });
      return;
    }

    const title = toStatus === 'approved'
      ? 'Scholarship submission approved'
      : 'Scholarship submission update';
    const body = buildSubmissionBody({
      status: toStatus,
      reviewNote: afterData.reviewNote,
      submissionTitle: afterData.title,
    });
    const delivery = await notifyMembers({
      clanId,
      memberIds: [memberId],
      type: 'scholarship_reviewed',
      title,
      body,
      target: 'scholarship',
      targetId: event.params.submissionId,
      extraData: {
        submissionId: event.params.submissionId,
        status: toStatus,
        programId: afterData.programId?.trim() ?? '',
      },
    });

    logInfo('submission status changed', {
      submissionId: event.params.submissionId,
      clanId,
      memberId,
      fromStatus: beforeData.status ?? null,
      toStatus,
      ...delivery,
    });
  },
);

function buildSubmissionBody({
  status,
  reviewNote,
  submissionTitle,
}: {
  status: string;
  reviewNote: string | null | undefined;
  submissionTitle: string | null | undefined;
}): string {
  const trimmedTitle = submissionTitle?.trim() ?? '';
  const trimmedReview = reviewNote?.trim() ?? '';
  const titlePrefix = trimmedTitle.length > 0 ? `"${trimmedTitle}"` : 'Your submission';

  if (status == 'approved') {
    if (trimmedReview.length > 0) {
      return `${titlePrefix} was approved. Note: ${trimmedReview}`;
    }
    return `${titlePrefix} was approved.`;
  }

  if (trimmedReview.length > 0) {
    return `${titlePrefix} was not approved. Reason: ${trimmedReview}`;
  }

  return `${titlePrefix} was not approved. Open BeFam to review details.`;
}
