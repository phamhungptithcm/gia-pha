import '../../../core/services/governance_role_matrix.dart';
import '../../auth/models/auth_session.dart';
import '../../scholarship/services/debug_scholarship_repository.dart';
import '../../scholarship/services/scholarship_repository.dart';
import '../models/treasurer_dashboard_snapshot.dart';
import 'debug_fund_repository.dart';
import 'fund_repository.dart';
import 'treasurer_dashboard_repository.dart';

class DebugTreasurerDashboardRepository
    implements TreasurerDashboardRepository {
  DebugTreasurerDashboardRepository({
    required FundRepository fundRepository,
    required ScholarshipRepository scholarshipRepository,
  }) : _fundRepository = fundRepository,
       _scholarshipRepository = scholarshipRepository;

  factory DebugTreasurerDashboardRepository.seeded() {
    return DebugTreasurerDashboardRepository(
      fundRepository: DebugFundRepository.seeded(),
      scholarshipRepository: DebugScholarshipRepository.seeded(),
    );
  }

  factory DebugTreasurerDashboardRepository.shared() {
    return DebugTreasurerDashboardRepository(
      fundRepository: DebugFundRepository.shared(),
      scholarshipRepository: DebugScholarshipRepository.shared(),
    );
  }

  final FundRepository _fundRepository;
  final ScholarshipRepository _scholarshipRepository;

  @override
  bool get isSandbox => true;

  @override
  Future<TreasurerDashboardSnapshot> loadDashboard({
    required AuthSession session,
  }) async {
    if (!GovernanceRoleMatrix.canViewFinance(session)) {
      throw const TreasurerDashboardRepositoryException(
        TreasurerDashboardRepositoryErrorCode.permissionDenied,
      );
    }

    final clanId = (session.clanId ?? '').trim();
    if (clanId.isEmpty) {
      return TreasurerDashboardSnapshot.empty();
    }

    final fundSnapshot = await _fundRepository.loadWorkspace(session: session);
    final privilegedScholarshipSession = session.copyWith(
      primaryRole: GovernanceRoles.scholarshipCouncilHead,
    );
    final scholarshipSnapshot = await _scholarshipRepository.loadWorkspace(
      session: privilegedScholarshipSession,
    );

    final scholarshipRequests =
        scholarshipSnapshot.submissions
            .where((submission) => submission.clanId == clanId)
            .toList(growable: false)
          ..sort(
            (left, right) => right.updatedAtIso.compareTo(left.updatedAtIso),
          );

    final totalDonationsMinor = fundSnapshot.transactions
        .where((transaction) => transaction.isDonation)
        .fold<int>(0, (sum, transaction) => sum + transaction.amountMinor);
    final totalExpensesMinor = fundSnapshot.transactions
        .where((transaction) => transaction.isExpense)
        .fold<int>(0, (sum, transaction) => sum + transaction.amountMinor);

    final reportSummary = [
      'Finance summary for clan $clanId',
      'Total balance: ${fundSnapshot.funds.fold<int>(0, (sum, fund) => sum + fund.balanceMinor)} minor units',
      'Donations tracked: $totalDonationsMinor minor units',
      'Expenses tracked: $totalExpensesMinor minor units',
      'Scholarship requests tracked: ${scholarshipRequests.length}',
      'Generated at: ${DateTime.now().toUtc().toIso8601String()}',
    ].join('\n');

    return TreasurerDashboardSnapshot(
      clanId: clanId,
      totals: TreasurerDashboardTotals(
        totalBalanceMinor: fundSnapshot.funds.fold<int>(
          0,
          (sum, fund) => sum + fund.balanceMinor,
        ),
        totalDonationsMinor: totalDonationsMinor,
        totalExpensesMinor: totalExpensesMinor,
      ),
      funds: fundSnapshot.funds,
      transactions: fundSnapshot.transactions,
      scholarshipRequests: scholarshipRequests,
      reportSummary: reportSummary,
    );
  }
}
