import '../models/dual_calendar_event.dart';

class LunarReminderSchedule {
  const LunarReminderSchedule({
    required this.eventId,
    required this.occurrenceDate,
    required this.reminderAt,
    required this.offsetMinutes,
  });

  final String eventId;
  final DateTime occurrenceDate;
  final DateTime reminderAt;
  final int offsetMinutes;
}

class LunarReminderScheduler {
  List<LunarReminderSchedule> buildSchedules({
    required DualCalendarEvent event,
    required List<DateTime> occurrences,
    DateTime? now,
    int? maxSchedules,
  }) {
    final baseline = now ?? DateTime.now();
    final schedules = <LunarReminderSchedule>[];
    final offsets =
        event.reminderOffsetsMinutes
            .where((offset) => offset > 0)
            .toSet()
            .toList(growable: false)
          ..sort((left, right) => right.compareTo(left));
    final seen = <String>{};

    for (final occurrence in occurrences) {
      final occurrenceDateTime = DateTime(
        occurrence.year,
        occurrence.month,
        occurrence.day,
        event.solarDate.hour,
        event.solarDate.minute,
      );

      for (final offset in offsets) {
        final reminderAt = occurrenceDateTime.subtract(
          Duration(minutes: offset),
        );
        if (reminderAt.isBefore(baseline)) {
          continue;
        }
        final dedupeKey =
            '${event.id}|${occurrenceDateTime.toIso8601String()}|$offset';
        if (!seen.add(dedupeKey)) {
          continue;
        }

        schedules.add(
          LunarReminderSchedule(
            eventId: event.id,
            occurrenceDate: occurrenceDateTime,
            reminderAt: reminderAt,
            offsetMinutes: offset,
          ),
        );
      }
    }

    schedules.sort(
      (left, right) => left.reminderAt.compareTo(right.reminderAt),
    );
    if (maxSchedules != null &&
        maxSchedules > 0 &&
        schedules.length > maxSchedules) {
      return schedules.take(maxSchedules).toList(growable: false);
    }
    return schedules;
  }
}
