import 'fund_profile.dart';
import 'fund_transaction.dart';

class FundWorkspaceSnapshot {
  const FundWorkspaceSnapshot({
    required this.funds,
    required this.transactions,
  });

  final List<FundProfile> funds;
  final List<FundTransaction> transactions;
}
