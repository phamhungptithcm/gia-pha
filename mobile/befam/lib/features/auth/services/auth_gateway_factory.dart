import '../../../core/services/runtime_mode.dart';
import 'auth_gateway.dart';
import 'debug_auth_gateway.dart';
import 'firebase_auth_gateway.dart';

AuthGateway createDefaultAuthGateway() {
  if (RuntimeMode.shouldUseMockBackend) {
    return DebugAuthGateway();
  }

  return FirebaseAuthGateway();
}
