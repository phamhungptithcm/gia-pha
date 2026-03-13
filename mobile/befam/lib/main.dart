import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app/app.dart';
import 'core/services/firebase_services.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  late final FirebaseSetupStatus status;

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    status = FirebaseSetupStatus.ready(
      projectId: Firebase.app().options.projectId,
      storageBucket: Firebase.app().options.storageBucket ?? '',
      enabledServices: FirebaseServices.enabledServiceLabels,
    );
  } catch (error) {
    status = FirebaseSetupStatus.failed(
      projectId: DefaultFirebaseOptions.currentPlatform.projectId,
      storageBucket: DefaultFirebaseOptions.currentPlatform.storageBucket ?? '',
      errorMessage: error.toString(),
    );
  }

  runApp(BeFamApp(status: status));
}
