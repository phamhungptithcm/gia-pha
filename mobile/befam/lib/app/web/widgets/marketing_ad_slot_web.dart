// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';

int _marketingAdSlotSeed = 0;

Widget buildMarketingInlineAdSlot({
  required String publisherId,
  required String slotId,
  required String pageType,
  required double minHeight,
}) {
  return _WebMarketingInlineAdSlot(
    publisherId: publisherId,
    slotId: slotId,
    pageType: pageType,
    minHeight: minHeight,
  );
}

class _WebMarketingInlineAdSlot extends StatefulWidget {
  const _WebMarketingInlineAdSlot({
    required this.publisherId,
    required this.slotId,
    required this.pageType,
    required this.minHeight,
  });

  final String publisherId;
  final String slotId;
  final String pageType;
  final double minHeight;

  @override
  State<_WebMarketingInlineAdSlot> createState() =>
      _WebMarketingInlineAdSlotState();
}

class _WebMarketingInlineAdSlotState extends State<_WebMarketingInlineAdSlot> {
  late final String _viewType;

  @override
  void initState() {
    super.initState();
    _viewType = 'befam-marketing-ad-slot-${_marketingAdSlotSeed++}';
    ui_web.platformViewRegistry.registerViewFactory(_viewType, _createHost);
  }

  html.DivElement _createHost(int viewId) {
    final host = html.DivElement()
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.display = 'block'
      ..setAttribute('role', 'complementary')
      ..setAttribute('aria-label', 'Advertising slot')
      ..setAttribute('data-befam-ad-slot', 'marketing_inline')
      ..setAttribute('data-befam-ad-client', widget.publisherId)
      ..setAttribute('data-befam-slot-id', widget.slotId)
      ..setAttribute('data-befam-page-type', widget.pageType)
      ..setAttribute('data-befam-breakpoint', 'content_unit_end')
      ..setAttribute(
        'data-befam-min-height',
        widget.minHeight.round().toString(),
      )
      ..setAttribute('data-befam-ad-context', 'marketing');
    return host;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.minHeight,
      child: HtmlElementView(viewType: _viewType),
    );
  }
}
