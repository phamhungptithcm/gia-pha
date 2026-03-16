import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import '../../../core/services/firebase_services.dart';
import '../../../core/services/firebase_session_access_sync.dart';
import '../../auth/models/auth_session.dart';
import '../models/billing_workspace_snapshot.dart';
import 'billing_repository.dart';

class FirebaseBillingRepository implements BillingRepository {
  FirebaseBillingRepository({
    FirebaseFunctions? functions,
    FirebaseFirestore? firestore,
  }) : _functions = functions ?? FirebaseServices.functions,
       _firestore = firestore ?? FirebaseServices.firestore;

  final FirebaseFunctions _functions;
  final FirebaseFirestore _firestore;

  @override
  bool get isSandbox => false;

  @override
  Future<BillingWorkspaceSnapshot> loadWorkspace({
    required AuthSession session,
  }) async {
    await _ensureSessionDocumentBestEffort(session);
    final result = await _call(
      'loadBillingWorkspace',
    ).call(_scopePayload(session));
    return _parseWorkspace(result.data);
  }

  @override
  Future<BillingViewerSummary> loadViewerSummary({
    required AuthSession session,
  }) async {
    final clanId = _sessionClanId(session);
    await _ensureSessionDocumentBestEffort(session);
    final result = await _call(
      'resolveBillingEntitlement',
    ).call(_scopePayload(session));
    final map = _asMap(result.data);
    final pricing = _asList(
      map['pricingTiers'],
    ).map((item) => _parsePricing(_asMap(item))).toList(growable: false);
    return BillingViewerSummary(
      clanId: _readString(map, 'clanId', fallback: clanId),
      subscription: _parseSubscription(_asMap(map['subscription'])),
      entitlement: _parseEntitlement(_asMap(map['entitlement'])),
      pricingTiers: pricing,
      memberCount: _readInt(map, 'memberCount'),
    );
  }

  @override
  Future<BillingEntitlement> resolveEntitlement({
    required AuthSession session,
  }) async {
    await _ensureSessionDocumentBestEffort(session);
    final result = await _call(
      'resolveBillingEntitlement',
    ).call(_scopePayload(session));
    final map = _asMap(result.data);
    return _parseEntitlement(_asMap(map['entitlement']));
  }

  @override
  Future<BillingSettings> updatePreferences({
    required AuthSession session,
    required String paymentMode,
    required bool autoRenew,
    List<int>? reminderDaysBefore,
  }) async {
    await _ensureSessionDocumentBestEffort(session);
    final payload = <String, dynamic>{
      'paymentMode': paymentMode,
      'autoRenew': autoRenew,
      ...?reminderDaysBefore == null
          ? null
          : {'reminderDaysBefore': reminderDaysBefore},
    };
    final result = await _call(
      'updateBillingPreferences',
    ).call(_scopePayload(session, payload));
    return _parseSettings(_asMap(result.data));
  }

  @override
  Future<BillingCheckoutResult> createCheckout({
    required AuthSession session,
    required String paymentMethod,
    String? requestedPlanCode,
    String? returnUrl,
  }) async {
    final clanId = _sessionClanId(session);
    await _ensureSessionDocumentBestEffort(session);
    final payload = <String, dynamic>{
      'paymentMethod': paymentMethod,
      if (requestedPlanCode != null && requestedPlanCode.trim().isNotEmpty)
        'requestedPlanCode': requestedPlanCode.trim().toUpperCase(),
      if (returnUrl != null && returnUrl.trim().isNotEmpty)
        'returnUrl': returnUrl.trim(),
    };
    final result = await _call(
      'createSubscriptionCheckout',
    ).call(_scopePayload(session, payload));
    final map = _asMap(result.data);
    return BillingCheckoutResult(
      clanId: _readString(map, 'clanId', fallback: clanId),
      paymentMethod: _readString(map, 'paymentMethod', fallback: paymentMethod),
      planCode: _readString(map, 'planCode', fallback: 'FREE'),
      amountVnd: _readInt(map, 'amountVnd'),
      vatIncluded: _readBool(map, 'vatIncluded', fallback: true),
      transactionId: _readString(map, 'transactionId'),
      invoiceId: _readString(map, 'invoiceId'),
      checkoutUrl: _readString(map, 'checkoutUrl', fallback: ''),
      requiresManualConfirmation: _readBool(
        map,
        'requiresManualConfirmation',
        fallback: false,
      ),
      subscription: _parseSubscription(_asMap(map['subscription'])),
      entitlement: _parseEntitlement(_asMap(map['entitlement'])),
    );
  }

