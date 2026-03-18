import 'package:flutter/material.dart';

import '../../core/services/app_logger.dart';
import '../../l10n/l10n.dart';

void installAppErrorFallback() {
  ErrorWidget.builder = (details) {
    AppLogger.warning(
      'Rendering fallback UI after widget error.',
      details.exception,
      details.stack,
    );
    return AppErrorFallback(details: details);
  };
}

class AppErrorFallback extends StatelessWidget {
  const AppErrorFallback({super.key, required this.details});

  final FlutterErrorDetails details;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = context.l10n;
    final description = l10n.pick(
      vi: 'Màn hình này tạm thời chưa thể hiển thị an toàn. Bạn có thể quay về Trang chủ để tiếp tục sử dụng ứng dụng.',
      en: 'This screen could not be displayed safely right now. You can return to Home and continue using the app.',
    );

    return Material(
      color: colorScheme.surface,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 52,
                        width: 52,
                        decoration: BoxDecoration(
                          color: colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.warning_amber_rounded,
                          color: colorScheme.onErrorContainer,
                          size: 28,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        l10n.pick(
                          vi: 'Đã có lỗi xảy ra',
                          en: 'Something went wrong',
                        ),
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(description, style: theme.textTheme.bodyMedium),
                      const SizedBox(height: 16),
                      Text(
                        details.exceptionAsString(),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: () {
                          final navigator = Navigator.maybeOf(context);
                          navigator?.popUntil((route) => route.isFirst);
                        },
                        icon: const Icon(Icons.home_rounded),
                        label: Text(
                          l10n.pick(vi: 'Về trang chủ', en: 'Back to home'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
