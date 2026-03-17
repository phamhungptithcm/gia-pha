import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';

import '../../auth/models/auth_session.dart';
import '../../clan/models/branch_profile.dart';
import '../../member/models/member_profile.dart';
import '../models/event_draft.dart';
import '../models/event_record.dart';
import '../models/event_type.dart';
import '../models/memorial_ritual.dart';
import '../services/event_permissions.dart';
import '../services/event_repository.dart';

class MemorialChecklistItem {
  const MemorialChecklistItem({
    required this.member,
    required this.deathDateRaw,
    required this.deathDate,
    required this.memorialEvents,
    required this.hasAlignedMemorialDate,
  });

  final MemberProfile member;
  final String deathDateRaw;
  final DateTime? deathDate;
  final List<EventRecord> memorialEvents;
  final bool hasAlignedMemorialDate;

  bool get hasMemorialEvent => memorialEvents.isNotEmpty;

  bool get hasDateMismatch =>
      deathDate != null && hasMemorialEvent && !hasAlignedMemorialDate;

  EventRecord? get primaryEvent {
    if (memorialEvents.isEmpty) {
      return null;
    }

    if (deathDate == null) {
      return memorialEvents.first;
    }

    return memorialEvents.firstWhereOrNull(
          (event) => _isSameMonthAndDay(event.startsAt.toLocal(), deathDate!),
        ) ??
        memorialEvents.first;
  }
}

class MemorialRitualChecklistMilestoneItem {
  const MemorialRitualChecklistMilestoneItem({
    required this.milestone,
    required this.expectedDate,
    required this.configuredEvent,
    required this.hasAlignedDate,
  });

  final MemorialRitualMilestone milestone;
  final DateTime expectedDate;
  final EventRecord? configuredEvent;
  final bool hasAlignedDate;

  bool get isConfigured => configuredEvent != null && hasAlignedDate;
  bool get isMissing => configuredEvent == null;
  bool get hasDateMismatch => configuredEvent != null && !hasAlignedDate;
}

class MemorialRitualChecklistItem {
  const MemorialRitualChecklistItem({
    required this.member,
    required this.deathDateRaw,
    required this.deathDate,
    required this.milestones,
  });

  final MemberProfile member;
  final String deathDateRaw;
  final DateTime deathDate;
  final List<MemorialRitualChecklistMilestoneItem> milestones;

  int get configuredCount =>
      milestones.where((milestone) => milestone.isConfigured).length;

  int get missingCount =>
      milestones.where((milestone) => milestone.isMissing).length;

  int get mismatchCount =>
      milestones.where((milestone) => milestone.hasDateMismatch).length;

  bool get hasMissingMilestone => missingCount > 0;
}

class EventController extends ChangeNotifier {
  EventController({
    required EventRepository repository,
    required AuthSession session,
  }) : _repository = repository,
       _session = session,
       permissions = EventPermissions.forSession(session);

  final EventRepository _repository;
  final AuthSession _session;
  final EventPermissions permissions;

  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;
  List<EventRecord> _events = const [];
  List<MemberProfile> _members = const [];
  List<BranchProfile> _branches = const [];
  Map<String, String> _memberNamesById = const {};
  Map<String, String> _branchNamesById = const {};
  String _query = '';
  EventType? _typeFilter;
  List<EventRecord> _filteredEvents = const [];
  int _upcomingCount = 0;
  int _memorialCount = 0;
  List<MemorialChecklistItem> _memorialChecklistItems = const [];
  int _memorialChecklistConfiguredCount = 0;
  int _memorialChecklistMissingCount = 0;
  int _memorialChecklistDateMismatchCount = 0;
  List<MemorialRitualChecklistItem> _memorialRitualChecklistItems = const [];
  int _memorialRitualConfiguredCount = 0;
  int _memorialRitualMissingCount = 0;
  int _memorialRitualDateMismatchCount = 0;

  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;
  List<EventRecord> get events => _events;
  List<MemberProfile> get members => _members;
  List<BranchProfile> get branches => _branches;
  String get query => _query;
  EventType? get typeFilter => _typeFilter;

  bool get hasClanContext => permissions.canViewWorkspace;

