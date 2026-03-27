class InflightTaskCache<TKey, TValue> {
  final Map<TKey, Future<TValue>> _pendingByKey = <TKey, Future<TValue>>{};

  Future<TValue> run(TKey key, Future<TValue> Function() task) {
    final existing = _pendingByKey[key];
    if (existing != null) {
      return existing;
    }

    final future = task();
    _pendingByKey[key] = future;
    return future.whenComplete(() {
      _pendingByKey.remove(key);
    });
  }

  void invalidate([TKey? key]) {
    if (key == null) {
      _pendingByKey.clear();
      return;
    }
    _pendingByKey.remove(key);
  }
}
