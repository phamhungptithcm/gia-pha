import 'package:flutter/foundation.dart';

import '../models/calendar_display_mode.dart';
import '../models/calendar_region.dart';
import '../models/dual_calendar_event.dart';
import '../models/lunar_date.dart';
import '../models/lunar_holiday.dart';
import '../models/lunar_recurrence_policy.dart';
import '../services/calendar_settings_store.dart';
import '../services/dual_calendar_event_store.dart';
import '../services/lunar_conversion_cache.dart';
import '../services/lunar_conversion_engine.dart';
import '../services/lunar_holiday_repository.dart';
import '../services/lunar_recurrence_resolver.dart';
import '../services/lunar_reminder_scheduler.dart';
import '../services/lunar_resolution_cache.dart';

class CalendarEventOccurrence {
  const CalendarEventOccurrence({
    required this.event,
    required this.occurrenceDate,
  });

  final DualCalendarEvent event;
  final DateTime occurrenceDate;
}

class DualCalendarController extends ChangeNotifier {
  DualCalendarController({
    required DualCalendarEventStore eventStore,
    required LunarConversionEngine conversionEngine,
    required LunarHolidayRepository holidayRepository,
    required LunarRecurrenceResolver recurrenceResolver,
    required LunarReminderScheduler reminderScheduler,
    required CalendarSettingsStore settingsStore,
    required LunarConversionCache conversionCache,
    required LunarResolutionCache resolutionCache,
    DateTime? now,
  }) : _eventStore = eventStore,
       _conversionEngine = conversionEngine,
       _holidayRepository = holidayRepository,
       _recurrenceResolver = recurrenceResolver,
       _reminderScheduler = reminderScheduler,
       _settingsStore = settingsStore,
       _conversionCache = conversionCache,
       _resolutionCache = resolutionCache,
       _clock = now ?? DateTime.now() {
    final today = _dateOnly(_clock);
    _focusedMonth = DateTime(today.year, today.month);
    _selectedDay = today;
  }

  final DualCalendarEventStore _eventStore;
  final LunarConversionEngine _conversionEngine;
  final LunarHolidayRepository _holidayRepository;
  final LunarRecurrenceResolver _recurrenceResolver;
  final LunarReminderScheduler _reminderScheduler;
  final CalendarSettingsStore _settingsStore;
  final LunarConversionCache _conversionCache;
  final LunarResolutionCache _resolutionCache;
  final DateTime _clock;

