import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'features/admin/menu_edit_page.dart';
import 'features/auth/login_page.dart';
import 'features/checkout/checkout_page.dart';
import 'features/home/home_page.dart';
import 'features/order/order_page.dart';
import 'features/visit/visit_register_page.dart';

class AceApp extends StatelessWidget {
  const AceApp({super.key, this.initializationError});

  final Object? initializationError;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '簡易会計',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: const ColorScheme(
          brightness: Brightness.light,
          primary: Color(0xFF8D4B32),
          onPrimary: Colors.white,
          secondary: Color(0xFFF4B860),
          onSecondary: Color(0xFF3E2723),
          error: Color(0xFFB3261E),
          onError: Colors.white,
          surface: Color(0xFFFFF8F2),
          onSurface: Color(0xFF2E1D15),
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFFDF7F2),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          backgroundColor: Color(0xFFFDF7F2),
          foregroundColor: Color(0xFF2E1D15),
        ),
        cardTheme: const CardThemeData(
          color: Colors.white,
          elevation: 1,
          margin: EdgeInsets.zero,
        ),
        snackBarTheme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
        ),
      ),
      home: initializationError == null
          ? const _AuthGate()
          : FirebaseInitErrorScreen(error: initializationError!),
      routes: {
        VisitRegisterPage.routeName: (_) => const VisitRegisterPage(),
        OrderPage.routeName: (_) => const OrderPage(),
        CheckoutPage.routeName: (_) => const CheckoutPage(),
        MenuEditPage.routeName: (_) => const MenuEditPage(),
      },
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        final user = snapshot.data;
        if (user == null) return const LoginPage();
        return const HomePage();
      },
    );
  }
}

class FirebaseInitErrorScreen extends StatelessWidget {
  const FirebaseInitErrorScreen({super.key, required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Firebase初期化に失敗しました。\n'
            'Webアプリの設定値を確認してください。\n\n$error',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
