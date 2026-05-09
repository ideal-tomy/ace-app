import 'package:flutter/material.dart';

import '../../core/admin_auth_service.dart';

Future<bool?> showAdminLoginDialog({
  required BuildContext context,
  required AdminAuthService adminAuthService,
}) {
  return showDialog<bool>(
    context: context,
    builder: (_) => AdminLoginDialog(adminAuthService: adminAuthService),
  );
}

class AdminLoginDialog extends StatefulWidget {
  const AdminLoginDialog({super.key, required this.adminAuthService});

  final AdminAuthService adminAuthService;

  @override
  State<AdminLoginDialog> createState() => _AdminLoginDialogState();
}

class _AdminLoginDialogState extends State<AdminLoginDialog> {
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
