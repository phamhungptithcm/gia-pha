import '../../../core/services/debug_genealogy_store.dart';
import '../../../core/services/runtime_mode.dart';
import '../../auth/models/auth_session.dart';
import '../models/genealogy_read_segment.dart';
import 'debug_genealogy_read_repository.dart';
import 'firebase_genealogy_read_repository.dart';
import 'genealogy_segment_cache.dart';

abstract interface class GenealogyReadRepository {
  bool get isSandbox;

  Future<GenealogyReadSegment> loadClanSegment({
    required AuthSession session,
    bool allowCached = true,
  });

  Future<GenealogyReadSegment> loadBranchSegment({
    required AuthSession session,
    String? branchId,
    bool allowCached = true,
  });
}

GenealogyReadRepository createDefaultGenealogyReadRepository() {
  final cache = GenealogySegmentCache.shared();
  if (RuntimeMode.shouldUseMockBackend) {
    return DebugGenealogyReadRepository(
      store: DebugGenealogyStore.sharedSeeded(),
      cache: cache,
    );
  }

  return FirebaseGenealogyReadRepository(cache: cache);
}
