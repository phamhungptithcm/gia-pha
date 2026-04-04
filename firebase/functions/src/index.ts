import { initializeApp } from 'firebase-admin/app';
import { setGlobalOptions } from 'firebase-functions/v2/options';

import {
  bootstrapClanWorkspace,
  claimMemberRecord,
  createUnlinkedPhoneIdentity,
  getAccountDeletionRequestStatus,
  createInvite,
  requestOtpChallenge,
  listUserClanContexts,
  lookupMemberProfileByPhone,
  registerDeviceToken,
  sendSelfTestEventReminder,
  sendSelfTestNotification,
  resolvePhoneIdentityAfterOtp,
  resolveChildLoginContext,
  startMemberIdentityVerification,
  submitMemberIdentityVerification,
  submitAccountDeletionRequest,
  switchActiveClanContext,
  verifyOtpChallenge,
} from './auth/callables';
import {
  loadBillingWorkspace,
  resolveBillingEntitlement,
  verifyInAppPurchase,
  updateBillingPreferences,
} from './billing/callables';
import { appleIapWebhook, googleIapWebhook } from './billing/iap-webhooks';
import { APP_REGION } from './config/runtime';
import { onEventCreated, sendEventReminder } from './events/event-triggers';
import { recordFundTransaction } from './funds/callables';
import {
  createParentChildRelationship,
  createSpouseRelationship,
} from './genealogy/callables';
import {
  createClanMember,
  notifyNearbyRelativesDetected,
} from './members/callables';
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

// Global defaults: 3 max instances keeps cold-start cost low for an
// early-stage app while still handling moderate bursts. Critical auth
// and IAP callables override this with higher limits per-function if needed.
setGlobalOptions({
  region: APP_REGION,
  maxInstances: 3,
  concurrency: 80,
});

export {
  billingContactNoticeJob,
  billingPendingTimeoutJob,
  billingSubscriptionDelinquencyJob,
  billingSubscriptionReminderJob,
  bootstrapClanWorkspace,
  claimMemberRecord,
  createUnlinkedPhoneIdentity,
  getAccountDeletionRequestStatus,
  cancelJoinRequest,
  appleIapWebhook,
  createParentChildRelationship,
  createSpouseRelationship,
  createInvite,
  createClanMember,
  notifyNearbyRelativesDetected,
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
  sendSelfTestEventReminder,
  sendSelfTestNotification,
  searchGenealogyDiscovery,
  sendEventReminder,
  startMemberIdentityVerification,
  submitMemberIdentityVerification,
  submitAccountDeletionRequest,
  submitJoinRequest,
  switchActiveClanContext,
  updateBillingPreferences,
  verifyOtpChallenge,
  verifyInAppPurchase,
};
