import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../../core/services/app_logger.dart';
import 'ad_analytics_tracker.dart';
import 'ad_eligibility_evaluator.dart';
import 'ad_persistence_store.dart';
import 'ad_policy.dart';
import 'ad_remote_config_provider.dart';
import 'ad_runtime_models.dart';
import 'ad_service.dart';
import 'screen_context_policy.dart';
import 'user_segmentation_service.dart';

class AdController {
  AdController({
    VoidCallback? onStateChanged,
    AdService? adService,
    AdRemoteConfigProvider? remoteConfigProvider,
    AdPersistenceStore? persistenceStore,
    AdAnalyticsTracker? analyticsTracker,
    AdEligibilityEvaluator? eligibilityEvaluator,
    UserSegmentationService? segmentationService,
    DateTime Function()? clock,
  }) : _onStateChanged = onStateChanged,
       _adService = adService ?? AdService(),
       _remoteConfigProvider =
           remoteConfigProvider ?? createDefaultAdRemoteConfigProvider(),
       _persistenceStore = persistenceStore ?? SharedPrefsAdPersistenceStore(),
       _analyticsTracker =
           analyticsTracker ?? createDefaultAdAnalyticsTracker(),
       _eligibilityEvaluator =
           eligibilityEvaluator ?? const AdEligibilityEvaluator(),
       _segmentationService =
           segmentationService ?? const UserSegmentationService(),
       _clock = clock ?? DateTime.now;

  static Future<void> initializeSdk() => AdService.initializeSdk();

  final VoidCallback? _onStateChanged;
  final AdService _adService;
  final AdRemoteConfigProvider _remoteConfigProvider;
  final AdPersistenceStore _persistenceStore;
  final AdAnalyticsTracker _analyticsTracker;
  final AdEligibilityEvaluator _eligibilityEvaluator;
  final UserSegmentationService _segmentationService;
  final DateTime Function() _clock;

  bool _isDisposed = false;
  bool _isInitialized = false;
  bool _adsEnabled = false;
  bool _bannerLoadFailed = false;
  bool _refreshingPolicy = false;
  String _currentTier = 'FREE';
  bool _backendShowAds = true;
  String _currentScreenId = 'home';
  AdPolicy _policy = AdPolicy.defaults;
  AdPersistedState? _persistedState;
  AdSessionState? _sessionState;
  AdUserState? _userState;

  BannerAd? get bannerAd => _adService.bannerAd;
  bool get isBannerReady => _adService.isBannerReady;
  bool get isBannerFallbackVisible =>
      _shouldPlaceBannerOnCurrentScreen && _bannerLoadFailed;
  bool get isBannerPlacementVisible =>
      _shouldPlaceBannerOnCurrentScreen &&
      (isBannerReady || isBannerFallbackVisible);
  bool get hasAdsEnabled => _adsEnabled;

  bool shouldShowAds({String? tier, bool backendShowAds = true}) {
    final normalizedTier = (tier ?? _currentTier).trim().toUpperCase();
    if (!backendShowAds) {
      return false;
    }
    if (normalizedTier == 'FREE' || normalizedTier == 'BASE') {
      return true;
    }
    if (normalizedTier == 'PLUS' || normalizedTier == 'PRO') {
      return false;
    }
    return false;
  }

  Future<void> initialize({required String initialScreenId}) async {
    if (_isDisposed || _isInitialized) {
      return;
    }
    _currentScreenId = initialScreenId.trim().toLowerCase();
    _policy = await _remoteConfigProvider.load();
    final now = _clock();
    final persisted = await _persistenceStore.load(now);
    final suspectedCrash =
        persisted.sessionOpenMarkerAt != null &&
        now.difference(persisted.sessionOpenMarkerAt!) <=
            const Duration(hours: 6);
    _persistedState = persisted
        .prune(now)
        .copyWith(
          totalSessions: persisted.totalSessions + 1,
          recentSessionStarts: [...persisted.recentSessionStarts, now],
          sessionOpenMarkerAt: now,
        )
        .prune(now);
    await _savePersistedState();

    _sessionState = AdSessionState(
      startedAt: now,
      currentScreenId: _currentScreenId,
      suspectedCrashReopen: suspectedCrash,
    );
    if (suspectedCrash && _policy.postCrashSuppressSessions > 0) {
      _sessionState!.crashSuppressSessionsRemaining =
          _policy.postCrashSuppressSessions;
    }
    _isInitialized = true;
    await _recomputeState();
    await _warmAdsIfNeeded();
    _notifyStateChanged();
  }

