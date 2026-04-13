import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';

import '../../../core/services/firebase_services.dart';
import '../../auth/models/auth_session.dart';
import '../../events/models/event_draft.dart';
import '../../profile/models/profile_draft.dart';
import 'app_assistant_context_service.dart';

abstract interface class AiAssistService {
  Future<AppAssistantReply> askAppAssistant({
    required AuthSession session,
    required String locale,
    required String currentScreenId,
    required String currentScreenTitle,
    required String question,
    required List<AppAssistantConversationMessage> history,
    required AppAssistantSearchContext searchContext,
    String? activeClanName,
  });

  Future<ProfileAiReview> reviewProfileDraft({
    required AuthSession session,
    required String locale,
    required ProfileDraft draft,
  });

  Future<EventAiSuggestion> draftEventCopy({
    required AuthSession session,
    required String locale,
    required EventDraft draft,
  });

  Future<DuplicateGenealogyExplanation> explainDuplicateGenealogy({
    required AuthSession session,
    required String locale,
    required String genealogyName,
    required String founderName,
    required String countryCode,
    required String description,
    required List<Map<String, dynamic>> candidates,
  });
}

class FirebaseAiAssistService implements AiAssistService {
  FirebaseAiAssistService({
    FirebaseFunctions? functions,
    Duration callableTimeout = _defaultCallableTimeout,
  }) : _functions = functions ?? FirebaseServices.functions,
       _callableTimeout = callableTimeout;

  final FirebaseFunctions _functions;
  final Duration _callableTimeout;

  static const Duration _defaultCallableTimeout = Duration(milliseconds: 6500);

  @override
  Future<AppAssistantReply> askAppAssistant({
    required AuthSession session,
    required String locale,
    required String currentScreenId,
    required String currentScreenTitle,
    required String question,
    required List<AppAssistantConversationMessage> history,
    required AppAssistantSearchContext searchContext,
    String? activeClanName,
  }) async {
    final callable = _callable('chatWithAppAssistantAi');
    try {
      final response = await callable.call(<String, dynamic>{
        'clanId': _requireClanId(session),
        'locale': locale,
        'currentScreenId': currentScreenId,
        'currentScreenTitle': currentScreenTitle,
        'activeClanName': activeClanName ?? '',
        'question': question.trim(),
        'history': history
            .map((entry) => entry.toMap())
            .toList(growable: false),
        'searchContext': searchContext.toMap(),
      });
      return AppAssistantReply.fromMap(_asMap(response.data));
    } on FirebaseFunctionsException catch (error) {
      throw _exceptionForFunctionsError(error);
    } on TimeoutException {
      throw const AiAssistServiceException(
        'AI assistance took too long. Please try again in a moment.',
        code: 'deadline-exceeded',
      );
    }
  }

  @override
  Future<ProfileAiReview> reviewProfileDraft({
    required AuthSession session,
    required String locale,
    required ProfileDraft draft,
  }) async {
    final callable = _callable('reviewProfileDraftAi');
    final socialLinkCount = [
      draft.facebook,
      draft.zalo,
      draft.linkedin,
    ].where((value) => value.trim().isNotEmpty).length;
    try {
      final response = await callable.call(<String, dynamic>{
        'clanId': _requireClanId(session),
        'locale': locale,
        'fullName': draft.fullName,
        'nickName': draft.nickName,
        'jobTitle': draft.jobTitle,
        'hasPhone': draft.phoneInput.trim().isNotEmpty,
        'hasEmail': draft.email.trim().isNotEmpty,
        'hasAddress': draft.addressText.trim().isNotEmpty,
        'bioWordCount': _wordCount(draft.bio),
        'socialLinkCount': socialLinkCount,
      });
      return ProfileAiReview.fromMap(_asMap(response.data));
    } on FirebaseFunctionsException catch (error) {
      throw _exceptionForFunctionsError(error);
    } on TimeoutException {
      throw const AiAssistServiceException(
        'The profile check took too long. Please try again in a moment.',
        code: 'deadline-exceeded',
      );
    }
  }

