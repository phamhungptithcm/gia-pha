class LunarDate {
  const LunarDate({
    required this.year,
    required this.month,
    required this.day,
    this.isLeapMonth = false,
  });

  final int year;
  final int month;
  final int day;
  final bool isLeapMonth;

  LunarDate copyWith({int? year, int? month, int? day, bool? isLeapMonth}) {
    return LunarDate(
      year: year ?? this.year,
      month: month ?? this.month,
      day: day ?? this.day,
      isLeapMonth: isLeapMonth ?? this.isLeapMonth,
    );
  }

  String get compactKey {
    return '${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
  }

  String get displayLabel {
    final prefix = isLeapMonth ? 'Leap ' : '';
    return '$prefix$day/$month';
  }

  Map<String, dynamic> toJson() {
    return {
      'year': year,
      'month': month,
      'day': day,
      'isLeapMonth': isLeapMonth,
    };
  }

  factory LunarDate.fromJson(Map<String, dynamic> json) {
    return LunarDate(
      year: json['year'] as int? ?? 0,
      month: json['month'] as int? ?? 1,
      day: json['day'] as int? ?? 1,
      isLeapMonth: json['isLeapMonth'] as bool? ?? false,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is LunarDate &&
        other.year == year &&
        other.month == month &&
        other.day == day &&
        other.isLeapMonth == isLeapMonth;
  }

  @override
  int get hashCode => Object.hash(year, month, day, isLeapMonth);
}
