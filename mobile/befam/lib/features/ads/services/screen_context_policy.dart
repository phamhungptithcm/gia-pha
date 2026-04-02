class ScreenContextPolicy {
  const ScreenContextPolicy({
    required this.allowBanner,
    required this.allowInterstitial,
    this.isPremiumFlow = false,
    this.isHighFocusFlow = false,
  });

  final bool allowBanner;
  final bool allowInterstitial;
  final bool isPremiumFlow;
  final bool isHighFocusFlow;

  bool get isBadMomentForInterstitial =>
      !allowInterstitial || isPremiumFlow || isHighFocusFlow;

  static ScreenContextPolicy forScreen(String screenId) {
    return switch (screenId.trim().toLowerCase()) {
      'home' => const ScreenContextPolicy(
        allowBanner: true,
        allowInterstitial: true,
      ),
      'tree' => const ScreenContextPolicy(
        allowBanner: true,
        allowInterstitial: true,
      ),
      'events' => const ScreenContextPolicy(
        allowBanner: true,
        allowInterstitial: true,
      ),
      'billing' => const ScreenContextPolicy(
        allowBanner: false,
        allowInterstitial: false,
        isPremiumFlow: true,
        isHighFocusFlow: true,
      ),
      'profile' => const ScreenContextPolicy(
        allowBanner: false,
        allowInterstitial: false,
        isHighFocusFlow: true,
      ),
      _ => const ScreenContextPolicy(
        allowBanner: false,
        allowInterstitial: false,
        isHighFocusFlow: true,
      ),
    };
  }
}
