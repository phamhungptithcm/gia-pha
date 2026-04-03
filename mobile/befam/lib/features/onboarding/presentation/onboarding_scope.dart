import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../models/onboarding_models.dart';
import 'onboarding_coordinator.dart';

class OnboardingScope extends StatelessWidget {
  const OnboardingScope({
    super.key,
    required this.controller,
    required this.child,
  });

  final OnboardingCoordinator controller;
  final Widget child;

  static OnboardingCoordinator? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_OnboardingInherited>()
        ?.notifier;
  }

  @override
  Widget build(BuildContext context) {
    return _OnboardingInherited(
      notifier: controller,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          child,
          Positioned.fill(child: _OnboardingOverlay(controller: controller)),
        ],
      ),
    );
  }
}

class OnboardingAnchor extends StatefulWidget {
  const OnboardingAnchor({
    super.key,
    required this.anchorId,
    required this.child,
  });

  final String anchorId;
  final Widget child;

  @override
  State<OnboardingAnchor> createState() => _OnboardingAnchorState();
}

class _OnboardingAnchorState extends State<OnboardingAnchor> {
  final GlobalKey _anchorKey = GlobalKey();
  OnboardingCoordinator? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextController = OnboardingScope.maybeOf(context);
    if (_controller == nextController) {
      return;
    }
    _controller?.unregisterAnchor(widget.anchorId, _anchorKey);
    _controller = nextController;
    _controller?.registerAnchor(widget.anchorId, _anchorKey);
  }

  @override
  void dispose() {
    _controller?.unregisterAnchor(widget.anchorId, _anchorKey);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(key: _anchorKey, child: widget.child);
  }
}

class _OnboardingInherited extends InheritedNotifier<OnboardingCoordinator> {
  const _OnboardingInherited({required super.notifier, required super.child});
}

class _OnboardingOverlay extends StatelessWidget {
  const _OnboardingOverlay({required this.controller});

