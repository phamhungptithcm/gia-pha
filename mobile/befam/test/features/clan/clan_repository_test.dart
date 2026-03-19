import 'package:befam/features/auth/models/auth_entry_method.dart';
import 'package:befam/features/auth/models/auth_member_access_mode.dart';
import 'package:befam/features/auth/models/auth_session.dart';
import 'package:befam/features/clan/models/branch_draft.dart';
import 'package:befam/features/clan/models/clan_draft.dart';
import '../../support/features/clan/services/debug_clan_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  AuthSession buildAdminSession() {
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
      signedInAtIso: DateTime(2026, 3, 13).toIso8601String(),
    );
  }

  test(
    'creates and persists the clan profile for the current clan context',
    () async {
      final repository = DebugClanRepository.empty();
      final session = buildAdminSession();

      final before = await repository.loadWorkspace(session: session);
      expect(before.clan, isNull);

      await repository.saveClan(
        session: session,
        draft: const ClanDraft(
          name: 'Họ Phạm Hưng',
          slug: 'ho-pham-hung',
          description: 'Kho dữ liệu họ tộc cho bài test.',
          countryCode: 'VN',
          founderName: 'Phạm Hưng tổ',
          logoUrl: '',
        ),
      );

      final after = await repository.loadWorkspace(session: session);
      expect(after.clan, isNotNull);
      expect(after.clan?.name, 'Họ Phạm Hưng');
      expect(after.clan?.slug, 'ho-pham-hung');
    },
  );

  test('creates a branch and keeps the selected leader assignments', () async {
    final repository = DebugClanRepository.seeded();
    final session = buildAdminSession();

    final branch = await repository.saveBranch(
      session: session,
      draft: const BranchDraft(
        name: 'Chi Alpha',
        code: 'CA03',
        generationLevelHint: 5,
        leaderMemberId: 'member_demo_parent_001',
        viceLeaderMemberId: 'member_demo_parent_002',
      ),
    );

    expect(branch.name, 'Chi Alpha');
    expect(branch.leaderMemberId, 'member_demo_parent_001');
    expect(branch.viceLeaderMemberId, 'member_demo_parent_002');

    final snapshot = await repository.loadWorkspace(session: session);
    final created = snapshot.branches.firstWhere(
      (candidate) => candidate.id == branch.id,
    );
    expect(created.code, 'CA03');
    expect(created.generationLevelHint, 5);
    expect(created.leaderMemberId, 'member_demo_parent_001');
    expect(created.viceLeaderMemberId, 'member_demo_parent_002');
  });
}
