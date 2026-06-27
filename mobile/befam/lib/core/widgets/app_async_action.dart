import 'dart:async';

import 'package:flutter/material.dart';

import 'app_motion.dart';

typedef AppAsyncActionBuilder =
    Widget Function(
      BuildContext context,
      VoidCallback? onPressed,
      bool isLoading,
    );

class AppAsyncAction extends StatefulWidget {
  const AppAsyncAction({
    super.key,
    required this.builder,
    required this.onPressed,
    this.enabled = true,
    this.isLoading = false,
    this.showLoadingBar = true,
  });

  final AppAsyncActionBuilder builder;
  final FutureOr<void> Function()? onPressed;
  final bool enabled;
  final bool isLoading;
  final bool showLoadingBar;

  @override
  State<AppAsyncAction> createState() => _AppAsyncActionState();
}

class _AppAsyncActionState extends State<AppAsyncAction> {
  bool _isLoading = false;
  bool _isPressed = false;

  Future<void> _runAction() async {
    final action = widget.onPressed;
    if (_effectiveIsLoading || !widget.enabled || action == null) {
      return;
    }
    setState(() {
      _isLoading = true;
      _isPressed = false;
    });
    try {
      await action();
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'app_async_action',
          context: ErrorDescription('while handling an async button action'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _handlePressed() {
    unawaited(_runAction());
  }

  bool get _effectiveIsLoading => _isLoading || widget.isLoading;

  void _setPressed(bool value) {
    final isEnabled =
        widget.enabled && !_effectiveIsLoading && widget.onPressed != null;
    if (!isEnabled || _isPressed == value) {
      return;
    }
    setState(() {
      _isPressed = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isEnabled =
        widget.enabled && !_effectiveIsLoading && widget.onPressed != null;
    final child = widget.builder(
      context,
      isEnabled ? _handlePressed : null,
      _effectiveIsLoading,
    );

    return Listener(
      onPointerDown: (_) => _setPressed(true),
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: AnimatedScale(
        duration: AppMotion.quick,
        curve: AppMotion.enterCurve,
        scale: _isPressed ? 0.985 : 1,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              child,
              if (widget.showLoadingBar && _effectiveIsLoading)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: LinearProgressIndicator(
                    minHeight: 3,
                    backgroundColor: Colors.transparent,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class AppStableLoadingChild extends StatelessWidget {
  const AppStableLoadingChild({
    super.key,
    required this.isLoading,
    required this.child,
    this.indicatorSize = 18,
    this.indicatorStrokeWidth = 2,
  });

  final bool isLoading;
  final Widget child;
  final double indicatorSize;
  final double indicatorStrokeWidth;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        IgnorePointer(
          ignoring: isLoading,
          child: Opacity(opacity: isLoading ? 0 : 1, child: child),
        ),
        if (isLoading)
          SizedBox(
            width: indicatorSize,
            height: indicatorSize,
            child: CircularProgressIndicator(strokeWidth: indicatorStrokeWidth),
          ),
      ],
    );
  }
}

enum AppActionButtonVariant { filled, tonal, outlined, text }

class AppActionButton extends StatelessWidget {
  const AppActionButton({
    super.key,
    this.buttonKey,
    required this.label,
    this.icon,
    this.onPressed,
    this.isLoading = false,
    this.enabled = true,
    this.variant = AppActionButtonVariant.filled,
    this.expand = false,
  });

  final Key? buttonKey;
  final String label;
  final IconData? icon;
  final FutureOr<void> Function()? onPressed;
  final bool isLoading;
  final bool enabled;
  final AppActionButtonVariant variant;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final buttonChild = AppAsyncAction(
      onPressed: onPressed,
      enabled: enabled && !isLoading,
      isLoading: isLoading,
      builder: (context, onPressed, loading) {
        final labelWidget = Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          softWrap: false,
        );
        final iconWidget = loading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : icon == null
            ? null
            : Icon(icon);

        return switch (variant) {
          AppActionButtonVariant.filled =>
            iconWidget == null
                ? FilledButton(
                    key: buttonKey,
                    onPressed: onPressed,
                    child: labelWidget,
                  )
                : FilledButton.icon(
                    key: buttonKey,
                    onPressed: onPressed,
                    icon: iconWidget,
                    label: labelWidget,
                  ),
          AppActionButtonVariant.tonal =>
            iconWidget == null
                ? FilledButton.tonal(
                    key: buttonKey,
                    onPressed: onPressed,
                    child: labelWidget,
                  )
                : FilledButton.tonalIcon(
                    key: buttonKey,
                    onPressed: onPressed,
                    icon: iconWidget,
                    label: labelWidget,
                  ),
          AppActionButtonVariant.outlined =>
            iconWidget == null
                ? OutlinedButton(
                    key: buttonKey,
                    onPressed: onPressed,
                    child: labelWidget,
                  )
                : OutlinedButton.icon(
                    key: buttonKey,
                    onPressed: onPressed,
                    icon: iconWidget,
                    label: labelWidget,
                  ),
          AppActionButtonVariant.text =>
            iconWidget == null
                ? TextButton(
                    key: buttonKey,
                    onPressed: onPressed,
                    child: labelWidget,
                  )
                : TextButton.icon(
                    key: buttonKey,
                    onPressed: onPressed,
                    icon: iconWidget,
                    label: labelWidget,
                  ),
        };
      },
    );

    if (!expand) {
      return buttonChild;
    }
    return SizedBox(width: double.infinity, child: buttonChild);
  }
}