  final OnboardingCoordinator controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        if (!controller.isVisible) {
          return const IgnorePointer(ignoring: true, child: SizedBox.shrink());
        }
        final step = controller.currentStep;
        if (step == null) {
          return const IgnorePointer(ignoring: true, child: SizedBox.shrink());
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final overlayBox = context.findRenderObject();
            final targetGlobalRect = controller.rectForAnchor(step.anchorId);
            if (overlayBox is! RenderBox || targetGlobalRect == null) {
              return const IgnorePointer(
                ignoring: true,
                child: SizedBox.shrink(),
              );
            }
            final overlayOrigin = overlayBox.localToGlobal(Offset.zero);
            final localRect = targetGlobalRect.shift(-overlayOrigin);
            final viewport = Size(constraints.maxWidth, constraints.maxHeight);
            final safePadding =
                MediaQuery.maybeOf(context)?.padding ?? EdgeInsets.zero;
            final layout = _TooltipLayout.resolve(
              viewport: viewport,
              targetRect: localRect,
              placement: step.placement,
              safePadding: safePadding,
            );
            final theme = Theme.of(context);
            final colorScheme = theme.colorScheme;
            final l10n = context.l10n;

            return Stack(
              children: <Widget>[
                _DismissibleScrim(
                  viewport: viewport,
                  targetRect: localRect,
                  onTap: step.barrierDismissible
                      ? () {
                          unawaited(controller.skip());
                        }
                      : null,
                ),
                Positioned(
                  left: math.max(8, localRect.left - 6),
                  top: math.max(8, localRect.top - 6),
                  width: math.min(viewport.width - 16, localRect.width + 12),
                  height: math.min(viewport.height - 16, localRect.height + 12),
                  child: IgnorePointer(
                    child: AnimatedScale(
                      duration: const Duration(milliseconds: 180),
                      scale: 1,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: colorScheme.primary,
                            width: 2.5,
                          ),
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: colorScheme.primary.withValues(
                                alpha: 0.18,
                              ),
                              blurRadius: 24,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: layout.left,
                  right: math.max(
                    0,
                    viewport.width - layout.left - layout.width,
                  ),
                  top: layout.top,
                  bottom: layout.bottom,
                  child: Align(
                    alignment: layout.placeBelow
                        ? Alignment.topCenter
                        : Alignment.bottomCenter,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: layout.width,
                        maxHeight: layout.maxHeight,
                      ),
                      child: _TooltipCard(
                        controller: controller,
                        step: step,
                        theme: theme,
                        targetRect: localRect,
                        layout: layout,
                        title: step.title.resolve(l10n),
                        body: step.body.resolve(l10n),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _DismissibleScrim extends StatelessWidget {
  const _DismissibleScrim({
    required this.viewport,
    required this.targetRect,
    this.onTap,
  });

  final Size viewport;
  final Rect targetRect;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final overlayColor = Colors.black.withValues(alpha: 0.64);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Stack(
        children: <Widget>[
          Positioned(
            left: 0,
            top: 0,
            width: viewport.width,
            height: math.max(0, targetRect.top),
            child: ColoredBox(color: overlayColor),
          ),
          Positioned(
            left: 0,
            top: math.max(0, targetRect.top),
            width: math.max(0, targetRect.left),
            height: math.min(targetRect.height, viewport.height),
            child: ColoredBox(color: overlayColor),
          ),
          Positioned(
            left: math.min(viewport.width, targetRect.right),
            top: math.max(0, targetRect.top),
            width: math.max(0, viewport.width - targetRect.right),
            height: math.min(targetRect.height, viewport.height),
            child: ColoredBox(color: overlayColor),
          ),
          Positioned(
            left: 0,
            top: math.min(viewport.height, targetRect.bottom),
            width: viewport.width,
            height: math.max(0, viewport.height - targetRect.bottom),
            child: ColoredBox(color: overlayColor),
          ),
        ],
      ),
    );
  }
}

class _TooltipCard extends StatelessWidget {
  const _TooltipCard({
    required this.controller,
    required this.step,
    required this.theme,
    required this.targetRect,
    required this.layout,
    required this.title,
    required this.body,
  });

  final OnboardingCoordinator controller;
  final OnboardingStep step;
  final ThemeData theme;
  final Rect targetRect;
  final _TooltipLayout layout;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final colorScheme = theme.colorScheme;
    final isLastStep = controller.currentStepIndex >= controller.stepCount - 1;
    final l10n = context.l10n;
    final surfaceColor = colorScheme.surface;
    final arrow = Align(
      alignment: Alignment(
        (((targetRect.center.dx - layout.left) / layout.width)
                    .clamp(0.12, 0.88)
                    .toDouble() *
                2) -
            1,
        0,
      ),
      child: Transform.rotate(
        angle: math.pi / 4,
        child: Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ),
    );

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: 1,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 180),
        scale: 1,
        alignment: layout.placeBelow
            ? Alignment.topCenter
            : Alignment.bottomCenter,
        child: Semantics(
          liveRegion: true,
          label: '${controller.currentStepIndex + 1}/${controller.stepCount}',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: layout.placeBelow
                ? <Widget>[
                    arrow,
                    const SizedBox(height: 6),
                    _TooltipBody(
                      controller: controller,
                      theme: theme,
                      title: title,
                      body: body,
                      isLastStep: isLastStep,
                      backLabel: l10n.pick(vi: 'Quay lại', en: 'Back'),
                      nextLabel: l10n.pick(vi: 'Tiếp', en: 'Next'),
                      doneLabel: l10n.pick(vi: 'Xong', en: 'Done'),
                      skipLabel: l10n.pick(vi: 'Bỏ qua', en: 'Skip'),
                    ),
                  ]
                : <Widget>[
                    _TooltipBody(
                      controller: controller,
                      theme: theme,
                      title: title,
                      body: body,
                      isLastStep: isLastStep,
                      backLabel: l10n.pick(vi: 'Quay lại', en: 'Back'),
                      nextLabel: l10n.pick(vi: 'Tiếp', en: 'Next'),
                      doneLabel: l10n.pick(vi: 'Xong', en: 'Done'),
                      skipLabel: l10n.pick(vi: 'Bỏ qua', en: 'Skip'),
                    ),
                    const SizedBox(height: 6),
                    arrow,
                  ],
          ),
        ),
      ),
    );
  }
}

