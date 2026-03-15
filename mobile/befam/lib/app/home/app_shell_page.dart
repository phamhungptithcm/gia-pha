import 'dart:async';

import 'package:flutter/material.dart';

import '../../features/billing/presentation/billing_workspace_page.dart';
import '../../features/billing/services/billing_repository.dart';
import '../../features/clan/presentation/clan_detail_page.dart';
import '../../features/clan/services/clan_repository.dart';
import '../../features/calendar/presentation/dual_calendar_workspace_page.dart';
import '../../features/events/models/event_record.dart';
import '../../features/events/services/event_repository.dart';
import '../../features/funds/presentation/fund_workspace_page.dart';
import '../../features/funds/services/fund_repository.dart';
import '../../features/genealogy/presentation/genealogy_workspace_page.dart';
import '../../features/genealogy/services/genealogy_read_repository.dart';
import '../../features/discovery/presentation/genealogy_discovery_page.dart';
import '../../features/discovery/services/genealogy_discovery_repository.dart';
import '../../features/member/presentation/member_workspace_page.dart';
import '../../features/member/services/member_repository.dart';
import '../../features/notifications/presentation/notification_target_page.dart';
import '../../features/notifications/services/push_notification_service.dart';
import '../../features/profile/presentation/profile_workspace_page.dart';
import '../../features/scholarship/presentation/scholarship_workspace_page.dart';
import '../../features/scholarship/services/scholarship_repository.dart';
import '../../l10n/l10n.dart';
import '../../features/auth/models/auth_entry_method.dart';
import '../../features/auth/models/auth_member_access_mode.dart';
import '../../features/auth/models/auth_session.dart';
import '../../features/auth/services/phone_number_formatter.dart';
import '../../core/services/app_locale_controller.dart';
import '../../core/services/governance_role_matrix.dart';
import '../bootstrap/firebase_setup_status.dart';
import '../models/app_shortcut.dart';
import 'app_shortcuts.dart';

class AppShellPage extends StatefulWidget {
  const AppShellPage({
    super.key,
    required this.status,
    required this.session,
    required this.clanRepository,
    required this.memberRepository,
    this.fundRepository,
    this.genealogyRepository,
    this.billingRepository,
    this.pushNotificationService,
    this.localeController,
    this.onLogoutRequested,
  });

  final FirebaseSetupStatus status;
  final AuthSession session;
  final ClanRepository clanRepository;
  final MemberRepository memberRepository;
  final FundRepository? fundRepository;
  final GenealogyReadRepository? genealogyRepository;
  final BillingRepository? billingRepository;
  final PushNotificationService? pushNotificationService;
  final AppLocaleController? localeController;
  final Future<void> Function()? onLogoutRequested;

  @override
  State<AppShellPage> createState() => _AppShellPageState();
}

class _AppShellPageState extends State<AppShellPage> {
  int _selectedIndex = 0;
  final Set<int> _visitedDestinationIndexes = <int>{0};
  late final GenealogyReadRepository _genealogyRepository;
  late final FundRepository _fundRepository;
  late final BillingRepository _billingRepository;
  late final PushNotificationService _pushNotificationService;
  String? _lastOpenedNotificationMessageId;
  bool _showAdBanner = true;
  bool _isResolvingBillingEntitlement = false;
  bool _dismissAdBannerForSession = false;
  bool get _hasClanContext => (widget.session.clanId ?? '').trim().isNotEmpty;

