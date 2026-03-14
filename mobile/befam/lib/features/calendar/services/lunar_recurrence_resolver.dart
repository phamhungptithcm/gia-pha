import '../models/calendar_region.dart';
import '../models/dual_calendar_event.dart';
import '../models/lunar_date.dart';
import '../models/lunar_recurrence_policy.dart';
import 'lunar_conversion_engine.dart';
import 'lunar_resolution_cache.dart';

class LunarRecurrenceResolver {
  LunarRecurrenceResolver({
    LunarConversionEngine? conversionEngine,
    LunarResolutionCache? cache,
  }) : _conversionEngine =
           conversionEngine ?? createDefaultLunarConversionEngine(),
       _cache = cache ?? LunarResolutionCache();

  final LunarConversionEngine _conversionEngine;
  final LunarResolutionCache _cache;

  Future<DateTime?> resolveLunarDateForYear({
    required LunarDate lunarDate,
    required int targetYear,
    required CalendarRegion region,
    required LunarRecurrencePolicy policy,
  }) async {
    final cached = await _cache.read(
      region: region,
      lunarDate: lunarDate,
      targetYear: targetYear,
      policy: policy,
    );
    if (cached != null) {
      return DateTime(cached.year, cached.month, cached.day);
    }

    final normalized = lunarDate.copyWith(year: targetYear);

    final nonLeapCandidate = await _conversionEngine.lunarToSolar(
      normalized.copyWith(isLeapMonth: false),
      region: region,
    );
    final leapCandidate = await _conversionEngine.lunarToSolar(
      normalized.copyWith(isLeapMonth: true),
      region: region,
    );

    final resolved = switch (policy) {
      LunarRecurrencePolicy.skip => _resolveSkipPolicy(
        source: normalized,
        nonLeapCandidate: nonLeapCandidate,
        leapCandidate: leapCandidate,
      ),
      LunarRecurrencePolicy.firstOccurrence => nonLeapCandidate,
      LunarRecurrencePolicy.leapOccurrence => _resolveLeapOccurrencePolicy(
        source: normalized,
        nonLeapCandidate: nonLeapCandidate,
        leapCandidate: leapCandidate,
      ),
    };

    await _cache.write(
      region: region,
      lunarDate: lunarDate,
      targetYear: targetYear,
      policy: policy,
      resolvedDate: resolved,
    );
    return resolved;
  }

  DateTime? _resolveSkipPolicy({
    required LunarDate source,
    required DateTime? nonLeapCandidate,
    required DateTime? leapCandidate,
  }) {
    if (source.isLeapMonth) {
      return leapCandidate;
    }
    return nonLeapCandidate;
  }

  DateTime? _resolveLeapOccurrencePolicy({
    required LunarDate source,
    required DateTime? nonLeapCandidate,
    required DateTime? leapCandidate,
  }) {
    if (source.isLeapMonth) {
      return leapCandidate;
    }
    return leapCandidate ?? nonLeapCandidate;
  }

  Future<List<DateTime>> resolveOccurrences({
    required DualCalendarEvent event,
    required CalendarRegion region,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) async {
    final startDate = DateTime(
      rangeStart.year,
      rangeStart.month,
      rangeStart.day,
    );
    final endDate = DateTime(rangeEnd.year, rangeEnd.month, rangeEnd.day);

    if (!event.usesLunarDate || event.lunarDate == null) {
      final solarDate = DateTime(
        event.solarDate.year,
        event.solarDate.month,
        event.solarDate.day,
      );

      if (event.isAnnualRecurring) {
        final values = <DateTime>[];
        for (var year = startDate.year; year <= endDate.year; year++) {
          final occurrence = DateTime(year, solarDate.month, solarDate.day);
          if (!occurrence.isBefore(startDate) && !occurrence.isAfter(endDate)) {
            values.add(occurrence);
          }
        }
        return values;
      }

      if (solarDate.isBefore(startDate) || solarDate.isAfter(endDate)) {
        return const [];
      }
      return [solarDate];
    }

    if (!event.isAnnualRecurring) {
      final occurrence = await resolveLunarDateForYear(
        lunarDate: event.lunarDate!,
        targetYear: event.lunarDate!.year,
        region: region,
        policy: event.recurrencePolicy,
      );
      if (occurrence == null ||
          occurrence.isBefore(startDate) ||
          occurrence.isAfter(endDate)) {
        return const [];
      }
      return [occurrence];
    }

    final occurrences = <DateTime>[];
    final seen = <String>{};
    for (var year = startDate.year - 1; year <= endDate.year + 1; year++) {
      final occurrence = await resolveLunarDateForYear(
        lunarDate: event.lunarDate!,
        targetYear: year,
        region: region,
        policy: event.recurrencePolicy,
      );
      if (occurrence == null) {
        continue;
      }

      if (occurrence.isBefore(startDate) || occurrence.isAfter(endDate)) {
        continue;
      }

      final normalized = DateTime(
        occurrence.year,
        occurrence.month,
        occurrence.day,
      );
      final key =
          '${normalized.year}-${normalized.month.toString().padLeft(2, '0')}-${normalized.day.toString().padLeft(2, '0')}';
      if (seen.add(key)) {
        occurrences.add(normalized);
      }
    }

    occurrences.sort();
    return occurrences;
  }
}
