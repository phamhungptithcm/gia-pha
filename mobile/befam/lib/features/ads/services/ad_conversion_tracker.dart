import 'package:firebase_analytics/firebase_analytics.dart';

import 'ad_analytics_tracker.dart';
import 'ad_persistence_store.dart';

abstract class AdConversionTracker {
  Future<void> logPremiumPurchase({
    required String planCode,
    required String productId,
  });
}

class FirebaseAdConversionTracker implements AdConversionTracker {
  FirebaseAdConversionTracker({
    AdPersistenceStore? persistenceStore,
    AdAnalyticsTracker? analyticsTracker,
    DateTime Function()? clock,
  }) : _persistenceStore = persistenceStore ?? SharedPrefsAdPersistenceStore(),
       _analyticsTracker =
           analyticsTracker ??
           FirebaseAdAnalyticsTracker(FirebaseAnalytics.instance),
       _clock = clock ?? DateTime.now;

  final AdPersistenceStore _persistenceStore;
  final AdAnalyticsTracker _analyticsTracker;
  final DateTime Function() _clock;

  @override
  Future<void> logPremiumPurchase({
    required String planCode,
    required String productId,
  }) async {
    final now = _clock();
    final state = await _persistenceStore.load(now);
    final secondsSinceLastAd = state.lastAdDismissedAt == null
        ? null
        : now.difference(state.lastAdDismissedAt!).inSeconds;
    final hadAdExposure24h =
        state.lastAdDismissedAt != null &&
        now.difference(state.lastAdDismissedAt!) <= const Duration(hours: 24);
    await _analyticsTracker.trackPremiumPurchaseAfterAdExposure(
      planCode: planCode,
      productId: productId,
      hadAdExposure24h: hadAdExposure24h,
      lastAdFormat: state.lastAdFormat,
      lastAdPlacement: state.lastAdPlacement,
      secondsSinceLastAd: secondsSinceLastAd,
    );
  }
}

AdConversionTracker createDefaultAdConversionTracker() {
  return FirebaseAdConversionTracker();
}