  bool _initialized = false;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;
  DateTime _focusedMonth = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  CalendarRegion _region = CalendarRegion.vietnam;
  CalendarDisplayMode _displayMode = CalendarDisplayMode.dual;
  Map<int, LunarDate> _monthLunarMap = const {};
  List<LunarHoliday> _holidays = const [];
  Map<String, List<LunarHoliday>> _holidaysByMonthDay = const {};
  Map<String, List<CalendarEventOccurrence>> _eventsByDay = const {};
  List<LunarReminderSchedule> _upcomingReminders = const [];
  List<DualCalendarEvent> _windowEvents = const [];

  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;
  DateTime get focusedMonth => _focusedMonth;
  DateTime get selectedDay => _selectedDay;
  CalendarRegion get region => _region;
  CalendarDisplayMode get displayMode => _displayMode;
  Map<int, LunarDate> get monthLunarMap => _monthLunarMap;
  List<LunarHoliday> get holidays => _holidays;
  List<LunarReminderSchedule> get upcomingReminders => _upcomingReminders;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    _initialized = true;
    await refreshAll();
  }

  Future<void> refreshAll() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final settings = await _settingsStore.load();
      _region = settings.region;
      _displayMode = settings.displayMode;
      await _loadFocusedMonth();
    } catch (error) {
      _errorMessage = error.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> setRegion(CalendarRegion value) async {
    if (_region == value) {
      return;
    }
    final previous = _region;
    _region = value;
    _isLoading = true;
    notifyListeners();

    try {
      await _settingsStore.save(
        CalendarSettings(region: _region, displayMode: _displayMode),
      );
      await _conversionCache.invalidateRegion(previous);
      await _resolutionCache.invalidateRegion(previous);
      await _loadFocusedMonth();
    } catch (error) {
      _errorMessage = error.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> setDisplayMode(CalendarDisplayMode value) async {
    if (_displayMode == value) {
      return;
    }
    _displayMode = value;
    await _settingsStore.save(
      CalendarSettings(region: _region, displayMode: _displayMode),
    );
    notifyListeners();
  }

  Future<void> goToPreviousMonth() async {
    _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1);
    _selectedDay = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    await _loadFocusedMonthWithLoading();
  }

  Future<void> goToNextMonth() async {
    _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1);
    _selectedDay = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    await _loadFocusedMonthWithLoading();
  }

  Future<void> jumpToMonth(DateTime month) async {
    _focusedMonth = DateTime(month.year, month.month);
    _selectedDay = DateTime(month.year, month.month, 1);
    await _loadFocusedMonthWithLoading();
  }

  void selectDay(DateTime value) {
    _selectedDay = _dateOnly(value);
    notifyListeners();
  }

  LunarDate? lunarDateForDay(DateTime day) {
    final normalized = _dateOnly(day);
    if (normalized.year == _focusedMonth.year &&
        normalized.month == _focusedMonth.month) {
      return _monthLunarMap[normalized.day];
    }
    return null;
  }

  bool isHolidayDay(DateTime day) {
    return holidaysForDay(day).isNotEmpty;
  }

  List<LunarHoliday> holidaysForDay(DateTime day) {
    final lunarDate = lunarDateForDay(day);
    if (lunarDate == null) {
      return const [];
    }

    final month = lunarDate.month.toString().padLeft(2, '0');
    final dayValue = lunarDate.day.toString().padLeft(2, '0');
    final key = '$month-$dayValue';
    return _holidaysByMonthDay[key] ?? const [];
  }

  int eventCountForDay(DateTime day) {
    final key = _dayKey(day);
    return _eventsByDay[key]?.length ?? 0;
  }

  List<CalendarEventOccurrence> occurrencesForDay(DateTime day) {
    final key = _dayKey(day);
    final occurrences = List<CalendarEventOccurrence>.from(
      _eventsByDay[key] ?? const [],
    );
    occurrences.sort(
      (left, right) => left.occurrenceDate.compareTo(right.occurrenceDate),
    );
    return occurrences;
  }

  Future<DateTime?> resolveLunarToSolar({
    required LunarDate lunarDate,
    required LunarRecurrencePolicy policy,
    int? targetYear,
  }) {
    return _recurrenceResolver.resolveLunarDateForYear(
      lunarDate: lunarDate,
      targetYear: targetYear ?? lunarDate.year,
      region: _region,
      policy: policy,
    );
  }

  Future<void> saveEvent({
    String? eventId,
    required DualCalendarEvent event,
  }) async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _eventStore.saveEvent(eventId: eventId, event: event);
      await _loadFocusedMonth();
    } catch (error) {
      _errorMessage = error.toString();
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<void> deleteEvent(String eventId) async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _eventStore.deleteEvent(eventId);
      await _loadFocusedMonth();
    } catch (error) {
      _errorMessage = error.toString();
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<void> _loadFocusedMonthWithLoading() async {
    _isLoading = true;
    notifyListeners();
    try {
      await _loadFocusedMonth();
    } catch (error) {
      _errorMessage = error.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadFocusedMonth() async {
    final month = _focusedMonth;
    _monthLunarMap = await _conversionEngine.monthSolarToLunar(
      year: month.year,
      month: month.month,
      region: _region,
    );
    _holidays = await _holidayRepository.loadHolidays(region: _region);
    _holidaysByMonthDay = _buildHolidayLookup(_holidays);
    await _loadWindowEvents();
  }

  Future<void> _loadWindowEvents() async {
    final windowStart = DateTime(
      _focusedMonth.year,
      _focusedMonth.month - 1,
      1,
    );
    final windowEnd = DateTime(_focusedMonth.year, _focusedMonth.month + 2, 0);
    final candidates = await _eventStore.loadEventsInWindow(
      start: windowStart,
      end: windowEnd,
    );
    _windowEvents = candidates;

    final byDay = <String, List<CalendarEventOccurrence>>{};
    final reminders = <LunarReminderSchedule>[];
    final resolutions = await Future.wait(
      _windowEvents.map((event) async {
        final occurrences = await _recurrenceResolver.resolveOccurrences(
          event: event,
          region: _region,
          rangeStart: windowStart,
          rangeEnd: windowEnd,
        );
        return (event: event, occurrences: occurrences);
      }),
    );

    for (final resolution in resolutions) {
      final event = resolution.event;
      final occurrences = resolution.occurrences;
      if (occurrences.isEmpty) {
        continue;
      }

      reminders.addAll(
        _reminderScheduler.buildSchedules(
          event: event,
          occurrences: occurrences,
          maxSchedules: 24,
        ),
      );

      for (final occurrenceDate in occurrences) {
        final occurrenceDateTime = DateTime(
          occurrenceDate.year,
          occurrenceDate.month,
          occurrenceDate.day,
          event.solarDate.hour,
          event.solarDate.minute,
        );
        final key = _dayKey(occurrenceDateTime);
        byDay
            .putIfAbsent(key, () => <CalendarEventOccurrence>[])
            .add(
              CalendarEventOccurrence(
                event: event,
                occurrenceDate: occurrenceDateTime,
              ),
            );
      }
    }

    reminders.sort(
      (left, right) => left.reminderAt.compareTo(right.reminderAt),
    );
    _eventsByDay = byDay;
    _upcomingReminders = reminders.take(15).toList(growable: false);
  }

  Map<String, List<LunarHoliday>> _buildHolidayLookup(
    List<LunarHoliday> values,
  ) {
    final lookup = <String, List<LunarHoliday>>{};
    for (final holiday in values) {
      lookup
          .putIfAbsent(holiday.monthDayKey, () => <LunarHoliday>[])
          .add(holiday);
    }
    return lookup;
  }

  static DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  String _dayKey(DateTime value) {
    return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  }
}
