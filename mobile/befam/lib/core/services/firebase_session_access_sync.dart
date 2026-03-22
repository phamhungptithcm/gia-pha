import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../features/auth/models/auth_session.dart';

class FirebaseSessionAccessSync {
  FirebaseSessionAccessSync._();

  static final Set<String> _syncedUids = {};

  static void invalidate(String uid) {
    _syncedUids.remove(uid);
  }

  static Future<void> ensureUserSessionDocument({
    required FirebaseFirestore firestore,
    required AuthSession session,
    FirebaseAuth? auth,
    bool forceRefresh = false,
  }) async {
    final uid = session.uid.trim();
    if (uid.isEmpty) {
      return;
    }

    if (_syncedUids.contains(uid) && !forceRefresh) {
      return;
    }

    final claims = await _resolveClaims(auth);
    final claimClanIds = _asStringList(claims?['clanIds']);
    final claimClanId = _clean(_asString(claims?['clanId']));
    final claimActiveClanId = _clean(_asString(claims?['activeClanId']));
    final sessionClanId = _clean(session.clanId);
    final clanIds = _mergeClanIds(
      preferredClanId: claimActiveClanId.isNotEmpty
          ? claimActiveClanId
          : (claimClanId.isNotEmpty ? claimClanId : sessionClanId),
      clanIds: claimClanIds.isNotEmpty
          ? claimClanIds
          : (sessionClanId.isEmpty ? const <String>[] : [sessionClanId]),
    );
    final clanId = clanIds.isEmpty ? '' : clanIds.first;
    final branchId = _clean(
      _asString(claims?['branchId']),
      fallback: _clean(session.branchId),
    );
    final memberId = _clean(
      _asString(claims?['memberId']),
      fallback: _clean(session.memberId),
    );
    final primaryRole = _clean(
      _asString(claims?['primaryRole']),
      fallback: _clean(session.primaryRole, fallback: 'GUEST'),
    );
    final accessMode = _clean(
      _asString(claims?['memberAccessMode']),
      fallback: session.accessMode.name,
    );
    final now = FieldValue.serverTimestamp();

    await firestore.collection('users').doc(uid).set({
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
    }, SetOptions(merge: true));
    _syncedUids.add(uid);
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
}
