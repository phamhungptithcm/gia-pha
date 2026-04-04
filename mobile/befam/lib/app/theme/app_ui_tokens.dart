import 'dart:ui';

import 'package:flutter/material.dart';

@immutable
class AppUiTokens extends ThemeExtension<AppUiTokens> {
  const AppUiTokens({
    required this.spaceXs,
    required this.spaceSm,
    required this.spaceMd,
    required this.spaceLg,
    required this.spaceXl,
    required this.space2xl,
    required this.radiusMd,
    required this.radiusLg,
    required this.radiusPill,
    required this.compactActionExtent,
    required this.buttonHeight,
    required this.inlineActionHorizontalPadding,
    required this.inlineActionVerticalPadding,
    required this.inputHorizontalPadding,
    required this.inputVerticalPadding,
  });

  const AppUiTokens.light()
    : this(
        spaceXs: 4,
        spaceSm: 8,
        spaceMd: 12,
        spaceLg: 16,
        spaceXl: 20,
        space2xl: 24,
        radiusMd: 14,
        radiusLg: 24,
        radiusPill: 999,
        compactActionExtent: 40,
        buttonHeight: 48,
        inlineActionHorizontalPadding: 12,
        inlineActionVerticalPadding: 6,
        inputHorizontalPadding: 14,
        inputVerticalPadding: 14,
      );

  final double spaceXs;
  final double spaceSm;
  final double spaceMd;
  final double spaceLg;
  final double spaceXl;
  final double space2xl;
  final double radiusMd;
  final double radiusLg;
  final double radiusPill;
  final double compactActionExtent;
  final double buttonHeight;
  final double inlineActionHorizontalPadding;
  final double inlineActionVerticalPadding;
  final double inputHorizontalPadding;
  final double inputVerticalPadding;

  @override
  AppUiTokens copyWith({
    double? spaceXs,
    double? spaceSm,
    double? spaceMd,
    double? spaceLg,
    double? spaceXl,
    double? space2xl,
    double? radiusMd,
    double? radiusLg,
    double? radiusPill,
    double? compactActionExtent,
    double? buttonHeight,
    double? inlineActionHorizontalPadding,
    double? inlineActionVerticalPadding,
    double? inputHorizontalPadding,
    double? inputVerticalPadding,
  }) {
    return AppUiTokens(
      spaceXs: spaceXs ?? this.spaceXs,
      spaceSm: spaceSm ?? this.spaceSm,
      spaceMd: spaceMd ?? this.spaceMd,
      spaceLg: spaceLg ?? this.spaceLg,
      spaceXl: spaceXl ?? this.spaceXl,
      space2xl: space2xl ?? this.space2xl,
      radiusMd: radiusMd ?? this.radiusMd,
      radiusLg: radiusLg ?? this.radiusLg,
      radiusPill: radiusPill ?? this.radiusPill,
      compactActionExtent: compactActionExtent ?? this.compactActionExtent,
      buttonHeight: buttonHeight ?? this.buttonHeight,
      inlineActionHorizontalPadding:
          inlineActionHorizontalPadding ?? this.inlineActionHorizontalPadding,
      inlineActionVerticalPadding:
          inlineActionVerticalPadding ?? this.inlineActionVerticalPadding,
      inputHorizontalPadding:
          inputHorizontalPadding ?? this.inputHorizontalPadding,
      inputVerticalPadding: inputVerticalPadding ?? this.inputVerticalPadding,
    );
  }

  @override
  AppUiTokens lerp(ThemeExtension<AppUiTokens>? other, double t) {
    if (other is! AppUiTokens) {
      return this;
    }
    return AppUiTokens(
      spaceXs: lerpDouble(spaceXs, other.spaceXs, t) ?? spaceXs,
      spaceSm: lerpDouble(spaceSm, other.spaceSm, t) ?? spaceSm,
      spaceMd: lerpDouble(spaceMd, other.spaceMd, t) ?? spaceMd,
      spaceLg: lerpDouble(spaceLg, other.spaceLg, t) ?? spaceLg,
      spaceXl: lerpDouble(spaceXl, other.spaceXl, t) ?? spaceXl,
      space2xl: lerpDouble(space2xl, other.space2xl, t) ?? space2xl,
      radiusMd: lerpDouble(radiusMd, other.radiusMd, t) ?? radiusMd,
      radiusLg: lerpDouble(radiusLg, other.radiusLg, t) ?? radiusLg,
      radiusPill: lerpDouble(radiusPill, other.radiusPill, t) ?? radiusPill,
      compactActionExtent:
          lerpDouble(compactActionExtent, other.compactActionExtent, t) ??
          compactActionExtent,
      buttonHeight:
          lerpDouble(buttonHeight, other.buttonHeight, t) ?? buttonHeight,
      inlineActionHorizontalPadding:
          lerpDouble(
            inlineActionHorizontalPadding,
            other.inlineActionHorizontalPadding,
            t,
          ) ??
          inlineActionHorizontalPadding,
      inlineActionVerticalPadding:
          lerpDouble(
            inlineActionVerticalPadding,
            other.inlineActionVerticalPadding,
            t,
          ) ??
          inlineActionVerticalPadding,
      inputHorizontalPadding:
          lerpDouble(inputHorizontalPadding, other.inputHorizontalPadding, t) ??
          inputHorizontalPadding,
      inputVerticalPadding:
          lerpDouble(inputVerticalPadding, other.inputVerticalPadding, t) ??
          inputVerticalPadding,
    );
  }
}

extension AppUiTokensBuildContext on BuildContext {
  AppUiTokens get uiTokens =>
      Theme.of(this).extension<AppUiTokens>() ?? const AppUiTokens.light();
}
