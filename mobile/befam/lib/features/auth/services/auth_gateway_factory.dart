import 'auth_gateway.dart';
import 'firebase_auth_gateway.dart';

AuthGateway createDefaultAuthGateway() {
  return FirebaseAuthGateway();
}
