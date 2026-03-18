import '../../scholarship/models/achievement_submission.dart';
import 'fund_profile.dart';
import 'fund_transaction.dart';

class TreasurerDashboardTotals {
  const TreasurerDashboardTotals({
    required this.totalBalanceMinor,
    required this.totalDonationsMinor,
    required this.totalExpensesMinor,
  });

  const TreasurerDashboardTotals.zero()
    : totalBalanceMinor = 0,
      totalDonationsMinor = 0,
      totalExpensesMinor = 0;

  final int totalBalanceMinor;
  final int totalDonationsMinor;
  final int totalExpensesMinor;
}

class TreasurerDashboardSnapshot {
  const TreasurerDashboardSnapshot({
    required this.clanId,
    required this.totals,
    required this.funds,
    required this.transactions,
    required this.scholarshipRequests,
    required this.reportSummary,
  });

  factory TreasurerDashboardSnapshot.empty({String clanId = ''}) {
    return TreasurerDashboardSnapshot(
      clanId: clanId,
      totals: const TreasurerDashboardTotals.zero(),
      funds: const [],
      transactions: const [],
      scholarshipRequests: const [],
      reportSummary: '',
    );
  }

  final String clanId;
  final TreasurerDashboardTotals totals;
  final List<FundProfile> funds;
  final List<FundTransaction> transactions;
  final List<AchievementSubmission> scholarshipRequests;
  final String reportSummary;

  List<FundTransaction> get donationHistory {
    return transactions
        .where((transaction) => transaction.isDonation)
        .toList(growable: false);
  }
}
