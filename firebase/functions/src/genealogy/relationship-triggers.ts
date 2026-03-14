import {
  onDocumentCreated,
  onDocumentDeleted,
} from 'firebase-functions/v2/firestore';

import { APP_REGION } from '../config/runtime';
import { logInfo, logWarn } from '../shared/logger';

export const onRelationshipCreated = onDocumentCreated(
  {
    document: 'relationships/{relationshipId}',
    region: APP_REGION,
  },
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) {
      logWarn('relationship create event missing snapshot', {
        relationshipId: event.params.relationshipId,
      });
      return;
    }

    const relationship = snapshot.data();

    logInfo('relationship created', {
      relationshipId: event.params.relationshipId,
      clanId: relationship.clanId ?? null,
      type: relationship.type ?? null,
    });
  },
);

export const onRelationshipDeleted = onDocumentDeleted(
  {
    document: 'relationships/{relationshipId}',
    region: APP_REGION,
  },
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) {
      logWarn('relationship delete event missing snapshot', {
        relationshipId: event.params.relationshipId,
      });
      return;
    }

    const relationship = snapshot.data();

    logInfo('relationship deleted', {
      relationshipId: event.params.relationshipId,
      clanId: relationship.clanId ?? null,
      type: relationship.type ?? null,
    });
  },
);
