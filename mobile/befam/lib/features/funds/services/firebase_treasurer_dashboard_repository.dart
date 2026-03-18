import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../../core/services/app_environment.dart';
import '../../../core/services/firebase_services.dart';
import '../../../core/services/firebase_session_access_sync.dart';
import '../../../core/services/governance_role_matrix.dart';
import '../../auth/models/auth_session.dart';
import '../../scholarship/models/achievement_submission.dart';
import '../models/fund_profile.dart';
import '../models/fund_transaction.dart';
import '../models/treasurer_dashboard_snapshot.dart';
import 'treasurer_dashboard_repository.dart';

class FirebaseTreasurerDashboardRepository
    implements TreasurerDashboardRepository {
  FirebaseTreasurerDashboardRepository({
    FirebaseFunctions? functions,
    FirebaseFirestore? firestore,
  }) : _functions =
           functions ??
           FirebaseFunctions.instanceFor(
             region: AppEnvironment.firebaseFunctionsRegion,
           ),
       _firestore = firestore ?? FirebaseServices.firestore;

  final FirebaseFunctions _functions;
  final FirebaseFirestore _firestore;

  @override
  bool get isSandbox => false;

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

    await FirebaseSessionAccessSync.ensureUserSessionDocument(
      firestore: _firestore,
      session: session,
    );

    try {
      final callable = _functions.httpsCallable('getTreasurerDashboard');
      final response = await callable.call(<String, dynamic>{'clanId': clanId});
      final payload = _asMap(response.data);
      final totalsPayload = _asMap(payload['totals']);
      final funds = _asListOfMap(
        payload['funds'],
      ).map(FundProfile.fromJson).toList(growable: false);
      final transactions =
          _asListOfMap(
            payload['transactions'],
          ).map(FundTransaction.fromJson).toList(growable: false)..sort(
            (left, right) => right.occurredAt.compareTo(left.occurredAt),
          );

      final scholarshipPayload =
          payload['scholarshipRequestHistory'] ??
          payload['scholarshipRequests'];
      final scholarshipRequests =
          _asListOfMap(
            scholarshipPayload,
          ).map(AchievementSubmission.fromJson).toList(growable: false)..sort(
            (left, right) => _parseIso(
              right.updatedAtIso,
            ).compareTo(_parseIso(left.updatedAtIso)),
          );

      return TreasurerDashboardSnapshot(
        clanId: _asString(payload['clanId']) ?? clanId,
        totals: TreasurerDashboardTotals(
          totalBalanceMinor: _asInt(totalsPayload['totalBalanceMinor']),
          totalDonationsMinor: _asInt(totalsPayload['totalDonationsMinor']),
          totalExpensesMinor: _asInt(totalsPayload['totalExpensesMinor']),
        ),
        funds: funds,
        transactions: transactions,
        scholarshipRequests: scholarshipRequests,
        reportSummary: _asString(payload['reportSummary']) ?? '',
      );
    } on FirebaseFunctionsException catch (error) {
      if (error.code == 'permission-denied') {
        throw const TreasurerDashboardRepositoryException(
          TreasurerDashboardRepositoryErrorCode.permissionDenied,
        );
      }
      throw TreasurerDashboardRepositoryException(
        TreasurerDashboardRepositoryErrorCode.fetchFailed,
        error.message ?? error.code,
      );
    } catch (error) {
      throw TreasurerDashboardRepositoryException(
        TreasurerDashboardRepositoryErrorCode.fetchFailed,
        error.toString(),
      );
    }
  }
}

Map<String, dynamic> _asMap(Object? value) {
  if (value is! Map) {
    return const {};
  }
  return value.map((key, entry) => MapEntry(key.toString(), entry));
}

List<Map<String, dynamic>> _asListOfMap(Object? value) {
  if (value is! List) {
    return const [];
  }
  return value
      .whereType<Map>()
      .map((entry) => entry.map((key, raw) => MapEntry(key.toString(), raw)))
      .toList(growable: false);
}

String? _asString(Object? value) {
  final text = value is String ? value.trim() : '';
  return text.isEmpty ? null : text;
}

int _asInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is double) {
    return value.round();
  }
  if (value is String) {
    return int.tryParse(value) ?? 0;
  }
  return 0;
}

DateTime _parseIso(String value) {
  final parsed = DateTime.tryParse(value);
  return parsed?.toUtc() ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
}
