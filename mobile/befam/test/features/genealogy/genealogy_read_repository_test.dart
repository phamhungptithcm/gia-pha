import '../../support/core/services/debug_genealogy_store.dart';
import 'package:befam/features/auth/models/auth_entry_method.dart';
import 'package:befam/features/auth/models/auth_member_access_mode.dart';
import 'package:befam/features/auth/models/auth_session.dart';
import 'package:befam/features/genealogy/models/genealogy_root_entry.dart';
import '../../support/features/genealogy/services/debug_genealogy_read_repository.dart';
import 'package:befam/features/genealogy/services/genealogy_segment_cache.dart';
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

  setUp(() {
    GenealogySegmentCache.shared().clear();
  });

  test('loads the clan scope and returns cached snapshots on repeat', () async {
    final store = DebugGenealogyStore.seeded();
    final repository = DebugGenealogyReadRepository(store: store);
    final session = buildClanAdminSession();

    final initial = await repository.loadClanSegment(session: session);
    final cached = await repository.loadClanSegment(session: session);

    expect(initial.members.length, store.members.length);
    expect(initial.branches.length, store.branches.length);
    expect(initial.relationships.length, store.relationships.length);
    expect(initial.fromCache, isFalse);
    expect(cached.fromCache, isTrue);
    expect(
      initial.rootEntries.any(
        (entry) =>
            entry.memberId == 'member_demo_parent_001' &&
            entry.reasons.contains(GenealogyRootReason.currentMember),
      ),
      isTrue,
    );
  });

  test(
    'loads the current branch scope only and filters relationships',
    () async {
      final store = DebugGenealogyStore.seeded();
      final repository = DebugGenealogyReadRepository(store: store);
      final session = buildClanAdminSession();

      final segment = await repository.loadBranchSegment(session: session);
      final branchMemberIds = store.members.values
          .where((member) => member.branchId == 'branch_demo_001')
          .map((member) => member.id)
          .toSet();
      final segmentMemberIds = segment.members
          .map((member) => member.id)
          .toSet();

      expect(segmentMemberIds, branchMemberIds);
      expect(segment.branches.single.id, 'branch_demo_001');
      expect(
        segment.relationships.map((relationship) => relationship.id).toSet(),
        contains(
          'rel_parent_child_member_demo_parent_001_member_demo_child_001',
        ),
      );
      for (final relationship in segment.relationships) {
        expect(segmentMemberIds, contains(relationship.personAId));
        expect(segmentMemberIds, contains(relationship.personBId));
      }
      expect(
        segment.rootEntries.any(
          (entry) =>
              entry.memberId == 'member_demo_parent_001' &&
              entry.reasons.contains(GenealogyRootReason.branchLeader),
        ),
        isTrue,
      );
      expect(
        segment.rootEntries.any(
          (entry) =>
              entry.memberId == 'member_demo_elder_001' &&
              entry.reasons.contains(GenealogyRootReason.scopeRoot),
        ),
        isTrue,
      );
    },
  );
}
