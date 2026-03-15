import { onSchedule } from 'firebase-functions/v2/scheduler';

import { APP_REGION, APP_TIMEZONE } from '../config/runtime';
import { expireInvitesJobRun } from './invite-expiration';
import { logInfo } from '../shared/logger';
import { sendSubscriptionRemindersRun } from '../billing/subscription-reminders';

export const expireInvitesJob = onSchedule(
  {
    schedule: '0 * * * *',
    region: APP_REGION,
    timeZone: APP_TIMEZONE,
  },
  async () => {
    const result = await expireInvitesJobRun({
      source: 'function:expireInvitesJob',
    });
    logInfo('expireInvitesJob tick complete', result);
  },
);

export const billingSubscriptionReminderJob = onSchedule(
  {
    schedule: '0 7 * * *',
    region: APP_REGION,
    timeZone: APP_TIMEZONE,
  },
  async () => {
    const result = await sendSubscriptionRemindersRun({
      source: 'function:billingSubscriptionReminderJob',
    });
    logInfo('billingSubscriptionReminderJob tick complete', result);
  },
);
