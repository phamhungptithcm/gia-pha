import '../models/app_shortcut.dart';

final List<AppShortcut> bootstrapShortcuts = List.unmodifiable(
  _bootstrapShortcutSeed.map(AppShortcut.fromJson),
);

const List<Map<String, dynamic>> _bootstrapShortcutSeed = [
  {
    'id': 'tree',
    'title': 'Family Tree',
    'description':
        'Start the genealogy experience with branch-aware tree navigation.',
    'route': '/tree',
    'iconKey': 'tree',
    'status': 'bootstrap',
    'isPrimary': true,
  },
  {
    'id': 'members',
    'title': 'Members',
    'description':
        'View member profiles, claim records, and prepare the first data flows.',
    'route': '/members',
    'iconKey': 'members',
    'status': 'bootstrap',
    'isPrimary': true,
  },
  {
    'id': 'events',
    'title': 'Events',
    'description':
        'Plan clan events, memorial days, and reminders from a shared calendar.',
    'route': '/events',
    'iconKey': 'events',
    'status': 'planned',
    'isPrimary': true,
  },
  {
    'id': 'funds',
    'title': 'Funds',
    'description':
        'Track contribution funds, transaction history, and transparent balances.',
    'route': '/funds',
    'iconKey': 'funds',
    'status': 'planned',
  },
  {
    'id': 'scholarship',
    'title': 'Scholarships',
    'description':
        'Capture student achievements and later connect awards to family branches.',
    'route': '/scholarship',
    'iconKey': 'scholarship',
    'status': 'planned',
  },
  {
    'id': 'profile',
    'title': 'Profile',
    'description':
        'Reserve a personal space for member settings, guardianship, and context.',
    'route': '/profile',
    'iconKey': 'profile',
    'status': 'live',
  },
];