  void updateAdPolicy({
    required String subscriptionTier,
    required bool backendShowAds,
  }) {
    _currentTier = subscriptionTier.trim().toUpperCase();
    _backendShowAds = backendShowAds;
    unawaited(_recomputeState(refreshPolicy: true));
  }

  void updateCurrentScreen(String screenId) {
    _currentScreenId = screenId.trim().toLowerCase();
    final sessionState = _sessionState;
    if (sessionState == null) {
      return;
    }
    sessionState.currentScreenId = _currentScreenId;
    _maybeTrackScreenAfterAd(nextScreenId: _currentScreenId);
    unawaited(_warmAdsIfNeeded());
    _notifyStateChanged();
  }

  void recordNavigationTransition({
    required String fromScreenId,
    required String toScreenId,
  }) {
    final sessionState = _sessionState;
    if (_isDisposed || !_isInitialized || sessionState == null) {
      return;
    }

    final normalizedFrom = fromScreenId.trim().toLowerCase();
    final normalizedTo = toScreenId.trim().toLowerCase();
    sessionState.recordMeaningfulAction();
    sessionState.recordScreenTransition(toScreenId: normalizedTo);
    _currentScreenId = normalizedTo;

    if (normalizedTo == 'billing') {
      unawaited(markPremiumIntent(source: 'billing_tab'));
    }

    _maybeTrackScreenAfterAd(nextScreenId: normalizedTo);
    unawaited(_warmAdsIfNeeded());
    _notifyStateChanged();

    final targetPolicy = ScreenContextPolicy.forScreen(normalizedTo);
    final context = AdOpportunityContext(
      screenId: normalizedTo,
      placementId: 'shell_${normalizedFrom}_to_$normalizedTo',
      breakpointType: 'shell_tab_switch',
      source: 'shell_navigation',
      isNaturalBreakpoint: true,
      isBadMoment: targetPolicy.isBadMomentForInterstitial,
    );
    unawaited(_evaluateAndMaybeShowInterstitial(context));
  }

  void recordRouteReturn({
    required String screenId,
    required String routeId,
    bool importantActionCompleted = false,
  }) {
    final sessionState = _sessionState;
    if (_isDisposed || !_isInitialized || sessionState == null) {
      return;
    }

    final normalizedScreen = screenId.trim().toLowerCase();
    if (importantActionCompleted) {
      recordImportantAction(screenId: normalizedScreen);
    }

    sessionState.recordMeaningfulAction();
    _currentScreenId = normalizedScreen;
    _maybeTrackScreenAfterAd(nextScreenId: normalizedScreen);
    unawaited(_warmAdsIfNeeded());
    _notifyStateChanged();

    final screenPolicy = ScreenContextPolicy.forScreen(normalizedScreen);
    final context = AdOpportunityContext(
      screenId: normalizedScreen,
      placementId: 'return_${routeId.trim().toLowerCase()}',
      breakpointType: importantActionCompleted
          ? 'task_complete'
          : 'route_return',
      source: 'route_return',
      isNaturalBreakpoint: true,
      isBadMoment: screenPolicy.isBadMomentForInterstitial,
      importantActionCompleted: importantActionCompleted,
    );
    unawaited(_evaluateAndMaybeShowInterstitial(context));
  }

