import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../services/push_notification_service.dart';

class NotificationTargetPage extends StatelessWidget {
  const NotificationTargetPage({
    super.key,
    required this.targetType,
    required this.referenceId,
    this.sourceTitle,
    this.sourceBody,
  });

  final NotificationTargetType targetType;
  final String? referenceId;
  final String? sourceTitle;
  final String? sourceBody;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final (title, description, icon, keyValue) = switch (targetType) {
      NotificationTargetType.event => (
        l10n.notificationTargetEventTitle,
        l10n.notificationTargetEventDescription,
        Icons.event_outlined,
        const Key('notification-target-event'),
      ),
      NotificationTargetType.scholarship => (
        l10n.notificationTargetScholarshipTitle,
        l10n.notificationTargetScholarshipDescription,
        Icons.school_outlined,
        const Key('notification-target-scholarship'),
      ),
      NotificationTargetType.billing => (
        l10n.pick(vi: 'Thanh toán gói', en: 'Billing update'),
        l10n.pick(
          vi: 'Mở mục Gói để xem chi tiết thanh toán hoặc gia hạn.',
          en: 'Open Billing to review payment or renewal details.',
        ),
        Icons.workspace_premium_outlined,
        const Key('notification-target-billing'),
      ),
      NotificationTargetType.authRefresh => (
        l10n.notificationTargetUnknownTitle,
        l10n.notificationTargetUnknownDescription,
        Icons.notifications_none_outlined,
        const Key('notification-target-unknown'),
      ),
      NotificationTargetType.unknown => (
        l10n.notificationTargetUnknownTitle,
        l10n.notificationTargetUnknownDescription,
        Icons.notifications_none_outlined,
        const Key('notification-target-unknown'),
      ),
    };

    final resolvedReference = referenceId?.trim();

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            Card(
              key: keyValue,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      backgroundColor: colorScheme.secondaryContainer,
                      child: Icon(icon),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(description),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SummaryRow(
                      label: l10n.notificationTargetReferenceLabel,
                      value:
                          resolvedReference == null || resolvedReference.isEmpty
                          ? l10n.notificationTargetUnknownReference
                          : resolvedReference,
                    ),
                    _SummaryRow(
                      label: l10n.notificationTargetPayloadTitleLabel,
                      value: (sourceTitle?.trim().isNotEmpty == true)
                          ? sourceTitle!.trim()
                          : l10n.notificationInboxFallbackTitle,
                    ),
                    _SummaryRow(
                      label: l10n.notificationTargetPayloadBodyLabel,
                      value: (sourceBody?.trim().isNotEmpty == true)
                          ? sourceBody!.trim()
                          : l10n.notificationInboxFallbackBody,
                      isLast: true,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.isLast = false,
  });

  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(value, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}
