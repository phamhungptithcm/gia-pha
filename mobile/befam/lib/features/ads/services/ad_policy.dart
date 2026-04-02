import 'dart:convert';

class AdPolicy {
  const AdPolicy({
    required this.adsEnabled,
    required this.policyVersion,
    required this.bannerEnabled,
    required this.bannerScreenAllowlist,
    required this.interstitialEnabled,
    required this.interstitialBreakpointAllowlist,
    required this.newUserGraceSessions,
    required this.newUserGraceDays,
    required this.interstitialMinSessionAgeSec,
    required this.interstitialMinActions,
    required this.interstitialMinIntervalSec,
    required this.interstitialMinScreenTransitions,
    required this.interstitialMaxPerSession,
    required this.interstitialMaxPerDay,
    required this.interstitialFailBackoffSec,
    required this.importantActionSuppressSec,
    required this.postCrashSuppressSessions,
    required this.rewardedEnabled,
    required this.appOpenEnabled,
    required this.premiumCandidateLowAdPressure,
    required this.premiumCandidateCooldownMultiplier,
    required this.churnRiskCooldownMultiplier,
    required this.lowEngagementDailyCap,
    required this.appOpenMinOpensBeforeEligible,
    required this.appOpenMinForegroundGapSec,
    required this.sessionExitAfterAdWindowSec,
  });

  static const defaults = AdPolicy(
    adsEnabled: true,
    policyVersion: 'v1',
    bannerEnabled: true,
    bannerScreenAllowlist: <String>['home', 'tree', 'events'],
    interstitialEnabled: true,
    interstitialBreakpointAllowlist: <String>[
      'shell_tab_switch',
      'route_return',
      'task_complete',
      'result_exit',
      'content_unit_end',
    ],
    newUserGraceSessions: 2,
    newUserGraceDays: 1,
    interstitialMinSessionAgeSec: 75,
    interstitialMinActions: 3,
    interstitialMinIntervalSec: 120,
    interstitialMinScreenTransitions: 2,
    interstitialMaxPerSession: 1,
    interstitialMaxPerDay: 3,
    interstitialFailBackoffSec: 300,
    importantActionSuppressSec: 45,
    postCrashSuppressSessions: 1,
    rewardedEnabled: false,
    appOpenEnabled: false,
    premiumCandidateLowAdPressure: true,
    premiumCandidateCooldownMultiplier: 2,
    churnRiskCooldownMultiplier: 2,
    lowEngagementDailyCap: 1,
    appOpenMinOpensBeforeEligible: 5,
    appOpenMinForegroundGapSec: 14400,
    sessionExitAfterAdWindowSec: 20,
  );

  final bool adsEnabled;
  final String policyVersion;
  final bool bannerEnabled;
  final List<String> bannerScreenAllowlist;
  final bool interstitialEnabled;
  final List<String> interstitialBreakpointAllowlist;
  final int newUserGraceSessions;
  final int newUserGraceDays;
  final int interstitialMinSessionAgeSec;
  final int interstitialMinActions;
  final int interstitialMinIntervalSec;
  final int interstitialMinScreenTransitions;
  final int interstitialMaxPerSession;
  final int interstitialMaxPerDay;
  final int interstitialFailBackoffSec;
  final int importantActionSuppressSec;
  final int postCrashSuppressSessions;
  final bool rewardedEnabled;
  final bool appOpenEnabled;
  final bool premiumCandidateLowAdPressure;
  final double premiumCandidateCooldownMultiplier;
  final double churnRiskCooldownMultiplier;
  final int lowEngagementDailyCap;
  final int appOpenMinOpensBeforeEligible;
  final int appOpenMinForegroundGapSec;
  final int sessionExitAfterAdWindowSec;

