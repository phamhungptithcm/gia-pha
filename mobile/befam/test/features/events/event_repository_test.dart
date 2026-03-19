import '../../support/core/services/debug_genealogy_store.dart';
import 'package:befam/features/auth/models/auth_entry_method.dart';
import 'package:befam/features/auth/models/auth_member_access_mode.dart';
import 'package:befam/features/auth/models/auth_session.dart';
import 'package:befam/features/events/models/event_draft.dart';
import 'package:befam/features/events/models/event_type.dart';
import '../../support/features/events/services/debug_event_repository.dart';
import 'package:befam/features/events/services/event_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  AuthSession buildClanAdminSession() {
    return AuthSession(
      uid: 'debug:+84901234567',
      loginMethod: AuthEntryMethod.phone,
      phoneE164: '+84901234567',
      displayName: 'Nguyễn Minh',
      memberId: 'member_demo_parent_001',
      clanId: 'clan_demo_001',
      branchId: 'branch_demo_001',
      primaryRole: 'CLAN_ADMIN',
      accessMode: AuthMemberAccessMode.claimed,
      linkedAuthUid: true,
      isSandbox: true,
      signedInAtIso: DateTime(2026, 3, 14).toIso8601String(),
    );
  }

  AuthSession buildMemberSession() {
    return AuthSession(
      uid: 'debug:+84909998888',
      loginMethod: AuthEntryMethod.phone,
      phoneE164: '+84909998888',
      displayName: 'Thành viên mẫu',
      memberId: 'member_demo_child_001',
      clanId: 'clan_demo_001',
      branchId: 'branch_demo_001',
      primaryRole: 'MEMBER',
      accessMode: AuthMemberAccessMode.claimed,
      linkedAuthUid: true,
      isSandbox: true,
      signedInAtIso: DateTime(2026, 3, 14).toIso8601String(),
    );
  }

  test('loads seeded events sorted by start time', () async {
    final repository = DebugEventRepository(
      store: DebugGenealogyStore.seeded(),
    );

    final snapshot = await repository.loadWorkspace(
      session: buildClanAdminSession(),
    );

    expect(snapshot.events, isNotEmpty);
    expect(
      snapshot.events.first.startsAt.isBefore(snapshot.events.last.startsAt),
      isTrue,
    );
  });

  test('creates a new event with sanitized reminder offsets', () async {
    final repository = DebugEventRepository(
      store: DebugGenealogyStore.seeded(),
    );

    final draft = EventDraft(
      branchId: 'branch_demo_001',
      title: 'Họp kế hoạch dòng họ',
      description: 'Thảo luận kế hoạch hoạt động năm.',
      eventType: EventType.meeting,
      targetMemberId: null,
      locationName: 'Main hall',
      locationAddress: 'Đà Nẵng, Việt Nam',
      startsAt: DateTime(2026, 6, 10, 18),
      endsAt: DateTime(2026, 6, 10, 20),
      timezone: 'Asia/Ho_Chi_Minh',
      isRecurring: false,
      recurrenceRule: null,
      reminderOffsetsMinutes: const [120, 120, 1440],
      visibility: 'clan',
      status: 'scheduled',
    );

    final created = await repository.saveEvent(
      session: buildClanAdminSession(),
      draft: draft,
    );

    final snapshot = await repository.loadWorkspace(
      session: buildClanAdminSession(),
    );
    expect(snapshot.events.map((event) => event.id), contains(created.id));
    expect(created.reminderOffsetsMinutes, const [1440, 120]);
  });

  test('rejects events where end time is before start time', () async {
    final repository = DebugEventRepository(
      store: DebugGenealogyStore.seeded(),
    );

    final invalidDraft = EventDraft(
      branchId: 'branch_demo_001',
      title: 'Thời gian không hợp lệ',
      description: '',
      eventType: EventType.meeting,
      targetMemberId: null,
      locationName: '',
      locationAddress: '',
      startsAt: DateTime(2026, 6, 10, 18),
      endsAt: DateTime(2026, 6, 10, 17),
      timezone: 'Asia/Ho_Chi_Minh',
      isRecurring: false,
      recurrenceRule: null,
      reminderOffsetsMinutes: const [120],
      visibility: 'clan',
      status: 'scheduled',
    );

    expect(
      () => repository.saveEvent(
        session: buildClanAdminSession(),
        draft: invalidDraft,
      ),
      throwsA(
        isA<EventRepositoryException>().having(
          (error) => error.code,
          'code',
          EventRepositoryErrorCode.invalidTimeRange,
        ),
      ),
    );
  });

  test(
    'requires memorial target member for recurring yearly memorials',
    () async {
      final repository = DebugEventRepository(
        store: DebugGenealogyStore.seeded(),
      );

      final invalidDraft = EventDraft(
        branchId: 'branch_demo_001',
        title: 'Giỗ cụ tổ',
        description: '',
        eventType: EventType.deathAnniversary,
        targetMemberId: null,
        locationName: '',
        locationAddress: '',
        startsAt: DateTime(2026, 6, 10, 9),
        endsAt: DateTime(2026, 6, 10, 11),
        timezone: 'Asia/Ho_Chi_Minh',
        isRecurring: true,
        recurrenceRule: 'FREQ=YEARLY',
        reminderOffsetsMinutes: const [10080, 1440],
        visibility: 'clan',
        status: 'scheduled',
      );

      expect(
        () => repository.saveEvent(
          session: buildClanAdminSession(),
          draft: invalidDraft,
        ),
        throwsA(
          isA<EventRepositoryException>().having(
            (error) => error.code,
            'code',
            EventRepositoryErrorCode.invalidMemorialTarget,
          ),
        ),
      );
    },
  );

  test('blocks regular members from creating events', () async {
    final repository = DebugEventRepository(
      store: DebugGenealogyStore.seeded(),
    );

    final draft = EventDraft.empty(defaultBranchId: 'branch_demo_001').copyWith(
      title: 'Member-created event',
      startsAt: DateTime(2026, 6, 10, 18),
      endsAt: DateTime(2026, 6, 10, 19),
    );

    expect(
      () => repository.saveEvent(session: buildMemberSession(), draft: draft),
      throwsA(
        isA<EventRepositoryException>().having(
          (error) => error.code,
          'code',
          EventRepositoryErrorCode.permissionDenied,
        ),
      ),
    );
  });
}
