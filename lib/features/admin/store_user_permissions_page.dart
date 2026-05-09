import 'package:flutter/material.dart';

import '../../core/app_config.dart';
import '../../core/admin_auth_service.dart';
import '../../data/repositories/store_user_permissions_repository.dart';
import '../../models/store_user_permissions.dart';

enum _PermissionPreset {
  none,
  accountingOnly,
  expenseOnly,
  expenseSubmitOnly,
  both,
}

class StoreUserPermissionsPage extends StatefulWidget {
  const StoreUserPermissionsPage({super.key});

  static const routeName = '/admin/store-users';

  @override
  State<StoreUserPermissionsPage> createState() =>
      _StoreUserPermissionsPageState();
}

class _StoreUserPermissionsPageState extends State<StoreUserPermissionsPage> {
  final _adminAuthService = AdminAuthService();
  final _repo = StoreUserPermissionsRepository();
  bool _checkingAdmin = true;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _refreshAdminState();
  }

  Future<void> _refreshAdminState() async {
    setState(() => _checkingAdmin = true);
    try {
      if (_adminAuthService.isCurrentUserAnonymous) {
        if (mounted) setState(() => _isAdmin = false);
        return;
      }
      final isAdmin = await _adminAuthService.isCurrentUserAdmin();
      if (mounted) setState(() => _isAdmin = isAdmin);
    } finally {
      if (mounted) setState(() => _checkingAdmin = false);
    }
  }

  Future<void> _loginAsAdmin() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _AdminLoginDialog(adminAuthService: _adminAuthService),
    );
    if (ok != true || !mounted) return;
    await _refreshAdminState();
  }

  Future<void> _showEditor({StoreUserPermissions? existing}) async {
    if (!_isAdmin) return;
    final uidController = TextEditingController(text: existing?.uid ?? '');
    final emailController = TextEditingController(text: existing?.email ?? '');
    final isEditing = existing != null;
    _PermissionPreset preset = _presetFromRoles(
      existing?.moduleRoles ?? const [],
    );

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            return AlertDialog(
              title: Text(isEditing ? 'ユーザー権限の編集' : 'ユーザーの追加'),
              content: SizedBox(
                width: 400,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: uidController,
                        enabled: !isEditing,
                        decoration: const InputDecoration(
                          labelText: 'ユーザー UID',
                          helperText: 'Firebase Authentication で確認できる UID',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: emailController,
                        decoration: const InputDecoration(
                          labelText: 'メール（任意・一覧表示用）',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'モジュール権限（moduleRoles）',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownMenu<_PermissionPreset>(
                        expandedInsets: EdgeInsets.zero,
                        initialSelection: preset,
                        label: const Text('権限プリセット'),
                        dropdownMenuEntries: [
                          for (final p in _PermissionPreset.values)
                            DropdownMenuEntry<_PermissionPreset>(
                              value: p,
                              label: _presetLabel(p),
                            ),
                        ],
                        onSelected: (v) {
                          if (v != null) setLocal(() => preset = v);
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('キャンセル'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('保存'),
                ),
              ],
            );
          },
        );
      },
    );

    if (saved != true || !mounted) {
      uidController.dispose();
      emailController.dispose();
      return;
    }

    final uid = uidController.text.trim();
    uidController.dispose();
    final email = emailController.text.trim();
    emailController.dispose();

    if (uid.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('UIDを入力してください')));
      return;
    }

    final roles = rolesFromPreset(preset);
    try {
      await _repo.upsertStoreUser(
        uid: uid,
        email: email.isEmpty ? null : email,
        moduleRoles: roles,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('権限を保存しました')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('保存に失敗しました: $e')));
    }
  }

  Future<void> _confirmDelete(StoreUserPermissions user) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ユーザーの削除'),
        content: Text(
          '${user.email ?? user.uid} の権限情報をFirestoreから削除しますか？\n'
          '（Authentication のユーザー本体は削除されません）',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await _repo.deleteStoreUser(user.uid);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('削除しました')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('削除に失敗しました: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingAdmin) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('ユーザー権限')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('この画面は管理者のみ利用できます。', textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _loginAsAdmin,
                    icon: const Icon(Icons.lock_open),
                    label: const Text('管理者ログイン'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('ユーザー権限')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showEditor(),
        icon: const Icon(Icons.person_add),
        label: const Text('ユーザーを追加'),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text(
                'stores / ${AppConfig.storeId} / users に moduleRoles を保存します。',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            Expanded(
              child: StreamBuilder<List<StoreUserPermissions>>(
                stream: _repo.streamStoreUsers(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('読み込みエラー: ${snapshot.error}'));
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final list = snapshot.data!;
                  if (list.isEmpty) {
                    return const Center(
                      child: Text(
                        '登録済みユーザーがありません。\n右下から UID を追加してください。',
                        textAlign: TextAlign.center,
                      ),
                    );
                  }
                  return ListView.separated(
                    itemCount: list.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final u = list[index];
                      return ListTile(
                        title: Text(u.email ?? u.uid),
                        subtitle: Text(
                          '${u.summaryLabel()} ｜ UID: ${u.uid}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert),
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Text('編集'),
                            ),
                            PopupMenuItem<String>(
                              value: 'delete',
                              child: Text(
                                '削除',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            ),
                          ],
                          onSelected: (value) {
                            if (value == 'edit') {
                              _showEditor(existing: u);
                            } else if (value == 'delete') {
                              _confirmDelete(u);
                            }
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  static _PermissionPreset _presetFromRoles(List<String> roles) {
    final normalized = roles.map((x) => x.trim()).where((x) => x.isNotEmpty);
    final s = normalized.toSet();
    if (s.isEmpty) return _PermissionPreset.none;
    if (s.contains('both')) return _PermissionPreset.both;
    if (s.contains('accounting') && s.contains('expense')) {
      return _PermissionPreset.both;
    }
    if (Set<String>.from(s) == {'accounting'}) {
      return _PermissionPreset.accountingOnly;
    }
    if (Set<String>.from(s) == {'expense'}) {
      return _PermissionPreset.expenseOnly;
    }
    if (Set<String>.from(s) == {'expense_submit'}) {
      return _PermissionPreset.expenseSubmitOnly;
    }
    return _PermissionPreset.none;
  }

  static String _presetLabel(_PermissionPreset p) {
    switch (p) {
      case _PermissionPreset.none:
        return '権限なし（空の moduleRoles）';
      case _PermissionPreset.accountingOnly:
        return '会計のみ（accounting）';
      case _PermissionPreset.expenseOnly:
        return '経費（expense・登録のみ・他人一覧不可）';
      case _PermissionPreset.expenseSubmitOnly:
        return '経費入力のみ（expense_submit）';
      case _PermissionPreset.both:
        return '両方（both）';
    }
  }

  static List<String> rolesFromPreset(_PermissionPreset preset) {
    switch (preset) {
      case _PermissionPreset.none:
        return const <String>[];
      case _PermissionPreset.accountingOnly:
        return const <String>['accounting'];
      case _PermissionPreset.expenseOnly:
        return const <String>['expense'];
      case _PermissionPreset.expenseSubmitOnly:
        return const <String>['expense_submit'];
      case _PermissionPreset.both:
        return const <String>['both'];
    }
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
              enabled: !_submitting,
              decoration: const InputDecoration(
                labelText: 'メールアドレス',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              enabled: !_submitting,
              decoration: const InputDecoration(
                labelText: 'パスワード',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
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
