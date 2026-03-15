import '../../member/models/member_profile.dart';

enum EventNotificationAudienceMode {
  clanAll('clan_all'),
  branchAll('branch_all'),
  named('named');

  const EventNotificationAudienceMode(this.wireName);

  final String wireName;

  static EventNotificationAudienceMode fromWireName(String? value) {
    final normalized = (value ?? '').trim().toLowerCase();
    for (final mode in EventNotificationAudienceMode.values) {
      if (mode.wireName == normalized) {
        return mode;
      }
    }
    return EventNotificationAudienceMode.clanAll;
  }
}

enum EventNotificationAudienceExcludeRule {
  female('exclude_female'),
  nonLeaderOrVice('exclude_non_leader_or_vice'),
  // Legacy rules kept for backward compatibility with older saved events.
  eldestSon('exclude_eldest_son'),
  youngestSon('exclude_youngest_son');

  const EventNotificationAudienceExcludeRule(this.wireName);

  final String wireName;

  static EventNotificationAudienceExcludeRule? tryParse(String value) {
    final normalized = value.trim().toLowerCase();
    for (final rule in EventNotificationAudienceExcludeRule.values) {
      if (rule.wireName == normalized) {
        return rule;
      }
    }
    return null;
  }
}

class EventNotificationAudience {
  const EventNotificationAudience({
    this.mode = EventNotificationAudienceMode.clanAll,
    this.branchId,
    this.includeMemberIds = const [],
    this.excludeMemberIds = const [],
    this.excludeRules = const [],
  });

  final EventNotificationAudienceMode mode;
  final String? branchId;
  final List<String> includeMemberIds;
  final List<String> excludeMemberIds;
  final List<EventNotificationAudienceExcludeRule> excludeRules;

  EventNotificationAudience copyWith({
    EventNotificationAudienceMode? mode,
    String? branchId,
    bool clearBranchId = false,
    List<String>? includeMemberIds,
    List<String>? excludeMemberIds,
    List<EventNotificationAudienceExcludeRule>? excludeRules,
  }) {
    return EventNotificationAudience(
      mode: mode ?? this.mode,
      branchId: clearBranchId ? null : (branchId ?? this.branchId),
      includeMemberIds: includeMemberIds ?? this.includeMemberIds,
      excludeMemberIds: excludeMemberIds ?? this.excludeMemberIds,
      excludeRules: excludeRules ?? this.excludeRules,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'mode': mode.wireName,
      'branchId': branchId,
      'includeMemberIds': includeMemberIds,
      'excludeMemberIds': excludeMemberIds,
      'excludeRules': excludeRules.map((entry) => entry.wireName).toList(),
    };
  }

