import 'package:flutter/material.dart';

import '../admin/menu_edit_page.dart';
import '../checkout/checkout_page.dart';
import '../order/open_order_flow.dart';
import '../order/order_page.dart';
import '../visit/visit_register_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  /// MaterialApp で `home` を使っているため、`'/'` と重複させないこと。
  static const routeName = '/home';

  Future<void> _openVisitRegister(BuildContext context) async {
    final result = await Navigator.pushNamed(
      context,
      VisitRegisterPage.routeName,
    );
    if (!context.mounted || result == null || result is! String) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$result さんの伝票を作成しました')));
  }

  Future<void> _openOrderFlow(BuildContext context) async {
    final result = await openOrderFlow(context);
    if (!context.mounted) return;
    showOrderFlowResultSnackBar(context, result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('簡易会計アプリ')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _NavButton(
                label: '来店登録',
                icon: Icons.person_add_alt_1,
                onTap: () => _openVisitRegister(context),
              ),
              const SizedBox(height: 12),
              _NavButton(
                label: '注文・伝票',
                icon: Icons.receipt_long_outlined,
                onTap: () => _openOrderFlow(context),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton.icon(
                  onPressed: () =>
                      Navigator.pushNamed(context, OrderPage.routeName),
                  icon: const Icon(Icons.list_alt_outlined, size: 20),
                  label: const Text('伝票・明細を確認'),
                ),
              ),
              const SizedBox(height: 12),
              _NavButton(
                label: '会計',
                icon: Icons.receipt_long,
                onTap: () =>
                    Navigator.pushNamed(context, CheckoutPage.routeName),
              ),
              const SizedBox(height: 24),
              _MenuEditEntryButton(
                onTap: () =>
                    Navigator.pushNamed(context, MenuEditPage.routeName),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuEditEntryButton extends StatelessWidget {
  const _MenuEditEntryButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const fill = Color(0xFF0F766E);
    const onFill = Color(0xFFFAFAFA);
    return SizedBox(
      height: 60,
      child: FilledButton.icon(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: fill,
          foregroundColor: onFill,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
        icon: const Icon(Icons.menu_book_outlined, size: 24),
        label: Text(
          'メニュー編集',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: onFill,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // トップ導線のみ、アプリ全体の茶色 primary ではなくオレンジ系で統一
    const fill = Color(0xFFEA580C);
    const onFill = Color(0xFFFAFAFA);
    return SizedBox(
      height: 88,
      child: FilledButton.icon(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: fill,
          foregroundColor: onFill,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
        icon: Icon(icon, size: 28),
        label: Text(
          label,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: onFill,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}
