import 'package:flutter/widgets.dart';

import '../services/app_locale_controller.dart';

class AppLocaleScope extends InheritedNotifier<AppLocaleController> {
  const AppLocaleScope({
    super.key,
    required AppLocaleController controller,
    required super.child,
  }) : super(notifier: controller);

  static AppLocaleController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<AppLocaleScope>()
        ?.notifier;
  }

  static AppLocaleController of(BuildContext context) {
    final controller = maybeOf(context);
    assert(controller != null, 'AppLocaleScope not found in context.');
    return controller!;
  }
}
