import 'dart:async';

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

import '../../../core/services/app_logger.dart';
import 'ad_policy.dart';
import 'ad_remote_config_keys.dart';

abstract class AdRemoteConfigProvider {
  Future<AdPolicy> load();
}

class FirebaseAdRemoteConfigProvider implements AdRemoteConfigProvider {
  FirebaseAdRemoteConfigProvider({FirebaseRemoteConfig? remoteConfig})
    : _remoteConfig = remoteConfig ?? FirebaseRemoteConfig.instance;

  final FirebaseRemoteConfig _remoteConfig;
  AdPolicy? _cache;
  DateTime? _cacheLoadedAt;

  @override
  Future<AdPolicy> load() async {
    final now = DateTime.now();
    if (_cache != null &&
        _cacheLoadedAt != null &&
        now.difference(_cacheLoadedAt!) < const Duration(minutes: 5)) {
      return _cache!;
    }

    try {
      await _remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 5),
          minimumFetchInterval: kReleaseMode
              ? const Duration(hours: 1)
              : const Duration(minutes: 5),
        ),
      );
      await _remoteConfig.setDefaults(
        AdRemoteConfigKeys.defaults(AdPolicy.defaults),
      );
      await _remoteConfig.fetchAndActivate();
    } catch (error, stackTrace) {
      AppLogger.warning(
        'Ads Remote Config fetch failed. Falling back to cached/default values.',
        error,
        stackTrace,
      );
    }

    final policy = AdPolicy(
      adsEnabled: _remoteConfig.getBool(AdRemoteConfigKeys.adsEnabled),
      policyVersion:
          _remoteConfig
              .getString(AdRemoteConfigKeys.adsPolicyVersion)
              .trim()
              .isEmpty
          ? AdPolicy.defaults.policyVersion
          : _remoteConfig.getString(AdRemoteConfigKeys.adsPolicyVersion).trim(),
      bannerEnabled: _remoteConfig.getBool(AdRemoteConfigKeys.bannerEnabled),
      bannerScreenAllowlist: parseRemoteConfigStringList(
        _remoteConfig.getString(AdRemoteConfigKeys.bannerScreenAllowlist),
        fallback: AdPolicy.defaults.bannerScreenAllowlist,
      ),
      interstitialEnabled: _remoteConfig.getBool(
        AdRemoteConfigKeys.interstitialEnabled,
      ),
      interstitialBreakpointAllowlist: parseRemoteConfigStringList(
        _remoteConfig.getString(
          AdRemoteConfigKeys.interstitialBreakpointAllowlist,
        ),
        fallback: AdPolicy.defaults.interstitialBreakpointAllowlist,
      ),
      newUserGraceSessions: _remoteConfig
          .getInt(AdRemoteConfigKeys.adsNewUserGraceSessions)
          .clamp(0, 20),
      newUserGraceDays: _remoteConfig
          .getInt(AdRemoteConfigKeys.adsNewUserGraceDays)
          .clamp(0, 30),
      interstitialMinSessionAgeSec: _remoteConfig
          .getInt(AdRemoteConfigKeys.interstitialMinSessionAgeSec)
          .clamp(0, 3600),
      interstitialMinActions: _remoteConfig
          .getInt(AdRemoteConfigKeys.interstitialMinActions)
          .clamp(0, 50),
      interstitialMinIntervalSec: _remoteConfig
          .getInt(AdRemoteConfigKeys.interstitialMinIntervalSec)
          .clamp(0, 3600),
      interstitialMinScreenTransitions: _remoteConfig
          .getInt(AdRemoteConfigKeys.interstitialMinScreenTransitions)
          .clamp(0, 20),
      interstitialMaxPerSession: _remoteConfig
          .getInt(AdRemoteConfigKeys.interstitialMaxPerSession)
          .clamp(0, 10),
      interstitialMaxPerDay: _remoteConfig
          .getInt(AdRemoteConfigKeys.interstitialMaxPerDay)
          .clamp(0, 20),
      interstitialFailBackoffSec: _remoteConfig
          .getInt(AdRemoteConfigKeys.interstitialFailBackoffSec)
          .clamp(0, 7200),
      importantActionSuppressSec: _remoteConfig
          .getInt(AdRemoteConfigKeys.importantActionSuppressSec)
          .clamp(0, 600),
      postCrashSuppressSessions: _remoteConfig
          .getInt(AdRemoteConfigKeys.postCrashSuppressSessions)
          .clamp(0, 5),
      rewardedEnabled: _remoteConfig.getBool(
        AdRemoteConfigKeys.rewardedEnabled,
      ),
      rewardedDiscoveryEnabled: _remoteConfig.getBool(
        AdRemoteConfigKeys.rewardedDiscoveryEnabled,
      ),
      rewardedDiscoveryFreeSearchesPerSession: _remoteConfig
          .getInt(AdRemoteConfigKeys.rewardedDiscoveryFreeSearchesPerSession)
          .clamp(0, 20),
      rewardedDiscoveryMaxUnlocksPerSession: _remoteConfig
          .getInt(AdRemoteConfigKeys.rewardedDiscoveryMaxUnlocksPerSession)
          .clamp(0, 10),
      rewardedDiscoveryExtraSearchesPerReward: _remoteConfig
          .getInt(AdRemoteConfigKeys.rewardedDiscoveryExtraSearchesPerReward)
          .clamp(1, 10),
      appOpenEnabled: _remoteConfig.getBool(AdRemoteConfigKeys.appOpenEnabled),
      premiumCandidateLowAdPressure: _remoteConfig.getBool(
        AdRemoteConfigKeys.premiumCandidateLowAdPressure,
      ),
      premiumCandidateCooldownMultiplier: _remoteConfig
          .getDouble(AdRemoteConfigKeys.premiumCandidateCooldownMultiplier)
          .clamp(1, 10),
      churnRiskCooldownMultiplier: _remoteConfig
          .getDouble(AdRemoteConfigKeys.churnRiskCooldownMultiplier)
          .clamp(1, 10),
      lowEngagementDailyCap: _remoteConfig
          .getInt(AdRemoteConfigKeys.lowEngagementDailyCap)
          .clamp(0, 10),
      appOpenMinOpensBeforeEligible: _remoteConfig
          .getInt(AdRemoteConfigKeys.appOpenMinOpensBeforeEligible)
          .clamp(0, 50),
      appOpenMinForegroundGapSec: _remoteConfig
          .getInt(AdRemoteConfigKeys.appOpenMinForegroundGapSec)
          .clamp(0, 86400),
      sessionExitAfterAdWindowSec: _remoteConfig
          .getInt(AdRemoteConfigKeys.sessionExitAfterAdWindowSec)
          .clamp(0, 300),
    );
    _cache = policy;
    _cacheLoadedAt = now;
    return policy;
  }
}

AdRemoteConfigProvider createDefaultAdRemoteConfigProvider() {
  return FirebaseAdRemoteConfigProvider();
}
