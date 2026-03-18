import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../features/billing/presentation/billing_workspace_page.dart';
import '../../features/billing/services/billing_repository.dart';
import '../../features/clan/presentation/clan_detail_page.dart';
import '../../features/clan/services/clan_repository.dart';
import '../../features/calendar/presentation/dual_calendar_workspace_page.dart';
import '../../features/events/models/event_record.dart';
import '../../features/events/presentation/event_workspace_page.dart';
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
import '../../features/auth/models/clan_context_option.dart';
import '../../features/auth/services/auth_session_store.dart';
import '../../features/auth/services/clan_context_service.dart';
import '../../core/services/app_locale_controller.dart';
import '../../core/services/governance_role_matrix.dart';
import '../../core/widgets/responsive_layout.dart';
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
  static const Duration _adBannerAutoHideDelay = Duration(seconds: 10);

  int _selectedIndex = 0;
  final Set<int> _visitedDestinationIndexes = <int>{0};
  late AuthSession _activeSession;
  late final GenealogyReadRepository _genealogyRepository;
  late final FundRepository _fundRepository;
  late final BillingRepository _billingRepository;
  late final PushNotificationService _pushNotificationService;
  late final ClanContextService _clanContextService;
  final AuthSessionStore _sessionStore = SharedPrefsAuthSessionStore();
  String? _lastOpenedNotificationMessageId;
  bool _showAdBanner = true;
  bool _isResolvingBillingEntitlement = false;
  bool _dismissAdBannerForSession = false;
  Timer? _adBannerAutoHideTimer;
  bool _isLoadingClanContexts = false;
  bool _isSwitchingClanContext = false;
  List<ClanContextOption> _clanContexts = const [];

  AuthSession get _session => _activeSession;

  bool get _hasClanContext => (_session.clanId ?? '').trim().isNotEmpty;

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
    _ShellDestination(
      id: 'profile',
      icon: Icons.person_outline,
      selectedIcon: Icons.person,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _activeSession = widget.session;
    _genealogyRepository =
        widget.genealogyRepository ??
        createDefaultGenealogyReadRepository(session: _session);
    _fundRepository =
        widget.fundRepository ?? createDefaultFundRepository(session: _session);
    _billingRepository =
        widget.billingRepository ??
        createDefaultBillingRepository(session: _session);
    _pushNotificationService =
        widget.pushNotificationService ??
        createDefaultPushNotificationService(session: _session);
    _clanContextService = createDefaultClanContextService(session: _session);
    unawaited(
      _pushNotificationService.start(
        session: _session,
        onDeepLink: _handleNotificationDeepLink,
      ),
    );
    unawaited(_loadClanContexts());
    unawaited(_refreshBillingEntitlement());
    _syncAdBannerAutoHideTimer();
  }

  @override
  void didUpdateWidget(covariant AppShellPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session != widget.session) {
      _activeSession = widget.session;
      unawaited(
        _pushNotificationService.start(
          session: _session,
          onDeepLink: _handleNotificationDeepLink,
        ),
      );
      unawaited(_loadClanContexts());
      _dismissAdBannerForSession = false;
      unawaited(_refreshBillingEntitlement());
      _syncAdBannerAutoHideTimer();
    }
  }

  @override
  void dispose() {
    _adBannerAutoHideTimer?.cancel();
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
      _syncAdBannerAutoHideTimer();
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

  bool get _isAdBannerVisible =>
      _showAdBanner && !_dismissAdBannerForSession && _selectedIndex != 3;

  void _syncAdBannerAutoHideTimer() {
    _adBannerAutoHideTimer?.cancel();
    if (!_isAdBannerVisible) {
      _adBannerAutoHideTimer = null;
      return;
    }
    _adBannerAutoHideTimer = Timer(_adBannerAutoHideDelay, () {
      if (!mounted || !_isAdBannerVisible) {
        return;
      }
      setState(() {
        _dismissAdBannerForSession = true;
      });
    });
  }

  Future<void> _refreshBillingEntitlement() async {
    if (_isResolvingBillingEntitlement) {
      return;
    }
    if (!_hasBillingContext(_session)) {
      if (mounted) {
        setState(() {
          _showAdBanner = true;
        });
        _syncAdBannerAutoHideTimer();
      }
      return;
    }

    _isResolvingBillingEntitlement = true;
    try {
      final entitlement = await _billingRepository.resolveEntitlement(
        session: _session,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _showAdBanner = entitlement.showAds;
      });
      _syncAdBannerAutoHideTimer();
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _showAdBanner = true;
      });
      _syncAdBannerAutoHideTimer();
    } finally {
      _isResolvingBillingEntitlement = false;
    }
  }

  bool _hasBillingContext(AuthSession session) {
    return (session.clanId ?? '').trim().isNotEmpty;
  }

  Future<void> _loadClanContexts() async {
    if (_isLoadingClanContexts || !_session.linkedAuthUid) {
      return;
    }
    _isLoadingClanContexts = true;
    try {
      final snapshot = await _clanContextService.loadContexts(
        session: _session,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _activeSession = snapshot.activeSession;
        _clanContexts = snapshot.contexts;
      });
      await _sessionStore.write(_activeSession);
      await _pushNotificationService.start(
        session: _session,
        onDeepLink: _handleNotificationDeepLink,
      );
      unawaited(_refreshBillingEntitlement());
    } catch (_) {
      // Keep the existing session context if callable is unavailable.
    } finally {
      _isLoadingClanContexts = false;
    }
  }

  Future<AuthSession?> _switchClanContext(String clanId) async {
    final normalized = clanId.trim();
    if (normalized.isEmpty || normalized == (_session.clanId ?? '').trim()) {
      return _session;
    }
    if (_isSwitchingClanContext) {
      return null;
    }
    _isSwitchingClanContext = true;
    try {
      final snapshot = await _clanContextService.switchActiveClan(
        session: _session,
        clanId: normalized,
      );
      if (!mounted) {
        return null;
      }
      setState(() {
        _activeSession = snapshot.activeSession;
        _clanContexts = snapshot.contexts;
        _visitedDestinationIndexes.add(_selectedIndex);
      });
      await _sessionStore.write(_activeSession);
      await _pushNotificationService.start(
        session: _session,
        onDeepLink: _handleNotificationDeepLink,
      );
      unawaited(_refreshBillingEntitlement());
      return _activeSession;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.pick(
                vi: 'Không thể chuyển gia phả lúc này. Vui lòng thử lại.',
                en: 'Unable to switch clan right now. Please try again.',
              ),
            ),
          ),
        );
      }
      return null;
    } finally {
      _isSwitchingClanContext = false;
    }
  }

  Future<void> _updateSessionFromProfile(AuthSession session) async {
    if (!mounted || session == _activeSession) {
      return;
    }
    setState(() {
      _activeSession = session;
      _visitedDestinationIndexes.add(_selectedIndex);
    });
    await _sessionStore.write(_activeSession);
    await _pushNotificationService.start(
      session: _session,
      onDeepLink: _handleNotificationDeepLink,
    );
    unawaited(_refreshBillingEntitlement());
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
    final layout = ResponsiveLayout.of(context);
    final l10n = context.l10n;
    final destinations = _hasClanContext
        ? _destinations
        : _unlinkedDestinations;
    if (_selectedIndex >= destinations.length) {
      _selectedIndex = 0;
    }
    final destination = destinations[_selectedIndex];
    final sessionTooltip = l10n.authEntryMethodSummary(_session.loginMethod);
    final readinessTooltip = widget.status.isReady
        ? l10n.shellReadinessReady
        : widget.status.errorMessage?.trim().isNotEmpty == true
        ? widget.status.errorMessage!
        : l10n.shellReadinessPending;
    final pages = [
      _HomeDashboard(
        key: ValueKey<String>('home-${_session.clanId ?? 'none'}'),
        status: widget.status,
        session: _session,
        clanRepository: widget.clanRepository,
        memberRepository: widget.memberRepository,
        fundRepository: _fundRepository,
        availableClanContexts: _clanContexts,
        onSwitchClanContext: _switchClanContext,
        onOpenTreeRequested: () {
          setState(() {
            _selectedIndex = 1;
            _visitedDestinationIndexes.add(1);
          });
          _syncAdBannerAutoHideTimer();
        },
        onOpenEventsRequested: () {
          setState(() {
            _selectedIndex = 2;
            _visitedDestinationIndexes.add(2);
          });
          _syncAdBannerAutoHideTimer();
        },
        onOpenMemorialChecklistRequested: () {
          unawaited(_openMemorialRitualWorkspace());
        },
        onOpenProfileRequested: () {
          setState(() {
            _selectedIndex = 4;
            _visitedDestinationIndexes.add(4);
          });
          _syncAdBannerAutoHideTimer();
        },
      ),
      if (_visitedDestinationIndexes.contains(1))
        _hasClanContext
            ? GenealogyWorkspacePage(
                key: ValueKey<String>('tree-${_session.clanId ?? 'none'}'),
                session: _session,
                repository: _genealogyRepository,
              )
            : GenealogyDiscoveryPage(
                key: const ValueKey<String>('tree-discovery'),
                session: _session,
                repository: createDefaultGenealogyDiscoveryRepository(
                  session: _session,
                ),
                onAddGenealogyRequested: _openClanWorkspaceFromTreeAddAction,
              )
      else
        const SizedBox.shrink(),
      if (_visitedDestinationIndexes.contains(2))
        KeyedSubtree(
          key: ValueKey<String>('events-${_session.clanId ?? 'none'}'),
          child: DualCalendarWorkspacePage(session: _session),
        )
      else
        const SizedBox.shrink(),
      if (_visitedDestinationIndexes.contains(3))
        BillingWorkspacePage(
          key: ValueKey<String>(
            'billing-${_session.clanId ?? 'none'}-${_session.uid}',
          ),
          session: _session,
          repository: _billingRepository,
          embeddedInShell: true,
        )
      else
        const SizedBox.shrink(),
      if (_visitedDestinationIndexes.contains(4))
        ProfileWorkspacePage(
          key: ValueKey<String>('profile-${_session.clanId ?? 'none'}'),
          session: _session,
          memberRepository: widget.memberRepository,
          billingRepository: _billingRepository,
          onBillingStateChanged: () {
            unawaited(_refreshBillingEntitlement());
          },
          localeController: widget.localeController,
          onLogoutRequested: widget.onLogoutRequested,
          onSessionUpdated: (session) {
            unawaited(_updateSessionFromProfile(session));
          },
        )
      else
        const SizedBox.shrink(),
    ];

    final appBar = AppBar(
      title: Text(l10n.shellDestinationTitle(destination.id)),
      actions: _buildAppBarActions(
        l10n: l10n,
        sessionTooltip: sessionTooltip,
        readinessTooltip: readinessTooltip,
      ),
    );

    Widget contentStack = IndexedStack(index: _selectedIndex, children: pages);
    if (layout.useRailNavigation) {
      contentStack = Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: layout.contentMaxWidth),
          child: contentStack,
        ),
      );
    }

    final contentWithBanner = Column(
      children: [
        if (_isAdBannerVisible)
          _SponsoredAdBanner(
            onClose: () {
              setState(() {
                _dismissAdBannerForSession = true;
              });
              _syncAdBannerAutoHideTimer();
            },
          ),
        Expanded(child: SafeArea(top: false, child: contentStack)),
      ],
    );

    if (layout.useRailNavigation) {
      return Scaffold(
        appBar: appBar,
        body: Row(
          children: [
            _ShellNavigationRail(
              selectedIndex: _selectedIndex,
              destinations: destinations,
              onDestinationSelected: _handleDestinationSelected,
            ),
            const VerticalDivider(width: 1),
            Expanded(child: contentWithBanner),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: appBar,
      body: SafeArea(child: contentStack),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isAdBannerVisible)
            _SponsoredAdBanner(
              onClose: () {
                setState(() {
                  _dismissAdBannerForSession = true;
                });
                _syncAdBannerAutoHideTimer();
              },
            ),
          MediaQuery.withClampedTextScaling(
            minScaleFactor: 1,
            maxScaleFactor: 1,
            child: NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: _handleDestinationSelected,
              labelBehavior: layout.width < 460
                  ? NavigationDestinationLabelBehavior.onlyShowSelected
                  : NavigationDestinationLabelBehavior.alwaysShow,
              destinations: [
                for (final destination in destinations)
                  NavigationDestination(
                    icon: Icon(destination.icon),
                    selectedIcon: Icon(destination.selectedIcon),
                    label: l10n.shellDestinationLabel(destination.id),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _handleDestinationSelected(int index) {
    setState(() {
      _selectedIndex = index;
      _visitedDestinationIndexes.add(index);
    });
    _syncAdBannerAutoHideTimer();
  }

  List<Widget> _buildAppBarActions({
    required dynamic l10n,
    required String sessionTooltip,
    required String readinessTooltip,
  }) {
    return [
      if (_selectedIndex == 0)
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Tooltip(
            message: sessionTooltip,
            child: Icon(
              _session.loginMethod == AuthEntryMethod.phone
                  ? Icons.phone_iphone
                  : Icons.child_care,
            ),
          ),
        ),
      if (_isLoadingClanContexts || _isSwitchingClanContext)
        const Padding(
          padding: EdgeInsets.only(right: 8),
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        )
      else if (_clanContexts.length > 1)
        PopupMenuButton<String>(
          tooltip: l10n.pick(vi: 'Chọn gia phả', en: 'Select clan'),
          onSelected: (clanId) {
            unawaited(_switchClanContext(clanId));
          },
          itemBuilder: (context) => [
            for (final contextOption in _clanContexts)
              PopupMenuItem<String>(
                value: contextOption.clanId,
                child: Text(
                  contextOption.clanId == (_session.clanId ?? '').trim()
                      ? '• ${contextOption.clanName}'
                      : contextOption.clanName,
                ),
              ),
          ],
          icon: const Icon(Icons.account_tree_outlined),
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
      PopupMenuButton<String>(
        tooltip: l10n.shellMoreActions,
        onSelected: (value) async {
          if (value == 'discover') {
            _openGenealogyDiscoveryPage();
            return;
          }
          if (value == 'logout') {
            await _confirmLogoutRequest();
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem<String>(
            value: 'discover',
            child: Text(
              l10n.pick(vi: 'Khám phá gia phả', en: 'Discover genealogies'),
            ),
          ),
          if (widget.onLogoutRequested != null)
            PopupMenuItem<String>(
              value: 'logout',
              child: Text(l10n.shellLogout),
            ),
        ],
      ),
    ];
  }

  void _openGenealogyDiscoveryPage() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) {
          return GenealogyDiscoveryPage(
            session: _session,
            repository: createDefaultGenealogyDiscoveryRepository(
              session: _session,
            ),
            onAddGenealogyRequested: _openClanWorkspaceFromTreeAddAction,
          );
        },
      ),
    );
  }

  Future<void> _openClanWorkspaceFromTreeAddAction() async {
    if (!_hasClanContext && !GovernanceRoleMatrix.canBootstrapClan(_session)) {
      if (!mounted) {
        return;
      }
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

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) {
          return ClanDetailPage(
            session: _session,
            repository: widget.clanRepository,
            availableClanContexts: _clanContexts,
            onSwitchClanContext: _switchClanContext,
          );
        },
      ),
    );
  }

  Future<void> _openMemorialRitualWorkspace() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) {
          return EventWorkspacePage(
            session: _session,
            repository: createDefaultEventRepository(session: _session),
          );
        },
      ),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 420;
        return Material(
          color: colorScheme.tertiaryContainer.withValues(alpha: 0.88),
          child: SafeArea(
            top: false,
            minimum: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  Icons.campaign_outlined,
                  color: colorScheme.onTertiaryContainer,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.pick(
                      vi: 'Gói Miễn phí/Cơ bản đang hiển thị quảng cáo nhẹ.',
                      en: 'Free/Base plans show light ads.',
                    ),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onTertiaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: compact ? 2 : 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (!compact)
                  TextButton(
                    onPressed: onClose,
                    child: Text(
                      l10n.pick(vi: 'Ẩn hôm nay', en: 'Hide today'),
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: colorScheme.onTertiaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                IconButton(
                  tooltip: l10n.pick(vi: 'Đóng', en: 'Close'),
                  onPressed: onClose,
                  icon: const Icon(Icons.close),
                  color: colorScheme.onTertiaryContainer,
                  visualDensity: VisualDensity.compact,
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
                icon: Icon(destination.icon),
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
    required this.fundRepository,
    required this.availableClanContexts,
    required this.onSwitchClanContext,
    required this.onOpenTreeRequested,
    required this.onOpenProfileRequested,
    required this.onOpenEventsRequested,
    required this.onOpenMemorialChecklistRequested,
  });

  final FirebaseSetupStatus status;
  final AuthSession session;
  final ClanRepository clanRepository;
  final MemberRepository memberRepository;
  final FundRepository fundRepository;
  final List<ClanContextOption> availableClanContexts;
  final Future<AuthSession?> Function(String clanId) onSwitchClanContext;
  final VoidCallback onOpenTreeRequested;
  final VoidCallback onOpenProfileRequested;
  final VoidCallback onOpenEventsRequested;
  final VoidCallback onOpenMemorialChecklistRequested;
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

  List<AppShortcut> get _primaryShortcuts {
    final primary = _availableShortcuts.where((entry) => entry.isPrimary);
    final fallback = primary.isEmpty ? _availableShortcuts : primary;
    return fallback.take(4).toList(growable: false);
  }

  List<AppShortcut> get _secondaryShortcuts {
    final primaryIds = _primaryShortcuts.map((entry) => entry.id).toSet();
    return _availableShortcuts
        .where((entry) => !primaryIds.contains(entry.id))
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final layout = ResponsiveLayout.of(context);
    final maxCrossAxisCount = layout.gridColumns(
      mobile: 1,
      tablet: 2,
      desktop: 3,
    );
    final availableWidth = math.min(
      layout.contentMaxWidth,
      layout.width - (layout.horizontalPadding * 2),
    );
    final fitColumns = ((availableWidth + 16) / 300).floor().clamp(
      1,
      maxCrossAxisCount,
    );
    final crossAxisCount = fitColumns;
    final childAspectRatio = switch (layout.viewport) {
      AppViewport.mobile => 1.05,
      AppViewport.tablet => 0.95,
      AppViewport.desktop => 1.08,
    };

    return ListView(
      padding: EdgeInsets.fromLTRB(
        layout.horizontalPadding,
        20,
        layout.horizontalPadding,
        32,
      ),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: layout.contentMaxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _UpcomingEventSection(
                  session: session,
                  onOpenEventsRequested: onOpenEventsRequested,
                ),
                const SizedBox(height: 24),
                _TodoSection(
                  status: status,
                  session: session,
                  onOpenTreeRequested: onOpenTreeRequested,
                  onOpenProfileRequested: onOpenProfileRequested,
                  onOpenEventsRequested: onOpenEventsRequested,
                  onOpenMemorialChecklistRequested:
                      onOpenMemorialChecklistRequested,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.pick(vi: 'Truy cập nhanh', en: 'Quick access'),
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => _openAllShortcutsSheet(context),
                      child: Text(l10n.pick(vi: 'Xem tất cả', en: 'View all')),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _primaryShortcuts.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: childAspectRatio,
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
        ),
      ],
    );
  }

  void _openAllShortcutsSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) {
        final l10n = context.l10n;
        final shortcuts = _secondaryShortcuts.isEmpty
            ? _availableShortcuts
            : _secondaryShortcuts;
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
              Card(
                child: ListTile(
                  leading: Icon(_iconFor(shortcut.iconKey)),
                  title: Text(l10n.shortcutTitle(shortcut.id)),
                  subtitle: Text(
                    _productionShortcutDescription(context, shortcut.id),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.of(context).pop();
                    _onShortcutTap(context, shortcut.id)?.call();
                  },
                ),
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
                availableClanContexts: availableClanContexts,
                onSwitchClanContext: onSwitchClanContext,
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
                onSwitchClanContext: onSwitchClanContext,
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
        onLongPress: onTap,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final textScale = MediaQuery.textScalerOf(context).scale(1);
            final compact = constraints.maxHeight < 260 || textScale > 1.15;
            final hideStatusChip =
                constraints.maxHeight < 280 || textScale > 1.2;
            return Padding(
              padding: EdgeInsets.all(compact ? 16 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: compact ? 16 : 20,
                    backgroundColor: statusColor,
                    foregroundColor: colorScheme.onSurface,
                    child: Icon(_iconFor(shortcut.iconKey)),
                  ),
                  SizedBox(height: compact ? 10 : 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          l10n.shortcutTitle(shortcut.id),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            fontSize: compact ? 17 : null,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!hideStatusChip) ...[
                        const SizedBox(width: 8),
                        _ShortcutStatusChip(status: shortcut.status),
                      ],
                    ],
                  ),
                  SizedBox(height: compact ? 6 : 10),
                  Expanded(
                    child: Text(
                      _productionShortcutDescription(context, shortcut.id),
                      style: theme.textTheme.bodyMedium,
                      maxLines: hideStatusChip ? 1 : (compact ? 2 : 3),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          },
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

class _TodoSection extends StatelessWidget {
  const _TodoSection({
    required this.status,
    required this.session,
    required this.onOpenTreeRequested,
    required this.onOpenProfileRequested,
    required this.onOpenEventsRequested,
    required this.onOpenMemorialChecklistRequested,
  });

  final FirebaseSetupStatus status;
  final AuthSession session;
  final VoidCallback onOpenTreeRequested;
  final VoidCallback onOpenProfileRequested;
  final VoidCallback onOpenEventsRequested;
  final VoidCallback onOpenMemorialChecklistRequested;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tasks = <({IconData icon, String title, VoidCallback onTap})>[
      (
        icon: Icons.event_available_outlined,
        title: l10n.pick(
          vi: 'Kiểm tra sự kiện trong tuần',
          en: 'Review this week events',
        ),
        onTap: onOpenEventsRequested,
      ),
      (
        icon: Icons.history_edu_outlined,
        title: l10n.pick(
          vi: 'Rà soát danh sách giỗ và dỗ trạp',
          en: 'Review memorial and ritual checklists',
        ),
        onTap: onOpenMemorialChecklistRequested,
      ),
      (
        icon: Icons.person_outline,
        title: l10n.pick(
          vi: 'Cập nhật hồ sơ của bạn',
          en: 'Update your profile',
        ),
        onTap: onOpenProfileRequested,
      ),
      if (session.accessMode == AuthMemberAccessMode.unlinked)
        (
          icon: Icons.travel_explore_outlined,
          title: l10n.pick(
            vi: 'Tìm gia phả để tham gia',
            en: 'Discover genealogies to join',
          ),
          onTap: onOpenTreeRequested,
        ),
      if (!status.isReady)
        (
          icon: Icons.cloud_off,
          title: l10n.pick(
            vi: 'Kiểm tra kết nối Firebase',
            en: 'Check Firebase connectivity',
          ),
          onTap: onOpenProfileRequested,
        ),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.pick(vi: 'Việc cần làm', en: 'To-do'),
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            for (final entry in tasks.take(3))
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(entry.icon),
                title: Text(entry.title),
                trailing: const Icon(Icons.chevron_right),
                onTap: entry.onTap,
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
