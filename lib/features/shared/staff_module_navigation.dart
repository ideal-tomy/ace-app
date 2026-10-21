import 'package:flutter/material.dart';

import '../../core/admin_auth_service.dart';
import '../expense/expense_dashboard_page.dart';
import '../home/home_page.dart';

/// 会計ハブ（ホーム）と経費ハブの切り替え。
enum StaffHubModule { accounting, expense }

void navigateToStaffHub(BuildContext context, StaffHubModule module) {
  final route = switch (module) {
    StaffHubModule.accounting => HomePage.routeName,
    StaffHubModule.expense => ExpenseDashboardPage.routeName,
  };
  Navigator.pushReplacementNamed(context, route);
}

/// AppBar の相手モジュールへ切り替えるボタン（権限がない場合は非表示）。
class StaffModuleSwitchAction extends StatelessWidget {
  const StaffModuleSwitchAction({
    super.key,
    required this.current,
    this.adminAuthService,
  });

  final StaffHubModule current;
  final AdminAuthService? adminAuthService;

  @override
  Widget build(BuildContext context) {
    final auth = adminAuthService ?? AdminAuthService();
    final target = current == StaffHubModule.accounting
        ? StaffHubModule.expense
        : StaffHubModule.accounting;

    return FutureBuilder<bool>(
      future: target == StaffHubModule.expense
          ? auth.canPostExpense()
          : auth.canAccessAccounting(),
      builder: (context, snapshot) {
        if (snapshot.data != true) return const SizedBox.shrink();
        final (icon, tooltip) = switch (target) {
          StaffHubModule.expense => (
            Icons.request_quote_outlined,
            '経費',
          ),
          StaffHubModule.accounting => (
            Icons.account_balance_wallet_outlined,
            '会計ホーム',
          ),
        };
        return IconButton(
          tooltip: tooltip,
          icon: Icon(icon),
          onPressed: () => navigateToStaffHub(context, target),
        );
      },
    );
  }
}
