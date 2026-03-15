import '../../../core/services/debug_genealogy_store.dart';
import '../../../core/services/runtime_mode.dart';
import '../../auth/models/auth_session.dart';
import '../models/event_draft.dart';
import '../models/event_record.dart';
import '../models/event_workspace_snapshot.dart';
import 'debug_event_repository.dart';
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

  Future<EventRecord> saveEvent({
    required AuthSession session,
    String? eventId,
    required EventDraft draft,
  });
}

EventRepository createDefaultEventRepository({AuthSession? session}) {
  final useMockBackend = session?.isSandbox ?? RuntimeMode.shouldUseMockBackend;
  if (useMockBackend) {
    return DebugEventRepository(store: DebugGenealogyStore.sharedSeeded());
  }

  return FirebaseEventRepository();
}
