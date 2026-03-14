import 'package:shared_preferences/shared_preferences.dart';

abstract interface class AppLocaleStore {
  Future<String?> readLanguageCode();

  Future<void> writeLanguageCode(String languageCode);
}

class SharedPrefsAppLocaleStore implements AppLocaleStore {
  SharedPrefsAppLocaleStore({SharedPreferences? preferences})
    : _preferences = preferences;

  static const _languageCodeKey = 'app.locale.language_code';

  final SharedPreferences? _preferences;
  SharedPreferences? _instance;

  @override
  Future<String?> readLanguageCode() async {
    final preferences = await _getPreferences();
    final languageCode = preferences.getString(_languageCodeKey)?.trim();
    if (languageCode == null || languageCode.isEmpty) {
      return null;
    }
    return languageCode;
  }

  @override
  Future<void> writeLanguageCode(String languageCode) async {
    final preferences = await _getPreferences();
    await preferences.setString(_languageCodeKey, languageCode.trim());
  }

  Future<SharedPreferences> _getPreferences() async {
    final existing = _instance ?? _preferences;
    if (existing != null) {
      _instance = existing;
      return existing;
    }
    final loaded = await SharedPreferences.getInstance();
    _instance = loaded;
    return loaded;
  }
}
