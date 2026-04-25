import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/admin_auth_service.dart';
import '../../core/menu_category_catalog.dart';
import '../../data/repositories/menu_repository.dart';
import '../../models/menu_item.dart';

enum _EditMode { register, remove }

class MenuEditPage extends StatefulWidget {
  const MenuEditPage({super.key});

  static const routeName = '/menu-edit';

  @override
  State<MenuEditPage> createState() => _MenuEditPageState();
}

class _MenuEditPageState extends State<MenuEditPage> {
  final _repo = MenuRepository();
  final _adminAuthService = AdminAuthService();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();

  _EditMode _mode = _EditMode.register;
  String _category = MenuCategoryCatalog.displayOrder.first;
  String? _removeMenuId;
  bool _saving = false;
  bool _checkingAdmin = true;
  bool _isAdmin = false;

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    super.dispose();
  }

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

  Future<void> _runRegister() async {
    final price = int.tryParse(_priceController.text.trim().replaceAll(',', ''));
    if (price == null || price < 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('金額を正しく入力してください（0以上の整数）')),
      );
      return;
    }
    if (_nameController.text.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('メニュー名を入力してください')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await _repo.addMenu(
        name: _nameController.text,
        category: _category,
        priceTaxIncluded: price,
      );
      if (!mounted) return;
      _nameController.clear();
      _priceController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('メニューを登録しました')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('登録に失敗しました: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmAndDelete() async {
    if (_removeMenuId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('削除するメニューを選んでください')),
      );
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('メニューの削除'),
        content: const Text('このメニューを削除してよいですか？\n注文に残っている履歴（伝票上の明細名）は影響しません。'),
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
    setState(() => _saving = true);
    try {
      await _repo.deleteMenu(_removeMenuId!);
      if (!mounted) return;
      setState(() => _removeMenuId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('メニューを削除しました')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('削除に失敗しました: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingAdmin) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (!_isAdmin) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('メニュー編集'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'この画面は管理者のみ利用できます。',
                    textAlign: TextAlign.center,
                  ),
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
      appBar: AppBar(
        title: const Text('メニュー編集'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<_EditMode>(
                segments: const [
                  ButtonSegment(
                    value: _EditMode.register,
                    label: Text('登録'),
                    icon: Icon(Icons.add),
                  ),
                  ButtonSegment(
                    value: _EditMode.remove,
                    label: Text('削除'),
                    icon: Icon(Icons.delete_outline),
                  ),
                ],
                selected: {_mode},
                onSelectionChanged: (s) {
                  setState(() {
                    _mode = s.first;
                    _saving = false;
                  });
                },
              ),
              const SizedBox(height: 20),
              Expanded(
                child: _mode == _EditMode.register ? _buildRegister() : _buildRemove(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRegister() {
    return ListView(
      children: [
        InputDecorator(
          decoration: const InputDecoration(
            labelText: 'カテゴリ',
            border: OutlineInputBorder(),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: _category,
              items: [
                for (final key in MenuCategoryCatalog.displayOrder)
                  DropdownMenuItem(
                    value: key,
                    child: Text(MenuCategoryCatalog.labelFor(key)),
                  ),
              ],
              onChanged: _saving
                  ? null
                  : (v) {
                      if (v != null) setState(() => _category = v);
                    },
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: 'メニュー名',
            border: OutlineInputBorder(),
            hintText: '例）生レモンサワー',
          ),
          textInputAction: TextInputAction.next,
          enabled: !_saving,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _priceController,
          decoration: const InputDecoration(
            labelText: '金額（税込）',
            border: OutlineInputBorder(),
            hintText: '例）550',
            prefixText: '¥',
          ),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _saving ? null : _runRegister(),
          enabled: !_saving,
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: _saving ? null : _runRegister,
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: const Color(0xFF0F766E),
            foregroundColor: Colors.white,
          ),
          icon: _saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.save),
          label: Text(_saving ? '登録中…' : '登録を実行'),
        ),
      ],
    );
  }

  Widget _buildRemove() {
    return StreamBuilder<List<MenuItem>>(
      stream: _repo.streamAllMenus(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('読み込みエラー: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final list = snapshot.data!;
        if (list.isEmpty) {
          return const Center(child: Text('登録されたメニューがありません'));
        }
        if (_removeMenuId != null) {
          final stillExists = list.any((m) => m.id == _removeMenuId);
          if (!stillExists) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _removeMenuId = null);
            });
          }
        }
        return ListView(
          children: [
            InputDecorator(
              decoration: const InputDecoration(
                labelText: '削除するメニュー',
                border: OutlineInputBorder(),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _removeMenuId,
                  hint: const Text('選んでください'),
                  items: [
                    for (final m in list)
                      DropdownMenuItem(
                        value: m.id,
                        child: Text(
                          '${MenuCategoryCatalog.labelFor(m.category)} ・ ${m.name} ・ ¥${m.priceTaxIncluded}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: _saving
                      ? null
                      : (v) => setState(() => _removeMenuId = v),
                ),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saving ? null : _confirmAndDelete,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: const Color(0xFF991B1B),
                foregroundColor: Colors.white,
              ),
              icon: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.delete_forever),
              label: Text(_saving ? '処理中…' : '削除を実行'),
            ),
          ],
        );
      },
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
              enabled: !_submitting,
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
              decoration: const InputDecoration(
                labelText: 'パスワード',
                border: OutlineInputBorder(),
              ),
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
