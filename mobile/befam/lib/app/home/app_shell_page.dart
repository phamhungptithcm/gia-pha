import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/services/firebase_services.dart';
import '../../core/widgets/member_phone_action.dart';
import '../../core/widgets/address_action_tools.dart';
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
import '../../features/discovery/presentation/join_request_review_page.dart';
import '../../features/discovery/presentation/my_join_requests_page.dart';
import '../../features/discovery/services/genealogy_discovery_repository.dart';
import '../../features/member/presentation/member_workspace_page.dart';
import '../../features/member/models/member_profile.dart';
import '../../features/member/services/member_repository.dart';
import '../../features/notifications/presentation/notification_target_page.dart';
import '../../features/notifications/services/push_notification_service.dart';
import '../../features/profile/presentation/profile_workspace_page.dart';
import '../../features/profile/services/profile_notification_preferences_repository.dart';
import '../../features/scholarship/presentation/scholarship_workspace_page.dart';
import '../../features/scholarship/services/scholarship_repository.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../l10n/l10n.dart';
import '../../features/auth/models/auth_entry_method.dart';
import '../../features/auth/models/auth_member_access_mode.dart';
import '../../features/auth/models/auth_session.dart';
import '../../features/auth/models/clan_context_option.dart';
import '../../features/auth/services/auth_session_store.dart';
import '../../features/auth/services/clan_context_service.dart';
import '../../core/services/app_locale_controller.dart';
import '../../core/widgets/responsive_layout.dart';
import '../bootstrap/firebase_setup_status.dart';
import '../models/app_shortcut.dart';
import 'app_shortcuts.dart';

enum _ShellOverflowAction { switchClan, logout }

bool _sessionHasClanContext(AuthSession session) {
  final clanId = (session.clanId ?? '').trim();
  if (clanId.isEmpty) {
    return false;
  }
  return session.accessMode != AuthMemberAccessMode.unlinked;
}

class AppShellPage extends StatefulWidget {
  const AppShellPage({
    super.key,
    required this.status,
    required this.session,
    required this.clanRepository,
    required this.memberRepository,
    this.eventRepository,
    this.fundRepository,
    this.genealogyRepository,
    this.genealogyDiscoveryRepository,
    this.billingRepository,
    this.pushNotificationService,
    this.clanContextService,
    this.profileNotificationPreferencesRepository,
    this.localeController,
    this.onLogoutRequested,
  });

  final FirebaseSetupStatus status;
  final AuthSession session;
  final ClanRepository clanRepository;
  final MemberRepository memberRepository;
  final EventRepository? eventRepository;
  final FundRepository? fundRepository;
  final GenealogyReadRepository? genealogyRepository;
  final GenealogyDiscoveryRepository? genealogyDiscoveryRepository;
  final BillingRepository? billingRepository;
  final PushNotificationService? pushNotificationService;
  final ClanContextService? clanContextService;
  final ProfileNotificationPreferencesRepository?
  profileNotificationPreferencesRepository;
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
  late final GenealogyDiscoveryRepository _genealogyDiscoveryRepository;
  late final EventRepository _eventRepository;
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
  final Map<String, String> _resolvedClanNamesById = <String, String>{};
  bool _isResolvingActiveClanName = false;

  AuthSession get _session => _activeSession;

