import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'firebase_bootstrap.dart';

class FirebaseServices {
  FirebaseServices._();

  static void _ensureConnected() {
    if (!FirebaseBootstrap.result.isConnected) {
      throw StateError(
        'Firebase is not connected. Complete FlutterFire configuration first.',
      );
    }
  }

  static FirebaseAuth get auth {
    _ensureConnected();
    return FirebaseAuth.instance;
  }

  static FirebaseFirestore get firestore {
    _ensureConnected();
    return FirebaseFirestore.instance;
  }

  static FirebaseFunctions get functions {
    _ensureConnected();
    return FirebaseFunctions.instanceFor(region: 'asia-southeast1');
  }

  static FirebaseStorage get storage {
    _ensureConnected();
    return FirebaseStorage.instance;
  }

  static FirebaseMessaging get messaging {
    _ensureConnected();
    return FirebaseMessaging.instance;
  }
}
