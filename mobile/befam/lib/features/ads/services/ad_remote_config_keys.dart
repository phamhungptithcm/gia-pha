import 'ad_policy.dart';

abstract final class AdRemoteConfigKeys {
  static const adsEnabled = 'ads_enabled';
  static const adsPolicyVersion = 'ads_policy_version';
  static const bannerEnabled = 'banner_enabled';
  static const bannerScreenAllowlist = 'banner_screen_allowlist';
  static const interstitialEnabled = 'interstitial_enabled';
  static const interstitialBreakpointAllowlist =
      'interstitial_breakpoint_allowlist';
  static const adsNewUserGraceSessions = 'ads_new_user_grace_sessions';
  static const adsNewUserGraceDays = 'ads_new_user_grace_days';
  static const interstitialMinSessionAgeSec =
      'interstitial_min_session_age_sec';
  static const interstitialMinActions = 'interstitial_min_actions';
  static const interstitialMinIntervalSec = 'interstitial_min_interval_sec';
  static const interstitialMinScreenTransitions =
      'interstitial_min_screen_transitions';
  static const interstitialMaxPerSession = 'interstitial_max_per_session';
  static const interstitialMaxPerDay = 'interstitial_max_per_day';
  static const interstitialFailBackoffSec = 'interstitial_fail_backoff_sec';
  static const importantActionSuppressSec = 'important_action_suppress_sec';
  static const postCrashSuppressSessions = 'post_crash_suppress_sessions';
  static const rewardedEnabled = 'rewarded_enabled';
  static const rewardedDiscoveryEnabled = 'rewarded_discovery_enabled';
  static const rewardedDiscoveryFreeSearchesPerSession =
      'rewarded_discovery_free_searches_per_session';
  static const rewardedDiscoveryMaxUnlocksPerSession =
      'rewarded_discovery_max_unlocks_per_session';
  static const rewardedDiscoveryExtraSearchesPerReward =
      'rewarded_discovery_extra_searches_per_reward';
  static const appOpenEnabled = 'app_open_enabled';
  static const premiumCandidateLowAdPressure =
      'premium_candidate_low_ad_pressure';
  static const premiumCandidateCooldownMultiplier =
      'premium_candidate_cooldown_multiplier';
  static const churnRiskCooldownMultiplier = 'churn_risk_cooldown_multiplier';
  static const lowEngagementDailyCap = 'low_engagement_daily_cap';
  static const appOpenMinOpensBeforeEligible =
      'app_open_min_opens_before_eligible';
  static const appOpenMinForegroundGapSec = 'app_open_min_foreground_gap_sec';
  static const sessionExitAfterAdWindowSec = 'session_exit_after_ad_window_sec';

  static const values = <String>[
    adsEnabled,
    adsPolicyVersion,
    bannerEnabled,
    bannerScreenAllowlist,
    interstitialEnabled,
    interstitialBreakpointAllowlist,
    adsNewUserGraceSessions,
    adsNewUserGraceDays,
    interstitialMinSessionAgeSec,
    interstitialMinActions,
    interstitialMinIntervalSec,
    interstitialMinScreenTransitions,
    interstitialMaxPerSession,
    interstitialMaxPerDay,
    interstitialFailBackoffSec,
    importantActionSuppressSec,
    postCrashSuppressSessions,
    rewardedEnabled,
    rewardedDiscoveryEnabled,
    rewardedDiscoveryFreeSearchesPerSession,
    rewardedDiscoveryMaxUnlocksPerSession,
    rewardedDiscoveryExtraSearchesPerReward,
    appOpenEnabled,
    premiumCandidateLowAdPressure,
    premiumCandidateCooldownMultiplier,
    churnRiskCooldownMultiplier,
    lowEngagementDailyCap,
    appOpenMinOpensBeforeEligible,
    appOpenMinForegroundGapSec,
    sessionExitAfterAdWindowSec,
  ];

  static Map<String, Object> defaults(AdPolicy policy) {
    return <String, Object>{
      adsEnabled: policy.adsEnabled,
      adsPolicyVersion: policy.policyVersion,
      bannerEnabled: policy.bannerEnabled,
      bannerScreenAllowlist: policy.bannerScreenAllowlist.join(','),
      interstitialEnabled: policy.interstitialEnabled,
      interstitialBreakpointAllowlist: policy.interstitialBreakpointAllowlist
          .join(','),
      adsNewUserGraceSessions: policy.newUserGraceSessions,
      adsNewUserGraceDays: policy.newUserGraceDays,
      interstitialMinSessionAgeSec: policy.interstitialMinSessionAgeSec,
      interstitialMinActions: policy.interstitialMinActions,
      interstitialMinIntervalSec: policy.interstitialMinIntervalSec,
      interstitialMinScreenTransitions: policy.interstitialMinScreenTransitions,
      interstitialMaxPerSession: policy.interstitialMaxPerSession,
      interstitialMaxPerDay: policy.interstitialMaxPerDay,
      interstitialFailBackoffSec: policy.interstitialFailBackoffSec,
      importantActionSuppressSec: policy.importantActionSuppressSec,
      postCrashSuppressSessions: policy.postCrashSuppressSessions,
      rewardedEnabled: policy.rewardedEnabled,
      rewardedDiscoveryEnabled: policy.rewardedDiscoveryEnabled,
      rewardedDiscoveryFreeSearchesPerSession:
          policy.rewardedDiscoveryFreeSearchesPerSession,
      rewardedDiscoveryMaxUnlocksPerSession:
          policy.rewardedDiscoveryMaxUnlocksPerSession,
      rewardedDiscoveryExtraSearchesPerReward:
          policy.rewardedDiscoveryExtraSearchesPerReward,
      appOpenEnabled: policy.appOpenEnabled,
      premiumCandidateLowAdPressure: policy.premiumCandidateLowAdPressure,
      premiumCandidateCooldownMultiplier:
          policy.premiumCandidateCooldownMultiplier,
      churnRiskCooldownMultiplier: policy.churnRiskCooldownMultiplier,
      lowEngagementDailyCap: policy.lowEngagementDailyCap,
      appOpenMinOpensBeforeEligible: policy.appOpenMinOpensBeforeEligible,
      appOpenMinForegroundGapSec: policy.appOpenMinForegroundGapSec,
      sessionExitAfterAdWindowSec: policy.sessionExitAfterAdWindowSec,
    };
  }
}