  bool get _hasClanContext => _sessionHasClanContext(_session);

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
    _activeSession = _sanitizeSessionContext(widget.session);
    _genealogyRepository =
        widget.genealogyRepository ??
        createDefaultGenealogyReadRepository(session: _session);
    _genealogyDiscoveryRepository =
        widget.genealogyDiscoveryRepository ??
        createDefaultGenealogyDiscoveryRepository(session: _session);
    _eventRepository =
        widget.eventRepository ??
        createDefaultEventRepository(session: _session);
    _fundRepository =
        widget.fundRepository ?? createDefaultFundRepository(session: _session);
    _billingRepository =
        widget.billingRepository ??
        createDefaultBillingRepository(session: _session);
    _pushNotificationService =
        widget.pushNotificationService ??
        createDefaultPushNotificationService(session: _session);
    _clanContextService =
        widget.clanContextService ??
        createDefaultClanContextService(session: _session);
    unawaited(
      _pushNotificationService.start(
        session: _session,
        onDeepLink: _handleNotificationDeepLink,
      ),
    );
    unawaited(_loadClanContexts());
    unawaited(_ensureActiveClanDisplayNameResolved());
    unawaited(_refreshBillingEntitlement());
    _syncAdBannerAutoHideTimer();
  }

  @override
  void didUpdateWidget(covariant AppShellPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session != widget.session) {
      _activeSession = _sanitizeSessionContext(widget.session);
      unawaited(
        _pushNotificationService.start(
          session: _session,
          onDeepLink: _handleNotificationDeepLink,
        ),
      );
      unawaited(_loadClanContexts());
      unawaited(_ensureActiveClanDisplayNameResolved());
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

    final destinationIndex = _destinationIndexForNotificationTarget(
      deepLink.targetType,
    );
    final shouldOpenTargetDestination =
        deepLink.openedFromSystemNotification && destinationIndex != null;
    if (shouldOpenTargetDestination) {
      setState(() {
        _selectedIndex = destinationIndex;
        _visitedDestinationIndexes.add(destinationIndex);
      });
      _syncAdBannerAutoHideTimer();
      if (deepLink.targetType != NotificationTargetType.billing) {
        _openNotificationTargetPage(
          targetType: deepLink.targetType,
          referenceId: deepLink.referenceId,
          sourceTitle: deepLink.title,
          sourceBody: deepLink.body,
          messageId: deepLink.messageId,
        );
      }
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
    if (targetType == NotificationTargetType.unknown ||
        targetType == NotificationTargetType.billing) {
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
        NotificationTargetType.billing => l10n.notificationOpenedGeneral,
        NotificationTargetType.unknown => l10n.notificationOpenedGeneral,
      };
    }

    return switch (targetType) {
      NotificationTargetType.event => l10n.notificationForegroundEvent,
      NotificationTargetType.scholarship =>
        l10n.notificationForegroundScholarship,
      NotificationTargetType.billing => l10n.notificationForegroundGeneral,
      NotificationTargetType.unknown => l10n.notificationForegroundGeneral,
    };
  }

  int? _destinationIndexForNotificationTarget(
    NotificationTargetType targetType,
  ) {
    return switch (targetType) {
      NotificationTargetType.event || NotificationTargetType.scholarship => 2,
      NotificationTargetType.billing => 3,
      NotificationTargetType.unknown => null,
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
    return _sessionHasClanContext(session);
  }

  AuthSession _sanitizeSessionContext(AuthSession session) {
    final clanId = (session.clanId ?? '').trim();
    final memberId = (session.memberId ?? '').trim();
    final hasLinkedContext = clanId.isNotEmpty && memberId.isNotEmpty;

    if (session.accessMode == AuthMemberAccessMode.unlinked) {
      if (clanId.isEmpty &&
          memberId.isEmpty &&
          (session.branchId ?? '').trim().isEmpty &&
          !session.linkedAuthUid &&
          (session.primaryRole ?? '').trim().toUpperCase() == 'GUEST') {
        return session;
      }
      return session.copyWith(
        clanId: null,
        memberId: null,
        branchId: null,
        primaryRole: 'GUEST',
        linkedAuthUid: false,
      );
    }

    if (session.accessMode == AuthMemberAccessMode.claimed &&
        !hasLinkedContext) {
      return session.copyWith(
        clanId: null,
        memberId: null,
        branchId: null,
        primaryRole: 'GUEST',
        accessMode: AuthMemberAccessMode.unlinked,
        linkedAuthUid: false,
      );
    }

    return session;
  }

  Future<void> _loadClanContexts() async {
    if (_isLoadingClanContexts) {
      return;
    }
    // Child-access sessions should keep their scoped context and skip clan sync.
    if (_session.loginMethod == AuthEntryMethod.child) {
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
      final resolvedNames = _extractNamedClanContexts(snapshot.contexts);
      final sanitizedSession = _sanitizeSessionContext(snapshot.activeSession);
      setState(() {
        _activeSession = sanitizedSession;
        _clanContexts = snapshot.contexts;
        _resolvedClanNamesById.addAll(resolvedNames);
      });
      await _sessionStore.write(_activeSession);
      await _pushNotificationService.start(
        session: _session,
        onDeepLink: _handleNotificationDeepLink,
      );
      unawaited(_ensureActiveClanDisplayNameResolved());
      unawaited(_refreshBillingEntitlement());
    } catch (_) {
      final sanitizedSession = _sanitizeSessionContext(_session);
      if (!mounted || sanitizedSession == _session) {
        return;
      }
      setState(() {
        _activeSession = sanitizedSession;
        if (!_sessionHasClanContext(sanitizedSession)) {
          _clanContexts = const [];
        }
      });
      await _sessionStore.write(_activeSession);
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
      final resolvedNames = _extractNamedClanContexts(snapshot.contexts);
      final sanitizedSession = _sanitizeSessionContext(snapshot.activeSession);
      setState(() {
        _activeSession = sanitizedSession;
        _clanContexts = snapshot.contexts;
        _resolvedClanNamesById.addAll(resolvedNames);
        _visitedDestinationIndexes.add(_selectedIndex);
      });
      await _sessionStore.write(_activeSession);
      await _pushNotificationService.start(
        session: _session,
        onDeepLink: _handleNotificationDeepLink,
      );
      unawaited(_ensureActiveClanDisplayNameResolved());
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
    final sanitizedSession = _sanitizeSessionContext(session);
    if (!mounted || sanitizedSession == _activeSession) {
      return;
    }
    setState(() {
      _activeSession = sanitizedSession;
      _visitedDestinationIndexes.add(_selectedIndex);
    });
    await _sessionStore.write(_activeSession);
    await _pushNotificationService.start(
      session: _session,
      onDeepLink: _handleNotificationDeepLink,
    );
    unawaited(_ensureActiveClanDisplayNameResolved());
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

  String _activeClanAppBarTitle(AppLocalizations l10n) {
    final activeClanId = (_session.clanId ?? '').trim();
    if (activeClanId.isEmpty) {
      return 'BeFam';
    }
    final resolvedName = _activeClanDisplayName();
    if (resolvedName != null) {
      return resolvedName;
    }
    return l10n.pick(vi: 'Gia phả hiện tại', en: 'Current clan');
  }

  Future<void> _openClanSwitcherSheet(AppLocalizations l10n) async {
    if (_isLoadingClanContexts || _isSwitchingClanContext) {
      return;
    }
    if (_clanContexts.length < 2) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.pick(
              vi: 'Bạn chỉ có một gia phả khả dụng.',
              en: 'You only have one available clan.',
            ),
          ),
        ),
      );
      return;
    }

    final activeClanId = (_session.clanId ?? '').trim();
    final selected = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) {
        final theme = Theme.of(context);
        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            children: [
              Text(
                l10n.pick(vi: 'Chuyển qua gia phả khác', en: 'Switch clan'),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.pick(
                  vi: 'Chọn gia phả muốn làm việc. Toàn bộ dữ liệu theo clan sẽ cập nhật theo lựa chọn này.',
                  en: 'Choose the clan to work with. All clan-scoped data will follow this selection.',
                ),
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              for (final option in _clanContexts)
                Card(
                  child: ListTile(
                    onTap: () => Navigator.of(context).pop(option.clanId),
                    leading: Icon(
                      option.clanId.trim() == activeClanId
                          ? Icons.check_circle
                          : Icons.circle_outlined,
                    ),
                    title: Text(
                      _displayClanNameForOption(option, l10n),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      _clanContextPopupSubtitle(option, l10n),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const Icon(Icons.chevron_right),
                  ),
                ),
            ],
          ),
        );
      },
    );

    if (!mounted || selected == null) {
      return;
    }
    await _switchClanContext(selected);
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
        eventRepository: _eventRepository,
        fundRepository: _fundRepository,
        discoveryRepository: _genealogyDiscoveryRepository,
        activeClanName: _activeClanDisplayName(),
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
        onOpenUpcomingEventDetailRequested: (event) {
          unawaited(_openUpcomingEventDetail(event));
        },
        onOpenMemorialChecklistRequested: () {
          unawaited(_openMemorialRitualWorkspace());
        },
        onOpenJoinRequestsRequested: () {
          unawaited(_openJoinRequestsCenter());
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
                clanRepository: widget.clanRepository,
              )
            : GenealogyDiscoveryPage(
                key: const ValueKey<String>('tree-discovery'),
                session: _session,
                repository: _genealogyDiscoveryRepository,
                onAddGenealogyRequested: _openClanWorkspaceFromTreeAddAction,
              )
      else
        const SizedBox.shrink(),
      if (_visitedDestinationIndexes.contains(2))
        KeyedSubtree(
          key: ValueKey<String>('events-${_session.clanId ?? 'none'}'),
          child: DualCalendarWorkspacePage(
            session: _session,
            memberRepository: widget.memberRepository,
            availableClanContexts: _clanContexts,
            onSwitchClanContext: _switchClanContext,
          ),
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
          notificationPreferencesRepository:
              widget.profileNotificationPreferencesRepository,
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
      title: Text(_activeClanAppBarTitle(l10n)),
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

  Map<String, String> _extractNamedClanContexts(
    Iterable<ClanContextOption> options,
  ) {
    final named = <String, String>{};
    for (final option in options) {
      final clanId = option.clanId.trim();
      final clanName = option.clanName.trim();
      if (clanId.isEmpty || clanName.isEmpty) {
        continue;
      }
      if (clanName.toLowerCase() == clanId.toLowerCase()) {
        continue;
      }
      named[clanId] = clanName;
    }
    return named;
  }

  String? _activeClanDisplayName() {
    final clanId = (_session.clanId ?? '').trim();
    if (clanId.isEmpty) {
      return null;
    }
    final contextName = _clanContexts
        .where((option) => option.clanId.trim() == clanId)
        .map((option) => option.clanName.trim())
        .firstWhere(
          (name) =>
              name.isNotEmpty && name.toLowerCase() != clanId.toLowerCase(),
          orElse: () => '',
        );
    if (contextName.isNotEmpty) {
      return contextName;
    }
    final cached = _resolvedClanNamesById[clanId]?.trim() ?? '';
    if (cached.isNotEmpty && cached.toLowerCase() != clanId.toLowerCase()) {
      return cached;
    }
    return null;
  }

  String _displayClanNameForOption(
    ClanContextOption option,
    AppLocalizations l10n,
  ) {
    final optionClanId = option.clanId.trim();
    final explicitName = option.clanName.trim();
    if (explicitName.isNotEmpty &&
        explicitName.toLowerCase() != optionClanId.toLowerCase()) {
      return explicitName;
    }
    final cached = _resolvedClanNamesById[optionClanId]?.trim() ?? '';
    if (cached.isNotEmpty) {
      return cached;
    }
    if (optionClanId == (_session.clanId ?? '').trim()) {
      final active = _activeClanDisplayName();
      if (active != null) {
        return active;
      }
    }
    return l10n.pick(vi: 'Gia phả', en: 'Clan');
  }

  Future<void> _ensureActiveClanDisplayNameResolved() async {
    final clanId = (_session.clanId ?? '').trim();
    if (clanId.isEmpty || _isResolvingActiveClanName) {
      return;
    }
    final cachedName = _resolvedClanNamesById[clanId]?.trim() ?? '';
    if (cachedName.isNotEmpty &&
        cachedName.toLowerCase() != clanId.toLowerCase()) {
      return;
    }
    final contextName = _activeClanDisplayName();
    if (contextName != null) {
      return;
    }

    _isResolvingActiveClanName = true;
    try {
      final workspace = await widget.clanRepository.loadWorkspace(
        session: _session,
      );
      final clanName = workspace.clan?.name.trim() ?? '';
      if (!mounted || clanName.isEmpty) {
        return;
      }
      if (clanName.toLowerCase() == clanId.toLowerCase()) {
        return;
      }
      setState(() {
        _resolvedClanNamesById[clanId] = clanName;
      });
    } catch (_) {
      // Keep fallback label when the clan profile cannot be loaded.
    } finally {
      _isResolvingActiveClanName = false;
    }
  }

  void _handleDestinationSelected(int index) {
    setState(() {
      _selectedIndex = index;
      _visitedDestinationIndexes.add(index);
    });
    _syncAdBannerAutoHideTimer();
  }

  List<Widget> _buildAppBarActions({
    required AppLocalizations l10n,
    required String sessionTooltip,
    required String readinessTooltip,
  }) {
    final canSwitchClan =
        !_isLoadingClanContexts &&
        !_isSwitchingClanContext &&
        _clanContexts.length > 1;
    final canLogout = widget.onLogoutRequested != null;

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
      else
        const SizedBox(width: 4),
      Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Tooltip(
          message: readinessTooltip,
          child: Icon(
            widget.status.isReady ? Icons.cloud_done : Icons.cloud_off,
          ),
        ),
      ),
      if (_selectedIndex == 1)
        IconButton(
          tooltip: l10n.pick(
            vi: 'Yêu cầu bạn đã gửi',
            en: 'Your submitted requests',
          ),
          onPressed: _openSubmittedJoinRequests,
          icon: const Icon(Icons.list_alt_outlined),
        ),
      if (canSwitchClan || canLogout)
        PopupMenuButton<_ShellOverflowAction>(
          tooltip: l10n.pick(vi: 'Tùy chọn', en: 'Options'),
          onSelected: (action) {
            switch (action) {
              case _ShellOverflowAction.switchClan:
                unawaited(_openClanSwitcherSheet(l10n));
              case _ShellOverflowAction.logout:
                unawaited(_confirmLogoutRequest());
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem<_ShellOverflowAction>(
              value: _ShellOverflowAction.switchClan,
              enabled: canSwitchClan,
              child: Text(
                l10n.pick(
                  vi: 'Chuyển qua gia phả khác',
                  en: 'Switch to another clan',
                ),
              ),
            ),
            if (canLogout)
              PopupMenuItem<_ShellOverflowAction>(
                value: _ShellOverflowAction.logout,
                child: Text(l10n.shellLogout),
              ),
          ],
          icon: const Icon(Icons.more_horiz),
        ),
    ];
  }

  String _clanContextPopupSubtitle(
    ClanContextOption option,
    AppLocalizations l10n,
  ) {
    final ownerLabel = (option.ownerDisplayName ?? option.ownerUid ?? '')
        .trim();
    final planCode = (option.billingPlanCode ?? '').trim().toUpperCase();
    final planLabel = planCode.isEmpty
        ? l10n.pick(vi: 'Gói: --', en: 'Plan: --')
        : l10n.pick(vi: 'Gói: $planCode', en: 'Plan: $planCode');
    final ownerPart = ownerLabel.isEmpty
        ? l10n.pick(vi: 'Owner: --', en: 'Owner: --')
        : l10n.pick(vi: 'Owner: $ownerLabel', en: 'Owner: $ownerLabel');
    return '$planLabel · $ownerPart';
  }

  Future<void> _openClanWorkspaceFromTreeAddAction() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) {
          return ClanDetailPage(
            session: _session,
            repository: widget.clanRepository,
            availableClanContexts: _clanContexts,
            onSwitchClanContext: _switchClanContext,
            autoOpenClanEditorOnOpen: !_hasClanContext,
          );
        },
      ),
    );
    await _loadClanContexts();
  }

  Future<void> _openMemorialRitualWorkspace() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) {
          return EventWorkspacePage(
            session: _session,
            repository: _eventRepository,
            availableClanContexts: _clanContexts,
            onSwitchClanContext: _switchClanContext,
          );
        },
      ),
    );
  }

  Future<void> _openUpcomingEventDetail(EventRecord event) async {
    if ((_session.clanId ?? '').trim().isEmpty) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) {
          return EventWorkspacePage(
            session: _session,
            repository: _eventRepository,
            availableClanContexts: _clanContexts,
            onSwitchClanContext: _switchClanContext,
            initialEventId: event.id,
          );
        },
      ),
    );
  }

  Future<void> _openJoinRequestsCenter() async {
    final repository = _genealogyDiscoveryRepository;
    final role = (_session.primaryRole ?? '').trim().toUpperCase();
    final canReview = <String>{
      'SUPER_ADMIN',
      'CLAN_ADMIN',
      'CLAN_LEADER',
      'BRANCH_ADMIN',
      'ADMIN_SUPPORT',
      'VICE_LEADER',
      'SUPPORTER_OF_LEADER',
    }.contains(role);

    if (canReview && _hasClanContext) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) {
            return JoinRequestReviewPage(
              session: _session,
              repository: repository,
            );
          },
        ),
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) {
          return MyJoinRequestsPage(
            session: _session,
            repository: repository,
            onOpenDiscoveryRequested: (query) async {
              await Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) {
                    return GenealogyDiscoveryPage(
                      session: _session,
                      repository: repository,
                      onAddGenealogyRequested: _hasClanContext
                          ? null
                          : _openClanWorkspaceFromTreeAddAction,
                      initialQuery: query,
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _openSubmittedJoinRequests() async {
    final repository = _genealogyDiscoveryRepository;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) {
          return MyJoinRequestsPage(
            session: _session,
            repository: repository,
            onOpenDiscoveryRequested: (query) async {
              await Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) {
                    return GenealogyDiscoveryPage(
                      session: _session,
                      repository: repository,
                      onAddGenealogyRequested: _hasClanContext
                          ? null
                          : _openClanWorkspaceFromTreeAddAction,
                      initialQuery: query,
                    );
                  },
                ),
              );
            },
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
    final childAspectRatio = switch ((layout.viewport, crossAxisCount)) {
      (AppViewport.mobile, 1) => 2.05,
      (AppViewport.tablet, 1) => 2.2,
      (AppViewport.desktop, 1) => 2.35,
      (AppViewport.mobile, _) => 1.2,
      (AppViewport.tablet, _) => 1.08,
      (AppViewport.desktop, _) => 1.15,
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
                  eventRepository: eventRepository,
                  activeClanName: _activeClanName,
                  onOpenEventDetailRequested:
                      onOpenUpcomingEventDetailRequested,
                ),
                const SizedBox(height: 24),
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
                const SizedBox(height: 24),
                _NearbyRelativesSection(
                  session: session,
                  memberRepository: memberRepository,
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

class _ShortcutCard extends StatelessWidget {
  const _ShortcutCard({required this.shortcut, this.onTap});

  final AppShortcut shortcut;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = context.l10n;
    final isEnabled = onTap != null;
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
        child: Opacity(
          opacity: isEnabled ? 1 : 0.58,
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
                    Text(
                      _productionShortcutDescription(context, shortcut.id),
                      style: theme.textTheme.bodyMedium,
                      maxLines: hideStatusChip ? 1 : (compact ? 2 : 3),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              );
            },
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

class _UpcomingEventSection extends StatefulWidget {
  const _UpcomingEventSection({
    required this.session,
    required this.eventRepository,
    required this.activeClanName,
    required this.onOpenEventDetailRequested,
  });

  final AuthSession session;
  final EventRepository eventRepository;
  final String? activeClanName;
  final ValueChanged<EventRecord> onOpenEventDetailRequested;

  @override
  State<_UpcomingEventSection> createState() => _UpcomingEventSectionState();
}

class _UpcomingEventSectionState extends State<_UpcomingEventSection>
    with WidgetsBindingObserver {
  static const Duration _upcomingRefreshInterval = Duration(seconds: 45);

  late Future<_UpcomingEventData?> _upcomingFuture;
  Timer? _upcomingRefreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _upcomingFuture = _loadUpcomingEvent();
    _upcomingRefreshTimer = Timer.periodic(_upcomingRefreshInterval, (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _upcomingFuture = _loadUpcomingEvent();
      });
    });
  }

  @override
  void didUpdateWidget(covariant _UpcomingEventSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session != widget.session ||
        oldWidget.activeClanName != widget.activeClanName) {
      setState(() {
        _upcomingFuture = _loadUpcomingEvent();
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !mounted) {
      return;
    }
    setState(() {
      _upcomingFuture = _loadUpcomingEvent();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _upcomingRefreshTimer?.cancel();
    super.dispose();
  }

  Future<_UpcomingEventData?> _loadUpcomingEvent() async {
    try {
      final snapshot = await widget.eventRepository.loadWorkspace(
        session: widget.session,
      );
      final nowLocal = DateTime.now();
      final upcoming = snapshot.events
          .map(
            (event) => (
              event: event,
              nextStartsAt: _nextUpcomingStartAt(event, nowLocal),
            ),
          )
          .where((entry) => entry.nextStartsAt != null)
          .map(
            (entry) => (event: entry.event, nextStartsAt: entry.nextStartsAt!),
          )
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
      return _UpcomingEventData(
        event: event,
        hostHousehold: hostHousehold,
        clanName: _resolvedClanName(),
        startsAt: next.nextStartsAt,
      );
    } catch (_) {
      return null;
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
            final clanLabel = data.clanName?.trim() ?? '';

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
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
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    TextButton(
                      onPressed: () {
                        widget.onOpenEventDetailRequested(event);
                      },
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        minimumSize: const Size(0, 32),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        l10n.pick(vi: 'Xem chi tiết', en: 'View details'),
                      ),
                    ),
                    IconButton(
                      tooltip: l10n.pick(
                        vi: 'Làm mới sự kiện',
                        en: 'Refresh event',
                      ),
                      onPressed: () {
                        setState(() {
                          _upcomingFuture = _loadUpcomingEvent();
                        });
                      },
                      constraints: const BoxConstraints.tightFor(
                        width: 36,
                        height: 36,
                      ),
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.refresh),
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
                  _formatDashboardDateTime(data.startsAt),
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
                if (clanLabel.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    l10n.pick(vi: 'Họ tộc: $clanLabel', en: 'Clan: $clanLabel'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                if (event.locationAddress.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.pick(
                            vi: 'Địa chỉ: ${event.locationAddress.trim()}',
                            en: 'Address: ${event.locationAddress.trim()}',
                          ),
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                      AddressDirectionIconButton(
                        address: event.locationAddress.trim(),
                        iconSize: 18,
                      ),
                    ],
                  ),
                ],
              ],
            );
          },
        ),
      ),
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
    try {
      final myRequests = await widget.discoveryRepository.loadMyJoinRequests(
        session: widget.session,
      );
      hasMyRequests = myRequests.isNotEmpty;
    } catch (_) {
      hasMyRequests = false;
    }

    if (_canReviewJoinRequests) {
      try {
        final pendingForReview = await widget.discoveryRepository
            .loadPendingJoinRequests(session: widget.session);
        hasPendingReview = pendingForReview.isNotEmpty;
      } catch (_) {
        hasPendingReview = false;
      }
    }

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
            for (final entry in tasks.take(4))
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
    this.settingsTarget,
  });

  final List<_NearbyRelative> items;
  final String message;
  final bool canRetry;
  final _NearbySettingsTarget? settingsTarget;

  bool get hasItems => items.isNotEmpty;
}

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

  late Future<_NearbyRelativeLoadResult> _future;

  CollectionReference<Map<String, dynamic>> get _membersCollection =>
      FirebaseServices.firestore.collection('members');

  @override
  void initState() {
    super.initState();
    _future = _loadNearbyRelatives();
  }

  @override
  void didUpdateWidget(covariant _NearbyRelativesSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session != widget.session ||
        oldWidget.memberRepository != widget.memberRepository) {
      _future = _loadNearbyRelatives();
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

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return _NearbyRelativeLoadResult(
        items: const [],
        canRetry: permission != LocationPermission.deniedForever,
        message: l10n.pick(
          vi: 'Bạn chưa cấp quyền vị trí. Cấp quyền để xem khoảng cách người thân.',
          en: 'Location permission is required to calculate nearby relative distances.',
        ),
        settingsTarget: _NearbySettingsTarget.appPermission,
      );
    }

    late final Position currentPosition;
    try {
      currentPosition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );
    } catch (_) {
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
      try {
        await widget.memberRepository.updateMemberLiveLocation(
          session: widget.session,
          memberId: activeMemberId,
          sharingEnabled: true,
          latitude: currentPosition.latitude,
          longitude: currentPosition.longitude,
          accuracyMeters: currentPosition.accuracy,
        );
      } catch (_) {
        // Keep nearby discovery functional even if live-location sync fails.
      }
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
    setState(() {
      _future = _loadNearbyRelatives();
    });
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: FutureBuilder<_NearbyRelativeLoadResult>(
          future: _future,
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
                  Expanded(
                    child: Text(
                      l10n.pick(
                        vi: 'Đang tìm người thân ở gần bạn...',
                        en: 'Finding nearby relatives...',
                      ),
                    ),
                  ),
                ],
              );
            }

            final result = snapshot.data;
            if (result == null) {
              return _NearbyRelativesEmpty(
                message: l10n.pick(
                  vi: 'Không tải được danh sách người thân ở gần. Vui lòng thử lại.',
                  en: 'Unable to load nearby relatives. Please try again.',
                ),
                canRetry: true,
                onRetry: _reload,
                onRadarScan: _reload,
                onOpenSettings: _openNearbySettings,
              );
            }

            if (!result.hasItems) {
              return _NearbyRelativesEmpty(
                message: result.message,
                canRetry: result.canRetry,
                onRetry: _reload,
                onRadarScan: _reload,
                settingsTarget: result.settingsTarget,
                onOpenSettings: _openNearbySettings,
              );
            }

            final previewItems = result.items.take(3).toList(growable: false);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.near_me_outlined,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.pick(
                          vi: 'Người thân ở gần bạn',
                          en: 'Relatives nearby',
                        ),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: l10n.pick(
                        vi: 'Rà lại người thân gần đây',
                        en: 'Rescan nearby relatives',
                      ),
                      onPressed: _reload,
                      icon: const Icon(Icons.radar),
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints.tightFor(
                        width: 36,
                        height: 36,
                      ),
                    ),
                    TextButton(
                      onPressed: () => _openNearbySheet(result.items),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        minimumSize: const Size(0, 32),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        l10n.pick(vi: 'Xem danh sách', en: 'View list'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(result.message, style: theme.textTheme.bodyMedium),
                const SizedBox(height: 8),
                for (final item in previewItems)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.person_pin_circle_outlined),
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
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
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
                              style: theme.textTheme.labelLarge,
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
              ],
            );
          },
        ),
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

