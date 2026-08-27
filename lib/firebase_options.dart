import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

/// Firebase configuration for the HRMS application.
///
/// Android and Web are connected to the `forum-d8b06` Firebase project.
/// Additional platform options stay intentionally unconfigured until their
/// platform-specific SDK configuration is verified.
class DefaultFirebaseOptions {
  DefaultFirebaseOptions._();

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;

    return switch (defaultTargetPlatform) {
      TargetPlatform.android => android,
      TargetPlatform.iOS => ios,
      TargetPlatform.macOS => macos,
      TargetPlatform.windows => windows,
      TargetPlatform.linux => throw UnsupportedError(
        'Firebase is not configured for Linux in this project.',
      ),
      _ => throw UnsupportedError(
        'Firebase is not supported on this platform.',
      ),
    };
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDXsatA5ZS-DPx6Qeln82xx09vV_fZ0c_A',
    appId: '1:432151378389:web:4855684f73f14ab89ae55c',
    messagingSenderId: '432151378389',
    projectId: 'forum-d8b06',
    authDomain: 'forum-d8b06.firebaseapp.com',
    storageBucket: 'forum-d8b06.firebasestorage.app',
    measurementId: 'G-6SL7DF76MQ',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCsLkqvvsezTUJ6hTWF0aNetufnJAz7ghY',
    appId: '1:432151378389:android:decaf3933abe61719ae55c',
    messagingSenderId: '432151378389',
    projectId: 'forum-d8b06',
    storageBucket: 'forum-d8b06.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'FIREBASE_NOT_CONFIGURED',
    appId: 'FIREBASE_NOT_CONFIGURED',
    messagingSenderId: 'FIREBASE_NOT_CONFIGURED',
    projectId: 'FIREBASE_NOT_CONFIGURED',
    storageBucket: 'FIREBASE_NOT_CONFIGURED',
    iosBundleId: 'com.qrscanning.hrms',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'FIREBASE_NOT_CONFIGURED',
    appId: 'FIREBASE_NOT_CONFIGURED',
    messagingSenderId: 'FIREBASE_NOT_CONFIGURED',
    projectId: 'FIREBASE_NOT_CONFIGURED',
    storageBucket: 'FIREBASE_NOT_CONFIGURED',
    iosBundleId: 'com.qrscanning.hrms',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'FIREBASE_NOT_CONFIGURED',
    appId: 'FIREBASE_NOT_CONFIGURED',
    messagingSenderId: 'FIREBASE_NOT_CONFIGURED',
    projectId: 'FIREBASE_NOT_CONFIGURED',
    authDomain: 'FIREBASE_NOT_CONFIGURED',
    storageBucket: 'FIREBASE_NOT_CONFIGURED',
  );
}
