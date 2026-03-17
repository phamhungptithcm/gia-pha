import 'package:flutter/foundation.dart';

import '../../../core/services/governance_role_matrix.dart';
import '../../auth/models/auth_session.dart';
import '../models/billing_workspace_snapshot.dart';
import '../services/billing_repository.dart';

class BillingController extends ChangeNotifier {
  BillingController({
    required BillingRepository repository,
    required AuthSession session,
  }) : _repository = repository,
       _session = session;

  final BillingRepository _repository;
  final AuthSession _session;

  bool _isLoading = true;
  bool _isSavingPreferences = false;
  bool _isProcessingPayment = false;
  bool _isCreatingCheckout = false;
  String? _errorMessage;
  String? _actionMessage;
  BillingWorkspaceSnapshot? _workspace;
  BillingViewerSummary? _viewerSummary;
  BillingCheckoutResult? _lastCheckout;

  bool get isLoading => _isLoading;
  bool get isSavingPreferences => _isSavingPreferences;
  bool get isProcessingPayment => _isProcessingPayment;
  bool get isCreatingCheckout => _isCreatingCheckout;
  String? get errorMessage => _errorMessage;
  String? get actionMessage => _actionMessage;
  BillingWorkspaceSnapshot? get workspace => _workspace;
  BillingViewerSummary? get viewerSummary => _viewerSummary;
  BillingCheckoutResult? get lastCheckout => _lastCheckout;

  bool get hasClanContext => (_session.clanId ?? '').trim().isNotEmpty;

  bool get canManageBilling {
    if (_session.uid.trim().isEmpty) {
      return false;
    }
    if (!hasClanContext) {
      // Personal billing scope: authenticated users can manage their own plan
      // before joining any clan.
      return true;
    }
    if (!GovernanceRoleMatrix.isClaimedClanSession(_session)) {
      return false;
    }
    final role = (_session.primaryRole ?? '').trim().toUpperCase();
    return role == 'SUPER_ADMIN' ||
        role == 'CLAN_ADMIN' ||
        role == 'BRANCH_ADMIN' ||
        role == 'CLAN_OWNER' ||
        role == 'CLAN_LEADER' ||
        role == 'VICE_LEADER' ||
        role == 'SUPPORTER_OF_LEADER';
  }

  bool get shouldShowAds {
    final entitlement = _workspace?.entitlement;
    if (entitlement == null) {
      return true;
    }
    return entitlement.showAds;
  }

  Future<void> initialize() async {
    await refresh();
  }

  Future<void> refresh() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      if (canManageBilling) {
        _workspace = await _repository.loadWorkspace(session: _session);
        _viewerSummary = null;
      } else {
        _viewerSummary = await _repository.loadViewerSummary(session: _session);
        _workspace = null;
      }
    } on BillingRepositoryException catch (error) {
      _errorMessage = error.toString();
      _workspace = null;
      _viewerSummary = null;
      debugPrint('[billing] refresh repository error: $error');
    } catch (error) {
      _errorMessage = error.toString();
      _workspace = null;
      _viewerSummary = null;
      debugPrint('[billing] refresh unexpected error: $error');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updatePreferences({
    required String paymentMode,
    required bool autoRenew,
    List<int>? reminderDaysBefore,
  }) async {
    _isSavingPreferences = true;
    _errorMessage = null;
    _actionMessage = null;
    notifyListeners();
    try {
      await _repository.updatePreferences(
        session: _session,
        paymentMode: paymentMode,
        autoRenew: autoRenew,
        reminderDaysBefore: reminderDaysBefore,
      );
      _workspace = await _repository.loadWorkspace(session: _session);
      _actionMessage = 'Billing preferences saved.';
    } on BillingRepositoryException catch (error) {
      _errorMessage = error.toString();
    } catch (error) {
      _errorMessage = error.toString();
    } finally {
      _isSavingPreferences = false;
      notifyListeners();
    }
  }

  Future<BillingCheckoutResult?> createCheckout({
    required String paymentMethod,
    String? requestedPlanCode,
    String? returnUrl,
    String? locale,
    String? orderNote,
    String? bankCode,
    String? contactPhone,
  }) async {
    _isCreatingCheckout = true;
    _errorMessage = null;
    _actionMessage = null;
    notifyListeners();
    try {
      _lastCheckout = await _repository.createCheckout(
        session: _session,
        paymentMethod: paymentMethod,
        requestedPlanCode: requestedPlanCode,
        returnUrl: returnUrl,
        locale: locale,
        orderNote: orderNote,
        bankCode: bankCode,
        contactPhone: contactPhone,
      );
      _workspace = await _repository.loadWorkspace(session: _session);
      _viewerSummary = null;
      _actionMessage = 'Checkout created successfully.';
      return _lastCheckout;
    } on BillingRepositoryException catch (error) {
      _errorMessage = error.toString();
      return null;
    } catch (error) {
      _errorMessage = error.toString();
      return null;
    } finally {
      _isCreatingCheckout = false;
      notifyListeners();
    }
  }

  Future<void> confirmCardPayment(String transactionId) async {
    _isProcessingPayment = true;
    _errorMessage = null;
    _actionMessage = null;
    notifyListeners();
    try {
      await _repository.completeCardCheckout(
        session: _session,
        transactionId: transactionId,
      );
      _workspace = await _repository.loadWorkspace(session: _session);
      _viewerSummary = null;
      _actionMessage = 'Card payment confirmed.';
    } on BillingRepositoryException catch (error) {
      _errorMessage = error.toString();
    } catch (error) {
      _errorMessage = error.toString();
    } finally {
      _isProcessingPayment = false;
      notifyListeners();
    }
  }

  Future<void> confirmVnpayPayment(String transactionId) async {
    _isProcessingPayment = true;
    _errorMessage = null;
    _actionMessage = null;
    notifyListeners();
    try {
      await _repository.settleVnpayCheckout(
        session: _session,
        transactionId: transactionId,
      );
      _workspace = await _repository.loadWorkspace(session: _session);
      _viewerSummary = null;
      _actionMessage = 'VNPay payment confirmed.';
    } on BillingRepositoryException catch (error) {
      _errorMessage = error.toString();
    } catch (error) {
      _errorMessage = error.toString();
    } finally {
      _isProcessingPayment = false;
      notifyListeners();
    }
  }

  Future<BillingEntitlement?> refreshEntitlement() async {
    try {
      final entitlement = await _repository.resolveEntitlement(
        session: _session,
      );
      final current = _workspace;
      if (current != null) {
        _workspace = BillingWorkspaceSnapshot(
          clanId: current.clanId,
          subscription: current.subscription,
          entitlement: entitlement,
          settings: current.settings,
          checkoutFlow: current.checkoutFlow,
          pricingTiers: current.pricingTiers,
          memberCount: current.memberCount,
          transactions: current.transactions,
          invoices: current.invoices,
          auditLogs: current.auditLogs,
        );
        notifyListeners();
      }
      return entitlement;
    } catch (_) {
      return null;
    }
  }
}
