import 'package:flutter/widgets.dart';

import '../../../core/services/app_environment.dart';
import 'marketing_ad_slot_stub.dart'
    if (dart.library.html) 'marketing_ad_slot_web.dart'
    as platform;

class MarketingInlineAdSlot extends StatelessWidget {
  const MarketingInlineAdSlot({
    super.key,
    required this.pageType,
    this.minHeight = 236,
  });

  final String pageType;
  final double minHeight;

  bool get _isConfigured =>
      AppEnvironment.adSensePublisherId.trim().isNotEmpty &&
      AppEnvironment.adSenseMarketingInlineSlotId.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    if (!_isConfigured) {
      return const SizedBox.shrink();
    }

    return platform.buildMarketingInlineAdSlot(
      publisherId: AppEnvironment.adSensePublisherId.trim(),
      slotId: AppEnvironment.adSenseMarketingInlineSlotId.trim(),
      pageType: pageType,
      minHeight: minHeight,
    );
  }
}