  @override
  Future<EventAiSuggestion> draftEventCopy({
    required AuthSession session,
    required String locale,
    required EventDraft draft,
  }) async {
    final callable = _callable('draftEventCopyAi');
    try {
      final response = await callable.call(<String, dynamic>{
        'clanId': _requireClanId(session),
        'locale': locale,
        'eventType': draft.eventType.wireName,
        'title': draft.title,
        'description': draft.description,
        'locationName': draft.locationName,
        'hasLocationAddress': draft.locationAddress.trim().isNotEmpty,
        'startsAtIso': draft.startsAt.toUtc().toIso8601String(),
        'timezone': draft.timezone,
        'isRecurring': draft.isRecurring,
      });
      return EventAiSuggestion.fromMap(_asMap(response.data));
    } on FirebaseFunctionsException catch (error) {
      throw _exceptionForFunctionsError(error);
    } on TimeoutException {
      throw const AiAssistServiceException(
        'Event suggestions took too long. Please try again in a moment.',
        code: 'deadline-exceeded',
      );
    }
  }

  @override
  Future<DuplicateGenealogyExplanation> explainDuplicateGenealogy({
    required AuthSession session,
    required String locale,
    required String genealogyName,
    required String founderName,
    required String countryCode,
    required String description,
    required List<Map<String, dynamic>> candidates,
  }) async {
    final callable = _callable('explainDuplicateGenealogyAi');
    try {
      final response = await callable.call(<String, dynamic>{
        'clanId': _requireClanId(session),
        'locale': locale,
        'genealogyName': genealogyName,
        'founderName': founderName,
        'countryCode': countryCode,
        'description': description,
        'candidates': candidates,
      });
      return DuplicateGenealogyExplanation.fromMap(_asMap(response.data));
    } on FirebaseFunctionsException catch (error) {
      throw _exceptionForFunctionsError(error);
    } on TimeoutException {
      throw const AiAssistServiceException(
        'Duplicate review assistance took too long. Please try again shortly.',
        code: 'deadline-exceeded',
      );
    }
  }

  HttpsCallable _callable(String name) {
    return _functions.httpsCallable(
      name,
      options: HttpsCallableOptions(timeout: _callableTimeout),
    );
  }

  String _requireClanId(AuthSession session) {
    final clanId = (session.clanId ?? '').trim();
    if (clanId.isEmpty) {
      throw const AiAssistServiceException(
        'This session is not linked to a clan.',
      );
    }
    return clanId;
  }
}

AiAssistService createDefaultAiAssistService() {
  return FirebaseAiAssistService();
}

class AiAssistServiceException implements Exception {
  const AiAssistServiceException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}

class ProfileAiReview {
  const ProfileAiReview({
    required this.summary,
    required this.strengths,
    required this.missingImportant,
    required this.risks,
    required this.nextActions,
    required this.usedFallback,
    required this.model,
  });

  final String summary;
  final List<String> strengths;
  final List<String> missingImportant;
  final List<String> risks;
  final List<String> nextActions;
  final bool usedFallback;
  final String? model;

  bool get hasAnyAdvice =>
      summary.trim().isNotEmpty ||
      strengths.isNotEmpty ||
      missingImportant.isNotEmpty ||
      risks.isNotEmpty ||
      nextActions.isNotEmpty;

  factory ProfileAiReview.fromMap(Map<String, dynamic> data) {
    return ProfileAiReview(
      summary: (data['summary'] as String? ?? '').trim(),
      strengths: _asStringList(data['strengths']),
      missingImportant: _asStringList(data['missingImportant']),
      risks: _asStringList(data['risks']),
      nextActions: _asStringList(data['nextActions']),
      usedFallback: data['usedFallback'] as bool? ?? false,
      model: (data['model'] as String?)?.trim(),
    );
  }
}

enum AppAssistantConversationRole { user, assistant }

class AppAssistantConversationMessage {
  const AppAssistantConversationMessage({
    required this.role,
    required this.text,
  });

  final AppAssistantConversationRole role;
  final String text;

  Map<String, String> toMap() {
    return <String, String>{
      'role': role == AppAssistantConversationRole.user ? 'user' : 'assistant',
      'text': text.trim(),
    };
  }
}

class AppAssistantReply {
  const AppAssistantReply({
    required this.answer,
    required this.steps,
    required this.quickReplies,
    required this.caution,
    required this.suggestedDestination,
    required this.usedFallback,
    required this.model,
  });

  final String answer;
  final List<String> steps;
  final List<String> quickReplies;
  final String caution;
  final String? suggestedDestination;
  final bool usedFallback;
  final String? model;

  bool get hasStructuredGuidance =>
      answer.trim().isNotEmpty ||
      steps.isNotEmpty ||
      quickReplies.isNotEmpty ||
      caution.trim().isNotEmpty;

