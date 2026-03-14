import '../models/genealogy_read_segment.dart';
import '../models/genealogy_scope.dart';

class GenealogySegmentCache {
  GenealogySegmentCache._();

  static final GenealogySegmentCache _shared = GenealogySegmentCache._();

  factory GenealogySegmentCache.shared() => _shared;

  final Map<String, GenealogyReadSegment> _entries = {};

  GenealogyReadSegment? read(GenealogyScope scope) {
    final entry = _entries[scope.cacheKey];
    if (entry == null) {
      return null;
    }
    return entry.copyWith(fromCache: true);
  }

  void write(GenealogyReadSegment segment) {
    _entries[segment.scope.cacheKey] = segment.copyWith(fromCache: false);
  }

  void clear([GenealogyScope? scope]) {
    if (scope == null) {
      _entries.clear();
      return;
    }
    _entries.remove(scope.cacheKey);
  }
}
