import 'package:flutter/material.dart';

import 'app_loading_skeletons.dart';

class AppLoadingState extends StatelessWidget {
  const AppLoadingState({
    super.key,
    required this.message,
    this.semanticLabel,
    this.padding = const EdgeInsets.all(24),
    this.showSkeleton = true,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String? semanticLabel;
  final EdgeInsetsGeometry padding;
  final bool showSkeleton;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: padding,
        child: Semantics(
          container: true,
          liveRegion: true,
          label: semanticLabel ?? message,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showSkeleton) ...[
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 320),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppSkeletonBox(width: 210, height: 16),
                      SizedBox(height: 10),
                      AppSkeletonBox(width: 260, height: 14),
                      SizedBox(height: 8),
                      AppSkeletonBox(width: 180, height: 14),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      message,
                      textAlign: TextAlign.center,
                      style: textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 14),
                TextButton.icon(
                  onPressed: onAction,
                  icon: const Icon(Icons.refresh),
                  label: Text(actionLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class AppInlineProgressIndicator extends StatelessWidget {
  const AppInlineProgressIndicator({
    super.key,
    this.size = 18,
    this.strokeWidth = 2,
    required this.semanticLabel,
  });

  final double size;
  final double strokeWidth;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      liveRegion: true,
      label: semanticLabel,
      child: SizedBox(
        width: size,
        height: size,
        child: CircularProgressIndicator(strokeWidth: strokeWidth),
      ),
    );
  }
}
