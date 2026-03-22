import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../../core/services/app_logger.dart';

class AdController {
  AdController({VoidCallback? onStateChanged})
    : _onStateChanged = onStateChanged;

  static const int _defaultInterstitialInterval = 4;

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

  String _currentTier = 'FREE';
  bool _adsEnabled = false;
  bool _bannerLoadFailed = false;
  final VoidCallback? _onStateChanged;
  bool _isDisposed = false;

  BannerAd? _bannerAd;
  bool _isBannerReady = false;
  bool _isLoadingBanner = false;

  InterstitialAd? _interstitialAd;
  bool _isInterstitialReady = false;
  bool _isLoadingInterstitial = false;
  bool _isShowingInterstitial = false;
  int _safeActionCount = 0;
  int _nextInterstitialTriggerAt = _defaultInterstitialInterval;

  bool get isBannerReady => _isBannerReady;
  bool get isBannerFallbackVisible =>
      _adsEnabled && (_bannerLoadFailed || !_isBannerReady);
  BannerAd? get bannerAd => _bannerAd;

  void _notifyStateChanged() {
    if (_isDisposed) {
      return;
    }
    _onStateChanged?.call();
  }

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
    // Safe fallback for unknown tiers: hide ads to prevent unexpected display.
    return false;
  }

  void updateAdPolicy({
    required String subscriptionTier,
    required bool backendShowAds,
  }) {
    _currentTier = subscriptionTier.trim().toUpperCase();
    final shouldEnable = shouldShowAds(
      tier: _currentTier,
      backendShowAds: backendShowAds,
    );
    if (!shouldEnable) {
      _adsEnabled = false;
      _safeActionCount = 0;
      _nextInterstitialTriggerAt = _defaultInterstitialInterval;
      _disposeBannerAd();
      _disposeInterstitialAd();
      _notifyStateChanged();
      return;
    }

    _adsEnabled = true;
    _ensureBannerLoaded();
    _ensureInterstitialLoaded();
    _notifyStateChanged();
  }

  void onSafeUserAction() {
    if (!_adsEnabled || kIsWeb || _isShowingInterstitial) {
      return;
    }

    _safeActionCount += 1;
    if (_safeActionCount < _nextInterstitialTriggerAt) {
      return;
    }

    final ad = _interstitialAd;
    if (ad == null || !_isInterstitialReady) {
      // Do not spam retries; push the next opportunity out by 2 actions.
      _nextInterstitialTriggerAt = _safeActionCount + 2;
      _ensureInterstitialLoaded();
      return;
    }

    _interstitialAd = null;
    _isInterstitialReady = false;
    _isShowingInterstitial = true;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _isShowingInterstitial = false;
        _safeActionCount = 0;
        _nextInterstitialTriggerAt = _defaultInterstitialInterval;
        _ensureInterstitialLoaded();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _isShowingInterstitial = false;
        _nextInterstitialTriggerAt = _safeActionCount + 2;
        _ensureInterstitialLoaded();
        AppLogger.warning('Interstitial ad failed to show.', error);
      },
    );
    try {
      ad.show();
    } catch (error, stackTrace) {
      _isShowingInterstitial = false;
      _nextInterstitialTriggerAt = _safeActionCount + 2;
      _ensureInterstitialLoaded();
      AppLogger.warning(
        'Interstitial ad show threw an exception.',
        error,
        stackTrace,
      );
    }
  }

  void _ensureBannerLoaded() {
    if (!_adsEnabled || kIsWeb || _isLoadingBanner || _bannerAd != null) {
      return;
    }
    final adUnitId = _bannerAdUnitIdForPlatform();
    if (adUnitId == null) {
      return;
    }

    _isLoadingBanner = true;
    _bannerLoadFailed = false;
    final banner = BannerAd(
      adUnitId: adUnitId,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          _isLoadingBanner = false;
          if (!_adsEnabled) {
            ad.dispose();
            return;
          }
          _bannerAd?.dispose();
          _bannerAd = ad as BannerAd;
          _isBannerReady = true;
          _notifyStateChanged();
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          _isLoadingBanner = false;
          _bannerAd = null;
          _isBannerReady = false;
          _bannerLoadFailed = true;
          _notifyStateChanged();
          AppLogger.warning('Banner ad failed to load.', error);
        },
      ),
    );
    try {
      banner.load();
    } catch (error, stackTrace) {
      _isLoadingBanner = false;
      _bannerAd = null;
      _isBannerReady = false;
      _bannerLoadFailed = true;
      _notifyStateChanged();
      AppLogger.warning(
        'Banner ad load threw an exception.',
        error,
        stackTrace,
      );
    }
  }

  void _ensureInterstitialLoaded() {
    if (!_adsEnabled ||
        kIsWeb ||
        _isLoadingInterstitial ||
        _isShowingInterstitial ||
        _interstitialAd != null) {
      return;
    }
    final adUnitId = _interstitialAdUnitIdForPlatform();
    if (adUnitId == null) {
      return;
    }

    _isLoadingInterstitial = true;
    try {
      InterstitialAd.load(
        adUnitId: adUnitId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            _isLoadingInterstitial = false;
            if (!_adsEnabled) {
              ad.dispose();
              return;
            }
            _interstitialAd?.dispose();
            _interstitialAd = ad;
            _isInterstitialReady = true;
            _notifyStateChanged();
          },
          onAdFailedToLoad: (error) {
            _isLoadingInterstitial = false;
            _interstitialAd = null;
            _isInterstitialReady = false;
            _notifyStateChanged();
            AppLogger.warning('Interstitial ad failed to load.', error);
          },
        ),
      );
    } catch (error, stackTrace) {
      _isLoadingInterstitial = false;
      _interstitialAd = null;
      _isInterstitialReady = false;
      _notifyStateChanged();
      AppLogger.warning(
        'Interstitial ad load threw an exception.',
        error,
        stackTrace,
      );
    }
  }

  String? _bannerAdUnitIdForPlatform() {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return _androidBannerTestAdUnitId;
      case TargetPlatform.iOS:
        return _iosBannerTestAdUnitId;
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
        return _androidInterstitialTestAdUnitId;
      case TargetPlatform.iOS:
        return _iosInterstitialTestAdUnitId;
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        return null;
    }
  }

  void _disposeBannerAd({bool notify = true}) {
    _bannerAd?.dispose();
    _bannerAd = null;
    _isBannerReady = false;
    _isLoadingBanner = false;
    _bannerLoadFailed = false;
    if (notify) {
      _notifyStateChanged();
    }
  }

  void _disposeInterstitialAd({bool notify = true}) {
    _interstitialAd?.dispose();
    _interstitialAd = null;
    _isInterstitialReady = false;
    _isLoadingInterstitial = false;
    _isShowingInterstitial = false;
    if (notify) {
      _notifyStateChanged();
    }
  }

  void dispose() {
    if (_isDisposed) {
      return;
    }
    _isDisposed = true;
    _adsEnabled = false;
    _disposeBannerAd(notify: false);
    _disposeInterstitialAd(notify: false);
  }
}
