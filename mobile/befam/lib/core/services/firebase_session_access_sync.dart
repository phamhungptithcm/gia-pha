import 'package:cloud_firestore/cloud_firestore.dart';

import '../../features/auth/models/auth_session.dart';

class FirebaseSessionAccessSync {
  FirebaseSessionAccessSync._();

  static Future<void> ensureUserSessionDocument({
    required FirebaseFirestore firestore,
    required AuthSession session,
  }) async {
    final uid = session.uid.trim();
    if (uid.isEmpty) {
      return;
    }

    final clanId = _clean(session.clanId);
    final branchId = _clean(session.branchId);
    final primaryRole = _clean(session.primaryRole, fallback: 'GUEST');
    final now = FieldValue.serverTimestamp();

    await firestore.collection('users').doc(uid).set({
      'uid': uid,
      'memberId': _clean(session.memberId),
      'clanId': clanId,
      'clanIds': clanId.isEmpty ? <String>[] : [clanId],
      'branchId': branchId,
      'primaryRole': primaryRole,
      'accessMode': session.accessMode.name,
      'linkedAuthUid': session.linkedAuthUid,
      'updatedAt': now,
      'createdAt': now,
    }, SetOptions(merge: true));
  }

  static String _clean(String? value, {String fallback = ''}) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? fallback : trimmed;
  }
}
