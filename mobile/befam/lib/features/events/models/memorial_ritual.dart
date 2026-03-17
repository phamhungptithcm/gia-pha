enum MemorialRitualPreset { genderSplit4950, unified49 }

const MemorialRitualPreset kDefaultMemorialRitualPreset =
    MemorialRitualPreset.genderSplit4950;

String memorialRitualPresetCode(MemorialRitualPreset preset) {
  return switch (preset) {
    MemorialRitualPreset.genderSplit4950 => 'gender_split_49_50',
    MemorialRitualPreset.unified49 => 'unified_49',
  };
}

enum MemorialRitualMilestoneType {
  first49Days,
  first50Days,
  day100,
  year1,
  year2,
}

class MemorialRitualMilestone {
  const MemorialRitualMilestone({
    required this.type,
    required this.key,
    required this.expectedAt,
  });

  final MemorialRitualMilestoneType type;
  final String key;
  final DateTime expectedAt;
}

List<MemorialRitualMilestone> buildMemorialRitualMilestones({
  required DateTime deathDate,
  String? gender,
  MemorialRitualPreset preset = kDefaultMemorialRitualPreset,
}) {
  final normalizedDeathDate = _atNineAm(
    year: deathDate.year,
    month: deathDate.month,
    day: deathDate.day,
  );

  final firstMilestoneDays = switch (preset) {
    MemorialRitualPreset.unified49 => 49,
    MemorialRitualPreset.genderSplit4950 => _isMaleGender(gender) ? 50 : 49,
  };

  final firstMilestoneType = firstMilestoneDays == 50
      ? MemorialRitualMilestoneType.first50Days
      : MemorialRitualMilestoneType.first49Days;
  final firstMilestoneKey = firstMilestoneDays == 50
      ? 'first_50_days'
      : 'first_49_days';

  return [
    MemorialRitualMilestone(
      type: firstMilestoneType,
      key: firstMilestoneKey,
      expectedAt: normalizedDeathDate.add(Duration(days: firstMilestoneDays)),
    ),
    MemorialRitualMilestone(
      type: MemorialRitualMilestoneType.day100,
      key: 'day_100',
      expectedAt: normalizedDeathDate.add(const Duration(days: 100)),
    ),
    MemorialRitualMilestone(
      type: MemorialRitualMilestoneType.year1,
      key: 'year_1',
      expectedAt: _safeLocalDate(
        year: normalizedDeathDate.year + 1,
        month: normalizedDeathDate.month,
        day: normalizedDeathDate.day,
        hour: 9,
      ),
    ),
    MemorialRitualMilestone(
      type: MemorialRitualMilestoneType.year2,
      key: 'year_2',
      expectedAt: _safeLocalDate(
        year: normalizedDeathDate.year + 2,
        month: normalizedDeathDate.month,
        day: normalizedDeathDate.day,
        hour: 9,
      ),
    ),
  ];
}

bool _isMaleGender(String? gender) {
  final normalized = (gender ?? '').trim().toLowerCase();
  if (normalized.isEmpty) {
    return false;
  }
  return normalized == 'male' || normalized == 'm' || normalized == 'nam';
}

DateTime _atNineAm({required int year, required int month, required int day}) {
  return _safeLocalDate(year: year, month: month, day: day, hour: 9);
}

DateTime _safeLocalDate({
  required int year,
  required int month,
  required int day,
  int hour = 0,
  int minute = 0,
}) {
  final value = DateTime(year, month, day, hour, minute);
  if (value.month == month && value.day == day) {
    return value;
  }
  return DateTime(year, month + 1, 0, hour, minute);
}
