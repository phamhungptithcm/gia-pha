import 'package:befam/features/ads/services/ad_policy.dart';
import 'package:befam/features/ads/services/ad_remote_config_provider.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeFirebaseAdRemoteConfigProvider implements AdRemoteConfigProvider {
  @override
  Future<AdPolicy> load() async => AdPolicy.defaults;
}

void main() {
  test(
    'falls back to default ad remote config provider when Firebase is unavailable',
    () {
      final provider = createDefaultAdRemoteConfigProvider(
        hasFirebaseApp: () => false,
      );

      expect(provider, isA<DefaultAdRemoteConfigProvider>());
    },
  );

  test('returns Firebase-backed provider when a Firebase app is available', () {
    final provider = createDefaultAdRemoteConfigProvider(
      hasFirebaseApp: () => true,
      firebaseProviderFactory: () => _FakeFirebaseAdRemoteConfigProvider(),
    );

    expect(provider, isA<_FakeFirebaseAdRemoteConfigProvider>());
  });

  test(
    'falls back to default provider when Firebase bootstrap probe throws',
    () {
      final provider = createDefaultAdRemoteConfigProvider(
        hasFirebaseApp: () => throw StateError('bootstrap unavailable'),
      );

      expect(provider, isA<DefaultAdRemoteConfigProvider>());
    },
  );
}
