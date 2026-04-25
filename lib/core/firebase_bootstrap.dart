import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'app_config.dart';

Future<Object?> initializeFirebase() async {
  try {
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
      debugPrint('App Check skipped: APP_CHECK_WEB_RECAPTCHA_SITE_KEY is empty.');
    }
    return;
  }
  await FirebaseAppCheck.instance.activate(
    providerWeb: ReCaptchaV3Provider(siteKey),
  );
}

FirebaseOptions _firebaseOptions() {
  const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  const appId = String.fromEnvironment('FIREBASE_APP_ID');
  const messagingSenderId = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
  const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  const authDomain = String.fromEnvironment('FIREBASE_AUTH_DOMAIN');
  const storageBucket = String.fromEnvironment('FIREBASE_STORAGE_BUCKET');

  return FirebaseOptions(
    apiKey: apiKey,
    appId: appId,
    messagingSenderId: messagingSenderId,
    projectId: projectId,
    authDomain: authDomain.isEmpty ? null : authDomain,
    storageBucket: storageBucket.isEmpty ? null : storageBucket,
  );
}
