enum CalendarRegion {
  vietnam,
  china,
  korea;

  String get code {
    return switch (this) {
      CalendarRegion.vietnam => 'VN',
      CalendarRegion.china => 'CN',
      CalendarRegion.korea => 'KR',
    };
  }

  String get label {
    return switch (this) {
      CalendarRegion.vietnam => 'Vietnam',
      CalendarRegion.china => 'China',
      CalendarRegion.korea => 'Korea',
    };
  }

  double get timezoneOffsetHours {
    return switch (this) {
      CalendarRegion.vietnam => 7.0,
      CalendarRegion.china => 8.0,
      CalendarRegion.korea => 9.0,
    };
  }

  static CalendarRegion fromCode(String? code) {
    return switch (code?.trim().toUpperCase()) {
      'CN' => CalendarRegion.china,
      'KR' => CalendarRegion.korea,
      _ => CalendarRegion.vietnam,
    };
  }
}
