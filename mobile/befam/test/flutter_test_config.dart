import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  try {
    final app = Firebase.app();
    final storageBucket = app.options.storageBucket?.trim() ?? '';
    if (storageBucket.isEmpty) {
      await app.delete();
      await _initializeTestFirebaseApp();
    }
  } on FirebaseException catch (error) {
    if (error.code == 'no-app') {
      await _initializeTestFirebaseApp();
    } else if (error.code != 'duplicate-app') {
      rethrow;
    }
  } catch (_) {
    await _initializeTestFirebaseApp();
  }

  await testMain();
}

Future<void> _initializeTestFirebaseApp() async {
  try {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: 'test-api-key',
        appId: '1:1234567890:web:test',
        messagingSenderId: '1234567890',
        projectId: 'befam-test',
        storageBucket: 'befam-test.appspot.com',
      ),
    );
  } on FirebaseException catch (error) {
    if (error.code != 'duplicate-app') {
      rethrow;
    }
  }
}
