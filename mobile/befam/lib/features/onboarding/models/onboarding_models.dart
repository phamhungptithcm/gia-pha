import 'package:flutter/foundation.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../l10n/l10n.dart';

enum OnboardingTooltipPlacement { auto, above, below }

enum OnboardingFlowStatus {
  notStarted,
  inProgress,
  completed,
  skipped,
  interrupted,
}

@immutable
class OnboardingTrigger {
  const OnboardingTrigger({
    required this.id,
    required this.routeId,
    this.metadata = const <String, Object?>{},
  });

  final String id;
  final String routeId;
  final Map<String, Object?> metadata;
}

@immutable
class OnboardingLocalizedText {
  const OnboardingLocalizedText({required this.vi, required this.en});

  final String vi;
  final String en;

  factory OnboardingLocalizedText.fromJson(
    dynamic raw, {
    required OnboardingLocalizedText fallback,
  }) {
    if (raw is String) {
      final text = raw.trim();
      if (text.isNotEmpty) {
        return OnboardingLocalizedText(vi: text, en: text);
      }
      return fallback;
    }
    if (raw is Map<Object?, Object?>) {
      final vi = (raw['vi'] as String?)?.trim() ?? fallback.vi;
      final en = (raw['en'] as String?)?.trim() ?? fallback.en;
      return OnboardingLocalizedText(vi: vi, en: en);
    }
    return fallback;
  }

  String resolve(AppLocalizations l10n) {
    return l10n.pick(vi: vi, en: en);
  }

  Map<String, String> toJson() => <String, String>{'vi': vi, 'en': en};
}

@immutable
class OnboardingStep {
  const OnboardingStep({
    required this.id,
    required this.anchorId,
    required this.title,
    required this.body,
    this.placement = OnboardingTooltipPlacement.auto,
    this.barrierDismissible = false,
  });

  final String id;
  final String anchorId;
  final OnboardingLocalizedText title;
  final OnboardingLocalizedText body;
  final OnboardingTooltipPlacement placement;
  final bool barrierDismissible;

  factory OnboardingStep.fromJson(Map<String, dynamic> json) {
    const fallbackTitle = OnboardingLocalizedText(vi: '', en: '');
    return OnboardingStep(
      id: (json['id'] as String?)?.trim() ?? '',
      anchorId: (json['anchorId'] as String?)?.trim() ?? '',
      title: OnboardingLocalizedText.fromJson(
        json['title'],
        fallback: fallbackTitle,
      ),
      body: OnboardingLocalizedText.fromJson(
        json['body'],
        fallback: fallbackTitle,
      ),
      placement: _placementFromRaw(json['placement']),
      barrierDismissible: json['barrierDismissible'] == true,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'anchorId': anchorId,
    'title': title.toJson(),
    'body': body.toJson(),
    'placement': placement.name,
    'barrierDismissible': barrierDismissible,
  };

  static OnboardingTooltipPlacement _placementFromRaw(dynamic raw) {
    final normalized = (raw as String?)?.trim().toLowerCase() ?? '';
    return switch (normalized) {
      'above' => OnboardingTooltipPlacement.above,
      'below' => OnboardingTooltipPlacement.below,
      _ => OnboardingTooltipPlacement.auto,
    };
  }
}

@immutable
class OnboardingFlow {
  const OnboardingFlow({
    required this.id,
    required this.triggerId,
    required this.version,
    required this.steps,
    this.priority = 100,
    this.enabled = true,
    this.maxDisplays = 1,
    this.cooldown = const Duration(hours: 24),
    this.resumeTtl = const Duration(hours: 72),
    this.platforms = const <String>{'android', 'ios', 'web'},
  });

  final String id;
  final String triggerId;
  final int version;
  final int priority;
  final bool enabled;
  final int maxDisplays;
  final Duration cooldown;
  final Duration resumeTtl;
  final Set<String> platforms;
  final List<OnboardingStep> steps;

  factory OnboardingFlow.fromJson(Map<String, dynamic> json) {
    final rawSteps = (json['steps'] as List<Object?>?) ?? const <Object?>[];
    return OnboardingFlow(
      id: (json['id'] as String?)?.trim() ?? '',
      triggerId: (json['triggerId'] as String?)?.trim() ?? '',
      version: _readInt(json['version'], fallback: 1),
      priority: _readInt(json['priority'], fallback: 100),
      enabled: json['enabled'] != false,
      maxDisplays: _readInt(json['maxDisplays'], fallback: 1),
      cooldown: Duration(hours: _readInt(json['cooldownHours'], fallback: 24)),
      resumeTtl: Duration(
        hours: _readInt(json['resumeTtlHours'], fallback: 72),
      ),
      platforms: _readPlatforms(json['platforms']),
      steps: rawSteps
          .whereType<Map<Object?, Object?>>()
          .map(
            (raw) => OnboardingStep.fromJson(
              raw.map((key, value) => MapEntry(key.toString(), value)),
            ),
          )
          .where((step) => step.id.isNotEmpty && step.anchorId.isNotEmpty)
          .toList(growable: false),
    );
  }

  bool supportsCurrentPlatform() {
    final platformId = defaultTargetPlatform == TargetPlatform.iOS
        ? 'ios'
        : defaultTargetPlatform == TargetPlatform.android
        ? 'android'
        : kIsWeb
        ? 'web'
        : defaultTargetPlatform.name.toLowerCase();
    return platforms.contains(platformId);
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'triggerId': triggerId,
    'version': version,
    'priority': priority,
    'enabled': enabled,
    'maxDisplays': maxDisplays,
    'cooldownHours': cooldown.inHours,
    'resumeTtlHours': resumeTtl.inHours,
    'platforms': platforms.toList(growable: false),
    'steps': steps.map((step) => step.toJson()).toList(growable: false),
  };

