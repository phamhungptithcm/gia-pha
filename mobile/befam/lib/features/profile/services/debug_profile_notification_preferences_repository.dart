import '../../auth/models/auth_session.dart';
import '../models/profile_notification_preferences.dart';
import 'profile_notification_preferences_repository.dart';

class DebugProfileNotificationPreferencesRepository
    implements ProfileNotificationPreferencesRepository {
  DebugProfileNotificationPreferencesRepository._();

  factory DebugProfileNotificationPreferencesRepository.shared() {
    return _shared;
  }

  static final DebugProfileNotificationPreferencesRepository _shared =
      DebugProfileNotificationPreferencesRepository._();

  final Map<String, ProfileNotificationPreferences> _preferencesByUid = {};

  @override
  bool get isSandbox => true;

  @override
  Future<ProfileNotificationPreferences> load({
    required AuthSession session,
  }) async {
    final uid = session.uid.trim();
    if (uid.isEmpty) {
      return const ProfileNotificationPreferences();
    }
    return _preferencesByUid[uid] ?? const ProfileNotificationPreferences();
  }

  @override
  Future<ProfileNotificationPreferences> save({
    required AuthSession session,
    required ProfileNotificationPreferences preferences,
  }) async {
    final uid = session.uid.trim();
    if (uid.isEmpty) {
      return preferences;
    }
    _preferencesByUid[uid] = preferences;
    return preferences;
  }
}