  AdPolicy copyWith({
    bool? adsEnabled,
    String? policyVersion,
    bool? bannerEnabled,
    List<String>? bannerScreenAllowlist,
    bool? interstitialEnabled,
    List<String>? interstitialBreakpointAllowlist,
    int? newUserGraceSessions,
    int? newUserGraceDays,
    int? interstitialMinSessionAgeSec,
    int? interstitialMinActions,
    int? interstitialMinIntervalSec,
    int? interstitialMinScreenTransitions,
    int? interstitialMaxPerSession,
    int? interstitialMaxPerDay,
    int? interstitialFailBackoffSec,
    int? importantActionSuppressSec,
    int? postCrashSuppressSessions,
    bool? rewardedEnabled,
    bool? appOpenEnabled,
    bool? premiumCandidateLowAdPressure,
    double? premiumCandidateCooldownMultiplier,
    double? churnRiskCooldownMultiplier,
    int? lowEngagementDailyCap,
    int? appOpenMinOpensBeforeEligible,
    int? appOpenMinForegroundGapSec,
    int? sessionExitAfterAdWindowSec,
  }) {
    return AdPolicy(
      adsEnabled: adsEnabled ?? this.adsEnabled,
      policyVersion: policyVersion ?? this.policyVersion,
      bannerEnabled: bannerEnabled ?? this.bannerEnabled,
      bannerScreenAllowlist:
          bannerScreenAllowlist ?? this.bannerScreenAllowlist,
      interstitialEnabled: interstitialEnabled ?? this.interstitialEnabled,
      interstitialBreakpointAllowlist:
          interstitialBreakpointAllowlist ??
          this.interstitialBreakpointAllowlist,
      newUserGraceSessions: newUserGraceSessions ?? this.newUserGraceSessions,
      newUserGraceDays: newUserGraceDays ?? this.newUserGraceDays,
      interstitialMinSessionAgeSec:
          interstitialMinSessionAgeSec ?? this.interstitialMinSessionAgeSec,
      interstitialMinActions:
          interstitialMinActions ?? this.interstitialMinActions,
      interstitialMinIntervalSec:
          interstitialMinIntervalSec ?? this.interstitialMinIntervalSec,
      interstitialMinScreenTransitions:
          interstitialMinScreenTransitions ??
          this.interstitialMinScreenTransitions,
      interstitialMaxPerSession:
          interstitialMaxPerSession ?? this.interstitialMaxPerSession,
      interstitialMaxPerDay:
          interstitialMaxPerDay ?? this.interstitialMaxPerDay,
      interstitialFailBackoffSec:
          interstitialFailBackoffSec ?? this.interstitialFailBackoffSec,
      importantActionSuppressSec:
          importantActionSuppressSec ?? this.importantActionSuppressSec,
      postCrashSuppressSessions:
          postCrashSuppressSessions ?? this.postCrashSuppressSessions,
      rewardedEnabled: rewardedEnabled ?? this.rewardedEnabled,
      appOpenEnabled: appOpenEnabled ?? this.appOpenEnabled,
      premiumCandidateLowAdPressure:
          premiumCandidateLowAdPressure ?? this.premiumCandidateLowAdPressure,
      premiumCandidateCooldownMultiplier:
          premiumCandidateCooldownMultiplier ??
          this.premiumCandidateCooldownMultiplier,
      churnRiskCooldownMultiplier:
          churnRiskCooldownMultiplier ?? this.churnRiskCooldownMultiplier,
      lowEngagementDailyCap:
          lowEngagementDailyCap ?? this.lowEngagementDailyCap,
      appOpenMinOpensBeforeEligible:
          appOpenMinOpensBeforeEligible ?? this.appOpenMinOpensBeforeEligible,
      appOpenMinForegroundGapSec:
          appOpenMinForegroundGapSec ?? this.appOpenMinForegroundGapSec,
      sessionExitAfterAdWindowSec:
          sessionExitAfterAdWindowSec ?? this.sessionExitAfterAdWindowSec,
    );
  }

  bool isBannerAllowedOnScreen(String screenId) {
    final normalized = screenId.trim().toLowerCase();
    return normalized.isNotEmpty &&
        bannerScreenAllowlist.contains(normalized) &&
        bannerEnabled;
  }

  bool isInterstitialAllowedAtBreakpoint(String breakpointType) {
    final normalized = breakpointType.trim().toLowerCase();
    return normalized.isNotEmpty &&
        interstitialBreakpointAllowlist.contains(normalized) &&
        interstitialEnabled;
  }
}

List<String> parseRemoteConfigStringList(
  String raw, {
  required List<String> fallback,
}) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    return fallback;
  }

  try {
    final decoded = jsonDecode(trimmed);
    if (decoded is List) {
      final values = decoded
          .whereType<String>()
          .map((entry) => entry.trim().toLowerCase())
          .where((entry) => entry.isNotEmpty)
          .toSet()
          .toList(growable: false);
      if (values.isNotEmpty) {
        return values;
      }
    }
  } catch (_) {
    // Fall through to the CSV parser below.
  }

  final values = trimmed
      .split(',')
      .map((entry) => entry.trim().toLowerCase())
      .where((entry) => entry.isNotEmpty)
      .toSet()
      .toList(growable: false);
  if (values.isEmpty) {
    return fallback;
  }
  return values;
}
