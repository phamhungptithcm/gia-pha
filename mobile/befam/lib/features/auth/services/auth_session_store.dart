import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/auth_session.dart';

abstract class AuthSessionStore {
  Future<AuthSession?> read();

  Future<void> write(AuthSession session);

  Future<void> clear();
}

class SharedPrefsAuthSessionStore implements AuthSessionStore {
  static const String _sessionKey = 'befam.auth.session';

  @override
  Future<AuthSession?> read() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_sessionKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }

    return AuthSession.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  @override
  Future<void> write(AuthSession session) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_sessionKey, jsonEncode(session.toJson()));
  }

  @override
  Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_sessionKey);
  }
}

class InMemoryAuthSessionStore implements AuthSessionStore {
  AuthSession? _session;

  @override
  Future<AuthSession?> read() async => _session;

  @override
  Future<void> write(AuthSession session) async {
    _session = session;
  }

  @override
  Future<void> clear() async {
    _session = null;
  }
}
