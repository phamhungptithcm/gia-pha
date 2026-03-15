import { initializeApp } from 'firebase-admin/app';
import { setGlobalOptions } from 'firebase-functions/v2/options';

import {
  claimMemberRecord,
  createInvite,
  registerDeviceToken,
  resolveChildLoginContext,
} from './auth/callables';
import {
  completeCardCheckout,
  createSubscriptionCheckout,
  loadBillingWorkspace,
  resolveBillingEntitlement,
  simulateVnpaySettlement,
  updateBillingPreferences,
} from './billing/callables';
import { cardPaymentCallback, vnpayPaymentCallback } from './billing/webhooks';
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
import { billingSubscriptionReminderJob, expireInvitesJob } from './scheduled/jobs';
import { onSubmissionReviewed } from './scholarship/submission-triggers';
import { onTransactionCreated } from './funds/transaction-triggers';

initializeApp();

setGlobalOptions({
  region: APP_REGION,
  maxInstances: 10,
});

export {
  billingSubscriptionReminderJob,
  cardPaymentCallback,
  claimMemberRecord,
  completeCardCheckout,
  createParentChildRelationship,
  createSpouseRelationship,
  createInvite,
  createSubscriptionCheckout,
  expireInvitesJob,
  loadBillingWorkspace,
  onEventCreated,
  onRelationshipCreated,
  onRelationshipDeleted,
  onSubmissionReviewed,
  onTransactionCreated,
  registerDeviceToken,
  resolveBillingEntitlement,
  resolveChildLoginContext,
  sendEventReminder,
  simulateVnpaySettlement,
  updateBillingPreferences,
  vnpayPaymentCallback,
};
