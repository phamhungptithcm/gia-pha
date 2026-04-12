import 'dart:math' as math;

import 'ad_policy.dart';
import 'ad_runtime_models.dart';

class AdEligibilityEvaluator {
  const AdEligibilityEvaluator();

  static const _warmupSessionLeadTimeSec = 30;
  static const _warmupCooldownLeadTimeSec = 30;
  static const _warmupActionSlack = 1;
  static const _warmupTransitionSlack = 1;

  AdDecision evaluateInterstitial({
    required AdOpportunityContext context,
    required AdUserState userState,
    required AdSessionState sessionState,
    required AdPolicy policy,
    required DateTime now,
    required bool interstitialReady,
  }) {
    final commonGuard = _evaluateCommonGuards(
      context: context,
      userState: userState,
      sessionState: sessionState,
      policy: policy,
      now: now,
    );
    if (commonGuard != null) {
      return commonGuard;
    }

    final resolvedPolicy = _resolveInterstitialPolicy(
      userState: userState,
      policy: policy,
    );
    if (resolvedPolicy.blockReason != null) {
      return AdDecision.deny(resolvedPolicy.blockReason!);
    }

    if (sessionState.timeSinceLastFullscreenSec(now) <
        resolvedPolicy.minIntervalSec) {
      return const AdDecision.deny('cooldown');
    }
    if (sessionState.actionsSinceLastInterstitial < resolvedPolicy.minActions) {
      return const AdDecision.deny('not_enough_actions');
    }
    if (sessionState.screenTransitionsSinceLastFullscreen <
        policy.interstitialMinScreenTransitions) {
      return const AdDecision.deny('transition_cap');
    }
    if (sessionState.fullscreenAdsThisSession >= resolvedPolicy.maxPerSession) {
      return const AdDecision.deny('session_cap');
    }
    if (userState.interstitialsLast24h >= resolvedPolicy.maxPerDay) {
      return const AdDecision.deny('daily_cap');
    }
    if (sessionState.consecutiveInterstitialLoadFailures > 0 &&
        sessionState.timeSinceLastLoadFailureSec(now) <
            policy.interstitialFailBackoffSec) {
      return const AdDecision.deny('fail_backoff');
    }

    final score = _scoreOpportunity(
      context: context,
      userState: userState,
      sessionState: sessionState,
      now: now,
      minActions: resolvedPolicy.minActions,
    );
    if (!interstitialReady) {
      return const AdDecision.deny('not_ready');
    }
    if (score < 40) {
      return const AdDecision.deny('low_quality_opportunity');
    }
    return AdDecision.allow(score: score);
  }

  AdDecision evaluateInterstitialWarmup({
    required AdOpportunityContext context,
    required AdUserState userState,
    required AdSessionState sessionState,
    required AdPolicy policy,
    required DateTime now,
  }) {
    final commonGuard = _evaluateCommonGuards(
      context: context,
      userState: userState,
      sessionState: sessionState,
      policy: policy,
      now: now,
    );
    if (commonGuard != null) {
      return commonGuard;
    }

    final resolvedPolicy = _resolveInterstitialPolicy(
      userState: userState,
      policy: policy,
    );
    if (resolvedPolicy.blockReason != null) {
      return AdDecision.deny(resolvedPolicy.blockReason!);
    }

    if (sessionState.timeSinceLastFullscreenSec(now) <
        math.max(
          0,
          resolvedPolicy.minIntervalSec - _warmupCooldownLeadTimeSec,
        )) {
      return const AdDecision.deny('cooldown');
    }
    if (sessionState.actionsSinceLastInterstitial <
        math.max(0, resolvedPolicy.minActions - _warmupActionSlack)) {
      return const AdDecision.deny('not_enough_actions');
    }
    if (sessionState.screenTransitionsSinceLastFullscreen <
        math.max(
          0,
          policy.interstitialMinScreenTransitions - _warmupTransitionSlack,
        )) {
      return const AdDecision.deny('transition_cap');
    }
    if (sessionState.sessionAgeSec(now) <
        math.max(
          0,
          policy.interstitialMinSessionAgeSec - _warmupSessionLeadTimeSec,
        )) {
      return const AdDecision.deny('session_too_young');
    }
    if (sessionState.fullscreenAdsThisSession >= resolvedPolicy.maxPerSession) {
      return const AdDecision.deny('session_cap');
    }
    if (userState.interstitialsLast24h >= resolvedPolicy.maxPerDay) {
      return const AdDecision.deny('daily_cap');
    }
    if (sessionState.consecutiveInterstitialLoadFailures > 0 &&
        sessionState.timeSinceLastLoadFailureSec(now) <
            policy.interstitialFailBackoffSec) {
      return const AdDecision.deny('fail_backoff');
    }

    final score = _scoreOpportunity(
      context: context,
      userState: userState,
      sessionState: sessionState,
      now: now,
      minActions: resolvedPolicy.minActions,
    );
    if (score < 40) {
      return const AdDecision.deny('low_quality_opportunity');
    }
    return AdDecision.allow(score: score, reason: 'warmup_eligible');
  }

