import 'package:befam/features/ai/services/ai_assist_service.dart';
import 'package:befam/features/auth/models/auth_session.dart';
import 'package:befam/features/events/models/event_draft.dart';
import 'package:befam/features/profile/models/profile_draft.dart';

class FakeAiAssistService implements AiAssistService {
  FakeAiAssistService({
    this.onAskAppAssistant,
    this.onReviewProfileDraft,
    this.onDraftEventCopy,
    this.onExplainDuplicateGenealogy,
  });

  final Future<AppAssistantReply> Function({
    required AuthSession session,
    required String locale,
    required String currentScreenId,
    required String currentScreenTitle,
    required String question,
    required List<AppAssistantConversationMessage> history,
    String? activeClanName,
  })?
  onAskAppAssistant;

  final Future<ProfileAiReview> Function({
    required AuthSession session,
    required String locale,
    required ProfileDraft draft,
  })?
  onReviewProfileDraft;

  final Future<EventAiSuggestion> Function({
    required AuthSession session,
    required String locale,
    required EventDraft draft,
  })?
  onDraftEventCopy;

  final Future<DuplicateGenealogyExplanation> Function({
    required AuthSession session,
    required String locale,
    required String genealogyName,
    required String founderName,
    required String countryCode,
    required String description,
    required List<Map<String, dynamic>> candidates,
  })?
  onExplainDuplicateGenealogy;

  @override
  Future<AppAssistantReply> askAppAssistant({
    required AuthSession session,
    required String locale,
    required String currentScreenId,
    required String currentScreenTitle,
    required String question,
    required List<AppAssistantConversationMessage> history,
    String? activeClanName,
  }) {
    final handler = onAskAppAssistant;
    if (handler == null) {
      throw UnimplementedError('askAppAssistant was not stubbed');
    }
    return handler(
      session: session,
      locale: locale,
      currentScreenId: currentScreenId,
      currentScreenTitle: currentScreenTitle,
      question: question,
      history: history,
      activeClanName: activeClanName,
    );
  }

  @override
  Future<EventAiSuggestion> draftEventCopy({
    required AuthSession session,
    required String locale,
    required EventDraft draft,
  }) {
    final handler = onDraftEventCopy;
    if (handler == null) {
      throw UnimplementedError('draftEventCopy was not stubbed');
    }
    return handler(session: session, locale: locale, draft: draft);
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
  }) {
    final handler = onExplainDuplicateGenealogy;
    if (handler == null) {
      throw UnimplementedError('explainDuplicateGenealogy was not stubbed');
    }
    return handler(
      session: session,
      locale: locale,
      genealogyName: genealogyName,
      founderName: founderName,
      countryCode: countryCode,
      description: description,
      candidates: candidates,
    );
  }

  @override
  Future<ProfileAiReview> reviewProfileDraft({
    required AuthSession session,
    required String locale,
    required ProfileDraft draft,
  }) {
    final handler = onReviewProfileDraft;
    if (handler == null) {
      throw UnimplementedError('reviewProfileDraft was not stubbed');
    }
    return handler(session: session, locale: locale, draft: draft);
  }
}
