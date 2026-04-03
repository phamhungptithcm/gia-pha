import 'package:befam/core/services/expiring_value_cache.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('returns cached value before ttl expires', () {
    var now = DateTime(2026, 1, 1, 10);
    final cache = ExpiringValueCache<String, String>(
      ttl: const Duration(seconds: 30),
      nowProvider: () => now,
    );

    cache.write('profile', 'ready');

    now = now.add(const Duration(seconds: 29));
    expect(cache.read('profile'), 'ready');
  });

  test('evicts cached value after ttl expires', () {
    var now = DateTime(2026, 1, 1, 10);
    final cache = ExpiringValueCache<String, String>(
      ttl: const Duration(seconds: 30),
      nowProvider: () => now,
    );

    cache.write('profile', 'ready');

    now = now.add(const Duration(seconds: 31));
    expect(cache.read('profile'), isNull);
  });

  test('invalidate clears a single key or the entire cache', () {
    final cache = ExpiringValueCache<String, String>(
      ttl: const Duration(minutes: 1),
    );

    cache
      ..write('a', '1')
      ..write('b', '2');

    cache.invalidate('a');
    expect(cache.read('a'), isNull);
    expect(cache.read('b'), '2');

    cache.invalidate();
    expect(cache.read('b'), isNull);
  });
}
