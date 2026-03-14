import '../models/event_draft.dart';
import '../models/event_type.dart';

enum EventValidationIssueCode {
  missingTitle,
  invalidTimeRange,
  invalidReminderOffsets,
  memorialRequiresTargetMember,
  memorialRequiresYearlyRecurrence,
}

class EventValidationIssue {
  const EventValidationIssue(this.code);

  final EventValidationIssueCode code;
}

class EventValidationResult {
  const EventValidationResult(this.issues);

  final List<EventValidationIssue> issues;

  bool get isValid => issues.isEmpty;
}

abstract final class EventValidation {
  static EventValidationResult validate(EventDraft draft) {
    final issues = <EventValidationIssue>[];

    if (draft.title.trim().isEmpty) {
      issues.add(
        const EventValidationIssue(EventValidationIssueCode.missingTitle),
      );
    }

    if (!hasValidTimeRange(draft.startsAt, draft.endsAt)) {
      issues.add(
        const EventValidationIssue(EventValidationIssueCode.invalidTimeRange),
      );
    }

    if (!_hasValidReminderOffsets(draft.reminderOffsetsMinutes)) {
      issues.add(
        const EventValidationIssue(
          EventValidationIssueCode.invalidReminderOffsets,
        ),
      );
    }

    if (draft.eventType == EventType.deathAnniversary && draft.isRecurring) {
      if (draft.targetMemberId?.trim().isNotEmpty != true) {
        issues.add(
          const EventValidationIssue(
            EventValidationIssueCode.memorialRequiresTargetMember,
          ),
        );
      }
      if (normalizeRecurrenceRule(draft.recurrenceRule) != 'FREQ=YEARLY') {
        issues.add(
          const EventValidationIssue(
            EventValidationIssueCode.memorialRequiresYearlyRecurrence,
          ),
        );
      }
    }

    return EventValidationResult(issues);
  }

  static bool hasValidTimeRange(DateTime startsAt, DateTime? endsAt) {
    if (endsAt == null) {
      return true;
    }

    return !endsAt.isBefore(startsAt);
  }

  static List<int> sanitizeReminderOffsets(Iterable<int> values) {
    final normalized =
        values.where((value) => value > 0).toSet().toList(growable: false)
          ..sort((left, right) => right.compareTo(left));

    return normalized;
  }

  static String? normalizeRecurrenceRule(String? rule) {
    final trimmed = rule?.trim().toUpperCase();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }

  static bool _hasValidReminderOffsets(Iterable<int> offsets) {
    return offsets.every((value) => value > 0);
  }
}
