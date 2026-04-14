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
      if (_shouldUseLocalAssistantFallback(error)) {
        return _buildLocalAssistantFallback(
          locale: locale,
          currentScreenId: currentScreenId,
          question: question,
          searchContext: searchContext,
          activeClanName: activeClanName,
        );
      }
      throw _exceptionForFunctionsError(error);
    } on TimeoutException {
      return _buildLocalAssistantFallback(
        locale: locale,
        currentScreenId: currentScreenId,
        question: question,
        searchContext: searchContext,
        activeClanName: activeClanName,
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
  final rawMessage = error.message?.trim() ?? '';
  final message = _normalizeAiFunctionsMessage(
    rawMessage: rawMessage,
    code: error.code,
  );
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

bool _shouldUseLocalAssistantFallback(FirebaseFunctionsException error) {
  final code = error.code.trim().toLowerCase();
  if (code == 'permission-denied' || code == 'resource-exhausted') {
    return false;
  }
  if (code == 'not-found' ||
      code == 'unavailable' ||
      code == 'deadline-exceeded' ||
      code == 'internal' ||
      code == 'unknown') {
    return true;
  }
  final message = (error.message ?? '').trim().toLowerCase();
  return message == 'not found' || message.contains('not found');
}

String _normalizeAiFunctionsMessage({
  required String rawMessage,
  required String code,
}) {
  final trimmed = rawMessage.trim();
  if (trimmed.isEmpty) {
    return '';
  }
  final normalized = trimmed.toLowerCase();
  if (normalized == 'not found' || code.trim().toLowerCase() == 'not-found') {
    return 'The assistant is still syncing right now. Please try again in a moment.';
  }
  return trimmed;
}

AppAssistantReply _buildLocalAssistantFallback({
  required String locale,
  required String currentScreenId,
  required String question,
  required AppAssistantSearchContext searchContext,
  String? activeClanName,
}) {
  final isVietnamese = locale.trim().toLowerCase().startsWith('vi');
  final clanLabel = (searchContext.activeClanName.trim().isNotEmpty
          ? searchContext.activeClanName
          : (activeClanName ?? ''))
      .trim();
  final matches = searchContext.memberMatches;
  final queryHint = searchContext.searchQueryHint.trim().isNotEmpty
      ? searchContext.searchQueryHint.trim()
      : question.trim();

  if (matches.isNotEmpty) {
    final firstMatch = matches.first;
    final answer = matches.length == 1
        ? (isVietnamese
              ? 'Mình thấy một hồ sơ khá khớp trong ${clanLabel.isEmpty ? 'gia phả đang mở' : clanLabel}: ${firstMatch.displayName}.'
              : 'I found one profile that looks like a good match in ${clanLabel.isEmpty ? 'the active family tree' : clanLabel}: ${firstMatch.displayName}.')
        : (isVietnamese
              ? 'Mình thấy ${matches.length} người khá khớp với câu hỏi này trong ${clanLabel.isEmpty ? 'gia phả đang mở' : clanLabel}. Mình để ngay bên dưới để bạn đối chiếu nhanh.'
              : 'I found ${matches.length} people that look close to your question in ${clanLabel.isEmpty ? 'the active family tree' : clanLabel}. I listed them below so you can compare quickly.');
    return AppAssistantReply(
      answer: answer,
      steps: <String>[
        isVietnamese
            ? 'Nếu đang tìm đúng người thân của mình, bạn nhìn thêm chi, đời, và năm sinh để chốt nhanh hơn.'
            : 'If you are looking for your exact relative, compare branch, generation, and birth year to confirm more quickly.',
      ],
      quickReplies: <String>[
        isVietnamese ? 'Mở Tree để xem kỹ hơn' : 'Open Tree',
        isVietnamese ? 'Tìm người khác' : 'Search another person',
      ],
      caution: matches.length > 1
          ? (isVietnamese
                ? 'Có vài hồ sơ gần giống nhau, nên mình chưa khẳng định tuyệt đối chỉ từ tên gọi.'
                : 'There are a few similar profiles, so I would not confirm only from the name.')
          : '',
      suggestedDestination: 'tree',
      usedFallback: true,
      model: null,
    );
  }

  if (queryHint.isNotEmpty) {
    return AppAssistantReply(
      answer: isVietnamese
          ? 'Mình chưa thấy hồ sơ nào khớp rõ với “$queryHint” trong gia phả đang mở.'
          : 'I could not find a clear profile match for “$queryHint” in the active family tree.',
      steps: <String>[
        isVietnamese
            ? 'Bạn thử nhập tên đầy đủ, tên thường gọi, hoặc hỏi rõ hơn như “anh ruột của tôi”, “chị họ của tôi”.'
            : 'Try the full name, a common nickname, or a more specific relation such as “my brother” or “my cousin”.',
        isVietnamese
            ? 'Nếu muốn chắc hơn, mở Tree để dò theo chi hoặc đời.'
            : 'If you want a safer check, open Tree and browse by branch or generation.',
      ],
      quickReplies: <String>[
        isVietnamese ? 'Mở Tree để tìm tiếp' : 'Open Tree',
        isVietnamese ? 'Tìm theo tên đầy đủ' : 'Search by full name',
      ],
      caution: '',
      suggestedDestination: 'tree',
      usedFallback: true,
      model: null,
    );
  }

  return AppAssistantReply(
    answer: isVietnamese
        ? _fallbackAssistantAnswerVi(currentScreenId)
        : _fallbackAssistantAnswerEn(currentScreenId),
    steps: <String>[
      isVietnamese
          ? 'Bạn cứ hỏi ngắn gọn như đang nhắn tin, mình sẽ gợi đúng chỗ để làm tiếp.'
          : 'Ask in a short natural way and I will point you to the right place to continue.',
    ],
    quickReplies: _defaultAssistantQuickReplies(
      currentScreenId: currentScreenId,
      isVietnamese: isVietnamese,
    ),
    caution: '',
    suggestedDestination: _defaultAssistantDestination(currentScreenId),
    usedFallback: true,
    model: null,
  );
}

String _fallbackAssistantAnswerVi(String currentScreenId) {
  switch (currentScreenId.trim().toLowerCase()) {
    case 'tree':
      return 'Mình có thể giúp bạn tìm người thân trong gia phả hoặc chỉ nhanh nên mở nhánh nào để kiểm tra tiếp.';
    case 'events':
      return 'Mình có thể giúp bạn tìm nhanh việc cần làm cho sự kiện, ngày giỗ, hoặc nhắc bạn nên điền gì trước.';
    case 'billing':
      return 'Mình có thể giải thích nhanh gói hiện tại của bạn và lúc nào nên nâng cấp.';
    case 'profile':
      return 'Mình có thể giúp bạn hoàn thiện hồ sơ và chỉ ra phần nào nên sửa trước.';
    default:
      return 'Mình có thể giúp bạn tìm người thân hoặc chỉ nhanh đúng khu vực trong BeFam để làm tiếp.';
  }
}

String _fallbackAssistantAnswerEn(String currentScreenId) {
  switch (currentScreenId.trim().toLowerCase()) {
    case 'tree':
      return 'I can help you find a relative in the tree or point to the right branch to inspect next.';
    case 'events':
      return 'I can help you move through event setup, memorial tasks, or the next detail to fill in.';
    case 'billing':
      return 'I can quickly explain your current plan and when an upgrade would make sense.';
    case 'profile':
      return 'I can help you improve the profile and point out what to fix first.';
    default:
      return 'I can help you find a relative or move to the right BeFam area to continue.';
  }
}

List<String> _defaultAssistantQuickReplies({
  required String currentScreenId,
  required bool isVietnamese,
}) {
  switch (currentScreenId.trim().toLowerCase()) {
    case 'tree':
      return <String>[
        isVietnamese ? 'Tìm anh chị em của tôi' : 'Find my siblings',
        isVietnamese ? 'Mở Tree để xem tiếp' : 'Open Tree',
      ];
    case 'events':
      return <String>[
        isVietnamese ? 'Tạo ngày giỗ' : 'Create a memorial event',
        isVietnamese ? 'Nhắc tôi nên điền gì trước' : 'What should I fill first?',
      ];
    default:
      return <String>[
        isVietnamese ? 'Tìm người thân trong gia phả' : 'Find a relative',
        isVietnamese ? 'Tôi nên bắt đầu từ đâu?' : 'Where should I start?',
      ];
  }
}

String? _defaultAssistantDestination(String currentScreenId) {
  switch (currentScreenId.trim().toLowerCase()) {
    case 'tree':
    case 'events':
    case 'billing':
    case 'profile':
    case 'home':
      return currentScreenId.trim().toLowerCase();
    default:
      return null;
  }
}

int _wordCount(String value) {
  return value
      .trim()
      .split(RegExp(r'\s+'))
      .where((token) => token.isNotEmpty)
      .length;
}
