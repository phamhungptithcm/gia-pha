import 'package:befam/features/ads/services/ad_analytics_tracker.dart';
import 'package:befam/features/ads/services/ad_controller.dart';
import 'package:befam/features/ads/services/ad_diagnostics_models.dart';
import 'package:befam/features/ads/services/ad_persistence_store.dart';
import 'package:befam/features/ads/services/ad_policy.dart';
import 'package:befam/features/ads/services/ad_remote_config_provider.dart';
import 'package:befam/features/ads/services/ad_runtime_models.dart';
import 'package:befam/features/ads/services/ad_service.dart';
import 'package:befam/features/ads/services/user_segmentation_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

void main() {
  setUp(() {
    AdService.debugSetAdsStateForTesting(
      canRequestAds: true,
      sdkInitialized: true,
    );
  });

  tearDown(() {
    AdService.debugSetAdsStateForTesting(
      canRequestAds: false,
      sdkInitialized: false,
    );
  });

  test('does not preload interstitials on high-focus screens', () async {
    final now = DateTime(2026, 4, 12, 9, 0);
    final adService = _FakeAdService();
    final controller = AdController(
      adService: adService,
      remoteConfigProvider: _FakeAdRemoteConfigProvider(),
      persistenceStore: _InMemoryAdPersistenceStore(_seedPersistedState(now)),
      analyticsTracker: _SpyAdAnalyticsTracker(),
      segmentationService: _FixedUserSegmentationService(_standardUserState),
      clock: () => now,
    );

    await controller.initialize(initialScreenId: 'profile');
    await _flushAsyncWork();

    expect(adService.interstitialLoadRequests, 0);
    expect(adService.bannerLoadRequests, 0);
  });

  test(
    'opportunity analytics no longer marks shown before an ad renders',
    () async {
      var now = DateTime(2026, 4, 12, 9, 0);
      final adService = _FakeAdService();
      final analyticsTracker = _SpyAdAnalyticsTracker();
      final controller = AdController(
        adService: adService,
        remoteConfigProvider: _FakeAdRemoteConfigProvider(),
        persistenceStore: _InMemoryAdPersistenceStore(_seedPersistedState(now)),
        analyticsTracker: analyticsTracker,
        segmentationService: _FixedUserSegmentationService(
          _highlyEngagedUserState,
        ),
        clock: () => now,
      );

      await controller.initialize(initialScreenId: 'home');
      await _flushAsyncWork();

      now = now.add(const Duration(seconds: 80));
      controller.recordNavigationTransition(
        fromScreenId: 'home',
        toScreenId: 'events',
      );
      await _flushAsyncWork();
      controller.recordNavigationTransition(
        fromScreenId: 'events',
        toScreenId: 'home',
      );
      await _flushAsyncWork();
      controller.recordRouteReturn(screenId: 'home', routeId: 'member_detail');
      await _flushAsyncWork();

      expect(analyticsTracker.opportunityShownStates, contains(isNull));
      expect(adService.interstitialLoadRequests, greaterThan(0));
    },
  );
}

Future<void> _flushAsyncWork() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

AdPersistedState _seedPersistedState(DateTime now) {
  return AdPersistedState.initial(now).copyWith(
    firstSeenAt: now.subtract(const Duration(days: 45)),
    totalSessions: 8,
    recentSessionStarts: <DateTime>[
      now.subtract(const Duration(days: 1)),
      now.subtract(const Duration(days: 2)),
      now.subtract(const Duration(days: 3)),
    ],
    lastSessionEndedAt: now.subtract(const Duration(hours: 12)),
  );
}

const AdUserState _standardUserState = AdUserState(
  isPremium: false,
  subscriptionTier: 'FREE',
  segment: AdUserSegment.standard,
  daysSinceFirstSeen: 45,
  totalSessions: 8,
  recentSessions7d: 3,
  recentShortSessions7d: 0,
  adFrustrationSignals7d: 0,
  interstitialsLast24h: 0,
  hasRecentPremiumIntent: false,
  isReturningAfterGap: false,
);

