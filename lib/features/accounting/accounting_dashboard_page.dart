import 'package:flutter/material.dart';

import '../checkout/checkout_page.dart';
import '../home/home_page.dart';

class AccountingDashboardPage extends StatelessWidget {
  const AccountingDashboardPage({super.key});

  static const routeName = '/accounting';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('会計ダッシュボード'),
        actions: [
          IconButton(
            tooltip: 'アプリホーム',
            icon: const Icon(Icons.dashboard_customize_outlined),
            onPressed: () => Navigator.pushNamed(context, HomePage.routeName),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('会計関連の業務を選択してください。'),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () =>
                    Navigator.pushNamed(context, CheckoutPage.routeName),
                icon: const Icon(Icons.receipt_long),
                label: const Text('会計処理へ進む'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
