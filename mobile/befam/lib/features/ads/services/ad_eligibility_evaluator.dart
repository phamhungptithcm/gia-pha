import 'dart:math' as math;

import 'ad_policy.dart';
import 'ad_runtime_models.dart';

class AdEligibilityEvaluator {
  const AdEligibilityEvaluator();

  AdDecision evaluateInterstitial({
    required AdOpportunityContext context,
    required AdUserState userState,
    required AdSessionState sessionState,
    required AdPolicy policy,
    required DateTime now,
    required bool interstitialReady,
  }) {
    if (!policy.adsEnabled || !policy.interstitialEnabled) {
      return const AdDecision.deny('disabled');
    }
    if (userState.isPremium) {
      return const AdDecision.deny('premium_user');
    }
    if (sessionState.fullscreenAdShowing) {
      return const AdDecision.deny('fullscreen_in_progress');
    }
    if (!context.isNaturalBreakpoint) {
      return const AdDecision.deny('not_natural_breakpoint');
    }
    if (context.isBadMoment) {
      return const AdDecision.deny('bad_moment');
    }
    if (!policy.isInterstitialAllowedAtBreakpoint(context.breakpointType)) {
      return const AdDecision.deny('breakpoint_not_allowed');
    }
    if (sessionState.suspectedCrashReopen &&
        sessionState.crashSuppressSessionsRemaining > 0) {
      return const AdDecision.deny('post_crash_session');
    }
    if (sessionState.sessionAgeSec(now) < policy.interstitialMinSessionAgeSec) {
      return const AdDecision.deny('session_too_young');
    }
    if (sessionState.timeSinceLastImportantActionSec(now) <
        policy.importantActionSuppressSec) {
      return const AdDecision.deny('important_action_window');
    }
    if (userState.segment == AdUserSegment.newUser) {
      return const AdDecision.deny('new_user_grace');
    }

    var minInterval = policy.interstitialMinIntervalSec;
    var minActions = policy.interstitialMinActions;
    var maxPerSession = policy.interstitialMaxPerSession;
    var maxPerDay = policy.interstitialMaxPerDay;

    switch (userState.segment) {
      case AdUserSegment.lowEngagement:
        minInterval *= 2;
        minActions += 1;
        maxPerDay = math.min(maxPerDay, policy.lowEngagementDailyCap);
      case AdUserSegment.highlyEngaged:
        maxPerSession += 1;
        maxPerDay += 1;
      case AdUserSegment.premiumCandidate:
        if (policy.premiumCandidateLowAdPressure) {
          minInterval =
              (minInterval * policy.premiumCandidateCooldownMultiplier).round();
          maxPerDay = math.min(maxPerDay, 1);
          if (userState.hasRecentPremiumIntent) {
            return const AdDecision.deny('premium_conversion_window');
          }
        }
      case AdUserSegment.churnRisk:
        minInterval = (minInterval * policy.churnRiskCooldownMultiplier)
            .round();
        maxPerSession = 0;
        maxPerDay = 1;
      case AdUserSegment.returningUser:
        minInterval = math.max(minInterval, 180);
      case AdUserSegment.newUser:
      case AdUserSegment.standard:
        break;
    }

    if (sessionState.timeSinceLastFullscreenSec(now) < minInterval) {
      return const AdDecision.deny('cooldown');
    }
    if (sessionState.actionsSinceLastInterstitial < minActions) {
      return const AdDecision.deny('not_enough_actions');
    }
    if (sessionState.screenTransitionsSinceLastFullscreen <
        policy.interstitialMinScreenTransitions) {
      return const AdDecision.deny('transition_cap');
    }
    if (sessionState.fullscreenAdsThisSession >= maxPerSession) {
      return const AdDecision.deny('session_cap');
    }
    if (userState.interstitialsLast24h >= maxPerDay) {
      return const AdDecision.deny('daily_cap');
    }
    if (sessionState.consecutiveInterstitialLoadFailures > 0 &&
        sessionState.timeSinceLastLoadFailureSec(now) <
            policy.interstitialFailBackoffSec) {
      return const AdDecision.deny('fail_backoff');
    }

    var score = 0;
    switch (context.breakpointType) {
      case 'task_complete':
        score += 40;
      case 'result_exit':
        score += 30;
      case 'content_unit_end':
      case 'route_return':
        score += 20;
      case 'shell_tab_switch':
        score += 15;
      default:
        score += 10;
    }

    if (sessionState.actionsSinceLastInterstitial >= minActions + 1) {
      score += 15;
    }
    if (sessionState.sessionAgeSec(now) >= 300) {
      score += 10;
    }
    if (userState.segment == AdUserSegment.highlyEngaged) {
      score += 20;
    }
    if (userState.segment == AdUserSegment.lowEngagement) {
      score -= 20;
    }
    if (userState.segment == AdUserSegment.returningUser) {
      score -= 10;
    }
    if (userState.segment == AdUserSegment.churnRisk) {
      score -= 40;
    }
    if (userState.adFrustrationSignals7d >= 2) {
      score -= 40;
    }
    if (!interstitialReady) {
      return const AdDecision.deny('not_ready');
    }
    if (score < 40) {
      return const AdDecision.deny('low_quality_opportunity');
    }
    return AdDecision.allow(score: score);
  }
}
