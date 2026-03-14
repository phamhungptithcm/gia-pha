import 'package:flutter/foundation.dart';

import '../../../core/services/debug_genealogy_store.dart';
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
  const useLiveBackend = bool.fromEnvironment('BEFAM_USE_LIVE_AUTH');
  final cache = GenealogySegmentCache.shared();
  if (kDebugMode && !useLiveBackend) {
    return DebugGenealogyReadRepository(
      store: DebugGenealogyStore.sharedSeeded(),
      cache: cache,
    );
  }

  return FirebaseGenealogyReadRepository(cache: cache);
}
