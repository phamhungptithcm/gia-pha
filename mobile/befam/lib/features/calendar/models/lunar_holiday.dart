class LunarHoliday {
  const LunarHoliday({
    required this.id,
    required this.name,
    required this.lunarMonth,
    required this.lunarDay,
    required this.regionCode,
    required this.colorHex,
  });

  final String id;
  final String name;
  final int lunarMonth;
  final int lunarDay;
  final String regionCode;
  final String colorHex;

  String get monthDayKey {
    final month = lunarMonth.toString().padLeft(2, '0');
    final day = lunarDay.toString().padLeft(2, '0');
    return '$month-$day';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'lunarMonth': lunarMonth,
      'lunarDay': lunarDay,
      'regionCode': regionCode,
      'colorHex': colorHex,
    };
  }

  factory LunarHoliday.fromJson(Map<String, dynamic> json) {
    return LunarHoliday(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      lunarMonth: json['lunarMonth'] as int? ?? 1,
      lunarDay: json['lunarDay'] as int? ?? 1,
      regionCode: json['regionCode'] as String? ?? 'VN',
      colorHex: json['colorHex'] as String? ?? '#E57373',
    );
  }
}
