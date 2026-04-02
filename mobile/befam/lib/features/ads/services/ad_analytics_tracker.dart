import 'package:firebase_analytics/firebase_analytics.dart';

import '../../../core/services/analytics_event_names.dart';
import '../../../core/services/app_logger.dart';
import 'ad_runtime_models.dart';

abstract class AdAnalyticsTracker {
  Future<void> syncUserState(
    AdUserState userState, {
    required String policyVersion,
  });

  Future<void> trackOpportunity({
    required AdOpportunityContext context,
    required AdUserState userState,
    required bool eligible,
    required String blockReason,
    required String policyVersion,
    int? score,
    bool? shown,
  });

  Future<void> trackRequest({
    required String format,
    required String placement,
    required AdUserState userState,
  });

  Future<void> trackLoaded({
    required String format,
    required String placement,
    required AdUserState userState,
  });

  Future<void> trackFailed({
    required String format,
    required String placement,
    required AdUserState userState,
    required String errorCode,
  });

  Future<void> trackShown({
    required String format,
    required String placement,
    required String screenId,
    required AdUserState userState,
    required int sessionAgeSec,
  });

  Future<void> trackDismissed({
    required String format,
    required String placement,
    required AdUserState userState,
    required int dismissDelaySec,
  });

  Future<void> trackScreenAfterAd({
    required String previousAdFormat,
    required String previousPlacement,
    required String nextScreenId,
    required AdUserState userState,
    required int secondsFromDismiss,
  });

  Future<void> trackSessionExitAfterAd({
    required String format,
    required String placement,
    required AdUserState userState,
    required int secondsFromDismiss,
  });

  Future<void> trackPremiumIntent({
    required String source,
    required AdUserState userState,
  });

  Future<void> trackPremiumPurchaseAfterAdExposure({
    required String planCode,
    required String productId,
    required bool hadAdExposure24h,
    required String? lastAdFormat,
    required String? lastAdPlacement,
    int? secondsSinceLastAd,
  });
}

class FirebaseAdAnalyticsTracker implements AdAnalyticsTracker {
  const FirebaseAdAnalyticsTracker(this._analytics);

  final FirebaseAnalytics _analytics;

  @override
  Future<void> syncUserState(
    AdUserState userState, {
    required String policyVersion,
  }) async {
    await _setUserProperty(
      AnalyticsUserPropertyNames.adSegment,
      userState.segmentName,
    );
    await _setUserProperty(
      AnalyticsUserPropertyNames.subscriptionTier,
      userState.subscriptionTier,
    );
    await _setUserProperty(
      AnalyticsUserPropertyNames.adsPolicyVersion,
      policyVersion,
    );
  }

  @override
  Future<void> trackDismissed({
    required String format,
    required String placement,
    required AdUserState userState,
    required int dismissDelaySec,
  }) {
    return _logEvent(AnalyticsEventNames.adDismissed, <String, Object>{
      'format': format,
      'placement': placement,
      'segment': userState.segmentName,
      'dismiss_delay_sec': dismissDelaySec,
    });
  }

  @override
  Future<void> trackFailed({
    required String format,
    required String placement,
    required AdUserState userState,
    required String errorCode,
  }) {
    return _logEvent(AnalyticsEventNames.adFailed, <String, Object>{
      'format': format,
      'placement': placement,
      'segment': userState.segmentName,
      'error_code': errorCode,
    });
  }

  @override
  Future<void> trackLoaded({
    required String format,
    required String placement,
    required AdUserState userState,
  }) {
    return _logEvent(AnalyticsEventNames.adLoaded, <String, Object>{
      'format': format,
      'placement': placement,
      'segment': userState.segmentName,
    });
  }

  @override
  Future<void> trackOpportunity({
    required AdOpportunityContext context,
    required AdUserState userState,
    required bool eligible,
    required String blockReason,
    required String policyVersion,
    int? score,
    bool? shown,
  }) {
    return _logEvent(AnalyticsEventNames.adOpportunity, <String, Object>{
      'format': 'interstitial',
      'placement': context.placementId,
      'screen': context.screenId,
      'breakpoint_type': context.breakpointType,
      'source': context.source,
      'segment': userState.segmentName,
      'eligible': eligible ? 1 : 0,
      'block_reason': blockReason,
      'policy_version': policyVersion,
      ...?score == null ? null : <String, Object>{'score': score},
      ...?shown == null ? null : <String, Object>{'shown': shown ? 1 : 0},
    });
  }

