import '../../../core/services/runtime_mode.dart';
import '../../auth/models/auth_session.dart';
import '../models/billing_workspace_snapshot.dart';
import 'debug_billing_repository.dart';
import 'firebase_billing_repository.dart';

enum BillingRepositoryErrorCode {
  permissionDenied,
  invalidArgument,
  failedPrecondition,
  notFound,
  unavailable,
  unknown,
}

class BillingRepositoryException implements Exception {
  const BillingRepositoryException(this.code, [this.message]);

  final BillingRepositoryErrorCode code;
  final String? message;

  @override
  String toString() => message ?? code.name;
}

abstract interface class BillingRepository {
  bool get isSandbox;

  Future<BillingWorkspaceSnapshot> loadWorkspace({required AuthSession session});

  Future<BillingEntitlement> resolveEntitlement({required AuthSession session});

  Future<BillingSettings> updatePreferences({
    required AuthSession session,
    required String paymentMode,
    required bool autoRenew,
    List<int>? reminderDaysBefore,
  });

  Future<BillingCheckoutResult> createCheckout({
    required AuthSession session,
    required String paymentMethod,
    String? returnUrl,
  });

  Future<void> completeCardCheckout({
    required AuthSession session,
    required String transactionId,
  });

  Future<void> settleVnpayCheckout({
    required AuthSession session,
    required String transactionId,
  });
}

BillingRepository createDefaultBillingRepository() {
  if (RuntimeMode.shouldUseMockBackend) {
    return DebugBillingRepository.shared();
  }

  return FirebaseBillingRepository();
}
