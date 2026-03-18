import 'package:befam/features/auth/models/auth_entry_method.dart';
import 'package:befam/features/auth/models/auth_member_access_mode.dart';
import 'package:befam/features/auth/models/auth_session.dart';
import 'package:befam/features/funds/services/debug_treasurer_dashboard_repository.dart';
import 'package:befam/features/funds/services/treasurer_dashboard_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  AuthSession buildSession({required String role}) {
    return AuthSession(
      uid: 'debug:+84901234567',
      loginMethod: AuthEntryMethod.phone,
      phoneE164: '+84901234567',
      displayName: 'Nguyễn Minh',
      memberId: 'member_demo_parent_001',
      clanId: 'clan_demo_001',
      branchId: 'branch_demo_001',
      primaryRole: role,
      accessMode: AuthMemberAccessMode.claimed,
      linkedAuthUid: true,
      isSandbox: true,
      signedInAtIso: DateTime(2026, 3, 18).toIso8601String(),
    );
  }

  test('loads treasurer dashboard with fund and scholarship history', () async {
    final repository = DebugTreasurerDashboardRepository.seeded();
    final session = buildSession(role: 'TREASURER');

    final snapshot = await repository.loadDashboard(session: session);

    expect(snapshot.clanId, 'clan_demo_001');
    expect(snapshot.totals.totalBalanceMinor, greaterThan(0));
    expect(snapshot.donationHistory, isNotEmpty);
    expect(snapshot.scholarshipRequests, hasLength(2));
    expect(
      snapshot.reportSummary,
      contains('Finance summary for clan clan_demo_001'),
    );
  });

  test('keeps donation history ordered by occurred date descending', () async {
    final repository = DebugTreasurerDashboardRepository.seeded();
    final session = buildSession(role: 'CLAN_ADMIN');

    final snapshot = await repository.loadDashboard(session: session);
    final history = snapshot.donationHistory;

    expect(history.length, greaterThan(1));
    for (var i = 0; i < history.length - 1; i++) {
      expect(
        history[i].occurredAt.isAfter(history[i + 1].occurredAt) ||
            history[i].occurredAt.isAtSameMomentAs(history[i + 1].occurredAt),
        isTrue,
      );
    }
  });

  test('denies dashboard access for non-finance role', () async {
    final repository = DebugTreasurerDashboardRepository.seeded();
    final session = buildSession(role: 'MEMBER');

    expect(
      () => repository.loadDashboard(session: session),
      throwsA(
        isA<TreasurerDashboardRepositoryException>().having(
          (error) => error.code,
          'code',
          TreasurerDashboardRepositoryErrorCode.permissionDenied,
        ),
      ),
    );
  });
}
