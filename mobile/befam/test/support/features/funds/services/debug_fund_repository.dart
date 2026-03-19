import 'dart:async';

import 'package:befam/core/services/governance_role_matrix.dart';
import 'package:befam/features/auth/models/auth_session.dart';
import 'package:befam/features/funds/models/fund_draft.dart';
import 'package:befam/features/funds/models/fund_profile.dart';
import 'package:befam/features/funds/models/fund_transaction.dart';
import 'package:befam/features/funds/models/fund_transaction_draft.dart';
import 'package:befam/features/funds/models/fund_workspace_snapshot.dart';
import 'package:befam/features/funds/services/currency_minor_units.dart';
import 'package:befam/features/funds/services/fund_repository.dart';
import 'package:befam/features/funds/services/fund_transaction_validation.dart';
import 'package:collection/collection.dart';
import '../../../core/services/debug_genealogy_store.dart';

class DebugFundRepository implements FundRepository {
  DebugFundRepository({required DebugGenealogyStore store}) : _store = store;

  factory DebugFundRepository.seeded() {
    return DebugFundRepository(store: DebugGenealogyStore.seeded());
  }

  factory DebugFundRepository.shared() {
    return DebugFundRepository(store: DebugGenealogyStore.sharedSeeded());
  }

  final DebugGenealogyStore _store;

  @override
  bool get isSandbox => true;

  @override
  Future<FundWorkspaceSnapshot> loadWorkspace({
    required AuthSession session,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));

    final clanId = session.clanId;
    if (clanId == null || clanId.isEmpty) {
      return const FundWorkspaceSnapshot(funds: [], transactions: []);
    }

    final funds = _store.funds.values
        .where((fund) => fund.clanId == clanId)
        .sortedBy((fund) => fund.name.toLowerCase())
        .toList(growable: false);

    final transactions = _store.transactions.values
        .where((transaction) => transaction.clanId == clanId)
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
    await Future<void>.delayed(const Duration(milliseconds: 140));

    final clanId = session.clanId;
    if (clanId == null || clanId.isEmpty) {
      throw const FundRepositoryException(
        FundRepositoryErrorCode.permissionDenied,
      );
    }
    final targetClanId = (draft.clanId ?? '').trim().isEmpty
        ? clanId
        : draft.clanId!.trim();
    if (targetClanId != clanId) {
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

    final resolvedFundId = fundId ?? 'fund_demo_${_store.fundSequence++}';
    final existing = _store.funds[resolvedFundId];
    final payload = FundProfile(
      id: resolvedFundId,
      clanId: targetClanId,
      branchId: _nullableTrim(draft.branchId),
      appliedMemberIds: normalizedAppliedMemberIds,
      treasurerMemberIds: normalizedTreasurerMemberIds,
      name: trimmedName,
      description: draft.description.trim(),
      fundType: draft.fundType.trim().isEmpty
          ? 'custom'
          : draft.fundType.trim().toLowerCase(),
      currency: normalizedCurrency,
      balanceMinor: existing?.balanceMinor ?? 0,
      status: existing?.status ?? 'active',
    );

    _store.funds[resolvedFundId] = payload;
    if (GovernanceRoleMatrix.canManageClanSettings(session)) {
      for (final memberId in normalizedTreasurerMemberIds) {
        final member = _store.members[memberId];
        if (member == null || member.clanId != targetClanId) {
          continue;
        }
        final role = GovernanceRoleMatrix.normalizeRole(member.primaryRole);
        if (role != GovernanceRoles.member && role != GovernanceRoles.guest) {
          continue;
        }
        _store.members[memberId] = member.copyWith(
          primaryRole: GovernanceRoles.treasurer,
        );
      }
    }
    return payload;
  }

  @override
  Future<FundTransaction> recordTransaction({
    required AuthSession session,
    required FundTransactionDraft draft,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 160));

    final clanId = session.clanId;
    if (clanId == null || clanId.isEmpty) {
      throw const FundRepositoryException(
        FundRepositoryErrorCode.permissionDenied,
      );
    }

    final fund = _store.funds[draft.fundId];
    if (fund == null || fund.clanId != clanId) {
      throw const FundRepositoryException(FundRepositoryErrorCode.fundNotFound);
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

    final transactionId = 'txn_demo_${_store.transactionSequence++}';
    final created = FundTransaction(
      id: transactionId,
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
      createdAt: DateTime.now().toUtc(),
      createdBy: session.memberId ?? session.uid,
    );

    _store.transactions[transactionId] = created;
    _store.funds[fund.id] = fund.copyWith(
      balanceMinor: fund.balanceMinor + created.signedAmountMinor,
    );

    return created;
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
}

String? _nullableTrim(String? value) {
  final trimmed = value?.trim() ?? '';
  return trimmed.isEmpty ? null : trimmed;
}
