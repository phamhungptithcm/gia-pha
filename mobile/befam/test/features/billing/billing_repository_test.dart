import '../../support/core/services/debug_genealogy_store.dart';
import 'package:befam/features/auth/models/auth_entry_method.dart';
import 'package:befam/features/auth/models/auth_member_access_mode.dart';
import 'package:befam/features/auth/models/auth_session.dart';
import '../../support/features/billing/services/debug_billing_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  AuthSession buildSession({required String clanId}) {
    return AuthSession(
      uid: 'debug:+84901234567',
      loginMethod: AuthEntryMethod.phone,
      phoneE164: '+84901234567',
      displayName: 'Nguyễn Minh',
      memberId: 'member_${clanId}_0',
      clanId: clanId,
      branchId: 'branch_demo_001',
      primaryRole: 'CLAN_ADMIN',
      accessMode: AuthMemberAccessMode.claimed,
      linkedAuthUid: true,
      isSandbox: true,
      signedInAtIso: DateTime(2026, 3, 15).toIso8601String(),
    );
  }

  AuthSession buildNoClanSession({String uid = 'debug:billing_repo_no_clan'}) {
    return AuthSession(
      uid: uid,
      loginMethod: AuthEntryMethod.phone,
      phoneE164: '+84900000000',
      displayName: 'Người dùng chưa có gia phả',
      memberId: null,
      clanId: null,
      branchId: null,
      primaryRole: 'MEMBER',
      accessMode: AuthMemberAccessMode.unlinked,
      linkedAuthUid: false,
      isSandbox: true,
      signedInAtIso: DateTime(2026, 3, 15).toIso8601String(),
    );
  }

  void seedClanMembers({required String clanId, required int count}) {
    final store = DebugGenealogyStore.sharedSeeded();
    final template = store.members['member_demo_parent_001']!;
    store.members.removeWhere((key, _) => key.startsWith('member_${clanId}_'));
    for (var index = 0; index < count; index += 1) {
      final id = 'member_${clanId}_$index';
      store.members[id] = template.copyWith(
        id: id,
        clanId: clanId,
        fullName: 'Billing Member $index',
        normalizedFullName: 'billing member $index',
        authUid: null,
        primaryRole: 'MEMBER',
      );
    }
  }

  test(
    'debug billing repository loads workspace and free-plan entitlement',
    () async {
      const clanId = 'clan_billing_repo_free';
      seedClanMembers(clanId: clanId, count: 8);

      final repository = DebugBillingRepository.shared();
      final snapshot = await repository.loadWorkspace(
        session: buildSession(clanId: clanId),
      );

      expect(snapshot.clanId, clanId);
      expect(snapshot.subscription.planCode, 'FREE');
      expect(snapshot.entitlement.showAds, isTrue);
      expect(snapshot.pricingTiers, isNotEmpty);
    },
  );

  test(
    'debug billing repository supports personal scope when user has no clan',
    () async {
      final repository = DebugBillingRepository.shared();
      final session = buildNoClanSession();
      final snapshot = await repository.loadWorkspace(session: session);

      expect(snapshot.clanId, 'user_scope__${session.uid}');
      expect(snapshot.memberCount, 0);
      expect(snapshot.subscription.planCode, 'FREE');
    },
  );

  test('debug billing repository updates billing preferences', () async {
    const clanId = 'clan_billing_repo_preferences';
    seedClanMembers(clanId: clanId, count: 40);

    final repository = DebugBillingRepository.shared();
    final settings = await repository.updatePreferences(
      session: buildSession(clanId: clanId),
      paymentMode: 'auto_renew',
      autoRenew: true,
      reminderDaysBefore: const [21, 7, 1],
    );

    expect(settings.paymentMode, 'auto_renew');
    expect(settings.autoRenew, isTrue);
    expect(settings.reminderDaysBefore, containsAll(<int>[21, 7, 1]));
  });

}
