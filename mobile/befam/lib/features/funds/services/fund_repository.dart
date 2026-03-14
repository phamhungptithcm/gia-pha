import '../../../core/services/runtime_mode.dart';
import '../../auth/models/auth_session.dart';
import '../models/fund_draft.dart';
import '../models/fund_profile.dart';
import '../models/fund_transaction.dart';
import '../models/fund_transaction_draft.dart';
import '../models/fund_workspace_snapshot.dart';
import 'debug_fund_repository.dart';
import 'firebase_fund_repository.dart';

enum FundRepositoryErrorCode {
  permissionDenied,
  fundNotFound,
  invalidCurrency,
  invalidAmount,
  insufficientBalance,
  validationFailed,
  writeFailed,
}

class FundRepositoryException implements Exception {
  const FundRepositoryException(this.code, [this.message]);

  final FundRepositoryErrorCode code;
  final String? message;

  @override
  String toString() => message ?? code.name;
}

abstract interface class FundRepository {
  bool get isSandbox;

  Future<FundWorkspaceSnapshot> loadWorkspace({required AuthSession session});

  Future<FundProfile> saveFund({
    required AuthSession session,
    String? fundId,
    required FundDraft draft,
  });

  Future<FundTransaction> recordTransaction({
    required AuthSession session,
    required FundTransactionDraft draft,
  });
}

FundRepository createDefaultFundRepository() {
  if (RuntimeMode.shouldUseMockBackend) {
    return DebugFundRepository.shared();
  }

  return FirebaseFundRepository();
}
