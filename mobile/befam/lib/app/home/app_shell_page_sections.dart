part of 'app_shell_page.dart';

final PerformanceMeasurementLogger _homeDashboardPerformanceLogger =
    PerformanceMeasurementLogger(
      defaultSlowThreshold: const Duration(milliseconds: 2000),
    );

Widget _buildShellDestinationAnchor(
  String destinationId, {
  required Widget child,
}) {
  final anchorId = switch (destinationId) {
    'tree' => 'shell.destination.tree',
    'events' => 'shell.destination.events',
    'profile' => 'shell.destination.profile',
    _ => null,
  };
  if (anchorId == null) {
    return child;
  }
  return OnboardingAnchor(anchorId: anchorId, child: child);
}

class _SponsoredAdBanner extends StatelessWidget {
  const _SponsoredAdBanner({required this.adController, required this.onClose});

  final AdController adController;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final tokens = context.uiTokens;
    final banner = adController.bannerAd;
    final showBannerAd = adController.isBannerReady && banner != null;
    final showFallback = adController.isBannerFallbackVisible;
    if (!showBannerAd && !showFallback) {
      return const SizedBox.shrink();
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 420;
        return Material(
          color: colorScheme.tertiaryContainer.withValues(alpha: 0.88),
          child: SafeArea(
            top: false,
            minimum: EdgeInsets.symmetric(
              horizontal: showBannerAd ? 0 : tokens.spaceMd,
              vertical: tokens.spaceSm,
            ),
            child: showBannerAd
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: tokens.spaceMd,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            AppCompactIconButton(
                              tooltip: l10n.pick(vi: 'Đóng', en: 'Close'),
                              onPressed: onClose,
                              icon: const Icon(Icons.close),
                              color: colorScheme.onTertiaryContainer,
                            ),
                          ],
                        ),
                      ),
                      Center(
                        child: SizedBox(
                          width: banner.size.width.toDouble(),
                          height: banner.size.height.toDouble(),
                          child: AdWidget(ad: banner),
                        ),
                      ),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.campaign_outlined,
                        color: colorScheme.onTertiaryContainer,
                        size: 18,
                      ),
                      SizedBox(width: tokens.spaceMd),
                      Expanded(
                        child: Text(
                          l10n.pick(
                            vi: 'Quảng cáo tạm thời chưa tải xong. Bạn vẫn đang ở chế độ miễn phí có quảng cáo.',
                            en: 'Ads are still loading. You are on the ad-supported free tier.',
                          ),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: colorScheme.onTertiaryContainer,
                                fontWeight: FontWeight.w600,
                              ),
                          maxLines: compact ? 2 : 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!compact)
                        AppCompactTextButton(
                          onPressed: onClose,
                          child: Text(
                            l10n.pick(
                              vi: 'Ẩn trong phiên',
                              en: 'Hide this session',
                            ),
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  color: colorScheme.onTertiaryContainer,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                      AppCompactIconButton(
                        tooltip: l10n.pick(vi: 'Đóng', en: 'Close'),
                        onPressed: onClose,
                        icon: const Icon(Icons.close),
                        color: colorScheme.onTertiaryContainer,
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }
}

class _ShellNavigationRail extends StatelessWidget {
  const _ShellNavigationRail({
    required this.selectedIndex,
    required this.destinations,
    required this.onDestinationSelected,
  });

  final int selectedIndex;
  final List<_ShellDestination> destinations;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final layout = ResponsiveLayout.of(context);
    return SafeArea(
      right: false,
      child: SizedBox(
        width: layout.isDesktop ? 104 : 92,
        child: NavigationRail(
          selectedIndex: selectedIndex,
          onDestinationSelected: onDestinationSelected,
          extended: false,
          useIndicator: true,
          labelType: NavigationRailLabelType.selected,
          groupAlignment: -0.9,
          destinations: [
            for (final destination in destinations)
              NavigationRailDestination(
                icon: _buildShellDestinationAnchor(
                  destination.id,
                  child: Icon(destination.icon),
                ),
                selectedIcon: Icon(destination.selectedIcon),
                label: Text(
                  l10n.shellDestinationLabel(destination.id),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _HomeDashboard extends StatelessWidget {
  const _HomeDashboard({
    super.key,
    required this.status,
    required this.session,
    required this.clanRepository,
    required this.memberRepository,
    required this.eventRepository,
    required this.fundRepository,
    required this.discoveryRepository,
    required this.activeClanName,
    required this.availableClanContexts,
    required this.onSwitchClanContext,
    required this.onOpenTreeRequested,
    required this.onOpenProfileRequested,
    required this.onOpenEventsRequested,
    required this.onOpenUpcomingEventDetailRequested,
    required this.onOpenMemorialChecklistRequested,
    required this.onOpenJoinRequestsRequested,
  });

  final FirebaseSetupStatus status;
  final AuthSession session;
  final ClanRepository clanRepository;
  final MemberRepository memberRepository;
  final EventRepository eventRepository;
  final FundRepository fundRepository;
  final GenealogyDiscoveryRepository discoveryRepository;
  final String? activeClanName;
  final List<ClanContextOption> availableClanContexts;
  final Future<AuthSession?> Function(String clanId) onSwitchClanContext;
  final VoidCallback onOpenTreeRequested;
  final VoidCallback onOpenProfileRequested;
  final VoidCallback onOpenEventsRequested;
  final ValueChanged<EventRecord> onOpenUpcomingEventDetailRequested;
  final VoidCallback onOpenMemorialChecklistRequested;
  final VoidCallback onOpenJoinRequestsRequested;
  bool get _hasClanContext => _sessionHasClanContext(session);

  String? get _activeClanName {
    final explicitActiveClanName = activeClanName?.trim() ?? '';
    if (explicitActiveClanName.isNotEmpty) {
      return explicitActiveClanName;
    }
    final clanId = (session.clanId ?? '').trim();
    if (clanId.isEmpty) {
      return null;
    }
    for (final option in availableClanContexts) {
      if (option.normalizedClanId != clanId) {
        continue;
      }
      final clanName = option.clanName.trim();
      if (clanName.isNotEmpty) {
        return clanName;
      }
    }
    return null;
  }

  List<AppShortcut> get _availableShortcuts {
    return bootstrapShortcuts;
  }

  List<AppShortcut> get _primaryShortcuts {
    final primary = _availableShortcuts.where((entry) => entry.isPrimary);
    final fallback = primary.isEmpty ? _availableShortcuts : primary;
    return fallback.take(4).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final tokens = context.uiTokens;
    final layout = ResponsiveLayout.of(context);
    final shortcutCrossAxisCount = layout.gridColumns(
      mobile: 2,
      tablet: 4,
      desktop: 4,
    );
    final shortcutAspectRatio = switch (layout.viewport) {
      AppViewport.mobile => layout.width < 390 ? 1.08 : 1.16,
      AppViewport.tablet => 1.28,
      AppViewport.desktop => 1.34,
    };

    return ListView(
      padding: EdgeInsets.fromLTRB(
        layout.horizontalPadding,
        tokens.spaceLg,
        layout.horizontalPadding,
        tokens.space2xl + tokens.spaceSm,
      ),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: layout.contentMaxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.pick(vi: 'Dòng họ hôm nay', en: 'Family today'),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: tokens.spaceXs),
                Text(
                  l10n.pick(
                    vi: 'Tập trung vào một điểm nổi bật, các lối vào nhanh và những việc cần xử lý tiếp theo.',
                    en: 'Keep one highlight, quick entry points, and the next actions in view.',
                  ),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                SizedBox(height: tokens.spaceLg),
                _UpcomingEventSection(
                  session: session,
                  eventRepository: eventRepository,
                  activeClanName: _activeClanName,
                  onOpenEventsRequested: onOpenEventsRequested,
                  onOpenEventDetailRequested:
                      onOpenUpcomingEventDetailRequested,
                ),
                SizedBox(height: tokens.spaceLg),
                _DashboardSectionShell(
                  padding: EdgeInsets.all(tokens.spaceLg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              l10n.pick(
                                vi: 'Truy cập nhanh',
                                en: 'Quick access',
                              ),
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          AppCompactTextButton(
                            onPressed: () => _openAllShortcutsSheet(context),
                            child: Text(
                              l10n.pick(vi: 'Xem tất cả', en: 'View all'),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: tokens.spaceXs),
                      Text(
                        l10n.pick(
                          vi: 'Vào thẳng 4 khu vực dùng nhiều nhất thay vì cuộn qua từng thẻ dài.',
                          en: 'Jump straight into the four most-used workspaces.',
                        ),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      SizedBox(height: tokens.spaceMd),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _primaryShortcuts.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: shortcutCrossAxisCount,
                          crossAxisSpacing: tokens.spaceMd,
                          mainAxisSpacing: tokens.spaceMd,
                          childAspectRatio: shortcutAspectRatio,
                        ),
                        itemBuilder: (context, index) {
                          final shortcut = _primaryShortcuts[index];
                          return _ShortcutCard(
                            shortcut: shortcut,
                            onTap: _onShortcutTap(context, shortcut.id),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                SizedBox(height: tokens.spaceLg),
                if (layout.isMobile) ...[
                  _TodoSection(
                    status: status,
                    session: session,
                    discoveryRepository: discoveryRepository,
                    onOpenTreeRequested: onOpenTreeRequested,
                    onOpenProfileRequested: onOpenProfileRequested,
                    onOpenEventsRequested: onOpenEventsRequested,
                    onOpenMemorialChecklistRequested:
                        onOpenMemorialChecklistRequested,
                    onOpenJoinRequestsRequested: onOpenJoinRequestsRequested,
                  ),
                  SizedBox(height: tokens.spaceLg),
                  _NearbyRelativesSection(
                    session: session,
                    memberRepository: memberRepository,
                  ),
                ] else ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _TodoSection(
                          status: status,
                          session: session,
                          discoveryRepository: discoveryRepository,
                          onOpenTreeRequested: onOpenTreeRequested,
                          onOpenProfileRequested: onOpenProfileRequested,
                          onOpenEventsRequested: onOpenEventsRequested,
                          onOpenMemorialChecklistRequested:
                              onOpenMemorialChecklistRequested,
                          onOpenJoinRequestsRequested:
                              onOpenJoinRequestsRequested,
                        ),
                      ),
                      SizedBox(width: tokens.spaceLg),
                      Expanded(
                        child: _NearbyRelativesSection(
                          session: session,
                          memberRepository: memberRepository,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _openAllShortcutsSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) {
        final l10n = sheetContext.l10n;
        final shortcuts = _availableShortcuts;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          children: [
            Text(
              l10n.pick(vi: 'Tất cả truy cập nhanh', en: 'All quick access'),
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            for (final shortcut in shortcuts)
              Builder(
                builder: (tileContext) {
                  final action = _onShortcutTap(context, shortcut.id);
                  final isEnabled = action != null;
                  return Card(
                    child: ListTile(
                      leading: Icon(_iconFor(shortcut.iconKey)),
                      title: Text(l10n.shortcutTitle(shortcut.id)),
                      subtitle: Text(
                        _productionShortcutDescription(context, shortcut.id),
                      ),
                      trailing: Icon(
                        isEnabled
                            ? Icons.arrow_forward_ios
                            : Icons.lock_outline_rounded,
                        size: 16,
                      ),
                      onTap: () {
                        if (!isEnabled) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                context.l10n.pick(
                                  vi: 'Mục này hiện chưa thể mở từ tài khoản của bạn.',
                                  en: 'This shortcut is not available for your account yet.',
                                ),
                              ),
                            ),
                          );
                          return;
                        }
                        Navigator.of(tileContext).pop();
                        action.call();
                      },
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }

  VoidCallback? _onShortcutTap(BuildContext context, String shortcutId) {
    if (!_hasClanContext &&
        shortcutId != 'tree' &&
        shortcutId != 'clan' &&
        shortcutId != 'events') {
      return null;
    }
    return switch (shortcutId) {
      'clan' => () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (context) {
              return ClanDetailPage(
                session: session,
                repository: clanRepository,
                availableClanContexts: availableClanContexts,
                onSwitchClanContext: onSwitchClanContext,
                autoOpenClanEditorOnOpen: !_hasClanContext,
              );
            },
          ),
        );
      },
      'members' => () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (context) {
              return MemberWorkspacePage(
                session: session,
                repository: memberRepository,
                availableClanContexts: availableClanContexts,
                onSwitchClanContext: onSwitchClanContext,
              );
            },
          ),
        );
      },
      'scholarship' => () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (context) {
              return ScholarshipWorkspacePage(
                session: session,
                repository: createDefaultScholarshipRepository(
                  session: session,
                ),
                availableClanContexts: availableClanContexts,
                onSwitchClanContext: onSwitchClanContext,
              );
            },
          ),
        );
      },
      'tree' => onOpenTreeRequested,
      'profile' => onOpenProfileRequested,
      'events' => onOpenEventsRequested,
      'funds' => () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (context) {
              return FundWorkspacePage(
                session: session,
                repository: fundRepository,
                memberRepository: memberRepository,
                availableClanContexts: availableClanContexts,
              );
            },
          ),
        );
      },
      _ => null,
    };
  }
}

class _DashboardSectionShell extends StatelessWidget {
  const _DashboardSectionShell({
    required this.child,
    this.padding,
    this.color,
    this.gradient,
    this.showAccentOrbs = false,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final Gradient? gradient;
  final bool showAccentOrbs;

  @override
  Widget build(BuildContext context) {
    final tokens = context.uiTokens;
    final colorScheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(tokens.radiusLg);
    final resolvedPadding =
        padding ??
        EdgeInsets.symmetric(horizontal: tokens.spaceLg, vertical: 18);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: color ?? Colors.white.withValues(alpha: 0.86),
        gradient: gradient,
        borderRadius: radius,
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.92),
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.08),
            blurRadius: 32,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: [
            if (showAccentOrbs) ...[
              Positioned(
                top: -44,
                right: -24,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colorScheme.secondary.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: const SizedBox(width: 132, height: 132),
                ),
              ),
              Positioned(
                bottom: -54,
                left: -18,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const SizedBox(width: 154, height: 154),
                ),
              ),
            ],
            Padding(padding: resolvedPadding, child: child),
          ],
        ),
      ),
    );
  }
}