class _NearbyRelativesEmpty extends StatelessWidget {
  const _NearbyRelativesEmpty({
    required this.message,
    required this.canRetry,
    required this.onRetry,
    required this.onRadarScan,
    this.settingsTarget,
    this.onOpenSettings,
  });

  final String message;
  final bool canRetry;
  final VoidCallback onRetry;
  final VoidCallback onRadarScan;
  final _NearbySettingsTarget? settingsTarget;
  final Future<void> Function(_NearbySettingsTarget target)? onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.near_me_disabled_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l10n.pick(vi: 'Người thân ở gần bạn', en: 'Relatives nearby'),
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            IconButton(
              tooltip: l10n.pick(
                vi: 'Rà lại người thân gần đây',
                en: 'Rescan nearby relatives',
              ),
              onPressed: onRadarScan,
              icon: const Icon(Icons.radar),
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints.tightFor(width: 36, height: 36),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(message),
        if (settingsTarget != null && onOpenSettings != null) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => unawaited(onOpenSettings!(settingsTarget!)),
            icon: const Icon(Icons.open_in_new),
            label: Text(switch (settingsTarget!) {
              _NearbySettingsTarget.appPermission => l10n.pick(
                vi: 'Mở cài đặt quyền vị trí',
                en: 'Open app location permission',
              ),
              _NearbySettingsTarget.locationService => l10n.pick(
                vi: 'Mở dịch vụ vị trí của máy',
                en: 'Open device location services',
              ),
            }),
          ),
        ],
        if (canRetry) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: Text(l10n.notificationInboxRetryAction),
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

extension _IterableFirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
