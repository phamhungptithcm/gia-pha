import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../../core/services/app_environment.dart';
import '../../../core/services/app_logger.dart';
import 'ad_consent_service.dart';
import 'ad_diagnostics_models.dart';

class AdService {
  AdService();

  static const String _androidBannerTestAdUnitId =
      'ca-app-pub-3940256099942544/6300978111';
  static const String _iosBannerTestAdUnitId =
      'ca-app-pub-3940256099942544/2934735716';
  static const String _androidInterstitialTestAdUnitId =
      'ca-app-pub-3940256099942544/1033173712';
  static const String _iosInterstitialTestAdUnitId =
      'ca-app-pub-3940256099942544/4411468910';
  static const String _androidRewardedTestAdUnitId =
      'ca-app-pub-3940256099942544/5224354917';
  static const String _iosRewardedTestAdUnitId =
      'ca-app-pub-3940256099942544/1712485313';

  static bool _canRequestAds = false;
  static bool _sdkInitialized = false;

  static bool get canRequestAds => _canRequestAds;
  static bool get isSdkInitialized => _sdkInitialized;

  @visibleForTesting
  static void debugSetAdsStateForTesting({
    required bool canRequestAds,
    required bool sdkInitialized,
  }) {
    _canRequestAds = canRequestAds;
    _sdkInitialized = sdkInitialized;
  }

  static Future<void> initializeSdk({AdConsentService? consentService}) async {
    if (kIsWeb) {
      _canRequestAds = false;
      _sdkInitialized = false;
      return;
    }
    try {
      final consentResult =
          await (consentService ?? createDefaultAdConsentService())
              .gatherConsent();
      _canRequestAds = consentResult.canRequestAds;
      if (!_canRequestAds) {
        _sdkInitialized = false;
        AppLogger.info(
          'Ads remain disabled because consent does not allow ad requests yet.',
        );
        return;
      }
      await MobileAds.instance.initialize();
      _sdkInitialized = true;
      AppLogger.info('Google Mobile Ads SDK initialized.');
    } catch (error, stackTrace) {
      _canRequestAds = false;
      _sdkInitialized = false;
      AppLogger.warning(
        'Google Mobile Ads SDK initialization failed; app will continue without ads.',
        error,
        stackTrace,
      );
    }
  }

  BannerAd? _bannerAd;
  InterstitialAd? _interstitialAd;
  RewardedAd? _rewardedAd;
  int? _bannerWidthDp;
  String? _bannerPlacement;
  bool _loadingBanner = false;
  bool _loadingInterstitial = false;
  bool _loadingRewarded = false;
  bool _showingInterstitial = false;
  bool _showingRewarded = false;

  BannerAd? get bannerAd => _bannerAd;
  bool get isBannerReady => _bannerAd != null;
  bool get isInterstitialReady => _interstitialAd != null;
  bool get isRewardedReady => _rewardedAd != null;
  bool get isShowingInterstitial => _showingInterstitial;
  bool get isShowingRewarded => _showingRewarded;

