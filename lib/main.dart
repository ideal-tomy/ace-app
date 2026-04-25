import 'package:flutter/material.dart';

import 'app.dart';
import 'core/firebase_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final initError = await initializeFirebase();
  runApp(AceApp(initializationError: initError));
}
