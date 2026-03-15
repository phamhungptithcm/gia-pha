enum LunarRecurrencePolicy {
  skip,
  firstOccurrence,
  leapOccurrence;

  String get wireName {
    return switch (this) {
      LunarRecurrencePolicy.skip => 'skip',
      LunarRecurrencePolicy.firstOccurrence => 'firstOccurrence',
      LunarRecurrencePolicy.leapOccurrence => 'leapOccurrence',
    };
  }

  String get label {
    return switch (this) {
      LunarRecurrencePolicy.skip => 'Skip year',
      LunarRecurrencePolicy.firstOccurrence => 'First occurrence',
      LunarRecurrencePolicy.leapOccurrence => 'Leap occurrence',
    };
  }

  static LunarRecurrencePolicy fromWireName(String? wireName) {
    return switch (wireName?.trim().toLowerCase()) {
      'skip' || 'skip_year' => LunarRecurrencePolicy.skip,
      'firstoccurrence' ||
      'keep_lunar_month' => LunarRecurrencePolicy.firstOccurrence,
      'leapoccurrence' ||
      'shift_next_month' => LunarRecurrencePolicy.leapOccurrence,
      _ => LunarRecurrencePolicy.firstOccurrence,
    };
  }
}
