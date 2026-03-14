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
  String _query = '';
  EventType? _typeFilter;

  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;
  List<EventRecord> get events => _events;
  List<MemberProfile> get members => _members;
  List<BranchProfile> get branches => _branches;
  String get query => _query;
  EventType? get typeFilter => _typeFilter;

  bool get hasClanContext => permissions.canViewWorkspace;

  List<EventRecord> get filteredEvents {
    final normalizedQuery = _query.trim().toLowerCase();
    final now = DateTime.now().toUtc();

    return _events
        .where((event) {
          if (_typeFilter != null && event.eventType != _typeFilter) {
            return false;
          }
          if (normalizedQuery.isNotEmpty) {
            final haystack = [
              event.title,
              event.description,
              event.locationName,
              event.locationAddress,
              memberName(event.targetMemberId),
            ].join(' ').toLowerCase();
            if (!haystack.contains(normalizedQuery)) {
              return false;
            }
          }
          return true;
        })
        .sorted((left, right) {
          final leftUpcoming = !left.startsAt.isBefore(now);
          final rightUpcoming = !right.startsAt.isBefore(now);
          if (leftUpcoming != rightUpcoming) {
            return leftUpcoming ? -1 : 1;
          }
          return left.startsAt.compareTo(right.startsAt);
        })
        .toList(growable: false);
  }

  int get upcomingCount {
    final now = DateTime.now().toUtc();
    return _events.where((event) => !event.startsAt.isBefore(now)).length;
  }

  int get memorialCount {
    return _events.where((event) => event.eventType.isMemorial).length;
  }

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
    } catch (error) {
      _errorMessage = error.toString();
      _events = const [];
      _members = const [];
      _branches = const [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void updateQuery(String value) {
    _query = value;
    notifyListeners();
  }

  void updateTypeFilter(EventType? value) {
    _typeFilter = value;
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

    return _members
            .firstWhereOrNull((member) => member.id == memberId)
            ?.fullName ??
        memberId;
  }

  String branchName(String? branchId) {
    if (branchId == null || branchId.trim().isEmpty) {
      return '';
    }

    return _branches
            .firstWhereOrNull((branch) => branch.id == branchId)
            ?.name ??
        branchId;
  }
}
