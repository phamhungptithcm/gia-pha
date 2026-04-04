import 'package:befam/features/ads/services/ad_eligibility_evaluator.dart';
import 'package:befam/features/ads/services/ad_policy.dart';
import 'package:befam/features/ads/services/ad_runtime_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const evaluator = AdEligibilityEvaluator();
  final now = DateTime(2026, 4, 2, 12);

  AdSessionState buildSessionState() {
    final session = AdSessionState(
      startedAt: now.subtract(const Duration(minutes: 12)),
      currentScreenId: 'home',
      suspectedCrashReopen: false,
    );
    session.actionsSinceLastInterstitial = 4;
    session.totalActionsThisSession = 4;
    session.screenTransitionsSinceLastFullscreen = 3;
    session.lastFullscreenShownAt = now.subtract(const Duration(minutes: 10));
    return session;
  }

  const eligibleContext = AdOpportunityContext(
    screenId: 'events',
    placementId: 'shell_home_to_events',
    breakpointType: 'shell_tab_switch',
    source: 'shell_navigation',
    isNaturalBreakpoint: true,
  );

  test('blocks premium users from interstitials', () {
    final decision = evaluator.evaluateInterstitial(
      context: eligibleContext,
      userState: const AdUserState(
        isPremium: true,
        subscriptionTier: 'PRO',
        segment: AdUserSegment.standard,
        daysSinceFirstSeen: 40,
        totalSessions: 10,
        recentSessions7d: 5,
        recentShortSessions7d: 0,
        adFrustrationSignals7d: 0,
        interstitialsLast24h: 0,
        hasRecentPremiumIntent: false,
        isReturningAfterGap: false,
      ),
      sessionState: buildSessionState(),
      policy: AdPolicy.defaults,
      now: now,
      interstitialReady: true,
    );

    expect(decision.shouldShow, isFalse);
    expect(decision.reason, 'premium_user');
  });

  test('blocks new users during grace period', () {
    final decision = evaluator.evaluateInterstitial(
      context: eligibleContext,
      userState: const AdUserState(
        isPremium: false,
        subscriptionTier: 'FREE',
        segment: AdUserSegment.newUser,
        daysSinceFirstSeen: 0,
        totalSessions: 1,
        recentSessions7d: 1,
        recentShortSessions7d: 0,
        adFrustrationSignals7d: 0,
        interstitialsLast24h: 0,
        hasRecentPremiumIntent: false,
        isReturningAfterGap: false,
      ),
      sessionState: buildSessionState(),
      policy: AdPolicy.defaults,
      now: now,
      interstitialReady: true,
    );

    expect(decision.shouldShow, isFalse);
    expect(decision.reason, 'new_user_grace');
  });

  test('allows a high quality opportunity for highly engaged free users', () {
    final decision = evaluator.evaluateInterstitial(
      context: const AdOpportunityContext(
        screenId: 'events',
        placementId: 'return_event_workspace',
        breakpointType: 'route_return',
        source: 'route_return',
        isNaturalBreakpoint: true,
      ),
      userState: const AdUserState(
        isPremium: false,
        subscriptionTier: 'FREE',
        segment: AdUserSegment.highlyEngaged,
        daysSinceFirstSeen: 30,
        totalSessions: 20,
        recentSessions7d: 8,
        recentShortSessions7d: 0,
        adFrustrationSignals7d: 0,
        interstitialsLast24h: 1,
        hasRecentPremiumIntent: false,
        isReturningAfterGap: false,
      ),
      sessionState: buildSessionState(),
      policy: AdPolicy.defaults,
      now: now,
      interstitialReady: true,
    );

    expect(decision.shouldShow, isTrue);
    expect(decision.score, greaterThanOrEqualTo(40));
  });
}
