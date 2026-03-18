import '../../../core/services/runtime_mode.dart';
import '../../auth/models/auth_session.dart';
import '../models/treasurer_dashboard_snapshot.dart';
import 'debug_treasurer_dashboard_repository.dart';
import 'firebase_treasurer_dashboard_repository.dart';

enum TreasurerDashboardRepositoryErrorCode { permissionDenied, fetchFailed }

class TreasurerDashboardRepositoryException implements Exception {
  const TreasurerDashboardRepositoryException(this.code, [this.message]);

  final TreasurerDashboardRepositoryErrorCode code;
  final String? message;

  @override
  String toString() => message ?? code.name;
}

abstract interface class TreasurerDashboardRepository {
  bool get isSandbox;

  Future<TreasurerDashboardSnapshot> loadDashboard({
    required AuthSession session,
  });
}

TreasurerDashboardRepository createDefaultTreasurerDashboardRepository({
  AuthSession? session,
}) {
  final useMockBackend = session?.isSandbox ?? RuntimeMode.shouldUseMockBackend;
  if (useMockBackend) {
    return DebugTreasurerDashboardRepository.shared();
  }
  return FirebaseTreasurerDashboardRepository();
}
