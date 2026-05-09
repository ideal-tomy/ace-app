import 'package:flutter/material.dart';

import 'admin_auth_service.dart';

enum RequiredModulePermission { accounting, expense }

class RoleGuard extends StatelessWidget {
  const RoleGuard({
    super.key,
    required this.permission,
    required this.child,
    this.fallbackRouteName = '/home',
  });

  final RequiredModulePermission permission;
  final Widget child;
  final String fallbackRouteName;

  @override
  Widget build(BuildContext context) {
    final authService = AdminAuthService();
    return FutureBuilder<bool>(
      future: permission == RequiredModulePermission.accounting
          ? authService.canAccessAccounting()
          : authService.canPostExpense(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.data == true) return child;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('この画面へのアクセス権限がありません')));
          Navigator.pushNamedAndRemoveUntil(
            context,
            fallbackRouteName,
            (route) => false,
          );
        });
        return const Scaffold(body: Center(child: Text('権限を確認中です...')));
      },
    );
  }
}