  void recordImportantAction({String? screenId}) {
    final sessionState = _sessionState;
    if (_isDisposed || !_isInitialized || sessionState == null) {
      return;
    }
    if (screenId != null && screenId.trim().isNotEmpty) {
      _currentScreenId = screenId.trim().toLowerCase();
    }
    sessionState.recordMeaningfulAction();
    sessionState.recordImportantAction(_clock());
    _notifyStateChanged();
  }

  Future<void> markPremiumIntent({required String source}) async {
    final persisted = _persistedState;
    final userState = _userState;
    if (_isDisposed || persisted == null || userState == null) {
      return;
    }

    final now = _clock();
    _persistedState = persisted
        .copyWith(
          premiumIntentSignals: [...persisted.premiumIntentSignals, now],
        )
        .prune(now);
    await _savePersistedState();
    await _recomputeState();
    await _analyticsTracker.trackPremiumIntent(
      source: source,
      userState: _userState ?? userState,
    );
  }

  Future<void> onAppLifecycleStateChanged(AppLifecycleState state) async {
    final persisted = _persistedState;
    final sessionState = _sessionState;
    final userState = _userState;
    if (_isDisposed ||
        !_isInitialized ||
        persisted == null ||
        sessionState == null ||
        userState == null) {
      return;
    }

    final now = _clock();
    switch (state) {
      case AppLifecycleState.resumed:
        _persistedState = persisted.copyWith(sessionOpenMarkerAt: now);
        await _savePersistedState();
        await _warmAdsIfNeeded();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        if (sessionState.awaitingScreenAfterAdEvent &&
            sessionState.timeSinceLastDismissSec(now) <=
                _policy.sessionExitAfterAdWindowSec &&
            sessionState.lastAdFormat != null &&
            sessionState.lastAdPlacement != null) {
          await _analyticsTracker.trackSessionExitAfterAd(
            format: sessionState.lastAdFormat!,
            placement: sessionState.lastAdPlacement!,
            userState: userState,
            secondsFromDismiss: sessionState.timeSinceLastDismissSec(now),
          );
          _persistedState = persisted
              .copyWith(
                recentAdFrustrationSignals: [
                  ...persisted.recentAdFrustrationSignals,
                  now,
                ],
              )
              .prune(now);
          sessionState.awaitingScreenAfterAdEvent = false;
          await _savePersistedState();
          await _recomputeState();
        }
        _persistedState = (_persistedState ?? persisted).copyWith(
          clearSessionOpenMarkerAt: true,
        );
        await _savePersistedState();
        break;
    }
  }

  Future<void> _recomputeState({bool refreshPolicy = false}) async {
    if (_isDisposed || _persistedState == null) {
      return;
    }
    if (refreshPolicy && !_refreshingPolicy) {
      _refreshingPolicy = true;
      try {
        _policy = await _remoteConfigProvider.load();
      } finally {
        _refreshingPolicy = false;
      }
    }

    final normalizedTier = _currentTier.trim().isEmpty ? 'FREE' : _currentTier;
    final isPremium = !shouldShowAds(
      tier: normalizedTier,
      backendShowAds: _backendShowAds,
    );
    _userState = _segmentationService.buildUserState(
      persisted: _persistedState!,
      now: _clock(),
      isPremium: isPremium,
      subscriptionTier: normalizedTier,
      policy: _policy,
    );
    _adsEnabled = !kIsWeb && _policy.adsEnabled && !isPremium;
    await _analyticsTracker.syncUserState(
      _userState!,
      policyVersion: _policy.policyVersion,
    );

    if (!_adsEnabled) {
      _bannerLoadFailed = false;
      _adService.dispose();
    }
    _notifyStateChanged();
  }

  Future<void> _warmAdsIfNeeded() async {
    final userState = _userState;
    if (_isDisposed || !_isInitialized || !_adsEnabled || userState == null) {
      return;
    }

    if (_shouldPlaceBannerOnCurrentScreen) {
      await _requestBanner(userState: userState);
    }
    await _requestInterstitial(userState: userState);
  }

