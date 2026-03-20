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
  Future<NotificationInboxPageResult> loadInboxPage({
    required AuthSession session,
    int limit = 20,
    NotificationInboxCursor? cursor,
  }) async {
    await FirebaseSessionAccessSync.ensureUserSessionDocument(
      firestore: _firestore,
      session: session,
    );

    final memberId = session.memberId?.trim() ?? '';
    if (memberId.isEmpty) {
      return const NotificationInboxPageResult(items: [], nextCursor: null);
    }

    final pageSize = limit.clamp(1, 100);
    var query = _notifications
        .where('memberId', isEqualTo: memberId)
        .orderBy('createdAt', descending: true)
        .orderBy(FieldPath.documentId, descending: true)
        .limit(pageSize + 1);

    final cursorCreatedAt = cursor?.createdAt;
    final cursorDocumentId = cursor?.documentId.trim() ?? '';
    if (cursorCreatedAt != null && cursorDocumentId.isNotEmpty) {
      query = query.startAfter([
        Timestamp.fromDate(cursorCreatedAt),
        cursorDocumentId,
      ]);
    }

    final snapshot = await query.get();

    final mappedItems = snapshot.docs
        .map(
          (doc) => NotificationInboxItem.fromFirestore(
            documentId: doc.id,
            json: doc.data(),
          ),
        )
        .toList(growable: false);

    if (mappedItems.isEmpty) {
      return const NotificationInboxPageResult(items: [], nextCursor: null);
    }

    final hasMore = mappedItems.length > pageSize;
    final visibleItems = hasMore
        ? mappedItems.take(pageSize).toList(growable: false)
        : mappedItems;
    final nextCursor = hasMore
        ? NotificationInboxCursor(
            createdAt: visibleItems.last.createdAt,
            documentId: visibleItems.last.id,
          )
        : null;

    return NotificationInboxPageResult(
      items: visibleItems,
      nextCursor: nextCursor,
    );
  }

  @override
  Future<void> markAsRead({
    required AuthSession session,
    required String notificationId,
  }) async {
    await FirebaseSessionAccessSync.ensureUserSessionDocument(
      firestore: _firestore,
      session: session,
    );

    final normalizedId = notificationId.trim();
    if (normalizedId.isEmpty) {
      return;
    }

    await _notifications.doc(normalizedId).update({'isRead': true});
  }
}
