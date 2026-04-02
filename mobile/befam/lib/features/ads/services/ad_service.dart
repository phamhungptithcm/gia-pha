import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../../core/services/app_environment.dart';
import '../../../core/services/app_logger.dart';

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

  static Future<void> initializeSdk() async {
    if (kIsWeb) {
      return;
    }
    try {
      await MobileAds.instance.initialize();
      AppLogger.info('Google Mobile Ads SDK initialized.');
    } catch (error, stackTrace) {
      AppLogger.warning(
        'Google Mobile Ads SDK initialization failed; app will continue without ads.',
        error,
        stackTrace,
      );
    }
  }

  BannerAd? _bannerAd;
  InterstitialAd? _interstitialAd;
  bool _loadingBanner = false;
  bool _loadingInterstitial = false;
  bool _showingInterstitial = false;

  BannerAd? get bannerAd => _bannerAd;
  bool get isBannerReady => _bannerAd != null;
  bool get isInterstitialReady => _interstitialAd != null;
  bool get isShowingInterstitial => _showingInterstitial;

  Future<void> ensureBannerLoaded({
    required VoidCallback onLoaded,
    required void Function(String errorCode) onFailed,
  }) async {
    if (kIsWeb || _loadingBanner || _bannerAd != null) {
      return;
    }
    final adUnitId = _bannerAdUnitIdForPlatform();
    if (adUnitId == null) {
      onFailed('banner_ad_unit_missing');
      return;
    }

    _loadingBanner = true;
    final banner = BannerAd(
      adUnitId: adUnitId,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          _loadingBanner = false;
          _bannerAd?.dispose();
          _bannerAd = ad as BannerAd;
          onLoaded();
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          _loadingBanner = false;
          _bannerAd = null;
          onFailed(error.code.toString());
        },
      ),
    );

    try {
      await banner.load();
    } catch (error, stackTrace) {
      _loadingBanner = false;
      _bannerAd = null;
      onFailed('banner_load_exception');
      AppLogger.warning(
        'Banner ad load threw an exception.',
        error,
        stackTrace,
      );
    }
  }

  Future<void> ensureInterstitialLoaded({
    required VoidCallback onLoaded,
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
            onLoaded();
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

  Future<bool> showInterstitial({
    required VoidCallback onShown,
    required void Function(int dismissDelaySec) onDismissed,
    required void Function(String errorCode) onFailedToShow,
  }) async {
    final ad = _interstitialAd;
    if (kIsWeb || ad == null || _showingInterstitial) {
      return false;
    }

    _showingInterstitial = true;
    _interstitialAd = null;
    final shownAt = DateTime.now();

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

  void disposeBanner() {
    _bannerAd?.dispose();
    _bannerAd = null;
    _loadingBanner = false;
  }

  void disposeInterstitial() {
    _interstitialAd?.dispose();
    _interstitialAd = null;
    _loadingInterstitial = false;
    _showingInterstitial = false;
  }

  void dispose() {
    disposeBanner();
    disposeInterstitial();
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
}
