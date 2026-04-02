enum AdUserSegment {
  newUser,
  lowEngagement,
  highlyEngaged,
  premiumCandidate,
  churnRisk,
  returningUser,
  standard,
}

class AdOpportunityContext {
  const AdOpportunityContext({
    required this.screenId,
    required this.placementId,
    required this.breakpointType,
    required this.source,
    this.isNaturalBreakpoint = false,
    this.isBadMoment = false,
    this.importantActionCompleted = false,
  });

  final String screenId;
  final String placementId;
  final String breakpointType;
  final String source;
  final bool isNaturalBreakpoint;
  final bool isBadMoment;
  final bool importantActionCompleted;
}

class AdDecision {
  const AdDecision._({
    required this.shouldShow,
    required this.reason,
    this.score,
  });

  const AdDecision.allow({required int score, String reason = 'eligible'})
    : this._(shouldShow: true, reason: reason, score: score);

  const AdDecision.deny(String reason)
    : this._(shouldShow: false, reason: reason);

  final bool shouldShow;
  final String reason;
  final int? score;
}

class AdSessionState {
  AdSessionState({
    required this.startedAt,
    required this.currentScreenId,
    required this.suspectedCrashReopen,
  });

  final DateTime startedAt;
  String currentScreenId;
  bool suspectedCrashReopen;
  bool fullscreenAdShowing = false;
  bool awaitingScreenAfterAdEvent = false;
  int actionsSinceLastInterstitial = 0;
  int totalActionsThisSession = 0;
  int screenTransitionsSinceLastFullscreen = 0;
  int fullscreenAdsThisSession = 0;
  int crashSuppressSessionsRemaining = 0;
  int consecutiveInterstitialLoadFailures = 0;
  DateTime? lastImportantActionAt;
  DateTime? lastInterstitialLoadFailureAt;
  DateTime? lastFullscreenShownAt;
  DateTime? lastAdDismissedAt;
  String? lastAdFormat;
  String? lastAdPlacement;

  int sessionAgeSec(DateTime now) => now.difference(startedAt).inSeconds;

  int timeSinceLastFullscreenSec(DateTime now) {
    final last = lastFullscreenShownAt;
    if (last == null) {
      return 1 << 30;
    }
    return now.difference(last).inSeconds;
  }

  int timeSinceLastImportantActionSec(DateTime now) {
    final last = lastImportantActionAt;
    if (last == null) {
      return 1 << 30;
    }
    return now.difference(last).inSeconds;
  }

  int timeSinceLastLoadFailureSec(DateTime now) {
    final last = lastInterstitialLoadFailureAt;
    if (last == null) {
      return 1 << 30;
    }
    return now.difference(last).inSeconds;
  }

  int timeSinceLastDismissSec(DateTime now) {
    final last = lastAdDismissedAt;
    if (last == null) {
      return 1 << 30;
    }
    return now.difference(last).inSeconds;
  }

  void recordMeaningfulAction() {
    totalActionsThisSession += 1;
    actionsSinceLastInterstitial += 1;
  }

  void recordScreenTransition({required String toScreenId}) {
    currentScreenId = toScreenId;
    screenTransitionsSinceLastFullscreen += 1;
  }

  void recordImportantAction(DateTime now) {
    lastImportantActionAt = now;
  }

  void recordInterstitialLoadFailure(DateTime now) {
    consecutiveInterstitialLoadFailures += 1;
    lastInterstitialLoadFailureAt = now;
  }

  void clearInterstitialLoadFailures() {
    consecutiveInterstitialLoadFailures = 0;
    lastInterstitialLoadFailureAt = null;
  }

  void recordInterstitialShown(
    DateTime now, {
    required String placementId,
    required String format,
  }) {
    fullscreenAdShowing = true;
    fullscreenAdsThisSession += 1;
    actionsSinceLastInterstitial = 0;
    screenTransitionsSinceLastFullscreen = 0;
    lastFullscreenShownAt = now;
    lastAdPlacement = placementId;
    lastAdFormat = format;
  }

  void recordInterstitialDismissed(DateTime now) {
    fullscreenAdShowing = false;
    awaitingScreenAfterAdEvent = true;
    lastAdDismissedAt = now;
  }

  void recordInterstitialShowFailure() {
    fullscreenAdShowing = false;
  }
}

class AdUserState {
  const AdUserState({
    required this.isPremium,
    required this.subscriptionTier,
    required this.segment,
    required this.daysSinceFirstSeen,
    required this.totalSessions,
    required this.recentSessions7d,
    required this.recentShortSessions7d,
    required this.adFrustrationSignals7d,
    required this.interstitialsLast24h,
    required this.hasRecentPremiumIntent,
    required this.isReturningAfterGap,
  });

  final bool isPremium;
  final String subscriptionTier;
  final AdUserSegment segment;
  final int daysSinceFirstSeen;
  final int totalSessions;
  final int recentSessions7d;
  final int recentShortSessions7d;
  final int adFrustrationSignals7d;
  final int interstitialsLast24h;
  final bool hasRecentPremiumIntent;
  final bool isReturningAfterGap;

  String get segmentName => switch (segment) {
    AdUserSegment.newUser => 'new_user',
    AdUserSegment.lowEngagement => 'low_engagement',
    AdUserSegment.highlyEngaged => 'highly_engaged',
    AdUserSegment.premiumCandidate => 'premium_candidate',
    AdUserSegment.churnRisk => 'churn_risk',
    AdUserSegment.returningUser => 'returning_user',
    AdUserSegment.standard => 'standard',
  };
}