  bool get _shouldPlaceBannerOnCurrentScreen {
    final screenPolicy = ScreenContextPolicy.forScreen(_currentScreenId);
    return _adsEnabled &&
        screenPolicy.allowBanner &&
        _policy.isBannerAllowedOnScreen(_currentScreenId);
  }

  Future<void> _requestBanner({required AdUserState userState}) async {
    if (!_shouldPlaceBannerOnCurrentScreen || _adService.isBannerReady) {
      return;
    }
    await _analyticsTracker.trackRequest(
      format: 'banner',
      placement: 'banner_$_currentScreenId',
      userState: userState,
    );
    await _adService.ensureBannerLoaded(
      onLoaded: () {
        _bannerLoadFailed = false;
        unawaited(
          _analyticsTracker.trackLoaded(
            format: 'banner',
            placement: 'banner_$_currentScreenId',
            userState: userState,
          ),
        );
        _notifyStateChanged();
      },
      onFailed: (errorCode) {
        _bannerLoadFailed = true;
        unawaited(
          _analyticsTracker.trackFailed(
            format: 'banner',
            placement: 'banner_$_currentScreenId',
            userState: userState,
            errorCode: errorCode,
          ),
        );
        _notifyStateChanged();
      },
    );
  }

  Future<void> _requestInterstitial({required AdUserState userState}) async {
    if (_adService.isInterstitialReady || _adService.isShowingInterstitial) {
      return;
    }
    await _analyticsTracker.trackRequest(
      format: 'interstitial',
      placement: 'interstitial_default',
      userState: userState,
    );
    await _adService.ensureInterstitialLoaded(
      onLoaded: () {
        _sessionState?.clearInterstitialLoadFailures();
        unawaited(
          _analyticsTracker.trackLoaded(
            format: 'interstitial',
            placement: 'interstitial_default',
            userState: userState,
          ),
        );
        _notifyStateChanged();
      },
      onFailed: (errorCode) {
        final now = _clock();
        _sessionState?.recordInterstitialLoadFailure(now);
        unawaited(
          _analyticsTracker.trackFailed(
            format: 'interstitial',
            placement: 'interstitial_default',
            userState: userState,
            errorCode: errorCode,
          ),
        );
        _notifyStateChanged();
      },
    );
  }