  List<EventRecord> get filteredEvents => _filteredEvents;

  int get upcomingCount => _upcomingCount;

  int get memorialCount => _memorialCount;

  List<MemorialChecklistItem> get memorialChecklistItems =>
      _memorialChecklistItems;

  int get memorialChecklistConfiguredCount => _memorialChecklistConfiguredCount;

  int get memorialChecklistMissingCount => _memorialChecklistMissingCount;

  int get memorialChecklistDateMismatchCount =>
      _memorialChecklistDateMismatchCount;

  List<MemorialRitualChecklistItem> get memorialRitualChecklistItems =>
      _memorialRitualChecklistItems;

  int get memorialRitualConfiguredCount => _memorialRitualConfiguredCount;

  int get memorialRitualMissingCount => _memorialRitualMissingCount;

  int get memorialRitualDateMismatchCount => _memorialRitualDateMismatchCount;

  Future<void> initialize() async {
    await refresh();
  }

  Future<void> refresh() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final snapshot = await _repository.loadWorkspace(session: _session);
      _events = snapshot.events;
      _members = snapshot.members;
      _branches = snapshot.branches;
      _buildNameIndexes();
      _recomputeDerivedData();
    } catch (error) {
      _errorMessage = error.toString();
      _events = const [];
      _members = const [];
      _branches = const [];
      _memberNamesById = const {};
      _branchNamesById = const {};
      _filteredEvents = const [];
      _upcomingCount = 0;
      _memorialCount = 0;
      _memorialChecklistItems = const [];
      _memorialChecklistConfiguredCount = 0;
      _memorialChecklistMissingCount = 0;
      _memorialChecklistDateMismatchCount = 0;
      _memorialRitualChecklistItems = const [];
      _memorialRitualConfiguredCount = 0;
      _memorialRitualMissingCount = 0;
      _memorialRitualDateMismatchCount = 0;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void updateQuery(String value) {
    _query = value;
    _recomputeFilteredEvents();
    notifyListeners();
  }

  void updateTypeFilter(EventType? value) {
    _typeFilter = value;
    _recomputeFilteredEvents();
    notifyListeners();
  }

  Future<EventRepositoryErrorCode?> saveEvent({
    String? eventId,
    required EventDraft draft,
  }) async {
    if (!permissions.canManageEvents) {
      return EventRepositoryErrorCode.permissionDenied;
    }

    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.saveEvent(
        session: _session,
        eventId: eventId,
        draft: draft,
      );
      await refresh();
      return null;
    } on EventRepositoryException catch (error) {
      return error.code;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  EventRecord? eventById(String eventId) {
    return _events.firstWhereOrNull((event) => event.id == eventId);
  }

  String memberName(String? memberId) {
    if (memberId == null || memberId.trim().isEmpty) {
      return '';
    }

    return _memberNamesById[memberId] ?? memberId;
  }

  String branchName(String? branchId) {
    if (branchId == null || branchId.trim().isEmpty) {
      return '';
    }

    return _branchNamesById[branchId] ?? branchId;
  }

  void _buildNameIndexes() {
    _memberNamesById = {
      for (final member in _members)
        if (member.id.trim().isNotEmpty) member.id: member.fullName,
    };
    _branchNamesById = {
      for (final branch in _branches)
        if (branch.id.trim().isNotEmpty) branch.id: branch.name,
    };
  }

  void _recomputeDerivedData() {
    final now = DateTime.now().toUtc();
    _upcomingCount = _events
        .where((event) => !event.startsAt.isBefore(now))
        .length;
    _memorialCount = _events
        .where((event) => event.eventType.isMemorial)
        .length;
    _recomputeMemorialChecklist();
    _recomputeMemorialRitualChecklist();
    _recomputeFilteredEvents();
  }

  void _recomputeMemorialChecklist() {
    final memorialEventsByMemberId = <String, List<EventRecord>>{};
    for (final event in _events) {
      if (!_isYearlyMemorialEvent(event)) {
        continue;
      }

      final targetMemberId = event.targetMemberId?.trim();
      if (targetMemberId == null || targetMemberId.isEmpty) {
        continue;
      }

      memorialEventsByMemberId
          .putIfAbsent(targetMemberId, () => <EventRecord>[])
          .add(event);
    }

    final values = <MemorialChecklistItem>[];
    for (final member in _members) {
      final deathDateRaw = member.deathDate?.trim() ?? '';
      if (deathDateRaw.isEmpty) {
        continue;
      }

      final deathDate = _parseDeathDate(deathDateRaw);
      final memorialEvents = List<EventRecord>.from(
        memorialEventsByMemberId[member.id] ?? const <EventRecord>[],
      )..sort((left, right) => left.startsAt.compareTo(right.startsAt));

      final hasAlignedMemorialDate =
          deathDate != null &&
          memorialEvents.any(
            (event) => _isSameMonthAndDay(event.startsAt.toLocal(), deathDate),
          );

      values.add(
        MemorialChecklistItem(
          member: member,
          deathDateRaw: deathDateRaw,
          deathDate: deathDate,
          memorialEvents: List.unmodifiable(memorialEvents),
          hasAlignedMemorialDate: hasAlignedMemorialDate,
        ),
      );
    }

    values.sort((left, right) {
      int rank(MemorialChecklistItem item) {
        if (!item.hasMemorialEvent) {
          return 0;
        }
        if (item.hasDateMismatch) {
          return 1;
        }
        return 2;
      }

      final byRank = rank(left).compareTo(rank(right));
      if (byRank != 0) {
        return byRank;
      }

      final leftDate = left.deathDate;
      final rightDate = right.deathDate;
      if (leftDate != null && rightDate != null) {
        final byMonth = leftDate.month.compareTo(rightDate.month);
        if (byMonth != 0) {
          return byMonth;
        }
        final byDay = leftDate.day.compareTo(rightDate.day);
        if (byDay != 0) {
          return byDay;
        }
      } else if (leftDate != null) {
        return -1;
      } else if (rightDate != null) {
        return 1;
      }

      return left.member.fullName.toLowerCase().compareTo(
        right.member.fullName.toLowerCase(),
      );
    });

    _memorialChecklistItems = List.unmodifiable(values);
    _memorialChecklistMissingCount = values
        .where((item) => !item.hasMemorialEvent)
        .length;
    _memorialChecklistDateMismatchCount = values
        .where((item) => item.hasDateMismatch)
        .length;
    _memorialChecklistConfiguredCount = values
        .where((item) => item.hasMemorialEvent && !item.hasDateMismatch)
        .length;
  }

  void _recomputeMemorialRitualChecklist() {
    final ritualEventsByMemberId = <String, List<EventRecord>>{};
    for (final event in _events) {
      if (!_isRitualMemorialEvent(event)) {
        continue;
      }

      final targetMemberId = event.targetMemberId?.trim();
      if (targetMemberId == null || targetMemberId.isEmpty) {
        continue;
      }
      ritualEventsByMemberId
          .putIfAbsent(targetMemberId, () => <EventRecord>[])
          .add(event);
    }

    final values = <MemorialRitualChecklistItem>[];
    var configuredCount = 0;
    var missingCount = 0;
    var mismatchCount = 0;

    for (final member in _members) {
      final deathDateRaw = member.deathDate?.trim() ?? '';
      if (deathDateRaw.isEmpty) {
        continue;
      }
      final deathDate = _parseDeathDate(deathDateRaw);
      if (deathDate == null) {
        continue;
      }

      final milestones = buildMemorialRitualMilestones(
        deathDate: deathDate,
        gender: member.gender,
      );
      final memberEvents = List<EventRecord>.from(
        ritualEventsByMemberId[member.id] ?? const <EventRecord>[],
      )..sort((left, right) => left.startsAt.compareTo(right.startsAt));

      final consumedEventIds = <String>{};
      final checklistMilestones = <MemorialRitualChecklistMilestoneItem>[];
      for (final milestone in milestones) {
        final expectedDate = milestone.expectedAt;
        final byKey = memberEvents.firstWhereOrNull(
          (event) =>
              !consumedEventIds.contains(event.id) &&
              (event.ritualKey?.trim() ?? '') == milestone.key,
        );
        final byDate = memberEvents.firstWhereOrNull(
          (event) =>
              !consumedEventIds.contains(event.id) &&
              _isSameCalendarDate(event.startsAt.toLocal(), expectedDate),
        );
        final configuredEvent = byKey ?? byDate;
        if (configuredEvent != null) {
          consumedEventIds.add(configuredEvent.id);
        }

        final hasAlignedDate =
            configuredEvent != null &&
            _isSameCalendarDate(
              configuredEvent.startsAt.toLocal(),
              expectedDate,
            );
        if (configuredEvent == null) {
          missingCount += 1;
        } else if (hasAlignedDate) {
          configuredCount += 1;
        } else {
          mismatchCount += 1;
        }

        checklistMilestones.add(
          MemorialRitualChecklistMilestoneItem(
            milestone: milestone,
            expectedDate: expectedDate,
            configuredEvent: configuredEvent,
            hasAlignedDate: hasAlignedDate,
          ),
        );
      }

      values.add(
        MemorialRitualChecklistItem(
          member: member,
          deathDateRaw: deathDateRaw,
          deathDate: deathDate,
          milestones: List.unmodifiable(checklistMilestones),
        ),
      );
    }

    values.sort((left, right) {
      final byMissing = right.missingCount.compareTo(left.missingCount);
      if (byMissing != 0) {
        return byMissing;
      }
      final byMismatch = right.mismatchCount.compareTo(left.mismatchCount);
      if (byMismatch != 0) {
        return byMismatch;
      }
      final byMonth = left.deathDate.month.compareTo(right.deathDate.month);
      if (byMonth != 0) {
        return byMonth;
      }
      final byDay = left.deathDate.day.compareTo(right.deathDate.day);
      if (byDay != 0) {
        return byDay;
      }
      return left.member.fullName.toLowerCase().compareTo(
        right.member.fullName.toLowerCase(),
      );
    });

    _memorialRitualChecklistItems = List.unmodifiable(values);
    _memorialRitualConfiguredCount = configuredCount;
    _memorialRitualMissingCount = missingCount;
    _memorialRitualDateMismatchCount = mismatchCount;
  }

  void _recomputeFilteredEvents() {
    final normalizedQuery = _query.trim().toLowerCase();
    final now = DateTime.now().toUtc();

    final values = _events
        .where((event) {
          if (_typeFilter != null && event.eventType != _typeFilter) {
            return false;
          }
          if (normalizedQuery.isEmpty) {
            return true;
          }
          final haystack = [
            event.title,
            event.description,
            event.locationName,
            event.locationAddress,
            memberName(event.targetMemberId),
          ].join(' ').toLowerCase();
          return haystack.contains(normalizedQuery);
        })
        .toList(growable: false);

    values.sort((left, right) {
      final leftUpcoming = !left.startsAt.isBefore(now);
      final rightUpcoming = !right.startsAt.isBefore(now);
      if (leftUpcoming != rightUpcoming) {
        return leftUpcoming ? -1 : 1;
      }
      return left.startsAt.compareTo(right.startsAt);
    });

    _filteredEvents = values;
  }
}

DateTime? _parseDeathDate(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return null;
  }

  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(trimmed);
  if (match != null) {
    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    final parsed = DateTime(year, month, day);
    if (parsed.year == year && parsed.month == month && parsed.day == day) {
      return parsed;
    }
    return null;
  }

  return DateTime.tryParse(trimmed)?.toLocal();
}

bool _isSameMonthAndDay(DateTime left, DateTime right) {
  return left.month == right.month && left.day == right.day;
}

bool _isSameCalendarDate(DateTime left, DateTime right) {
  return left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;
}

bool _isYearlyMemorialEvent(EventRecord event) {
  if (!event.eventType.isMemorial) {
    return false;
  }
  if (!event.isRecurring) {
    return false;
  }
  final rule = event.recurrenceRule?.trim().toUpperCase() ?? '';
  return rule.contains('FREQ=YEARLY');
}

bool _isRitualMemorialEvent(EventRecord event) {
  if (!event.eventType.isMemorial) {
    return false;
  }
  return !event.isRecurring;
}
