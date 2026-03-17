import 'dart:async';

import 'package:flutter/material.dart';

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
  });

  final AppAsyncActionBuilder builder;
  final Future<void> Function()? onPressed;
  final bool enabled;

  @override
  State<AppAsyncAction> createState() => _AppAsyncActionState();
}

class _AppAsyncActionState extends State<AppAsyncAction> {
  bool _isLoading = false;

  Future<void> _runAction() async {
    final action = widget.onPressed;
    if (_isLoading || !widget.enabled || action == null) {
      return;
    }
    setState(() {
      _isLoading = true;
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

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.enabled && !_isLoading && widget.onPressed != null;
    return widget.builder(
      context,
      isEnabled ? _handlePressed : null,
      _isLoading,
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
