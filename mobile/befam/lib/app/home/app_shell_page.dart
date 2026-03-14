import 'dart:async';

import 'package:flutter/material.dart';

import '../../features/clan/presentation/clan_detail_page.dart';
import '../../features/clan/services/clan_repository.dart';
import '../../features/events/presentation/event_workspace_page.dart';
import '../../features/events/services/event_repository.dart';
import '../../features/funds/presentation/fund_workspace_page.dart';
import '../../features/funds/services/fund_repository.dart';
import '../../features/genealogy/presentation/genealogy_workspace_page.dart';
import '../../features/genealogy/services/genealogy_read_repository.dart';
import '../../features/member/presentation/member_workspace_page.dart';
import '../../features/member/services/member_repository.dart';
import '../../features/notifications/services/push_notification_service.dart';
import '../../features/scholarship/presentation/scholarship_workspace_page.dart';
import '../../features/scholarship/services/scholarship_repository.dart';
import '../../l10n/l10n.dart';
import '../../features/auth/models/auth_entry_method.dart';
import '../../features/auth/models/auth_member_access_mode.dart';
import '../../features/auth/models/auth_session.dart';
import '../../features/auth/services/phone_number_formatter.dart';
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
    this.eventRepository,
    this.fundRepository,
    this.genealogyRepository,
    this.pushNotificationService,
    this.onLogoutRequested,
  });

  final FirebaseSetupStatus status;
  final AuthSession session;
  final ClanRepository clanRepository;
  final MemberRepository memberRepository;
  final EventRepository? eventRepository;
  final FundRepository? fundRepository;
  final GenealogyReadRepository? genealogyRepository;
  final PushNotificationService? pushNotificationService;
  final Future<void> Function()? onLogoutRequested;

  @override
  State<AppShellPage> createState() => _AppShellPageState();
}

class _AppShellPageState extends State<AppShellPage> {
  int _selectedIndex = 0;
  late final GenealogyReadRepository _genealogyRepository;
  late final EventRepository _eventRepository;
  late final FundRepository _fundRepository;
  late final PushNotificationService _pushNotificationService;

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
      id: 'profile',
      icon: Icons.person_outline,
      selectedIcon: Icons.person,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _genealogyRepository =
        widget.genealogyRepository ?? createDefaultGenealogyReadRepository();
    _eventRepository = widget.eventRepository ?? createDefaultEventRepository();
    _fundRepository = widget.fundRepository ?? createDefaultFundRepository();
    _pushNotificationService =
        widget.pushNotificationService ??
        createDefaultPushNotificationService();
    unawaited(
      _pushNotificationService.start(
        session: widget.session,
        onDeepLink: _handleNotificationDeepLink,
      ),
    );
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

    if (deepLink.openedFromSystemNotification &&
        deepLink.targetType == NotificationTargetType.event) {
      setState(() {
        _selectedIndex = 2;
      });
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

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final destination = _destinations[_selectedIndex];
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
          });
        },
        onOpenEventsRequested: () {
          setState(() {
            _selectedIndex = 2;
          });
        },
      ),
      GenealogyWorkspacePage(
        session: widget.session,
        repository: _genealogyRepository,
      ),
      EventWorkspacePage(session: widget.session, repository: _eventRepository),
      _ComingSoonPane(
        title: l10n.shellProfileWorkspaceTitle,
        description: l10n.shellProfileWorkspaceDescription,
        icon: Icons.person,
      ),
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
                  await widget.onLogoutRequested?.call();
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
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: [
          for (final destination in _destinations)
            NavigationDestination(
              icon: Icon(destination.icon),
              selectedIcon: Icon(destination.selectedIcon),
              label: l10n.shellDestinationLabel(destination.id),
            ),
        ],
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
    required this.onOpenEventsRequested,
  });

  final FirebaseSetupStatus status;
  final AuthSession session;
  final ClanRepository clanRepository;
  final MemberRepository memberRepository;
  final FundRepository fundRepository;
  final VoidCallback onOpenTreeRequested;
  final VoidCallback onOpenEventsRequested;

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
                    ? l10n.shellSignedInMethod(
                        l10n.authEntryMethodInline(session.loginMethod),
                      )
                    : l10n.shellCloudSetupNeeded,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onPrimary.withValues(alpha: 0.9),
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _FoundationTag(
                    label: l10n.shellTagFreezedJson,
                    tone: colorScheme.secondaryContainer,
                  ),
                  _FoundationTag(
                    label: l10n.shellTagFirebaseCore,
                    tone: colorScheme.secondaryContainer,
                  ),
                  _FoundationTag(
                    label: l10n.shellTagAuthSessionLive,
                    tone: colorScheme.secondaryContainer,
                  ),
                  _FoundationTag(
                    label: status.isCrashReportingEnabled
                        ? l10n.shellTagCrashlyticsEnabled
                        : l10n.shellTagLocalLoggerActive,
                    tone: colorScheme.surfaceContainerHighest,
                  ),
                  _FoundationTag(
                    label: l10n.shellTagShellPlaceholders,
                    tone: colorScheme.surfaceContainerHighest,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _MemberAccessCard(session: session),
        const SizedBox(height: 24),
        Text(
          l10n.shellPriorityWorkspaces,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.shellPriorityWorkspacesDescription,
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: bootstrapShortcuts.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.24,
          ),
          itemBuilder: (context, index) {
            final shortcut = bootstrapShortcuts[index];
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
    return switch (shortcutId) {
      'clan' => () {
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
                repository: createDefaultScholarshipRepository(),
              );
            },
          ),
        );
      },
      'tree' => onOpenTreeRequested,
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
                l10n.shortcutDescription(shortcut.id),
                style: theme.textTheme.bodyMedium,
              ),
              const Spacer(),
              const SizedBox(height: 12),
              Text(
                shortcut.route,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
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

class _FoundationTag extends StatelessWidget {
  const _FoundationTag({required this.label, required this.tone});

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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
        l10n.shellMemberAccessClaimedDescription,
        Icons.verified_user_outlined,
        colorScheme.primaryContainer,
      ),
      AuthMemberAccessMode.child => (
        l10n.shellMemberAccessChildTitle,
        l10n.shellMemberAccessChildDescription,
        Icons.family_restroom_outlined,
        colorScheme.secondaryContainer,
      ),
      AuthMemberAccessMode.unlinked => (
        l10n.shellMemberAccessUnlinkedTitle,
        l10n.shellMemberAccessUnlinkedDescription,
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

class _ComingSoonPane extends StatelessWidget {
  const _ComingSoonPane({
    required this.title,
    required this.description,
    required this.icon,
  });

  final String title;
  final String description;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: colorScheme.primaryContainer,
                    child: Icon(icon, size: 32),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
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
