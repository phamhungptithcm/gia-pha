import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/services/app_logger.dart';
import '../../../core/services/firebase_services.dart';
import '../models/calendar_region.dart';
import '../models/lunar_holiday.dart';

abstract interface class LunarHolidayRepository {
  Future<List<LunarHoliday>> loadHolidays({required CalendarRegion region});
}

class FirebaseLunarHolidayRepository implements LunarHolidayRepository {
  FirebaseLunarHolidayRepository({FirebaseFirestore? firestore})
    : _firestore = firestore;

  final FirebaseFirestore? _firestore;
  final Map<String, List<LunarHoliday>> _memoryCache = {};

  @override
  Future<List<LunarHoliday>> loadHolidays({
    required CalendarRegion region,
  }) async {
    final cacheKey = region.code;
    final cached = _memoryCache[cacheKey];
    if (cached != null) {
      return cached;
    }

    try {
      final firestore = _firestore ?? FirebaseServices.firestore;
      final snapshot = await firestore
          .collection('lunar_holidays')
          .where('regions', arrayContains: region.code)
          .get();

      final items = snapshot.docs
          .map(
            (doc) => LunarHoliday.fromJson({
              ...doc.data(),
              'regionCode': region.code,
              if ((doc.data()['id'] as String?)?.isEmpty ?? true) 'id': doc.id,
            }),
          )
          .toList(growable: false);

      if (items.isNotEmpty) {
        _memoryCache[cacheKey] = items;
        return items;
      }
    } catch (error, stackTrace) {
      AppLogger.warning(
        'Không thể tải ngày lễ âm lịch từ Firestore (lunar_holidays). Chuyển sang dữ liệu mặc định.',
        error,
        stackTrace,
      );
    }

    final defaults = _defaultHolidays(region);
    _memoryCache[cacheKey] = defaults;
    return defaults;
  }

  List<LunarHoliday> _defaultHolidays(CalendarRegion region) {
    final code = region.code;
    return [
      LunarHoliday(
        id: '$code-new-year',
        name: 'Tết Nguyên Đán',
        lunarMonth: 1,
        lunarDay: 1,
        regionCode: code,
        colorHex: '#EF5350',
      ),
      LunarHoliday(
        id: '$code-lantern',
        name: 'Rằm tháng Giêng',
        lunarMonth: 1,
        lunarDay: 15,
        regionCode: code,
        colorHex: '#FFA726',
      ),
      LunarHoliday(
        id: '$code-mid-autumn',
        name: 'Tết Trung Thu',
        lunarMonth: 8,
        lunarDay: 15,
        regionCode: code,
        colorHex: '#5C6BC0',
      ),
      LunarHoliday(
        id: '$code-dragon-boat',
        name: 'Tết Đoan Ngọ',
        lunarMonth: 5,
        lunarDay: 5,
        regionCode: code,
        colorHex: '#43A047',
      ),
    ];
  }
}

LunarHolidayRepository createDefaultLunarHolidayRepository() {
  return FirebaseLunarHolidayRepository();
}
