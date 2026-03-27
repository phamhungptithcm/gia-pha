import '../../auth/models/auth_session.dart';
import '../models/event_draft.dart';
import '../models/event_record.dart';
import '../models/event_workspace_snapshot.dart';
import 'firebase_event_repository.dart';

enum EventRepositoryErrorCode {
  permissionDenied,
  eventNotFound,
  invalidTitle,
  invalidTimeRange,
  invalidMemorialTarget,
  invalidRecurrence,
  invalidReminderOffsets,
}

class EventRepositoryException implements Exception {
  const EventRepositoryException(this.code, [this.message]);

  final EventRepositoryErrorCode code;
  final String? message;

  @override
  String toString() => message ?? code.name;
}

abstract interface class EventRepository {
  bool get isSandbox;

  Future<EventWorkspaceSnapshot> loadWorkspace({required AuthSession session});

  Future<List<EventRecord>> loadUpcomingEvents({
    required AuthSession session,
    int limit = 80,
  });

  Future<EventRecord> saveEvent({
    required AuthSession session,
    String? eventId,
    required EventDraft draft,
  });
}

EventRepository createDefaultEventRepository({AuthSession? session}) {
  return FirebaseEventRepository();
}
