import 'package:flutter/material.dart';

import '../../core/admin_auth_service.dart';
import 'login_entry_target.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    required this.entryTarget,
    required this.onBackToModuleSelection,
  });

  final LoginEntryTarget entryTarget;

  /// モジュール選択画面へ戻る（ログイン前フローのみ）。
  final VoidCallback onBackToModuleSelection;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _authService = AdminAuthService();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _submitting = false;
  String? _errorText;

  String get _appBarTitle {
    switch (widget.entryTarget) {
      case LoginEntryTarget.accounting:
        return '会計ダッシュボード（ログイン）';
      case LoginEntryTarget.expense:
        return '経費（ログイン）';
    }
  }

  String get _headline {
    switch (widget.entryTarget) {
      case LoginEntryTarget.accounting:
        return '会計ダッシュボードへ進むためにログインしてください';
      case LoginEntryTarget.expense:
        return '経費メニューへ進むためにログインしてください';
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
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
      await _authService.signInWithEmailPassword(
        email: email,
        password: password,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorText = 'ログインに失敗しました: $error');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: widget.onBackToModuleSelection),
        title: Text(_appBarTitle),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _headline,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _emailController,
                  enabled: !_submitting,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'メールアドレス',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passwordController,
                  enabled: !_submitting,
                  obscureText: true,
                  onSubmitted: (_) => _submitting ? null : _login(),
                  decoration: const InputDecoration(
                    labelText: 'パスワード',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (_errorText != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _errorText!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _submitting ? null : _login,
                    child: Text(_submitting ? 'ログイン中...' : 'ログイン'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
