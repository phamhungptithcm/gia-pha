import { initializeApp } from 'firebase-admin/app';
import { setGlobalOptions } from 'firebase-functions/v2/options';

import {
  bootstrapClanWorkspace,
  claimMemberRecord,
  createUnlinkedPhoneIdentity,
  createInvite,
  requestOtpChallenge,
  listUserClanContexts,
  lookupMemberProfileByPhone,
  registerDeviceToken,
  resolvePhoneIdentityAfterOtp,
  resolveChildLoginContext,
  startMemberIdentityVerification,
  submitMemberIdentityVerification,
  switchActiveClanContext,
  verifyOtpChallenge,
} from './auth/callables';
import {
  completeCardCheckout,
  createSubscriptionCheckout,
  loadBillingWorkspace,
  resolveBillingEntitlement,
  verifyInAppPurchase,
  updateBillingPreferences,
} from './billing/callables';
import { cardPaymentCallback } from './billing/webhooks';
import { appleIapWebhook, googleIapWebhook } from './billing/iap-webhooks';
import { APP_REGION } from './config/runtime';
import { onEventCreated, sendEventReminder } from './events/event-triggers';
import { recordFundTransaction } from './funds/callables';
import {
  createParentChildRelationship,
  createSpouseRelationship,
} from './genealogy/callables';
import { createClanMember } from './members/callables';
import { onMemberDeathDateChanged } from './members/memorial-ritual-triggers';
import {
  cancelJoinRequest,
  detectDuplicateGenealogy,
  listJoinRequestsForReview,
  listMyJoinRequests,
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
import {
  disburseScholarshipSubmissionFromFund,
  reviewScholarshipSubmission,
} from './scholarship/callables';
import {
  billingContactNoticeJob,
  billingPendingTimeoutJob,
  billingSubscriptionDelinquencyJob,
  billingSubscriptionReminderJob,
  expireInvitesJob,
} from './scheduled/jobs';
import { onSubmissionReviewed } from './scholarship/submission-triggers';
import { onTransactionCreated } from './funds/transaction-triggers';
import { appHealthCheck } from './system/health';

initializeApp();

setGlobalOptions({
  region: APP_REGION,
  maxInstances: 10,
});

export {
  billingContactNoticeJob,
  billingPendingTimeoutJob,
  billingSubscriptionDelinquencyJob,
  billingSubscriptionReminderJob,
  bootstrapClanWorkspace,
  cardPaymentCallback,
  claimMemberRecord,
  createUnlinkedPhoneIdentity,
  completeCardCheckout,
  cancelJoinRequest,
  appleIapWebhook,
  createParentChildRelationship,
  createSpouseRelationship,
  createInvite,
  createClanMember,
  createSubscriptionCheckout,
  requestOtpChallenge,
  disburseScholarshipSubmissionFromFund,
  detectDuplicateGenealogy,
  expireInvitesJob,
  assignGovernanceRole,
  appHealthCheck,
  getTreasurerDashboard,
  listJoinRequestsForReview,
  listMyJoinRequests,
  listUserClanContexts,
  lookupMemberProfileByPhone,
  loadBillingWorkspace,
  onEventCreated,
  onRelationshipCreated,
  onRelationshipDeleted,
  onMemberDeathDateChanged,
  onSubmissionReviewed,
  onTransactionCreated,
  googleIapWebhook,
  registerDeviceToken,
  recordFundTransaction,
  resolvePhoneIdentityAfterOtp,
  resolveBillingEntitlement,
  reviewJoinRequest,
  reviewScholarshipSubmission,
  resolveChildLoginContext,
  searchGenealogyDiscovery,
  sendEventReminder,
  startMemberIdentityVerification,
  submitMemberIdentityVerification,
  submitJoinRequest,
  switchActiveClanContext,
  updateBillingPreferences,
  verifyOtpChallenge,
  verifyInAppPurchase,
};