  static const List<_ShellDestination> _destinations = [
    _ShellDestination(
      id: 'home',
      icon: Icons.space_dashboard_outlined,
      selectedIcon: Icons.space_dashboard,
    ),
    _ShellDestination(
      id: 'tree',
      icon: Icons.account_tree_outlined,
      selectedIcon: Icons.account_tree,
    ),
    _ShellDestination(
      id: 'events',
      icon: Icons.event_outlined,
      selectedIcon: Icons.event,
    ),
    _ShellDestination(
      id: 'billing',
      icon: Icons.workspace_premium_outlined,
      selectedIcon: Icons.workspace_premium,
    ),
    _ShellDestination(
      id: 'profile',
      icon: Icons.person_outline,
      selectedIcon: Icons.person,
    ),
  ];
  static const List<_ShellDestination> _unlinkedDestinations = [
    _ShellDestination(
      id: 'home',
      icon: Icons.space_dashboard_outlined,
      selectedIcon: Icons.space_dashboard,
    ),
    _ShellDestination(
      id: 'tree',
      icon: Icons.travel_explore_outlined,
      selectedIcon: Icons.travel_explore,
    ),
    _ShellDestination(
      id: 'events',
      icon: Icons.event_outlined,
      selectedIcon: Icons.event,
    ),
    _ShellDestination(
      id: 'billing',
      icon: Icons.workspace_premium_outlined,
      selectedIcon: Icons.workspace_premium,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _genealogyRepository =
        widget.genealogyRepository ??
        createDefaultGenealogyReadRepository(session: widget.session);
    _fundRepository =
        widget.fundRepository ??
        createDefaultFundRepository(session: widget.session);
    _billingRepository =
        widget.billingRepository ??
        createDefaultBillingRepository(session: widget.session);
    _pushNotificationService =
        widget.pushNotificationService ??
        createDefaultPushNotificationService(session: widget.session);
    unawaited(
      _pushNotificationService.start(
        session: widget.session,
        onDeepLink: _handleNotificationDeepLink,
      ),
    );
    unawaited(_refreshBillingEntitlement());
  }

  @override
  void didUpdateWidget(covariant AppShellPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session != widget.session) {
      unawaited(
        _pushNotificationService.start(
          session: widget.session,
          onDeepLink: _handleNotificationDeepLink,
        ),
      );
      _dismissAdBannerForSession = false;
      unawaited(_refreshBillingEntitlement());
    }
  }

  @override
  void dispose() {
    unawaited(_pushNotificationService.stop());
    super.dispose();
  }