  @override
  Future<void> trackPremiumIntent({
    required String source,
    required AdUserState userState,
  }) {
    return _logEvent(AnalyticsEventNames.premiumIntentMarked, <String, Object>{
      'source': source,
      'segment': userState.segmentName,
    });
  }

  @override
  Future<void> trackPremiumPurchaseAfterAdExposure({
    required String planCode,
    required String productId,
    required bool hadAdExposure24h,
    required String? lastAdFormat,
    required String? lastAdPlacement,
    int? secondsSinceLastAd,
  }) {
    return _logEvent(
      AnalyticsEventNames.premiumPurchaseAfterAdExposure,
      <String, Object>{
        'plan_code': planCode,
        'product_id': productId,
        'had_ad_exposure_24h': hadAdExposure24h ? 1 : 0,
        ...?lastAdFormat == null
            ? null
            : <String, Object>{'last_ad_format': lastAdFormat},
        ...?lastAdPlacement == null
            ? null
            : <String, Object>{'last_ad_placement': lastAdPlacement},
        ...?secondsSinceLastAd == null
            ? null
            : <String, Object>{'seconds_since_last_ad': secondsSinceLastAd},
      },
    );
  }

  @override
  Future<void> trackRequest({
    required String format,
    required String placement,
    required AdUserState userState,
  }) {
    return _logEvent(AnalyticsEventNames.adRequested, <String, Object>{
      'format': format,
      'placement': placement,
      'segment': userState.segmentName,
    });
  }

  @override
  Future<void> trackScreenAfterAd({
    required String previousAdFormat,
    required String previousPlacement,
    required String nextScreenId,
    required AdUserState userState,
    required int secondsFromDismiss,
  }) {
    return _logEvent(AnalyticsEventNames.screenAfterAd, <String, Object>{
      'previous_ad_format': previousAdFormat,
      'previous_placement': previousPlacement,
      'next_screen': nextScreenId,
      'segment': userState.segmentName,
      'seconds_from_dismiss': secondsFromDismiss,
    });
  }

  @override
  Future<void> trackSessionExitAfterAd({
    required String format,
    required String placement,
    required AdUserState userState,
    required int secondsFromDismiss,
  }) {
    return _logEvent(AnalyticsEventNames.sessionExitAfterAd, <String, Object>{
      'format': format,
      'placement': placement,
      'segment': userState.segmentName,
      'seconds_from_dismiss': secondsFromDismiss,
    });
  }

  @override
  Future<void> trackShown({
    required String format,
    required String placement,
    required String screenId,
    required AdUserState userState,
    required int sessionAgeSec,
  }) {
    return _logEvent(AnalyticsEventNames.adShown, <String, Object>{
      'format': format,
      'placement': placement,
      'screen': screenId,
      'segment': userState.segmentName,
      'session_age_sec': sessionAgeSec,
    });
  }

  Future<void> _setUserProperty(String name, String value) async {
    try {
      await _analytics.setUserProperty(name: name, value: value);
    } catch (error, stackTrace) {
      AppLogger.warning(
        'Ads analytics user property failed for $name.',
        error,
        stackTrace,
      );
    }
  }

  Future<void> _logEvent(String name, Map<String, Object?> parameters) async {
    try {
      final sanitized = <String, Object>{};
      for (final entry in parameters.entries) {
        final value = entry.value;
        if (value != null) {
          sanitized[entry.key] = value;
        }
      }
      await _analytics.logEvent(name: name, parameters: sanitized);
    } catch (error, stackTrace) {
      AppLogger.warning(
        'Ads analytics event failed for $name.',
        error,
        stackTrace,
      );
    }
  }
}

AdAnalyticsTracker createDefaultAdAnalyticsTracker() {
  return FirebaseAdAnalyticsTracker(FirebaseAnalytics.instance);
}
