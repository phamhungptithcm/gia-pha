import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';

import '../../../core/services/app_environment.dart';
import '../../../core/services/expiring_value_cache.dart';
import '../../../core/services/firestore_paged_query_loader.dart';
import '../../../core/services/firebase_session_access_sync.dart';
import '../../../core/services/firebase_services.dart';
import '../../../core/services/governance_role_matrix.dart';
import '../../../core/services/inflight_task_cache.dart';
import '../../auth/models/auth_session.dart';
import '../../clan/models/branch_profile.dart';
import '../../member/models/member_profile.dart';
import '../models/event_draft.dart';
import '../models/event_record.dart';
import '../models/event_type.dart';
import '../models/event_workspace_snapshot.dart';
import 'event_repository.dart';
import 'event_validation.dart';

class FirebaseEventRepository implements EventRepository {
  static const int _workspacePageSize = 400;
  static const int _workspaceMaxDocuments = 2000;
  static const Duration _workspaceCacheTtl = Duration(seconds: 60);
  static const Duration _upcomingCacheTtl = Duration(seconds: 45);

  FirebaseEventRepository({
    FirebaseFirestore? firestore,
    FirestorePagedQueryLoader? pagedQueryLoader,
  }) : _firestore = firestore ?? FirebaseServices.firestore,
       _pagedQueryLoader =
           pagedQueryLoader ?? const FirestorePagedQueryLoader();

  final FirebaseFirestore _firestore;
  final FirestorePagedQueryLoader _pagedQueryLoader;
  final InflightTaskCache<String, EventWorkspaceSnapshot> _workspaceLoadCache =
      InflightTaskCache<String, EventWorkspaceSnapshot>();
  final ExpiringValueCache<String, EventWorkspaceSnapshot>
  _workspaceSnapshotCache = ExpiringValueCache<String, EventWorkspaceSnapshot>(
    ttl: _workspaceCacheTtl,
  );
  final ExpiringValueCache<String, List<EventRecord>> _upcomingEventsCache =
      ExpiringValueCache<String, List<EventRecord>>(ttl: _upcomingCacheTtl);

  CollectionReference<Map<String, dynamic>> get _events =>
      _firestore.collection('events');

  CollectionReference<Map<String, dynamic>> get _members =>
      _firestore.collection('members');

  CollectionReference<Map<String, dynamic>> get _branches =>
      _firestore.collection('branches');

  @override
  bool get isSandbox => false;

  @override
  Future<EventWorkspaceSnapshot> loadWorkspace({
    required AuthSession session,
  }) async {
    await FirebaseSessionAccessSync.ensureUserSessionDocument(
      firestore: _firestore,
      session: session,
    );

    final clanId = (session.clanId ?? '').trim();
    if (clanId.isEmpty) {
      return const EventWorkspaceSnapshot(
        events: [],
        members: [],
        branches: [],
      );
    }

    final cached = _workspaceSnapshotCache.read(clanId);
    if (cached != null) {
      return cached;
    }

    return _workspaceLoadCache.run(clanId, () async {
      final results =
          await Future.wait<List<QueryDocumentSnapshot<Map<String, dynamic>>>>([
            _fetchPagedDocuments(
              _events.where('clanId', isEqualTo: clanId).orderBy('startsAt'),
            ),
            _fetchPagedDocuments(_members.where('clanId', isEqualTo: clanId)),
            _fetchPagedDocuments(_branches.where('clanId', isEqualTo: clanId)),
          ]);

      final events = results[0]
          .map((doc) => EventRecord.fromJson(doc.data()))
          .sortedBy((event) => event.startsAt)
          .toList(growable: false);
      final members = results[1]
          .map((doc) => MemberProfile.fromJson(doc.data()))
          .sortedBy((member) => member.fullName.toLowerCase())
          .toList(growable: false);
      final branches = results[2]
          .map((doc) => BranchProfile.fromJson(doc.data()))
          .sortedBy((branch) => branch.name.toLowerCase())
          .toList(growable: false);

      final snapshot = EventWorkspaceSnapshot(
        events: events,
        members: members,
        branches: branches,
      );
      _workspaceSnapshotCache.write(clanId, snapshot);
      return snapshot;
    });
  }

