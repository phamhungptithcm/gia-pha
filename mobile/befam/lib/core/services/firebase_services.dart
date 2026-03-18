import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'app_environment.dart';

class FirebaseServices {
  FirebaseServices._();

  static FirebaseAuth get auth => FirebaseAuth.instance;
  static FirebaseAnalytics get analytics => FirebaseAnalytics.instance;
  static FirebaseFirestore get firestore => FirebaseFirestore.instance;
  static FirebaseFunctions get functions => FirebaseFunctions.instanceFor(
    region: AppEnvironment.firebaseFunctionsRegion,
  );
  static FirebaseStorage get storage => FirebaseStorage.instance;
  static FirebaseMessaging get messaging => FirebaseMessaging.instance;

  static List<String> get enabledServiceLabels => const [
    'Auth',
    'Analytics',
    'Firestore',
    'Functions',
    'Storage',
    'Messaging',
    'App Check',
  ];
}
