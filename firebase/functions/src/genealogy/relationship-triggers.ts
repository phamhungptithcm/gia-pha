import {
  onDocumentCreated,
  onDocumentDeleted,
} from 'firebase-functions/v2/firestore';

import { APP_REGION } from '../config/runtime';
import { reconcileRelationshipMembers } from './relationship-reconciliation';
import { logWarn } from '../shared/logger';

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
    await reconcileRelationshipMembers({
      relationshipId: event.params.relationshipId,
      action: 'create',
      relationship,
      source: 'function:onRelationshipCreated',
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
    await reconcileRelationshipMembers({
      relationshipId: event.params.relationshipId,
      action: 'delete',
      relationship,
      source: 'function:onRelationshipDeleted',
    });
  },
);