  @override
  Future<List<EventRecord>> loadUpcomingEvents({
    required AuthSession session,
    int limit = 80,
  }) async {
    await FirebaseSessionAccessSync.ensureUserSessionDocument(
      firestore: _firestore,
      session: session,
    );

    final clanId = (session.clanId ?? '').trim();
    if (clanId.isEmpty) {
      return const <EventRecord>[];
    }
    final safeLimit = limit.clamp(1, 200);
    final cacheKey = '$clanId|$safeLimit';
    final cached = _upcomingEventsCache.read(cacheKey);
    if (cached != null) {
      return cached;
    }
    final now = DateTime.now().toUtc();
    final anchor = Timestamp.fromDate(now.subtract(const Duration(days: 1)));

    final snapshot = await _events
        .where('clanId', isEqualTo: clanId)
        .where('startsAt', isGreaterThanOrEqualTo: anchor)
        .orderBy('startsAt')
        .limit(safeLimit)
        .get();

    final events = snapshot.docs
        .map((doc) => EventRecord.fromJson(doc.data()))
        .where((event) => !event.startsAt.isBefore(now))
        .sortedBy((event) => event.startsAt)
        .take(safeLimit)
        .toList(growable: false);
    _upcomingEventsCache.write(cacheKey, events);
    return events;
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  _fetchPagedDocuments(
    Query<Map<String, dynamic>> baseQuery, {
    int pageSize = _workspacePageSize,
    int maxDocuments = _workspaceMaxDocuments,
  }) async {
    return _pagedQueryLoader.loadAll(
      baseQuery: baseQuery,
      pageSize: pageSize,
      maxDocuments: maxDocuments,
    );
  }

  @override
  Future<EventRecord> saveEvent({
    required AuthSession session,
    String? eventId,
    required EventDraft draft,
  }) async {
    await FirebaseSessionAccessSync.ensureUserSessionDocument(
      firestore: _firestore,
      session: session,
    );

    _ensureCanManage(session);
    _validateDraft(draft);

    final clanId = (session.clanId ?? '').trim();
    if (clanId.isEmpty) {
      throw const EventRepositoryException(
        EventRepositoryErrorCode.permissionDenied,
      );
    }
    final eventRef = eventId == null ? _events.doc() : _events.doc(eventId);
    final existing = await eventRef.get();

    if (eventId != null && !existing.exists) {
      throw const EventRepositoryException(
        EventRepositoryErrorCode.eventNotFound,
      );
    }
    if (existing.exists &&
        (existing.data()?['clanId'] as String?)?.trim() != clanId) {
      throw const EventRepositoryException(
        EventRepositoryErrorCode.permissionDenied,
      );
    }

    final branchId = await _resolvedBranchId(
      clanId: clanId,
      draft: draft,
      existing: existing.data(),
      session: session,
    );
    final targetMemberId = await _resolvedTargetMemberId(
      clanId: clanId,
      draft: draft,
    );
    final recurrenceRule = _resolvedRecurrenceRule(draft);
    final reminderOffsets = EventValidation.sanitizeReminderOffsets(
      draft.reminderOffsetsMinutes,
    );
    final actor = session.memberId ?? session.uid;

    final payload = <String, Object?>{
      'id': eventRef.id,
      'clanId': clanId,
      'branchId': branchId,
      'title': draft.title.trim(),
      'description': draft.description.trim(),
      'eventType': draft.eventType.wireName,
      'targetMemberId': targetMemberId,
      'locationName': draft.locationName.trim(),
      'locationAddress': draft.locationAddress.trim(),
      'startsAt': draft.startsAt.toUtc(),
      'endsAt': draft.endsAt?.toUtc(),
      'timezone': draft.timezone.trim().isEmpty
          ? AppEnvironment.defaultTimezone
          : draft.timezone.trim(),
      'isRecurring': draft.isRecurring,
      'recurrenceRule': recurrenceRule,
      'reminderOffsetsMinutes': reminderOffsets,
      'visibility': draft.visibility.trim().isEmpty
          ? 'clan'
          : draft.visibility.trim(),
      'status': draft.status.trim().isEmpty ? 'scheduled' : draft.status.trim(),
      'ritualKey': _nullableTrim(draft.ritualKey),
      'ritualPreset': _nullableTrim(draft.ritualPreset),
      'isAutoGenerated': draft.isAutoGenerated,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': actor,
      if (!existing.exists) 'createdAt': FieldValue.serverTimestamp(),
      if (!existing.exists) 'createdBy': actor,
    };

    await eventRef.set(payload, SetOptions(merge: true));
    final updated = await eventRef.get();
    _invalidateEventCaches(clanId);
    return EventRecord.fromJson(updated.data()!);
  }

  void _invalidateEventCaches(String clanId) {
    _workspaceLoadCache.invalidate(clanId);
    _workspaceSnapshotCache.invalidate(clanId);
    _upcomingEventsCache.invalidate();
  }

  void _ensureCanManage(AuthSession session) {
    final canManage = GovernanceRoleMatrix.canManageEvents(session);
    if (!canManage) {
      throw const EventRepositoryException(
        EventRepositoryErrorCode.permissionDenied,
      );
    }
  }

  void _validateDraft(EventDraft draft) {
    final result = EventValidation.validate(draft);
    if (result.isValid) {
      return;
    }

    final primaryIssue = result.issues.first.code;
    throw EventRepositoryException(switch (primaryIssue) {
      EventValidationIssueCode.missingTitle =>
        EventRepositoryErrorCode.invalidTitle,
      EventValidationIssueCode.invalidTimeRange =>
        EventRepositoryErrorCode.invalidTimeRange,
      EventValidationIssueCode.invalidReminderOffsets =>
        EventRepositoryErrorCode.invalidReminderOffsets,
      EventValidationIssueCode.memorialRequiresTargetMember =>
        EventRepositoryErrorCode.invalidMemorialTarget,
      EventValidationIssueCode.memorialRequiresYearlyRecurrence =>
        EventRepositoryErrorCode.invalidRecurrence,
    });
  }

  Future<String?> _resolvedBranchId({
    required String clanId,
    required EventDraft draft,
    required Map<String, dynamic>? existing,
    required AuthSession session,
  }) async {
    final draftBranchId = draft.branchId?.trim();
    final existingBranchId = (existing?['branchId'] as String?)?.trim();
    final sessionBranchId = session.branchId?.trim();

    final resolved = [
      draftBranchId,
      existingBranchId,
      sessionBranchId,
    ].firstWhereOrNull((value) => value != null && value.isNotEmpty);

    if (resolved == null) {
      return null;
    }

    final branch = await _branches.doc(resolved).get();
    if (!branch.exists || branch.data()?['clanId'] != clanId) {
      throw const EventRepositoryException(
        EventRepositoryErrorCode.permissionDenied,
      );
    }

    return resolved;
  }

  Future<String?> _resolvedTargetMemberId({
    required String clanId,
    required EventDraft draft,
  }) async {
    if (!draft.eventType.isMemorial) {
      return null;
    }

    final targetMemberId = draft.targetMemberId?.trim();
    if (targetMemberId == null || targetMemberId.isEmpty) {
      return null;
    }

    final targetMember = await _members.doc(targetMemberId).get();
    if (!targetMember.exists || targetMember.data()?['clanId'] != clanId) {
      throw const EventRepositoryException(
        EventRepositoryErrorCode.invalidMemorialTarget,
      );
    }

    return targetMemberId;
  }

  String? _resolvedRecurrenceRule(EventDraft draft) {
    if (!draft.isRecurring) {
      return null;
    }

    if (draft.eventType == EventType.deathAnniversary) {
      return 'FREQ=YEARLY';
    }

    return EventValidation.normalizeRecurrenceRule(draft.recurrenceRule);
  }
}

String? _nullableTrim(String? value) {
  final trimmed = value?.trim() ?? '';
  return trimmed.isEmpty ? null : trimmed;
}
