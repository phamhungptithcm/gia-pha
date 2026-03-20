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

    const content = buildSubmissionNotificationContent({
      status: toStatus,
      reviewNote: afterData.reviewNote,
      submissionTitle: afterData.title,
    });
    const delivery = await notifyMembers({
      clanId,
      memberIds: [memberId],
      type: 'scholarship_reviewed',
      title: content.vi.title,
      body: content.vi.body,
      localized: content,
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

function buildSubmissionNotificationContent({
  status,
  reviewNote,
  submissionTitle,
}: {
  status: string;
  reviewNote: string | null | undefined;
  submissionTitle: string | null | undefined;
}): {
  vi: { title: string; body: string };
  en: { title: string; body: string };
} {
  const trimmedTitle = submissionTitle?.trim() ?? '';
  const trimmedReview = reviewNote?.trim() ?? '';
  const titlePrefixVi =
    trimmedTitle.length > 0 ? `"${trimmedTitle}"` : 'Hồ sơ của bạn';
  const titlePrefixEn =
    trimmedTitle.length > 0 ? `"${trimmedTitle}"` : 'Your submission';

  if (status == 'approved') {
    return {
      vi: {
        title: 'Hồ sơ khuyến học đã được duyệt',
        body: trimmedReview.length > 0
          ? `${titlePrefixVi} đã được duyệt. Ghi chú: ${trimmedReview}`
          : `${titlePrefixVi} đã được duyệt.`,
      },
      en: {
        title: 'Scholarship submission approved',
        body: trimmedReview.length > 0
          ? `${titlePrefixEn} was approved. Note: ${trimmedReview}`
          : `${titlePrefixEn} was approved.`,
      },
    };
  }

  return {
    vi: {
      title: 'Cập nhật hồ sơ khuyến học',
      body: trimmedReview.length > 0
        ? `${titlePrefixVi} chưa được duyệt. Lý do: ${trimmedReview}`
        : `${titlePrefixVi} chưa được duyệt. Mở BeFam để xem chi tiết.`,
    },
    en: {
      title: 'Scholarship submission update',
      body: trimmedReview.length > 0
        ? `${titlePrefixEn} was not approved. Reason: ${trimmedReview}`
        : `${titlePrefixEn} was not approved. Open BeFam to review details.`,
    },
  };
}
