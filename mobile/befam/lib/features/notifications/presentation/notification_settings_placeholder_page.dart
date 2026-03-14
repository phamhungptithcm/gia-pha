import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';

class NotificationSettingsPlaceholderPage extends StatefulWidget {
  const NotificationSettingsPlaceholderPage({super.key});

  @override
  State<NotificationSettingsPlaceholderPage> createState() =>
      _NotificationSettingsPlaceholderPageState();
}

class _NotificationSettingsPlaceholderPageState
    extends State<NotificationSettingsPlaceholderPage> {
  bool _eventUpdates = true;
  bool _scholarshipUpdates = true;
  bool _generalUpdates = true;
  bool _quietHours = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        Container(
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
                l10n.notificationSettingsTitle,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: colorScheme.onPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                l10n.notificationSettingsDescription,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onPrimary.withValues(alpha: 0.92),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                key: const Key('notification-setting-event-updates'),
                value: _eventUpdates,
                onChanged: (value) {
                  setState(() {
                    _eventUpdates = value;
                  });
                },
                title: Text(l10n.notificationSettingsEventUpdates),
              ),
              SwitchListTile(
                key: const Key('notification-setting-scholarship-updates'),
                value: _scholarshipUpdates,
                onChanged: (value) {
                  setState(() {
                    _scholarshipUpdates = value;
                  });
                },
                title: Text(l10n.notificationSettingsScholarshipUpdates),
              ),
              SwitchListTile(
                key: const Key('notification-setting-general-updates'),
                value: _generalUpdates,
                onChanged: (value) {
                  setState(() {
                    _generalUpdates = value;
                  });
                },
                title: Text(l10n.notificationSettingsGeneralUpdates),
              ),
              SwitchListTile(
                key: const Key('notification-setting-quiet-hours'),
                value: _quietHours,
                onChanged: (value) {
                  setState(() {
                    _quietHours = value;
                  });
                },
                title: Text(l10n.notificationSettingsQuietHours),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Card(
          color: colorScheme.secondaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Text(
              l10n.notificationSettingsPlaceholderNote,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ),
      ],
    );
  }
}
