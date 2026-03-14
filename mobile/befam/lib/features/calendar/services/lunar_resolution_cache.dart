import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/calendar_region.dart';
import '../models/lunar_date.dart';
import '../models/lunar_recurrence_policy.dart';

class LunarResolutionCache {
  LunarResolutionCache({SharedPreferences? preferences})
    : _preferences = preferences;

  static const _storageKey = 'lunar-resolution-cache-v1';
  static const _nullMarker = '__null__';

  final SharedPreferences? _preferences;
  SharedPreferences? _instance;
  Map<String, String>? _memory;

  Future<DateTime?> read({
    required CalendarRegion region,
    required LunarDate lunarDate,
    required int targetYear,
    required LunarRecurrencePolicy policy,
  }) async {
    final cache = await _readAll();
    final key = _cacheKey(
      region: region,
      lunarDate: lunarDate,
      targetYear: targetYear,
      policy: policy,
    );
    final encoded = cache[key];
    if (encoded == null || encoded == _nullMarker) {
      return null;
    }
    return DateTime.tryParse(encoded)?.toLocal();
  }

  Future<void> write({
    required CalendarRegion region,
    required LunarDate lunarDate,
    required int targetYear,
    required LunarRecurrencePolicy policy,
    required DateTime? resolvedDate,
  }) async {
    final cache = await _readAll();
    final key = _cacheKey(
      region: region,
      lunarDate: lunarDate,
      targetYear: targetYear,
      policy: policy,
    );
    cache[key] = resolvedDate?.toIso8601String() ?? _nullMarker;
    await _persist();
  }

  Future<void> invalidateRegion(CalendarRegion region) async {
    final cache = await _readAll();
    cache.removeWhere((key, value) => key.startsWith('${region.code}|'));
    await _persist();
  }

  Future<void> clear() async {
    _memory = {};
    final prefs = await _getPreferences();
    await prefs.remove(_storageKey);
  }

  Future<Map<String, String>> _readAll() async {
    final existing = _memory;
    if (existing != null) {
      return existing;
    }

    final prefs = await _getPreferences();
    final encoded = prefs.getString(_storageKey);
    if (encoded == null || encoded.isEmpty) {
      _memory = {};
      return _memory!;
    }

    final decoded = jsonDecode(encoded);
    if (decoded is! Map<String, dynamic>) {
      _memory = {};
      return _memory!;
    }

    _memory = decoded.map(
      (key, value) => MapEntry(key, value?.toString() ?? _nullMarker),
    );
    return _memory!;
  }

  Future<void> _persist() async {
    final cache = _memory;
    if (cache == null) {
      return;
    }
    final prefs = await _getPreferences();
    await prefs.setString(_storageKey, jsonEncode(cache));
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
    required LunarDate lunarDate,
    required int targetYear,
    required LunarRecurrencePolicy policy,
  }) {
    return '${region.code}|$targetYear|${lunarDate.month}|${lunarDate.day}|${lunarDate.isLeapMonth ? 1 : 0}|${policy.wireName}';
  }
}