  @override
  Future<void> completeCardCheckout({
    required AuthSession session,
    required String transactionId,
  }) async {
    await _ensureSessionDocumentBestEffort(session);
    await _call(
      'completeCardCheckout',
    ).call(_scopePayload(session, {'transactionId': transactionId.trim()}));
  }

  @override
  Future<void> settleVnpayCheckout({
    required AuthSession session,
    required String transactionId,
  }) async {
    await _ensureSessionDocumentBestEffort(session);
    await _call(
      'simulateVnpaySettlement',
    ).call(_scopePayload(session, {'transactionId': transactionId.trim()}));
  }

  Future<void> _ensureSessionDocumentBestEffort(AuthSession session) async {
    try {
      await FirebaseSessionAccessSync.ensureUserSessionDocument(
        firestore: _firestore,
        session: session,
      );
    } catch (error, stackTrace) {
      debugPrint('[billing] user session sync skipped: $error');
      debugPrintStack(
        stackTrace: stackTrace,
        label: '[billing] session sync stack',
      );
    }
  }

  Map<String, dynamic> _scopePayload(
    AuthSession session, [
    Map<String, dynamic>? payload,
  ]) {
    final clanId = (session.clanId ?? '').trim();
    final uid = session.uid.trim();
    final base = <String, dynamic>{...?payload};
    if (clanId.isNotEmpty) {
      return <String, dynamic>{'clanId': clanId, ...base};
    }
    return <String, dynamic>{'ownerUid': uid, ...base};
  }

  HttpsCallable _call(String name) {
    return _functions.httpsCallable(name);
  }

  BillingWorkspaceSnapshot _parseWorkspace(Object? raw) {
    final map = _asMap(raw);
    final pricing = _asList(
      map['pricingTiers'],
    ).map((item) => _parsePricing(_asMap(item))).toList(growable: false);
    final transactions = _asList(
      map['transactions'],
    ).map((item) => _parseTransaction(_asMap(item))).toList(growable: false);
    final invoices = _asList(
      map['invoices'],
    ).map((item) => _parseInvoice(_asMap(item))).toList(growable: false);
    final auditLogs = _asList(
      map['auditLogs'],
    ).map((item) => _parseAuditLog(_asMap(item))).toList(growable: false);

    return BillingWorkspaceSnapshot(
      clanId: _readString(map, 'clanId'),
      subscription: _parseSubscription(_asMap(map['subscription'])),
      entitlement: _parseEntitlement(_asMap(map['entitlement'])),
      settings: _parseSettings(_asMap(map['settings'])),
      pricingTiers: pricing,
      memberCount: _readInt(map, 'memberCount'),
      transactions: transactions,
      invoices: invoices,
      auditLogs: auditLogs,
    );
  }

