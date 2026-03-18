import 'package:flutter/material.dart';

enum AppViewport { mobile, tablet, desktop }

class ResponsiveLayout {
  const ResponsiveLayout._({required this.viewport, required this.width});

  static const double mobileMaxWidth = 767;
  static const double tabletMaxWidth = 1199;

  final AppViewport viewport;
  final double width;

  bool get isMobile => viewport == AppViewport.mobile;
  bool get isTablet => viewport == AppViewport.tablet;
  bool get isDesktop => viewport == AppViewport.desktop;
  bool get useRailNavigation => !isMobile;

  double get contentMaxWidth => switch (viewport) {
    AppViewport.mobile => 900,
    AppViewport.tablet => 1100,
    AppViewport.desktop => 1240,
  };

  double get horizontalPadding => switch (viewport) {
    AppViewport.mobile => 20,
    AppViewport.tablet => 24,
    AppViewport.desktop => 28,
  };

  int gridColumns({
    required int mobile,
    required int tablet,
    required int desktop,
  }) {
    return switch (viewport) {
      AppViewport.mobile => mobile,
      AppViewport.tablet => tablet,
      AppViewport.desktop => desktop,
    };
  }

  static ResponsiveLayout of(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width <= mobileMaxWidth) {
      return ResponsiveLayout._(viewport: AppViewport.mobile, width: width);
    }
    if (width <= tabletMaxWidth) {
      return ResponsiveLayout._(viewport: AppViewport.tablet, width: width);
    }
    return ResponsiveLayout._(viewport: AppViewport.desktop, width: width);
  }
}
