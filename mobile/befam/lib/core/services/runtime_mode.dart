import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

class RuntimeMode {
  const RuntimeMode._();

  static const bool useLiveFirebase = bool.fromEnvironment(
    'BEFAM_USE_LIVE_AUTH',
    defaultValue: true,
  );
  static const bool forceMockBackend = bool.fromEnvironment(
    'BEFAM_USE_MOCK_AUTH',
  );
  static const bool forceTestMode = bool.fromEnvironment('FLUTTER_TEST');

  static bool get shouldUseMockBackend {
    return forceTestMode || _isWidgetTestBinding() || _isDebugMockOverride;
  }

  static bool get _isDebugMockOverride {
    return kDebugMode && (!useLiveFirebase || forceMockBackend);
  }

  static bool _isWidgetTestBinding() {
    try {
      final bindingType = WidgetsBinding.instance.runtimeType.toString();
      return bindingType.contains('TestWidgetsFlutterBinding');
    } catch (_) {
      return false;
    }
  }
}
