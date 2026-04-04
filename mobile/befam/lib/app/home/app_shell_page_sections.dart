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
    required this.scholarshipRepository,
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
  final ScholarshipRepository scholarshipRepository;
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
      AppViewport.mobile => layout.width < 390 ? 1.14 : 1.22,
      AppViewport.tablet => 1.28,
      AppViewport.desktop => 1.34,
    };

    return ListView(
      padding: EdgeInsets.fromLTRB(
        layout.horizontalPadding,
        tokens.spaceMd,
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
                  l10n.pick(
                    vi: 'Hôm nay trong gia đình',
                    en: 'Today with your family',
                  ),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(
                  height: layout.isMobile ? tokens.spaceSm : tokens.spaceLg,
                ),
                _UpcomingEventSection(
                  session: session,
                  eventRepository: eventRepository,
                  activeClanName: _activeClanName,
                  onOpenEventsRequested: onOpenEventsRequested,
                  onOpenEventDetailRequested:
                      onOpenUpcomingEventDetailRequested,
                ),
                SizedBox(
                  height: layout.isMobile ? tokens.spaceSm : tokens.spaceLg,
                ),
                _DashboardSectionShell(
                  padding: EdgeInsets.all(tokens.spaceLg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              l10n.pick(vi: 'Lối tắt', en: 'Shortcuts'),
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          AppCompactTextButton(
                            onPressed: () => _openAllShortcutsSheet(context),
                            child: Text(l10n.pick(vi: 'Tất cả', en: 'All')),
                          ),
                        ],
                      ),
                      SizedBox(
                        height: layout.isMobile
                            ? tokens.spaceSm
                            : tokens.spaceMd,
                      ),
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
                SizedBox(
                  height: layout.isMobile ? tokens.spaceSm : tokens.spaceLg,
                ),
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
                  SizedBox(height: tokens.spaceMd),
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
              l10n.pick(vi: 'Tất cả lối tắt', en: 'All shortcuts'),
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
                repository: scholarshipRepository,
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
    this.gradient,
    this.showAccentOrbs = false,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
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
        color: Colors.white.withValues(alpha: 0.86),
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
    final layout = ResponsiveLayout.of(context);
    final resolvedForeground = foregroundColor ?? theme.colorScheme.onSurface;
    final resolvedBackground =
        backgroundColor ?? Colors.white.withValues(alpha: 0.56);
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final maxChipWidth = layout.isMobile
        ? math.min(viewportWidth * 0.62, 224.0)
        : 320.0;

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxChipWidth),
      child: DecoratedBox(
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
              Flexible(
                child: Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: resolvedForeground,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
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
    final compactTile = layout.isMobile;
    final statusColor = switch (shortcut.status) {
      AppShortcutStatus.live => colorScheme.primaryContainer,
      AppShortcutStatus.bootstrap => colorScheme.secondaryContainer,
      AppShortcutStatus.planned => colorScheme.surfaceContainerHighest,
    };
    final showDescription = !compactTile;
    final tilePadding = compactTile ? tokens.spaceMd : tokens.spaceLg;
    final avatarRadius = compactTile ? 17.0 : 19.0;
    final titleFontSize = compactTile ? 16.0 : 17.0;

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
            padding: EdgeInsets.all(tilePadding),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: avatarRadius,
                      backgroundColor: statusColor,
                      foregroundColor: colorScheme.onSurface,
                      child: Icon(
                        _iconFor(shortcut.iconKey),
                        size: compactTile ? 16 : 18,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      isEnabled
                          ? Icons.north_east_rounded
                          : Icons.lock_outline_rounded,
                      size: compactTile ? 16 : 18,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
                SizedBox(height: compactTile ? tokens.spaceSm : tokens.spaceMd),
                Text(
                  l10n.shortcutTitle(shortcut.id),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: titleFontSize,
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

String _productionShortcutDescription(BuildContext context, String shortcutId) {
  final l10n = context.l10n;
  return switch (shortcutId) {
    'clan' => l10n.pick(
      vi: 'Xem thông tin họ tộc và các nhánh trong gia đình.',
      en: 'View clan details and family branches.',
    ),
    'tree' => l10n.pick(
      vi: 'Xem cây gia phả và các mối quan hệ trong họ.',
      en: 'Explore the family tree and member relationships.',
    ),
    'members' => l10n.pick(
      vi: 'Tìm và cập nhật hồ sơ thành viên.',
      en: 'Search and update member profiles.',
    ),
    'events' => l10n.pick(
      vi: 'Theo dõi lịch họ, giỗ và lời nhắc quan trọng.',
      en: 'Follow family events, memorial dates, and reminders.',
    ),
    'funds' => l10n.pick(
      vi: 'Theo dõi đóng góp, thu chi và số dư quỹ.',
      en: 'Track contributions, spending, and fund balance.',
    ),
    'scholarship' => l10n.pick(
      vi: 'Theo dõi hồ sơ khuyến học của gia đình.',
      en: 'Review scholarship requests and student support.',
    ),
    'profile' => l10n.pick(
      vi: 'Cập nhật hồ sơ và thiết lập tài khoản.',
      en: 'Update your profile and account settings.',
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
              label: l10n.pick(vi: 'Sắp tới', en: 'Coming up'),
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
            vi: 'Chưa có sự kiện sắp tới.',
            en: 'No upcoming events yet.',
          ),
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: tokens.spaceLg),
        Wrap(
          spacing: tokens.spaceSm,
          runSpacing: tokens.spaceSm,
          children: [
            FilledButton(
              onPressed: onOpenEventsRequested,
              child: Text(l10n.pick(vi: 'Mở lịch', en: 'Open calendar')),
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
              label: l10n.pick(vi: 'Sắp tới', en: 'Coming up'),
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
                vi: 'Chi/nhà: $hostLabel',
                en: 'Household: $hostLabel',
              ),
            ),
            if (clanLabel.isNotEmpty)
              _DashboardMetaChip(
                icon: Icons.people_outline_rounded,
                label: l10n.pick(
                  vi: 'Dòng tộc: $clanLabel',
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
              child: Text(l10n.pick(vi: 'Xem sự kiện', en: 'View details')),
            ),
            OutlinedButton(
              onPressed: onOpenEventsRequested,
              child: Text(l10n.pick(vi: 'Mở lịch', en: 'Open calendar')),
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
        title: l10n.pick(vi: 'Xem lịch tuần này', en: 'This week schedule'),
        onTap: widget.onOpenEventsRequested,
      ),
      (
        icon: Icons.history_edu_outlined,
        title: l10n.pick(vi: 'Xem danh sách giỗ', en: 'Memorial list'),
        onTap: widget.onOpenMemorialChecklistRequested,
      ),
      if (!_isProfileLikelyComplete)
        (
          icon: Icons.person_outline,
          title: l10n.pick(vi: 'Hoàn thiện hồ sơ', en: 'Complete your profile'),
          onTap: widget.onOpenProfileRequested,
        ),
      if (!_isLoadingJoinRequestSignals && shouldShowJoinRequestsTask)
        (
          icon: Icons.fact_check_outlined,
          title: _hasPendingJoinRequestsToReview
              ? l10n.pick(
                  vi: 'Xem yêu cầu gia nhập',
                  en: 'Review join requests',
                )
              : l10n.pick(
                  vi: 'Xem yêu cầu đã gửi',
                  en: 'View your submitted requests',
                ),
          onTap: widget.onOpenJoinRequestsRequested,
        ),
      if (widget.session.accessMode == AuthMemberAccessMode.unlinked)
        (
          icon: Icons.travel_explore_outlined,
          title: l10n.pick(vi: 'Tìm gia phả phù hợp', en: 'Find a genealogy'),
          onTap: widget.onOpenTreeRequested,
        ),
    ];

    final visibleTasks = tasks.take(layout.isMobile ? 3 : 4);

    return _DashboardSectionShell(
      padding: EdgeInsets.all(tokens.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.pick(vi: 'Cần xem', en: 'Up next'),
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
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
                      vertical: tokens.spaceSm + 4,
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
    this.emptyStateType,
  });

  final List<_NearbyRelative> items;
  final String message;
  final bool canRetry;
  final _NearbyRetryAction retryAction;
  final _NearbySettingsTarget? settingsTarget;
  final _NearbyEmptyStateType? emptyStateType;

  bool get hasItems => items.isNotEmpty;
}

enum _NearbyRetryAction { reload, requestPermission }

enum _NearbySettingsTarget { appPermission, locationService }

enum _NearbyEmptyStateType {
  joinGenealogy,
  enableLocationService,
  requestLocationPermission,
  openAppPermission,
  locateCurrentUser,
  noSharedMembers,
  loadFailed,
}

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
        emptyStateType: _NearbyEmptyStateType.joinGenealogy,
        message: l10n.pick(
          vi: 'Tham gia gia phả để biết ai trong gia đình đang ở gần bạn.',
          en: 'Join a genealogy first to see nearby relatives.',
        ),
      );
    }
    final activeClanId = (widget.session.clanId ?? '').trim();
    if (activeClanId.isEmpty) {
      return _NearbyRelativeLoadResult(
        items: const [],
        canRetry: false,
        emptyStateType: _NearbyEmptyStateType.joinGenealogy,
        message: l10n.pick(
          vi: 'Tham gia gia phả để biết ai trong gia đình đang ở gần bạn.',
          en: 'Join a genealogy first to see nearby relatives.',
        ),
      );
    }

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return _NearbyRelativeLoadResult(
        items: const [],
        emptyStateType: _NearbyEmptyStateType.enableLocationService,
        message: l10n.pick(
          vi: 'Bật vị trí để xem người thân nào đang ở gần bạn nhất.',
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
        emptyStateType: _NearbyEmptyStateType.requestLocationPermission,
        message: l10n.pick(
          vi: 'Cho phép BeFam dùng vị trí để tính khoảng cách và gợi ý người thân ở gần bạn.',
          en: 'Allow location access to calculate distance and discover nearby relatives.',
        ),
      );
    }
    if (permission == LocationPermission.deniedForever) {
      return _NearbyRelativeLoadResult(
        items: const [],
        emptyStateType: _NearbyEmptyStateType.openAppPermission,
        message: l10n.pick(
          vi: 'Mở lại quyền vị trí trong cài đặt để BeFam tìm người thân quanh bạn.',
          en: 'Location access is permanently disabled. Open app settings to re-enable nearby relatives.',
        ),
        settingsTarget: _NearbySettingsTarget.appPermission,
      );
    }

    final currentPosition = await _resolveCurrentPosition();
    if (currentPosition == null) {
      return _NearbyRelativeLoadResult(
        items: const [],
        emptyStateType: _NearbyEmptyStateType.locateCurrentUser,
        message: l10n.pick(
          vi: 'BeFam chưa lấy được vị trí của bạn. Hãy thử lại sau ít phút.',
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
        emptyStateType: _NearbyEmptyStateType.loadFailed,
        message: l10n.pick(
          vi: 'Chưa tải được danh sách người thân quanh bạn lúc này. Hãy thử lại.',
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
        emptyStateType: _NearbyEmptyStateType.noSharedMembers,
        message: l10n.pick(
          vi: 'Chưa có người thân nào chia sẻ vị trí lúc này. Khi họ bật vị trí và mở BeFam, bạn sẽ thấy ngay tại đây.',
          en: 'No relatives are sharing live location yet. Ask them to allow location and open BeFam to appear nearby.',
        ),
      );
    }

    return _NearbyRelativeLoadResult(
      items: nearbyItems,
      message: l10n.pick(
        vi: 'Đã thấy ${nearbyItems.length} người thân đang ở quanh bạn.',
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
              emptyStateType: _NearbyEmptyStateType.loadFailed,
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
              emptyStateType:
                  result.emptyStateType ?? _NearbyEmptyStateType.loadFailed,
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
              .skip(1)
              .take(layout.isMobile ? 2 : 3)
              .toList(growable: false);
          final spotlight = result.items.first;
          final remainingCount = result.items.length - previewItems.length - 1;
          final nearbyCountLabel = result.items.length == 1
              ? l10n.pick(vi: '1 người gần bạn', en: '1 nearby')
              : l10n.pick(
                  vi: '${result.items.length} người gần bạn',
                  en: '${result.items.length} nearby',
                );
          final summaryText = result.items.length == 1
              ? l10n.pick(
                  vi: 'Có 1 người thân đang ở gần bạn lúc này.',
                  en: '1 relative is currently nearby.',
                )
              : l10n.pick(
                  vi: '${result.items.length} người thân đang ở gần bạn lúc này.',
                  en: '${result.items.length} relatives are currently nearby.',
                );
          final content = Column(
            key: ValueKey<String>(
              'nearby-${result.items.length}-${result.items.first.member.id}',
            ),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _NearbySectionHeader(
                title: l10n.pick(
                  vi: 'Người thân ở gần',
                  en: 'Relatives nearby',
                ),
                badgeLabel: nearbyCountLabel,
                isRefreshing: _isRefreshing,
                onRefresh: _reload,
              ),
              SizedBox(height: tokens.spaceMd),
              _NearbySpotlightCard(
                item: spotlight,
                totalCount: result.items.length,
                summaryText: summaryText,
                previewItems: previewItems,
                remainingCount: remainingCount,
                onOpenList: () => _openNearbySheet(result.items),
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

class _NearbySectionHeader extends StatelessWidget {
  const _NearbySectionHeader({
    required this.title,
    required this.onRefresh,
    this.badgeLabel,
    this.isRefreshing = false,
  });

  final String title;
  final String? badgeLabel;
  final bool isRefreshing;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final tokens = context.uiTokens;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (badgeLabel != null) ...[
          SizedBox(width: tokens.spaceSm),
          DecoratedBox(
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.78),
              borderRadius: BorderRadius.circular(tokens.radiusPill),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.48),
              ),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: tokens.spaceMd,
                vertical: tokens.spaceSm - 1,
              ),
              child: Text(
                badgeLabel!,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
        SizedBox(width: tokens.spaceSm),
        AppCompactIconButton(
          tooltip: context.l10n.pick(vi: 'Làm mới', en: 'Refresh'),
          onPressed: isRefreshing ? null : onRefresh,
          icon: isRefreshing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.radar_rounded),
        ),
      ],
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
    final theme = Theme.of(context);
    final tokens = context.uiTokens;

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
                  l10n.pick(
                    vi: 'Người thân ở gần bạn',
                    en: 'Relatives near you',
                  ),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: l10n.pick(
                      vi: 'Tìm theo tên hoặc quan hệ',
                      en: 'Search by name or relationship',
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
                          vi: 'Không có người thân phù hợp.',
                          en: 'No matching relatives.',
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
                      return Padding(
                        padding: EdgeInsets.only(bottom: tokens.spaceSm),
                        child: Material(
                          color: Colors.white.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(
                            tokens.radiusMd + 2,
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(tokens.spaceMd),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor:
                                      theme.colorScheme.primaryContainer,
                                  foregroundColor:
                                      theme.colorScheme.onPrimaryContainer,
                                  child: const Icon(
                                    Icons.people_alt_outlined,
                                    size: 18,
                                  ),
                                ),
                                SizedBox(width: tokens.spaceMd),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.member.displayName,
                                        style: theme.textTheme.titleSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w800,
                                            ),
                                      ),
                                      if (item.relationHint.trim().isNotEmpty)
                                        Padding(
                                          padding: EdgeInsets.only(
                                            top: tokens.spaceXs,
                                          ),
                                          child: Text(
                                            item.relationHint,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                                  color: theme
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                                ),
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
                                      label: _formatDistanceLabel(
                                        item.distanceKm,
                                      ),
                                      icon: Icons.near_me_rounded,
                                      backgroundColor: theme.colorScheme.primary
                                          .withValues(alpha: 0.10),
                                    ),
                                    if ((item.member.phoneE164 ?? '')
                                        .trim()
                                        .isNotEmpty)
                                      Padding(
                                        padding: EdgeInsets.only(
                                          top: tokens.spaceSm,
                                        ),
                                        child: DecoratedBox(
                                          decoration: BoxDecoration(
                                            color: theme
                                                .colorScheme
                                                .secondaryContainer
                                                .withValues(alpha: 0.82),
                                            shape: BoxShape.circle,
                                          ),
                                          child: MemberPhoneActionIconButton(
                                            phoneNumber:
                                                item.member.phoneE164 ?? '',
                                            contactName:
                                                item.member.displayName,
                                            iconSize: 18,
                                            constraints: const BoxConstraints(
                                              minWidth: 38,
                                              minHeight: 38,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
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
    required this.emptyStateType,
    required this.message,
    required this.canRetry,
    required this.retryAction,
    required this.onRetry,
    required this.onRadarScan,
    this.settingsTarget,
    this.onOpenSettings,
  });

  final _NearbyEmptyStateType emptyStateType;
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
    final colorScheme = theme.colorScheme;
    final leadLabel = switch (emptyStateType) {
      _NearbyEmptyStateType.joinGenealogy => l10n.pick(
        vi: 'Kết nối gần hơn',
        en: 'Stay close',
      ),
      _NearbyEmptyStateType.enableLocationService ||
      _NearbyEmptyStateType.requestLocationPermission ||
      _NearbyEmptyStateType.openAppPermission => l10n.pick(
        vi: 'Chỉ khi bạn cho phép',
        en: 'Only with permission',
      ),
      _NearbyEmptyStateType.locateCurrentUser => l10n.pick(
        vi: 'Đang chờ vị trí',
        en: 'Waiting for location',
      ),
      _NearbyEmptyStateType.noSharedMembers => l10n.pick(
        vi: 'Sẽ hiện ở đây',
        en: 'Will appear here',
      ),
      _NearbyEmptyStateType.loadFailed => l10n.pick(
        vi: 'Thử lại sau',
        en: 'Try again later',
      ),
    };
    final supportLabels = switch (emptyStateType) {
      _NearbyEmptyStateType.joinGenealogy => <String>[
        l10n.pick(vi: 'Chỉ người trong gia đình', en: 'Family only'),
      ],
      _NearbyEmptyStateType.enableLocationService ||
      _NearbyEmptyStateType.requestLocationPermission ||
      _NearbyEmptyStateType.openAppPermission => <String>[
        l10n.pick(vi: 'Dùng để tính khoảng cách', en: 'Used for distance only'),
        l10n.pick(vi: 'Không chia sẻ công khai', en: 'Not public'),
      ],
      _NearbyEmptyStateType.locateCurrentUser ||
      _NearbyEmptyStateType.noSharedMembers ||
      _NearbyEmptyStateType.loadFailed => const <String>[],
    };
    final primaryLabel = switch (emptyStateType) {
      _NearbyEmptyStateType.enableLocationService => l10n.pick(
        vi: 'Bật vị trí',
        en: 'Turn on location',
      ),
      _NearbyEmptyStateType.requestLocationPermission => l10n.pick(
        vi: 'Cho phép vị trí',
        en: 'Allow location',
      ),
      _NearbyEmptyStateType.openAppPermission => l10n.pick(
        vi: 'Mở cài đặt vị trí',
        en: 'Open location settings',
      ),
      _NearbyEmptyStateType.locateCurrentUser ||
      _NearbyEmptyStateType.noSharedMembers ||
      _NearbyEmptyStateType.loadFailed => l10n.pick(
        vi: 'Làm mới',
        en: 'Refresh',
      ),
      _NearbyEmptyStateType.joinGenealogy => null,
    };
    final primaryAction = switch (emptyStateType) {
      _NearbyEmptyStateType.enableLocationService =>
        settingsTarget != null && onOpenSettings != null
            ? () => unawaited(onOpenSettings!(settingsTarget!))
            : onRetry,
      _NearbyEmptyStateType.requestLocationPermission => onRetry,
      _NearbyEmptyStateType.openAppPermission =>
        settingsTarget != null && onOpenSettings != null
            ? () => unawaited(onOpenSettings!(settingsTarget!))
            : onRetry,
      _NearbyEmptyStateType.locateCurrentUser ||
      _NearbyEmptyStateType.noSharedMembers ||
      _NearbyEmptyStateType.loadFailed => canRetry ? onRetry : null,
      _NearbyEmptyStateType.joinGenealogy => null,
    };
    final heroTitle = switch (emptyStateType) {
      _NearbyEmptyStateType.joinGenealogy => l10n.pick(
        vi: 'Tham gia gia phả để xem người thân ở gần',
        en: 'Join a genealogy to see which relatives are near you',
      ),
      _NearbyEmptyStateType.enableLocationService => l10n.pick(
        vi: 'Bật vị trí để dùng tính năng này',
        en: 'Turn on location to unlock this feature',
      ),
      _NearbyEmptyStateType.requestLocationPermission => l10n.pick(
        vi: 'Cho phép vị trí để tìm người thân ở gần',
        en: 'Allow location to see nearby relatives',
      ),
      _NearbyEmptyStateType.openAppPermission => l10n.pick(
        vi: 'Mở lại quyền vị trí cho BeFam',
        en: 'Re-enable location access for BeFam',
      ),
      _NearbyEmptyStateType.locateCurrentUser => l10n.pick(
        vi: 'BeFam chưa lấy được vị trí của bạn',
        en: 'BeFam needs your location to calculate distance',
      ),
      _NearbyEmptyStateType.noSharedMembers => l10n.pick(
        vi: 'Chưa có người thân nào chia sẻ vị trí',
        en: 'When relatives share location, they will appear here',
      ),
      _NearbyEmptyStateType.loadFailed => l10n.pick(
        vi: 'Tạm thời chưa tải được người thân quanh bạn',
        en: 'Nearby relatives are temporarily unavailable',
      ),
    };
    final heroDescription = switch (emptyStateType) {
      _NearbyEmptyStateType.joinGenealogy => l10n.pick(
        vi: 'Khi tham gia gia phả, bạn sẽ thấy ai trong gia đình đang ở gần.',
        en: 'This feature helps you see which relatives are nearby so you can call or meet up faster.',
      ),
      _NearbyEmptyStateType.enableLocationService ||
      _NearbyEmptyStateType.requestLocationPermission ||
      _NearbyEmptyStateType.openAppPermission => l10n.pick(
        vi: 'BeFam chỉ dùng vị trí để tính khoảng cách và gợi ý người thân đang ở gần bạn.',
        en: 'BeFam only uses location to calculate distance and suggest relatives near you.',
      ),
      _NearbyEmptyStateType.locateCurrentUser ||
      _NearbyEmptyStateType.noSharedMembers ||
      _NearbyEmptyStateType.loadFailed => message,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _NearbySectionHeader(
          title: l10n.pick(vi: 'Người thân ở gần', en: 'Relatives nearby'),
          onRefresh: onRadarScan,
        ),
        SizedBox(height: tokens.spaceMd),
        _DashboardSectionShell(
          padding: EdgeInsets.all(tokens.spaceLg),
          gradient: LinearGradient(
            colors: [
              Colors.white.withValues(alpha: 0.96),
              colorScheme.primaryContainer.withValues(alpha: 0.48),
              colorScheme.secondaryContainer.withValues(alpha: 0.34),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          showAccentOrbs: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _DashboardMetaChip(
                          label: leadLabel,
                          icon: Icons.favorite_outline_rounded,
                          backgroundColor: colorScheme.secondaryContainer
                              .withValues(alpha: 0.72),
                          foregroundColor: colorScheme.onSecondaryContainer,
                        ),
                        SizedBox(height: tokens.spaceSm),
                        Text(
                          heroTitle,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            height: 1.15,
                          ),
                        ),
                        SizedBox(height: tokens.spaceSm),
                        Text(
                          heroDescription,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        if (supportLabels.isNotEmpty) ...[
                          SizedBox(height: tokens.spaceMd),
                          Wrap(
                            spacing: tokens.spaceSm,
                            runSpacing: tokens.spaceSm,
                            children: [
                              for (final label in supportLabels)
                                _DashboardMetaChip(
                                  label: label,
                                  backgroundColor: Colors.white.withValues(
                                    alpha: 0.72,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(width: tokens.spaceMd),
                  const _NearbyRadarGlyph(size: 76),
                ],
              ),
              SizedBox(height: tokens.spaceMd),
              if (primaryLabel != null && primaryAction != null)
                FilledButton.icon(
                  onPressed: primaryAction,
                  icon: Icon(
                    emptyStateType ==
                            _NearbyEmptyStateType.requestLocationPermission
                        ? Icons.my_location_outlined
                        : emptyStateType ==
                                  _NearbyEmptyStateType.enableLocationService ||
                              emptyStateType ==
                                  _NearbyEmptyStateType.openAppPermission
                        ? Icons.open_in_new
                        : Icons.refresh,
                  ),
                  label: Text(primaryLabel),
                ),
              if (settingsTarget != null &&
                  onOpenSettings != null &&
                  emptyStateType ==
                      _NearbyEmptyStateType.requestLocationPermission) ...[
                SizedBox(height: tokens.spaceSm),
                AppCompactTextButton(
                  onPressed: () => unawaited(onOpenSettings!(settingsTarget!)),
                  child: Text(
                    l10n.pick(
                      vi: 'Mở cài đặt vị trí',
                      en: 'Open location settings',
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _NearbySpotlightCard extends StatelessWidget {
  const _NearbySpotlightCard({
    required this.item,
    required this.totalCount,
    required this.summaryText,
    required this.previewItems,
    required this.remainingCount,
    required this.onOpenList,
  });

  final _NearbyRelative item;
  final int totalCount;
  final String summaryText;
  final List<_NearbyRelative> previewItems;
  final int remainingCount;
  final VoidCallback onOpenList;

  @override
  Widget build(BuildContext context) {
    final tokens = context.uiTokens;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasPhone = (item.member.phoneE164 ?? '').trim().isNotEmpty;
    return _DashboardSectionShell(
      padding: EdgeInsets.all(tokens.spaceLg),
      gradient: LinearGradient(
        colors: [
          Colors.white.withValues(alpha: 0.96),
          colorScheme.primaryContainer.withValues(alpha: 0.50),
          colorScheme.secondaryContainer.withValues(alpha: 0.32),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      showAccentOrbs: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DashboardMetaChip(
                      label: context.l10n.pick(
                        vi: 'Ở gần nhất lúc này',
                        en: 'Closest right now',
                      ),
                      icon: Icons.near_me_rounded,
                      backgroundColor: colorScheme.secondaryContainer
                          .withValues(alpha: 0.72),
                      foregroundColor: colorScheme.onSecondaryContainer,
                    ),
                    SizedBox(height: tokens.spaceSm),
                    Text(
                      summaryText,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: tokens.spaceMd),
              const _NearbyRadarGlyph(size: 68),
            ],
          ),
          SizedBox(height: tokens.spaceMd),
          Material(
            color: Colors.white.withValues(alpha: 0.80),
            borderRadius: BorderRadius.circular(tokens.radiusMd + 4),
            child: Padding(
              padding: EdgeInsets.all(tokens.spaceMd),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    foregroundColor: theme.colorScheme.onPrimaryContainer,
                    child: const Icon(Icons.person_pin_circle_outlined),
                  ),
                  SizedBox(width: tokens.spaceMd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.member.displayName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: tokens.spaceXs),
                        Text(
                          item.relationHint,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: tokens.spaceMd),
                  _DashboardMetaChip(
                    label: _formatDistanceLabel(item.distanceKm),
                    icon: Icons.near_me_rounded,
                    backgroundColor: colorScheme.primary.withValues(
                      alpha: 0.10,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: tokens.spaceMd),
          Wrap(
            spacing: tokens.spaceSm,
            runSpacing: tokens.spaceSm,
            children: [
              _DashboardMetaChip(
                label: context.l10n.pick(
                  vi: '$totalCount người đang chia sẻ',
                  en: '$totalCount sharing now',
                ),
                icon: Icons.radar_outlined,
                backgroundColor: Colors.white.withValues(alpha: 0.72),
              ),
              if (previewItems.isNotEmpty)
                _DashboardMetaChip(
                  label: context.l10n.pick(
                    vi: '${previewItems.length} gợi ý nhanh',
                    en: '${previewItems.length} quick picks',
                  ),
                  icon: Icons.people_outline_rounded,
                  backgroundColor: Colors.white.withValues(alpha: 0.72),
                ),
            ],
          ),
          if (previewItems.isNotEmpty || remainingCount > 0) ...[
            SizedBox(height: tokens.spaceMd),
            Wrap(
              spacing: tokens.spaceSm,
              runSpacing: tokens.spaceSm,
              children: [
                for (final preview in previewItems)
                  _NearbyRelativeMiniCard(item: preview),
                if (remainingCount > 0)
                  _DashboardMetaChip(
                    label: context.l10n.pick(
                      vi: '+$remainingCount người nữa',
                      en: '+$remainingCount more',
                    ),
                    icon: Icons.add_rounded,
                    backgroundColor: Colors.white.withValues(alpha: 0.72),
                  ),
              ],
            ),
          ],
          SizedBox(height: tokens.spaceMd),
          Row(
            children: [
              if (hasPhone) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      unawaited(
                        showMemberPhoneActionSheet(
                          context,
                          phoneNumber: item.member.phoneE164 ?? '',
                          contactName: item.member.displayName,
                        ),
                      );
                    },
                    icon: const Icon(Icons.phone_outlined),
                    label: Text(
                      context.l10n.pick(vi: 'Liên hệ', en: 'Contact'),
                    ),
                  ),
                ),
                SizedBox(width: tokens.spaceSm),
              ],
              Expanded(
                child: FilledButton.icon(
                  onPressed: onOpenList,
                  icon: const Icon(Icons.radar_outlined),
                  label: Text(
                    context.l10n.pick(vi: 'Xem quanh bạn', en: 'View nearby'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NearbyRelativeMiniCard extends StatelessWidget {
  const _NearbyRelativeMiniCard({required this.item});

  final _NearbyRelative item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.uiTokens;
    return Material(
      color: Colors.white.withValues(alpha: 0.76),
      borderRadius: BorderRadius.circular(tokens.radiusPill),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: tokens.spaceMd,
          vertical: tokens.spaceSm,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.person_outline_rounded,
                size: 15,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            SizedBox(width: tokens.spaceSm),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 112),
              child: Text(
                item.member.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            SizedBox(width: tokens.spaceSm),
            Text(
              _formatDistanceLabel(item.distanceKm),
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NearbyRadarGlyph extends StatelessWidget {
  const _NearbyRadarGlyph({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(size * 0.32),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.96),
                  colorScheme.primaryContainer.withValues(alpha: 0.92),
                  colorScheme.secondaryContainer.withValues(alpha: 0.74),
                ],
              ),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.48),
              ),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.shadow.withValues(alpha: 0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
          ),
          Positioned(
            top: size * 0.16,
            right: size * 0.14,
            child: Container(
              width: size * 0.20,
              height: size * 0.20,
              decoration: BoxDecoration(
                color: colorScheme.secondary.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: size * 0.18,
            left: size * 0.16,
            child: Container(
              width: size * 0.16,
              height: size * 0.16,
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Container(
            width: size * 0.52,
            height: size * 0.52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.82),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.diversity_3_rounded,
              color: colorScheme.onPrimaryContainer,
              size: size * 0.24,
            ),
          ),
          Positioned(
            bottom: size * 0.14,
            right: size * 0.14,
            child: Container(
              width: size * 0.24,
              height: size * 0.24,
              decoration: BoxDecoration(
                color: colorScheme.primary,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.near_me_rounded,
                color: colorScheme.onPrimary,
                size: size * 0.11,
              ),
            ),
          ),
        ],
      ),
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
