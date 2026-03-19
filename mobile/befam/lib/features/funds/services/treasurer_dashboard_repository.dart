import '../../auth/models/auth_session.dart';
import '../models/treasurer_dashboard_snapshot.dart';
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
  return FirebaseTreasurerDashboardRepository();
}
