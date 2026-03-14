enum LunarRecurrencePolicy {
  keepLunarMonth,
  shiftToPreviousMonth,
  shiftToNextMonth,
  skipYear;

  String get wireName {
    return switch (this) {
      LunarRecurrencePolicy.keepLunarMonth => 'keep_lunar_month',
      LunarRecurrencePolicy.shiftToPreviousMonth => 'shift_prev_month',
      LunarRecurrencePolicy.shiftToNextMonth => 'shift_next_month',
      LunarRecurrencePolicy.skipYear => 'skip_year',
    };
  }

  String get label {
    return switch (this) {
      LunarRecurrencePolicy.keepLunarMonth => 'Keep lunar month',
      LunarRecurrencePolicy.shiftToPreviousMonth => 'Shift to previous month',
      LunarRecurrencePolicy.shiftToNextMonth => 'Shift to next month',
      LunarRecurrencePolicy.skipYear => 'Skip year when invalid',
    };
  }

  static LunarRecurrencePolicy fromWireName(String? wireName) {
    return switch (wireName?.trim().toLowerCase()) {
      'shift_prev_month' => LunarRecurrencePolicy.shiftToPreviousMonth,
      'shift_next_month' => LunarRecurrencePolicy.shiftToNextMonth,
      'skip_year' => LunarRecurrencePolicy.skipYear,
      _ => LunarRecurrencePolicy.keepLunarMonth,
    };
  }
}
