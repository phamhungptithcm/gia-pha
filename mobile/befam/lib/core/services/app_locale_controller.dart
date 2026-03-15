import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'app_locale_store.dart';

class AppLocaleController extends ChangeNotifier {
  AppLocaleController({
    AppLocaleStore? store,
    Locale defaultLocale = const Locale('vi'),
  }) : _store = store ?? SharedPrefsAppLocaleStore(),
       _locale = defaultLocale;

  static const supportedLanguageCodes = {'vi', 'en'};

  final AppLocaleStore _store;
  Locale _locale;
  bool _isLoading = false;
  bool _hasLoaded = false;

  Locale get locale => _locale;
  bool get hasLoaded => _hasLoaded;

  Future<void> load() async {
    if (_isLoading || _hasLoaded) {
      return;
    }
    _isLoading = true;
    try {
      final savedLanguageCode = await _store.readLanguageCode();
      if (savedLanguageCode == null) {
        return;
      }
      final normalized = savedLanguageCode.toLowerCase();
      if (!supportedLanguageCodes.contains(normalized)) {
        return;
      }
      if (_locale.languageCode != normalized) {
        _locale = Locale(normalized);
        notifyListeners();
      }
    } finally {
      _isLoading = false;
      _hasLoaded = true;
    }
  }

  Future<void> updateLanguageCode(String languageCode) async {
    final normalized = languageCode.trim().toLowerCase();
    if (!supportedLanguageCodes.contains(normalized)) {
      return;
    }
    if (_locale.languageCode == normalized) {
      return;
    }

    _locale = Locale(normalized);
    notifyListeners();
    await _store.writeLanguageCode(normalized);
  }
}
