import 'package:befam/core/services/debug_genealogy_store.dart';
import 'package:befam/features/auth/models/auth_entry_method.dart';
import 'package:befam/features/auth/models/auth_member_access_mode.dart';
import 'package:befam/features/auth/models/auth_session.dart';
import 'package:befam/features/billing/services/debug_billing_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  AuthSession buildSession() {
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
      signedInAtIso: DateTime(2026, 3, 15).toIso8601String(),
    );
  }

  test('debug billing repository loads workspace and free-plan entitlement', () async {
    final repository = DebugBillingRepository.shared();
    final snapshot = await repository.loadWorkspace(session: buildSession());

    expect(snapshot.clanId, 'clan_demo_001');
    expect(snapshot.subscription.planCode, 'FREE');
    expect(snapshot.entitlement.showAds, isTrue);
    expect(snapshot.pricingTiers, isNotEmpty);
  });

  test('debug billing repository updates billing preferences', () async {
    final repository = DebugBillingRepository.shared();
    final settings = await repository.updatePreferences(
      session: buildSession(),
      paymentMode: 'auto_renew',
      autoRenew: true,
      reminderDaysBefore: const [21, 7, 1],
    );

    expect(settings.paymentMode, 'auto_renew');
    expect(settings.autoRenew, isTrue);
    expect(settings.reminderDaysBefore, containsAll(<int>[21, 7, 1]));
  });

  test('debug billing repository creates checkout for paid tier and settles payment', () async {
    final store = DebugGenealogyStore.sharedSeeded();
    for (var index = 0; index < 20; index += 1) {
      store.members['member_billing_test_$index'] =
          store.members['member_demo_parent_001']!.copyWith(
            id: 'member_billing_test_$index',
            fullName: 'Billing Test Member $index',
            normalizedFullName: 'billing test member $index',
            authUid: null,
            primaryRole: 'MEMBER',
          );
    }

    final repository = DebugBillingRepository.shared();
    final checkout = await repository.createCheckout(
      session: buildSession(),
      paymentMethod: 'card',
    );
    expect(checkout.planCode, isNot('FREE'));
    expect(checkout.amountVnd, greaterThan(0));
    expect(checkout.requiresManualConfirmation, isTrue);

    await repository.completeCardCheckout(
      session: buildSession(),
      transactionId: checkout.transactionId,
    );

    final snapshot = await repository.loadWorkspace(session: buildSession());
    expect(snapshot.subscription.status, 'active');
    expect(snapshot.entitlement.hasPremiumAccess, isTrue);
  });
}
