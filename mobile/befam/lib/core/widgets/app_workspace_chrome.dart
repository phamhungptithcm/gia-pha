import 'package:flutter/material.dart';

import '../../app/theme/app_ui_tokens.dart';
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
      colorScheme.primaryContainer.withValues(alpha: 0.94),
      colorScheme.secondaryContainer.withValues(alpha: 0.82),
      Colors.white.withValues(alpha: 0.96),
    ],
  );
}

class AppWorkspaceViewport extends StatelessWidget {
  const AppWorkspaceViewport({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final layout = ResponsiveLayout.of(context);
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: layout.contentMaxWidth),
        child: child,
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

    return DecoratedBox(
      decoration: BoxDecoration(
        color: color ?? Colors.white.withValues(alpha: 0.88),
        gradient: gradient,
        borderRadius: resolvedRadius,
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.92),
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.08),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: resolvedRadius,
        child: Stack(
          children: [
            if (showAccentOrbs) ...[
              Positioned(
                top: -44,
                right: -24,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colorScheme.secondary.withValues(alpha: 0.16),
                  ),
                  child: const SizedBox(width: 136, height: 136),
                ),
              ),
              Positioned(
                left: -34,
                bottom: -46,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colorScheme.primary.withValues(alpha: 0.08),
                  ),
                  child: const SizedBox(width: 128, height: 128),
                ),
              ),
            ],
            Padding(
              padding: padding ?? EdgeInsets.all(tokens.spaceLg),
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}
