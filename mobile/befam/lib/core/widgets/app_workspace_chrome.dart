import 'package:flutter/material.dart';

import '../../app/theme/app_ui_tokens.dart';
import 'app_motion.dart';
import 'responsive_layout.dart';

EdgeInsets appWorkspacePagePadding(
  BuildContext context, {
  double? top,
  double? bottom,
}) {
  final layout = ResponsiveLayout.of(context);
  final tokens = context.uiTokens;
  return EdgeInsets.fromLTRB(
    layout.horizontalPadding,
    top ?? tokens.spaceLg,
    layout.horizontalPadding,
    bottom ?? (tokens.space2xl + tokens.spaceSm),
  );
}

LinearGradient appWorkspaceHeroGradient(BuildContext context) {
  final colorScheme = Theme.of(context).colorScheme;
  return LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Colors.white.withValues(alpha: 0.96),
      colorScheme.primaryContainer.withValues(alpha: 0.34),
      colorScheme.surface.withValues(alpha: 0.96),
    ],
  );
}

class AppLineageBackdrop extends StatelessWidget {
  const AppLineageBackdrop({super.key, required this.child, this.opacity = 1});

  final Widget child;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(color: colorScheme.surface),
      child: Stack(
        children: [
          Positioned.fill(child: AppLineageGridOverlay(opacity: opacity)),
          child,
        ],
      ),
    );
  }
}

class AppLineageGridOverlay extends StatelessWidget {
  const AppLineageGridOverlay({super.key, this.opacity = 1, this.spacing = 32});

  final double opacity;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _LineageGridPainter(
            spacing: spacing,
            lineColor: colorScheme.primary.withValues(alpha: 0.055 * opacity),
            accentColor: colorScheme.secondary.withValues(alpha: 0),
          ),
        ),
      ),
    );
  }
}

class AppWorkspaceViewport extends StatelessWidget {
  const AppWorkspaceViewport({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final layout = ResponsiveLayout.of(context);
    return RepaintBoundary(
      child: AppPageEntrance(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: layout.contentMaxWidth),
            child: child,
          ),
        ),
      ),
    );
  }
}

class AppWorkspaceSurface extends StatelessWidget {
  const AppWorkspaceSurface({
    super.key,
    required this.child,
    this.padding,
    this.color,
    this.gradient,
    this.showAccentOrbs = false,
    this.borderRadius,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final Gradient? gradient;
  final bool showAccentOrbs;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final tokens = context.uiTokens;
    final colorScheme = Theme.of(context).colorScheme;
    final resolvedRadius =
        borderRadius ?? BorderRadius.circular(tokens.radiusLg);

    final decoration = BoxDecoration(
      color: color ?? Colors.white.withValues(alpha: 0.90),
      gradient: gradient,
      borderRadius: resolvedRadius,
      border: Border.all(
        color: colorScheme.outlineVariant.withValues(alpha: 0.82),
      ),
      boxShadow: [
        BoxShadow(
          color: colorScheme.shadow.withValues(alpha: 0.045),
          blurRadius: 28,
          offset: const Offset(0, 16),
        ),
      ],
    );

    final content = ClipRRect(
      borderRadius: resolvedRadius,
      child: Stack(
        children: [
          if (showAccentOrbs)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _LineageGridPainter(
                    spacing: 28,
                    lineColor: colorScheme.primary.withValues(alpha: 0.04),
                    accentColor: colorScheme.secondary.withValues(alpha: 0),
                  ),
                ),
              ),
            ),
          Padding(
            padding: padding ?? EdgeInsets.all(tokens.spaceLg),
            child: child,
          ),
        ],
      ),
    );

    if (AppMotion.isReduced(context)) {
      return RepaintBoundary(
        child: DecoratedBox(decoration: decoration, child: content),
      );
    }

    return RepaintBoundary(
      child: AnimatedContainer(
        duration: AppMotion.standard,
        curve: AppMotion.enterCurve,
        decoration: decoration,
        child: content,
      ),
    );
  }
}

class _LineageGridPainter extends CustomPainter {
  const _LineageGridPainter({
    required this.lineColor,
    required this.accentColor,
    this.spacing = 32,
  });

  final Color lineColor;
  final Color accentColor;
  final double spacing;

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 1;
    for (double x = 0; x <= size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
    }
    for (double y = 0; y <= size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    // The shared workspace pattern stays as a quiet grid. Decorative rings or
    // blobs make dense genealogy and finance screens harder to scan.
  }

  @override
  bool shouldRepaint(covariant _LineageGridPainter oldDelegate) {
    return oldDelegate.lineColor != lineColor ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.spacing != spacing;
  }
}
