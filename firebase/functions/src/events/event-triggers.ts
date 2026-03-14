import { onDocumentCreated } from 'firebase-functions/v2/firestore';
import { onSchedule } from 'firebase-functions/v2/scheduler';

import { APP_REGION, APP_TIMEZONE } from '../config/runtime';
import { logInfo, logWarn } from '../shared/logger';

export const onEventCreated = onDocumentCreated(
  {
    document: 'events/{eventId}',
    region: APP_REGION,
  },
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) {
      logWarn('event create trigger received no snapshot', {
        eventId: event.params.eventId,
      });
      return;
    }

    const data = snapshot.data();

    logInfo('event created', {
      eventId: event.params.eventId,
      clanId: data.clanId ?? null,
      eventType: data.eventType ?? null,
      startsAt: data.startsAt ?? null,
    });
  },
);

export const sendEventReminder = onSchedule(
  {
    schedule: '*/30 * * * *',
    region: APP_REGION,
    timeZone: APP_TIMEZONE,
  },
  async () => {
    logInfo('sendEventReminder tick');
  },
);
