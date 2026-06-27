import 'package:flutter/material.dart';

import '../../../core/widgets/app_workspace_chrome.dart';
import '../../../l10n/l10n.dart';
import '../../auth/models/auth_session.dart';
import '../../billing/models/billing_workspace_snapshot.dart';
import '../../billing/services/billing_repository.dart';

class AiUsageQuotaNotice extends StatefulWidget {
  const AiUsageQuotaNotice({
    super.key,
    required this.session,
    required this.requestCost,
    required this.usageHint,
    this.billingRepository,
    this.compact = false,
    this.inline = false,
    this.hideWhenNeutral = false,
  });

  final AuthSession session;
  final BillingRepository? billingRepository;
  final int requestCost;
  final String usageHint;
  final bool compact;
  final bool inline;
  final bool hideWhenNeutral;

  @override
  State<AiUsageQuotaNotice> createState() => _AiUsageQuotaNoticeState();
}

class _AiUsageQuotaNoticeState extends State<AiUsageQuotaNotice> {
  late Future<BillingAiUsageSummary?> _summaryFuture;

  @override
  void initState() {
    super.initState();
    _summaryFuture = _loadSummary();
  }

  @override
  void didUpdateWidget(covariant AiUsageQuotaNotice oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session != widget.session ||
        oldWidget.billingRepository != widget.billingRepository) {
      _summaryFuture = _loadSummary();
    }
  }

  Future<BillingAiUsageSummary?> _loadSummary() async {
    final repository = widget.billingRepository;
    if (repository == null) {
      return null;
    }
    try {
      final summary = await repository.loadViewerSummary(
        session: widget.session,
      );
      return summary.aiUsageSummary;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<BillingAiUsageSummary?>(
      future: _summaryFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return _AiUsageNoticeCard(
            compact: widget.compact,
            inline: widget.inline,
            hideWhenNeutral: widget.hideWhenNeutral,
            icon: Icons.hourglass_bottom_outlined,
            tone: _NoticeTone.neutral,
            title: context.l10n.pick(
              vi: 'Đang kiểm tra lượt hỗ trợ còn lại...',
              en: 'Checking remaining AI help...',
            ),
            description: widget.compact ? null : widget.usageHint,
          );
        }

        final summary = snapshot.data;
        if (summary == null) {
          return const SizedBox.shrink();
        }
        if (!summary.hasResolvedQuota) {
          return const SizedBox.shrink();
        }

        final l10n = context.l10n;
        final remainingCredits = summary.remainingCredits;
        final remainingAfterRequest = (remainingCredits - widget.requestCost)
            .clamp(0, summary.quotaCredits);
        final isExhausted = summary.isExhausted;
        final isLastSafeRequest =
            !isExhausted && remainingCredits <= widget.requestCost;
        final isNearLimit =
            !isExhausted && !isLastSafeRequest && summary.usageProgress >= 0.8;

        final title = isExhausted
            ? l10n.pick(
                vi: 'Tháng này bạn đã dùng hết lượt hỗ trợ AI của mình.',
                en: 'You have used all of your AI help for this month.',
              )
            : l10n.pick(
                vi: 'Bạn còn $remainingCredits/${summary.quotaCredits} lượt hỗ trợ trong tháng này.',
                en: 'You have $remainingCredits/${summary.quotaCredits} AI help uses left this month.',
              );

        final description = isExhausted
            ? l10n.pick(
                vi: 'Tính năng AI sẽ tạm dừng cho tài khoản của bạn đến kỳ tháng mới hoặc khi gói được nâng cấp.',
                en: 'AI features pause for your account until the next monthly window or until the plan is upgraded.',
              )
            : '${widget.usageHint} ${isLastSafeRequest
                  ? l10n.pick(vi: 'Sau lượt này bạn sẽ chạm giới hạn tháng.', en: 'After this request, you will hit the monthly limit.')
                  : isNearLimit
                  ? l10n.pick(vi: 'Bạn đang gần chạm giới hạn tháng.', en: 'You are getting close to the monthly limit.')
                  : l10n.pick(vi: 'Sau lượt này vẫn còn khoảng $remainingAfterRequest lượt.', en: 'After this request, about $remainingAfterRequest uses remain.')}';

        return _AiUsageNoticeCard(
          compact: widget.compact,
          inline: widget.inline,
          hideWhenNeutral: widget.hideWhenNeutral,
          icon: isExhausted
              ? Icons.block_outlined
              : isNearLimit || isLastSafeRequest
              ? Icons.warning_amber_rounded
              : Icons.auto_awesome_outlined,
          tone: isExhausted
              ? _NoticeTone.danger
              : isNearLimit || isLastSafeRequest
              ? _NoticeTone.warning
              : _NoticeTone.neutral,
          title: title,
          description: description,
        );
      },
    );
  }
}

enum _NoticeTone { neutral, warning, danger }

class _AiUsageNoticeCard extends StatelessWidget {
  const _AiUsageNoticeCard({
    required this.compact,
    required this.inline,
    required this.hideWhenNeutral,
    required this.icon,
    required this.tone,
    required this.title,
    required this.description,
  });

  final bool compact;
  final bool inline;
  final bool hideWhenNeutral;
  final IconData icon;
  final _NoticeTone tone;
  final String title;
  final String? description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final backgroundColor = switch (tone) {
      _NoticeTone.danger => colorScheme.errorContainer,
      _NoticeTone.warning => colorScheme.tertiaryContainer,
      _NoticeTone.neutral => colorScheme.surfaceContainerHighest,
    };
    final iconColor = switch (tone) {
      _NoticeTone.danger => colorScheme.onErrorContainer,
      _NoticeTone.warning => colorScheme.onTertiaryContainer,
      _NoticeTone.neutral => colorScheme.onSurfaceVariant,
    };
    if (hideWhenNeutral && tone == _NoticeTone.neutral) {
      return const SizedBox.shrink();
    }
    if (inline) {
      if (tone == _NoticeTone.neutral) {
        return Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 10 : 12,
              vertical: compact ? 7 : 8,
            ),
            decoration: BoxDecoration(
              color: backgroundColor.withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.82),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: compact ? 14 : 16, color: iconColor),
                SizedBox(width: compact ? 6 : 8),
                Text(
                  title,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: iconColor,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: compact ? 14 : 16, color: iconColor),
          ),
          SizedBox(width: compact ? 6 : 8),
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.bodySmall?.copyWith(
                color: iconColor,
                fontWeight: tone == _NoticeTone.danger
                    ? FontWeight.w700
                    : FontWeight.w500,
                height: 1.25,
              ),
            ),
          ),
        ],
      );
    }

    return AppWorkspaceSurface(
      color: backgroundColor,
      padding: EdgeInsets.all(compact ? 10 : 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: compact ? 18 : 20, color: iconColor),
          SizedBox(width: compact ? 8 : 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style:
                      (compact
                              ? theme.textTheme.bodySmall
                              : theme.textTheme.bodyMedium)
                          ?.copyWith(fontWeight: FontWeight.w700),
                ),
                if (description != null && description!.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    description!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.3,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
