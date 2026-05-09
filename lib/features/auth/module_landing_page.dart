import 'package:flutter/material.dart';

import 'login_entry_target.dart';

/// ログイン前: 会計ダッシュボード用と経費用のどちらでログインするか選択する。
class ModuleLandingPage extends StatelessWidget {
  const ModuleLandingPage({
    super.key,
    required this.onSelectAccounting,
    required this.onSelectExpense,
  });

  final VoidCallback onSelectAccounting;
  final VoidCallback onSelectExpense;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('簡易会計')),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 40,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '利用するメニューを選んでください',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '選んだあと、そのメニュー用のログイン画面になります。',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 28),
                    _EntryCard(
                      target: LoginEntryTarget.accounting,
                      onTap: onSelectAccounting,
                    ),
                    const SizedBox(height: 16),
                    _EntryCard(
                      target: LoginEntryTarget.expense,
                      onTap: onSelectExpense,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.target, required this.onTap});

  final LoginEntryTarget target;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (IconData icon, String title, String subtitle) = switch (target) {
      LoginEntryTarget.accounting => (
        Icons.account_balance_wallet_outlined,
        '会計ダッシュボード',
        '来店〜会計処理・伝票など',
      ),
      LoginEntryTarget.expense => (
        Icons.request_quote_outlined,
        '経費',
        '経費の入力・一覧',
      ),
    };

    return Material(
      color: Colors.white,
      elevation: 1,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Icon(
                icon,
                size: 36,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Theme.of(context).colorScheme.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
