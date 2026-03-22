import '../models/genealogy_read_segment.dart';
import '../models/genealogy_scope.dart';

class GenealogySegmentCache {
  GenealogySegmentCache._();

  static final GenealogySegmentCache _shared = GenealogySegmentCache._();

  factory GenealogySegmentCache.shared() => _shared;

  static const Duration _ttl = Duration(minutes: 5);

  final Map<String, _CacheEntry> _entries = {};

  GenealogyReadSegment? read(GenealogyScope scope) {
    final entry = _entries[scope.cacheKey];
    if (entry == null) {
      return null;
    }
    if (DateTime.now().difference(entry.cachedAt) > _ttl) {
      _entries.remove(scope.cacheKey);
      return null;
    }
    return entry.segment.copyWith(fromCache: true);
  }

  void write(GenealogyReadSegment segment) {
    _entries[segment.scope.cacheKey] = _CacheEntry(
      segment: segment.copyWith(fromCache: false),
      cachedAt: DateTime.now(),
    );
  }

  void clear([GenealogyScope? scope]) {
    if (scope == null) {
      _entries.clear();
      return;
    }
    _entries.remove(scope.cacheKey);
  }
}

class _CacheEntry {
  const _CacheEntry({required this.segment, required this.cachedAt});

  final GenealogyReadSegment segment;
  final DateTime cachedAt;
}