class _DashboardMetaChip extends StatelessWidget {
  const _DashboardMetaChip({
    required this.label,
    this.icon,
    this.backgroundColor,
    this.foregroundColor,
  });

  final String label;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.uiTokens;
    final resolvedForeground = foregroundColor ?? theme.colorScheme.onSurface;
    final resolvedBackground =
        backgroundColor ?? Colors.white.withValues(alpha: 0.56);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: resolvedBackground,
        borderRadius: BorderRadius.circular(tokens.radiusPill),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: tokens.spaceMd,
          vertical: tokens.spaceSm,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: resolvedForeground),
              SizedBox(width: tokens.spaceSm),
            ],
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: resolvedForeground,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShortcutCard extends StatelessWidget {
  const _ShortcutCard({required this.shortcut, this.onTap});

  final AppShortcut shortcut;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.uiTokens;
    final layout = ResponsiveLayout.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = context.l10n;
    final isEnabled = onTap != null;
    final statusColor = switch (shortcut.status) {
      AppShortcutStatus.live => colorScheme.primaryContainer,
      AppShortcutStatus.bootstrap => colorScheme.secondaryContainer,
      AppShortcutStatus.planned => colorScheme.surfaceContainerHighest,
    };
    final showDescription = !layout.isMobile;

    return Material(
      color: Colors.white.withValues(alpha: isEnabled ? 0.92 : 0.72),
      borderRadius: BorderRadius.circular(tokens.radiusMd + 4),
      child: InkWell(
        key: Key('shortcut-${shortcut.id}'),
        borderRadius: BorderRadius.circular(tokens.radiusMd + 4),
        onTap: onTap,
        onLongPress: onTap,
        child: Opacity(
          opacity: isEnabled ? 1 : 0.62,
          child: Padding(
            padding: EdgeInsets.all(tokens.spaceLg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 19,
                      backgroundColor: statusColor,
                      foregroundColor: colorScheme.onSurface,
                      child: Icon(_iconFor(shortcut.iconKey), size: 18),
                    ),
                    const Spacer(),
                    Icon(
                      isEnabled
                          ? Icons.north_east_rounded
                          : Icons.lock_outline_rounded,
                      size: 18,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  l10n.shortcutTitle(shortcut.id),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: layout.isMobile ? 18 : 17,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (showDescription) ...[
                  SizedBox(height: tokens.spaceXs + 2),
                  Text(
                    _productionShortcutDescription(context, shortcut.id),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ShortcutStatusChip extends StatelessWidget {
  const _ShortcutStatusChip({required this.status});

  final AppShortcutStatus status;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final background = switch (status) {
      AppShortcutStatus.live => colorScheme.primaryContainer,
      AppShortcutStatus.bootstrap => colorScheme.secondaryContainer,
      AppShortcutStatus.planned => colorScheme.surfaceContainerHighest,
    };
    final label = switch (status) {
      AppShortcutStatus.live => context.l10n.pick(
        vi: 'Đang dùng',
        en: 'In use',
      ),
      AppShortcutStatus.bootstrap => context.l10n.pick(
        vi: 'Chưa thiết lập',
        en: 'Not set',
      ),
      AppShortcutStatus.planned => context.l10n.pick(
        vi: 'Cần cập nhật',
        en: 'Needs update',
      ),
    };

    return Chip(
      label: Text(label),
      backgroundColor: background,
      visualDensity: VisualDensity.compact,
      side: BorderSide.none,
    );
  }
}

String _productionShortcutDescription(BuildContext context, String shortcutId) {
  final l10n = context.l10n;
  return switch (shortcutId) {
    'clan' => l10n.pick(
      vi: 'Quản lý thông tin họ tộc và cấu trúc chi nhánh.',
      en: 'Manage clan profile and branch structure.',
    ),
    'tree' => l10n.pick(
      vi: 'Theo dõi cây gia phả và các mối quan hệ thành viên.',
      en: 'Explore family tree and member relationships.',
    ),
    'members' => l10n.pick(
      vi: 'Tra cứu và cập nhật hồ sơ thành viên nhanh chóng.',
      en: 'Search and update member profiles quickly.',
    ),
    'events' => l10n.pick(
      vi: 'Xem lịch sự kiện, giỗ và lời nhắc quan trọng.',
      en: 'Track events, memorial dates, and reminders.',
    ),
    'funds' => l10n.pick(
      vi: 'Theo dõi thu chi và số dư quỹ dòng họ.',
      en: 'Track fund transactions and balances.',
    ),
    'scholarship' => l10n.pick(
      vi: 'Quản lý chương trình học bổng của dòng họ.',
      en: 'Manage clan scholarship programs.',
    ),
    'profile' => l10n.pick(
      vi: 'Cập nhật thông tin cá nhân và thiết lập tài khoản.',
      en: 'Update personal profile and account settings.',
    ),
    _ => l10n.shortcutDescription(shortcutId),
  };
}

String _formatDashboardDateTime(DateTime utcValue) {
  final value = utcValue.toLocal();
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  return '$hour:$minute · $day/$month/${value.year}';
}

String _formatUpcomingRelativeLabel(BuildContext context, DateTime startsAt) {
  final l10n = context.l10n;
  final now = DateTime.now();
  final localStart = startsAt.toLocal();
  final normalizedNow = DateTime(now.year, now.month, now.day);
  final normalizedStart = DateTime(
    localStart.year,
    localStart.month,
    localStart.day,
  );
  final differenceDays = normalizedStart.difference(normalizedNow).inDays;

  if (differenceDays <= 0) {
    return l10n.pick(vi: 'Diễn ra hôm nay', en: 'Happening today');
  }
  if (differenceDays == 1) {
    return l10n.pick(vi: 'Diễn ra ngày mai', en: 'Happening tomorrow');
  }
  if (differenceDays < 7) {
    return l10n.pick(
      vi: 'Còn $differenceDays ngày',
      en: 'In $differenceDays days',
    );
  }
  return l10n.pick(vi: 'Sắp diễn ra', en: 'Coming up soon');
}

class _UpcomingEventSection extends StatefulWidget {
  const _UpcomingEventSection({
    required this.session,
    required this.eventRepository,
    required this.activeClanName,
    required this.onOpenEventsRequested,
    required this.onOpenEventDetailRequested,
  });

  final AuthSession session;
  final EventRepository eventRepository;
  final String? activeClanName;
  final VoidCallback onOpenEventsRequested;
  final ValueChanged<EventRecord> onOpenEventDetailRequested;

  @override
  State<_UpcomingEventSection> createState() => _UpcomingEventSectionState();
}

class _UpcomingEventSectionState extends State<_UpcomingEventSection>
    with WidgetsBindingObserver {
  static const Duration _upcomingRefreshInterval = Duration(minutes: 3);

  late Future<_UpcomingEventData?> _upcomingFuture;
  _UpcomingEventData? _cachedUpcomingData;
  bool _isRefreshingUpcoming = false;
  bool _isUpcomingRequestInFlight = false;
  Timer? _upcomingRefreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _upcomingFuture = _runUpcomingLoad(showInlineIndicator: false);
    _upcomingRefreshTimer = Timer.periodic(_upcomingRefreshInterval, (_) {
      if (!mounted) {
        return;
      }
      _startUpcomingReload();
    });
  }

  @override
  void didUpdateWidget(covariant _UpcomingEventSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session != widget.session ||
        oldWidget.activeClanName != widget.activeClanName) {
      _startUpcomingReload();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !mounted) {
      return;
    }
    _startUpcomingReload();
  }

  void _startUpcomingReload({bool showInlineIndicator = false}) {
    if (!mounted || _isUpcomingRequestInFlight) {
      return;
    }
    setState(() {
      _upcomingFuture = _runUpcomingLoad(
        showInlineIndicator: showInlineIndicator,
      );
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _upcomingRefreshTimer?.cancel();
    super.dispose();
  }

  Future<_UpcomingEventData?> _runUpcomingLoad({
    required bool showInlineIndicator,
  }) {
    _isUpcomingRequestInFlight = true;
    if (showInlineIndicator) {
      _isRefreshingUpcoming = true;
    }
    return _loadUpcomingEventAndCache().whenComplete(() {
      _isUpcomingRequestInFlight = false;
      if (!mounted || !_isRefreshingUpcoming) {
        return;
      }
      setState(() {
        _isRefreshingUpcoming = false;
      });
    });
  }

  Future<_UpcomingEventData?> _loadUpcomingEvent() async {
    final events = await widget.eventRepository.loadUpcomingEvents(
      session: widget.session,
      limit: 80,
    );
    final nowLocal = DateTime.now();
    final upcoming = events
        .map(
          (event) => (
            event: event,
            nextStartsAt: _nextUpcomingStartAt(event, nowLocal),
          ),
        )
        .where((entry) => entry.nextStartsAt != null)
        .map((entry) => (event: entry.event, nextStartsAt: entry.nextStartsAt!))
        .toList(growable: false);
    if (upcoming.isEmpty) {
      return null;
    }

    final normalizedMemberId = (widget.session.memberId ?? '').trim();
    final userScopedUpcoming = normalizedMemberId.isEmpty
        ? const <({EventRecord event, DateTime nextStartsAt})>[]
        : upcoming
              .where(
                (event) =>
                    (event.event.targetMemberId ?? '').trim() ==
                    normalizedMemberId,
              )
              .toList(growable: false);
    final prioritized = userScopedUpcoming.isNotEmpty
        ? userScopedUpcoming
        : upcoming;
    prioritized.sort(
      (left, right) => left.nextStartsAt.compareTo(right.nextStartsAt),
    );
    final next = prioritized.first;
    final event = next.event;
    final hostHousehold = event.locationName.trim().isNotEmpty
        ? event.locationName.trim()
        : null;
    return _UpcomingEventData(
      event: event,
      hostHousehold: hostHousehold,
      clanName: _resolvedClanName(),
      startsAt: next.nextStartsAt,
    );
  }

  Future<_UpcomingEventData?> _loadUpcomingEventAndCache() async {
    try {
      final data = await _homeDashboardPerformanceLogger.measureAsync(
        metric: 'home.upcoming_events',
        dimensions: {
          'has_clan_context': _sessionHasClanContext(widget.session) ? 1 : 0,
        },
        warnAfter: const Duration(milliseconds: 1800),
        action: _loadUpcomingEvent,
      );
      _cachedUpcomingData = data;
      return data;
    } catch (_) {
      return _cachedUpcomingData;
    }
  }

  String? _resolvedClanName() {
    final activeClanName = widget.activeClanName?.trim() ?? '';
    if (activeClanName.isNotEmpty) {
      return activeClanName;
    }
    return null;
  }

  DateTime? _nextUpcomingStartAt(EventRecord event, DateTime nowLocal) {
    if (!_isVisibleUpcomingEvent(event)) {
      return null;
    }

    final localStart = event.startsAt.toLocal();
    if (!localStart.isBefore(nowLocal)) {
      return localStart;
    }

    if (!_isYearlyRecurringEvent(event)) {
      return null;
    }

    var nextYear = nowLocal.year;
    var yearlyOccurrence = _safeYearlyOccurrence(localStart, nextYear);
    if (yearlyOccurrence.isBefore(nowLocal)) {
      nextYear += 1;
      yearlyOccurrence = _safeYearlyOccurrence(localStart, nextYear);
    }
    return yearlyOccurrence;
  }

  bool _isVisibleUpcomingEvent(EventRecord event) {
    final normalizedStatus = event.status.trim().toLowerCase();
    if (normalizedStatus == 'cancelled' ||
        normalizedStatus == 'canceled' ||
        normalizedStatus == 'completed' ||
        normalizedStatus == 'archived' ||
        normalizedStatus == 'deleted') {
      return false;
    }

    return true;
  }

  bool _isYearlyRecurringEvent(EventRecord event) {
    if (!event.isRecurring) {
      return false;
    }
    final normalizedRule = event.recurrenceRule?.trim().toUpperCase() ?? '';
    return normalizedRule.contains('FREQ=YEARLY');
  }

  DateTime _safeYearlyOccurrence(DateTime localStart, int year) {
    final occurrence = DateTime(
      year,
      localStart.month,
      localStart.day,
      localStart.hour,
      localStart.minute,
      localStart.second,
      localStart.millisecond,
      localStart.microsecond,
    );
    if (occurrence.month == localStart.month &&
        occurrence.day == localStart.day) {
      return occurrence;
    }
    final fallbackDay = DateTime(year, localStart.month + 1, 0).day;
    return DateTime(
      year,
      localStart.month,
      fallbackDay,
      localStart.hour,
      localStart.minute,
      localStart.second,
      localStart.millisecond,
      localStart.microsecond,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return _DashboardSectionShell(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          colorScheme.primaryContainer.withValues(alpha: 0.92),
          colorScheme.secondaryContainer.withValues(alpha: 0.82),
          Colors.white.withValues(alpha: 0.95),
        ],
      ),
      showAccentOrbs: true,
      padding: const EdgeInsets.all(20),
      child: FutureBuilder<_UpcomingEventData?>(
        future: _upcomingFuture,
        builder: (context, snapshot) {
          final isWaiting = snapshot.connectionState == ConnectionState.waiting;
          final data = isWaiting ? _cachedUpcomingData : snapshot.data;

          Widget child;
          if (isWaiting && data == null) {
            child = const _UpcomingEventLoadingSkeleton(
              key: ValueKey<String>('upcoming-loading'),
            );
          } else if (data == null) {
            child = _UpcomingEventEmptyState(
              key: const ValueKey<String>('upcoming-empty'),
              isRefreshing: _isRefreshingUpcoming,
              onRefresh: () => _startUpcomingReload(showInlineIndicator: true),
              onOpenEventsRequested: widget.onOpenEventsRequested,
            );
          } else {
            child = _UpcomingEventResolvedState(
              key: ValueKey<String>(
                'upcoming-${data.event.id}-${data.startsAt.millisecondsSinceEpoch}',
              ),
              data: data,
              isRefreshing: _isRefreshingUpcoming,
              onOpenEventDetailRequested: widget.onOpenEventDetailRequested,
              onOpenEventsRequested: widget.onOpenEventsRequested,
              onRefresh: () => _startUpcomingReload(showInlineIndicator: true),
            );
          }

          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeOutCubic,
            child: child,
          );
        },
      ),
    );
  }
}

class _UpcomingEventLoadingSkeleton extends StatelessWidget {
  const _UpcomingEventLoadingSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        AppSkeletonBox(width: 180, height: 18),
        SizedBox(height: 14),
        AppSkeletonBox(width: double.infinity, height: 28),
        SizedBox(height: 10),
        AppSkeletonBox(width: 180, height: 20),
        SizedBox(height: 8),
        AppSkeletonBox(width: 220, height: 16),
        SizedBox(height: 6),
        AppSkeletonBox(width: double.infinity, height: 16),
      ],
    );
  }
}

class _UpcomingEventEmptyState extends StatelessWidget {
  const _UpcomingEventEmptyState({
    super.key,
    required this.isRefreshing,
    required this.onRefresh,
    required this.onOpenEventsRequested,
  });

  final bool isRefreshing;
  final VoidCallback onRefresh;
  final VoidCallback onOpenEventsRequested;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final tokens = context.uiTokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _DashboardMetaChip(
              icon: Icons.auto_awesome_rounded,
              label: l10n.pick(vi: 'Điểm nổi bật', en: 'Today highlight'),
              backgroundColor: Colors.white.withValues(alpha: 0.56),
              foregroundColor: theme.colorScheme.onSurface,
            ),
            const Spacer(),
            if (isRefreshing)
              const Padding(
                padding: EdgeInsets.only(right: 6),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            AppCompactIconButton(
              tooltip: l10n.pick(vi: 'Làm mới sự kiện', en: 'Refresh event'),
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        SizedBox(height: tokens.spaceLg),
        Text(
          l10n.pick(
            vi: 'Chưa có sự kiện nổi bật trong thời gian tới.',
            en: 'No upcoming highlight at the moment.',
          ),
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: tokens.spaceSm),
        Text(
          l10n.pick(
            vi: 'Bạn vẫn có thể mở lịch để xem các ngày giỗ, lời nhắc và sự kiện sắp diễn ra của cả họ.',
            en: 'Open the calendar to review memorial days, reminders, and clan events.',
          ),
          style: theme.textTheme.bodyMedium,
        ),
        SizedBox(height: tokens.spaceLg),
        Wrap(
          spacing: tokens.spaceSm,
          runSpacing: tokens.spaceSm,
          children: [
            FilledButton(
              onPressed: onOpenEventsRequested,
              child: Text(
                l10n.pick(vi: 'Mở lịch sự kiện', en: 'Open calendar'),
              ),
            ),
            OutlinedButton(
              onPressed: onRefresh,
              child: Text(l10n.pick(vi: 'Làm mới', en: 'Refresh')),
            ),
          ],
        ),
      ],
    );
  }
}

class _UpcomingEventResolvedState extends StatelessWidget {
  const _UpcomingEventResolvedState({
    super.key,
    required this.data,
    required this.isRefreshing,
    required this.onOpenEventDetailRequested,
    required this.onOpenEventsRequested,
    required this.onRefresh,
  });

  final _UpcomingEventData data;
  final bool isRefreshing;
  final ValueChanged<EventRecord> onOpenEventDetailRequested;
  final VoidCallback onOpenEventsRequested;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final tokens = context.uiTokens;
    final event = data.event;
    final colorScheme = theme.colorScheme;
    final hostLabel = data.hostHousehold?.trim().isNotEmpty == true
        ? data.hostHousehold!.trim()
        : l10n.pick(vi: 'Cả họ', en: 'Clan-wide');
    final clanLabel = data.clanName?.trim() ?? '';
    final timelineLabel = _formatUpcomingRelativeLabel(context, data.startsAt);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _DashboardMetaChip(
              icon: Icons.auto_awesome_rounded,
              label: l10n.pick(vi: 'Điểm nổi bật', en: 'Today highlight'),
              backgroundColor: Colors.white.withValues(alpha: 0.56),
              foregroundColor: colorScheme.onSurface,
            ),
            const Spacer(),
            if (isRefreshing)
              const Padding(
                padding: EdgeInsets.only(right: 6),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            AppCompactIconButton(
              tooltip: l10n.pick(vi: 'Làm mới sự kiện', en: 'Refresh event'),
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        SizedBox(height: tokens.spaceLg),
        Text(
          event.title,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: tokens.spaceMd),
        Wrap(
          spacing: tokens.spaceSm,
          runSpacing: tokens.spaceSm,
          children: [
            _DashboardMetaChip(
              icon: Icons.schedule_rounded,
              label: timelineLabel,
              backgroundColor: colorScheme.primary.withValues(alpha: 0.10),
              foregroundColor: colorScheme.onSurface,
            ),
            _DashboardMetaChip(
              icon: Icons.event_note_rounded,
              label: _formatDashboardDateTime(data.startsAt),
            ),
            _DashboardMetaChip(
              icon: Icons.account_tree_outlined,
              label: l10n.pick(
                vi: 'Nhà/chi: $hostLabel',
                en: 'Household: $hostLabel',
              ),
            ),
            if (clanLabel.isNotEmpty)
              _DashboardMetaChip(
                icon: Icons.people_outline_rounded,
                label: l10n.pick(
                  vi: 'Họ tộc: $clanLabel',
                  en: 'Clan: $clanLabel',
                ),
              ),
          ],
        ),
        if (event.locationAddress.trim().isNotEmpty) ...[
          SizedBox(height: tokens.spaceMd),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(
                  Icons.location_on_outlined,
                  size: 18,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              SizedBox(width: tokens.spaceSm),
              Expanded(
                child: Text(
                  event.locationAddress.trim(),
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              AddressDirectionIconButton(
                address: event.locationAddress.trim(),
                iconSize: 18,
              ),
            ],
          ),
        ],
        SizedBox(height: tokens.spaceLg),
        Wrap(
          spacing: tokens.spaceSm,
          runSpacing: tokens.spaceSm,
          children: [
            FilledButton(
              onPressed: () {
                onOpenEventDetailRequested(event);
              },
              child: Text(l10n.pick(vi: 'Xem chi tiết', en: 'View details')),
            ),
            OutlinedButton(
              onPressed: onOpenEventsRequested,
              child: Text(
                l10n.pick(vi: 'Mở lịch sự kiện', en: 'Open calendar'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _UpcomingEventData {
  const _UpcomingEventData({
    required this.event,
    required this.hostHousehold,
    required this.clanName,
    required this.startsAt,
  });

  final EventRecord event;
  final String? hostHousehold;
  final String? clanName;
  final DateTime startsAt;
}

class _TodoSection extends StatefulWidget {
  const _TodoSection({
    required this.status,
    required this.session,
    required this.discoveryRepository,
    required this.onOpenTreeRequested,
    required this.onOpenProfileRequested,
    required this.onOpenEventsRequested,
    required this.onOpenMemorialChecklistRequested,
    required this.onOpenJoinRequestsRequested,
  });

  final FirebaseSetupStatus status;
  final AuthSession session;
  final GenealogyDiscoveryRepository discoveryRepository;
  final VoidCallback onOpenTreeRequested;
  final VoidCallback onOpenProfileRequested;
  final VoidCallback onOpenEventsRequested;
  final VoidCallback onOpenMemorialChecklistRequested;
  final VoidCallback onOpenJoinRequestsRequested;

  @override
  State<_TodoSection> createState() => _TodoSectionState();
}

class _TodoSectionState extends State<_TodoSection> {
  static const Set<String> _reviewerRoles = {
    'SUPER_ADMIN',
    'CLAN_ADMIN',
    'CLAN_LEADER',
    'BRANCH_ADMIN',
    'ADMIN_SUPPORT',
    'VICE_LEADER',
    'SUPPORTER_OF_LEADER',
  };

  bool _isLoadingJoinRequestSignals = false;
  bool _hasPendingJoinRequestsToReview = false;
  bool _hasMySubmittedJoinRequests = false;

  bool get _canReviewJoinRequests {
    final role = (widget.session.primaryRole ?? '').trim().toUpperCase();
    return widget.session.accessMode == AuthMemberAccessMode.claimed &&
        _sessionHasClanContext(widget.session) &&
        _reviewerRoles.contains(role);
  }

  bool get _isProfileLikelyComplete {
    final hasDisplayName = widget.session.displayName.trim().isNotEmpty;
    final hasPhone = widget.session.phoneE164.trim().isNotEmpty;
    final hasMemberLink = (widget.session.memberId ?? '').trim().isNotEmpty;
    return hasDisplayName &&
        hasPhone &&
        hasMemberLink &&
        widget.session.accessMode == AuthMemberAccessMode.claimed;
  }

  @override
  void initState() {
    super.initState();
    unawaited(_loadJoinRequestSignals());
  }

  @override
  void didUpdateWidget(covariant _TodoSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session.uid != widget.session.uid ||
        oldWidget.session.clanId != widget.session.clanId ||
        oldWidget.session.primaryRole != widget.session.primaryRole) {
      unawaited(_loadJoinRequestSignals());
    }
  }

  Future<void> _loadJoinRequestSignals() async {
    if (_isLoadingJoinRequestSignals) {
      return;
    }
    setState(() {
      _isLoadingJoinRequestSignals = true;
    });

    var hasMyRequests = false;
    var hasPendingReview = false;
    final myRequestsFuture = widget.discoveryRepository
        .loadMyJoinRequests(session: widget.session)
        .then((requests) => requests.isNotEmpty)
        .catchError((_) => false);
    final pendingReviewFuture = _canReviewJoinRequests
        ? widget.discoveryRepository
              .loadPendingJoinRequests(session: widget.session)
              .then((requests) => requests.isNotEmpty)
              .catchError((_) => false)
        : Future<bool>.value(false);

    final results = await _homeDashboardPerformanceLogger.measureAsync(
      metric: 'home.join_request_signals',
      dimensions: {'can_review': _canReviewJoinRequests ? 1 : 0},
      warnAfter: const Duration(milliseconds: 1800),
      action: () => Future.wait<bool>([myRequestsFuture, pendingReviewFuture]),
    );
    hasMyRequests = results[0];
    hasPendingReview = results[1];

    if (!mounted) {
      return;
    }
    setState(() {
      _hasMySubmittedJoinRequests = hasMyRequests;
      _hasPendingJoinRequestsToReview = hasPendingReview;
      _isLoadingJoinRequestSignals = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final tokens = context.uiTokens;
    final layout = ResponsiveLayout.of(context);
    final shouldShowJoinRequestsTask =
        _hasPendingJoinRequestsToReview || _hasMySubmittedJoinRequests;
    final tasks = <({IconData icon, String title, VoidCallback onTap})>[
      (
        icon: Icons.event_available_outlined,
        title: l10n.pick(
          vi: 'Kiểm tra sự kiện trong tuần',
          en: 'Review this week events',
        ),
        onTap: widget.onOpenEventsRequested,
      ),
      (
        icon: Icons.history_edu_outlined,
        title: l10n.pick(
          vi: 'Xem danh sách giỗ kỵ',
          en: 'View memorial checklist',
        ),
        onTap: widget.onOpenMemorialChecklistRequested,
      ),
      if (!_isProfileLikelyComplete)
        (
          icon: Icons.person_outline,
          title: l10n.pick(
            vi: 'Cập nhật hồ sơ của bạn',
            en: 'Update your profile',
          ),
          onTap: widget.onOpenProfileRequested,
        ),
      if (!_isLoadingJoinRequestSignals && shouldShowJoinRequestsTask)
        (
          icon: Icons.fact_check_outlined,
          title: _hasPendingJoinRequestsToReview
              ? l10n.pick(
                  vi: 'Xem yêu cầu gia nhập gia phả',
                  en: 'Review join requests',
                )
              : l10n.pick(
                  vi: 'Xem yêu cầu bạn đã gửi',
                  en: 'View your submitted requests',
                ),
          onTap: widget.onOpenJoinRequestsRequested,
        ),
      if (widget.session.accessMode == AuthMemberAccessMode.unlinked)
        (
          icon: Icons.travel_explore_outlined,
          title: l10n.pick(
            vi: 'Tìm gia phả để tham gia',
            en: 'Discover genealogies to join',
          ),
          onTap: widget.onOpenTreeRequested,
        ),
      if (!widget.status.isReady)
        (
          icon: Icons.cloud_off,
          title: l10n.pick(
            vi: 'Kiểm tra kết nối Firebase',
            en: 'Check Firebase connectivity',
          ),
          onTap: widget.onOpenProfileRequested,
        ),
    ];

    final visibleTasks = tasks.take(layout.isMobile ? 3 : 4);

    return _DashboardSectionShell(
      padding: EdgeInsets.all(tokens.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.pick(vi: 'Việc cần làm', en: 'To-do'),
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: tokens.spaceXs),
          Text(
            l10n.pick(
              vi: 'Giữ những việc quan trọng nhất ở ngay đầu màn hình.',
              en: 'Keep the most important follow-up actions close.',
            ),
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: tokens.spaceMd),
          for (final entry in visibleTasks)
            Padding(
              padding: EdgeInsets.only(bottom: tokens.spaceSm),
              child: Material(
                color: colorScheme.surface.withValues(alpha: 0.78),
                borderRadius: BorderRadius.circular(tokens.radiusMd),
                child: InkWell(
                  borderRadius: BorderRadius.circular(tokens.radiusMd),
                  onTap: entry.onTap,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: tokens.spaceMd,
                      vertical: tokens.spaceMd,
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: colorScheme.primaryContainer,
                          foregroundColor: colorScheme.onPrimaryContainer,
                          child: Icon(entry.icon, size: 18),
                        ),
                        SizedBox(width: tokens.spaceMd),
                        Expanded(
                          child: Text(
                            entry.title,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _NearbyRelative {
  const _NearbyRelative({
    required this.member,
    required this.distanceKm,
    required this.relationHint,
  });

  final MemberProfile member;
  final double distanceKm;
  final String relationHint;
}

class _NearbyRelativeLoadResult {
  const _NearbyRelativeLoadResult({
    required this.items,
    required this.message,
    this.canRetry = true,
    this.retryAction = _NearbyRetryAction.reload,
    this.settingsTarget,
  });

  final List<_NearbyRelative> items;
  final String message;
  final bool canRetry;
  final _NearbyRetryAction retryAction;
  final _NearbySettingsTarget? settingsTarget;

  bool get hasItems => items.isNotEmpty;
}

enum _NearbyRetryAction { reload, requestPermission }

enum _NearbySettingsTarget { appPermission, locationService }

class _NearbyRelativesSection extends StatefulWidget {
  const _NearbyRelativesSection({
    required this.session,
    required this.memberRepository,
  });

  final AuthSession session;
  final MemberRepository memberRepository;

  @override
  State<_NearbyRelativesSection> createState() =>
      _NearbyRelativesSectionState();
}

class _NearbyRelativesSectionState extends State<_NearbyRelativesSection> {
  static const int _maxCandidateCount = 80;
  static const int _nearbyQueryPageSize = 120;
  static const int _maxNearbyScanDocuments = 1200;
  static const Duration _liveLocationMaxAge = Duration(hours: 12);
  static const Duration _preferredLastKnownLocationAge = Duration(minutes: 5);
  static const Duration _nearbyPushThrottle = Duration(minutes: 15);
  static const double _nearbyPushDistanceKm = 10;
  static const int _nearbyPushMaxMemberIds = 5;

  late Future<_NearbyRelativeLoadResult> _future;
  _NearbyRelativeLoadResult? _cachedResult;
  bool _isRefreshing = false;
  String _lastNearbyAlertSignature = '';
  DateTime? _lastNearbyAlertAt;

  CollectionReference<Map<String, dynamic>> get _membersCollection =>
      FirebaseServices.firestore.collection('members');

  @override
  void initState() {
    super.initState();
    _future = _loadNearbyRelativesAndCache();
  }

  @override
  void didUpdateWidget(covariant _NearbyRelativesSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session != widget.session ||
        oldWidget.memberRepository != widget.memberRepository) {
      _future = _loadNearbyRelativesAndCache();
    }
  }

  Future<_NearbyRelativeLoadResult> _loadNearbyRelativesAndCache() async {
    final result = await _homeDashboardPerformanceLogger.measureAsync(
      metric: 'home.nearby_relatives',
      dimensions: {
        'has_clan_context': _sessionHasClanContext(widget.session) ? 1 : 0,
      },
      warnAfter: const Duration(milliseconds: 2500),
      action: _loadNearbyRelatives,
    );
    _cachedResult = result;
    return result;
  }

  Future<Position?> _resolveCurrentPosition() async {
    try {
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null) {
        final age = DateTime.now().difference(lastKnown.timestamp);
        if (age <= _preferredLastKnownLocationAge) {
          return lastKnown;
        }
      }
    } catch (_) {
      // Fall through to active location fetch.
    }

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 8),
        ),
      );
    } catch (_) {
      try {
        return await Geolocator.getLastKnownPosition();
      } catch (_) {
        return null;
      }
    }
  }

  Future<_NearbyRelativeLoadResult> _loadNearbyRelatives() async {
    final l10n = context.l10n;
    if (!_sessionHasClanContext(widget.session)) {
      return _NearbyRelativeLoadResult(
        items: const [],
        canRetry: false,
        message: l10n.pick(
          vi: 'Hãy tham gia gia phả để xem người thân ở gần bạn.',
          en: 'Join a genealogy first to see nearby relatives.',
        ),
      );
    }
    final activeClanId = (widget.session.clanId ?? '').trim();
    if (activeClanId.isEmpty) {
      return _NearbyRelativeLoadResult(
        items: const [],
        canRetry: false,
        message: l10n.pick(
          vi: 'Hãy tham gia gia phả để xem người thân ở gần bạn.',
          en: 'Join a genealogy first to see nearby relatives.',
        ),
      );
    }

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return _NearbyRelativeLoadResult(
        items: const [],
        message: l10n.pick(
          vi: 'Vui lòng bật dịch vụ vị trí để tìm người thân ở gần.',
          en: 'Please enable location services to discover nearby relatives.',
        ),
        settingsTarget: _NearbySettingsTarget.locationService,
      );
    }

    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      return _NearbyRelativeLoadResult(
        items: const [],
        canRetry: true,
        retryAction: _NearbyRetryAction.requestPermission,
        message: l10n.pick(
          vi: 'Cho phép vị trí để xem khoảng cách và phát hiện người thân ở gần bạn.',
          en: 'Allow location access to calculate distance and discover nearby relatives.',
        ),
      );
    }
    if (permission == LocationPermission.deniedForever) {
      return _NearbyRelativeLoadResult(
        items: const [],
        message: l10n.pick(
          vi: 'Quyền vị trí đang bị tắt vĩnh viễn. Mở cài đặt ứng dụng để bật lại và xem người thân ở gần.',
          en: 'Location access is permanently disabled. Open app settings to re-enable nearby relatives.',
        ),
        settingsTarget: _NearbySettingsTarget.appPermission,
      );
    }

    final currentPosition = await _resolveCurrentPosition();
    if (currentPosition == null) {
      return _NearbyRelativeLoadResult(
        items: const [],
        message: l10n.pick(
          vi: 'Không lấy được vị trí hiện tại. Vui lòng thử lại.',
          en: 'Unable to read your current location. Please retry.',
        ),
      );
    }

    final activeMemberId = (widget.session.memberId ?? '').trim();
    if (activeMemberId.isNotEmpty) {
      unawaited(
        widget.memberRepository
            .updateMemberLiveLocation(
              session: widget.session,
              memberId: activeMemberId,
              sharingEnabled: true,
              latitude: currentPosition.latitude,
              longitude: currentPosition.longitude,
              accuracyMeters: currentPosition.accuracy,
            )
            .catchError((_) {
              // Keep nearby discovery functional even if live-location sync fails.
            }),
      );
    }

    final activeUid = widget.session.uid.trim();
    List<MemberProfile> candidates;
    Map<String, MemberProfile> membersById;
    try {
      candidates = await _loadNearbyCandidateMembers(
        clanId: activeClanId,
        activeMemberId: activeMemberId,
        activeUid: activeUid,
      );
      membersById = await _loadNearbyRelationContext(candidates);
      for (final candidate in candidates) {
        membersById[candidate.id] = candidate;
      }
    } catch (_) {
      return _NearbyRelativeLoadResult(
        items: const [],
        canRetry: true,
        message: l10n.pick(
          vi: 'Không tải được danh sách người thân ở gần lúc này. Vui lòng thử lại.',
          en: 'Unable to load nearby relatives right now. Please retry.',
        ),
      );
    }

    final nearbyItems = <_NearbyRelative>[];
    for (final member in candidates) {
      final memberLatitude = member.locationLatitude!;
      final memberLongitude = member.locationLongitude!;
      final distanceMeters = Geolocator.distanceBetween(
        currentPosition.latitude,
        currentPosition.longitude,
        memberLatitude,
        memberLongitude,
      );
      if (!distanceMeters.isFinite || distanceMeters < 0) {
        continue;
      }
      nearbyItems.add(
        _NearbyRelative(
          member: member,
          distanceKm: distanceMeters / 1000,
          relationHint: _relationHintFor(
            member: member,
            membersById: membersById,
            l10n: l10n,
          ),
        ),
      );
    }

    nearbyItems.sort(
      (left, right) => left.distanceKm.compareTo(right.distanceKm),
    );

    if (activeMemberId.isNotEmpty && nearbyItems.isNotEmpty) {
      _notifyNearbyRelativesIfNeeded(
        session: widget.session,
        clanId: activeClanId,
        activeMemberId: activeMemberId,
        nearbyItems: nearbyItems,
      );
    }

    if (nearbyItems.isEmpty) {
      return _NearbyRelativeLoadResult(
        items: const [],
        canRetry: true,
        message: l10n.pick(
          vi: 'Chưa có người thân nào chia sẻ vị trí thực tế. Nhờ họ bật quyền vị trí và mở BeFam để cập nhật gần bạn.',
          en: 'No relatives are sharing live location yet. Ask them to allow location and open BeFam to appear nearby.',
        ),
      );
    }

    return _NearbyRelativeLoadResult(
      items: nearbyItems,
      message: l10n.pick(
        vi: 'Đã tìm thấy ${nearbyItems.length} người thân có thể ở gần bạn.',
        en: 'Found ${nearbyItems.length} relatives that may be near you.',
      ),
    );
  }

  void _notifyNearbyRelativesIfNeeded({
    required AuthSession session,
    required String clanId,
    required String activeMemberId,
    required List<_NearbyRelative> nearbyItems,
  }) {
    final candidates = nearbyItems
        .where((item) => item.distanceKm <= _nearbyPushDistanceKm)
        .take(_nearbyPushMaxMemberIds)
        .toList(growable: false);
    if (candidates.isEmpty) {
      return;
    }

    final relativeIds =
        candidates
            .map((item) => item.member.id.trim())
            .where((id) => id.isNotEmpty && id != activeMemberId)
            .toSet()
            .toList(growable: false)
          ..sort();
    if (relativeIds.isEmpty) {
      return;
    }

    final now = DateTime.now();
    final signature =
        '${clanId.trim()}|${activeMemberId.trim()}|${relativeIds.join(',')}';
    final lastAlertAt = _lastNearbyAlertAt;
    if (signature == _lastNearbyAlertSignature &&
        lastAlertAt != null &&
        now.difference(lastAlertAt) < _nearbyPushThrottle) {
      return;
    }

    _lastNearbyAlertSignature = signature;
    _lastNearbyAlertAt = now;
    unawaited(
      widget.memberRepository
          .notifyNearbyRelativesDetected(
            session: session,
            clanId: clanId,
            memberId: activeMemberId,
            relativeMemberIds: relativeIds,
            closestDistanceKm: candidates.first.distanceKm,
          )
          .catchError((_) {
            // Nearby discovery remains functional even if push dispatch fails.
          }),
    );
  }

  Future<List<MemberProfile>> _loadNearbyCandidateMembers({
    required String clanId,
    required String activeMemberId,
    required String activeUid,
  }) async {
    final candidates = <MemberProfile>[];
    QueryDocumentSnapshot<Map<String, dynamic>>? cursor;
    var scannedCount = 0;
    while (candidates.length < _maxCandidateCount &&
        scannedCount < _maxNearbyScanDocuments) {
      Query<Map<String, dynamic>> query = _membersCollection
          .where('clanId', isEqualTo: clanId)
          .where('locationSharingEnabled', isEqualTo: true)
          .limit(_nearbyQueryPageSize);
      if (cursor != null) {
        query = query.startAfterDocument(cursor);
      }
      final snapshot = await query.get();
      if (snapshot.docs.isEmpty) {
        break;
      }
      scannedCount += snapshot.docs.length;
      cursor = snapshot.docs.last;

      for (final doc in snapshot.docs) {
        final member = _memberFromSnapshot(doc);
        if (!_isNearbyCandidateMember(
          member,
          activeClanId: clanId,
          activeMemberId: activeMemberId,
          activeUid: activeUid,
        )) {
          continue;
        }
        candidates.add(member);
        if (candidates.length >= _maxCandidateCount) {
          break;
        }
      }

      if (snapshot.docs.length < _nearbyQueryPageSize) {
        break;
      }
    }
    return candidates;
  }

  Future<Map<String, MemberProfile>> _loadNearbyRelationContext(
    List<MemberProfile> candidates,
  ) async {
    final parentIds = <String>{};
    for (final candidate in candidates) {
      for (final parentId in candidate.parentIds) {
        final normalized = parentId.trim();
        if (normalized.isNotEmpty) {
          parentIds.add(normalized);
        }
      }
    }
    final parentsById = await _loadMembersByIds(parentIds);
    if (parentsById.isEmpty) {
      return {};
    }

    final grandParentIds = <String>{};
    for (final parent in parentsById.values) {
      for (final grandParentId in parent.parentIds) {
        final normalized = grandParentId.trim();
        if (normalized.isNotEmpty) {
          grandParentIds.add(normalized);
        }
      }
    }
    if (grandParentIds.isEmpty) {
      return parentsById;
    }
    final grandParentsById = await _loadMembersByIds(grandParentIds);
    return <String, MemberProfile>{...parentsById, ...grandParentsById};
  }

  Future<Map<String, MemberProfile>> _loadMembersByIds(
    Set<String> memberIds,
  ) async {
    final normalized = memberIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (normalized.isEmpty) {
      return {};
    }

    final membersById = <String, MemberProfile>{};
    for (var offset = 0; offset < normalized.length; offset += 30) {
      final nextOffset = math.min(offset + 30, normalized.length);
      final chunk = normalized.sublist(offset, nextOffset);
      final snapshot = await _membersCollection
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      for (final doc in snapshot.docs) {
        final member = _memberFromSnapshot(doc);
        if (member.id.trim().isNotEmpty) {
          membersById[member.id] = member;
        }
      }
    }
    return membersById;
  }

  MemberProfile _memberFromSnapshot(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final rawId = (data['id'] as String?)?.trim() ?? '';
    return MemberProfile.fromJson({
      ...data,
      'id': rawId.isNotEmpty ? rawId : doc.id,
    });
  }

  bool _isNearbyCandidateMember(
    MemberProfile member, {
    required String activeClanId,
    required String activeMemberId,
    required String activeUid,
  }) {
    if (member.clanId.trim() != activeClanId) {
      return false;
    }
    if (!member.locationSharingEnabled ||
        !_memberHasShareableCoordinates(member) ||
        !_isMemberLocationFresh(member)) {
      return false;
    }
    if (activeMemberId.isNotEmpty && member.id == activeMemberId) {
      return false;
    }
    if (activeUid.isNotEmpty && (member.authUid ?? '').trim() == activeUid) {
      return false;
    }
    final status = member.status.trim().toLowerCase();
    if (status == 'inactive' || status == 'deleted') {
      return false;
    }
    return true;
  }

  bool _memberHasShareableCoordinates(MemberProfile member) {
    final latitude = member.locationLatitude;
    final longitude = member.locationLongitude;
    if (latitude == null || longitude == null) {
      return false;
    }
    return latitude.isFinite &&
        longitude.isFinite &&
        latitude >= -90 &&
        latitude <= 90 &&
        longitude >= -180 &&
        longitude <= 180;
  }

  bool _isMemberLocationFresh(MemberProfile member) {
    final rawUpdatedAt = member.locationUpdatedAt?.trim() ?? '';
    if (rawUpdatedAt.isEmpty) {
      return false;
    }
    final updatedAt = DateTime.tryParse(rawUpdatedAt);
    if (updatedAt == null) {
      return false;
    }
    return DateTime.now().difference(updatedAt.toLocal()) <=
        _liveLocationMaxAge;
  }

  String _relationHintFor({
    required MemberProfile member,
    required Map<String, MemberProfile> membersById,
    required AppLocalizations l10n,
  }) {
    final parentNames = member.parentIds
        .map((id) => membersById[id]?.displayName.trim() ?? '')
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList(growable: false);

    if (parentNames.isEmpty) {
      return l10n.pick(
        vi: 'Chưa có dữ liệu cha/mẹ trong gia phả',
        en: 'No parent relation data in this genealogy yet',
      );
    }

    final relationParts = <String>[
      l10n.pick(
        vi: 'Con của ${_compactNameList(parentNames, l10n)}',
        en: 'Child of ${_compactNameList(parentNames, l10n)}',
      ),
    ];

    final grandParentNames = <String>{};
    for (final parentId in member.parentIds) {
      final parent = membersById[parentId];
      if (parent == null) {
        continue;
      }
      for (final grandParentId in parent.parentIds) {
        final grandParentName =
            membersById[grandParentId]?.displayName.trim() ?? '';
        if (grandParentName.isNotEmpty) {
          grandParentNames.add(grandParentName);
        }
      }
    }

    if (grandParentNames.isNotEmpty) {
      relationParts.add(
        l10n.pick(
          vi: 'Cháu của ${_compactNameList(grandParentNames.toList(), l10n)}',
          en: 'Grandchild of ${_compactNameList(grandParentNames.toList(), l10n)}',
        ),
      );
    }

    return relationParts.join(' • ');
  }

  String _compactNameList(List<String> names, AppLocalizations l10n) {
    final unique = names
        .map((name) => name.trim())
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (unique.isEmpty) {
      return '';
    }
    if (unique.length == 1) {
      return unique.first;
    }
    if (unique.length == 2) {
      return '${unique.first} & ${unique.last}';
    }
    final preview = '${unique[0]}, ${unique[1]}';
    final remaining = unique.length - 2;
    return l10n.pick(vi: '$preview +$remaining', en: '$preview +$remaining');
  }

  void _reload() {
    if (_isRefreshing) {
      return;
    }
    setState(() {
      _isRefreshing = true;
      _future = _loadNearbyRelativesAndCache().whenComplete(() {
        if (!mounted || !_isRefreshing) {
          return;
        }
        setState(() {
          _isRefreshing = false;
        });
      });
    });
  }

  Future<void> _requestLocationPermissionAndReload() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      await Geolocator.requestPermission();
    }
    if (!mounted) {
      return;
    }
    _reload();
  }

  void _openNearbySheet(List<_NearbyRelative> items) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _NearbyRelativesSheet(items: items),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final tokens = context.uiTokens;
    final layout = ResponsiveLayout.of(context);
    return _DashboardSectionShell(
      padding: EdgeInsets.all(tokens.spaceLg),
      child: FutureBuilder<_NearbyRelativeLoadResult>(
        future: _future,
        builder: (context, snapshot) {
          final isWaiting = snapshot.connectionState == ConnectionState.waiting;
          final result = snapshot.data ?? _cachedResult;
          if (isWaiting && result == null) {
            return const _NearbyRelativesLoadingSkeleton(
              key: ValueKey<String>('nearby-loading'),
            );
          }

          if (result == null) {
            return _NearbyRelativesEmpty(
              key: const ValueKey<String>('nearby-null'),
              message: l10n.pick(
                vi: 'Không tải được danh sách người thân ở gần. Vui lòng thử lại.',
                en: 'Unable to load nearby relatives. Please try again.',
              ),
              canRetry: true,
              retryAction: _NearbyRetryAction.reload,
              onRetry: _reload,
              onRadarScan: _reload,
              onOpenSettings: _openNearbySettings,
            );
          }

          if (!result.hasItems) {
            return _NearbyRelativesEmpty(
              key: const ValueKey<String>('nearby-empty'),
              message: result.message,
              canRetry: result.canRetry,
              retryAction: result.retryAction,
              onRetry:
                  result.retryAction == _NearbyRetryAction.requestPermission
                  ? _requestLocationPermissionAndReload
                  : _reload,
              onRadarScan: _reload,
              settingsTarget: result.settingsTarget,
              onOpenSettings: _openNearbySettings,
            );
          }

          final previewItems = result.items
              .take(layout.isMobile ? 2 : 3)
              .toList(growable: false);
          final content = Column(
            key: ValueKey<String>(
              'nearby-${result.items.length}-${result.items.first.member.id}',
            ),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    l10n.pick(
                      vi: 'Người thân ở gần bạn',
                      en: 'Relatives nearby',
                    ),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  if (_isRefreshing)
                    const Padding(
                      padding: EdgeInsets.only(right: 6),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  AppCompactIconButton(
                    tooltip: l10n.pick(
                      vi: 'Rà lại người thân gần đây',
                      en: 'Rescan nearby relatives',
                    ),
                    onPressed: _reload,
                    icon: const Icon(Icons.radar),
                  ),
                ],
              ),
              SizedBox(height: tokens.spaceXs),
              Text(
                result.message,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              SizedBox(height: tokens.spaceMd),
              for (final item in previewItems)
                Padding(
                  padding: EdgeInsets.only(bottom: tokens.spaceSm),
                  child: Material(
                    color: theme.colorScheme.surface.withValues(alpha: 0.78),
                    borderRadius: BorderRadius.circular(tokens.radiusMd),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: tokens.spaceMd,
                        vertical: tokens.spaceMd,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: theme.colorScheme.primaryContainer,
                            foregroundColor:
                                theme.colorScheme.onPrimaryContainer,
                            child: const Icon(
                              Icons.person_pin_circle_outlined,
                              size: 18,
                            ),
                          ),
                          SizedBox(width: tokens.spaceMd),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.member.displayName,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if ((item.member.phoneE164 ?? '').isNotEmpty)
                                  Text(
                                    item.member.phoneE164!,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                SizedBox(height: tokens.spaceXs),
                                Text(
                                  item.relationHint,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: tokens.spaceSm),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              _DashboardMetaChip(
                                label: _formatDistanceLabel(item.distanceKm),
                                backgroundColor: theme.colorScheme.primary
                                    .withValues(alpha: 0.10),
                                foregroundColor: theme.colorScheme.onSurface,
                              ),
                              SizedBox(height: tokens.spaceXs),
                              MemberPhoneActionIconButton(
                                phoneNumber: item.member.phoneE164 ?? '',
                                contactName: item.member.displayName,
                                iconSize: 18,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              AppCompactTextButton(
                onPressed: () => _openNearbySheet(result.items),
                child: Text(l10n.pick(vi: 'Xem danh sách', en: 'View list')),
              ),
            ],
          );
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeOutCubic,
            child: content,
          );
        },
      ),
    );
  }

  Future<void> _openNearbySettings(_NearbySettingsTarget target) async {
    final l10n = context.l10n;
    final opened = switch (target) {
      _NearbySettingsTarget.appPermission => await Geolocator.openAppSettings(),
      _NearbySettingsTarget.locationService =>
        await Geolocator.openLocationSettings(),
    };
    if (!mounted || opened) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          l10n.pick(
            vi: 'Không thể mở phần cài đặt vị trí trên thiết bị này.',
            en: 'Unable to open location settings on this device.',
          ),
        ),
      ),
    );
  }
}

enum _NearbyDistanceFilter { all, under5, under20, under50 }

class _NearbyRelativesSheet extends StatefulWidget {
  const _NearbyRelativesSheet({required this.items});

  final List<_NearbyRelative> items;

  @override
  State<_NearbyRelativesSheet> createState() => _NearbyRelativesSheetState();
}

class _NearbyRelativesSheetState extends State<_NearbyRelativesSheet> {
  late final TextEditingController _searchController;
  String _query = '';
  _NearbyDistanceFilter _distanceFilter = _NearbyDistanceFilter.all;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController()
      ..addListener(() {
        final next = _searchController.text.trim().toLowerCase();
        if (next == _query) {
          return;
        }
        setState(() {
          _query = next;
        });
      });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<_NearbyRelative> _visibleItems() {
    final filtered = widget.items
        .where((item) {
          if (!_matchesDistance(item.distanceKm)) {
            return false;
          }
          if (_query.isEmpty) {
            return true;
          }
          final fullName = item.member.fullName.toLowerCase();
          final nickName = item.member.nickName.toLowerCase();
          final phone = (item.member.phoneE164 ?? '').toLowerCase();
          final relation = item.relationHint.toLowerCase();
          return fullName.contains(_query) ||
              nickName.contains(_query) ||
              phone.contains(_query) ||
              relation.contains(_query);
        })
        .toList(growable: false);
    filtered.sort((left, right) {
      final distanceCompare = left.distanceKm.compareTo(right.distanceKm);
      if (distanceCompare != 0) {
        return distanceCompare;
      }
      return left.member.displayName.toLowerCase().compareTo(
        right.member.displayName.toLowerCase(),
      );
    });
    return filtered;
  }

  bool _matchesDistance(double distanceKm) {
    return switch (_distanceFilter) {
      _NearbyDistanceFilter.all => true,
      _NearbyDistanceFilter.under5 => distanceKm <= 5,
      _NearbyDistanceFilter.under20 => distanceKm <= 20,
      _NearbyDistanceFilter.under50 => distanceKm <= 50,
    };
  }

  String _filterLabel(BuildContext context, _NearbyDistanceFilter filter) {
    final l10n = context.l10n;
    return switch (filter) {
      _NearbyDistanceFilter.all => l10n.pick(vi: 'Tất cả', en: 'All distances'),
      _NearbyDistanceFilter.under5 => l10n.pick(vi: '≤ 5 km', en: '≤ 5 km'),
      _NearbyDistanceFilter.under20 => l10n.pick(vi: '≤ 20 km', en: '≤ 20 km'),
      _NearbyDistanceFilter.under50 => l10n.pick(vi: '≤ 50 km', en: '≤ 50 km'),
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final visibleItems = _visibleItems();

    return FractionallySizedBox(
      heightFactor: 0.92,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.pick(vi: 'Người thân ở gần', en: 'Nearby relatives'),
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: l10n.pick(
                      vi: 'Tìm theo tên, SĐT, quan hệ',
                      en: 'Search by name, phone, relation',
                    ),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: l10n.pick(vi: 'Xóa', en: 'Clear'),
                            onPressed: () => _searchController.clear(),
                            icon: const Icon(Icons.close),
                          ),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final filter in _NearbyDistanceFilter.values)
                      FilterChip(
                        label: Text(_filterLabel(context, filter)),
                        selected: _distanceFilter == filter,
                        onSelected: (_) {
                          setState(() {
                            _distanceFilter = filter;
                          });
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.pick(
                    vi: 'Hiển thị ${visibleItems.length}/${widget.items.length} người thân gần nhất.',
                    en: 'Showing ${visibleItems.length}/${widget.items.length} nearest relatives.',
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: visibleItems.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        l10n.pick(
                          vi: 'Không có kết quả phù hợp với bộ lọc hiện tại.',
                          en: 'No relatives match your current search/filter.',
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
                    itemCount: visibleItems.length,
                    itemBuilder: (context, index) {
                      final item = visibleItems[index];
                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.people_alt_outlined),
                          title: Text(item.member.displayName),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(item.member.phoneE164 ?? ''),
                              Text(
                                item.relationHint,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                          trailing: SizedBox(
                            width: 116,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Flexible(
                                  child: Text(
                                    _formatDistanceLabel(item.distanceKm),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.labelLarge,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                MemberPhoneActionIconButton(
                                  phoneNumber: item.member.phoneE164 ?? '',
                                  contactName: item.member.displayName,
                                  iconSize: 18,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _NearbyRelativesLoadingSkeleton extends StatelessWidget {
  const _NearbyRelativesLoadingSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        AppSkeletonBox(width: 190, height: 20),
        SizedBox(height: 10),
        AppSkeletonBox(width: double.infinity, height: 16),
        SizedBox(height: 14),
        AppSkeletonBox(width: double.infinity, height: 64),
        SizedBox(height: 10),
        AppSkeletonBox(width: double.infinity, height: 64),
      ],
    );
  }
}

class _NearbyRelativesEmpty extends StatelessWidget {
  const _NearbyRelativesEmpty({
    super.key,
    required this.message,
    required this.canRetry,
    required this.retryAction,
    required this.onRetry,
    required this.onRadarScan,
    this.settingsTarget,
    this.onOpenSettings,
  });

  final String message;
  final bool canRetry;
  final _NearbyRetryAction retryAction;
  final VoidCallback onRetry;
  final VoidCallback onRadarScan;
  final _NearbySettingsTarget? settingsTarget;
  final Future<void> Function(_NearbySettingsTarget target)? onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tokens = context.uiTokens;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              l10n.pick(vi: 'Người thân ở gần bạn', en: 'Relatives nearby'),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const Spacer(),
            AppCompactIconButton(
              tooltip: l10n.pick(
                vi: 'Rà lại người thân gần đây',
                en: 'Rescan nearby relatives',
              ),
              onPressed: onRadarScan,
              icon: const Icon(Icons.radar),
            ),
          ],
        ),
        SizedBox(height: tokens.spaceXs),
        Text(
          message,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (settingsTarget != null && onOpenSettings != null) ...[
          SizedBox(height: tokens.spaceSm),
          AppCompactTextButton(
            onPressed: () => unawaited(onOpenSettings!(settingsTarget!)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.open_in_new, size: 18),
                SizedBox(width: tokens.spaceSm),
                Text(switch (settingsTarget!) {
                  _NearbySettingsTarget.appPermission => l10n.pick(
                    vi: 'Mở cài đặt quyền vị trí',
                    en: 'Open app location permission',
                  ),
                  _NearbySettingsTarget.locationService => l10n.pick(
                    vi: 'Mở dịch vụ vị trí của máy',
                    en: 'Open device location services',
                  ),
                }),
              ],
            ),
          ),
        ],
        if (canRetry) ...[
          SizedBox(height: tokens.spaceSm),
          AppCompactTextButton(
            onPressed: onRetry,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  retryAction == _NearbyRetryAction.requestPermission
                      ? Icons.my_location_outlined
                      : Icons.refresh,
                  size: 18,
                ),
                SizedBox(width: tokens.spaceSm),
                Text(
                  retryAction == _NearbyRetryAction.requestPermission
                      ? l10n.pick(
                          vi: 'Cho phép vị trí',
                          en: 'Allow location access',
                        )
                      : l10n.notificationInboxRetryAction,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

String _formatDistanceLabel(double distanceKm) {
  if (distanceKm < 1) {
    return '${(distanceKm * 1000).round()} m';
  }
  if (distanceKm < 10) {
    return '${distanceKm.toStringAsFixed(1)} km';
  }
  return '${distanceKm.toStringAsFixed(0)} km';
}

class _ShellDestination {
  const _ShellDestination({
    required this.id,
    required this.icon,
    required this.selectedIcon,
  });

  final String id;
  final IconData icon;
  final IconData selectedIcon;
}

IconData _iconFor(String iconKey) {
  return switch (iconKey) {
    'clan' => Icons.apartment_outlined,
    'tree' => Icons.account_tree_outlined,
    'members' => Icons.groups_2_outlined,
    'events' => Icons.event_note_outlined,
    'funds' => Icons.volunteer_activism_outlined,
    'scholarship' => Icons.school_outlined,
    'profile' => Icons.person_outline,
    _ => Icons.widgets_outlined,
  };
}
