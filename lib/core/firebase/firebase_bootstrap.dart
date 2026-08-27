import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../../firebase_options.dart';

enum FirebaseConnectionState { connected, notConfigured, failed }

class FirebaseBootstrapResult {
  const FirebaseBootstrapResult._({required this.state, this.error});

  const FirebaseBootstrapResult.connected()
    : this._(state: FirebaseConnectionState.connected);

  const FirebaseBootstrapResult.notConfigured()
    : this._(state: FirebaseConnectionState.notConfigured);

  const FirebaseBootstrapResult.failed(Object error)
    : this._(state: FirebaseConnectionState.failed, error: error);

  final FirebaseConnectionState state;
  final Object? error;

  bool get isConnected => state == FirebaseConnectionState.connected;
}

class FirebaseBootstrap {
  FirebaseBootstrap._();

  static const _placeholderProjectId = 'FIREBASE_NOT_CONFIGURED';

  static FirebaseBootstrapResult _result =
      const FirebaseBootstrapResult.notConfigured();

  static FirebaseBootstrapResult get result => _result;

  static Future<FirebaseBootstrapResult> initialize() async {
    try {
      final options = DefaultFirebaseOptions.currentPlatform;

      if (options.projectId == _placeholderProjectId) {
        _result = const FirebaseBootstrapResult.notConfigured();
        debugPrint(
          'Firebase is not configured yet. Run `flutterfire configure`.',
        );
        return _result;
      }

      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(options: options);
      }

      _result = const FirebaseBootstrapResult.connected();
      debugPrint('Firebase connected: ${Firebase.app().options.projectId}');
      return _result;
    } catch (error, stackTrace) {
      _result = FirebaseBootstrapResult.failed(error);
      debugPrint('Firebase initialization failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return _result;
    }
  }
}
