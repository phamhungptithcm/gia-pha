import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/services/app_environment.dart';
import 'auth_gateway.dart';
import 'firebase_auth_gateway.dart';
import 'mock_auth_gateway.dart';

AuthGateway createDefaultAuthGateway() {
  if (AppEnvironment.useMockAuth) {
    return MockAuthGateway(
      firestore: AppEnvironment.useRemoteDebugLoginProfiles
          ? FirebaseFirestore.instance
          : null,
    );
  }
  return FirebaseAuthGateway();
}
