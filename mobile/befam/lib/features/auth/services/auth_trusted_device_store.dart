import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

abstract class AuthTrustedDeviceStore {
  Future<String> readOrCreateDeviceToken();
}

class SharedPrefsAuthTrustedDeviceStore implements AuthTrustedDeviceStore {
  SharedPrefsAuthTrustedDeviceStore({SharedPreferences? preferences})
      : _preferences = preferences;

  static const _deviceTokenKey = 'auth_trusted_device_token';
  final SharedPreferences? _preferences;

  @override
  Future<String> readOrCreateDeviceToken() async {
    final prefs = _preferences ?? await SharedPreferences.getInstance();
    final existing = prefs.getString(_deviceTokenKey)?.trim() ?? '';
    if (existing.length >= 16) {
      return existing;
    }

    final random = Random.secure();
    final bytes = List<int>.generate(24, (_) => random.nextInt(256));
    final generated = base64Url.encode(bytes).replaceAll('=', '');
    await prefs.setString(_deviceTokenKey, generated);
    return generated;
  }
}

