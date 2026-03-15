import 'package:flutter/material.dart';

class AppLoadingState extends StatelessWidget {
  const AppLoadingState({
    super.key,
    required this.message,
    this.semanticLabel,
    this.padding = const EdgeInsets.all(24),
  });

  final String message;
  final String? semanticLabel;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

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
              SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.8,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
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
