import 'event_type.dart';

class EventRecord {
  const EventRecord({
    required this.id,
    required this.clanId,
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

  final String id;
  final String clanId;
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

  EventRecord copyWith({
    String? id,
    String? clanId,
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
    return EventRecord(
      id: id ?? this.id,
      clanId: clanId ?? this.clanId,
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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'clanId': clanId,
      'branchId': branchId,
      'title': title,
      'description': description,
      'eventType': eventType.wireName,
      'targetMemberId': targetMemberId,
      'locationName': locationName,
      'locationAddress': locationAddress,
      'startsAt': startsAt.toUtc().toIso8601String(),
      'endsAt': endsAt?.toUtc().toIso8601String(),
      'timezone': timezone,
      'isRecurring': isRecurring,
      'recurrenceRule': recurrenceRule,
      'reminderOffsetsMinutes': reminderOffsetsMinutes,
      'visibility': visibility,
      'status': status,
    };
  }

  factory EventRecord.fromJson(Map<String, dynamic> json) {
    final startsAt = _parseDateTime(json['startsAt']);
    return EventRecord(
      id: json['id'] as String? ?? '',
      clanId: json['clanId'] as String? ?? '',
      branchId: _nullableTrim(json['branchId']),
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      eventType: EventType.fromWireName(json['eventType'] as String?),
      targetMemberId: _nullableTrim(json['targetMemberId']),
      locationName: json['locationName'] as String? ?? '',
      locationAddress: json['locationAddress'] as String? ?? '',
      startsAt: startsAt ?? DateTime.now().toUtc(),
      endsAt: _parseDateTime(json['endsAt']),
      timezone: json['timezone'] as String? ?? 'Asia/Ho_Chi_Minh',
      isRecurring: json['isRecurring'] as bool? ?? false,
      recurrenceRule: _nullableTrim(json['recurrenceRule']),
      reminderOffsetsMinutes: _offsetList(json['reminderOffsetsMinutes']),
      visibility: json['visibility'] as String? ?? 'clan',
      status: json['status'] as String? ?? 'scheduled',
    );
  }
}

DateTime? _parseDateTime(dynamic value) {
  if (value == null) {
    return null;
  }

  if (value is DateTime) {
    return value.toUtc();
  }

  if (value is String) {
    return DateTime.tryParse(value)?.toUtc();
  }

  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
  }

  try {
    final dynamic maybeDate = value.toDate();
    if (maybeDate is DateTime) {
      return maybeDate.toUtc();
    }
  } catch (_) {
    return null;
  }

  return null;
}

String? _nullableTrim(dynamic value) {
  if (value is! String) {
    return null;
  }

  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

List<int> _offsetList(dynamic value) {
  if (value is! List) {
    return const [];
  }

  final offsets =
      value
          .whereType<num>()
          .map((entry) => entry.toInt())
          .where((entry) => entry > 0)
          .toSet()
          .toList(growable: false)
        ..sort((left, right) => right.compareTo(left));

  return offsets;
}
