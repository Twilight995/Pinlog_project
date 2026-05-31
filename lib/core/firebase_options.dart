import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAbflUYvVWWpJyVHKbBSJLpPe2rfVnUarQ',
    appId: '1:215622839769:ios:870a6ad1f9e41018987dc8',
    messagingSenderId: '215622839769',
    projectId: 'pinlog-ba4dc',
    storageBucket: 'pinlog-ba4dc.firebasestorage.app',
    iosBundleId: 'com.pinlog.app',
  );
}
