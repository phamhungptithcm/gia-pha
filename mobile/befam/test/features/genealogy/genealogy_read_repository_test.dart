import 'package:befam/core/services/debug_genealogy_store.dart';
import 'package:befam/features/auth/models/auth_entry_method.dart';
import 'package:befam/features/auth/models/auth_member_access_mode.dart';
import 'package:befam/features/auth/models/auth_session.dart';
import 'package:befam/features/genealogy/models/genealogy_root_entry.dart';
import 'package:befam/features/genealogy/services/debug_genealogy_read_repository.dart';
import 'package:befam/features/genealogy/services/genealogy_segment_cache.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  AuthSession buildClanAdminSession() {
    return AuthSession(
      uid: 'debug:+84901234567',
      loginMethod: AuthEntryMethod.phone,
      phoneE164: '+84901234567',
      displayName: 'Nguyen Minh',
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
    final repository = DebugGenealogyReadRepository(
      store: DebugGenealogyStore.seeded(),
    );
    final session = buildClanAdminSession();

    final initial = await repository.loadClanSegment(session: session);
    final cached = await repository.loadClanSegment(session: session);

    expect(initial.members.length, 5);
    expect(initial.branches.length, 2);
    expect(initial.relationships.length, 2);
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

  test('loads the current branch scope only and filters relationships', () async {
    final repository = DebugGenealogyReadRepository(
      store: DebugGenealogyStore.seeded(),
    );
    final session = buildClanAdminSession();

    final segment = await repository.loadBranchSegment(session: session);

    expect(segment.members.map((member) => member.id).toSet(), {
      'member_demo_parent_001',
      'member_demo_child_001',
      'member_demo_elder_001',
    });
    expect(segment.branches.single.id, 'branch_demo_001');
    expect(segment.relationships.map((relationship) => relationship.id).toSet(), {
      'rel_parent_child_member_demo_parent_001_member_demo_child_001',
    });
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
  });
}