  BillingSubscription _parseSubscription(Map<String, dynamic> map) {
    return BillingSubscription(
      id: _readString(map, 'id'),
      clanId: _readString(map, 'clanId'),
      planCode: _readString(map, 'planCode', fallback: 'FREE'),
      status: _readString(map, 'status', fallback: 'expired'),
      memberCount: _readInt(map, 'memberCount'),
      amountVndYear: _readInt(map, 'amountVndYear'),
      vatIncluded: _readBool(map, 'vatIncluded', fallback: true),
      paymentMode: _readString(map, 'paymentMode', fallback: 'manual'),
      autoRenew: _readBool(map, 'autoRenew', fallback: false),
      startsAtIso: _readIso(map, 'startsAt'),
      expiresAtIso: _readIso(map, 'expiresAt'),
      nextPaymentDueAtIso: _readIso(map, 'nextPaymentDueAt'),
      graceEndsAtIso: _readIso(map, 'graceEndsAt'),
      lastPaymentMethod: _readNullableString(map, 'lastPaymentMethod'),
      lastTransactionId: _readNullableString(map, 'lastTransactionId'),
      updatedAtIso: _readIso(map, 'updatedAt'),
    );
  }

  BillingEntitlement _parseEntitlement(Map<String, dynamic> map) {
    return BillingEntitlement(
      planCode: _readString(map, 'planCode', fallback: 'FREE'),
      status: _readString(map, 'status', fallback: 'expired'),
      showAds: _readBool(map, 'showAds', fallback: true),
      adFree: _readBool(map, 'adFree', fallback: false),
      hasPremiumAccess: _readBool(map, 'hasPremiumAccess', fallback: false),
      expiresAtIso: _readIso(map, 'expiresAtIso'),
      nextPaymentDueAtIso: _readIso(map, 'nextPaymentDueAtIso'),
    );
  }

  BillingSettings _parseSettings(Map<String, dynamic> map) {
    return BillingSettings(
      id: _readString(map, 'id'),
      clanId: _readString(map, 'clanId'),
      paymentMode: _readString(map, 'paymentMode', fallback: 'manual'),
      autoRenew: _readBool(map, 'autoRenew', fallback: false),
      reminderDaysBefore: _readIntList(map, 'reminderDaysBefore'),
      updatedAtIso: _readIso(map, 'updatedAt'),
    );
  }

  BillingPlanPricing _parsePricing(Map<String, dynamic> map) {
    return BillingPlanPricing(
      planCode: _readString(map, 'planCode', fallback: 'FREE'),
      minMembers: _readInt(map, 'minMembers'),
      maxMembers: _readNullableInt(map, 'maxMembers'),
      priceVndYear: _readInt(map, 'priceVndYear'),
      vatIncluded: _readBool(map, 'vatIncluded', fallback: true),
      showAds: _readBool(map, 'showAds', fallback: true),
      adFree: _readBool(map, 'adFree', fallback: false),
    );
  }

  BillingPaymentTransaction _parseTransaction(Map<String, dynamic> map) {
    return BillingPaymentTransaction(
      id: _readString(map, 'id'),
      clanId: _readString(map, 'clanId'),
      subscriptionId: _readString(map, 'subscriptionId'),
      invoiceId: _readString(map, 'invoiceId'),
      paymentMethod: _readString(map, 'paymentMethod', fallback: 'card'),
      paymentStatus: _readString(map, 'paymentStatus', fallback: 'created'),
      planCode: _readString(map, 'planCode', fallback: 'FREE'),
      memberCount: _readInt(map, 'memberCount'),
      amountVnd: _readInt(map, 'amountVnd'),
      vatIncluded: _readBool(map, 'vatIncluded', fallback: true),
      currency: _readString(map, 'currency', fallback: 'VND'),
      gatewayReference: _readNullableString(map, 'gatewayReference'),
      createdAtIso: _readIso(map, 'createdAt'),
      paidAtIso: _readIso(map, 'paidAt'),
      failedAtIso: _readIso(map, 'failedAt'),
    );
  }

