enum CalendarDisplayMode {
  dual,
  solarOnly,
  lunarOnly;

  String get wireName {
    return switch (this) {
      CalendarDisplayMode.dual => 'dual',
      CalendarDisplayMode.solarOnly => 'solar',
      CalendarDisplayMode.lunarOnly => 'lunar',
    };
  }

  String get label {
    return switch (this) {
      CalendarDisplayMode.dual => 'Dual',
      CalendarDisplayMode.solarOnly => 'Solar only',
      CalendarDisplayMode.lunarOnly => 'Lunar only',
    };
  }

  static CalendarDisplayMode fromWireName(String? wireName) {
    return switch (wireName?.trim().toLowerCase()) {
      'solar' => CalendarDisplayMode.solarOnly,
      'lunar' => CalendarDisplayMode.lunarOnly,
      _ => CalendarDisplayMode.dual,
    };
  }
}
