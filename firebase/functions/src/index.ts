import { initializeApp } from 'firebase-admin/app';
import { setGlobalOptions } from 'firebase-functions/v2/options';

import {
  bootstrapClanWorkspace,
  claimMemberRecord,
  createInvite,
  issueDebugProfileCustomToken,
  listDebugLoginProfiles,
  listUserClanContexts,
  lookupMemberProfileByPhone,
  registerDeviceToken,
  resolveChildLoginContext,
  switchActiveClanContext,
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
import { createClanMember } from './members/callables';
import {
  detectDuplicateGenealogy,
  listJoinRequestsForReview,
  reviewJoinRequest,
  searchGenealogyDiscovery,
  submitJoinRequest,
} from './genealogy/discovery-callables';
import {
  onRelationshipCreated,
  onRelationshipDeleted,
} from './genealogy/relationship-triggers';
import {
  assignGovernanceRole,
  getTreasurerDashboard,
} from './governance/callables';
import { reviewScholarshipSubmission } from './scholarship/callables';
import {
  billingPendingTimeoutJob,
  billingSubscriptionReminderJob,
  expireInvitesJob,
} from './scheduled/jobs';
import { onSubmissionReviewed } from './scholarship/submission-triggers';
import { onTransactionCreated } from './funds/transaction-triggers';

initializeApp();

setGlobalOptions({
  region: APP_REGION,
  maxInstances: 10,
});

export {
  billingPendingTimeoutJob,
  billingSubscriptionReminderJob,
  bootstrapClanWorkspace,
  cardPaymentCallback,
  claimMemberRecord,
  completeCardCheckout,
  createParentChildRelationship,
  createSpouseRelationship,
  createInvite,
  createClanMember,
  issueDebugProfileCustomToken,
  createSubscriptionCheckout,
  detectDuplicateGenealogy,
  expireInvitesJob,
  assignGovernanceRole,
  getTreasurerDashboard,
  listJoinRequestsForReview,
  listDebugLoginProfiles,
  listUserClanContexts,
  lookupMemberProfileByPhone,
  loadBillingWorkspace,
  onEventCreated,
  onRelationshipCreated,
  onRelationshipDeleted,
  onSubmissionReviewed,
  onTransactionCreated,
  registerDeviceToken,
  resolveBillingEntitlement,
  reviewJoinRequest,
  reviewScholarshipSubmission,
  resolveChildLoginContext,
  searchGenealogyDiscovery,
  sendEventReminder,
  submitJoinRequest,
  simulateVnpaySettlement,
  switchActiveClanContext,
  updateBillingPreferences,
  vnpayPaymentCallback,
};
