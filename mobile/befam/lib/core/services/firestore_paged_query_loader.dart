import 'package:cloud_firestore/cloud_firestore.dart';

typedef FirestoreDocumentSnapshot = QueryDocumentSnapshot<Map<String, dynamic>>;

class FirestorePagedQueryLoader {
  const FirestorePagedQueryLoader();

  Future<List<FirestoreDocumentSnapshot>> loadAll({
    required Query<Map<String, dynamic>> baseQuery,
    int pageSize = 200,
    int maxDocuments = 2000,
  }) async {
    final safePageSize = pageSize.clamp(1, 500).toInt();
    final safeMaxDocuments = maxDocuments.clamp(1, 10000).toInt();
    final docs = <FirestoreDocumentSnapshot>[];
    FirestoreDocumentSnapshot? cursor;

    while (docs.length < safeMaxDocuments) {
      final remaining = safeMaxDocuments - docs.length;
      final pageLimit = remaining < safePageSize ? remaining : safePageSize;
      final query = cursor == null
          ? baseQuery.limit(pageLimit)
          : baseQuery.limit(pageLimit).startAfterDocument(cursor);
      final snapshot = await query.get();
      if (snapshot.docs.isEmpty) {
        break;
      }

      docs.addAll(snapshot.docs);
      if (snapshot.docs.length < pageLimit) {
        break;
      }
      cursor = snapshot.docs.last;
    }

    if (docs.length <= safeMaxDocuments) {
      return docs;
    }
    return docs.take(safeMaxDocuments).toList(growable: false);
  }
}