  factory AppAssistantReply.fromMap(Map<String, dynamic> data) {
    final destination = (data['suggestedDestination'] as String? ?? '').trim();
    return AppAssistantReply(
      answer: (data['answer'] as String? ?? '').trim(),
      steps: _asStringList(data['steps']),
      quickReplies: _asStringList(data['quickReplies']),
      caution: (data['caution'] as String? ?? '').trim(),
      suggestedDestination: switch (destination) {
        'home' || 'tree' || 'events' || 'billing' || 'profile' => destination,
        _ => null,
      },
      usedFallback: data['usedFallback'] as bool? ?? false,
      model: (data['model'] as String?)?.trim(),
    );
  }
}

class EventAiSuggestion {
  const EventAiSuggestion({
    required this.title,
    required this.description,
    required this.recommendedReminderOffsetsMinutes,
    required this.rationale,
    required this.usedFallback,
    required this.model,
  });

  final String title;
  final String description;
  final List<int> recommendedReminderOffsetsMinutes;
  final List<String> rationale;
  final bool usedFallback;
  final String? model;

  factory EventAiSuggestion.fromMap(Map<String, dynamic> data) {
    return EventAiSuggestion(
      title: (data['title'] as String? ?? '').trim(),
      description: (data['description'] as String? ?? '').trim(),
      recommendedReminderOffsetsMinutes: _asIntList(
        data['recommendedReminderOffsetsMinutes'],
      ),
      rationale: _asStringList(data['rationale']),
      usedFallback: data['usedFallback'] as bool? ?? false,
      model: (data['model'] as String?)?.trim(),
    );
  }
}

enum DuplicateExplanationAction { reviewFirst, safeToOverride, uncertain }

class DuplicateGenealogyExplanation {
  const DuplicateGenealogyExplanation({
    required this.summary,
    required this.topSignals,
    required this.reviewChecklist,
    required this.recommendedAction,
    required this.usedFallback,
    required this.model,
  });

  final String summary;
  final List<String> topSignals;
  final List<String> reviewChecklist;
  final DuplicateExplanationAction recommendedAction;
  final bool usedFallback;
  final String? model;

  factory DuplicateGenealogyExplanation.fromMap(Map<String, dynamic> data) {
    final actionRaw = (data['recommendedAction'] as String? ?? '').trim();
    final action = switch (actionRaw) {
      'review_first' => DuplicateExplanationAction.reviewFirst,
      'safe_to_override' => DuplicateExplanationAction.safeToOverride,
      _ => DuplicateExplanationAction.uncertain,
    };
    return DuplicateGenealogyExplanation(
      summary: (data['summary'] as String? ?? '').trim(),
      topSignals: _asStringList(data['topSignals']),
      reviewChecklist: _asStringList(data['reviewChecklist']),
      recommendedAction: action,
      usedFallback: data['usedFallback'] as bool? ?? false,
      model: (data['model'] as String?)?.trim(),
    );
  }
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<Object?, Object?>) {
    return value.map((key, entry) => MapEntry('$key', entry));
  }
  return const <String, dynamic>{};
}

List<String> _asStringList(dynamic value) {
  if (value is! List) {
    return const [];
  }
  return value
      .whereType<String>()
      .map((entry) => entry.trim())
      .where((entry) => entry.isNotEmpty)
      .toList(growable: false);
}

List<int> _asIntList(dynamic value) {
  if (value is! List) {
    return const [];
  }
  return value
      .map((entry) {
        if (entry is int) {
          return entry;
        }
        if (entry is num) {
          return entry.round();
        }
        return null;
      })
      .whereType<int>()
      .where((entry) => entry > 0)
      .toList(growable: false);
}

AiAssistServiceException _exceptionForFunctionsError(
  FirebaseFunctionsException error,
) {
  final message = error.message?.trim() ?? '';
  if (message.isNotEmpty) {
    return AiAssistServiceException(message, code: error.code);
  }
  return AiAssistServiceException(switch (error.code) {
    'permission-denied' => 'You do not have permission to use this AI feature.',
    'failed-precondition' =>
      'This AI feature is not available in the current session.',
    'resource-exhausted' =>
      'This AI feature is cooling down. Please wait a few seconds and try again.',
    'deadline-exceeded' =>
      'AI assistance took too long. Please try again in a moment.',
    _ => 'AI assistance is temporarily unavailable.',
  }, code: error.code);
}

int _wordCount(String value) {
  return value
      .trim()
      .split(RegExp(r'\s+'))
      .where((token) => token.isNotEmpty)
      .length;
}