  AdDecision? _evaluateCommonGuards({
    required AdOpportunityContext context,
    required AdUserState userState,
    required AdSessionState sessionState,
    required AdPolicy policy,
    required DateTime now,
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
    if (sessionState.timeSinceLastImportantActionSec(now) <
        policy.importantActionSuppressSec) {
      return const AdDecision.deny('important_action_window');
    }
    return null;
  }

  _ResolvedInterstitialPolicy _resolveInterstitialPolicy({
    required AdUserState userState,
    required AdPolicy policy,
  }) {
    if (userState.segment == AdUserSegment.newUser) {
      return const _ResolvedInterstitialPolicy(blockReason: 'new_user_grace');
    }

    var minIntervalSec = policy.interstitialMinIntervalSec;
    var minActions = policy.interstitialMinActions;
    var maxPerSession = policy.interstitialMaxPerSession;
    var maxPerDay = policy.interstitialMaxPerDay;

    switch (userState.segment) {
      case AdUserSegment.lowEngagement:
        minIntervalSec *= 2;
        minActions += 1;
        maxPerDay = math.min(maxPerDay, policy.lowEngagementDailyCap);
      case AdUserSegment.highlyEngaged:
        maxPerSession += 1;
        maxPerDay += 1;
      case AdUserSegment.premiumCandidate:
        if (policy.premiumCandidateLowAdPressure) {
          minIntervalSec =
              (minIntervalSec * policy.premiumCandidateCooldownMultiplier)
                  .round();
          maxPerDay = math.min(maxPerDay, 1);
          if (userState.hasRecentPremiumIntent) {
            return const _ResolvedInterstitialPolicy(
              blockReason: 'premium_conversion_window',
            );
          }
        }
      case AdUserSegment.churnRisk:
        minIntervalSec = (minIntervalSec * policy.churnRiskCooldownMultiplier)
            .round();
        maxPerSession = 0;
        maxPerDay = 1;
      case AdUserSegment.returningUser:
        minIntervalSec = math.max(minIntervalSec, 180);
      case AdUserSegment.newUser:
      case AdUserSegment.standard:
        break;
    }

    return _ResolvedInterstitialPolicy(
      minIntervalSec: minIntervalSec,
      minActions: minActions,
      maxPerSession: maxPerSession,
      maxPerDay: maxPerDay,
    );
  }

  int _scoreOpportunity({
    required AdOpportunityContext context,
    required AdUserState userState,
    required AdSessionState sessionState,
    required DateTime now,
    required int minActions,
  }) {
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
    return score;
  }
}

class _ResolvedInterstitialPolicy {
  const _ResolvedInterstitialPolicy({
    this.minIntervalSec = 0,
    this.minActions = 0,
    this.maxPerSession = 0,
    this.maxPerDay = 0,
    this.blockReason,
  });

  final int minIntervalSec;
  final int minActions;
  final int maxPerSession;
  final int maxPerDay;
  final String? blockReason;
}