  factory EventNotificationAudience.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const EventNotificationAudience();
    }
    final includeIds = _stringList(json['includeMemberIds']);
    final excludeIds = _stringList(json['excludeMemberIds']);
    final rules = _stringList(json['excludeRules'])
        .map(EventNotificationAudienceExcludeRule.tryParse)
        .whereType<EventNotificationAudienceExcludeRule>()
        .toSet()
        .toList(growable: false);
    final rawBranch = json['branchId'];
    final branchId = rawBranch is String && rawBranch.trim().isNotEmpty
        ? rawBranch.trim()
        : null;

    return EventNotificationAudience(
      mode: EventNotificationAudienceMode.fromWireName(json['mode'] as String?),
      branchId: branchId,
      includeMemberIds: includeIds,
      excludeMemberIds: excludeIds,
      excludeRules: rules,
    );
  }

  List<MemberProfile> resolveRecipients({
    required List<MemberProfile> members,
    required List<MemberProfile> fallbackMembers,
  }) {
    final universe = members.isNotEmpty ? members : fallbackMembers;
    if (universe.isEmpty) {
      return const [];
    }

    final byId = {for (final member in universe) member.id: member};
    final selectedIds = <String>{};
    final excludedIds = <String>{};

    switch (mode) {
      case EventNotificationAudienceMode.clanAll:
        selectedIds.addAll(byId.keys);
      case EventNotificationAudienceMode.branchAll:
        final targetBranch = (branchId ?? '').trim();
        if (targetBranch.isNotEmpty) {
          selectedIds.addAll(
            universe
                .where((member) => member.branchId.trim() == targetBranch)
                .map((member) => member.id),
          );
        }
      case EventNotificationAudienceMode.named:
        selectedIds.addAll(
          includeMemberIds
              .map((entry) => entry.trim())
              .where((entry) => entry.isNotEmpty),
        );
    }

    if (mode != EventNotificationAudienceMode.named) {
      excludedIds.addAll(
        excludeMemberIds
            .map((entry) => entry.trim())
            .where((entry) => entry.isNotEmpty),
      );
      if (excludeRules.contains(EventNotificationAudienceExcludeRule.female)) {
        excludedIds.addAll(
          universe
              .where((member) => selectedIds.contains(member.id))
              .where((member) => _isFemale(member.gender))
              .map((member) => member.id),
        );
      }
      if (excludeRules.contains(
        EventNotificationAudienceExcludeRule.nonLeaderOrVice,
      )) {
        excludedIds.addAll(
          universe
              .where((member) => selectedIds.contains(member.id))
              .where((member) => !_isLeaderOrVice(member.primaryRole))
              .map((member) => member.id),
        );
      }
      if (excludeRules.contains(
        EventNotificationAudienceExcludeRule.eldestSon,
      )) {
        excludedIds.addAll(
          _resolveSpecialRuleMemberIds(
            universe: universe,
            rule: EventNotificationAudienceExcludeRule.eldestSon,
            withinIds: selectedIds,
          ),
        );
      }
      if (excludeRules.contains(
        EventNotificationAudienceExcludeRule.youngestSon,
      )) {
        excludedIds.addAll(
          _resolveSpecialRuleMemberIds(
            universe: universe,
            rule: EventNotificationAudienceExcludeRule.youngestSon,
            withinIds: selectedIds,
          ),
        );
      }
      selectedIds.removeAll(excludedIds);
    }

    final resolvedIds = <String>{};
    for (final memberId in selectedIds) {
      final member = byId[memberId];
      if (member == null) {
        continue;
      }
      if (_isMemberAlive(member)) {
        resolvedIds.add(member.id);
        continue;
      }

      final successor = _resolveNextAliveSon(
        universe: universe,
        deceasedMember: member,
        excludedIds: excludedIds,
      );
      if (successor != null) {
        resolvedIds.add(successor.id);
      }
    }

    return resolvedIds
        .map((id) => byId[id])
        .whereType<MemberProfile>()
        .toList(growable: false)
      ..sort((left, right) => left.fullName.compareTo(right.fullName));
  }
}

List<String> _stringList(Object? value) {
  if (value is! List) {
    return const [];
  }
  return value
      .whereType<String>()
      .map((entry) => entry.trim())
      .where((entry) => entry.isNotEmpty)
      .toSet()
      .toList(growable: false);
}

Set<String> _resolveSpecialRuleMemberIds({
  required List<MemberProfile> universe,
  required EventNotificationAudienceExcludeRule rule,
  required Set<String> withinIds,
}) {
  final groups = <String, List<MemberProfile>>{};
  for (final member in universe) {
    if (!withinIds.contains(member.id)) {
      continue;
    }
    if (!_isMemberAlive(member)) {
      continue;
    }
    if (!_isMale(member.gender)) {
      continue;
    }
    if (member.parentIds.isEmpty) {
      continue;
    }
    final parentKey = [...member.parentIds]..sort();
    groups
        .putIfAbsent(parentKey.join('|'), () => <MemberProfile>[])
        .add(member);
  }

  final resolved = <String>{};
  for (final siblings in groups.values) {
    if (siblings.isEmpty) {
      continue;
    }
    siblings.sort(_compareByBirthThenName);
    final selected = rule == EventNotificationAudienceExcludeRule.eldestSon
        ? siblings.first
        : siblings.last;
    resolved.add(selected.id);
  }
  return resolved;
}

