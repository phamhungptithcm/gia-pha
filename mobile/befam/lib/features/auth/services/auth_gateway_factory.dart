import 'package:flutter/foundation.dart';

import 'auth_gateway.dart';
import 'debug_auth_gateway.dart';
import 'firebase_auth_gateway.dart';

AuthGateway createDefaultAuthGateway() {
  const useLiveAuth = bool.fromEnvironment('BEFAM_USE_LIVE_AUTH');
  if (kDebugMode && !useLiveAuth) {
    return DebugAuthGateway();
  }

  return FirebaseAuthGateway();
}
