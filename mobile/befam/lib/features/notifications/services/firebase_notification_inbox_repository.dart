import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/services/firebase_session_access_sync.dart';
import '../../../core/services/firebase_services.dart';
import '../../auth/models/auth_session.dart';
import '../models/notification_inbox_item.dart';
import 'notification_inbox_repository.dart';

class FirebaseNotificationInboxRepository
    implements NotificationInboxRepository {
  FirebaseNotificationInboxRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseServices.firestore;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _notifications =>
      _firestore.collection('notifications');

  @override
  bool get isSandbox => false;

  @override
  Future<List<NotificationInboxItem>> loadInbox({
    required AuthSession session,
    int limit = 25,
  }) async {
    await FirebaseSessionAccessSync.ensureUserSessionDocument(
      firestore: _firestore,
      session: session,
    );

    final memberId = session.memberId?.trim() ?? '';
    if (memberId.isEmpty) {
      return const [];
    }

    final effectiveLimit = limit.clamp(1, 100);
    final snapshot = await _notifications
        .where('memberId', isEqualTo: memberId)
        .orderBy('createdAt', descending: true)
        .limit(effectiveLimit)
        .get();

    return snapshot.docs
        .map(
          (doc) => NotificationInboxItem.fromFirestore(
            documentId: doc.id,
            json: doc.data(),
          ),
        )
        .toList(growable: false);
  }
}
