import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class AdPersistedState {
  const AdPersistedState({
    required this.firstSeenAt,
    required this.totalSessions,
    required this.recentSessionStarts,
    required this.recentShortSessions,
    required this.recentAdFrustrationSignals,
    required this.interstitialShows,
    required this.premiumIntentSignals,
    this.lastSessionEndedAt,
    this.sessionOpenMarkerAt,
    this.lastFullscreenShownAt,
    this.lastInterstitialShownAt,
    this.lastAdDismissedAt,
    this.lastAdFormat,
    this.lastAdPlacement,
  });

  factory AdPersistedState.initial(DateTime now) {
    return AdPersistedState(
      firstSeenAt: now,
      totalSessions: 0,
      recentSessionStarts: const <DateTime>[],
      recentShortSessions: const <DateTime>[],
      recentAdFrustrationSignals: const <DateTime>[],
      interstitialShows: const <DateTime>[],
      premiumIntentSignals: const <DateTime>[],
    );
  }

  factory AdPersistedState.fromJson(Map<String, dynamic> json) {
    return AdPersistedState(
      firstSeenAt: _dateFromEpochValue(json['first_seen_at']) ?? DateTime.now(),
      totalSessions: _intValue(json['total_sessions']),
      recentSessionStarts: _dateListFromDynamic(json['recent_session_starts']),
      recentShortSessions: _dateListFromDynamic(json['recent_short_sessions']),
      recentAdFrustrationSignals: _dateListFromDynamic(
        json['recent_ad_frustration_signals'],
      ),
      interstitialShows: _dateListFromDynamic(json['interstitial_shows']),
      premiumIntentSignals: _dateListFromDynamic(
        json['premium_intent_signals'],
      ),
      lastSessionEndedAt: _dateFromEpochValue(json['last_session_ended_at']),
      sessionOpenMarkerAt: _dateFromEpochValue(json['session_open_marker_at']),
      lastFullscreenShownAt: _dateFromEpochValue(
        json['last_fullscreen_shown_at'],
      ),
      lastInterstitialShownAt: _dateFromEpochValue(
        json['last_interstitial_shown_at'],
      ),
      lastAdDismissedAt: _dateFromEpochValue(json['last_ad_dismissed_at']),
      lastAdFormat: _stringValue(json['last_ad_format']),
      lastAdPlacement: _stringValue(json['last_ad_placement']),
    );
  }

  final DateTime firstSeenAt;
  final int totalSessions;
  final List<DateTime> recentSessionStarts;
  final List<DateTime> recentShortSessions;
  final List<DateTime> recentAdFrustrationSignals;
  final List<DateTime> interstitialShows;
  final List<DateTime> premiumIntentSignals;
  final DateTime? lastSessionEndedAt;
  final DateTime? sessionOpenMarkerAt;
  final DateTime? lastFullscreenShownAt;
  final DateTime? lastInterstitialShownAt;
  final DateTime? lastAdDismissedAt;
  final String? lastAdFormat;
  final String? lastAdPlacement;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'first_seen_at': firstSeenAt.millisecondsSinceEpoch,
      'total_sessions': totalSessions,
      'recent_session_starts': _epochList(recentSessionStarts),
      'recent_short_sessions': _epochList(recentShortSessions),
      'recent_ad_frustration_signals': _epochList(recentAdFrustrationSignals),
      'interstitial_shows': _epochList(interstitialShows),
      'premium_intent_signals': _epochList(premiumIntentSignals),
      'last_session_ended_at': lastSessionEndedAt?.millisecondsSinceEpoch,
      'session_open_marker_at': sessionOpenMarkerAt?.millisecondsSinceEpoch,
      'last_fullscreen_shown_at': lastFullscreenShownAt?.millisecondsSinceEpoch,
      'last_interstitial_shown_at':
          lastInterstitialShownAt?.millisecondsSinceEpoch,
      'last_ad_dismissed_at': lastAdDismissedAt?.millisecondsSinceEpoch,
      'last_ad_format': lastAdFormat,
      'last_ad_placement': lastAdPlacement,
    };
  }

  AdPersistedState copyWith({
    DateTime? firstSeenAt,
    int? totalSessions,
    List<DateTime>? recentSessionStarts,
    List<DateTime>? recentShortSessions,
    List<DateTime>? recentAdFrustrationSignals,
    List<DateTime>? interstitialShows,
    List<DateTime>? premiumIntentSignals,
    DateTime? lastSessionEndedAt,
    bool clearLastSessionEndedAt = false,
    DateTime? sessionOpenMarkerAt,
    bool clearSessionOpenMarkerAt = false,
    DateTime? lastFullscreenShownAt,
    bool clearLastFullscreenShownAt = false,
    DateTime? lastInterstitialShownAt,
    bool clearLastInterstitialShownAt = false,
    DateTime? lastAdDismissedAt,
    bool clearLastAdDismissedAt = false,
    String? lastAdFormat,
    bool clearLastAdFormat = false,
    String? lastAdPlacement,
    bool clearLastAdPlacement = false,
  }) {
    return AdPersistedState(
      firstSeenAt: firstSeenAt ?? this.firstSeenAt,
      totalSessions: totalSessions ?? this.totalSessions,
      recentSessionStarts: recentSessionStarts ?? this.recentSessionStarts,
      recentShortSessions: recentShortSessions ?? this.recentShortSessions,
      recentAdFrustrationSignals:
          recentAdFrustrationSignals ?? this.recentAdFrustrationSignals,
      interstitialShows: interstitialShows ?? this.interstitialShows,
      premiumIntentSignals: premiumIntentSignals ?? this.premiumIntentSignals,
      lastSessionEndedAt: clearLastSessionEndedAt
          ? null
          : (lastSessionEndedAt ?? this.lastSessionEndedAt),
      sessionOpenMarkerAt: clearSessionOpenMarkerAt
          ? null
          : (sessionOpenMarkerAt ?? this.sessionOpenMarkerAt),
      lastFullscreenShownAt: clearLastFullscreenShownAt
          ? null
          : (lastFullscreenShownAt ?? this.lastFullscreenShownAt),
      lastInterstitialShownAt: clearLastInterstitialShownAt
          ? null
          : (lastInterstitialShownAt ?? this.lastInterstitialShownAt),
      lastAdDismissedAt: clearLastAdDismissedAt
          ? null
          : (lastAdDismissedAt ?? this.lastAdDismissedAt),
      lastAdFormat: clearLastAdFormat
          ? null
          : (lastAdFormat ?? this.lastAdFormat),
      lastAdPlacement: clearLastAdPlacement
          ? null
          : (lastAdPlacement ?? this.lastAdPlacement),
    );
  }

  AdPersistedState prune(DateTime now) {
    return copyWith(
      recentSessionStarts: _retainRecent(
        recentSessionStarts,
        now: now,
        maxAge: const Duration(days: 30),
      ),
      recentShortSessions: _retainRecent(
        recentShortSessions,
        now: now,
        maxAge: const Duration(days: 7),
      ),
      recentAdFrustrationSignals: _retainRecent(
        recentAdFrustrationSignals,
        now: now,
        maxAge: const Duration(days: 7),
      ),
      interstitialShows: _retainRecent(
        interstitialShows,
        now: now,
        maxAge: const Duration(days: 7),
      ),
      premiumIntentSignals: _retainRecent(
        premiumIntentSignals,
        now: now,
        maxAge: const Duration(days: 7),
      ),
    );
  }

  static List<int> _epochList(List<DateTime> values) {
    return values.map((value) => value.millisecondsSinceEpoch).toList();
  }

  static List<DateTime> _dateListFromDynamic(Object? value) {
    if (value is! List) {
      return const <DateTime>[];
    }
    return value
        .map((entry) => _dateFromEpochValue(entry))
        .whereType<DateTime>()
        .toList(growable: false);
  }

  static DateTime? _dateFromEpochValue(Object? value) {
    final intValue = _intValueNullable(value);
    if (intValue == null || intValue <= 0) {
      return null;
    }
    return DateTime.fromMillisecondsSinceEpoch(intValue);
  }

  static int _intValue(Object? value) => _intValueNullable(value) ?? 0;

  static int? _intValueNullable(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse('$value');
  }

  static String? _stringValue(Object? value) {
    final normalized = '$value'.trim();
    if (normalized.isEmpty || normalized == 'null') {
      return null;
    }
    return normalized;
  }
}

