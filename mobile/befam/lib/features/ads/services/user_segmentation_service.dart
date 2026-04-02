import 'ad_policy.dart';
import 'ad_persistence_store.dart';
import 'ad_runtime_models.dart';

class UserSegmentationService {
  const UserSegmentationService();

  AdUserState buildUserState({
    required AdPersistedState persisted,
    required DateTime now,
    required bool isPremium,
    required String subscriptionTier,
    required AdPolicy policy,
  }) {
    final daysSinceFirstSeen = now.difference(persisted.firstSeenAt).inDays;
    final recentSessions7d = persisted.recentSessionStarts
        .where((entry) => now.difference(entry) <= const Duration(days: 7))
        .length;
    final recentShortSessions7d = persisted.recentShortSessions
        .where((entry) => now.difference(entry) <= const Duration(days: 7))
        .length;
    final adFrustrationSignals7d = persisted.recentAdFrustrationSignals
        .where((entry) => now.difference(entry) <= const Duration(days: 7))
        .length;
    final interstitialsLast24h = persisted.interstitialShows
        .where((entry) => now.difference(entry) <= const Duration(hours: 24))
        .length;
    final hasRecentPremiumIntent = persisted.premiumIntentSignals.any(
      (entry) => now.difference(entry) <= const Duration(hours: 24),
    );
    final isReturningAfterGap =
        persisted.lastSessionEndedAt != null &&
        now.difference(persisted.lastSessionEndedAt!) >=
            const Duration(days: 3);

    final isNewUser =
        daysSinceFirstSeen < policy.newUserGraceDays ||
        persisted.totalSessions <= policy.newUserGraceSessions;

    final segment = switch ((
      isPremium,
      isNewUser,
      hasRecentPremiumIntent,
      adFrustrationSignals7d,
      recentShortSessions7d,
      isReturningAfterGap,
      recentSessions7d,
    )) {
      (true, _, _, _, _, _, _) => AdUserSegment.standard,
      (_, true, _, _, _, _, _) => AdUserSegment.newUser,
      (_, _, true, _, _, _, _) => AdUserSegment.premiumCandidate,
      (_, _, _, >= 2, _, _, _) => AdUserSegment.churnRisk,
      (_, _, _, _, >= 3, _, _) => AdUserSegment.churnRisk,
      (_, _, _, _, _, true, _) => AdUserSegment.returningUser,
      (_, _, _, _, <= 1, _, >= 6) => AdUserSegment.highlyEngaged,
      (_, _, _, _, >= 2, _, _) => AdUserSegment.lowEngagement,
      (_, _, _, _, _, _, <= 2) => AdUserSegment.lowEngagement,
      _ => AdUserSegment.standard,
    };

    return AdUserState(
      isPremium: isPremium,
      subscriptionTier: subscriptionTier,
      segment: segment,
      daysSinceFirstSeen: daysSinceFirstSeen,
      totalSessions: persisted.totalSessions,
      recentSessions7d: recentSessions7d,
      recentShortSessions7d: recentShortSessions7d,
      adFrustrationSignals7d: adFrustrationSignals7d,
      interstitialsLast24h: interstitialsLast24h,
      hasRecentPremiumIntent: hasRecentPremiumIntent,
      isReturningAfterGap: isReturningAfterGap,
    );
  }
}