  static int _readInt(dynamic raw, {required int fallback}) {
    if (raw is int) {
      return raw;
    }
    if (raw is num) {
      return raw.toInt();
    }
    return int.tryParse(raw?.toString() ?? '') ?? fallback;
  }

  static Set<String> _readPlatforms(dynamic raw) {
    if (raw is! List<Object?>) {
      return const <String>{'android', 'ios', 'web'};
    }
    final values = raw
        .map((entry) => entry?.toString().trim().toLowerCase() ?? '')
        .where((entry) => entry.isNotEmpty)
        .toSet();
    return values.isEmpty ? const <String>{'android', 'ios', 'web'} : values;
  }
}

@immutable
class OnboardingFlowProgress {
  const OnboardingFlowProgress({
    required this.flowId,
    required this.version,
    this.status = OnboardingFlowStatus.notStarted,
    this.currentStepIndex = 0,
    this.displayCount = 0,
    this.lastStartedAt,
    this.lastCompletedAt,
    this.lastSkippedAt,
    this.cooldownUntil,
    this.resumeExpiresAt,
    this.updatedAt,
  });

  final String flowId;
  final int version;
  final OnboardingFlowStatus status;
  final int currentStepIndex;
  final int displayCount;
  final DateTime? lastStartedAt;
  final DateTime? lastCompletedAt;
  final DateTime? lastSkippedAt;
  final DateTime? cooldownUntil;
  final DateTime? resumeExpiresAt;
  final DateTime? updatedAt;

  bool get hasActiveCooldown =>
      cooldownUntil != null && cooldownUntil!.isAfter(DateTime.now());

  bool get canResume =>
      (status == OnboardingFlowStatus.inProgress ||
          status == OnboardingFlowStatus.interrupted) &&
      resumeExpiresAt != null &&
      resumeExpiresAt!.isAfter(DateTime.now());

  factory OnboardingFlowProgress.fromJson(
    String flowId,
    Map<String, dynamic> json,
  ) {
    final statusRaw = (json['status'] as String?)?.trim() ?? '';
    return OnboardingFlowProgress(
      flowId: flowId,
      version: OnboardingFlow._readInt(json['version'], fallback: 1),
      status: OnboardingFlowStatus.values.firstWhere(
        (value) => value.name == statusRaw,
        orElse: () => OnboardingFlowStatus.notStarted,
      ),
      currentStepIndex: OnboardingFlow._readInt(
        json['currentStepIndex'],
        fallback: 0,
      ),
      displayCount: OnboardingFlow._readInt(json['displayCount'], fallback: 0),
      lastStartedAt: _readDateTime(json['lastStartedAt']),
      lastCompletedAt: _readDateTime(json['lastCompletedAt']),
      lastSkippedAt: _readDateTime(json['lastSkippedAt']),
      cooldownUntil: _readDateTime(json['cooldownUntil']),
      resumeExpiresAt: _readDateTime(json['resumeExpiresAt']),
      updatedAt: _readDateTime(json['updatedAt']),
    );
  }

  OnboardingFlowProgress copyWith({
    int? version,
    OnboardingFlowStatus? status,
    int? currentStepIndex,
    int? displayCount,
    DateTime? lastStartedAt,
    DateTime? lastCompletedAt,
    DateTime? lastSkippedAt,
    DateTime? cooldownUntil,
    DateTime? resumeExpiresAt,
    DateTime? updatedAt,
    bool clearCooldownUntil = false,
    bool clearResumeExpiresAt = false,
  }) {
    return OnboardingFlowProgress(
      flowId: flowId,
      version: version ?? this.version,
      status: status ?? this.status,
      currentStepIndex: currentStepIndex ?? this.currentStepIndex,
      displayCount: displayCount ?? this.displayCount,
      lastStartedAt: lastStartedAt ?? this.lastStartedAt,
      lastCompletedAt: lastCompletedAt ?? this.lastCompletedAt,
      lastSkippedAt: lastSkippedAt ?? this.lastSkippedAt,
      cooldownUntil: clearCooldownUntil
          ? null
          : cooldownUntil ?? this.cooldownUntil,
      resumeExpiresAt: clearResumeExpiresAt
          ? null
          : resumeExpiresAt ?? this.resumeExpiresAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'flowId': flowId,
    'version': version,
    'status': status.name,
    'currentStepIndex': currentStepIndex,
    'displayCount': displayCount,
    'lastStartedAt': lastStartedAt,
    'lastCompletedAt': lastCompletedAt,
    'lastSkippedAt': lastSkippedAt,
    'cooldownUntil': cooldownUntil,
    'resumeExpiresAt': resumeExpiresAt,
    'updatedAt': updatedAt,
  };

  static DateTime? _readDateTime(dynamic raw) {
    if (raw == null) {
      return null;
    }
    if (raw is DateTime) {
      return raw;
    }
    if (raw is int) {
      return DateTime.fromMillisecondsSinceEpoch(raw);
    }
    final milliseconds = raw.millisecondsSinceEpoch;
    if (milliseconds is int) {
      return DateTime.fromMillisecondsSinceEpoch(milliseconds);
    }
    return DateTime.tryParse(raw.toString());
  }
}

@immutable
class OnboardingUserState {
  const OnboardingUserState({
    this.flows = const <String, OnboardingFlowProgress>{},
  });

  final Map<String, OnboardingFlowProgress> flows;

  OnboardingFlowProgress? progressFor(String flowId) => flows[flowId];

  OnboardingUserState copyWithFlow(OnboardingFlowProgress progress) {
    return OnboardingUserState(
      flows: <String, OnboardingFlowProgress>{
        ...flows,
        progress.flowId: progress,
      },
    );
  }
}
