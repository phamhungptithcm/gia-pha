import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../features/auth/models/auth_session.dart';
import 'app_environment.dart';
import 'performance_measurement_logger.dart';

class FirebaseSessionAccessSync {
  FirebaseSessionAccessSync._();

  static const Duration _minimumSyncInterval = Duration(minutes: 10);
  static const Duration _claimsCacheTtl = Duration(minutes: 2);
  static final Map<String, _SessionSyncSnapshot> _lastSyncedSnapshotByUid = {};
  static final Map<String, _ClaimsSnapshot> _claimsSnapshotByUid = {};
  static final Map<String, Future<void>> _inflightSyncByUid = {};
  static final PerformanceMeasurementLogger _performanceLogger =
      PerformanceMeasurementLogger(
        defaultSlowThreshold: const Duration(milliseconds: 250),
      );

  static Future<void> ensureUserSessionDocument({
    FirebaseFirestore? firestore,
    required AuthSession session,
    FirebaseAuth? auth,
    Future<Map<String, dynamic>?> Function(FirebaseAuth? auth)? claimsResolver,
    Future<void> Function(String uid, Map<String, dynamic> payload)?
    sessionWriter,
    DateTime Function()? nowProvider,
  }) async {
    final usesInjectedSyncHandlers =
        claimsResolver != null || sessionWriter != null;
    if (AppEnvironment.useLocalFirebaseFallbacks && !usesInjectedSyncHandlers) {
      return;
    }
    final uid = session.uid.trim();
    if (uid.isEmpty) {
      return;
    }

    if (sessionWriter == null && firestore == null) {
      throw ArgumentError(
        'firestore is required when no custom sessionWriter is provided.',
      );
    }

    final existing = _inflightSyncByUid[uid];
    if (existing != null) {
      await existing;
      return;
    }

    final syncFuture = _performanceLogger.measureAsync<void>(
      metric: 'firebase.session_sync',
      warnAfter: const Duration(milliseconds: 250),
      dimensions: <String, Object?>{
        'login_method': session.loginMethod.name,
        'linked_auth_uid': session.linkedAuthUid ? 1 : 0,
      },
      action: () => _ensureUserSessionDocumentInternal(
        firestore: firestore,
        session: session,
        uid: uid,
        auth: auth,
        claimsResolver: claimsResolver ?? _resolveClaims,
        sessionWriter: sessionWriter,
        nowProvider: nowProvider ?? DateTime.now,
      ),
    );
    _inflightSyncByUid[uid] = syncFuture;
    try {
      await syncFuture;
    } finally {
      if (identical(_inflightSyncByUid[uid], syncFuture)) {
        _inflightSyncByUid.remove(uid);
      }
    }
  }

  static Future<void> _ensureUserSessionDocumentInternal({
    required FirebaseFirestore? firestore,
    required AuthSession session,
    required String uid,
    required FirebaseAuth? auth,
    required Future<Map<String, dynamic>?> Function(FirebaseAuth? auth)
    claimsResolver,
    required Future<void> Function(String uid, Map<String, dynamic> payload)?
    sessionWriter,
    required DateTime Function() nowProvider,
  }) async {
    final currentTime = nowProvider();
    final claims = await _resolveClaimsCached(
      uid: uid,
      auth: auth,
      now: currentTime,
      claimsResolver: claimsResolver,
    );
    if (claims == null) {
      return;
    }
    final claimClanIds = _asStringList(claims['clanIds']);
    final claimClanId = _clean(_asString(claims['clanId']));
    final claimActiveClanId = _clean(_asString(claims['activeClanId']));
    final clanIds = _mergeClanIds(
      preferredClanId: claimActiveClanId.isNotEmpty
          ? claimActiveClanId
          : (claimClanId.isNotEmpty
                ? claimClanId
                : (claimClanIds.isNotEmpty ? claimClanIds.first : '')),
      clanIds: claimClanIds,
    );
    final clanId = clanIds.isEmpty ? '' : clanIds.first;
    final branchId = _clean(_asString(claims['branchId']));
    final memberId = _clean(_asString(claims['memberId']));
    final primaryRole = _clean(_asString(claims['primaryRole']));
    final accessMode = _clean(
      _asString(claims['memberAccessMode']),
      fallback: 'unlinked',
    );
    final now = FieldValue.serverTimestamp();
    final fingerprint = _buildSyncFingerprint(
      uid: uid,
      memberId: memberId,
      clanId: clanId,
      clanIds: clanIds,
      branchId: branchId,
      primaryRole: primaryRole,
      accessMode: accessMode,
      linkedAuthUid: session.linkedAuthUid,
    );
    final previous = _lastSyncedSnapshotByUid[uid];
    if (previous != null &&
        previous.fingerprint == fingerprint &&
        currentTime.difference(previous.syncedAt) < _minimumSyncInterval) {
      return;
    }

    try {
      final payload = <String, dynamic>{
        'uid': uid,
        'memberId': memberId,
        'clanId': clanId,
        'clanIds': clanIds,
        'branchId': branchId,
        'primaryRole': primaryRole,
        'accessMode': accessMode,
        'linkedAuthUid': session.linkedAuthUid,
        'updatedAt': now,
        'createdAt': now,
      };
      if (sessionWriter != null) {
        await sessionWriter(uid, payload);
      } else {
        await firestore!
            .collection('users')
            .doc(uid)
            .set(payload, SetOptions(merge: true));
      }
      _lastSyncedSnapshotByUid[uid] = _SessionSyncSnapshot(
        fingerprint: fingerprint,
        syncedAt: currentTime,
      );
    } catch (_) {
      // Session sync is best-effort; do not block feature flows when claims/rules are in transition.
      return;
    }
  }

