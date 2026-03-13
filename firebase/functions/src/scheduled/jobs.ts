import { onSchedule } from 'firebase-functions/v2/scheduler';

import { APP_REGION, APP_TIMEZONE } from '../config/runtime';
import { logInfo } from '../shared/logger';

export const expireInvitesJob = onSchedule(
  {
    schedule: '0 * * * *',
    region: APP_REGION,
    timeZone: APP_TIMEZONE,
  },
  async () => {
    logInfo('expireInvitesJob tick');
  },
);
