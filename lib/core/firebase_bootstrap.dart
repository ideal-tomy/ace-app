import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'app_config.dart';
import 'firebase_web_runtime_config.dart';

Future<Object?> initializeFirebase() async {
  try {
    final apiKey = _configValue('FIREBASE_API_KEY');
    if (apiKey.isEmpty) {
      return StateError(
        'Firebase 設定が読み込まれていません。\n'
        'デプロイ時は .\\deploy_hosting.ps1 を使ってください。\n'
        'ローカル起動は次のコマンド:\n'
        'flutter run -d chrome --dart-define-from-file=firebase.web.dev.json',
      );
    }
    await Firebase.initializeApp(options: _firebaseOptions());
    await _activateAppCheckIfConfigured();

    // Webの永続キャッシュを有効化。
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
    return null;
  } catch (error) {
    if (kDebugMode) {
      debugPrint('Firebase init error: $error');
    }
    return error;
  }
}

Future<void> _activateAppCheckIfConfigured() async {
  if (!kIsWeb) return;
  final siteKey = AppConfig.appCheckWebRecaptchaSiteKey;
  if (siteKey.isEmpty) {
    if (kDebugMode) {
      debugPrint(
        'App Check skipped: APP_CHECK_WEB_RECAPTCHA_SITE_KEY is empty.',
      );
    }
    return;
  }
  await FirebaseAppCheck.instance.activate(
    providerWeb: ReCaptchaV3Provider(siteKey),
  );
}

String _configValue(String key) {
  final runtime = readRuntimeFirebaseConfig();
  final fromRuntime = runtime?[key];
  if (fromRuntime != null && fromRuntime.isNotEmpty) {
    return fromRuntime;
  }
  return switch (key) {
    'FIREBASE_API_KEY' => const String.fromEnvironment('FIREBASE_API_KEY'),
    'FIREBASE_APP_ID' => const String.fromEnvironment('FIREBASE_APP_ID'),
    'FIREBASE_MESSAGING_SENDER_ID' =>
      const String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID'),
    'FIREBASE_PROJECT_ID' => const String.fromEnvironment('FIREBASE_PROJECT_ID'),
    'FIREBASE_AUTH_DOMAIN' =>
      const String.fromEnvironment('FIREBASE_AUTH_DOMAIN'),
    'FIREBASE_STORAGE_BUCKET' =>
      const String.fromEnvironment('FIREBASE_STORAGE_BUCKET'),
    _ => '',
  };
}

FirebaseOptions _firebaseOptions() {
  final apiKey = _configValue('FIREBASE_API_KEY');
  final appId = _configValue('FIREBASE_APP_ID');
  final messagingSenderId = _configValue('FIREBASE_MESSAGING_SENDER_ID');
  final projectId = _configValue('FIREBASE_PROJECT_ID');
  final authDomain = _configValue('FIREBASE_AUTH_DOMAIN');
  final storageBucket = _configValue('FIREBASE_STORAGE_BUCKET');

  return FirebaseOptions(
    apiKey: apiKey,
    appId: appId,
    messagingSenderId: messagingSenderId,
    projectId: projectId,
    authDomain: authDomain.isEmpty ? null : authDomain,
    storageBucket: storageBucket.isEmpty ? null : storageBucket,
  );
}
