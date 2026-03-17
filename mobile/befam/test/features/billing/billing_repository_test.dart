import 'package:befam/core/services/debug_genealogy_store.dart';
import 'package:befam/features/auth/models/auth_entry_method.dart';
import 'package:befam/features/auth/models/auth_member_access_mode.dart';
import 'package:befam/features/auth/models/auth_session.dart';
import 'package:befam/features/billing/services/debug_billing_repository.dart';
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

      final checkout = await repository.createCheckout(
        session: session,
        paymentMethod: 'vnpay',
        requestedPlanCode: 'BASE',
      );
      expect(checkout.planCode, 'BASE');
      expect(checkout.amountVnd, 49000);
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

  test(
    'debug billing repository creates checkout for paid tier and settles payment',
    () async {
      const clanId = 'clan_billing_repo_paid';
      seedClanMembers(clanId: clanId, count: 80);

      final repository = DebugBillingRepository.shared();
      final checkout = await repository.createCheckout(
        session: buildSession(clanId: clanId),
        paymentMethod: 'card',
      );
      expect(checkout.planCode, isNot('FREE'));
      expect(checkout.amountVnd, greaterThan(0));
      expect(checkout.requiresManualConfirmation, isTrue);

      await repository.completeCardCheckout(
        session: buildSession(clanId: clanId),
        transactionId: checkout.transactionId,
      );

      final snapshot = await repository.loadWorkspace(
        session: buildSession(clanId: clanId),
      );
      expect(snapshot.subscription.status, 'active');
      expect(snapshot.entitlement.hasPremiumAccess, isTrue);
    },
  );

  test(
    'debug billing repository keeps current subscription until requested plan is paid',
    () async {
      const clanId = 'clan_billing_repo_requested_plan';
      seedClanMembers(clanId: clanId, count: 90); // minimum BASE

      final repository = DebugBillingRepository.shared();
      final checkout = await repository.createCheckout(
        session: buildSession(clanId: clanId),
        paymentMethod: 'vnpay',
        requestedPlanCode: 'PLUS',
      );

      expect(checkout.planCode, 'PLUS');
      expect(checkout.subscription.status, 'expired');

      final snapshot = await repository.loadWorkspace(
        session: buildSession(clanId: clanId),
      );
      expect(snapshot.subscription.planCode, 'BASE');
      expect(snapshot.subscription.status, 'expired');
    },
  );

  test(
    'debug billing repository rejects requestedPlanCode below member-count minimum',
    () async {
      const clanId = 'clan_billing_repo_invalid_plan';
      seedClanMembers(clanId: clanId, count: 60); // minimum BASE

      final repository = DebugBillingRepository.shared();
      expect(
        () => repository.createCheckout(
          session: buildSession(clanId: clanId),
          paymentMethod: 'card',
          requestedPlanCode: 'FREE',
        ),
        throwsA(
          isA<Exception>().having(
            (error) => error.toString(),
            'error',
            contains('requestedPlanCode is below minimum tier'),
          ),
        ),
      );
    },
  );

  test(
    'debug billing repository allows downgrade when member count fits target tier',
    () async {
      const clanId = 'clan_billing_repo_downgrade_allowed';
      seedClanMembers(clanId: clanId, count: 220); // minimum PLUS

      final repository = DebugBillingRepository.shared();
      final upgradeCheckout = await repository.createCheckout(
        session: buildSession(clanId: clanId),
        paymentMethod: 'card',
        requestedPlanCode: 'PRO',
      );
      await repository.completeCardCheckout(
        session: buildSession(clanId: clanId),
        transactionId: upgradeCheckout.transactionId,
      );

      seedClanMembers(clanId: clanId, count: 120); // minimum BASE
      final downgradeCheckout = await repository.createCheckout(
        session: buildSession(clanId: clanId),
        paymentMethod: 'vnpay',
        requestedPlanCode: 'BASE',
      );

      expect(downgradeCheckout.planCode, 'BASE');
      expect(downgradeCheckout.amountVnd, 49000);
      expect(downgradeCheckout.subscription.planCode, 'PRO');
    },
  );

  test(
    'debug billing repository keeps upgraded plan when member count decreases',
    () async {
      const clanId = 'clan_billing_repo_no_downgrade';
      seedClanMembers(clanId: clanId, count: 260); // minimum PLUS

      final repository = DebugBillingRepository.shared();
      final checkout = await repository.createCheckout(
        session: buildSession(clanId: clanId),
        paymentMethod: 'card',
        requestedPlanCode: 'PLUS',
      );
      await repository.completeCardCheckout(
        session: buildSession(clanId: clanId),
        transactionId: checkout.transactionId,
      );

      seedClanMembers(clanId: clanId, count: 50); // minimum drops to BASE
      final snapshot = await repository.loadWorkspace(
        session: buildSession(clanId: clanId),
      );

      expect(snapshot.memberCount, 50);
      expect(snapshot.subscription.planCode, 'PLUS');
    },
  );
}
