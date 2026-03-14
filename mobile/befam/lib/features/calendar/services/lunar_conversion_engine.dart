import '../models/calendar_region.dart';
import '../models/lunar_date.dart';
import 'local_lunar_conversion_engine.dart';

abstract interface class LunarConversionEngine {
  Future<LunarDate> solarToLunar(
    DateTime solarDate, {
    required CalendarRegion region,
  });

  Future<DateTime?> lunarToSolar(
    LunarDate lunarDate, {
    required CalendarRegion region,
  });

  Future<Map<int, LunarDate>> monthSolarToLunar({
    required int year,
    required int month,
    required CalendarRegion region,
  });
}

LunarConversionEngine createDefaultLunarConversionEngine() {
  return LocalLunarConversionEngine();
}