  void _handleNotificationDeepLink(NotificationDeepLink deepLink) {
    if (!mounted) {
      return;
    }

    final shouldOpenTargetPage =
        deepLink.openedFromSystemNotification &&
        (deepLink.targetType == NotificationTargetType.event ||
            deepLink.targetType == NotificationTargetType.scholarship);
    if (shouldOpenTargetPage) {
      setState(() {
        _selectedIndex = 2;
        _visitedDestinationIndexes.add(2);
      });
      _openNotificationTargetPage(
        targetType: deepLink.targetType,
        referenceId: deepLink.referenceId,
        sourceTitle: deepLink.title,
        sourceBody: deepLink.body,
        messageId: deepLink.messageId,
      );
    }

    final defaultMessage = _defaultNotificationMessage(
      context,
      targetType: deepLink.targetType,
      origin: deepLink.origin,
    );
    final title = deepLink.title?.trim();
    final body = deepLink.body?.trim();
    final snackBarMessage = [
      if (title != null && title.isNotEmpty) title else defaultMessage,
      if (body != null && body.isNotEmpty) body,
    ].join('\n');

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(snackBarMessage)));
  }

  void _openNotificationTargetPage({
    required NotificationTargetType targetType,
    required String? referenceId,
    required String? sourceTitle,
    required String? sourceBody,
    String? messageId,
  }) {
    if (targetType == NotificationTargetType.unknown) {
      return;
    }
    if (!_shouldOpenNotificationMessage(messageId)) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) {
            return NotificationTargetPage(
              targetType: targetType,
              referenceId: referenceId,
              sourceTitle: sourceTitle,
              sourceBody: sourceBody,
            );
          },
        ),
      );
    });
  }

  bool _shouldOpenNotificationMessage(String? messageId) {
    final normalizedId = messageId?.trim() ?? '';
    if (normalizedId.isEmpty) {
      return true;
    }
    if (_lastOpenedNotificationMessageId == normalizedId) {
      return false;
    }
    _lastOpenedNotificationMessageId = normalizedId;
    return true;
  }

  String _defaultNotificationMessage(
    BuildContext context, {
    required NotificationTargetType targetType,
    required NotificationMessageOrigin origin,
  }) {
    final l10n = context.l10n;
    final openedFromTray = origin != NotificationMessageOrigin.foreground;

    if (openedFromTray) {
      return switch (targetType) {
        NotificationTargetType.event => l10n.notificationOpenedEvent,
        NotificationTargetType.scholarship =>
          l10n.notificationOpenedScholarship,
        NotificationTargetType.unknown => l10n.notificationOpenedGeneral,
      };
    }

    return switch (targetType) {
      NotificationTargetType.event => l10n.notificationForegroundEvent,
      NotificationTargetType.scholarship =>
        l10n.notificationForegroundScholarship,
      NotificationTargetType.unknown => l10n.notificationForegroundGeneral,
    };
  }

  Future<void> _refreshBillingEntitlement() async {
    if (_isResolvingBillingEntitlement) {
      return;
    }
    if (!_hasBillingContext(widget.session)) {
      if (mounted) {
        setState(() {
          _showAdBanner = true;
        });
      }
      return;
    }

    _isResolvingBillingEntitlement = true;
    try {
      final entitlement = await _billingRepository.resolveEntitlement(
        session: widget.session,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _showAdBanner = entitlement.showAds;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _showAdBanner = true;
      });
    } finally {
      _isResolvingBillingEntitlement = false;
    }
  }

  bool _hasBillingContext(AuthSession session) {
    return (session.clanId ?? '').trim().isNotEmpty;
  }

  Future<void> _confirmLogoutRequest() async {
    if (widget.onLogoutRequested == null) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final l10n = context.l10n;
        return AlertDialog(
          title: Text(l10n.shellLogout),
          content: Text(l10n.profileLogoutDialogDescription),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.profileCancelAction),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.shellLogout),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      await widget.onLogoutRequested?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final destinations = _hasClanContext
        ? _destinations
        : _unlinkedDestinations;
    if (_selectedIndex >= destinations.length) {
      _selectedIndex = 0;
    }
    final destination = destinations[_selectedIndex];
    final sessionTooltip = l10n.authEntryMethodSummary(
      widget.session.loginMethod,
    );
    final readinessTooltip = widget.status.isReady
        ? l10n.shellReadinessReady
        : widget.status.errorMessage?.trim().isNotEmpty == true
        ? widget.status.errorMessage!
        : l10n.shellReadinessPending;
    final pages = [
      _HomeDashboard(
        status: widget.status,
        session: widget.session,
        clanRepository: widget.clanRepository,
        memberRepository: widget.memberRepository,
        fundRepository: _fundRepository,
        onOpenTreeRequested: () {
          setState(() {
            _selectedIndex = 1;
            _visitedDestinationIndexes.add(1);
          });
        },
        onOpenEventsRequested: () {
          setState(() {
            _selectedIndex = 2;
            _visitedDestinationIndexes.add(2);
          });
        },
        onOpenProfileRequested: () {
          if (!_hasClanContext) {
            return;
          }
          setState(() {
            _selectedIndex = 4;
            _visitedDestinationIndexes.add(4);
          });
        },
      ),
      if (_visitedDestinationIndexes.contains(1))
        _hasClanContext
            ? GenealogyWorkspacePage(
                session: widget.session,
                repository: _genealogyRepository,
              )
            : GenealogyDiscoveryPage(
                session: widget.session,
                repository: createDefaultGenealogyDiscoveryRepository(
                  session: widget.session,
                ),
              )
      else
        const SizedBox.shrink(),
      if (_visitedDestinationIndexes.contains(2))
        const DualCalendarWorkspacePage()
      else
        const SizedBox.shrink(),
      if (_visitedDestinationIndexes.contains(3))
        _hasClanContext
            ? BillingWorkspacePage(
                session: widget.session,
                repository: _billingRepository,
                embeddedInShell: true,
              )
            : _UnlinkedBillingWorkspace(
                onOpenDiscovery: () {
                  setState(() {
                    _selectedIndex = 1;
                    _visitedDestinationIndexes.add(1);
                  });
                },
                onCreateClanWorkspace: () {
                  _openClanWorkspaceFromBilling();
                },
              )
      else
        const SizedBox.shrink(),
      if (_hasClanContext && _visitedDestinationIndexes.contains(4))
        ProfileWorkspacePage(
          session: widget.session,
          memberRepository: widget.memberRepository,
          billingRepository: _billingRepository,
          onBillingStateChanged: () {
            unawaited(_refreshBillingEntitlement());
          },
          localeController: widget.localeController,
          onLogoutRequested: widget.onLogoutRequested,
        )
      else
        const SizedBox.shrink(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.shellDestinationTitle(destination.id)),
        actions: [
          if (_selectedIndex == 0)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Tooltip(
                message: sessionTooltip,
                child: Icon(
                  widget.session.loginMethod == AuthEntryMethod.phone
                      ? Icons.phone_iphone
                      : Icons.child_care,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Tooltip(
              message: readinessTooltip,
              child: Icon(
                widget.status.isReady ? Icons.cloud_done : Icons.cloud_off,
              ),
            ),
          ),
          if (widget.onLogoutRequested != null)
            PopupMenuButton<String>(
              tooltip: l10n.shellMoreActions,
              onSelected: (value) async {
                if (value == 'logout') {
                  await _confirmLogoutRequest();
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem<String>(
                  value: 'logout',
                  child: Text(l10n.shellLogout),
                ),
              ],
            ),
        ],
      ),
      body: SafeArea(
        child: IndexedStack(index: _selectedIndex, children: pages),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_showAdBanner && !_dismissAdBannerForSession)
            _SponsoredAdBanner(
              onClose: () {
                setState(() {
                  _dismissAdBannerForSession = true;
                });
              },
            ),
          NavigationBar(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) {
              setState(() {
                _selectedIndex = index;
                _visitedDestinationIndexes.add(index);
              });
            },
            destinations: [
              for (final destination in destinations)
                NavigationDestination(
                  icon: Icon(destination.icon),
                  selectedIcon: Icon(destination.selectedIcon),
                  label: l10n.shellDestinationLabel(destination.id),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _openClanWorkspaceFromBilling() {
    if (!_hasClanContext &&
        !GovernanceRoleMatrix.canBootstrapClan(widget.session)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.pick(
              vi: 'Tài khoản này chưa có quyền khởi tạo gia phả mới. Vui lòng liên hệ quản trị.',
              en: 'This account is not allowed to bootstrap a new clan workspace. Please contact an administrator.',
            ),
          ),
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) {
          return ClanDetailPage(
            session: widget.session,
            repository: widget.clanRepository,
          );
        },
      ),
    );
  }
}

