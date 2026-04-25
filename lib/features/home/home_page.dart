import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/admin_auth_service.dart';
import '../admin/menu_edit_page.dart';
import '../checkout/checkout_page.dart';
import '../order/order_page.dart';
import '../visit/visit_register_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _adminAuthService = AdminAuthService();

  Future<void> _openVisitRegister() async {
    final result = await Navigator.pushNamed(
      context,
      VisitRegisterPage.routeName,
    );
    if (!mounted || result == null || result is! String) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$result さんの伝票を作成しました')),
    );
  }

  Future<void> _openMenuEditWithAdminCheck() async {
    final alreadyAdmin = await _adminAuthService.isCurrentUserAdmin();
    if (!mounted) return;
    if (alreadyAdmin) {
      await Navigator.pushNamed(context, MenuEditPage.routeName);
      return;
    }

    final loggedIn = await showDialog<bool>(
      context: context,
      builder: (_) => _AdminLoginDialog(adminAuthService: _adminAuthService),
    );
    if (!mounted || loggedIn != true) return;

    final nowAdmin = await _adminAuthService.isCurrentUserAdmin();
    if (!mounted) return;
    if (!nowAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('管理者権限がありません。admins設定を確認してください')),
      );
      return;
    }
    await Navigator.pushNamed(context, MenuEditPage.routeName);
  }

  Future<void> _logoutToAnonymous() async {
    await _adminAuthService.signOut();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('ログアウトしました')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('簡易会計アプリ')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              StreamBuilder<User?>(
                stream: _adminAuthService.authStateChanges,
                initialData: _adminAuthService.currentUser,
                builder: (context, authSnapshot) {
                  final user = authSnapshot.data;
                  final isAnonymous = user?.isAnonymous ?? true;
                  final accountText = isAnonymous
                      ? '匿名利用中'
                      : 'ログイン中: ${user?.email ?? user?.uid ?? '(不明)'}';
                  final adminFuture = isAnonymous
                      ? Future<bool>.value(false)
                      : _adminAuthService.isCurrentUserAdmin();
                  return FutureBuilder<bool>(
                    future: adminFuture,
                    builder: (context, adminSnapshot) {
                      final isAdmin = adminSnapshot.data == true;
                      return Card(
                        child: ListTile(
                          dense: true,
                          title: Text(accountText),
                          subtitle: Text(isAdmin ? '権限: 管理者' : '権限: 一般'),
                          trailing: isAnonymous
                              ? null
                              : TextButton.icon(
                                  onPressed: _logoutToAnonymous,
                                  icon: const Icon(Icons.logout),
                                  label: const Text('ログアウト'),
                                ),
                        ),
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 12),
              const Spacer(),
              _NavButton(
                label: '来店登録',
                icon: Icons.person_add_alt_1,
                onTap: _openVisitRegister,
              ),
              const SizedBox(height: 12),
              _NavButton(
                label: '注文受付',
                icon: Icons.restaurant_menu,
                onTap: () => Navigator.pushNamed(context, OrderPage.routeName),
              ),
              const SizedBox(height: 12),
              _NavButton(
                label: '会計',
                icon: Icons.receipt_long,
                onTap: () => Navigator.pushNamed(context, CheckoutPage.routeName),
              ),
              const SizedBox(height: 24),
              _MenuEditEntryButton(
                onTap: _openMenuEditWithAdminCheck,
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminLoginDialog extends StatefulWidget {
  const _AdminLoginDialog({required this.adminAuthService});

  final AdminAuthService adminAuthService;

  @override
  State<_AdminLoginDialog> createState() => _AdminLoginDialogState();
}

class _AdminLoginDialogState extends State<_AdminLoginDialog> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _submitting = false;
  String? _errorText;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorText = 'メールアドレスとパスワードを入力してください');
      return;
    }
    setState(() {
      _submitting = true;
      _errorText = null;
    });
    try {
      await widget.adminAuthService.signInWithEmailPassword(
        email: email,
        password: password,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorText = 'ログインに失敗しました: $error');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('管理者ログイン'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'メールアドレス',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
              enabled: !_submitting,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: 'パスワード',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
              enabled: !_submitting,
              onSubmitted: (_) => _submitting ? null : _submit(),
            ),
            if (_errorText != null) ...[
              const SizedBox(height: 10),
              Text(
                _errorText!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.pop(context, false),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: Text(_submitting ? '確認中...' : 'ログイン'),
        ),
      ],
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
