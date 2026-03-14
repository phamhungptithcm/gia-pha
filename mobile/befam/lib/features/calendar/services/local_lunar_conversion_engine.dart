import 'dart:math' as math;

import '../models/calendar_region.dart';
import '../models/lunar_date.dart';
import 'lunar_conversion_cache.dart';
import 'lunar_conversion_engine.dart';

class LocalLunarConversionEngine implements LunarConversionEngine {
  LocalLunarConversionEngine({LunarConversionCache? cache})
    : _cache = cache ?? LunarConversionCache();

  final LunarConversionCache _cache;

  @override
  Future<LunarDate> solarToLunar(
    DateTime solarDate, {
    required CalendarRegion region,
  }) async {
    final date = DateTime(solarDate.year, solarDate.month, solarDate.day);
    final cached = await _cache.readDay(region: region, solarDate: date);
    if (cached != null) {
      return cached;
    }

    final resolved = _convertSolarToLunar(
      day: date.day,
      month: date.month,
      year: date.year,
      timeZone: region.timezoneOffsetHours,
    );
    await _cache.writeDay(region: region, solarDate: date, lunarDate: resolved);
    return resolved;
  }

  @override
  Future<DateTime?> lunarToSolar(
    LunarDate lunarDate, {
    required CalendarRegion region,
  }) async {
    final resolved = _convertLunarToSolar(
      lunarDay: lunarDate.day,
      lunarMonth: lunarDate.month,
      lunarYear: lunarDate.year,
      lunarLeap: lunarDate.isLeapMonth ? 1 : 0,
      timeZone: region.timezoneOffsetHours,
    );
    if (resolved == null) {
      return null;
    }

    return DateTime(resolved.year, resolved.month, resolved.day);
  }

  @override
  Future<Map<int, LunarDate>> monthSolarToLunar({
    required int year,
    required int month,
    required CalendarRegion region,
  }) async {
    final cached = await _cache.readMonth(
      region: region,
      year: year,
      month: month,
    );
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }

    final daysInMonth = DateTime(year, month + 1, 0).day;
    final monthMap = <int, LunarDate>{};
    for (var day = 1; day <= daysInMonth; day++) {
      monthMap[day] = _convertSolarToLunar(
        day: day,
        month: month,
        year: year,
        timeZone: region.timezoneOffsetHours,
      );
    }

