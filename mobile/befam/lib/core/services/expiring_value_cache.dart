class ExpiringValueCache<TKey, TValue> {
  ExpiringValueCache({required this.ttl, DateTime Function()? nowProvider})
    : _nowProvider = nowProvider ?? DateTime.now;

  final Duration ttl;
  final DateTime Function() _nowProvider;
  final Map<TKey, _ExpiringValueCacheEntry<TValue>> _entries =
      <TKey, _ExpiringValueCacheEntry<TValue>>{};

  TValue? read(TKey key) {
    final entry = _entries[key];
    if (entry == null) {
      return null;
    }

    final now = _nowProvider();
    if (now.difference(entry.cachedAt) > ttl) {
      _entries.remove(key);
      return null;
    }

    return entry.value;
  }

  void write(TKey key, TValue value) {
    _entries[key] = _ExpiringValueCacheEntry<TValue>(
      value: value,
      cachedAt: _nowProvider(),
    );
  }

  void invalidate([TKey? key]) {
    if (key == null) {
      _entries.clear();
      return;
    }
    _entries.remove(key);
  }
}

class _ExpiringValueCacheEntry<TValue> {
  const _ExpiringValueCacheEntry({required this.value, required this.cachedAt});

  final TValue value;
  final DateTime cachedAt;
}
