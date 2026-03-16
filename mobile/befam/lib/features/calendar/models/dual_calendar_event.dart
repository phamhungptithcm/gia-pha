import '../../../core/services/app_environment.dart';
import 'calendar_date_mode.dart';
import '../../events/models/event_type.dart';
import 'event_notification_audience.dart';
import 'lunar_date.dart';
import 'lunar_recurrence_policy.dart';

class DualCalendarEvent {
  const DualCalendarEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.eventType,
    required this.memorialForName,
    required this.hostHousehold,
    required this.locationAddress,
    required this.dateMode,
    required this.solarDate,
    required this.lunarDate,
    required this.isAnnualRecurring,
    required this.recurrencePolicy,
    required this.reminderOffsetsMinutes,
    this.notificationAudience = const EventNotificationAudience(),
    required this.timezone,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String description;
  final EventType eventType;
  final String memorialForName;
  final String hostHousehold;
  final String locationAddress;
  final CalendarDateMode dateMode;
  final DateTime solarDate;
  final LunarDate? lunarDate;
  final bool isAnnualRecurring;
  final LunarRecurrencePolicy recurrencePolicy;
  final List<int> reminderOffsetsMinutes;
  final EventNotificationAudience notificationAudience;
  final String timezone;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get usesLunarDate => dateMode == CalendarDateMode.lunar;
  bool get hasReminders => reminderOffsetsMinutes.isNotEmpty;

  String get dayKey {
    return '${solarDate.year}-${solarDate.month.toString().padLeft(2, '0')}-${solarDate.day.toString().padLeft(2, '0')}';
  }

  DualCalendarEvent copyWith({
    String? id,
    String? title,
    String? description,
    EventType? eventType,
    String? memorialForName,
    String? hostHousehold,
    String? locationAddress,
    CalendarDateMode? dateMode,
    DateTime? solarDate,
    LunarDate? lunarDate,
    bool? isAnnualRecurring,
    LunarRecurrencePolicy? recurrencePolicy,
    List<int>? reminderOffsetsMinutes,
    EventNotificationAudience? notificationAudience,
    String? timezone,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool clearLunarDate = false,
  }) {
    return DualCalendarEvent(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      eventType: eventType ?? this.eventType,
      memorialForName: memorialForName ?? this.memorialForName,
      hostHousehold: hostHousehold ?? this.hostHousehold,
      locationAddress: locationAddress ?? this.locationAddress,
      dateMode: dateMode ?? this.dateMode,
      solarDate: solarDate ?? this.solarDate,
      lunarDate: clearLunarDate ? null : lunarDate ?? this.lunarDate,
      isAnnualRecurring: isAnnualRecurring ?? this.isAnnualRecurring,
      recurrencePolicy: recurrencePolicy ?? this.recurrencePolicy,
      reminderOffsetsMinutes:
          reminderOffsetsMinutes ?? this.reminderOffsetsMinutes,
      notificationAudience: notificationAudience ?? this.notificationAudience,
      timezone: timezone ?? this.timezone,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'eventType': eventType.wireName,
      'memorialForName': memorialForName,
      'hostHousehold': hostHousehold,
      'locationAddress': locationAddress,
      'dateMode': dateMode.name,
      'solarDate': solarDate.toUtc().toIso8601String(),
      'lunarDate': lunarDate?.toJson(),
      'isAnnualRecurring': isAnnualRecurring,
      'recurrencePolicy': recurrencePolicy.wireName,
      'reminderOffsetsMinutes': reminderOffsetsMinutes,
      'notificationAudience': notificationAudience.toJson(),
      'timezone': timezone,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'updatedAt': updatedAt.toUtc().toIso8601String(),
    };
  }

  factory DualCalendarEvent.fromJson(Map<String, dynamic> json) {
    final lunarRaw = json['lunarDate'];
    return DualCalendarEvent(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      eventType: EventType.fromWireName(json['eventType'] as String?),
      memorialForName: json['memorialForName'] as String? ?? '',
      hostHousehold: json['hostHousehold'] as String? ?? '',
      locationAddress: json['locationAddress'] as String? ?? '',
      dateMode: (json['dateMode'] as String? ?? '').toLowerCase() == 'lunar'
          ? CalendarDateMode.lunar
          : CalendarDateMode.solar,
      solarDate: _parseDateTime(json['solarDate']) ?? DateTime.now(),
      lunarDate: lunarRaw is Map<String, dynamic>
          ? LunarDate.fromJson(lunarRaw)
          : null,
      isAnnualRecurring: json['isAnnualRecurring'] as bool? ?? false,
      recurrencePolicy: LunarRecurrencePolicy.fromWireName(
        json['recurrencePolicy'] as String?,
      ),
      reminderOffsetsMinutes: _offsetList(json['reminderOffsetsMinutes']),
      notificationAudience: EventNotificationAudience.fromJson(
        json['notificationAudience'] is Map<String, dynamic>
            ? json['notificationAudience'] as Map<String, dynamic>
            : null,
      ),
      timezone: json['timezone'] as String? ?? AppEnvironment.defaultTimezone,
      createdAt: _parseDateTime(json['createdAt']) ?? DateTime.now(),
      updatedAt: _parseDateTime(json['updatedAt']) ?? DateTime.now(),
    );
  }
}

DateTime? _parseDateTime(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is DateTime) {
    return value.toLocal();
  }
  if (value is String) {
    return DateTime.tryParse(value)?.toLocal();
  }
  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true).toLocal();
  }
  return null;
}

List<int> _offsetList(dynamic value) {
  if (value is! List) {
    return const [];
  }

  return value
      .whereType<num>()
      .map((entry) => entry.toInt())
      .where((entry) => entry > 0)
      .toSet()
      .toList(growable: false)
    ..sort((a, b) => b.compareTo(a));
}
