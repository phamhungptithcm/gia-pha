import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/calendar_region.dart';
import '../models/lunar_date.dart';

class LunarConversionCache {
  LunarConversionCache({SharedPreferences? preferences})
    : _preferences = preferences;

  static const _version = 'v2';

  final SharedPreferences? _preferences;
  SharedPreferences? _instance;

  final Map<String, Map<int, LunarDate>> _memory = {};
  final Map<String, LunarDate> _dayMemory = {};

  Future<LunarDate?> readDay({
    required CalendarRegion region,
    required DateTime solarDate,
  }) async {
    final key = _dayCacheKey(region: region, solarDate: solarDate);
    final inMemory = _dayMemory[key];
    if (inMemory != null) {
      return inMemory;
    }

    final prefs = await _getPreferences();
    final encoded = prefs.getString(key);
    if (encoded == null || encoded.isEmpty) {
      return null;
    }

    final decoded = jsonDecode(encoded);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }
    final date = LunarDate.fromJson(decoded);
    _dayMemory[key] = date;
    return date;
  }

  Future<void> writeDay({
    required CalendarRegion region,
    required DateTime solarDate,
    required LunarDate lunarDate,
  }) async {
    final key = _dayCacheKey(region: region, solarDate: solarDate);
    _dayMemory[key] = lunarDate;
    final prefs = await _getPreferences();
    await prefs.setString(key, jsonEncode(lunarDate.toJson()));
  }

  Future<Map<int, LunarDate>?> readMonth({
    required CalendarRegion region,
    required int year,
    required int month,
  }) async {
    final key = _cacheKey(region: region, year: year, month: month);
    final inMemory = _memory[key];
    if (inMemory != null) {
      return inMemory;
    }

    final prefs = await _getPreferences();
    final encoded = prefs.getString(key);
    if (encoded == null || encoded.isEmpty) {
      return null;
    }

    final decoded = jsonDecode(encoded);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }

    final monthMap = <int, LunarDate>{};
    for (final entry in decoded.entries) {
      final day = int.tryParse(entry.key);
      final raw = entry.value;
      if (day == null || raw is! Map<String, dynamic>) {
        continue;
      }
      monthMap[day] = LunarDate.fromJson(raw);
    }

    _memory[key] = monthMap;
    return monthMap;
  }

  Future<void> writeMonth({
    required CalendarRegion region,
    required int year,
    required int month,
    required Map<int, LunarDate> monthMap,
  }) async {
    final key = _cacheKey(region: region, year: year, month: month);
    _memory[key] = monthMap;

    final payload = <String, dynamic>{
      for (final entry in monthMap.entries)
        '${entry.key}': entry.value.toJson(),
    };

    final prefs = await _getPreferences();
    await prefs.setString(key, jsonEncode(payload));

    for (final entry in monthMap.entries) {
      await writeDay(
        region: region,
        solarDate: DateTime(year, month, entry.key),
        lunarDate: entry.value,
      );
    }
  }

  Future<void> invalidateRegion(CalendarRegion region) async {
    final prefs = await _getPreferences();
    final monthPrefix = 'lunar-cache-$_version-${region.code}-';
    final dayPrefix = 'lunar-day-cache-$_version-${region.code}-';
    final keys = prefs.getKeys().where(
      (key) => key.startsWith(monthPrefix) || key.startsWith(dayPrefix),
    );
    for (final key in keys) {
      await prefs.remove(key);
    }
    _memory.removeWhere((key, value) => key.startsWith(monthPrefix));
    _dayMemory.removeWhere((key, value) => key.startsWith(dayPrefix));
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

  String _cacheKey({
    required CalendarRegion region,
    required int year,
    required int month,
  }) {
    return 'lunar-cache-$_version-${region.code}-$year-${month.toString().padLeft(2, '0')}';
  }

  String _dayCacheKey({
    required CalendarRegion region,
    required DateTime solarDate,
  }) {
    return 'lunar-day-cache-$_version-${region.code}-${solarDate.year}-${solarDate.month.toString().padLeft(2, '0')}-${solarDate.day.toString().padLeft(2, '0')}';
  }
}
