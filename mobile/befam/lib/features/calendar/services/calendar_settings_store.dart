import 'package:shared_preferences/shared_preferences.dart';

import '../models/calendar_display_mode.dart';
import '../models/calendar_region.dart';

class CalendarSettings {
  const CalendarSettings({
    required this.region,
    required this.displayMode,
  });

  final CalendarRegion region;
  final CalendarDisplayMode displayMode;

  CalendarSettings copyWith({
    CalendarRegion? region,
    CalendarDisplayMode? displayMode,
  }) {
    return CalendarSettings(
      region: region ?? this.region,
      displayMode: displayMode ?? this.displayMode,
    );
  }
}

abstract interface class CalendarSettingsStore {
  Future<CalendarSettings> load();

  Future<CalendarSettings> save(CalendarSettings settings);
}

class SharedPrefsCalendarSettingsStore implements CalendarSettingsStore {
  SharedPrefsCalendarSettingsStore({SharedPreferences? preferences})
    : _preferences = preferences;

  static const _regionKey = 'calendar-settings-region';
  static const _displayModeKey = 'calendar-settings-display-mode';

  final SharedPreferences? _preferences;
  SharedPreferences? _instance;

  @override
  Future<CalendarSettings> load() async {
    final prefs = await _getPreferences();
    return CalendarSettings(
      region: CalendarRegion.fromCode(prefs.getString(_regionKey)),
      displayMode: CalendarDisplayMode.fromWireName(
        prefs.getString(_displayModeKey),
      ),
    );
  }

  @override
  Future<CalendarSettings> save(CalendarSettings settings) async {
    final prefs = await _getPreferences();
    await prefs.setString(_regionKey, settings.region.code);
    await prefs.setString(_displayModeKey, settings.displayMode.wireName);
    return settings;
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
}

CalendarSettingsStore createDefaultCalendarSettingsStore() {
  return SharedPrefsCalendarSettingsStore();
}
