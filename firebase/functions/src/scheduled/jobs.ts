import { onSchedule } from 'firebase-functions/v2/scheduler';

import {
  APP_REGION,
  APP_TIMEZONE,
  BILLING_DELINQUENCY_JOB_SCHEDULE,
  BILLING_PENDING_TIMEOUT_JOB_SCHEDULE,
  BILLING_PENDING_TIMEOUT_LIMIT,
  BILLING_PENDING_TIMEOUT_MINUTES,
  BILLING_SUBSCRIPTION_REMINDER_JOB_SCHEDULE,
  EXPIRE_INVITES_JOB_SCHEDULE,
} from '../config/runtime';
import { loadBillingRuntimeConfig } from '../config/runtime-overrides';
import { expireInvitesJobRun } from './invite-expiration';
import { logInfo } from '../shared/logger';
import { sendSubscriptionRemindersRun } from '../billing/subscription-reminders';
import { cancelStalePendingTransactionsRun } from '../billing/store';
import { enforceSubscriptionDelinquencyRun } from '../billing/subscription-delinquency';

export const expireInvitesJob = onSchedule(
  {
    schedule: EXPIRE_INVITES_JOB_SCHEDULE,
    region: APP_REGION,
    timeZone: APP_TIMEZONE,
  },
  async () => {
    const result = await expireInvitesJobRun({
      source: 'function:expireInvitesJob',
    });
    logInfo('expireInvitesJob tick complete', result);
  },
);

export const billingSubscriptionReminderJob = onSchedule(
  {
    schedule: BILLING_SUBSCRIPTION_REMINDER_JOB_SCHEDULE,
    region: APP_REGION,
    timeZone: APP_TIMEZONE,
  },
  async () => {
    const result = await sendSubscriptionRemindersRun({
      source: 'function:billingSubscriptionReminderJob',
    });
    logInfo('billingSubscriptionReminderJob tick complete', result);
  },
);

export const billingPendingTimeoutJob = onSchedule(
  {
    schedule: BILLING_PENDING_TIMEOUT_JOB_SCHEDULE,
    region: APP_REGION,
    timeZone: APP_TIMEZONE,
  },
  async () => {
    let timeoutMinutes = BILLING_PENDING_TIMEOUT_MINUTES;
    let limit = BILLING_PENDING_TIMEOUT_LIMIT;
    try {
      const runtimeConfig = await loadBillingRuntimeConfig();
      timeoutMinutes = runtimeConfig.pendingTimeoutMinutes;
      limit = runtimeConfig.pendingTimeoutLimit;
    } catch {
      // Keep environment defaults if runtime overrides cannot be loaded.
    }
    const result = await cancelStalePendingTransactionsRun({
      source: 'system:billing_pending_timeout_job',
      timeoutMinutes,
      limit,
    });
    logInfo('billingPendingTimeoutJob tick complete', result);
  },
);

export const billingSubscriptionDelinquencyJob = onSchedule(
  {
    schedule: BILLING_DELINQUENCY_JOB_SCHEDULE,
    region: APP_REGION,
    timeZone: APP_TIMEZONE,
  },
  async () => {
    const runtimeConfig = await loadBillingRuntimeConfig();
    const result = await enforceSubscriptionDelinquencyRun({
      source: 'function:billingSubscriptionDelinquencyJob',
      graceDays: runtimeConfig.delinquencyGraceDays,
      limit: runtimeConfig.delinquencyLimit,
      reminderDays: runtimeConfig.delinquencyReminderDays,
    });
    logInfo('billingSubscriptionDelinquencyJob tick complete', result);
  },
);
