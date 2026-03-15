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
  static const String localAuthBypass = String.fromEnvironment(
    'BEFAM_LOCAL_AUTH_BYPASS',
    defaultValue: 'auto',
  );
  static const bool forceTestMode = bool.fromEnvironment('FLUTTER_TEST');

  static bool get shouldUseMockBackend {
    return forceTestMode ||
        _isWidgetTestBinding() ||
        shouldBypassPhoneOtp ||
        _isDebugMockOverride;
  }

  static bool get shouldBypassPhoneOtp {
    final mode = localAuthBypass.toLowerCase().trim();
    if (mode == 'on' || mode == 'true' || mode == '1') {
      return true;
    }
    if (mode == 'off' || mode == 'false' || mode == '0') {
      return false;
    }
    return kDebugMode;
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
