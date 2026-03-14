import { initializeApp } from 'firebase-admin/app';
import { setGlobalOptions } from 'firebase-functions/v2/options';

import {
  claimMemberRecord,
  createInvite,
  registerDeviceToken,
  resolveChildLoginContext,
} from './auth/callables';
import { APP_REGION } from './config/runtime';
import { onEventCreated, sendEventReminder } from './events/event-triggers';
import {
  createParentChildRelationship,
  createSpouseRelationship,
} from './genealogy/callables';
import {
  onRelationshipCreated,
  onRelationshipDeleted,
} from './genealogy/relationship-triggers';
import { expireInvitesJob } from './scheduled/jobs';
import { onSubmissionReviewed } from './scholarship/submission-triggers';
import { onTransactionCreated } from './funds/transaction-triggers';

initializeApp();

setGlobalOptions({
  region: APP_REGION,
  maxInstances: 10,
});

export {
  claimMemberRecord,
  createParentChildRelationship,
  createSpouseRelationship,
  createInvite,
  expireInvitesJob,
  onEventCreated,
  onRelationshipCreated,
  onRelationshipDeleted,
  onSubmissionReviewed,
  onTransactionCreated,
  registerDeviceToken,
  resolveChildLoginContext,
  sendEventReminder,
};
