import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../theme/app_ui_tokens.dart';
import '../../core/services/firebase_services.dart';
import '../../core/widgets/member_phone_action.dart';
import '../../core/widgets/address_action_tools.dart';
import '../../core/widgets/app_compact_controls.dart';
import '../../core/widgets/app_loading_skeletons.dart';
import '../../features/ads/services/ad_controller.dart';
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
import '../../features/onboarding/models/onboarding_models.dart';
import '../../features/onboarding/presentation/onboarding_coordinator.dart';
import '../../features/onboarding/presentation/onboarding_scope.dart';
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

part 'app_shell_page_sections.dart';

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

class _AppShellPageState extends State<AppShellPage>
    with WidgetsBindingObserver {
  int _selectedIndex = 0;
  final Set<int> _visitedDestinationIndexes = <int>{0};
  late AuthSession _activeSession;
  late final GenealogyReadRepository _genealogyRepository;
  late final GenealogyDiscoveryRepository _genealogyDiscoveryRepository;
  late final EventRepository _eventRepository;
  late final FundRepository _fundRepository;
  late final BillingRepository _billingRepository;
  late final AdController _adController;
  late final PushNotificationService _pushNotificationService;
  late final ClanContextService _clanContextService;
  late final OnboardingCoordinator _onboardingCoordinator;
  final AuthSessionStore _sessionStore = SharedPrefsAuthSessionStore();
  String? _lastOpenedNotificationMessageId;
  bool _showAdBanner = false;
  bool _isResolvingBillingEntitlement = false;
  bool _dismissAdBannerForSession = false;
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
    WidgetsBinding.instance.addObserver(this);
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
    _adController = AdController(onStateChanged: _handleAdStateChanged);
    unawaited(
      _adController.initialize(
        initialScreenId: _screenIdForIndex(_selectedIndex),
      ),
    );
    _pushNotificationService =
        widget.pushNotificationService ??
        createDefaultPushNotificationService(session: _session);
    _clanContextService =
        widget.clanContextService ??
        createDefaultClanContextService(session: _session);
    _onboardingCoordinator = createDefaultOnboardingCoordinator(
      session: _session,
    );
    unawaited(
      _pushNotificationService.start(
        session: _session,
        onDeepLink: _handleNotificationDeepLink,
      ),
    );
    unawaited(_loadClanContexts());
    unawaited(_ensureActiveClanDisplayNameResolved());
    unawaited(_refreshBillingEntitlement());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(
        _onboardingCoordinator.scheduleTrigger(
          const OnboardingTrigger(
            id: 'app_shell_home',
            routeId: 'app_shell_home',
          ),
        ),
      );
    });
  }

  @override
  void didUpdateWidget(covariant AppShellPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session != widget.session) {
      _activeSession = _sanitizeSessionContext(widget.session);
      _onboardingCoordinator.updateSession(_activeSession);
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
      _adController.updateCurrentScreen(_screenIdForIndex(_selectedIndex));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _adController.dispose();
    unawaited(_onboardingCoordinator.interrupt());
    _onboardingCoordinator.dispose();
    unawaited(_pushNotificationService.stop());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    unawaited(_adController.onAppLifecycleStateChanged(state));
  }

  void _handleAdStateChanged() {
    if (!mounted) {
      return;
    }
    setState(() {});
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
      final previousIndex = _selectedIndex;
      setState(() {
        _selectedIndex = destinationIndex;
        _visitedDestinationIndexes.add(destinationIndex);
      });
      _adController.recordNavigationTransition(
        fromScreenId: _screenIdForIndex(previousIndex),
        toScreenId: _screenIdForIndex(destinationIndex),
      );
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
        NotificationTargetType.authRefresh => l10n.notificationOpenedGeneral,
        NotificationTargetType.unknown => l10n.notificationOpenedGeneral,
      };
    }

    return switch (targetType) {
      NotificationTargetType.event => l10n.notificationForegroundEvent,
      NotificationTargetType.scholarship =>
        l10n.notificationForegroundScholarship,
      NotificationTargetType.billing => l10n.notificationForegroundGeneral,
      NotificationTargetType.authRefresh => l10n.notificationForegroundGeneral,
      NotificationTargetType.unknown => l10n.notificationForegroundGeneral,
    };
  }

  int? _destinationIndexForNotificationTarget(
    NotificationTargetType targetType,
  ) {
    return switch (targetType) {
      NotificationTargetType.event || NotificationTargetType.scholarship => 2,
      NotificationTargetType.billing => 3,
      NotificationTargetType.authRefresh => null,
      NotificationTargetType.unknown => null,
    };
  }

  bool get _isAdBannerVisible =>
      _showAdBanner &&
      !_dismissAdBannerForSession &&
      _adController.isBannerPlacementVisible;

  String _screenIdForIndex(int index) {
    final destinations = _hasClanContext
        ? _destinations
        : _unlinkedDestinations;
    if (index < 0 || index >= destinations.length) {
      return 'home';
    }
    return destinations[index].id;
  }

  void _selectDestination(int index) {
    if (index == _selectedIndex) {
      return;
    }
    final previousIndex = _selectedIndex;
    setState(() {
      _selectedIndex = index;
      _visitedDestinationIndexes.add(index);
      if (_screenIdForIndex(index) == 'billing') {
        _dismissAdBannerForSession = false;
      }
    });
    _adController.recordNavigationTransition(
      fromScreenId: _screenIdForIndex(previousIndex),
      toScreenId: _screenIdForIndex(index),
    );
  }

  Future<void> _refreshBillingEntitlement() async {
    if (_isResolvingBillingEntitlement) {
      return;
    }
    if (!_hasBillingContext(_session)) {
      final shouldShow = _adController.shouldShowAds(
        tier: 'FREE',
        backendShowAds: true,
      );
      _adController.updateAdPolicy(
        subscriptionTier: 'FREE',
        backendShowAds: true,
      );
      if (mounted) {
        setState(() {
          _showAdBanner = shouldShow;
        });
        _adController.updateCurrentScreen(_screenIdForIndex(_selectedIndex));
      }
      return;
    }

    _isResolvingBillingEntitlement = true;
    try {
      final entitlement = await _billingRepository.resolveEntitlement(
        session: _session,
      );
      final normalizedTier = entitlement.planCode.trim().toUpperCase();
      final resolvedTier = normalizedTier.isEmpty ? 'FREE' : normalizedTier;
      final shouldShow = _adController.shouldShowAds(
        tier: resolvedTier,
        backendShowAds: entitlement.showAds,
      );
      _adController.updateAdPolicy(
        subscriptionTier: resolvedTier,
        backendShowAds: entitlement.showAds,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _showAdBanner = shouldShow;
        if (!shouldShow) {
          _dismissAdBannerForSession = false;
        }
      });
      _adController.updateCurrentScreen(_screenIdForIndex(_selectedIndex));
    } catch (_) {
      // Keep current state when billing entitlement cannot be refreshed.
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
          _selectDestination(1);
        },
        onOpenEventsRequested: () {
          _selectDestination(2);
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
          _selectDestination(4);
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
                rewardedDiscoveryAttemptService: _adController,
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
            adController: _adController,
            onClose: () {
              setState(() {
                _dismissAdBannerForSession = true;
              });
            },
          ),
        Expanded(child: SafeArea(top: false, child: contentStack)),
      ],
    );

    final scaffold = layout.useRailNavigation
        ? Scaffold(
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
          )
        : Scaffold(
            appBar: appBar,
            body: SafeArea(child: contentStack),
            bottomNavigationBar: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isAdBannerVisible)
                  _SponsoredAdBanner(
                    adController: _adController,
                    onClose: () {
                      setState(() {
                        _dismissAdBannerForSession = true;
                      });
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
                          icon: _buildShellDestinationAnchor(
                            destination.id,
                            child: Icon(destination.icon),
                          ),
                          selectedIcon: Icon(destination.selectedIcon),
                          label: l10n.shellDestinationLabel(destination.id),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );

    return OnboardingScope(controller: _onboardingCoordinator, child: scaffold);
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
    _selectDestination(index);
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
    _adController.recordRouteReturn(
      screenId: _screenIdForIndex(_selectedIndex),
      routeId: 'clan_detail',
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
    _adController.recordRouteReturn(
      screenId: _screenIdForIndex(_selectedIndex),
      routeId: 'event_workspace',
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
    _adController.recordRouteReturn(
      screenId: _screenIdForIndex(_selectedIndex),
      routeId: 'event_detail',
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
      _adController.recordRouteReturn(
        screenId: _screenIdForIndex(_selectedIndex),
        routeId: 'join_request_review',
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
                      rewardedDiscoveryAttemptService: _adController,
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
    _adController.recordRouteReturn(
      screenId: _screenIdForIndex(_selectedIndex),
      routeId: 'my_join_requests',
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
                      rewardedDiscoveryAttemptService: _adController,
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
    _adController.recordRouteReturn(
      screenId: _screenIdForIndex(_selectedIndex),
      routeId: 'submitted_join_requests',
    );
  }
}
