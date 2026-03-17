import 'package:befam/core/services/debug_genealogy_store.dart';
import 'package:befam/features/auth/models/auth_entry_method.dart';
import 'package:befam/features/auth/models/auth_member_access_mode.dart';
import 'package:befam/features/auth/models/auth_session.dart';
import 'package:befam/features/relationship/services/debug_relationship_repository.dart';
import 'package:befam/features/relationship/services/relationship_repository.dart';
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

  AuthSession buildBranchAdminSession() {
    return AuthSession(
      uid: 'debug:+84908886655',
      loginMethod: AuthEntryMethod.phone,
      phoneE164: '+84908886655',
      displayName: 'Trần Văn Long',
      memberId: 'member_demo_parent_002',
      clanId: 'clan_demo_001',
      branchId: 'branch_demo_002',
      primaryRole: 'BRANCH_ADMIN',
      accessMode: AuthMemberAccessMode.claimed,
      linkedAuthUid: true,
      isSandbox: true,
      signedInAtIso: DateTime(2026, 3, 14).toIso8601String(),
    );
  }

  test(
    'creates a parent-child relationship and reconciles member arrays',
    () async {
      final store = DebugGenealogyStore.seeded();
      final repository = DebugRelationshipRepository(store: store);
      final session = buildClanAdminSession();

      final created = await repository.createParentChildRelationship(
        session: session,
        parentId: 'member_demo_parent_001',
        childId: 'member_demo_elder_001',
      );

      expect(created.type.wireName, 'parent_child');
      expect(
        store.members['member_demo_parent_001']?.childrenIds,
        contains('member_demo_elder_001'),
      );
      expect(
        store.members['member_demo_elder_001']?.parentIds,
        contains('member_demo_parent_001'),
      );
    },
  );

  test('prevents duplicate spouse edges', () async {
    final store = DebugGenealogyStore.seeded();
    final repository = DebugRelationshipRepository(store: store);
    final session = buildClanAdminSession();

    await repository.createSpouseRelationship(
      session: session,
      memberId: 'member_demo_parent_001',
      spouseId: 'member_demo_elder_001',
    );

    expect(
      () => repository.createSpouseRelationship(
        session: session,
        memberId: 'member_demo_elder_001',
        spouseId: 'member_demo_parent_001',
      ),
      throwsA(
        isA<RelationshipRepositoryException>().having(
          (error) => error.code,
          'code',
          RelationshipRepositoryErrorCode.duplicateSpouse,
        ),
      ),
    );
  });

  test('prevents parent-child cycles', () async {
    final store = DebugGenealogyStore.seeded();
    final repository = DebugRelationshipRepository(store: store);
    final session = buildClanAdminSession();

    expect(
      () => repository.createParentChildRelationship(
        session: session,
        parentId: 'member_demo_child_001',
        childId: 'member_demo_parent_001',
      ),
      throwsA(
        isA<RelationshipRepositoryException>().having(
          (error) => error.code,
          'code',
          RelationshipRepositoryErrorCode.cycleDetected,
        ),
      ),
    );
  });

  test(
    'blocks branch admins from editing relationships outside their branch',
    () async {
      final store = DebugGenealogyStore.seeded();
      final repository = DebugRelationshipRepository(store: store);
      final session = buildBranchAdminSession();

      expect(
        () => repository.createSpouseRelationship(
          session: session,
          memberId: 'member_demo_parent_002',
          spouseId: 'member_demo_parent_001',
        ),
        throwsA(
          isA<RelationshipRepositoryException>().having(
            (error) => error.code,
            'code',
            RelationshipRepositoryErrorCode.permissionDenied,
          ),
        ),
      );
    },
  );
}
