import { initializeApp } from 'firebase-admin/app';
import { setGlobalOptions } from 'firebase-functions/v2/options';

import { claimMemberRecord, createInvite, registerDeviceToken } from './auth/callables';
import { APP_REGION } from './config/runtime';
import { onEventCreated, sendEventReminder } from './events/event-triggers';
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
  createInvite,
  expireInvitesJob,
  onEventCreated,
  onRelationshipCreated,
  onRelationshipDeleted,
  onSubmissionReviewed,
  onTransactionCreated,
  registerDeviceToken,
  sendEventReminder,
};
