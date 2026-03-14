import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../features/auth/models/auth_entry_method.dart';
import '../../features/auth/models/auth_session.dart';
import '../bootstrap/firebase_setup_status.dart';
import '../models/app_shortcut.dart';
import 'app_shortcuts.dart';

class AppShellPage extends StatefulWidget {
  const AppShellPage({
    super.key,
    required this.status,
    required this.session,
    this.onLogoutRequested,
  });

  final FirebaseSetupStatus status;
  final AuthSession session;
  final Future<void> Function()? onLogoutRequested;

  @override
  State<AppShellPage> createState() => _AppShellPageState();
}

class _AppShellPageState extends State<AppShellPage> {
  int _selectedIndex = 0;

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
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final destination = _destinations[_selectedIndex];
    final pages = [
      _HomeDashboard(status: widget.status, session: widget.session),
      _ComingSoonPane(
        title: l10n.shellTreeWorkspaceTitle,
        description: l10n.shellTreeWorkspaceDescription,
        icon: Icons.account_tree,
      ),
      _ComingSoonPane(
        title: l10n.shellEventsWorkspaceTitle,
        description: l10n.shellEventsWorkspaceDescription,
        icon: Icons.event,
      ),
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
              padding: const EdgeInsets.only(right: 8),
              child: Align(
                alignment: Alignment.center,
                child: _SessionChip(session: widget.session),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Align(
              alignment: Alignment.center,
              child: _ReadinessChip(status: widget.status),
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
  const _HomeDashboard({required this.status, required this.session});

  final FirebaseSetupStatus status;
  final AuthSession session;

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
            return _ShortcutCard(shortcut: shortcut);
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
                  value: session.phoneE164,
                ),
                if (session.childIdentifier != null)
                  _FoundationRow(
                    label: l10n.shellFieldChildId,
                    value: session.childIdentifier!,
                  ),
                if (session.memberId != null)
                  _FoundationRow(
                    label: l10n.shellFieldMemberId,
                    value: session.memberId!,
                  ),
                _FoundationRow(
                  label: l10n.shellFieldSessionType,
                  value: session.isSandbox
                      ? l10n.shellSessionTypeSandbox
                      : l10n.shellSessionTypeFirebase,
                  isLast: false,
                ),
                _FoundationRow(
                  label: l10n.shellFieldFirebaseProject,
                  value: status.projectId,
                ),
                _FoundationRow(
                  label: l10n.shellFieldStorageBucket,
                  value: status.storageBucket,
                ),
                _FoundationRow(
                  label: l10n.shellFieldCrashHandling,
                  value: status.isCrashReportingEnabled
                      ? l10n.shellCrashHandlingRelease
                      : l10n.shellCrashHandlingLocal,
                ),
                _FoundationRow(
                  label: l10n.shellFieldCoreServices,
                  value: status.isReady
                      ? status.enabledServices.join(', ')
                      : l10n.shellCoreServicesWaiting,
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
}

class _ShortcutCard extends StatelessWidget {
  const _ShortcutCard({required this.shortcut});

  final AppShortcut shortcut;

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

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
      child: Row(
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

class _ReadinessChip extends StatelessWidget {
  const _ReadinessChip({required this.status});

  final FirebaseSetupStatus status;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Chip(
      avatar: Icon(
        status.isReady ? Icons.check_circle : Icons.pending,
        size: 18,
        color: status.isReady
            ? colorScheme.onPrimaryContainer
            : colorScheme.onSecondaryContainer,
      ),
      label: Text(
        status.isReady
            ? context.l10n.shellReadinessReady
            : context.l10n.shellReadinessPending,
      ),
      backgroundColor: status.isReady
          ? colorScheme.primaryContainer
          : colorScheme.secondaryContainer,
      side: BorderSide.none,
    );
  }
}

class _SessionChip extends StatelessWidget {
  const _SessionChip({required this.session});

  final AuthSession session;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Chip(
      avatar: Icon(
        session.loginMethod == AuthEntryMethod.phone
            ? Icons.phone_iphone
            : Icons.child_care,
        size: 18,
      ),
      label: Text(context.l10n.authEntryMethodSummary(session.loginMethod)),
      backgroundColor: session.isSandbox
          ? colorScheme.secondaryContainer
          : colorScheme.surfaceContainerHighest,
      side: BorderSide.none,
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
    'tree' => Icons.account_tree_outlined,
    'members' => Icons.groups_2_outlined,
    'events' => Icons.event_note_outlined,
    'funds' => Icons.volunteer_activism_outlined,
    'scholarship' => Icons.school_outlined,
    'profile' => Icons.person_outline,
    _ => Icons.widgets_outlined,
  };
}
