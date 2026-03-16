import '../../../core/services/app_environment.dart';
import 'event_record.dart';
import 'event_type.dart';

class EventDraft {
  const EventDraft({
    required this.branchId,
    required this.title,
    required this.description,
    required this.eventType,
    required this.targetMemberId,
    required this.locationName,
    required this.locationAddress,
    required this.startsAt,
    required this.endsAt,
    required this.timezone,
    required this.isRecurring,
    required this.recurrenceRule,
    required this.reminderOffsetsMinutes,
    required this.visibility,
    required this.status,
  });

  final String? branchId;
  final String title;
  final String description;
  final EventType eventType;
  final String? targetMemberId;
  final String locationName;
  final String locationAddress;
  final DateTime startsAt;
  final DateTime? endsAt;
  final String timezone;
  final bool isRecurring;
  final String? recurrenceRule;
  final List<int> reminderOffsetsMinutes;
  final String visibility;
  final String status;

  bool get isMemorial => eventType.isMemorial;

  EventDraft copyWith({
    String? branchId,
    String? title,
    String? description,
    EventType? eventType,
    String? targetMemberId,
    String? locationName,
    String? locationAddress,
    DateTime? startsAt,
    DateTime? endsAt,
    String? timezone,
    bool? isRecurring,
    String? recurrenceRule,
    List<int>? reminderOffsetsMinutes,
    String? visibility,
    String? status,
    bool clearBranchId = false,
    bool clearTargetMemberId = false,
    bool clearEndsAt = false,
    bool clearRecurrenceRule = false,
  }) {
    return EventDraft(
      branchId: clearBranchId ? null : branchId ?? this.branchId,
      title: title ?? this.title,
      description: description ?? this.description,
      eventType: eventType ?? this.eventType,
      targetMemberId: clearTargetMemberId
          ? null
          : targetMemberId ?? this.targetMemberId,
      locationName: locationName ?? this.locationName,
      locationAddress: locationAddress ?? this.locationAddress,
      startsAt: startsAt ?? this.startsAt,
      endsAt: clearEndsAt ? null : endsAt ?? this.endsAt,
      timezone: timezone ?? this.timezone,
      isRecurring: isRecurring ?? this.isRecurring,
      recurrenceRule: clearRecurrenceRule
          ? null
          : recurrenceRule ?? this.recurrenceRule,
      reminderOffsetsMinutes:
          reminderOffsetsMinutes ?? this.reminderOffsetsMinutes,
      visibility: visibility ?? this.visibility,
      status: status ?? this.status,
    );
  }

  factory EventDraft.empty({String? defaultBranchId}) {
    final now = DateTime.now();
    final nextHour = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
    ).add(const Duration(hours: 1));

    return EventDraft(
      branchId: defaultBranchId,
      title: '',
      description: '',
      eventType: EventType.clanGathering,
      targetMemberId: null,
      locationName: '',
      locationAddress: '',
      startsAt: nextHour,
      endsAt: nextHour.add(const Duration(hours: 2)),
      timezone: AppEnvironment.defaultTimezone,
      isRecurring: false,
      recurrenceRule: null,
      reminderOffsetsMinutes: const [1440, 120],
      visibility: 'clan',
      status: 'scheduled',
    );
  }

  factory EventDraft.fromRecord(EventRecord event) {
    return EventDraft(
      branchId: event.branchId,
      title: event.title,
      description: event.description,
      eventType: event.eventType,
      targetMemberId: event.targetMemberId,
      locationName: event.locationName,
      locationAddress: event.locationAddress,
      startsAt: event.startsAt,
      endsAt: event.endsAt,
      timezone: event.timezone,
      isRecurring: event.isRecurring,
      recurrenceRule: event.recurrenceRule,
      reminderOffsetsMinutes: event.reminderOffsetsMinutes,
      visibility: event.visibility,
      status: event.status,
    );
  }
}