  Future<void> ensureBannerLoaded({
    required String placement,
    required void Function(AdResponseDiagnostics diagnostics) onLoaded,
    required void Function(AdPaidEvent paidEvent) onPaidEvent,
    required void Function(String errorCode) onFailed,
  }) async {
    if (kIsWeb || _loadingBanner) {
      return;
    }
    final widthDp = _currentBannerWidthDp();
    if (widthDp == null || widthDp <= 0) {
      onFailed('banner_size_unavailable');
      return;
    }
    if (_bannerAd != null &&
        _bannerWidthDp == widthDp &&
        _bannerPlacement == placement) {
      return;
    }
    if (_bannerAd != null &&
        (_bannerWidthDp != widthDp || _bannerPlacement != placement)) {
      disposeBanner();
    }
    final adUnitId = _bannerAdUnitIdForPlatform();
    if (adUnitId == null) {
      onFailed('banner_ad_unit_missing');
      return;
    }

    _loadingBanner = true;
    final size = await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(
      widthDp,
    );
    if (size == null) {
      _loadingBanner = false;
      onFailed('banner_size_unavailable');
      return;
    }
    final banner = BannerAd(
      adUnitId: adUnitId,
      request: const AdRequest(),
      size: size,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          _loadingBanner = false;
          _bannerAd?.dispose();
          _bannerAd = ad as BannerAd;
          _bannerWidthDp = widthDp;
          _bannerPlacement = placement;
          onLoaded(
            AdResponseDiagnostics.fromResponseInfo(_bannerAd?.responseInfo),
          );
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          _loadingBanner = false;
          _bannerAd = null;
          _bannerWidthDp = null;
          _bannerPlacement = null;
          onFailed(error.code.toString());
        },
        onPaidEvent: (ad, valueMicros, precision, currencyCode) {
          onPaidEvent(
            AdPaidEvent.fromAdValue(
              valueMicros: valueMicros,
              precision: precision,
              currencyCode: currencyCode,
              responseInfo: (ad as BannerAd).responseInfo,
            ),
          );
        },
      ),
    );

    try {
      await banner.load();
    } catch (error, stackTrace) {
      _loadingBanner = false;
      _bannerAd = null;
      _bannerWidthDp = null;
      _bannerPlacement = null;
      onFailed('banner_load_exception');
      AppLogger.warning(
        'Banner ad load threw an exception.',
        error,
        stackTrace,
      );
    }
  }

  Future<void> ensureInterstitialLoaded({
    required void Function(AdResponseDiagnostics diagnostics) onLoaded,
    required void Function(String errorCode) onFailed,
  }) async {
    if (kIsWeb || _loadingInterstitial || _interstitialAd != null) {
      return;
    }
    final adUnitId = _interstitialAdUnitIdForPlatform();
    if (adUnitId == null) {
      onFailed('interstitial_ad_unit_missing');
      return;
    }

    _loadingInterstitial = true;
    try {
      await InterstitialAd.load(
        adUnitId: adUnitId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            _loadingInterstitial = false;
            _interstitialAd?.dispose();
            _interstitialAd = ad;
            onLoaded(
              AdResponseDiagnostics.fromResponseInfo(
                _interstitialAd?.responseInfo,
              ),
            );
          },
          onAdFailedToLoad: (error) {
            _loadingInterstitial = false;
            _interstitialAd = null;
            onFailed(error.code.toString());
          },
        ),
      );
    } catch (error, stackTrace) {
      _loadingInterstitial = false;
      _interstitialAd = null;
      onFailed('interstitial_load_exception');
      AppLogger.warning(
        'Interstitial ad load threw an exception.',
        error,
        stackTrace,
      );
    }
  }

  Future<void> ensureRewardedLoaded({
    required void Function(AdResponseDiagnostics diagnostics) onLoaded,
    required void Function(String errorCode) onFailed,
  }) async {
    if (kIsWeb || _loadingRewarded || _rewardedAd != null) {
      return;
    }
    final adUnitId = _rewardedAdUnitIdForPlatform();
    if (adUnitId == null) {
      onFailed('rewarded_ad_unit_missing');
      return;
    }

    _loadingRewarded = true;
    try {
      await RewardedAd.load(
        adUnitId: adUnitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            _loadingRewarded = false;
            _rewardedAd?.dispose();
            _rewardedAd = ad;
            onLoaded(
              AdResponseDiagnostics.fromResponseInfo(_rewardedAd?.responseInfo),
            );
          },
          onAdFailedToLoad: (error) {
            _loadingRewarded = false;
            _rewardedAd = null;
            onFailed(error.code.toString());
          },
        ),
      );
    } catch (error, stackTrace) {
      _loadingRewarded = false;
      _rewardedAd = null;
      onFailed('rewarded_load_exception');
      AppLogger.warning(
        'Rewarded ad load threw an exception.',
        error,
        stackTrace,
      );
    }
  }

  Future<bool> showInterstitial({
    required VoidCallback onShown,
    required void Function(int dismissDelaySec) onDismissed,
    required void Function(String errorCode) onFailedToShow,
    required void Function(AdPaidEvent paidEvent) onPaidEvent,
  }) async {
    final ad = _interstitialAd;
    if (kIsWeb || ad == null || _showingInterstitial) {
      return false;
    }

    _showingInterstitial = true;
    _interstitialAd = null;
    final shownAt = DateTime.now();
    ad.onPaidEvent = (_, valueMicros, precision, currencyCode) {
      onPaidEvent(
        AdPaidEvent.fromAdValue(
          valueMicros: valueMicros,
          precision: precision,
          currencyCode: currencyCode,
          responseInfo: ad.responseInfo,
        ),
      );
    };

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        onShown();
      },
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _showingInterstitial = false;
        onDismissed(DateTime.now().difference(shownAt).inSeconds);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _showingInterstitial = false;
        onFailedToShow(error.code.toString());
      },
    );

    try {
      ad.show();
      return true;
    } catch (error, stackTrace) {
      _showingInterstitial = false;
      onFailedToShow('interstitial_show_exception');
      AppLogger.warning(
        'Interstitial ad show threw an exception.',
        error,
        stackTrace,
      );
      return false;
    }
  }

  Future<bool> showRewarded({
    required VoidCallback onShown,
    required void Function(int dismissDelaySec, bool rewardEarned) onDismissed,
    required void Function(String errorCode) onFailedToShow,
    required void Function(int rewardAmount, String rewardType) onRewardEarned,
    required void Function(AdPaidEvent paidEvent) onPaidEvent,
  }) async {
    final ad = _rewardedAd;
    if (kIsWeb || ad == null || _showingRewarded) {
      return false;
    }

    _showingRewarded = true;
    _rewardedAd = null;
    var rewardEarned = false;
    final shownAt = DateTime.now();
    ad.onPaidEvent = (_, valueMicros, precision, currencyCode) {
      onPaidEvent(
        AdPaidEvent.fromAdValue(
          valueMicros: valueMicros,
          precision: precision,
          currencyCode: currencyCode,
          responseInfo: ad.responseInfo,
        ),
      );
    };

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        onShown();
      },
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _showingRewarded = false;
        onDismissed(DateTime.now().difference(shownAt).inSeconds, rewardEarned);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _showingRewarded = false;
        onFailedToShow(error.code.toString());
      },
    );

    try {
      ad.show(
        onUserEarnedReward: (_, reward) {
          rewardEarned = true;
          onRewardEarned(reward.amount.toInt(), reward.type);
        },
      );
      return true;
    } catch (error, stackTrace) {
      _showingRewarded = false;
      onFailedToShow('rewarded_show_exception');
      AppLogger.warning(
        'Rewarded ad show threw an exception.',
        error,
        stackTrace,
      );
      return false;
    }
  }

  void disposeBanner() {
    _bannerAd?.dispose();
    _bannerAd = null;
    _bannerWidthDp = null;
    _bannerPlacement = null;
    _loadingBanner = false;
  }

  void disposeInterstitial() {
    _interstitialAd?.dispose();
    _interstitialAd = null;
    _loadingInterstitial = false;
    _showingInterstitial = false;
  }

  void disposeRewarded() {
    _rewardedAd?.dispose();
    _rewardedAd = null;
    _loadingRewarded = false;
    _showingRewarded = false;
  }

  void dispose() {
    disposeBanner();
    disposeInterstitial();
    disposeRewarded();
  }

  String? _bannerAdUnitIdForPlatform() {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return _resolveAdUnitId(
          configured: AppEnvironment.adMobAndroidBannerUnitId,
          test: _androidBannerTestAdUnitId,
        );
      case TargetPlatform.iOS:
        return _resolveAdUnitId(
          configured: AppEnvironment.adMobIosBannerUnitId,
          test: _iosBannerTestAdUnitId,
        );
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        return null;
    }
  }

  String? _interstitialAdUnitIdForPlatform() {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return _resolveAdUnitId(
          configured: AppEnvironment.adMobAndroidInterstitialUnitId,
          test: _androidInterstitialTestAdUnitId,
        );
      case TargetPlatform.iOS:
        return _resolveAdUnitId(
          configured: AppEnvironment.adMobIosInterstitialUnitId,
          test: _iosInterstitialTestAdUnitId,
        );
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        return null;
    }
  }

  String? _rewardedAdUnitIdForPlatform() {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return _resolveAdUnitId(
          configured: AppEnvironment.adMobAndroidRewardedUnitId,
          test: _androidRewardedTestAdUnitId,
        );
      case TargetPlatform.iOS:
        return _resolveAdUnitId(
          configured: AppEnvironment.adMobIosRewardedUnitId,
          test: _iosRewardedTestAdUnitId,
        );
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        return null;
    }
  }

  String? _resolveAdUnitId({required String configured, required String test}) {
    final normalized = configured.trim();
    if (normalized.isNotEmpty) {
      return normalized;
    }
    if (!kReleaseMode) {
      return test;
    }
    return null;
  }

  int? _currentBannerWidthDp() {
    final views = WidgetsBinding.instance.platformDispatcher.views;
    if (views.isEmpty) {
      return null;
    }
    final view = views.first;
    final mediaQuery = MediaQueryData.fromView(view);
    final widthDp = mediaQuery.size.width - mediaQuery.padding.horizontal;
    if (widthDp <= 0) {
      return null;
    }
    return widthDp.truncate();
  }
}
