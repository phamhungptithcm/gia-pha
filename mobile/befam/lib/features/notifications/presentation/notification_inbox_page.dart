import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/widgets/app_feedback_states.dart';
import '../../../l10n/l10n.dart';
import '../../auth/models/auth_session.dart';
import '../models/notification_inbox_item.dart';
import '../services/notification_inbox_repository.dart';

class NotificationInboxPage extends StatefulWidget {
  const NotificationInboxPage({
    super.key,
    required this.session,
    required this.repository,
    this.onOpenTarget,
  });

  final AuthSession session;
  final NotificationInboxRepository repository;
  final void Function(NotificationInboxItem item)? onOpenTarget;

  @override
  State<NotificationInboxPage> createState() => _NotificationInboxPageState();
}

class _NotificationInboxPageState extends State<NotificationInboxPage> {
  static const int _pageSize = 4;

  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _isLoadingMore = false;
  String? _errorMessage;
  List<NotificationInboxItem> _items = const [];
  NotificationInboxCursor? _nextCursor;
  final Set<String> _markingReadIds = <String>{};

  bool get _hasMemberContext {
    final memberId = widget.session.memberId?.trim() ?? '';
    final clanId = widget.session.clanId?.trim() ?? '';
    return memberId.isNotEmpty && clanId.isNotEmpty;
  }

  int get _unreadCount => _items.where((item) => item.isUnread).length;

  @override
  void initState() {
    super.initState();
    unawaited(_loadInitial());
  }

  Future<void> _loadInitial({bool refresh = false}) async {
    setState(() {
      _errorMessage = null;
      if (refresh) {
        _isRefreshing = true;
      } else {
        _isLoading = true;
      }
    });

    try {
      final result = await widget.repository.loadInboxPage(
        session: widget.session,
        limit: _pageSize,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _items = result.items;
        _nextCursor = result.nextCursor;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || _nextCursor == null) {
      return;
    }

    setState(() {
      _isLoadingMore = true;
      _errorMessage = null;
    });

    try {
      final result = await widget.repository.loadInboxPage(
        session: widget.session,
        limit: _pageSize,
        cursor: _nextCursor,
      );
      if (!mounted) {
        return;
      }

      setState(() {
        final merged = <String, NotificationInboxItem>{
          for (final item in _items) item.id: item,
        };
        for (final item in result.items) {
          merged[item.id] = item;
        }

        final deduped = merged.values.toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        _items = deduped;
        _nextCursor = result.nextCursor;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  Future<void> _markAsRead(
    NotificationInboxItem item, {
    bool showError = true,
  }) async {
    if (item.isRead || _markingReadIds.contains(item.id)) {
      return;
    }

    setState(() {
      _markingReadIds.add(item.id);
    });

    try {
      await widget.repository.markAsRead(
        session: widget.session,
        notificationId: item.id,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _items = _items
            .map(
              (candidate) => candidate.id == item.id
                  ? candidate.copyWith(isRead: true)
                  : candidate,
            )
            .toList(growable: false);
      });
    } catch (_) {
      if (showError && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.notificationInboxMarkReadFailed)),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _markingReadIds.remove(item.id);
        });
      }
    }
  }

