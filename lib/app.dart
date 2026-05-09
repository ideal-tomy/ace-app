import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'core/admin_auth_service.dart';
import 'core/role_guard.dart';
import 'features/accounting/accounting_dashboard_page.dart';
import 'features/admin/expense_summary_admin_page.dart';
import 'features/admin/menu_edit_page.dart';
import 'features/admin/store_user_permissions_page.dart';
import 'features/auth/login_entry_target.dart';
import 'features/auth/login_page.dart';
import 'features/auth/module_landing_page.dart';
import 'features/checkout/checkout_page.dart';
import 'features/expense/expense_dashboard_page.dart';
import 'features/home/home_page.dart';
import 'features/order/order_page.dart';
import 'features/visit/visit_register_page.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

class AceApp extends StatelessWidget {
  const AceApp({super.key, this.initializationError});

  final Object? initializationError;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: appNavigatorKey,
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
        HomePage.routeName: (_) => const HomePage(),
        VisitRegisterPage.routeName: (_) => const VisitRegisterPage(),
        OrderPage.routeName: (_) => const OrderPage(),
        CheckoutPage.routeName: (_) => const RoleGuard(
          permission: RequiredModulePermission.accounting,
          fallbackRouteName: HomePage.routeName,
          child: CheckoutPage(),
        ),
        AccountingDashboardPage.routeName: (_) => const RoleGuard(
          permission: RequiredModulePermission.accounting,
          fallbackRouteName: HomePage.routeName,
          child: AccountingDashboardPage(),
        ),
        ExpenseDashboardPage.routeName: (_) => const RoleGuard(
          permission: RequiredModulePermission.expense,
          fallbackRouteName: HomePage.routeName,
          child: ExpenseDashboardPage(),
        ),
        MenuEditPage.routeName: (_) => const MenuEditPage(),
        StoreUserPermissionsPage.routeName: (_) =>
            const StoreUserPermissionsPage(),
        ExpenseSummaryAdminPage.routeName: (_) =>
            const ExpenseSummaryAdminPage(),
      },
    );
  }
}

/// ログイン前: 会計／経費の選択 → ログイン。その後または既存セッションは従来どおり権限ベース。
class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  final _adminAuthService = AdminAuthService();
  StreamSubscription<User?>? _authSubscription;

  /// ログアウトでリセット。選択直後〜ログイン成功後まで保持し、ログイン済みツリーの初期画面に使う。
  LoginEntryTarget? _reservedEntryAfterAuth;

  @override
  void initState() {
    super.initState();
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((
      User? user,
    ) {
      if (user != null || !mounted) return;
      appNavigatorKey.currentState?.popUntil((route) => route.isFirst);
      setState(() {
        _reservedEntryAfterAuth = null;
      });
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        final user = snapshot.data;
        if (user == null) {
          final reserved = _reservedEntryAfterAuth;
          if (reserved == null) {
            return ModuleLandingPage(
              onSelectAccounting: () => setState(
                () => _reservedEntryAfterAuth = LoginEntryTarget.accounting,
              ),
              onSelectExpense: () => setState(
                () => _reservedEntryAfterAuth = LoginEntryTarget.expense,
              ),
            );
          }
          return LoginPage(
            entryTarget: reserved,
            onBackToModuleSelection: () =>
                setState(() => _reservedEntryAfterAuth = null),
          );
        }

        if (_reservedEntryAfterAuth == LoginEntryTarget.accounting) {
          return const RoleGuard(
            permission: RequiredModulePermission.accounting,
            fallbackRouteName: HomePage.routeName,
            child: HomePage(),
          );
        }
        if (_reservedEntryAfterAuth == LoginEntryTarget.expense) {
          return const RoleGuard(
            permission: RequiredModulePermission.expense,
            fallbackRouteName: HomePage.routeName,
            child: ExpenseDashboardPage(),
          );
        }

        return FutureBuilder<Set<AppModuleRole>>(
          future: _adminAuthService.getCurrentUserModuleRoles(),
          builder: (context, rolesSnapshot) {
            if (!rolesSnapshot.hasData) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            final roles = rolesSnapshot.data!;
            final canAccounting =
                roles.contains(AppModuleRole.accounting) ||
                roles.contains(AppModuleRole.both);
            final canExpenseRoute =
                roles.contains(AppModuleRole.expense) ||
                roles.contains(AppModuleRole.both) ||
                roles.contains(AppModuleRole.expenseSubmit);
            if (canAccounting && !canExpenseRoute) {
              return const HomePage();
            }
            if (canExpenseRoute && !canAccounting) {
              return const ExpenseDashboardPage();
            }
            return const HomePage();
          },
        );
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