class _UnlinkedBillingWorkspace extends StatelessWidget {
  const _UnlinkedBillingWorkspace({
    required this.onOpenDiscovery,
    required this.onCreateClanWorkspace,
  });

  final VoidCallback onOpenDiscovery;
  final VoidCallback onCreateClanWorkspace;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.workspace_premium_outlined,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l10n.pick(
                          vi: 'Gói dịch vụ & thanh toán',
                          en: 'Subscription & billing',
                        ),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  l10n.pick(
                    vi: 'Bạn chưa liên kết vào gia phả nào. Hãy tìm gia phả để tham gia hoặc tạo gia phả mới để sử dụng gói dịch vụ.',
                    en: 'You are not linked to a clan yet. Discover a genealogy to join, or create a new clan workspace before using billing.',
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: onOpenDiscovery,
                  icon: const Icon(Icons.travel_explore_outlined),
                  label: Text(
                    l10n.pick(vi: 'Tìm gia phả', en: 'Discover genealogies'),
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: onCreateClanWorkspace,
                  icon: const Icon(Icons.apartment_outlined),
                  label: Text(
                    l10n.pick(
                      vi: 'Tạo gia phả mới',
                      en: 'Create clan workspace',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SponsoredAdBanner extends StatelessWidget {
  const _SponsoredAdBanner({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.tertiaryContainer.withValues(alpha: 0.88),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            Icon(
              Icons.campaign_outlined,
              color: colorScheme.onTertiaryContainer,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                l10n.pick(
                  vi: 'Quảng cáo nhẹ đang hiển thị trong gói Free/Base. Nâng cấp Plus/Pro để tắt hoàn toàn quảng cáo.',
                  en: 'Light ads are active on Free/Base plans. Upgrade to Plus/Pro for a fully ad-free experience.',
                ),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onTertiaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            IconButton(
              tooltip: l10n.pick(vi: 'Đóng', en: 'Close'),
              onPressed: onClose,
              icon: const Icon(Icons.close),
              color: colorScheme.onTertiaryContainer,
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeDashboard extends StatelessWidget {
  const _HomeDashboard({
    required this.status,
    required this.session,
    required this.clanRepository,
    required this.memberRepository,
    required this.fundRepository,
    required this.onOpenTreeRequested,
    required this.onOpenProfileRequested,
    required this.onOpenEventsRequested,
  });

  final FirebaseSetupStatus status;
  final AuthSession session;
  final ClanRepository clanRepository;
  final MemberRepository memberRepository;
  final FundRepository fundRepository;
  final VoidCallback onOpenTreeRequested;
  final VoidCallback onOpenProfileRequested;
  final VoidCallback onOpenEventsRequested;
  bool get _hasClanContext => (session.clanId ?? '').trim().isNotEmpty;

  List<AppShortcut> get _availableShortcuts {
    if (_hasClanContext) {
      return bootstrapShortcuts;
    }
    return bootstrapShortcuts
        .where(
          (shortcut) =>
              shortcut.id == 'tree' ||
              shortcut.id == 'clan' ||
              shortcut.id == 'events',
        )
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = context.l10n;
    final size = MediaQuery.sizeOf(context);
    final crossAxisCount = switch (size.width) {
      > 1000 => 3,
      > 640 => 2,
      _ => 1,
    };

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [colorScheme.primary, colorScheme.primaryContainer],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                status.isReady
                    ? l10n.shellWelcomeBack(session.displayName)
                    : l10n.shellBootstrapNeedsCloud,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: colorScheme.onPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                status.isReady
                    ? l10n.pick(
                        vi: 'Trang chủ đã sẵn sàng để bạn theo dõi gia phả, sự kiện và hồ sơ gia đình.',
                        en: 'Your home dashboard is ready to manage family tree, events, and member profiles.',
                      )
                    : l10n.shellCloudSetupNeeded,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onPrimary.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _UpcomingEventSection(
          session: session,
          onOpenEventsRequested: onOpenEventsRequested,
        ),
        const SizedBox(height: 24),
        _MemberAccessCard(session: session),
        const SizedBox(height: 24),
        Text(
          l10n.pick(vi: 'Truy cập nhanh', en: 'Quick access'),
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _availableShortcuts.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.24,
          ),
          itemBuilder: (context, index) {
            final shortcut = _availableShortcuts[index];
            return _ShortcutCard(
              shortcut: shortcut,
              onTap: _onShortcutTap(context, shortcut.id),
            );
          },
        ),
        const SizedBox(height: 24),
        Text(
          l10n.shellSignedInContext,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _FoundationRow(
                  label: l10n.shellFieldDisplayName,
                  value: session.displayName,
                ),
                _FoundationRow(
                  label: l10n.shellFieldLoginMethod,
                  value: l10n.authEntryMethodSummary(session.loginMethod),
                ),
                _FoundationRow(
                  label: l10n.shellFieldPhone,
                  value: _formatPhoneForDisplay(session.phoneE164),
                ),
                if (session.childIdentifier != null)
                  _FoundationRow(
                    label: l10n.shellFieldChildId,
                    value: session.childIdentifier!,
                  ),
                if (session.primaryRole != null)
                  _FoundationRow(
                    label: l10n.shellFieldPrimaryRole,
                    value: l10n.roleLabel(session.primaryRole),
                  ),
                _FoundationRow(
                  label: l10n.shellFieldAccessMode,
                  value: l10n.authMemberAccessModeLabel(session.accessMode),
                  isLast: status.errorMessage == null,
                ),
                if (status.errorMessage != null)
                  _FoundationRow(
                    label: l10n.shellFieldStartupNote,
                    value: status.errorMessage!,
                    isLast: true,
                  ),
              ],
            ),
          ),
        ),
      ],
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
        if (!_hasClanContext &&
            !GovernanceRoleMatrix.canBootstrapClan(session)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.l10n.pick(
                  vi: 'Tài khoản này chưa có quyền khởi tạo gia phả mới. Vui lòng liên hệ quản trị.',
                  en: 'This account is not allowed to bootstrap a new clan workspace. Please contact an administrator.',
                ),
              ),
            ),
          );
          return;
        }
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (context) {
              return ClanDetailPage(
                session: session,
                repository: clanRepository,
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
              );
            },
          ),
        );
      },
      _ => null,
    };
  }
}