  void _openTarget(NotificationInboxItem item) {
    if (!item.canOpenTarget) {
      return;
    }

    if (item.isUnread) {
      unawaited(_markAsRead(item, showError: false));
    }

    widget.onOpenTarget?.call(item);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;

    if (_isLoading) {
      return AppLoadingState(
        message: l10n.pick(
          vi: 'Đang tải hộp thư thông báo...',
          en: 'Loading notifications...',
        ),
      );
    }

    if (!_hasMemberContext) {
      return _InboxStateCard(
        icon: Icons.lock_outline,
        title: l10n.notificationInboxNoContextTitle,
        description: l10n.notificationInboxNoContextDescription,
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadInitial(refresh: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          _InboxHeroCard(
            unreadCount: _unreadCount,
            isSandbox: widget.repository.isSandbox,
          ),
          const SizedBox(height: 20),
          if (_errorMessage != null) ...[
            _MessageCard(
              icon: Icons.error_outline,
              title: l10n.notificationInboxLoadErrorTitle,
              description: l10n.notificationInboxLoadErrorDescription,
              tone: colorScheme.errorContainer,
              actionLabel: l10n.notificationInboxRetryAction,
              onAction: _isRefreshing
                  ? null
                  : () => unawaited(_loadInitial(refresh: true)),
            ),
            const SizedBox(height: 20),
          ],
          if (_items.isEmpty)
            _InboxStateCard(
              icon: Icons.notifications_none_outlined,
              title: l10n.notificationInboxEmptyTitle,
              description: l10n.notificationInboxEmptyDescription,
            )
          else
            Column(
              children: [
                for (final item in _items)
                  Padding(
                    padding: EdgeInsets.only(
                      bottom: item == _items.last ? 0 : 12,
                    ),
                    child: _NotificationCard(
                      item: item,
                      isMarkingRead: _markingReadIds.contains(item.id),
                      onMarkAsRead: () => unawaited(_markAsRead(item)),
                      onOpenTarget: () => _openTarget(item),
                    ),
                  ),
                const SizedBox(height: 16),
                if (_isLoadingMore)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: AppInlineProgressIndicator(
                      semanticLabel: l10n.pick(
                        vi: 'Đang tải thêm thông báo',
                        en: 'Loading more notifications',
                      ),
                    ),
                  )
                else if (_nextCursor != null)
                  OutlinedButton.icon(
                    key: const Key('notification-load-more'),
                    onPressed: _loadMore,
                    icon: const Icon(Icons.expand_more),
                    label: Text(l10n.notificationInboxLoadMoreAction),
                  )
                else
                  Text(
                    l10n.notificationInboxPaginationDone,
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _InboxHeroCard extends StatelessWidget {
  const _InboxHeroCard({required this.unreadCount, required this.isSandbox});

  final int unreadCount;
  final bool isSandbox;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = context.l10n;

    final unreadLabel = unreadCount > 0
        ? l10n.notificationInboxUnreadCount(unreadCount)
        : l10n.notificationInboxAllRead;
    final sourceLabel = isSandbox
        ? l10n.notificationInboxSourceSandbox
        : l10n.notificationInboxSourceLive;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colorScheme.primary, colorScheme.primaryContainer],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.notificationInboxHeroTitle,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: colorScheme.onPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            l10n.notificationInboxHeroDescription,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colorScheme.onPrimary.withValues(alpha: 0.92),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _HeroChip(
                label: unreadLabel,
                tone: colorScheme.secondaryContainer,
              ),
              _HeroChip(
                label: sourceLabel,
                tone: colorScheme.surfaceContainerHighest,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.label, required this.tone});

  final String label;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tone,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.item,
    required this.isMarkingRead,
    required this.onMarkAsRead,
    required this.onOpenTarget,
  });

  final NotificationInboxItem item;
  final bool isMarkingRead;
  final VoidCallback onMarkAsRead;
  final VoidCallback onOpenTarget;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final targetIcon = switch (item.target) {
      NotificationInboxTarget.event => Icons.event_outlined,
      NotificationInboxTarget.scholarship => Icons.school_outlined,
      NotificationInboxTarget.generic => Icons.notifications_active_outlined,
      NotificationInboxTarget.unknown => Icons.notifications_none_outlined,
    };

    final targetLabel = switch (item.target) {
      NotificationInboxTarget.event => l10n.notificationInboxTargetEvent,
      NotificationInboxTarget.scholarship =>
        l10n.notificationInboxTargetScholarship,
      NotificationInboxTarget.generic => l10n.notificationInboxTargetGeneric,
      NotificationInboxTarget.unknown => l10n.notificationInboxTargetUnknown,
    };

    final canOpenTarget = item.canOpenTarget;

    return Card(
      key: Key('notification-row-${item.id}'),
      color: item.isUnread
          ? colorScheme.primaryContainer.withValues(alpha: 0.25)
          : null,
      child: InkWell(
        onTap: canOpenTarget ? onOpenTarget : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: colorScheme.secondaryContainer,
                child: Icon(targetIcon, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            item.title.isEmpty
                                ? l10n.notificationInboxFallbackTitle
                                : item.title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (item.isUnread)
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(top: 6),
                            decoration: BoxDecoration(
                              color: colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.body.isEmpty
                          ? l10n.notificationInboxFallbackBody
                          : item.body,
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _MetaChip(label: targetLabel),
                        _MetaChip(
                          label: item.isUnread
                              ? l10n.notificationInboxUnreadChip
                              : l10n.notificationInboxReadChip,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        if (canOpenTarget)
                          TextButton.icon(
                            key: Key('notification-open-${item.id}'),
                            onPressed: onOpenTarget,
                            icon: const Icon(Icons.open_in_new, size: 18),
                            label: Text(l10n.notificationInboxOpenAction),
                          ),
                        if (item.isUnread)
                          TextButton.icon(
                            key: Key('notification-mark-read-${item.id}'),
                            onPressed: isMarkingRead ? null : onMarkAsRead,
                            icon: isMarkingRead
                                ? SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: AppInlineProgressIndicator(
                                      size: 14,
                                      strokeWidth: 2,
                                      semanticLabel: l10n.pick(
                                        vi: 'Đang đánh dấu đã đọc',
                                        en: 'Marking as read',
                                      ),
                                    ),
                                  )
                                : const Icon(Icons.done, size: 18),
                            label: Text(l10n.notificationInboxMarkReadAction),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatTimestamp(context, item.createdAt),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.72),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.tone,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color tone;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: tone,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(description),
                    ],
                  ),
                ),
              ],
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.refresh),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InboxStateCard extends StatelessWidget {
  const _InboxStateCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: colorScheme.primaryContainer,
                    child: Icon(icon, size: 28),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    description,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _formatTimestamp(BuildContext context, DateTime value) {
  final localizations = MaterialLocalizations.of(context);
  final use24HourFormat = MediaQuery.alwaysUse24HourFormatOf(context);
  final timeLabel = localizations.formatTimeOfDay(
    TimeOfDay.fromDateTime(value),
    alwaysUse24HourFormat: use24HourFormat,
  );

  if (DateUtils.isSameDay(value, DateTime.now())) {
    return timeLabel;
  }

  final dateLabel = localizations.formatMediumDate(value);
  return '$dateLabel $timeLabel';
}
