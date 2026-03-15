import '../../../core/services/runtime_mode.dart';
import '../../auth/models/auth_session.dart';
import '../models/genealogy_discovery_result.dart';
import '../models/join_request_draft.dart';
import '../models/join_request_review_item.dart';
import 'debug_genealogy_discovery_repository.dart';
import 'firebase_genealogy_discovery_repository.dart';

abstract interface class GenealogyDiscoveryRepository {
  bool get isSandbox;

  Future<List<GenealogyDiscoveryResult>> search({
    String? query,
    String? leaderQuery,
    String? locationQuery,
    int limit = 20,
  });

  Future<void> submitJoinRequest({required JoinRequestDraft draft});

  Future<List<JoinRequestReviewItem>> loadPendingJoinRequests({
    required AuthSession session,
  });

  Future<void> reviewJoinRequest({
    required AuthSession session,
    required String requestId,
    required bool approve,
    String? note,
  });
}

GenealogyDiscoveryRepository createDefaultGenealogyDiscoveryRepository({
  AuthSession? session,
}) {
  final useMockBackend = session?.isSandbox ?? RuntimeMode.shouldUseMockBackend;
  if (useMockBackend) {
    return DebugGenealogyDiscoveryRepository.seeded();
  }
  return FirebaseGenealogyDiscoveryRepository();
}