class _ShortcutCard extends StatelessWidget {
  const _ShortcutCard({required this.shortcut, this.onTap});

  final AppShortcut shortcut;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = context.l10n;
    final statusColor = switch (shortcut.status) {
      AppShortcutStatus.live => colorScheme.primaryContainer,
      AppShortcutStatus.bootstrap => colorScheme.secondaryContainer,
      AppShortcutStatus.planned => colorScheme.surfaceContainerHighest,
    };

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: Key('shortcut-${shortcut.id}'),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: statusColor,
                foregroundColor: colorScheme.onSurface,
                child: Icon(_iconFor(shortcut.iconKey)),
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      l10n.shortcutTitle(shortcut.id),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _ShortcutStatusChip(status: shortcut.status),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                _productionShortcutDescription(context, shortcut.id),
                style: theme.textTheme.bodyMedium,
              ),
              const Spacer(),
            ],
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

    return Chip(
      label: Text(context.l10n.shortcutStatusLabel(status)),
      backgroundColor: background,
      visualDensity: VisualDensity.compact,
      side: BorderSide.none,
    );
  }
}

class _FoundationRow extends StatelessWidget {
  const _FoundationRow({
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
    final screenWidth = MediaQuery.sizeOf(context).width;
    final stackForAccessibility = screenWidth < 420;

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
      child: stackForAccessibility
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(value, style: theme.textTheme.bodyMedium),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 132,
                  child: Text(
                    label,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
              ],
            ),
    );
  }
}

