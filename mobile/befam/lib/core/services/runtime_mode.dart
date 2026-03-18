import 'package:flutter/widgets.dart';

class RuntimeMode {
  const RuntimeMode._();

  static const bool forceTestMode = bool.fromEnvironment('FLUTTER_TEST');

  static bool get shouldUseMockBackend {
    return forceTestMode || _isWidgetTestBinding();
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