    await _cache.writeMonth(
      region: region,
      year: year,
      month: month,
      monthMap: monthMap,
    );
    return monthMap;
  }

  LunarDate _convertSolarToLunar({
    required int day,
    required int month,
    required int year,
    required double timeZone,
  }) {
    final dayNumber = _julianDayFromDate(day, month, year);
    final k = ((dayNumber - 2415021.076998695) / 29.530588853).floor();
    var monthStart = _newMoonDay(k + 1, timeZone);
    if (monthStart > dayNumber) {
      monthStart = _newMoonDay(k, timeZone);
    }

    var a11 = _lunarMonth11(year, timeZone);
    var b11 = a11;
    late int lunarYear;

    if (a11 >= monthStart) {
      lunarYear = year;
      a11 = _lunarMonth11(year - 1, timeZone);
    } else {
      lunarYear = year + 1;
      b11 = _lunarMonth11(year + 1, timeZone);
    }

    final lunarDay = dayNumber - monthStart + 1;
    final diff = ((monthStart - a11) / 29).floor();
    var lunarMonth = diff + 11;
    var lunarLeap = 0;

    if (b11 - a11 > 365) {
      final leapMonthDiff = _leapMonthOffset(a11, timeZone);
      if (diff >= leapMonthDiff) {
        lunarMonth = diff + 10;
        if (diff == leapMonthDiff) {
          lunarLeap = 1;
        }
      }
    }

    if (lunarMonth > 12) {
      lunarMonth -= 12;
    }
    if (lunarMonth >= 11 && diff < 4) {
      lunarYear -= 1;
    }

    return LunarDate(
      year: lunarYear,
      month: lunarMonth,
      day: lunarDay,
      isLeapMonth: lunarLeap == 1,
    );
  }

  DateTime? _convertLunarToSolar({
    required int lunarDay,
    required int lunarMonth,
    required int lunarYear,
    required int lunarLeap,
    required double timeZone,
  }) {
    late int a11;
    late int b11;

    if (lunarMonth < 11) {
      a11 = _lunarMonth11(lunarYear - 1, timeZone);
      b11 = _lunarMonth11(lunarYear, timeZone);
    } else {
      a11 = _lunarMonth11(lunarYear, timeZone);
      b11 = _lunarMonth11(lunarYear + 1, timeZone);
    }

    var off = lunarMonth - 11;
    if (off < 0) {
      off += 12;
    }

    if (b11 - a11 > 365) {
      final leapOff = _leapMonthOffset(a11, timeZone);
      var leapMonth = leapOff - 2;
      if (leapMonth < 0) {
        leapMonth += 12;
      }

      if (lunarLeap == 1 && lunarMonth != leapMonth) {
        return null;
      }
      if (lunarLeap == 1 || off >= leapOff) {
        off += 1;
      }
    }

    final k = ((a11 - 2415021.076998695) / 29.530588853 + 0.5).floor();
    final monthStart = _newMoonDay(k + off, timeZone);
    return _julianDayToDate(monthStart + lunarDay - 1);
  }

  int _julianDayFromDate(int day, int month, int year) {
    final a = ((14 - month) / 12).floor();
    final y = year + 4800 - a;
    final m = month + 12 * a - 3;

    var jd =
        day +
        ((153 * m + 2) / 5).floor() +
        365 * y +
        (y / 4).floor() -
        (y / 100).floor() +
        (y / 400).floor() -
        32045;

    if (jd < 2299161) {
      jd =
          day + ((153 * m + 2) / 5).floor() + 365 * y + (y / 4).floor() - 32083;
    }

    return jd;
  }

  DateTime _julianDayToDate(int julianDay) {
    late int a;
    late int b;
    late int c;

    if (julianDay > 2299160) {
      a = julianDay + 32044;
      b = ((4 * a + 3) / 146097).floor();
      c = a - ((b * 146097) / 4).floor();
    } else {
      b = 0;
      c = julianDay + 32082;
    }

    final d = ((4 * c + 3) / 1461).floor();
    final e = c - ((1461 * d) / 4).floor();
    final m = ((5 * e + 2) / 153).floor();
    final day = e - ((153 * m + 2) / 5).floor() + 1;
    final month = m + 3 - 12 * (m / 10).floor();
    final year = b * 100 + d - 4800 + (m / 10).floor();

    return DateTime(year, month, day);
  }

  int _newMoonDay(int k, double timeZone) {
    final julianDate = _newMoon(k);
    return (julianDate + 0.5 + timeZone / 24).floor();
  }

  int _lunarMonth11(int year, double timeZone) {
    final off = _julianDayFromDate(31, 12, year) - 2415021;
    final k = (off / 29.530588853).floor();
    var newMoon = _newMoonDay(k, timeZone);
    final sunLongitude = _sunLongitude(newMoon, timeZone);
    if (sunLongitude >= 9) {
      newMoon = _newMoonDay(k - 1, timeZone);
    }
    return newMoon;
  }

  int _leapMonthOffset(int a11, double timeZone) {
    final k = ((a11 - 2415021.076998695) / 29.530588853 + 0.5).floor();
    var last = 0;
    var index = 1;
    var arc = _sunLongitude(_newMoonDay(k + index, timeZone), timeZone);

    do {
      last = arc;
      index += 1;
      arc = _sunLongitude(_newMoonDay(k + index, timeZone), timeZone);
    } while (arc != last && index < 14);

    return index - 1;
  }

  int _sunLongitude(int julianDayNumber, double timeZone) {
    final t = (julianDayNumber - 2451545.5 - timeZone / 24) / 36525;
    final t2 = t * t;
    final dr = math.pi / 180;
    final m =
        357.52910 + 35999.05030 * t - 0.0001559 * t2 - 0.00000048 * t * t2;
    final l0 = 280.46645 + 36000.76983 * t + 0.0003032 * t2;
    final dl =
        (1.914600 - 0.004817 * t - 0.000014 * t2) * math.sin(dr * m) +
        (0.019993 - 0.000101 * t) * math.sin(2 * dr * m) +
        0.000290 * math.sin(3 * dr * m);

    var longitude = l0 + dl;
    longitude *= dr;
    longitude -= math.pi * 2 * (longitude / (math.pi * 2)).floor();

    return (longitude / math.pi * 6).floor();
  }

  double _newMoon(int k) {
    final t = k / 1236.85;
    final t2 = t * t;
    final t3 = t2 * t;
    final dr = math.pi / 180;

    var jd1 =
        2415020.75933 + 29.53058868 * k + 0.0001178 * t2 - 0.000000155 * t3;
    jd1 += 0.00033 * math.sin((166.56 + 132.87 * t - 0.009173 * t2) * dr);

    final m = 359.2242 + 29.10535608 * k - 0.0000333 * t2 - 0.00000347 * t3;
    final mPrime =
        306.0253 + 385.81691806 * k + 0.0107306 * t2 + 0.00001236 * t3;
    final f = 21.2964 + 390.67050646 * k - 0.0016528 * t2 - 0.00000239 * t3;

    final correction =
        (0.1734 - 0.000393 * t) * math.sin(m * dr) +
        0.0021 * math.sin(2 * dr * m) -
        0.4068 * math.sin(mPrime * dr) +
        0.0161 * math.sin(2 * dr * mPrime) -
        0.0004 * math.sin(3 * dr * mPrime) +
        0.0104 * math.sin(2 * dr * f) -
        0.0051 * math.sin(dr * (m + mPrime)) -
        0.0074 * math.sin(dr * (m - mPrime)) +
        0.0004 * math.sin(dr * (2 * f + m)) -
        0.0004 * math.sin(dr * (2 * f - m)) -
        0.0006 * math.sin(dr * (2 * f + mPrime)) +
        0.0010 * math.sin(dr * (2 * f - mPrime)) +
        0.0005 * math.sin(dr * (2 * mPrime + m));

    final deltaT = t < -11
        ? 0.001 +
              0.000839 * t +
              0.0002261 * t2 -
              0.00000845 * t3 -
              0.000000081 * t * t3
        : -0.000278 + 0.000265 * t + 0.000262 * t2;

    return jd1 + correction - deltaT;
  }
}
