import 'package:flutter/material.dart';

import '../../core/admin_auth_service.dart';

class LogoutAction extends StatefulWidget {
  const LogoutAction({super.key, this.adminAuthService});

  final AdminAuthService? adminAuthService;

  @override
  State<LogoutAction> createState() => _LogoutActionState();
}

class _LogoutActionState extends State<LogoutAction> {
  bool _signingOut = false;

  Future<void> _signOut() async {
    setState(() => _signingOut = true);
    try {
      await (widget.adminAuthService ?? AdminAuthService()).signOut();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ログアウトに失敗しました。もう一度お試しください。')),
      );
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: _signingOut ? null : _signOut,
      icon: const Icon(Icons.logout, size: 20),
      label: Text(_signingOut ? 'ログアウト中…' : 'ログアウト'),
    );
  }
}
