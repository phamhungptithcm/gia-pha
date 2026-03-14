import 'package:flutter/foundation.dart';

import '../../auth/models/auth_session.dart';
import '../models/fund_draft.dart';
import '../models/fund_profile.dart';
import '../models/fund_transaction.dart';
import '../models/fund_transaction_draft.dart';
import '../models/fund_transaction_filters.dart';
import '../services/fund_repository.dart';

class FundController extends ChangeNotifier {
  FundController({
    required FundRepository repository,
    required AuthSession session,
  }) : _repository = repository,
       _session = session;

  final FundRepository _repository;
  final AuthSession _session;

  bool _isLoading = true;
  bool _isSavingFund = false;
  bool _isSavingTransaction = false;
  String? _errorMessage;
  List<FundProfile> _funds = const [];
  List<FundTransaction> _transactions = const [];
  String? _selectedFundId;
  FundTransactionFilters _filters = const FundTransactionFilters();

  bool get isLoading => _isLoading;
  bool get isSavingFund => _isSavingFund;
  bool get isSavingTransaction => _isSavingTransaction;
  String? get errorMessage => _errorMessage;
  List<FundProfile> get funds => _funds;
  List<FundTransaction> get transactions => _transactions;
  FundTransactionFilters get filters => _filters;

  bool get hasClanContext => (_session.clanId ?? '').trim().isNotEmpty;

  bool get canManageFunds {
    final role = _session.primaryRole?.trim().toUpperCase();
    return role == 'SUPER_ADMIN' ||
        role == 'CLAN_ADMIN' ||
        role == 'BRANCH_ADMIN';
  }

  FundProfile? get selectedFund {
    if (_selectedFundId == null || _selectedFundId!.isEmpty) {
      return _funds.isEmpty ? null : _funds.first;
    }

    for (final fund in _funds) {
      if (fund.id == _selectedFundId) {
        return fund;
      }
    }

    return _funds.isEmpty ? null : _funds.first;
  }

  int get totalBalanceMinor {
    return _funds.fold<int>(0, (sum, fund) => sum + fund.balanceMinor);
  }

  Future<void> initialize() async {
    await refresh();
  }

  Future<void> refresh() async {
    final previousSelectedFundId = _selectedFundId;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final snapshot = await _repository.loadWorkspace(session: _session);
      _funds = snapshot.funds;
      _transactions = snapshot.transactions;
      _selectedFundId = _resolveSelectedFundId(previousSelectedFundId);
    } catch (error) {
      _errorMessage = error.toString();
      _funds = const [];
      _transactions = const [];
      _selectedFundId = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void selectFund(String fundId) {
    _selectedFundId = fundId;
    notifyListeners();
  }

  void updateQueryFilter(String value) {
    _filters = _filters.copyWith(query: value);
    notifyListeners();
  }

  void updateTypeFilter(FundTransactionType? type) {
    _filters = _filters.copyWith(
      transactionType: type,
      clearTransactionType: type == null,
    );
    notifyListeners();
  }

  void clearFilters() {
    _filters = const FundTransactionFilters();
    notifyListeners();
  }

  List<FundTransaction> filteredTransactionsForFund(String fundId) {
    final query = _filters.query.trim().toLowerCase();

    return _transactions
        .where((transaction) {
          if (transaction.fundId != fundId) {
            return false;
          }

          if (_filters.transactionType != null &&
              transaction.transactionType != _filters.transactionType) {
            return false;
          }

          final from = _filters.from;
          if (from != null && transaction.occurredAt.isBefore(from.toUtc())) {
            return false;
          }

          final to = _filters.to;
          if (to != null && transaction.occurredAt.isAfter(to.toUtc())) {
            return false;
          }

          if (query.isEmpty) {
            return true;
          }

          final haystack = [
            transaction.note,
            transaction.externalReference ?? '',
            transaction.memberId ?? '',
          ].join(' ').toLowerCase();

          return haystack.contains(query);
        })
        .toList(growable: false)
      ..sort((left, right) => right.occurredAt.compareTo(left.occurredAt));
  }

  Future<FundRepositoryErrorCode?> saveFund({
    String? fundId,
    required FundDraft draft,
  }) async {
    if (!canManageFunds) {
      return FundRepositoryErrorCode.permissionDenied;
    }

    _isSavingFund = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final saved = await _repository.saveFund(
        session: _session,
        fundId: fundId,
        draft: draft,
      );
      await refresh();
      _selectedFundId = saved.id;
      notifyListeners();
      return null;
    } on FundRepositoryException catch (error) {
      _errorMessage = error.toString();
      return error.code;
    } finally {
      _isSavingFund = false;
      notifyListeners();
    }
  }

  Future<FundRepositoryErrorCode?> recordTransaction({
    required FundTransactionDraft draft,
  }) async {
    if (!canManageFunds) {
      return FundRepositoryErrorCode.permissionDenied;
    }

    _isSavingTransaction = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.recordTransaction(session: _session, draft: draft);
      await refresh();
      return null;
    } on FundRepositoryException catch (error) {
      _errorMessage = error.toString();
      return error.code;
    } finally {
      _isSavingTransaction = false;
      notifyListeners();
    }
  }

  String? _resolveSelectedFundId(String? previousSelectedFundId) {
    if (_funds.isEmpty) {
      return null;
    }

    if (previousSelectedFundId != null &&
        _funds.any((fund) => fund.id == previousSelectedFundId)) {
      return previousSelectedFundId;
    }

    return _funds.first.id;
  }
}
