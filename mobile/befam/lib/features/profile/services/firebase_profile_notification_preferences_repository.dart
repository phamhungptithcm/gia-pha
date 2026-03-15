import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/services/firebase_services.dart';
import '../../../core/services/firebase_session_access_sync.dart';
import '../../auth/models/auth_session.dart';
import '../models/profile_notification_preferences.dart';
import 'profile_notification_preferences_repository.dart';

class FirebaseProfileNotificationPreferencesRepository
    implements ProfileNotificationPreferencesRepository {
  FirebaseProfileNotificationPreferencesRepository({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseServices.firestore;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  @override
  bool get isSandbox => false;

  @override
  Future<ProfileNotificationPreferences> load({
    required AuthSession session,
  }) async {
    final uid = session.uid.trim();
    if (uid.isEmpty) {
      return const ProfileNotificationPreferences();
    }

    await FirebaseSessionAccessSync.ensureUserSessionDocument(
      firestore: _firestore,
      session: session,
    );

    final snapshot = await _users
        .doc(uid)
        .collection('preferences')
        .doc('notifications')
        .get();
    final data = snapshot.data();
    if (data == null || data.isEmpty) {
      return const ProfileNotificationPreferences();
    }

    return ProfileNotificationPreferences.fromJson(data);
  }

  @override
  Future<ProfileNotificationPreferences> save({
    required AuthSession session,
    required ProfileNotificationPreferences preferences,
  }) async {
    final uid = session.uid.trim();
    if (uid.isEmpty) {
      return preferences;
    }

    await FirebaseSessionAccessSync.ensureUserSessionDocument(
      firestore: _firestore,
      session: session,
    );

    final memberId = (session.memberId ?? '').trim();
    final clanId = (session.clanId ?? '').trim();
    final branchId = (session.branchId ?? '').trim();
    await _users.doc(uid).collection('preferences').doc('notifications').set({
      'id': 'notifications',
      'uid': uid,
      'memberId': memberId,
      'clanId': clanId,
      'branchId': branchId,
      ...preferences.toJson(),
      'updatedBy': uid,
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return preferences;
  }
}
