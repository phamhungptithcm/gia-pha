enum CalendarDateMode {
  solar,
  lunar;

  String get label {
    return switch (this) {
      CalendarDateMode.solar => 'Solar date',
      CalendarDateMode.lunar => 'Lunar date',
    };
  }
}
