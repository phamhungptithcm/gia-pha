import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/app_environment.dart';
import '../../events/models/event_type.dart';
import '../models/calendar_date_mode.dart';
import '../models/dual_calendar_event.dart';
import '../models/lunar_date.dart';
import '../models/lunar_recurrence_policy.dart';

abstract interface class DualCalendarEventStore {
  Future<List<DualCalendarEvent>> loadEvents();

  Future<List<DualCalendarEvent>> loadEventsInWindow({
    required DateTime start,
    required DateTime end,
  });

  Future<DualCalendarEvent> saveEvent({
    String? eventId,
    required DualCalendarEvent event,
  });

  Future<void> deleteEvent(String eventId);
}

class SharedPrefsDualCalendarEventStore implements DualCalendarEventStore {
  SharedPrefsDualCalendarEventStore({SharedPreferences? preferences})
    : _preferences = preferences;

  static const _storageKey = 'dual-calendar-events-v1';

  final SharedPreferences? _preferences;
  SharedPreferences? _instance;

  List<DualCalendarEvent>? _memory;
  final Map<String, List<DualCalendarEvent>> _eventsByMonth = {};
  List<DualCalendarEvent> _annualRecurring = const [];
  int _sequence = 1000;

  @override
  Future<List<DualCalendarEvent>> loadEvents() async {
    final inMemory = _memory;
    if (inMemory != null) {
      return inMemory;
    }

    final prefs = await _getPreferences();
    final encoded = prefs.getString(_storageKey);
    if (encoded == null || encoded.isEmpty) {
      _memory = _seedEvents();
      await _persist();
      return _memory!;
    }

    final decoded = jsonDecode(encoded);
    if (decoded is! List) {
      _memory = _seedEvents();
      await _persist();
      return _memory!;
    }

    final loaded = decoded
        .whereType<Map<String, dynamic>>()
        .map(DualCalendarEvent.fromJson)
        .toList(growable: false);

    _memory = loaded;
    _rebuildIndex(loaded);
    final maxSuffix = loaded
        .map((event) => int.tryParse(event.id.split('_').last) ?? 1000)
        .fold<int>(1000, (max, value) => value > max ? value : max);
    _sequence = maxSuffix + 1;

    return loaded;
  }

  @override
  Future<List<DualCalendarEvent>> loadEventsInWindow({
    required DateTime start,
    required DateTime end,
  }) async {
    final events = await loadEvents();
    if (events.isEmpty) {
      return const [];
    }

    final rangeStart = DateTime(start.year, start.month, start.day);
    final rangeEnd = DateTime(end.year, end.month, end.day);
    if (rangeEnd.isBefore(rangeStart)) {
      return const [];
    }

    final candidateIds = <String>{};
    final candidates = <DualCalendarEvent>[];
    for (
      var cursor = DateTime(rangeStart.year, rangeStart.month);
      !cursor.isAfter(DateTime(rangeEnd.year, rangeEnd.month));
      cursor = DateTime(cursor.year, cursor.month + 1)
    ) {
      final monthKey = _monthKey(cursor);
      final bucket = _eventsByMonth[monthKey];
      if (bucket == null) {
        continue;
      }

      for (final event in bucket) {
        if (candidateIds.add(event.id)) {
          candidates.add(event);
        }
      }
    }

    for (final recurring in _annualRecurring) {
      if (candidateIds.add(recurring.id)) {
        candidates.add(recurring);
      }
    }

    return candidates;
  }

  @override
  Future<DualCalendarEvent> saveEvent({
    String? eventId,
    required DualCalendarEvent event,
  }) async {
    final events = List<DualCalendarEvent>.from(await loadEvents());
    final resolvedId =
        eventId ??
        (event.id.isNotEmpty ? event.id : 'cal_event_${_sequence++}');

    final now = DateTime.now();
    final payload = event.copyWith(
      id: resolvedId,
      createdAt: eventId == null ? now : event.createdAt,
      updatedAt: now,
    );

    final index = events.indexWhere((candidate) => candidate.id == resolvedId);
    if (index >= 0) {
      events[index] = payload;
    } else {
      events.add(payload);
    }

    events.sort((left, right) => left.solarDate.compareTo(right.solarDate));
    _memory = events;
    _rebuildIndex(events);
    await _persist();
    return payload;
  }

  @override
  Future<void> deleteEvent(String eventId) async {
    final events = List<DualCalendarEvent>.from(await loadEvents());
    events.removeWhere((event) => event.id == eventId);
    _memory = events;
    _rebuildIndex(events);
    await _persist();
  }

  Future<void> _persist() async {
    final events = _memory;
    if (events == null) {
      return;
    }

    final encoded = jsonEncode(events.map((event) => event.toJson()).toList());
    final prefs = await _getPreferences();
    await prefs.setString(_storageKey, encoded);
  }

  Future<SharedPreferences> _getPreferences() async {
    final existing = _instance ?? _preferences;
    if (existing != null) {
      _instance = existing;
      return existing;
    }

    final loaded = await SharedPreferences.getInstance();
    _instance = loaded;
    return loaded;
  }

  List<DualCalendarEvent> _seedEvents() {
    final now = DateTime.now();
    return [
      DualCalendarEvent(
        id: 'cal_event_1000',
        title: 'Lễ giỗ tổ tiên',
        description: 'Chuẩn bị lễ vật và họp mặt gia đình.',
        eventType: EventType.deathAnniversary,
        memorialForName: 'Nguyễn Văn Tổ',
        hostHousehold: 'Nhà trưởng chi',
        locationAddress: 'Nhà thờ họ, Quảng Nam',
        dateMode: CalendarDateMode.lunar,
        solarDate: DateTime(now.year, now.month, now.day, 9),
        lunarDate: LunarDate(year: now.year, month: 3, day: 10),
        isAnnualRecurring: true,
        recurrencePolicy: LunarRecurrencePolicy.firstOccurrence,
        reminderOffsetsMinutes: const [10080, 1440, 120],
        timezone: AppEnvironment.defaultTimezone,
        createdAt: now,
        updatedAt: now,
      ),
      DualCalendarEvent(
        id: 'cal_event_1001',
        title: 'Họp họ theo quý',
        description: 'Trao đổi kế hoạch học bổng và quỹ họ tộc.',
        eventType: EventType.meeting,
        memorialForName: '',
        hostHousehold: 'Nhà văn hóa chi phụ',
        locationAddress: 'Thừa Thiên Huế',
        dateMode: CalendarDateMode.solar,
        solarDate: DateTime(now.year, now.month, now.day + 7, 19),
        lunarDate: null,
        isAnnualRecurring: false,
        recurrencePolicy: LunarRecurrencePolicy.firstOccurrence,
        reminderOffsetsMinutes: const [1440, 180],
        timezone: AppEnvironment.defaultTimezone,
        createdAt: now,
        updatedAt: now,
      ),
    ];
  }

  void _rebuildIndex(List<DualCalendarEvent> events) {
    _eventsByMonth.clear();
    final annual = <DualCalendarEvent>[];
    for (final event in events) {
      if (event.isAnnualRecurring) {
        annual.add(event);
      } else {
        final key = _monthKey(event.solarDate);
        _eventsByMonth.update(
          key,
          (existing) => [...existing, event],
          ifAbsent: () => [event],
        );
      }
    }
    _annualRecurring = annual;
  }

  String _monthKey(DateTime value) {
    return '${value.year}-${value.month.toString().padLeft(2, '0')}';
  }
}

DualCalendarEventStore createDefaultDualCalendarEventStore() {
  return SharedPrefsDualCalendarEventStore();
}
