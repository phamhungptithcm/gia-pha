import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';

import '../../../core/services/firebase_services.dart';
import '../../../core/services/firebase_session_access_sync.dart';
import '../../auth/models/auth_session.dart';
import '../models/fund_draft.dart';
import '../models/fund_profile.dart';
import '../models/fund_transaction.dart';
import '../models/fund_transaction_draft.dart';
import '../models/fund_workspace_snapshot.dart';
import 'currency_minor_units.dart';
import 'fund_repository.dart';
import 'fund_transaction_validation.dart';

class FirebaseFundRepository implements FundRepository {
  FirebaseFundRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseServices.firestore;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _funds =>
      _firestore.collection('funds');

  CollectionReference<Map<String, dynamic>> get _transactions =>
      _firestore.collection('transactions');

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
      _transactions
          .where('clanId', isEqualTo: clanId)
          .orderBy('occurredAt', descending: true)
          .limit(400)
          .get(),
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
        .toList(growable: false);

    return FundWorkspaceSnapshot(funds: funds, transactions: transactions);
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

    final trimmedName = draft.name.trim();
    if (trimmedName.isEmpty) {
      throw const FundRepositoryException(
        FundRepositoryErrorCode.validationFailed,
      );
    }

    try {
      final docRef = fundId == null ? _funds.doc() : _funds.doc(fundId);
      final existing = await docRef.get();

      await docRef.set({
        'id': docRef.id,
        'clanId': clanId,
        'branchId': _nullableTrim(draft.branchId),
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
      }, SetOptions(merge: true));

      final refreshed = await docRef.get();
      final payload = _normalizeFirestoreMap(
        refreshed.data() ?? {},
        fallbackId: docRef.id,
      );
      return FundProfile.fromJson(payload);
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
      return await _firestore.runTransaction((tx) async {
        final fundRef = _funds.doc(draft.fundId);
        final fundSnapshot = await tx.get(fundRef);

        if (!fundSnapshot.exists || fundSnapshot.data() == null) {
          throw const FundRepositoryException(
            FundRepositoryErrorCode.fundNotFound,
          );
        }

        final fund = FundProfile.fromJson(
          _normalizeFirestoreMap(fundSnapshot.data()!, fallbackId: fundRef.id),
        );
        if (fund.clanId != clanId) {
          throw const FundRepositoryException(
            FundRepositoryErrorCode.permissionDenied,
          );
        }

        try {
          validateFundTransactionInput(
            fundId: draft.fundId,
            transactionType: draft.transactionType,
            amountMinor: amountMinor,
            currentBalanceMinor: fund.balanceMinor,
            currency: normalizedCurrency,
            occurredAt: draft.occurredAt,
            note: draft.note,
          );
        } on FundTransactionValidationException catch (error) {
          throw _mapValidationError(error);
        }

        final transactionRef = _transactions.doc();
        final createdAt = DateTime.now().toUtc();
        final created = FundTransaction(
          id: transactionRef.id,
          fundId: fund.id,
          clanId: clanId,
          branchId: fund.branchId,
          transactionType: draft.transactionType,
          amountMinor: amountMinor,
          currency: normalizedCurrency,
          memberId: _nullableTrim(draft.memberId) ?? session.memberId,
          externalReference: _nullableTrim(draft.externalReference),
          occurredAt: draft.occurredAt.toUtc(),
          note: draft.note.trim(),
          receiptUrl: _nullableTrim(draft.receiptUrl),
          createdAt: createdAt,
          createdBy: session.memberId ?? session.uid,
        );

        tx.set(transactionRef, {
          ...created.toJson(),
          'occurredAt': Timestamp.fromDate(created.occurredAt),
          'createdAt': FieldValue.serverTimestamp(),
        });
        tx.set(fundRef, {
          'balanceMinor': fund.balanceMinor + created.signedAmountMinor,
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedBy': session.memberId ?? session.uid,
        }, SetOptions(merge: true));

        return created;
      });
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

  FundRepositoryException _mapValidationError(
    FundTransactionValidationException error,
  ) {
    return switch (error.code) {
      FundTransactionValidationErrorCode.insufficientBalance =>
        const FundRepositoryException(
          FundRepositoryErrorCode.insufficientBalance,
        ),
      FundTransactionValidationErrorCode.unsupportedCurrency =>
        const FundRepositoryException(FundRepositoryErrorCode.invalidCurrency),
      FundTransactionValidationErrorCode.amountNotPositive =>
        const FundRepositoryException(FundRepositoryErrorCode.invalidAmount),
      _ => const FundRepositoryException(
        FundRepositoryErrorCode.validationFailed,
      ),
    };
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
