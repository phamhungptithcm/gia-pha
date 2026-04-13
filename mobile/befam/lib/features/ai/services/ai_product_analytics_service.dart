import 'package:firebase_core/firebase_core.dart';

import '../../../core/services/analytics_event_names.dart';
import '../../../core/services/app_logger.dart';
import '../../../core/services/firebase_services.dart';

abstract interface class AiProductAnalyticsService {
  Future<void> trackProfileCheckRequested({
    required bool hasPhone,
    required bool hasEmail,
    required bool hasBio,
    required int socialLinkCount,
  });

  Future<void> trackProfileCheckCompleted({
    required bool usedFallback,
    required int missingCount,
    required int riskCount,
    required int nextActionCount,
    required int elapsedMs,
  });

  Future<void> trackProfileCheckFailed({
    required String reason,
    required int elapsedMs,
  });

  Future<void> trackProfileQuickFixSelected({required String target});

  Future<void> trackEventSuggestionRequested({
    required String eventType,
    required bool hasTitle,
    required bool hasDescription,
    required bool hasLocation,
    required bool hasTargetMember,
    required bool hasSchedule,
  });

  Future<void> trackEventSuggestionCompleted({
    required String eventType,
    required bool usedFallback,
    required bool hasTitleSuggestion,
    required bool hasDescriptionSuggestion,
    required int reminderSuggestionCount,
    required int elapsedMs,
  });

  Future<void> trackEventSuggestionFailed({
    required String eventType,
    required String reason,
    required int elapsedMs,
  });

  Future<void> trackEventSuggestionApplied({
    required String eventType,
    required String section,
  });

  Future<void> trackDuplicateReviewOpened({
    required int candidateCount,
    required int highestScore,
  });

  Future<void> trackDuplicateReviewDecision({
    required int candidateCount,
    required int highestScore,
    required String decision,
  });
}

class NoopAiProductAnalyticsService implements AiProductAnalyticsService {
  const NoopAiProductAnalyticsService();

  @override
  Future<void> trackDuplicateReviewDecision({
    required int candidateCount,
    required int highestScore,
    required String decision,
  }) async {}

  @override
  Future<void> trackDuplicateReviewOpened({
    required int candidateCount,
    required int highestScore,
  }) async {}

  @override
  Future<void> trackEventSuggestionApplied({
    required String eventType,
    required String section,
  }) async {}

  @override
  Future<void> trackEventSuggestionCompleted({
    required String eventType,
    required bool usedFallback,
    required bool hasTitleSuggestion,
    required bool hasDescriptionSuggestion,
    required int reminderSuggestionCount,
    required int elapsedMs,
  }) async {}

  @override
  Future<void> trackEventSuggestionFailed({
    required String eventType,
    required String reason,
    required int elapsedMs,
  }) async {}

  @override
  Future<void> trackEventSuggestionRequested({
    required String eventType,
    required bool hasTitle,
    required bool hasDescription,
    required bool hasLocation,
    required bool hasTargetMember,
    required bool hasSchedule,
  }) async {}

  @override
  Future<void> trackProfileCheckCompleted({
    required bool usedFallback,
    required int missingCount,
    required int riskCount,
    required int nextActionCount,
    required int elapsedMs,
  }) async {}

  @override
  Future<void> trackProfileCheckFailed({
    required String reason,
    required int elapsedMs,
  }) async {}

  @override
  Future<void> trackProfileCheckRequested({
    required bool hasPhone,
    required bool hasEmail,
    required bool hasBio,
    required int socialLinkCount,
  }) async {}

  @override
  Future<void> trackProfileQuickFixSelected({required String target}) async {}
}

class FirebaseAiProductAnalyticsService implements AiProductAnalyticsService {
  const FirebaseAiProductAnalyticsService();

  @override
  Future<void> trackDuplicateReviewDecision({
    required int candidateCount,
    required int highestScore,
    required String decision,
  }) {
    return _logEvent(
      AnalyticsEventNames.aiDuplicateReviewDecision,
      <String, Object>{
        'candidate_count': candidateCount,
        'highest_score': highestScore,
        'decision': decision,
      },
    );
  }

  @override
  Future<void> trackDuplicateReviewOpened({
    required int candidateCount,
    required int highestScore,
  }) {
    return _logEvent(
      AnalyticsEventNames.aiDuplicateReviewOpened,
      <String, Object>{
        'candidate_count': candidateCount,
        'highest_score': highestScore,
      },
    );
  }