  BillingInvoice _parseInvoice(Map<String, dynamic> map) {
    return BillingInvoice(
      id: _readString(map, 'id'),
      clanId: _readString(map, 'clanId'),
      subscriptionId: _readString(map, 'subscriptionId'),
      transactionId: _readString(map, 'transactionId'),
      planCode: _readString(map, 'planCode', fallback: 'FREE'),
      amountVnd: _readInt(map, 'amountVnd'),
      vatIncluded: _readBool(map, 'vatIncluded', fallback: true),
      currency: _readString(map, 'currency', fallback: 'VND'),
      status: _readString(map, 'status', fallback: 'issued'),
      periodStartIso: _readIso(map, 'periodStart'),
      periodEndIso: _readIso(map, 'periodEnd'),
      issuedAtIso: _readIso(map, 'issuedAt'),
      paidAtIso: _readIso(map, 'paidAt'),
    );
  }

  BillingAuditLog _parseAuditLog(Map<String, dynamic> map) {
    return BillingAuditLog(
      id: _readString(map, 'id'),
      clanId: _readString(map, 'clanId'),
      actorUid: _readNullableString(map, 'actorUid'),
      action: _readString(map, 'action'),
      entityType: _readString(map, 'entityType'),
      entityId: _readString(map, 'entityId'),
      createdAtIso: _readIso(map, 'createdAt'),
    );
  }

  String _sessionClanId(AuthSession session) {
    final clanId = (session.clanId ?? '').trim();
    if (clanId.isNotEmpty) {
      return clanId;
    }
    final uid = session.uid.trim();
    if (uid.isEmpty) {
      throw const BillingRepositoryException(
        BillingRepositoryErrorCode.failedPrecondition,
        'Missing authenticated user for billing scope.',
      );
    }
    return 'user_scope__$uid';
  }

  Map<String, dynamic> _asMap(Object? raw) {
    if (raw is Map<String, dynamic>) {
      return raw;
    }
    if (raw is Map) {
      return raw.map((key, value) => MapEntry(key.toString(), value));
    }
    return const {};
  }

  List<dynamic> _asList(Object? raw) {
    if (raw is List) {
      return raw;
    }
    return const [];
  }

  String _readString(
    Map<String, dynamic> map,
    String key, {
    String fallback = '',
  }) {
    final value = map[key];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    return fallback;
  }

  String? _readNullableString(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    return null;
  }

  int _readInt(Map<String, dynamic> map, String key, {int fallback = 0}) {
    final value = map[key];
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) {
        return parsed;
      }
    }
    return fallback;
  }

  int? _readNullableInt(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  bool _readBool(
    Map<String, dynamic> map,
    String key, {
    bool fallback = false,
  }) {
    final value = map[key];
    if (value is bool) {
      return value;
    }
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true') {
        return true;
      }
      if (normalized == 'false') {
        return false;
      }
    }
    return fallback;
  }

  List<int> _readIntList(Map<String, dynamic> map, String key) {
    final raw = map[key];
    if (raw is! List) {
      return const [30, 14, 7, 3, 1];
    }
    final values =
        raw
            .map((item) {
              if (item is int) {
                return item;
              }
              if (item is num) {
                return item.toInt();
              }
              if (item is String) {
                return int.tryParse(item);
              }
              return null;
            })
            .whereType<int>()
            .where((value) => value > 0 && value <= 60)
            .toSet()
            .toList(growable: false)
          ..sort((left, right) => right.compareTo(left));
    return values.isEmpty ? const [30, 14, 7, 3, 1] : values;
  }

  String? _readIso(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value == null) {
      return null;
    }
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    if (value is DateTime) {
      return value.toUtc().toIso8601String();
    }
    if (value is Timestamp) {
      return value.toDate().toUtc().toIso8601String();
    }
    if (value is Map) {
      final seconds = value['_seconds'];
      final nanoseconds = value['_nanoseconds'];
      if (seconds is int) {
        final dt = DateTime.fromMillisecondsSinceEpoch(
          (seconds * 1000) +
              (nanoseconds is int ? (nanoseconds ~/ 1000000) : 0),
          isUtc: true,
        );
        return dt.toIso8601String();
      }
    }
    return null;
  }
}
