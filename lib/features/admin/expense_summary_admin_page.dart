import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/admin_auth_service.dart';
import '../../core/csv_download.dart';
import '../../data/expense_accounts_master.dart';
import '../../data/repositories/finance_entry_repository.dart';
import '../../models/finance_entry.dart';
import '../home/home_page.dart';

enum _ExpensePeriodFilter { thisMonth, thisYear, all }

class ExpenseSummaryAdminPage extends StatefulWidget {
  const ExpenseSummaryAdminPage({super.key});

  static const routeName = '/admin/expense-summary';

  @override
  State<ExpenseSummaryAdminPage> createState() =>
      _ExpenseSummaryAdminPageState();
}

class _ExpenseSummaryAdminPageState extends State<ExpenseSummaryAdminPage> {
  final _adminAuthService = AdminAuthService();
  final _repo = FinanceEntryRepository();

  bool _checkingAdmin = true;
  bool _isAdmin = false;
  _ExpensePeriodFilter _period = _ExpensePeriodFilter.thisMonth;

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

  static String _csvCell(String value) {
    if (value.contains(',') ||
        value.contains('"') ||
        value.contains('\n') ||
        value.contains('\r')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  List<FinanceEntry> _filtered(List<FinanceEntry> all) {
    if (_period == _ExpensePeriodFilter.all) return List.of(all);
    final now = DateTime.now();
    if (_period == _ExpensePeriodFilter.thisMonth) {
      return all
          .where((e) => e.date.year == now.year && e.date.month == now.month)
          .toList();
    }
    return all.where((e) => e.date.year == now.year).toList();
  }

  Map<String, int> _totalsByCategory(List<FinanceEntry> entries) {
    final map = <String, int>{};
    for (final e in entries) {
      final key = expenseEntryGroupingKey(e);
      map[key] = (map[key] ?? 0) + e.amount;
    }
    return map;
  }

  String _buildCsv(List<FinanceEntry> rows) {
    final dateFmt = DateFormat('yyyy-MM-dd');
    final buf = StringBuffer()
      ..writeln(
        [
          'date',
          'category',
          'accountItemId',
          'amount',
          'memo',
          'createdBy',
          'entryId',
        ].join(','),
      );
    for (final e in rows) {
      final aid = resolvedExpenseAccountItemId(e);
      buf.writeln(
        [
          _csvCell(dateFmt.format(e.date)),
          _csvCell(entryDisplayExpenseCategory(e)),
          _csvCell(aid),
          e.amount.toString(),
          _csvCell(e.memo),
          _csvCell(e.createdBy),
          _csvCell(e.id),
        ].join(','),
      );
    }
    return buf.toString();
  }

  void _downloadCsv(List<FinanceEntry> filtered) {
    if (!kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('CSVダウンロードは現在 Web のみ対応しています')),
      );
      return;
    }
    final name =
        'expense_summary_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.csv';
    downloadCsvUtf8Bom(filename: name, csvBody: _buildCsv(filtered));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('CSVをダウンロードしました')));
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingAdmin) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('経費集計')),
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
                    '経費の全体集計は管理者のみ確認できます。',
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

    final money = NumberFormat.currency(
      locale: 'ja_JP',
      symbol: '¥',
      decimalDigits: 0,
    );
    final dateFmt = DateFormat('yyyy/MM/dd');

    return Scaffold(
      appBar: AppBar(
        title: const Text('経費集計（管理者）'),
        actions: [
          IconButton(
            tooltip: 'アプリホーム',
            icon: const Icon(Icons.home_outlined),
            onPressed: () => Navigator.pushNamed(context, HomePage.routeName),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: StreamBuilder<List<FinanceEntry>>(
            stream: _repo.streamAllExpenseEntries(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('読み込みエラー: ${snapshot.error}'));
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final all = snapshot.data!;
              final filtered = _filtered(all)
                ..sort((a, b) => b.date.compareTo(a.date));
              final byCat = _totalsByCategory(filtered);
              final grandTotal = filtered.fold<int>(0, (s, e) => s + e.amount);
              final catRows = byCat.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value));

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SegmentedButton<_ExpensePeriodFilter>(
                    segments: const [
                      ButtonSegment(
                        value: _ExpensePeriodFilter.thisMonth,
                        label: Text('今月'),
                      ),
                      ButtonSegment(
                        value: _ExpensePeriodFilter.thisYear,
                        label: Text('今年'),
                      ),
                      ButtonSegment(
                        value: _ExpensePeriodFilter.all,
                        label: Text('すべて'),
                      ),
                    ],
                    selected: {_period},
                    onSelectionChanged: (next) {
                      if (next.isEmpty) return;
                      setState(() => _period = next.first);
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '件数 ${filtered.length} ・ 合計 ${money.format(grandTotal)}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: filtered.isEmpty
                            ? null
                            : () => _downloadCsv(filtered),
                        icon: const Icon(Icons.download),
                        label: const Text('CSV'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text('科目別内訳', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 140,
                    child: Card(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('科目')),
                            DataColumn(label: Text('合計'), numeric: true),
                          ],
                          rows: [
                            for (final e in catRows)
                              DataRow(
                                cells: [
                                  DataCell(Text(expenseGroupingLabel(e.key))),
                                  DataCell(Text(money.format(e.value))),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '明細プレビュー',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Card(
                      child: filtered.isEmpty
                          ? const Center(child: Text('該当データがありません'))
                          : LayoutBuilder(
                              builder: (context, c) {
                                return Scrollbar(
                                  thumbVisibility: true,
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(
                                        minWidth: c.maxWidth,
                                      ),
                                      child: SingleChildScrollView(
                                        child: DataTable(
                                          columns: const [
                                            DataColumn(label: Text('日付')),
                                            DataColumn(label: Text('科目')),
                                            DataColumn(label: Text('科目ID')),
                                            DataColumn(
                                              label: Text('金額'),
                                              numeric: true,
                                            ),
                                            DataColumn(label: Text('メモ')),
                                            DataColumn(label: Text('登録UID')),
                                          ],
                                          rows: [
                                            for (final e in filtered)
                                              () {
                                                final aid =
                                                    resolvedExpenseAccountItemId(
                                                      e,
                                                    );
                                                return DataRow(
                                                  cells: [
                                                    DataCell(
                                                      Text(
                                                        dateFmt.format(e.date),
                                                      ),
                                                    ),
                                                    DataCell(
                                                      Text(
                                                        entryDisplayExpenseCategory(
                                                          e,
                                                        ),
                                                      ),
                                                    ),
                                                    DataCell(
                                                      Text(
                                                        aid.isEmpty ? '—' : aid,
                                                      ),
                                                    ),
                                                    DataCell(
                                                      Text(
                                                        money.format(e.amount),
                                                      ),
                                                    ),
                                                    DataCell(
                                                      Text(
                                                        e.memo.isEmpty
                                                            ? '—'
                                                            : e.memo,
                                                      ),
                                                    ),
                                                    DataCell(Text(e.createdBy)),
                                                  ],
                                                );
                                              }(),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// [store_user_permissions_page.dart] と同型のログインダイアログ。
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
      if (!mounted) return;
      Navigator.pop(context, true);
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
