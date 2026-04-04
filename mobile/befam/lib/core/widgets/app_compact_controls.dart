import 'package:flutter/material.dart';

import '../../app/theme/app_ui_tokens.dart';

class AppCompactIconButton extends StatelessWidget {
  const AppCompactIconButton({
    super.key,
    this.tooltip,
    required this.onPressed,
    required this.icon,
    this.color,
  });

  final String? tooltip;
  final VoidCallback? onPressed;
  final Widget icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tokens = context.uiTokens;
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: icon,
      color: color,
      visualDensity: VisualDensity.compact,
      constraints: BoxConstraints.tightFor(
        width: tokens.compactActionExtent,
        height: tokens.compactActionExtent,
      ),
    );
  }
}

class AppCompactTextButton extends StatelessWidget {
  const AppCompactTextButton({
    super.key,
    required this.onPressed,
    required this.child,
  });

  final VoidCallback? onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = context.uiTokens;
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.symmetric(
          horizontal: tokens.inlineActionHorizontalPadding,
          vertical: tokens.inlineActionVerticalPadding,
        ),
        minimumSize: Size(0, tokens.compactActionExtent),
      ),
      child: child,
    );
  }
}
