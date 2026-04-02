enum RewardedDiscoveryAttemptResult {
  granted,
  dismissed,
  unavailable,
  failed,
  disabled,
}

abstract interface class RewardedDiscoveryAttemptService {
  bool get isRewardedDiscoveryEnabled;
  int get freeSearchesPerSession;
  int get maxUnlocksPerSession;
  int get extraSearchesPerReward;

  Future<void> primeRewardedDiscoveryAttempt();

  Future<RewardedDiscoveryAttemptResult> unlockExtraDiscoveryAttempt({
    required String screenId,
    required String placementId,
  });
}