String _formatPhoneForDisplay(String value) {
  try {
    final parsed = PhoneNumberFormatter.parse(value).e164;
    if (parsed.startsWith('+84') && parsed.length == 12) {
      return '+84 ${parsed.substring(3, 5)} ${parsed.substring(5, 8)} ${parsed.substring(8)}';
    }
    return parsed;
  } catch (_) {
    return value;
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

class _UpcomingEventSection extends StatefulWidget {
  const _UpcomingEventSection({
    required this.session,
    required this.onOpenEventsRequested,
  });

  final AuthSession session;
  final VoidCallback onOpenEventsRequested;

  @override
  State<_UpcomingEventSection> createState() => _UpcomingEventSectionState();
}

class _UpcomingEventSectionState extends State<_UpcomingEventSection> {
  late EventRepository _eventRepository;
  late Future<_UpcomingEventData?> _upcomingFuture;

  @override
  void initState() {
    super.initState();
    _eventRepository = createDefaultEventRepository(session: widget.session);
    _upcomingFuture = _loadUpcomingEvent();
  }

  @override
  void didUpdateWidget(covariant _UpcomingEventSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session != widget.session) {
      _eventRepository = createDefaultEventRepository(session: widget.session);
      _upcomingFuture = _loadUpcomingEvent();
    }
  }

  Future<_UpcomingEventData?> _loadUpcomingEvent() async {
    try {
      final snapshot = await _eventRepository.loadWorkspace(
        session: widget.session,
      );
      final nowUtc = DateTime.now().toUtc();
      final upcoming =
          snapshot.events
              .where((event) => !event.startsAt.isBefore(nowUtc))
              .toList(growable: false)
            ..sort((left, right) => left.startsAt.compareTo(right.startsAt));
      if (upcoming.isEmpty) {
        return null;
      }

      final event = upcoming.first;
      final branchName = event.branchId == null
          ? null
          : snapshot.branches
                .where((branch) => branch.id == event.branchId)
                .map((branch) => branch.name)
                .toList(growable: false)
                .firstOrNull;
      final hostHousehold = event.locationName.trim().isNotEmpty
          ? event.locationName.trim()
          : branchName;
      return _UpcomingEventData(event: event, hostHousehold: hostHousehold);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: FutureBuilder<_UpcomingEventData?>(
          future: _upcomingFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Row(
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    l10n.pick(
                      vi: 'Đang tải sự kiện sắp tới...',
                      en: 'Loading upcoming event...',
                    ),
                  ),
                ],
              );
            }

            final data = snapshot.data;
            if (data == null) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.pick(vi: 'Sự kiện gần tới', en: 'Upcoming event'),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.pick(
                      vi: 'Hiện chưa có sự kiện nào trong thời gian tới.',
                      en: 'There are no upcoming events at the moment.',
                    ),
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              );
            }

            final event = data.event;
            final hostLabel = data.hostHousehold?.trim().isNotEmpty == true
                ? data.hostHousehold!.trim()
                : l10n.pick(vi: 'Cả họ', en: 'Clan-wide');

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.event_outlined,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.pick(vi: 'Sự kiện gần tới', en: 'Upcoming event'),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: widget.onOpenEventsRequested,
                      child: Text(
                        l10n.pick(vi: 'Mở lịch', en: 'Open calendar'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  event.title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _formatDashboardDateTime(event.startsAt),
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.pick(
                    vi: 'Nhà/chi: $hostLabel',
                    en: 'Household/branch: $hostLabel',
                  ),
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _UpcomingEventData {
  const _UpcomingEventData({required this.event, required this.hostHousehold});

  final EventRecord event;
  final String? hostHousehold;
}

class _MemberAccessCard extends StatelessWidget {
  const _MemberAccessCard({required this.session});

  final AuthSession session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = context.l10n;

    final (title, description, icon, tone) = switch (session.accessMode) {
      AuthMemberAccessMode.claimed => (
        l10n.shellMemberAccessClaimedTitle,
        l10n.pick(
          vi: 'Tài khoản đã liên kết với hồ sơ thành viên của bạn trong gia phả.',
          en: 'Your account is linked to your member profile in the family tree.',
        ),
        Icons.verified_user_outlined,
        colorScheme.primaryContainer,
      ),
      AuthMemberAccessMode.child => (
        l10n.shellMemberAccessChildTitle,
        l10n.pick(
          vi: 'Bạn đang vào chế độ trẻ em thông qua xác thực của phụ huynh.',
          en: 'You are viewing child access mode through parent verification.',
        ),
        Icons.family_restroom_outlined,
        colorScheme.secondaryContainer,
      ),
      AuthMemberAccessMode.unlinked => (
        l10n.shellMemberAccessUnlinkedTitle,
        l10n.pick(
          vi: 'Tài khoản chưa liên kết vào gia phả nào. Bạn có thể khám phá gia phả, tạo gia phả mới (nếu đủ quyền), hoặc dùng lịch sự kiện.',
          en: 'This account is not linked to any clan yet. You can discover genealogies, create a clan workspace (if your role allows), or use events.',
        ),
        Icons.info_outline,
        colorScheme.surfaceContainerHighest,
      ),
    };

    return Card(
      color: tone,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 24),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(description, style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
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

extension _IterableFirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