  static Future<Map<String, dynamic>?> _resolveClaimsCached({
    required String uid,
    required FirebaseAuth? auth,
    required DateTime now,
    required Future<Map<String, dynamic>?> Function(FirebaseAuth? auth)
    claimsResolver,
  }) async {
    final cached = _claimsSnapshotByUid[uid];
    if (cached != null && now.difference(cached.resolvedAt) < _claimsCacheTtl) {
      return cached.claims;
    }

    final claims = await claimsResolver(auth);
    if (claims == null) {
      return null;
    }

    final normalizedClaims = Map<String, dynamic>.unmodifiable(
      claims.map((key, value) => MapEntry(key.toString(), value)),
    );
    _claimsSnapshotByUid[uid] = _ClaimsSnapshot(
      claims: normalizedClaims,
      resolvedAt: now,
    );
    return normalizedClaims;
  }

  static Future<Map<String, dynamic>?> _resolveClaims(
    FirebaseAuth? auth,
  ) async {
    try {
      final authInstance = auth ?? FirebaseAuth.instance;
      final tokenResult = await authInstance.currentUser?.getIdTokenResult();
      final rawClaims = tokenResult?.claims;
      if (rawClaims == null) {
        return null;
      }
      return rawClaims.map((key, value) => MapEntry(key.toString(), value));
    } catch (_) {
      return null;
    }
  }

  static String? _asString(Object? value) {
    if (value is! String) {
      return null;
    }
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static List<String> _asStringList(Object? value) {
    if (value is! List) {
      return const [];
    }
    return value
        .whereType<String>()
        .map((entry) => entry.trim())
        .where((entry) => entry.isNotEmpty)
        .toSet()
        .toList(growable: false);
  }

  static List<String> _mergeClanIds({
    required String preferredClanId,
    required List<String> clanIds,
  }) {
    final deduped = <String>{};
    final ordered = <String>[];
    if (preferredClanId.isNotEmpty) {
      deduped.add(preferredClanId);
      ordered.add(preferredClanId);
    }
    for (final entry in clanIds) {
      if (deduped.add(entry)) {
        ordered.add(entry);
      }
    }
    return ordered;
  }

  static String _clean(String? value, {String fallback = ''}) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? fallback : trimmed;
  }

  static String _buildSyncFingerprint({
    required String uid,
    required String memberId,
    required String clanId,
    required List<String> clanIds,
    required String branchId,
    required String primaryRole,
    required String accessMode,
    required bool linkedAuthUid,
  }) {
    return [
      uid,
      memberId,
      clanId,
      clanIds.join(','),
      branchId,
      primaryRole,
      accessMode,
      linkedAuthUid ? '1' : '0',
    ].join('|');
  }

  @visibleForTesting
  static void resetForTest() {
    _lastSyncedSnapshotByUid.clear();
    _claimsSnapshotByUid.clear();
    _inflightSyncByUid.clear();
  }
}

class _SessionSyncSnapshot {
  const _SessionSyncSnapshot({
    required this.fingerprint,
    required this.syncedAt,
  });

  final String fingerprint;
  final DateTime syncedAt;
}

class _ClaimsSnapshot {
  const _ClaimsSnapshot({required this.claims, required this.resolvedAt});

  final Map<String, dynamic> claims;
  final DateTime resolvedAt;
}
