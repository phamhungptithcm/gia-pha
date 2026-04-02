import 'package:firebase_analytics/firebase_analytics.dart';

import '../../../core/services/analytics_event_names.dart';
import '../../../core/services/app_logger.dart';
import '../models/onboarding_models.dart';

abstract class OnboardingAnalyticsService {
  Future<void> logStarted({
    required OnboardingFlow flow,
    required OnboardingStep step,
    required int stepIndex,
    required String routeId,
  });

  Future<void> logStepViewed({
    required OnboardingFlow flow,
    required OnboardingStep step,
    required int stepIndex,
    required String routeId,
  });

  Future<void> logCompleted({
    required OnboardingFlow flow,
    required String routeId,
  });

  Future<void> logSkipped({
    required OnboardingFlow flow,
    required OnboardingStep step,
    required int stepIndex,
    required String routeId,
  });

  Future<void> logInterrupted({
    required OnboardingFlow flow,
    required OnboardingStep step,
    required int stepIndex,
    required String routeId,
  });

  Future<void> logAnchorMissing({
    required OnboardingFlow flow,
    required OnboardingStep step,
    required int stepIndex,
    required String routeId,
  });
}

class NoopOnboardingAnalyticsService implements OnboardingAnalyticsService {
  const NoopOnboardingAnalyticsService();

  @override
  Future<void> logAnchorMissing({
    required OnboardingFlow flow,
    required OnboardingStep step,
    required int stepIndex,
    required String routeId,
  }) async {}

  @override
  Future<void> logCompleted({
    required OnboardingFlow flow,
    required String routeId,
  }) async {}

  @override
  Future<void> logInterrupted({
    required OnboardingFlow flow,
    required OnboardingStep step,
    required int stepIndex,
    required String routeId,
  }) async {}

  @override
  Future<void> logSkipped({
    required OnboardingFlow flow,
    required OnboardingStep step,
    required int stepIndex,
    required String routeId,
  }) async {}

  @override
  Future<void> logStarted({
    required OnboardingFlow flow,
    required OnboardingStep step,
    required int stepIndex,
    required String routeId,
  }) async {}

  @override
  Future<void> logStepViewed({
    required OnboardingFlow flow,
    required OnboardingStep step,
    required int stepIndex,
    required String routeId,
  }) async {}
}

class FirebaseOnboardingAnalyticsService implements OnboardingAnalyticsService {
  const FirebaseOnboardingAnalyticsService(this._analytics);

  final FirebaseAnalytics _analytics;

  @override
  Future<void> logAnchorMissing({
    required OnboardingFlow flow,
    required OnboardingStep step,
    required int stepIndex,
    required String routeId,
  }) {
    return _logEvent(
      AnalyticsEventNames.onboardingAnchorMissing,
      <String, Object>{
        'flow_id': flow.id,
        'flow_version': flow.version,
        'step_id': step.id,
        'step_index': stepIndex,
        'route_id': routeId,
      },
    );
  }

  @override
  Future<void> logCompleted({
    required OnboardingFlow flow,
    required String routeId,
  }) {
    return _logEvent(AnalyticsEventNames.onboardingCompleted, <String, Object>{
      'flow_id': flow.id,
      'flow_version': flow.version,
      'route_id': routeId,
    });
  }

  @override
  Future<void> logInterrupted({
    required OnboardingFlow flow,
    required OnboardingStep step,
    required int stepIndex,
    required String routeId,
  }) {
    return _logEvent(
      AnalyticsEventNames.onboardingInterrupted,
      <String, Object>{
        'flow_id': flow.id,
        'flow_version': flow.version,
        'step_id': step.id,
        'step_index': stepIndex,
        'route_id': routeId,
      },
    );
  }

  @override
  Future<void> logSkipped({
    required OnboardingFlow flow,
    required OnboardingStep step,
    required int stepIndex,
    required String routeId,
  }) {
    return _logEvent(AnalyticsEventNames.onboardingSkipped, <String, Object>{
      'flow_id': flow.id,
      'flow_version': flow.version,
      'step_id': step.id,
      'step_index': stepIndex,
      'route_id': routeId,
    });
  }

  @override
  Future<void> logStarted({
    required OnboardingFlow flow,
    required OnboardingStep step,
    required int stepIndex,
    required String routeId,
  }) {
    return _logEvent(AnalyticsEventNames.onboardingStarted, <String, Object>{
      'flow_id': flow.id,
      'flow_version': flow.version,
      'step_id': step.id,
      'step_index': stepIndex,
      'route_id': routeId,
    });
  }

  @override
  Future<void> logStepViewed({
    required OnboardingFlow flow,
    required OnboardingStep step,
    required int stepIndex,
    required String routeId,
  }) {
    return _logEvent(AnalyticsEventNames.onboardingStepViewed, <String, Object>{
      'flow_id': flow.id,
      'flow_version': flow.version,
      'step_id': step.id,
      'step_index': stepIndex,
      'route_id': routeId,
    });
  }

  Future<void> _logEvent(String name, Map<String, Object> parameters) async {
    try {
      await _analytics.logEvent(name: name, parameters: parameters);
    } catch (error, stackTrace) {
      AppLogger.warning(
        'Onboarding analytics event failed for $name.',
        error,
        stackTrace,
      );
    }
  }
}

OnboardingAnalyticsService createDefaultOnboardingAnalyticsService() {
  return FirebaseOnboardingAnalyticsService(FirebaseAnalytics.instance);
}