List<DateTime> _retainRecent(
  List<DateTime> values, {
  required DateTime now,
  required Duration maxAge,
}) {
  return values
      .where((value) => now.difference(value) <= maxAge)
      .toList(growable: false);
}

abstract class AdPersistenceStore {
  Future<AdPersistedState> load(DateTime now);
  Future<void> save(AdPersistedState state);
}

class SharedPrefsAdPersistenceStore implements AdPersistenceStore {
  static const _prefsKey = 'befam_ads_persistence_v1';

  SharedPrefsAdPersistenceStore({SharedPreferences? preferences})
    : _preferencesFuture = preferences != null
          ? Future<SharedPreferences>.value(preferences)
          : SharedPreferences.getInstance();

  final Future<SharedPreferences> _preferencesFuture;

  @override
  Future<AdPersistedState> load(DateTime now) async {
    final prefs = await _preferencesFuture;
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.trim().isEmpty) {
      final initial = AdPersistedState.initial(now);
      await save(initial);
      return initial;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return AdPersistedState.fromJson(decoded).prune(now);
      }
      if (decoded is Map) {
        return AdPersistedState.fromJson(
          decoded.map((key, value) => MapEntry(key.toString(), value)),
        ).prune(now);
      }
    } catch (_) {
      // Fall through to reset corrupted state below.
    }

    final reset = AdPersistedState.initial(now);
    await save(reset);
    return reset;
  }

  @override
  Future<void> save(AdPersistedState state) async {
    final prefs = await _preferencesFuture;
    await prefs.setString(_prefsKey, jsonEncode(state.toJson()));
  }
}
