import 'dart:async';

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

import '../../../core/services/app_logger.dart';
import 'ad_policy.dart';

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
      await _remoteConfig.setDefaults(<String, Object>{
        'ads_enabled': AdPolicy.defaults.adsEnabled,
        'ads_policy_version': AdPolicy.defaults.policyVersion,
        'banner_enabled': AdPolicy.defaults.bannerEnabled,
        'banner_screen_allowlist': AdPolicy.defaults.bannerScreenAllowlist.join(
          ',',
        ),
        'interstitial_enabled': AdPolicy.defaults.interstitialEnabled,
        'interstitial_breakpoint_allowlist': AdPolicy
            .defaults
            .interstitialBreakpointAllowlist
            .join(','),
        'ads_new_user_grace_sessions': AdPolicy.defaults.newUserGraceSessions,
        'ads_new_user_grace_days': AdPolicy.defaults.newUserGraceDays,
        'interstitial_min_session_age_sec':
            AdPolicy.defaults.interstitialMinSessionAgeSec,
        'interstitial_min_actions': AdPolicy.defaults.interstitialMinActions,
        'interstitial_min_interval_sec':
            AdPolicy.defaults.interstitialMinIntervalSec,
        'interstitial_min_screen_transitions':
            AdPolicy.defaults.interstitialMinScreenTransitions,
        'interstitial_max_per_session':
            AdPolicy.defaults.interstitialMaxPerSession,
        'interstitial_max_per_day': AdPolicy.defaults.interstitialMaxPerDay,
        'interstitial_fail_backoff_sec':
            AdPolicy.defaults.interstitialFailBackoffSec,
        'important_action_suppress_sec':
            AdPolicy.defaults.importantActionSuppressSec,
        'post_crash_suppress_sessions':
            AdPolicy.defaults.postCrashSuppressSessions,
        'rewarded_enabled': AdPolicy.defaults.rewardedEnabled,
        'app_open_enabled': AdPolicy.defaults.appOpenEnabled,
        'premium_candidate_low_ad_pressure':
            AdPolicy.defaults.premiumCandidateLowAdPressure,
        'premium_candidate_cooldown_multiplier':
            AdPolicy.defaults.premiumCandidateCooldownMultiplier,
        'churn_risk_cooldown_multiplier':
            AdPolicy.defaults.churnRiskCooldownMultiplier,
        'low_engagement_daily_cap': AdPolicy.defaults.lowEngagementDailyCap,
        'app_open_min_opens_before_eligible':
            AdPolicy.defaults.appOpenMinOpensBeforeEligible,
        'app_open_min_foreground_gap_sec':
            AdPolicy.defaults.appOpenMinForegroundGapSec,
        'session_exit_after_ad_window_sec':
            AdPolicy.defaults.sessionExitAfterAdWindowSec,
      });
      await _remoteConfig.fetchAndActivate();
    } catch (error, stackTrace) {
      AppLogger.warning(
        'Ads Remote Config fetch failed. Falling back to cached/default values.',
        error,
        stackTrace,
      );
    }

    final policy = AdPolicy(
      adsEnabled: _remoteConfig.getBool('ads_enabled'),
      policyVersion:
          _remoteConfig.getString('ads_policy_version').trim().isEmpty
          ? AdPolicy.defaults.policyVersion
          : _remoteConfig.getString('ads_policy_version').trim(),
      bannerEnabled: _remoteConfig.getBool('banner_enabled'),
      bannerScreenAllowlist: parseRemoteConfigStringList(
        _remoteConfig.getString('banner_screen_allowlist'),
        fallback: AdPolicy.defaults.bannerScreenAllowlist,
      ),
      interstitialEnabled: _remoteConfig.getBool('interstitial_enabled'),
      interstitialBreakpointAllowlist: parseRemoteConfigStringList(
        _remoteConfig.getString('interstitial_breakpoint_allowlist'),
        fallback: AdPolicy.defaults.interstitialBreakpointAllowlist,
      ),
      newUserGraceSessions: _remoteConfig
          .getInt('ads_new_user_grace_sessions')
          .clamp(0, 20),
      newUserGraceDays: _remoteConfig
          .getInt('ads_new_user_grace_days')
          .clamp(0, 30),
      interstitialMinSessionAgeSec: _remoteConfig
          .getInt('interstitial_min_session_age_sec')
          .clamp(0, 3600),
      interstitialMinActions: _remoteConfig
          .getInt('interstitial_min_actions')
          .clamp(0, 50),
      interstitialMinIntervalSec: _remoteConfig
          .getInt('interstitial_min_interval_sec')
          .clamp(0, 3600),
      interstitialMinScreenTransitions: _remoteConfig
          .getInt('interstitial_min_screen_transitions')
          .clamp(0, 20),
      interstitialMaxPerSession: _remoteConfig
          .getInt('interstitial_max_per_session')
          .clamp(0, 10),
      interstitialMaxPerDay: _remoteConfig
          .getInt('interstitial_max_per_day')
          .clamp(0, 20),
      interstitialFailBackoffSec: _remoteConfig
          .getInt('interstitial_fail_backoff_sec')
          .clamp(0, 7200),
      importantActionSuppressSec: _remoteConfig
          .getInt('important_action_suppress_sec')
          .clamp(0, 600),
      postCrashSuppressSessions: _remoteConfig
          .getInt('post_crash_suppress_sessions')
          .clamp(0, 5),
      rewardedEnabled: _remoteConfig.getBool('rewarded_enabled'),
      appOpenEnabled: _remoteConfig.getBool('app_open_enabled'),
      premiumCandidateLowAdPressure: _remoteConfig.getBool(
        'premium_candidate_low_ad_pressure',
      ),
      premiumCandidateCooldownMultiplier: _remoteConfig
          .getDouble('premium_candidate_cooldown_multiplier')
          .clamp(1, 10),
      churnRiskCooldownMultiplier: _remoteConfig
          .getDouble('churn_risk_cooldown_multiplier')
          .clamp(1, 10),
      lowEngagementDailyCap: _remoteConfig
          .getInt('low_engagement_daily_cap')
          .clamp(0, 10),
      appOpenMinOpensBeforeEligible: _remoteConfig
          .getInt('app_open_min_opens_before_eligible')
          .clamp(0, 50),
      appOpenMinForegroundGapSec: _remoteConfig
          .getInt('app_open_min_foreground_gap_sec')
          .clamp(0, 86400),
      sessionExitAfterAdWindowSec: _remoteConfig
          .getInt('session_exit_after_ad_window_sec')
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
