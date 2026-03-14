import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/calendar_region.dart';
import '../models/lunar_date.dart';

class LunarConversionCache {
  LunarConversionCache({SharedPreferences? preferences}) : _preferences = preferences;

  final SharedPreferences? _preferences;
  SharedPreferences? _instance;

  final Map<String, Map<int, LunarDate>> _memory = {};

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
      for (final entry in monthMap.entries) '${entry.key}': entry.value.toJson(),
    };

    final prefs = await _getPreferences();
    await prefs.setString(key, jsonEncode(payload));
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
    return 'lunar-cache-${region.code}-$year-${month.toString().padLeft(2, '0')}';
  }
}