MemberProfile? _resolveNextAliveSon({
  required List<MemberProfile> universe,
  required MemberProfile deceasedMember,
  required Set<String> excludedIds,
}) {
  if (!_isMale(deceasedMember.gender) || deceasedMember.parentIds.isEmpty) {
    return null;
  }

  final siblings = <MemberProfile>[];
  final parentKey = _normalizedParentKey(deceasedMember.parentIds);
  for (final member in universe) {
    if (!_isMale(member.gender)) {
      continue;
    }
    if (_normalizedParentKey(member.parentIds) != parentKey) {
      continue;
    }
    siblings.add(member);
  }
  if (siblings.isEmpty) {
    return null;
  }

  siblings.sort(_compareByBirthThenName);
  final currentIndex = siblings.indexWhere(
    (entry) => entry.id == deceasedMember.id,
  );
  if (currentIndex < 0) {
    return null;
  }

  for (var i = currentIndex + 1; i < siblings.length; i++) {
    final candidate = siblings[i];
    if (_isMemberAlive(candidate) && !excludedIds.contains(candidate.id)) {
      return candidate;
    }
  }

  for (var i = currentIndex - 1; i >= 0; i--) {
    final candidate = siblings[i];
    if (_isMemberAlive(candidate) && !excludedIds.contains(candidate.id)) {
      return candidate;
    }
  }
  return null;
}

bool _isMale(String? value) {
  final normalized = (value ?? '').trim().toLowerCase();
  return normalized == 'male' ||
      normalized == 'm' ||
      normalized == 'nam' ||
      normalized == 'con trai';
}

bool _isFemale(String? value) {
  final normalized = (value ?? '').trim().toLowerCase();
  return normalized == 'female' ||
      normalized == 'f' ||
      normalized == 'nu' ||
      normalized == 'nữ' ||
      normalized == 'con gái';
}

bool _isLeaderOrVice(String? role) {
  final normalized = (role ?? '').trim().toUpperCase();
  if (normalized.isEmpty) {
    return false;
  }
  return const <String>{
    'SUPER_ADMIN',
    'CLAN_ADMIN',
    'CLAN_OWNER',
    'CLAN_LEADER',
    'BRANCH_ADMIN',
    'VICE_LEADER',
  }.contains(normalized);
}

bool _isMemberAlive(MemberProfile member) {
  final deathDate = member.deathDate?.trim() ?? '';
  if (deathDate.isNotEmpty) {
    return false;
  }
  final normalizedStatus = member.status.trim().toLowerCase();
  return normalizedStatus != 'deceased' && normalizedStatus != 'dead';
}

String _normalizedParentKey(List<String> parentIds) {
  if (parentIds.isEmpty) {
    return '';
  }
  final key =
      parentIds
          .map((entry) => entry.trim())
          .where((entry) => entry.isNotEmpty)
          .toList(growable: false)
        ..sort();
  return key.join('|');
}

int _compareByBirthThenName(MemberProfile left, MemberProfile right) {
  final leftBirth = _parseBirthDate(left.birthDate);
  final rightBirth = _parseBirthDate(right.birthDate);
  if (leftBirth != null && rightBirth != null) {
    final byBirth = leftBirth.compareTo(rightBirth);
    if (byBirth != 0) {
      return byBirth;
    }
  } else if (leftBirth != null) {
    return -1;
  } else if (rightBirth != null) {
    return 1;
  }

  final byGeneration = left.generation.compareTo(right.generation);
  if (byGeneration != 0) {
    return byGeneration;
  }
  return left.fullName.toLowerCase().compareTo(right.fullName.toLowerCase());
}

DateTime? _parseBirthDate(String? value) {
  final trimmed = value?.trim() ?? '';
  if (trimmed.isEmpty) {
    return null;
  }
  return DateTime.tryParse(trimmed);
}
