import { initializeApp } from 'firebase-admin/app';
import { setGlobalOptions } from 'firebase-functions/v2/options';

import {
  claimMemberRecord,
  createInvite,
  listDebugLoginProfiles,
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
import { expireInvitesJob } from './scheduled/jobs';
import { reviewScholarshipSubmission } from './scholarship/callables';
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
  detectDuplicateGenealogy,
  expireInvitesJob,
  assignGovernanceRole,
  getTreasurerDashboard,
  listJoinRequestsForReview,
  listDebugLoginProfiles,
  onEventCreated,
  onRelationshipCreated,
  onRelationshipDeleted,
  onSubmissionReviewed,
  onTransactionCreated,
  registerDeviceToken,
  reviewJoinRequest,
  reviewScholarshipSubmission,
  resolveChildLoginContext,
  searchGenealogyDiscovery,
  sendEventReminder,
  submitJoinRequest,
};
