import 'package:shared_preferences/shared_preferences.dart';

abstract class AuthPrivacyPolicyStore {
  Future<bool> readAccepted();

  Future<void> writeAccepted(bool accepted);
}

class SharedPrefsAuthPrivacyPolicyStore implements AuthPrivacyPolicyStore {
  static const String _acceptedKey = 'befam.auth.privacy_policy.accepted';

  @override
  Future<bool> readAccepted() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_acceptedKey) ?? false;
  }

  @override
  Future<void> writeAccepted(bool accepted) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_acceptedKey, accepted);
  }
}

class InMemoryAuthPrivacyPolicyStore implements AuthPrivacyPolicyStore {
  InMemoryAuthPrivacyPolicyStore({this.accepted = false});

  bool accepted;

  @override
  Future<bool> readAccepted() async => accepted;

  @override
  Future<void> writeAccepted(bool value) async {
    accepted = value;
  }
}
