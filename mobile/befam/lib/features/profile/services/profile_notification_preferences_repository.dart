import '../../../core/services/runtime_mode.dart';
import '../../auth/models/auth_session.dart';
import '../models/profile_notification_preferences.dart';
import 'debug_profile_notification_preferences_repository.dart';
import 'firebase_profile_notification_preferences_repository.dart';

abstract interface class ProfileNotificationPreferencesRepository {
  bool get isSandbox;

  Future<ProfileNotificationPreferences> load({required AuthSession session});

  Future<ProfileNotificationPreferences> save({
    required AuthSession session,
    required ProfileNotificationPreferences preferences,
  });
}

ProfileNotificationPreferencesRepository
createDefaultProfileNotificationPreferencesRepository({AuthSession? session}) {
  final useMockBackend = session?.isSandbox ?? RuntimeMode.shouldUseMockBackend;
  if (useMockBackend) {
    return DebugProfileNotificationPreferencesRepository.shared();
  }

  return FirebaseProfileNotificationPreferencesRepository();
}
