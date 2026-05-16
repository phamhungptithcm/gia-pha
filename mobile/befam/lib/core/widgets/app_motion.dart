import 'package:flutter/material.dart';

abstract final class AppMotion {
  static const Duration quick = Duration(milliseconds: 140);
  static const Duration standard = Duration(milliseconds: 180);
  static const Duration emphasized = Duration(milliseconds: 220);

  static const Curve enterCurve = Curves.easeOutCubic;
  static const Curve exitCurve = Curves.easeInCubic;
  static const Curve emphasizedCurve = Curves.easeOutQuart;

  static bool isReduced(BuildContext context) {
    return MediaQuery.maybeOf(context)?.disableAnimations ?? false;
  }

  static Widget noSwitcherTransition(
    Widget child,
    Animation<double> animation,
  ) {
    return child;
  }
}

class BeFamPageTransitionsBuilder extends PageTransitionsBuilder {
  const BeFamPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // Route clicks should keep clan data stable; use local control feedback.
    return child;
  }
}

class AppPageEntrance extends StatelessWidget {
  const AppPageEntrance({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = AppMotion.emphasized,
  });

  final Widget child;
  final Duration delay;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return child;
  }
}

class AppStaggeredEntrance extends StatelessWidget {
  const AppStaggeredEntrance({
    super.key,
    required this.index,
    required this.child,
    this.step = const Duration(milliseconds: 34),
    this.maxDelay = const Duration(milliseconds: 170),
  });

  final int index;
  final Widget child;
  final Duration step;
  final Duration maxDelay;

  @override
  Widget build(BuildContext context) {
    return child;
  }
}
