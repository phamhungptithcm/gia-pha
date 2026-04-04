import '../models/app_shortcut.dart';

final List<AppShortcut> bootstrapShortcuts = List.unmodifiable(
  _bootstrapShortcutSeed.map(AppShortcut.fromJson),
);

const List<Map<String, dynamic>> _bootstrapShortcutSeed = [
  {
    'id': 'clan',
    'title': 'Clan',
    'description': 'View clan details and family branches.',
    'route': '/clan',
    'iconKey': 'clan',
    'status': 'live',
    'isPrimary': true,
  },
  {
    'id': 'tree',
    'title': 'Family Tree',
    'description': 'Explore the family tree and member relationships.',
    'route': '/tree',
    'iconKey': 'tree',
    'status': 'bootstrap',
    'isPrimary': true,
  },
  {
    'id': 'members',
    'title': 'Members',
    'description': 'Search and update member profiles quickly.',
    'route': '/members',
    'iconKey': 'members',
    'status': 'live',
    'isPrimary': true,
  },
  {
    'id': 'events',
    'title': 'Events',
    'description': 'Follow family events, memorial dates, and reminders.',
    'route': '/events',
    'iconKey': 'events',
    'status': 'live',
    'isPrimary': true,
  },
  {
    'id': 'funds',
    'title': 'Funds',
    'description': 'Track contributions, spending, and fund balance.',
    'route': '/funds',
    'iconKey': 'funds',
    'status': 'live',
  },
  {
    'id': 'scholarship',
    'title': 'Scholarships',
    'description': 'Review scholarship requests and student support.',
    'route': '/scholarship',
    'iconKey': 'scholarship',
    'status': 'planned',
  },
  {
    'id': 'profile',
    'title': 'Profile',
    'description': 'Update your profile and account settings.',
    'route': '/profile',
    'iconKey': 'profile',
    'status': 'live',
  },
];
