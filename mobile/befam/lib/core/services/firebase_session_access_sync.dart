import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../features/auth/models/auth_session.dart';

class FirebaseSessionAccessSync {
  FirebaseSessionAccessSync._();

  static Future<void> ensureUserSessionDocument({
    required FirebaseFirestore firestore,
    required AuthSession session,
    FirebaseAuth? auth,
  }) async {
    final uid = session.uid.trim();
    if (uid.isEmpty) {
      return;
    }

    final claims = await _resolveClaims(auth);
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

    try {
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
    } catch (_) {
      // Session sync is best-effort; do not block feature flows when claims/rules are in transition.
      return;
    }
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
