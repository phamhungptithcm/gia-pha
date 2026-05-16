import 'package:flutter/material.dart';

abstract final class AppMotion {
  static const Duration quick = Duration(milliseconds: 140);
  static const Duration standard = Duration(milliseconds: 220);
  static const Duration emphasized = Duration(milliseconds: 340);

  static const Curve enterCurve = Curves.easeOutCubic;
  static const Curve exitCurve = Curves.easeInCubic;
  static const Curve emphasizedCurve = Curves.easeOutQuart;

  static bool isReduced(BuildContext context) {
    return MediaQuery.maybeOf(context)?.disableAnimations ?? false;
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
    if (AppMotion.isReduced(context) || route.fullscreenDialog) {
      return FadeTransition(opacity: animation, child: child);
    }

    final curved = CurvedAnimation(
      parent: animation,
      curve: AppMotion.enterCurve,
      reverseCurve: AppMotion.exitCurve,
    );
    final secondaryCurved = CurvedAnimation(
      parent: secondaryAnimation,
      curve: AppMotion.exitCurve,
      reverseCurve: AppMotion.enterCurve,
    );

    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.035, 0.02),
          end: Offset.zero,
        ).animate(curved),
        child: SlideTransition(
          position: Tween<Offset>(
            begin: Offset.zero,
            end: const Offset(-0.012, 0),
          ).animate(secondaryCurved),
          child: child,
        ),
      ),
    );
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
    if (AppMotion.isReduced(context)) {
      return child;
    }

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: delay + duration,
      curve: AppMotion.emphasizedCurve,
      child: child,
      builder: (context, value, child) {
        final delayFraction = delay.inMicroseconds <= 0
            ? 0.0
            : delay.inMicroseconds /
                  (delay.inMicroseconds + duration.inMicroseconds);
        final progress = delayFraction >= 1
            ? 1.0
            : ((value - delayFraction) / (1 - delayFraction))
                  .clamp(0.0, 1.0)
                  .toDouble();
        return Opacity(
          opacity: progress,
          child: Transform.translate(
            offset: Offset(0, (1 - progress) * 14),
            child: child,
          ),
        );
      },
    );
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
    final delayMs = (index.clamp(0, 10) * step.inMilliseconds)
        .clamp(0, maxDelay.inMilliseconds)
        .toInt();
    return AppPageEntrance(
      delay: Duration(milliseconds: delayMs),
      duration: AppMotion.standard,
      child: child,
    );
  }
}
