import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/services/app_logger.dart';
import '../../../core/services/governance_role_matrix.dart';
import '../../ads/services/ad_conversion_tracker.dart';
import '../../auth/models/auth_session.dart';
import '../models/billing_workspace_snapshot.dart';
import '../services/billing_repository.dart';

class BillingController extends ChangeNotifier {
  BillingController({
    required BillingRepository repository,
    required AuthSession session,
    AdConversionTracker? adConversionTracker,
  }) : _repository = repository,
       _session = session,
       _adConversionTracker =
           adConversionTracker ?? createDefaultAdConversionTracker();

  final BillingRepository _repository;
  final AuthSession _session;
  final AdConversionTracker _adConversionTracker;

  bool _isLoading = true;
  bool _isSavingPreferences = false;
  bool _isProcessingPayment = false;
  String? _errorMessage;
  BillingWorkspaceSnapshot? _workspace;
  BillingViewerSummary? _viewerSummary;

  bool get isLoading => _isLoading;
  bool get isSavingPreferences => _isSavingPreferences;
  bool get isProcessingPayment => _isProcessingPayment;
  String? get errorMessage => _errorMessage;
  BillingWorkspaceSnapshot? get workspace => _workspace;
  BillingViewerSummary? get viewerSummary => _viewerSummary;
  bool get isRepositorySandbox => _repository.isSandbox;

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

  bool get canMutateBilling {
    if (_session.uid.trim().isEmpty) {
      return false;
    }
    if (!hasClanContext) {
      return true;
    }
    return canManageBilling;
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
        try {
          _workspace = await _repository.loadWorkspace(session: _session);
          _viewerSummary = null;
        } on BillingRepositoryException catch (error) {
          if (_shouldFallbackToViewer(error)) {
            _viewerSummary = await _repository.loadViewerSummary(
              session: _session,
            );
            _workspace = null;
            _errorMessage = null;
          } else {
            rethrow;
          }
        }
      } else {
        _viewerSummary = await _repository.loadViewerSummary(session: _session);
        _workspace = null;
      }
    } on BillingRepositoryException catch (error) {
      _errorMessage = error.toString();
      _workspace = null;
      _viewerSummary = null;
      AppLogger.warning('Billing refresh failed with repository error.', error);
    } catch (error) {
      _errorMessage = error.toString();
      _workspace = null;
      _viewerSummary = null;
      AppLogger.warning('Billing refresh failed unexpectedly.', error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  bool _shouldFallbackToViewer(BillingRepositoryException error) {
    if (error.code == BillingRepositoryErrorCode.permissionDenied) {
      return true;
    }
    if (error.code == BillingRepositoryErrorCode.failedPrecondition) {
      final lower = (error.message ?? '').toLowerCase();
      if (lower.contains('owner') ||
          lower.contains('billing scope') ||
          lower.contains('clan billing')) {
        return true;
      }
    }
    return false;
  }

  Future<void> updatePreferences({
    required String paymentMode,
    required bool autoRenew,
    List<int>? reminderDaysBefore,
  }) async {
    _isSavingPreferences = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _repository.updatePreferences(
        session: _session,
        paymentMode: paymentMode,
        autoRenew: autoRenew,
        reminderDaysBefore: reminderDaysBefore,
      );
      _workspace = await _repository.loadWorkspace(session: _session);
    } on BillingRepositoryException catch (error) {
      _errorMessage = error.toString();
    } catch (error) {
      _errorMessage = error.toString();
    } finally {
      _isSavingPreferences = false;
      notifyListeners();
    }
  }

  Future<BillingEntitlement?> verifyInAppPurchase({
    required String platform,
    required String productId,
    required Map<String, dynamic> payload,
  }) async {
    _isProcessingPayment = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final entitlement = await _repository.verifyInAppPurchase(
        session: _session,
        platform: platform,
        productId: productId,
        payload: payload,
      );
      _workspace = await _repository.loadWorkspace(session: _session);
      _viewerSummary = null;
      unawaited(
        _adConversionTracker.logPremiumPurchase(
          planCode: entitlement.planCode,
          productId: productId,
        ),
      );
      return entitlement;
    } on BillingRepositoryException catch (error) {
      _errorMessage = error.toString();
      return null;
    } catch (error) {
      _errorMessage = error.toString();
      return null;
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
          scope: current.scope,
          subscription: current.subscription,
          entitlement: entitlement,
          aiUsageSummary: current.aiUsageSummary,
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
