import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:collection/collection.dart';

import '../../../core/services/firebase_services.dart';
import '../../../core/services/firebase_session_access_sync.dart';
import '../../../core/services/governance_role_matrix.dart';
import '../../auth/models/auth_session.dart';
import '../models/fund_draft.dart';
import '../models/fund_profile.dart';
import '../models/fund_transaction.dart';
import '../models/fund_transaction_draft.dart';
import '../models/fund_workspace_snapshot.dart';
import 'currency_minor_units.dart';
import 'fund_repository.dart';

class FirebaseFundRepository implements FundRepository {
  FirebaseFundRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) : _firestore = firestore ?? FirebaseServices.firestore,
       _functions = functions ?? FirebaseServices.functions;

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  CollectionReference<Map<String, dynamic>> get _funds =>
      _firestore.collection('funds');

  CollectionReference<Map<String, dynamic>> get _transactions =>
      _firestore.collection('transactions');

  CollectionReference<Map<String, dynamic>> get _members =>
      _firestore.collection('members');

  @override
  bool get isSandbox => false;

  @override
  Future<FundWorkspaceSnapshot> loadWorkspace({
    required AuthSession session,
  }) async {
    await FirebaseSessionAccessSync.ensureUserSessionDocument(
      firestore: _firestore,
      session: session,
    );

    final clanId = session.clanId;
    if (clanId == null || clanId.isEmpty) {
      return const FundWorkspaceSnapshot(funds: [], transactions: []);
    }

    final results = await Future.wait<QuerySnapshot<Map<String, dynamic>>>([
      _funds.where('clanId', isEqualTo: clanId).get(),
      _loadTransactionSnapshot(clanId: clanId),
    ]);

    final funds = results[0].docs
        .map(
          (doc) => FundProfile.fromJson(
            _normalizeFirestoreMap(doc.data(), fallbackId: doc.id),
          ),
        )
        .sortedBy((fund) => fund.name.toLowerCase())
        .toList(growable: false);

    final transactions = results[1].docs
        .map(
          (doc) => FundTransaction.fromJson(
            _normalizeFirestoreMap(doc.data(), fallbackId: doc.id),
          ),
        )
        .sorted((left, right) => right.occurredAt.compareTo(left.occurredAt))
        .take(400)
        .toList(growable: false);

    return FundWorkspaceSnapshot(funds: funds, transactions: transactions);
  }

  Future<QuerySnapshot<Map<String, dynamic>>> _loadTransactionSnapshot({
    required String clanId,
  }) async {
    final baseQuery = _transactions.where('clanId', isEqualTo: clanId);
    try {
      return await baseQuery
          .orderBy('occurredAt', descending: true)
          .limit(400)
          .get();
    } on FirebaseException catch (error) {
      if (_isMissingCompositeIndex(error)) {
        return baseQuery.limit(1200).get();
      }
      rethrow;
    }
  }

  bool _isMissingCompositeIndex(FirebaseException error) {
    if (error.code != 'failed-precondition') {
      return false;
    }
    final message = (error.message ?? '').toLowerCase();
    return message.contains('requires an index');
  }

  @override
  Future<FundProfile> saveFund({
    required AuthSession session,
    String? fundId,
    required FundDraft draft,
  }) async {
    await FirebaseSessionAccessSync.ensureUserSessionDocument(
      firestore: _firestore,
      session: session,
    );

    final sessionClanId = session.clanId?.trim() ?? '';
    if (sessionClanId.isEmpty) {
      throw const FundRepositoryException(
        FundRepositoryErrorCode.permissionDenied,
      );
    }
    final targetClanId = (draft.clanId ?? '').trim().isEmpty
        ? sessionClanId
        : draft.clanId!.trim();
    if (targetClanId != sessionClanId) {
      throw const FundRepositoryException(
        FundRepositoryErrorCode.permissionDenied,
      );
    }

    final normalizedCurrency = CurrencyMinorUnits.normalizeCurrencyCode(
      draft.currency,
    );
    if (!CurrencyMinorUnits.isValidCurrencyCode(normalizedCurrency)) {
      throw const FundRepositoryException(
        FundRepositoryErrorCode.invalidCurrency,
      );
    }

    final trimmedName = draft.name.trim();
    if (trimmedName.isEmpty) {
      throw const FundRepositoryException(
        FundRepositoryErrorCode.validationFailed,
      );
    }
    final normalizedAppliedMemberIds = draft.appliedMemberIds
        .map((entry) => entry.trim())
        .where((entry) => entry.isNotEmpty)
        .toSet()
        .toList(growable: false);
    final normalizedTreasurerMemberIds = draft.treasurerMemberIds
        .map((entry) => entry.trim())
        .where((entry) => entry.isNotEmpty)
        .toSet()
        .toList(growable: false);

    try {
      final docRef = fundId == null ? _funds.doc() : _funds.doc(fundId);
      final existing = await docRef.get();
      if (fundId != null && !existing.exists) {
        throw const FundRepositoryException(
          FundRepositoryErrorCode.fundNotFound,
        );
      }
      if (existing.exists &&
          (existing.data()?['clanId'] as String?)?.trim() != targetClanId) {
        throw const FundRepositoryException(
          FundRepositoryErrorCode.permissionDenied,
        );
      }
      final payload = <String, dynamic>{
        'id': docRef.id,
        'clanId': targetClanId,
        'branchId': _nullableTrim(draft.branchId),
        'appliedMemberIds': normalizedAppliedMemberIds,
        'treasurerMemberIds': normalizedTreasurerMemberIds,
        'name': trimmedName,
        'description': draft.description.trim(),
        'fundType': draft.fundType.trim().isEmpty
            ? 'custom'
            : draft.fundType.trim().toLowerCase(),
        'currency': normalizedCurrency,
        'balanceMinor': _coerceInt(existing.data()?['balanceMinor']),
        'status': existing.data()?['status'] as String? ?? 'active',
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': session.memberId ?? session.uid,
        if (!existing.exists) 'createdAt': FieldValue.serverTimestamp(),
        if (!existing.exists) 'createdBy': session.memberId ?? session.uid,
      };

      final canGrantTreasurerRole = GovernanceRoleMatrix.canManageClanSettings(
        session,
      );
      if (!canGrantTreasurerRole || normalizedTreasurerMemberIds.isEmpty) {
        await docRef.set(payload, SetOptions(merge: true));
      } else {
        final memberSnapshots = await Future.wait(
          normalizedTreasurerMemberIds.map(
            (memberId) => _members.doc(memberId).get(),
          ),
        );
        final batch = _firestore.batch();
        batch.set(docRef, payload, SetOptions(merge: true));

        for (final memberSnapshot in memberSnapshots) {
          if (!memberSnapshot.exists) {
            continue;
          }
          final data = memberSnapshot.data();
          if (data == null) {
            continue;
          }
          final clanId = _stringOrEmpty(data['clanId']);
          if (clanId != targetClanId) {
            continue;
          }
          final currentRole = _stringOrEmpty(data['primaryRole']).toUpperCase();
          if (!_shouldPromoteToTreasurer(currentRole)) {
            continue;
          }
          batch.set(memberSnapshot.reference, {
            'primaryRole': GovernanceRoles.treasurer,
            'updatedAt': FieldValue.serverTimestamp(),
            'updatedBy': session.memberId ?? session.uid,
          }, SetOptions(merge: true));
        }

        await batch.commit();
      }

      // Build response without an extra read: substitute FieldValue sentinels
      // with local timestamps (within milliseconds of the server timestamp).
      final nowIso = DateTime.now().toUtc().toIso8601String();
      final responsePayload = Map<String, dynamic>.from(payload)
        ..['updatedAt'] = nowIso
        ..['id'] = docRef.id;
      if (!existing.exists) responsePayload['createdAt'] = nowIso;
      return FundProfile.fromJson(
        _normalizeFirestoreMap(responsePayload, fallbackId: docRef.id),
      );
    } on FirebaseException catch (error) {
      throw _mapFirebaseError(error);
    }
  }

  @override
  Future<FundTransaction> recordTransaction({
    required AuthSession session,
    required FundTransactionDraft draft,
  }) async {
    await FirebaseSessionAccessSync.ensureUserSessionDocument(
      firestore: _firestore,
      session: session,
    );

    final clanId = session.clanId;
    if (clanId == null || clanId.isEmpty) {
      throw const FundRepositoryException(
        FundRepositoryErrorCode.permissionDenied,
      );
    }

    final normalizedCurrency = CurrencyMinorUnits.normalizeCurrencyCode(
      draft.currency,
    );
    if (!CurrencyMinorUnits.isValidCurrencyCode(normalizedCurrency)) {
      throw const FundRepositoryException(
        FundRepositoryErrorCode.invalidCurrency,
      );
    }

    final amountMinor = _parseAmountMinor(
      currency: normalizedCurrency,
      amountInput: draft.amountInput,
    );

    try {
      final callable = _functions.httpsCallable('recordFundTransaction');
      final response = await callable.call(<String, dynamic>{
        'fundId': draft.fundId,
        'transactionType': draft.transactionType.jsonValue,
        'amountMinor': amountMinor,
        'occurredAt': draft.occurredAt.toUtc().toIso8601String(),
        'note': draft.note.trim(),
        'memberId': _nullableTrim(draft.memberId) ?? session.memberId,
        'externalReference': _nullableTrim(draft.externalReference),
        'receiptUrl': _nullableTrim(draft.receiptUrl),
      });
      final payload = response.data;
      if (payload is Map && payload['transaction'] is Map<String, dynamic>) {
        return FundTransaction.fromJson(
          payload['transaction'] as Map<String, dynamic>,
        );
      }

      final fallbackId = _stringOrEmpty(
        payload is Map ? payload['fundId'] : null,
      );
      final latestSnapshot = await _loadTransactionSnapshot(clanId: clanId);
      final fallback = latestSnapshot.docs
          .map(
            (doc) => FundTransaction.fromJson(
              _normalizeFirestoreMap(doc.data(), fallbackId: doc.id),
            ),
          )
          .sorted((left, right) => right.occurredAt.compareTo(left.occurredAt))
          .firstWhereOrNull(
            (entry) =>
                entry.fundId == draft.fundId || entry.fundId == fallbackId,
          );
      if (fallback == null) {
        throw const FundRepositoryException(
          FundRepositoryErrorCode.writeFailed,
        );
      }
      return fallback;
    } on FundRepositoryException {
      rethrow;
    } on FirebaseFunctionsException catch (error) {
      throw _mapFunctionsError(error);
    } on FirebaseException catch (error) {
      throw _mapFirebaseError(error);
    }
  }

  int _parseAmountMinor({
    required String currency,
    required String amountInput,
  }) {
    try {
      return CurrencyMinorUnits.toMinorUnits(
        currency: currency,
        amountInput: amountInput,
      );
    } on FormatException {
      throw const FundRepositoryException(
        FundRepositoryErrorCode.invalidAmount,
      );
    }
  }

  FundRepositoryException _mapFirebaseError(FirebaseException error) {
    if (error.code == 'permission-denied') {
      return FundRepositoryException(
        FundRepositoryErrorCode.permissionDenied,
        error.message,
      );
    }

    return FundRepositoryException(
      FundRepositoryErrorCode.writeFailed,
      error.message,
    );
  }

  FundRepositoryException _mapFunctionsError(FirebaseFunctionsException error) {
    if (error.code == 'permission-denied') {
      return FundRepositoryException(
        FundRepositoryErrorCode.permissionDenied,
        error.message,
      );
    }
    if (error.code == 'not-found') {
      return const FundRepositoryException(
        FundRepositoryErrorCode.fundNotFound,
      );
    }
    final normalizedMessage = (error.message ?? '').toLowerCase();
    if (normalizedMessage.contains('insufficient_fund_balance')) {
      return const FundRepositoryException(
        FundRepositoryErrorCode.insufficientBalance,
      );
    }
    if (error.code == 'invalid-argument' ||
        error.code == 'failed-precondition') {
      return FundRepositoryException(
        FundRepositoryErrorCode.validationFailed,
        error.message ?? error.code,
      );
    }
    return FundRepositoryException(
      FundRepositoryErrorCode.writeFailed,
      error.message ?? error.code,
    );
  }
}

Map<String, dynamic> _normalizeFirestoreMap(
  Map<String, dynamic> source, {
  required String fallbackId,
}) {
  final data = <String, dynamic>{'id': fallbackId};

  for (final entry in source.entries) {
    final value = entry.value;
    if (value is Timestamp) {
      data[entry.key] = value.toDate().toUtc().toIso8601String();
    } else {
      data[entry.key] = value;
    }
  }

  data['id'] = (data['id'] as String?)?.trim().isNotEmpty == true
      ? data['id']
      : fallbackId;

  return data;
}

String? _nullableTrim(String? value) {
  final trimmed = value?.trim() ?? '';
  return trimmed.isEmpty ? null : trimmed;
}

int _coerceInt(Object? value) {
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

String _stringOrEmpty(Object? value) {
  return value is String ? value.trim() : '';
}

bool _shouldPromoteToTreasurer(String role) {
  final normalized = role.trim().toUpperCase();
  if (normalized.isEmpty) {
    return true;
  }
  if (normalized == GovernanceRoles.member ||
      normalized == GovernanceRoles.guest) {
    return true;
  }
  return false;
}
