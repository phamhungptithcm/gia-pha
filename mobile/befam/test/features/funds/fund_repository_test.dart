import 'package:befam/features/auth/models/auth_entry_method.dart';
import 'package:befam/features/auth/models/auth_member_access_mode.dart';
import 'package:befam/features/auth/models/auth_session.dart';
import 'package:befam/features/funds/models/fund_draft.dart';
import 'package:befam/features/funds/models/fund_transaction.dart';
import 'package:befam/features/funds/models/fund_transaction_draft.dart';
import 'package:befam/features/funds/services/debug_fund_repository.dart';
import 'package:befam/features/funds/services/fund_repository.dart';
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

  test('loads seeded funds and transactions', () async {
    final repository = DebugFundRepository.seeded();
    final session = buildClanAdminSession();

    final snapshot = await repository.loadWorkspace(session: session);

    expect(snapshot.funds, hasLength(2));
    expect(snapshot.transactions, hasLength(4));

    final scholarship = snapshot.funds.firstWhere(
      (fund) => fund.id == 'fund_demo_scholarship',
    );
    expect(scholarship.balanceMinor, 2500000);
  });

  test('creates a new fund with zero starting balance', () async {
    final repository = DebugFundRepository.seeded();
    final session = buildClanAdminSession();

    final created = await repository.saveFund(
      session: session,
      draft: const FundDraft(
        name: 'Temple Maintenance',
        description: 'Keeps yearly maintenance transparent.',
        fundType: 'maintenance',
        currency: 'VND',
      ),
    );

    expect(created.name, 'Temple Maintenance');
    expect(created.balanceMinor, 0);

    final snapshot = await repository.loadWorkspace(session: session);
    expect(snapshot.funds.any((fund) => fund.id == created.id), isTrue);
  });

  test('records donation and updates running balance', () async {
    final repository = DebugFundRepository.seeded();
    final session = buildClanAdminSession();

    final before = await repository.loadWorkspace(session: session);
    final fund = before.funds.firstWhere(
      (candidate) => candidate.id == 'fund_demo_operations',
    );

    final donation = await repository.recordTransaction(
      session: session,
      draft: FundTransactionDraft(
        fundId: fund.id,
        transactionType: FundTransactionType.donation,
        amountInput: '500000',
        currency: fund.currency,
        occurredAt: DateTime.utc(2026, 3, 13, 2, 0),
        note: 'Quarterly contribution',
      ),
    );

    expect(donation.amountMinor, 500000);

    final after = await repository.loadWorkspace(session: session);
    final updatedFund = after.funds.firstWhere(
      (candidate) => candidate.id == fund.id,
    );
    expect(updatedFund.balanceMinor, fund.balanceMinor + 500000);
  });

  test('rejects expense that exceeds balance', () async {
    final repository = DebugFundRepository.seeded();
    final session = buildClanAdminSession();

    expect(
      () => repository.recordTransaction(
        session: session,
        draft: FundTransactionDraft(
          fundId: 'fund_demo_operations',
          transactionType: FundTransactionType.expense,
          amountInput: '999999999',
          currency: 'VND',
          occurredAt: DateTime.utc(2026, 3, 13, 4, 0),
          note: 'Invalid overdraw',
        ),
      ),
      throwsA(
        isA<FundRepositoryException>().having(
          (error) => error.code,
          'code',
          FundRepositoryErrorCode.insufficientBalance,
        ),
      ),
    );
  });
}