const AdUserState _highlyEngagedUserState = AdUserState(
  isPremium: false,
  subscriptionTier: 'FREE',
  segment: AdUserSegment.highlyEngaged,
  daysSinceFirstSeen: 45,
  totalSessions: 12,
  recentSessions7d: 7,
  recentShortSessions7d: 0,
  adFrustrationSignals7d: 0,
  interstitialsLast24h: 0,
  hasRecentPremiumIntent: false,
  isReturningAfterGap: false,
);

class _FakeAdService extends AdService {
  int bannerLoadRequests = 0;
  int interstitialLoadRequests = 0;
  int rewardedLoadRequests = 0;
  final bool _interstitialReady = false;
  final bool _rewardedReady = false;

  @override
  BannerAd? get bannerAd => null;

  @override
  bool get isBannerReady => false;

  @override
  bool get isInterstitialReady => _interstitialReady;

  @override
  bool get isRewardedReady => _rewardedReady;

  @override
  bool get isShowingInterstitial => false;

  @override
  bool get isShowingRewarded => false;

  @override
  Future<void> ensureBannerLoaded({
    required String placement,
    required void Function(AdResponseDiagnostics diagnostics) onLoaded,
    required void Function(AdPaidEvent paidEvent) onPaidEvent,
    required void Function(String errorCode) onFailed,
  }) async {
    bannerLoadRequests += 1;
  }

  @override
  Future<void> ensureInterstitialLoaded({
    required void Function(AdResponseDiagnostics diagnostics) onLoaded,
    required void Function(String errorCode) onFailed,
  }) async {
    interstitialLoadRequests += 1;
  }

  @override
  Future<void> ensureRewardedLoaded({
    required void Function(AdResponseDiagnostics diagnostics) onLoaded,
    required void Function(String errorCode) onFailed,
  }) async {
    rewardedLoadRequests += 1;
  }

  @override
  Future<bool> showInterstitial({
    required void Function() onShown,
    required void Function(int dismissDelaySec) onDismissed,
    required void Function(String errorCode) onFailedToShow,
    required void Function(AdPaidEvent paidEvent) onPaidEvent,
  }) async {
    return _interstitialReady;
  }

  @override
  Future<bool> showRewarded({
    required void Function() onShown,
    required void Function(int dismissDelaySec, bool rewardEarned) onDismissed,
    required void Function(String errorCode) onFailedToShow,
    required void Function(int rewardAmount, String rewardType) onRewardEarned,
    required void Function(AdPaidEvent paidEvent) onPaidEvent,
  }) async {
    return _rewardedReady;
  }
}

class _FakeAdRemoteConfigProvider implements AdRemoteConfigProvider {
  @override
  Future<AdPolicy> load() async => AdPolicy.defaults;
}

class _InMemoryAdPersistenceStore implements AdPersistenceStore {
  _InMemoryAdPersistenceStore(this._state);

  AdPersistedState _state;

  @override
  Future<AdPersistedState> load(DateTime now) async => _state;

  @override
  Future<void> save(AdPersistedState state) async {
    _state = state;
  }
}

class _FixedUserSegmentationService extends UserSegmentationService {
  const _FixedUserSegmentationService(this._userState);

  final AdUserState _userState;

  @override
  AdUserState buildUserState({
    required AdPersistedState persisted,
    required DateTime now,
    required bool isPremium,
    required String subscriptionTier,
    required AdPolicy policy,
  }) {
    return _userState;
  }
}

class _SpyAdAnalyticsTracker extends NoopAdAnalyticsTracker {
  final List<bool?> opportunityShownStates = <bool?>[];

  @override
  Future<void> trackOpportunity({
    required AdOpportunityContext context,
    required AdUserState userState,
    required bool eligible,
    required String blockReason,
    required String policyVersion,
    int? score,
    bool? shown,
  }) async {
    opportunityShownStates.add(shown);
  }
}
