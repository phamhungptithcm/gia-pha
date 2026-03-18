import 'auth_session.dart';

class MemberVerificationOption {
  const MemberVerificationOption({required this.id, required this.label});

  final String id;
  final String label;

  factory MemberVerificationOption.fromMap(Map<String, dynamic> data) {
    String normalizeString(dynamic value, String fallback) {
      if (value is! String) {
        return fallback;
      }
      final trimmed = value.trim();
      return trimmed.isEmpty ? fallback : trimmed;
    }

    return MemberVerificationOption(
      id: normalizeString(data['id'], ''),
      label: normalizeString(data['label'], ''),
    );
  }
}

class MemberVerificationQuestion {
  const MemberVerificationQuestion({
    required this.id,
    required this.category,
    required this.prompt,
    required this.options,
  });

  final String id;
  final String category;
  final String prompt;
  final List<MemberVerificationOption> options;

  factory MemberVerificationQuestion.fromMap(Map<String, dynamic> data) {
    String normalizeString(dynamic value, String fallback) {
      if (value is! String) {
        return fallback;
      }
      final trimmed = value.trim();
      return trimmed.isEmpty ? fallback : trimmed;
    }

    final rawOptions = data['options'];
    final options = rawOptions is List
        ? rawOptions
              .whereType<Map>()
              .map((entry) => entry.map(
                    (key, value) => MapEntry(key.toString(), value),
                  ))
              .map(MemberVerificationOption.fromMap)
              .toList(growable: false)
        : const <MemberVerificationOption>[];

    return MemberVerificationQuestion(
      id: normalizeString(data['id'], ''),
      category: normalizeString(data['category'], 'personal'),
      prompt: normalizeString(data['prompt'], ''),
      options: options,
    );
  }
}

class MemberIdentityVerificationChallenge {
  const MemberIdentityVerificationChallenge({
    required this.verificationSessionId,
    required this.memberId,
    required this.maxAttempts,
    required this.remainingAttempts,
    required this.questions,
  });

  final String verificationSessionId;
  final String memberId;
  final int maxAttempts;
  final int remainingAttempts;
  final List<MemberVerificationQuestion> questions;

  factory MemberIdentityVerificationChallenge.fromMap(
    Map<String, dynamic> data,
  ) {
    String normalizeString(dynamic value, String fallback) {
      if (value is! String) {
        return fallback;
      }
      final trimmed = value.trim();
      return trimmed.isEmpty ? fallback : trimmed;
    }

    int normalizeInt(dynamic value, int fallback) {
      if (value is int) {
        return value;
      }
      if (value is num) {
        return value.toInt();
      }
      return fallback;
    }

    final rawQuestions = data['questions'];
    final questions = rawQuestions is List
        ? rawQuestions
              .whereType<Map>()
              .map((entry) => entry.map(
                    (key, value) => MapEntry(key.toString(), value),
                  ))
              .map(MemberVerificationQuestion.fromMap)
              .toList(growable: false)
        : const <MemberVerificationQuestion>[];

    return MemberIdentityVerificationChallenge(
      verificationSessionId: normalizeString(data['verificationSessionId'], ''),
      memberId: normalizeString(data['memberId'], ''),
      maxAttempts: normalizeInt(data['maxAttempts'], 3),
      remainingAttempts: normalizeInt(data['remainingAttempts'], 3),
      questions: questions,
    );
  }
}

class MemberIdentityVerificationResult {
  const MemberIdentityVerificationResult({
    required this.passed,
    required this.locked,
    required this.remainingAttempts,
    required this.score,
    required this.requiredCorrect,
    this.session,
  });

  final bool passed;
  final bool locked;
  final int remainingAttempts;
  final int score;
  final int requiredCorrect;
  final AuthSession? session;
}

