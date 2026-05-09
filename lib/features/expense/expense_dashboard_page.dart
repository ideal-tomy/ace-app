import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../../core/admin_auth_service.dart';
import '../../data/repositories/finance_entry_repository.dart';
import '../../models/expense_account_item.dart';
import '../../models/finance_entry.dart';
import 'expense_account_picker.dart';
import '../admin/admin_login_dialog.dart';
import '../admin/expense_summary_admin_page.dart';
import '../admin/store_user_permissions_page.dart';
import '../home/home_page.dart';

class ExpenseDashboardPage extends StatefulWidget {
  const ExpenseDashboardPage({super.key});

  static const routeName = '/expense';

  @override
  State<ExpenseDashboardPage> createState() => _ExpenseDashboardPageState();
}

class _ExpenseDashboardPageState extends State<ExpenseDashboardPage> {
  final _repo = FinanceEntryRepository();
  final _adminAuth = AdminAuthService();
  final _amountController = TextEditingController();
  final _memoController = TextEditingController();
  ExpenseAccountItem? _selectedAccount;
  bool _submitting = false;

  @override
  void dispose() {
    _amountController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  Future<void> _openExpenseSummaryWithAdminCheck() async {
    final alreadyAdmin = await _adminAuth.isCurrentUserAdmin();
    if (!mounted) return;
    if (alreadyAdmin) {
      await Navigator.pushNamed(context, ExpenseSummaryAdminPage.routeName);
      return;
    }

    final loggedIn = await showAdminLoginDialog(
      context: context,
      adminAuthService: _adminAuth,
    );
    if (!mounted || loggedIn != true) return;

    final nowAdmin = await _adminAuth.isCurrentUserAdmin();
    if (!mounted) return;
    if (!nowAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('管理者のみ経費の全体集計を確認できます。admins設定を確認してください')),
      );
      return;
    }
    await Navigator.pushNamed(context, ExpenseSummaryAdminPage.routeName);
  }

  Future<void> _openStoreUserPermissionsWithAdminCheck() async {
    final alreadyAdmin = await _adminAuth.isCurrentUserAdmin();
    if (!mounted) return;
    if (alreadyAdmin) {
      await Navigator.pushNamed(context, StoreUserPermissionsPage.routeName);
      return;
    }

    final loggedIn = await showAdminLoginDialog(
      context: context,
      adminAuthService: _adminAuth,
    );
    if (!mounted || loggedIn != true) return;

    final nowAdmin = await _adminAuth.isCurrentUserAdmin();
    if (!mounted) return;
    if (!nowAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('管理者権限がありません。admins設定を確認してください')),
      );
      return;
    }
    await Navigator.pushNamed(context, StoreUserPermissionsPage.routeName);
  }

  Future<void> _submit() async {
    final acc = _selectedAccount;
    final amount = int.tryParse(_amountController.text.trim()) ?? 0;
    if (acc == null || amount <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('科目と金額を正しく入力してください')));
      return;
    }
    setState(() => _submitting = true);
    try {
      await _repo.addExpenseEntry(
        date: DateTime.now(),
        accountItemId: acc.id,
        category: acc.labelJa,
        amount: amount,
        memo: _memoController.text,
      );
      if (!mounted) return;
      setState(() => _selectedAccount = null);
      _amountController.clear();
      _memoController.clear();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('経費を登録しました')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('登録に失敗しました: $error')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy/MM/dd');
    final moneyFormat = NumberFormat.currency(
      locale: 'ja_JP',
      symbol: '¥',
      decimalDigits: 0,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('経費ダッシュボード'),
        actions: [
          IconButton(
            tooltip: 'アプリホーム（会計）',
            icon: const Icon(Icons.dashboard_customize_outlined),
            onPressed: () => Navigator.pushNamed(context, HomePage.routeName),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxW = constraints.maxWidth;
            final hPad = maxW >= 600 ? 24.0 : 12.0;
            final contentMax = maxW >= 900 ? 720.0 : double.infinity;
            final widePicker = maxW >= 600;
            final formRow = maxW >= 640;

            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: contentMax),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '自分が登録した経費のみ一覧に表示されます。',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            children: [
                              if (formRow)
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: ExpenseAccountPicker(
                                        selected: _selectedAccount,
                                        onSelected: (v) => setState(
                                          () => _selectedAccount = v,
                                        ),
                                        wide: widePicker,
                                        enabled: !_submitting,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      flex: 1,
                                      child: TextField(
                                        controller: _amountController,
                                        enabled: !_submitting,
                                        keyboardType: TextInputType.number,
                                        decoration: const InputDecoration(
                                          labelText: '金額',
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              else ...[
                                ExpenseAccountPicker(
                                  selected: _selectedAccount,
                                  onSelected: (v) =>
                                      setState(() => _selectedAccount = v),
                                  wide: widePicker,
                                  enabled: !_submitting,
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: _amountController,
                                  enabled: !_submitting,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: '金額',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 8),
                              TextField(
                                controller: _memoController,
                                enabled: !_submitting,
                                decoration: const InputDecoration(
                                  labelText: 'メモ',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton(
                                  onPressed: _submitting ? null : _submit,
                                  child: Text(_submitting ? '登録中...' : '経費を登録'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      StreamBuilder<User?>(
                        stream: _adminAuth.authStateChanges,
                        initialData: _adminAuth.currentUser,
                        builder: (context, authSnap) {
                          final user = authSnap.data;
                          if (user == null || user.isAnonymous) {
                            return const SizedBox.shrink();
                          }
                          return FutureBuilder<bool>(
                            future: _adminAuth.isCurrentUserAdmin(),
                            builder: (context, adminSnap) {
                              final isAdmin = adminSnap.data == true;
                              if (!isAdmin) {
                                return const SizedBox.shrink();
                              }
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const SizedBox(height: 12),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      '管理者メニュー',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  _ExpenseSummaryAdminTile(
                                    onTap: _openExpenseSummaryWithAdminCheck,
                                  ),
                                  const SizedBox(height: 12),
                                  _StoreUserPermissionsAdminTile(
                                    onTap:
                                        _openStoreUserPermissionsWithAdminCheck,
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'あなたの登録一覧',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      Expanded(
                        child: StreamBuilder<List<FinanceEntry>>(
                          stream: _repo.streamMyExpenseEntries(),
                          builder: (context, snapshot) {
                            if (snapshot.hasError) {
                              return Center(
                                child: Text('取得エラー: ${snapshot.error}'),
                              );
                            }
                            if (!snapshot.hasData) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }
                            final entries = snapshot.data!;
                            if (entries.isEmpty) {
                              return const Center(
                                child: Text('まだあなたの経費登録はありません'),
                              );
                            }
                            return ListView.separated(
                              itemCount: entries.length,
                              separatorBuilder: (_, _) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final entry = entries[index];
                                return ListTile(
                                  dense: true,
                                  title: Text(entry.category),
                                  subtitle: Text(
                                    '${dateFormat.format(entry.date)}  ${entry.memo}',
                                  ),
                                  trailing: Text(
                                    moneyFormat.format(entry.amount),
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
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ExpenseSummaryAdminTile extends StatelessWidget {
  const _ExpenseSummaryAdminTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const fill = Color(0xFFB45309);
    const onFill = Color(0xFFFAFAFA);
    return SizedBox(
      height: 56,
      child: FilledButton.icon(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: fill,
          foregroundColor: onFill,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        ),
        icon: const Icon(Icons.table_chart_outlined, size: 22),
        label: Text(
          '経費集計・CSV（管理者）',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: onFill,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _StoreUserPermissionsAdminTile extends StatelessWidget {
  const _StoreUserPermissionsAdminTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const fill = Color(0xFF5B21B6);
    const onFill = Color(0xFFFAFAFA);
    return SizedBox(
      height: 56,
      child: FilledButton.icon(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: fill,
          foregroundColor: onFill,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        ),
        icon: const Icon(Icons.group_outlined, size: 22),
        label: Text(
          'ユーザー権限（会計／経費）',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: onFill,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