  @override
  Future<void> trackEventSuggestionApplied({
    required String eventType,
    required String section,
  }) {
    return _logEvent(
      AnalyticsEventNames.aiEventSuggestionApplied,
      <String, Object>{'event_type': eventType, 'section': section},
    );
  }

  @override
  Future<void> trackEventSuggestionCompleted({
    required String eventType,
    required bool usedFallback,
    required bool hasTitleSuggestion,
    required bool hasDescriptionSuggestion,
    required int reminderSuggestionCount,
    required int elapsedMs,
  }) {
    return _logEvent(
      AnalyticsEventNames.aiEventSuggestionCompleted,
      <String, Object>{
        'event_type': eventType,
        'used_fallback': usedFallback ? 1 : 0,
        'has_title_suggestion': hasTitleSuggestion ? 1 : 0,
        'has_description_suggestion': hasDescriptionSuggestion ? 1 : 0,
        'reminder_suggestion_count': reminderSuggestionCount,
        'elapsed_ms': elapsedMs,
      },
    );
  }

  @override
  Future<void> trackEventSuggestionFailed({
    required String eventType,
    required String reason,
    required int elapsedMs,
  }) {
    return _logEvent(
      AnalyticsEventNames.aiEventSuggestionFailed,
      <String, Object>{
        'event_type': eventType,
        'reason': reason,
        'elapsed_ms': elapsedMs,
      },
    );
  }

  @override
  Future<void> trackEventSuggestionRequested({
    required String eventType,
    required bool hasTitle,
    required bool hasDescription,
    required bool hasLocation,
    required bool hasTargetMember,
    required bool hasSchedule,
  }) {
    return _logEvent(
      AnalyticsEventNames.aiEventSuggestionRequested,
      <String, Object>{
        'event_type': eventType,
        'has_title': hasTitle ? 1 : 0,
        'has_description': hasDescription ? 1 : 0,
        'has_location': hasLocation ? 1 : 0,
        'has_target_member': hasTargetMember ? 1 : 0,
        'has_schedule': hasSchedule ? 1 : 0,
      },
    );
  }

  @override
  Future<void> trackProfileCheckCompleted({
    required bool usedFallback,
    required int missingCount,
    required int riskCount,
    required int nextActionCount,
    required int elapsedMs,
  }) {
    return _logEvent(
      AnalyticsEventNames.aiProfileCheckCompleted,
      <String, Object>{
        'used_fallback': usedFallback ? 1 : 0,
        'missing_count': missingCount,
        'risk_count': riskCount,
        'next_action_count': nextActionCount,
        'elapsed_ms': elapsedMs,
      },
    );
  }

  @override
  Future<void> trackProfileCheckFailed({
    required String reason,
    required int elapsedMs,
  }) {
    return _logEvent(
      AnalyticsEventNames.aiProfileCheckFailed,
      <String, Object>{'reason': reason, 'elapsed_ms': elapsedMs},
    );
  }

  @override
  Future<void> trackProfileCheckRequested({
    required bool hasPhone,
    required bool hasEmail,
    required bool hasBio,
    required int socialLinkCount,
  }) {
    return _logEvent(
      AnalyticsEventNames.aiProfileCheckRequested,
      <String, Object>{
        'has_phone': hasPhone ? 1 : 0,
        'has_email': hasEmail ? 1 : 0,
        'has_bio': hasBio ? 1 : 0,
        'social_link_count': socialLinkCount,
      },
    );
  }

  @override
  Future<void> trackProfileQuickFixSelected({required String target}) {
    return _logEvent(
      AnalyticsEventNames.aiProfileQuickFixSelected,
      <String, Object>{'target': target},
    );
  }

  Future<void> _logEvent(String name, Map<String, Object> parameters) async {
    try {
      await FirebaseServices.analytics.logEvent(
        name: name,
        parameters: parameters,
      );
    } catch (error, stackTrace) {
      AppLogger.warning(
        'AI product analytics event failed for $name.',
        error,
        stackTrace,
      );
    }
  }
}

AiProductAnalyticsService createDefaultAiProductAnalyticsService() {
  if (Firebase.apps.isEmpty) {
    return const NoopAiProductAnalyticsService();
  }
  return const FirebaseAiProductAnalyticsService();
}
