import 'dart:js_interop';

@JS()
extension type _FirebaseRuntimeConfig(JSObject _) implements JSObject {
  external String get FIREBASE_API_KEY;
  external String get FIREBASE_APP_ID;
  external String get FIREBASE_MESSAGING_SENDER_ID;
  external String get FIREBASE_PROJECT_ID;
  external String get FIREBASE_AUTH_DOMAIN;
  external String get FIREBASE_STORAGE_BUCKET;
}

@JS('window.__ACE_FIREBASE_CONFIG__')
external _FirebaseRuntimeConfig? get _firebaseRuntimeConfig;

Map<String, String>? readRuntimeFirebaseConfig() {
  final config = _firebaseRuntimeConfig;
  if (config == null) return null;
  return {
    'FIREBASE_API_KEY': config.FIREBASE_API_KEY,
    'FIREBASE_APP_ID': config.FIREBASE_APP_ID,
    'FIREBASE_MESSAGING_SENDER_ID': config.FIREBASE_MESSAGING_SENDER_ID,
    'FIREBASE_PROJECT_ID': config.FIREBASE_PROJECT_ID,
    'FIREBASE_AUTH_DOMAIN': config.FIREBASE_AUTH_DOMAIN,
    'FIREBASE_STORAGE_BUCKET': config.FIREBASE_STORAGE_BUCKET,
  };
}