  Future<void> _evaluateAndMaybeShowInterstitial(
    AdOpportunityContext context,
  ) async {
    final userState = _userState;
    final sessionState = _sessionState;
    final persisted = _persistedState;
    if (_isDisposed ||
        !_adsEnabled ||
        userState == null ||
        sessionState == null ||
        persisted == null) {
      return;
    }

    final now = _clock();
    final decision = _eligibilityEvaluator.evaluateInterstitial(
      context: context,
      userState: userState,
      sessionState: sessionState,
      policy: _policy,
      now: now,
      interstitialReady: _adService.isInterstitialReady,
    );
    await _analyticsTracker.trackOpportunity(
      context: context,
      userState: userState,
      eligible: decision.shouldShow,
      blockReason: decision.reason,
      policyVersion: _policy.policyVersion,
      score: decision.score,
      shown: decision.shouldShow,
    );

    if (!decision.shouldShow) {
      if (decision.reason == 'not_ready' || decision.reason == 'fail_backoff') {
        await _requestInterstitial(userState: userState);
      }
      return;
    }

    sessionState.fullscreenAdShowing = true;
    final showSucceeded = await _adService.showInterstitial(
      onShown: () {
        final shownAt = _clock();
        sessionState.recordInterstitialShown(
          shownAt,
          placementId: context.placementId,
          format: 'interstitial',
        );
        _persistedState = (_persistedState ?? persisted)
            .copyWith(
              interstitialShows: [
                ...(_persistedState ?? persisted).interstitialShows,
                shownAt,
              ],
              lastFullscreenShownAt: shownAt,
              lastInterstitialShownAt: shownAt,
              lastAdPlacement: context.placementId,
              lastAdFormat: 'interstitial',
            )
            .prune(shownAt);
        unawaited(_savePersistedState());
        unawaited(
          _analyticsTracker.trackShown(
            format: 'interstitial',
            placement: context.placementId,
            screenId: context.screenId,
            userState: userState,
            sessionAgeSec: sessionState.sessionAgeSec(shownAt),
          ),
        );
        _notifyStateChanged();
      },
      onDismissed: (dismissDelaySec) {
        final dismissedAt = _clock();
        sessionState.recordInterstitialDismissed(dismissedAt);
        _persistedState = (_persistedState ?? persisted).copyWith(
          lastAdDismissedAt: dismissedAt,
          lastAdPlacement: context.placementId,
          lastAdFormat: 'interstitial',
        );
        unawaited(_savePersistedState());
        unawaited(
          _analyticsTracker.trackDismissed(
            format: 'interstitial',
            placement: context.placementId,
            userState: userState,
            dismissDelaySec: dismissDelaySec,
          ),
        );
        if (sessionState.crashSuppressSessionsRemaining > 0) {
          sessionState.crashSuppressSessionsRemaining -= 1;
          sessionState.suspectedCrashReopen = false;
        }
        unawaited(_requestInterstitial(userState: userState));
        _notifyStateChanged();
      },
      onFailedToShow: (errorCode) {
        final failedAt = _clock();
        sessionState.recordInterstitialShowFailure();
        sessionState.recordInterstitialLoadFailure(failedAt);
        unawaited(
          _analyticsTracker.trackFailed(
            format: 'interstitial',
            placement: context.placementId,
            userState: userState,
            errorCode: errorCode,
          ),
        );
        unawaited(_requestInterstitial(userState: userState));
        _notifyStateChanged();
      },
    );

    if (!showSucceeded) {
      sessionState.fullscreenAdShowing = false;
      await _requestInterstitial(userState: userState);
    }
  }

  void _maybeTrackScreenAfterAd({required String nextScreenId}) {
    final sessionState = _sessionState;
    final userState = _userState;
    if (sessionState == null ||
        userState == null ||
        !sessionState.awaitingScreenAfterAdEvent ||
        sessionState.lastAdFormat == null ||
        sessionState.lastAdPlacement == null) {
      return;
    }

    final secondsFromDismiss = sessionState.timeSinceLastDismissSec(_clock());
    if (secondsFromDismiss > 60) {
      sessionState.awaitingScreenAfterAdEvent = false;
      return;
    }

    sessionState.awaitingScreenAfterAdEvent = false;
    unawaited(
      _analyticsTracker.trackScreenAfterAd(
        previousAdFormat: sessionState.lastAdFormat!,
        previousPlacement: sessionState.lastAdPlacement!,
        nextScreenId: nextScreenId,
        userState: userState,
        secondsFromDismiss: secondsFromDismiss,
      ),
    );
  }

  Future<void> _savePersistedState() async {
    final state = _persistedState;
    if (_isDisposed || state == null) {
      return;
    }
    try {
      await _persistenceStore.save(state);
    } catch (error, stackTrace) {
      AppLogger.warning('Ads persistence save failed.', error, stackTrace);
    }
  }

  void _notifyStateChanged() {
    if (_isDisposed) {
      return;
    }
    _onStateChanged?.call();
  }

  void dispose() {
    if (_isDisposed) {
      return;
    }
    _isDisposed = true;
    final persisted = _persistedState;
    final sessionState = _sessionState;
    if (persisted != null && sessionState != null) {
      final now = _clock();
      _persistedState = persisted.copyWith(
        clearSessionOpenMarkerAt: true,
        lastSessionEndedAt: now,
      );
      unawaited(_savePersistedState());
    }
    _adService.dispose();
  }
}
