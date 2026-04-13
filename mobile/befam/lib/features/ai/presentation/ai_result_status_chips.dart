import 'package:flutter/material.dart';

class AiResultStatusChips extends StatelessWidget {
  const AiResultStatusChips({
    super.key,
    required this.usedFallback,
    required this.model,
    required this.liveLabel,
    required this.fallbackLabel,
    required this.modelPrefix,
  });

  final bool usedFallback;
  final String? model;
  final String liveLabel;
  final String fallbackLabel;
  final String modelPrefix;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final normalizedModel = model?.trim() ?? '';

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        Chip(
          avatar: Icon(
            usedFallback ? Icons.shield_outlined : Icons.auto_awesome_outlined,
            size: 18,
            color: usedFallback
                ? colorScheme.onSecondaryContainer
                : colorScheme.onTertiaryContainer,
          ),
          backgroundColor: usedFallback
              ? colorScheme.secondaryContainer
              : colorScheme.tertiaryContainer,
          label: Text(usedFallback ? fallbackLabel : liveLabel),
        ),
        if (normalizedModel.isNotEmpty)
          Chip(
            avatar: Icon(
              Icons.memory_outlined,
              size: 18,
              color: colorScheme.onSurfaceVariant,
            ),
            backgroundColor: colorScheme.surfaceContainerHighest,
            label: Text('$modelPrefix $normalizedModel'),
          ),
      ],
    );
  }
}
