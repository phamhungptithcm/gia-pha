import 'package:flutter/material.dart';

class AppSkeletonBox extends StatefulWidget {
  const AppSkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(10)),
    this.margin,
  });

  final double? width;
  final double height;
  final BorderRadiusGeometry borderRadius;
  final EdgeInsetsGeometry? margin;

  @override
  State<AppSkeletonBox> createState() => _AppSkeletonBoxState();
}

class _AppSkeletonBoxState extends State<AppSkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final baseColor = colorScheme.surfaceContainerHighest.withValues(
      alpha: 0.62,
    );
    final pulseColor = colorScheme.surfaceContainerHighest.withValues(
      alpha: 0.28,
    );
    final box = AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return DecoratedBox(
          decoration: BoxDecoration(
            color: Color.lerp(baseColor, pulseColor, _controller.value),
            borderRadius: widget.borderRadius,
          ),
          child: SizedBox(width: widget.width, height: widget.height),
        );
      },
    );
    final margin = widget.margin;
    if (margin == null) {
      return box;
    }
    return Padding(padding: margin, child: box);
  }
}
