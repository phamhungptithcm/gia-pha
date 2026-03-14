import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';

import '../../auth/models/auth_session.dart';
import '../../clan/models/branch_profile.dart';
import '../../member/models/member_profile.dart';
import '../models/event_draft.dart';
import '../models/event_record.dart';
import '../models/event_type.dart';
import '../services/event_permissions.dart';
import '../services/event_repository.dart';

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
    _recomputeFilteredEvents();
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
