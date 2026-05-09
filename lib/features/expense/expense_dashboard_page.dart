import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/repositories/finance_entry_repository.dart';
import '../home/home_page.dart';
import '../../models/finance_entry.dart';

class ExpenseDashboardPage extends StatefulWidget {
  const ExpenseDashboardPage({super.key});

  static const routeName = '/expense';

  @override
  State<ExpenseDashboardPage> createState() => _ExpenseDashboardPageState();
}

class _ExpenseDashboardPageState extends State<ExpenseDashboardPage> {
  final _repo = FinanceEntryRepository();
  final _categoryController = TextEditingController();
  final _amountController = TextEditingController();
  final _memoController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _categoryController.dispose();
    _amountController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final category = _categoryController.text.trim();
    final amount = int.tryParse(_amountController.text.trim()) ?? 0;
    if (category.isEmpty || amount <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('科目と金額を正しく入力してください')));
      return;
    }
    setState(() => _submitting = true);
    try {
      await _repo.addExpenseEntry(
        date: DateTime.now(),
        category: category,
        amount: amount,
        memo: _memoController.text,
      );
      if (!mounted) return;
      _categoryController.clear();
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
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      TextField(
                        controller: _categoryController,
                        enabled: !_submitting,
                        decoration: const InputDecoration(
                          labelText: '科目（例: 消耗品費）',
                          border: OutlineInputBorder(),
                        ),
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
              const SizedBox(height: 10),
              Expanded(
                child: StreamBuilder<List<FinanceEntry>>(
                  stream: _repo.streamExpenseEntries(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(child: Text('取得エラー: ${snapshot.error}'));
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final entries = snapshot.data!;
                    if (entries.isEmpty) {
                      return const Center(child: Text('まだ経費データはありません'));
                    }
                    return ListView.separated(
                      itemCount: entries.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final entry = entries[index];
                        return ListTile(
                          title: Text(entry.category),
                          subtitle: Text(
                            '${dateFormat.format(entry.date)}  ${entry.memo}',
                          ),
                          trailing: Text(moneyFormat.format(entry.amount)),
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
  }
}