class _TooltipBody extends StatelessWidget {
  const _TooltipBody({
    required this.controller,
    required this.theme,
    required this.title,
    required this.body,
    required this.isLastStep,
    required this.backLabel,
    required this.nextLabel,
    required this.doneLabel,
    required this.skipLabel,
  });

  final OnboardingCoordinator controller;
  final ThemeData theme;
  final String title;
  final String body;
  final bool isLastStep;
  final String backLabel;
  final String nextLabel;
  final String doneLabel;
  final String skipLabel;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 10,
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: double.infinity,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                '${controller.currentStepIndex + 1}/${controller.stepCount}',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(body, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 14),
              OverflowBar(
                alignment: MainAxisAlignment.end,
                spacing: 8,
                overflowSpacing: 8,
                children: <Widget>[
                  TextButton(
                    onPressed: controller.isActionInFlight
                        ? null
                        : () {
                            unawaited(controller.skip());
                          },
                    child: Text(skipLabel),
                  ),
                  if (controller.currentStepIndex > 0)
                    TextButton(
                      onPressed: controller.isActionInFlight
                          ? null
                          : () {
                              unawaited(controller.back());
                            },
                      child: Text(backLabel),
                    ),
                  FilledButton(
                    onPressed: controller.isActionInFlight
                        ? null
                        : () {
                            unawaited(
                              isLastStep
                                  ? controller.complete()
                                  : controller.next(),
                            );
                          },
                    child: Text(isLastStep ? doneLabel : nextLabel),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TooltipLayout {
  const _TooltipLayout({
    required this.left,
    required this.top,
    required this.bottom,
    required this.width,
    required this.maxHeight,
    required this.placeBelow,
  });

  final double left;
  final double top;
  final double bottom;
  final double width;
  final double maxHeight;
  final bool placeBelow;

  static _TooltipLayout resolve({
    required Size viewport,
    required Rect targetRect,
    required OnboardingTooltipPlacement placement,
    required EdgeInsets safePadding,
  }) {
    const horizontalPadding = 16.0;
    const gap = 12.0;
    const minimumTooltipHeight = 180.0;
    final leftInset = math.max(horizontalPadding, safePadding.left + 8);
    final rightInset = math.max(horizontalPadding, safePadding.right + 8);
    final topInset = math.max(16.0, safePadding.top + 8);
    final bottomInset = math.max(16.0, safePadding.bottom + 8);
    final width = math.min(340.0, viewport.width - leftInset - rightInset);
    final centeredLeft = (targetRect.center.dx - (width / 2))
        .clamp(leftInset, viewport.width - width - rightInset)
        .toDouble();
    final availableBelow = math.max(
      0.0,
      viewport.height - bottomInset - (targetRect.bottom + gap),
    );
    final availableAbove = math.max(0.0, targetRect.top - gap - topInset);
    final hasMoreSpaceBelow = availableBelow >= availableAbove;
    final placeBelow = switch (placement) {
      OnboardingTooltipPlacement.below =>
        availableBelow >= minimumTooltipHeight ||
            availableBelow >= availableAbove,
      OnboardingTooltipPlacement.above =>
        !(availableAbove >= minimumTooltipHeight ||
            availableAbove >= availableBelow),
      OnboardingTooltipPlacement.auto => hasMoreSpaceBelow,
    };
    if (placeBelow) {
      final top = math.max(topInset, targetRect.bottom + gap);
      return _TooltipLayout(
        left: centeredLeft,
        top: top,
        bottom: bottomInset,
        width: width,
        maxHeight: math.max(120.0, viewport.height - top - bottomInset),
        placeBelow: true,
      );
    }
    final bottom = math.max(
      bottomInset,
      viewport.height - targetRect.top + gap,
    );
    return _TooltipLayout(
      left: centeredLeft,
      top: topInset,
      bottom: bottom,
      width: width,
      maxHeight: math.max(120.0, viewport.height - topInset - bottom),
      placeBelow: false,
    );
  }
}
