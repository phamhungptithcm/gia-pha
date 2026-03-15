import 'package:cloud_functions/cloud_functions.dart';

import '../../../core/services/firebase_services.dart';
import '../../../core/services/firebase_session_access_sync.dart';
import '../../auth/models/auth_session.dart';
import '../models/genealogy_discovery_result.dart';
import '../models/join_request_draft.dart';
import '../models/join_request_review_item.dart';
import 'genealogy_discovery_repository.dart';

class FirebaseGenealogyDiscoveryRepository
    implements GenealogyDiscoveryRepository {
  FirebaseGenealogyDiscoveryRepository({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'asia-southeast1');

  final FirebaseFunctions _functions;

  @override
  bool get isSandbox => false;

  @override
  Future<List<GenealogyDiscoveryResult>> search({
    String? query,
    String? leaderQuery,
    String? locationQuery,
    int limit = 20,
  }) async {
    final callable = _functions.httpsCallable('searchGenealogyDiscovery');
    final response = await callable.call(<String, dynamic>{
      'query': query?.trim(),
      'leaderQuery': leaderQuery?.trim(),
      'locationQuery': locationQuery?.trim(),
      'limit': limit,
    });
    final payload = _asMap(response.data);
    final entries = payload['results'];
    if (entries is! List) {
      return const [];
    }
    return entries
        .whereType<Map>()
        .map(
          (item) => GenealogyDiscoveryResult.fromJson(
            item.map((key, value) => MapEntry(key.toString(), value)),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<void> submitJoinRequest({required JoinRequestDraft draft}) async {
    final callable = _functions.httpsCallable('submitJoinRequest');
    await callable.call(draft.toPayload());
  }

  @override
  Future<List<JoinRequestReviewItem>> loadPendingJoinRequests({
    required AuthSession session,
  }) async {
    await FirebaseSessionAccessSync.ensureUserSessionDocument(
      firestore: FirebaseServices.firestore,
      session: session,
    );
    final callable = _functions.httpsCallable('listJoinRequestsForReview');
    final response = await callable.call(<String, dynamic>{
      'status': 'pending',
    });
    final payload = _asMap(response.data);
    final entries = payload['requests'];
    if (entries is! List) {
      return const [];
    }
    return entries
        .whereType<Map>()
        .map(
          (item) => JoinRequestReviewItem.fromJson(
            item.map((key, value) => MapEntry(key.toString(), value)),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<void> reviewJoinRequest({
    required AuthSession session,
    required String requestId,
    required bool approve,
    String? note,
  }) async {
    await FirebaseSessionAccessSync.ensureUserSessionDocument(
      firestore: FirebaseServices.firestore,
      session: session,
    );
    final callable = _functions.httpsCallable('reviewJoinRequest');
    await callable.call(<String, dynamic>{
      'requestId': requestId,
      'decision': approve ? 'approve' : 'reject',
      if ((note ?? '').trim().isNotEmpty) 'note': note!.trim(),
    });
  }

  Map<String, dynamic> _asMap(Object? value) {
    if (value is! Map) {
      return const {};
    }
    return value.map((key, entry) => MapEntry(key.toString(), entry));
  }
}
