import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/admin_auth_service.dart';
import '../../core/billing_rules.dart';
import '../../core/business_mode.dart';
import '../../data/repositories/check_repository.dart';
import '../../models/check_item.dart';
import '../../models/check_summary.dart';
import '../../models/person_option.dart';
import '../shared/person_selector.dart';

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key});

  static const routeName = '/checkout';

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final _checkRepository = CheckRepository();
  final _adminAuthService = AdminAuthService();
  final _currency = NumberFormat.currency(locale: 'ja_JP', symbol: '¥', decimalDigits: 0);
  PersonOption? _selectedPerson;
  bool _isAdmin = false;
  bool _adminBusy = false;
  String? _lastSelectedCheckId;
  bool _removingLine = false;

  Future<void> _confirmRemoveLine(CheckItem item) async {
    final person = _selectedPerson;
    if (person == null || _removingLine) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('明細の削除'),
        content: Text(
          '次の注文を削除しますか？\n\n'
          '${item.menuNameSnapshot}\n'
          '数量 ${item.qty} ・ ${_currency.format(item.lineTotalTaxIncluded)}',
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
    setState(() => _removingLine = true);
    try {
      await _checkRepository.removeOrderItem(
        checkId: person.openCheckId,
        itemId: item.id,
        lineTotalTaxIncluded: item.lineTotalTaxIncluded,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('明細を削除しました')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('削除に失敗しました: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _removingLine = false);
    }
  }

  Future<void> _finalize() async {
    final person = _selectedPerson;
    if (person == null) return;
    await _checkRepository.finalizeCheck(person.openCheckId);
    if (mounted) {
      setState(() => _selectedPerson = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('会計を確定しました')),
      );
    }
  }

  Future<void> _loginAsAdmin() async {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    String? errorText;
    var submitting = false;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            Future<void> submit() async {
              final email = emailController.text.trim();
              final password = passwordController.text;
              if (email.isEmpty || password.isEmpty) {
                setDialogState(() => errorText = 'メールアドレスとパスワードを入力してください');
                return;
              }
              setDialogState(() {
                submitting = true;
                errorText = null;
              });
              try {
                await _adminAuthService.signInWithEmailPassword(
                  email: email,
                  password: password,
                );
                if (ctx.mounted) Navigator.pop(ctx, true);
              } catch (error) {
                setDialogState(() => errorText = 'ログインに失敗しました: $error');
              } finally {
                if (ctx.mounted) {
                  setDialogState(() => submitting = false);
                }
              }
            }

            return AlertDialog(
              title: const Text('管理者ログイン'),
              content: SizedBox(
                width: 360,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: emailController,
                      enabled: !submitting,
                      decoration: const InputDecoration(
                        labelText: 'メールアドレス',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: passwordController,
                      enabled: !submitting,
                      decoration: const InputDecoration(
                        labelText: 'パスワード',
                        border: OutlineInputBorder(),
                      ),
                      obscureText: true,
                      onSubmitted: (_) => submitting ? null : submit(),
                    ),
                    if (errorText != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        errorText!,
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: submitting ? null : () => Navigator.pop(ctx, false),
                  child: const Text('キャンセル'),
                ),
                FilledButton(
                  onPressed: submitting ? null : submit,
                  child: Text(submitting ? '確認中...' : 'ログイン'),
                ),
              ],
            );
          },
        );
      },
    );

    emailController.dispose();
    passwordController.dispose();
    if (result != true || !mounted) return;
    await _refreshAdminState();
  }

  Future<void> _refreshAdminState() async {
    setState(() => _adminBusy = true);
    try {
      if (_adminAuthService.isCurrentUserAnonymous) {
        if (mounted) setState(() => _isAdmin = false);
        return;
      }
      final isAdmin = await _adminAuthService.isCurrentUserAdmin();
      if (mounted) setState(() => _isAdmin = isAdmin);
    } finally {
      if (mounted) setState(() => _adminBusy = false);
    }
  }

  Future<void> _signOutAdmin() async {
    setState(() => _adminBusy = true);
    try {
      await _adminAuthService.signOut();
      if (mounted) setState(() => _isAdmin = false);
    } finally {
      if (mounted) setState(() => _adminBusy = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _refreshAdminState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('会計')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                children: [
                  Text(_isAdmin ? '管理者モード有効' : '一般モード'),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _adminBusy ? null : (_isAdmin ? _signOutAdmin : _loginAsAdmin),
                    icon: Icon(_isAdmin ? Icons.logout : Icons.lock_open),
                    label: Text(_isAdmin ? '管理者ログアウト' : '管理者ログイン'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '会計は伝票の営業モード（来店登録時）に基づいて計算されます',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              StreamBuilder<List<PersonOption>>(
                stream: _checkRepository.streamOpenPeople(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Text('会計対象取得エラー: ${snapshot.error}');
                  }
                  final people = snapshot.data ?? const <PersonOption>[];
                  return PersonSelector(
                    people: people,
                    label: '会計対象の人',
                    initialSelectedCheckId: _lastSelectedCheckId,
                    onSelected: (person) => setState(() {
                      _selectedPerson = person;
                      _lastSelectedCheckId = person?.openCheckId;
                    }),
                  );
                },
              ),
              const SizedBox(height: 10),
              if (_selectedPerson != null)
                Expanded(
                  child: _CheckDetail(
                    checkId: _selectedPerson!.openCheckId,
                    currency: _currency,
                    onDeleteLine: _isAdmin && !_removingLine ? _confirmRemoveLine : null,
                  ),
                )
              else
                const Expanded(
                  child: Center(child: Text('会計対象の人を選択してください')),
                ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _selectedPerson == null || !_isAdmin ? null : _finalize,
                  child: const Text('会計確定（管理者のみ）'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CheckDetail extends StatelessWidget {
  const _CheckDetail({
    required this.checkId,
    required this.currency,
    this.onDeleteLine,
  });

  final String checkId;
  final NumberFormat currency;
  final Future<void> Function(CheckItem item)? onDeleteLine;

  @override
  Widget build(BuildContext context) {
    final repository = CheckRepository();
    return StreamBuilder<CheckSummary?>(
      stream: repository.streamCheckSummary(checkId),
      builder: (context, summarySnapshot) {
        if (!summarySnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final summary = summarySnapshot.data!;
        return Column(
          children: [
            Expanded(
              child: StreamBuilder<List<CheckItem>>(
                stream: repository.streamCheckItems(checkId),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('明細取得エラー: ${snapshot.error}'));
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final items = snapshot.data!;
                  return Column(
                    children: [
                      _TotalCard(
                        summary: summary,
                        items: items,
                        currency: currency,
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: items.isEmpty
                            ? const Center(child: Text('注文履歴はまだありません'))
                            : ListView.separated(
                                itemCount: items.length,
                                separatorBuilder: (_, _) => const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final item = items[index];
                                  return ListTile(
                                    dense: true,
                                    title: Text(item.menuNameSnapshot),
                                    subtitle: Text('数量 ${item.qty}'),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(currency.format(item.lineTotalTaxIncluded)),
                                        if (onDeleteLine != null)
                                          IconButton(
                                            tooltip: 'この明細を削除',
                                            onPressed: () => onDeleteLine!(item),
                                            icon: const Icon(Icons.delete_outline),
                                            color: Theme.of(context).colorScheme.error,
                                          ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TotalCard extends StatelessWidget {
  const _TotalCard({
    required this.summary,
    required this.items,
    required this.currency,
  });

  final CheckSummary summary;
  final List<CheckItem> items;
  final NumberFormat currency;

  @override
  Widget build(BuildContext context) {
    final breakdown = buildBillingBreakdown(
      summary: summary,
      items: items,
      now: DateTime.now(),
    );
    final isNormal = summary.billingMode == BusinessMode.normal;
    final isPaid = summary.status == 'paid';
    final total = isPaid && summary.finalAmount != null
        ? summary.finalAmount!
        : (isNormal ? breakdown.normalTotal : summary.totalTaxIncluded);
    final timeCharge = isPaid ? (summary.timeChargeFinal ?? breakdown.timeCharge) : breakdown.timeCharge;
    final separate = isPaid
        ? (summary.separateFinal ?? breakdown.separateDrinksTotal)
        : breakdown.separateDrinksTotal;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(summary.customerNameSnapshot, style: Theme.of(context).textTheme.titleMedium),
                Text('営業モード: ${isNormal ? '通常営業' : 'イベント営業'}'),
                    Text('登録時間: ${DateFormat('yyyy/MM/dd HH:mm').format(summary.createdAt)}'),
                    Text('内税10%: ${currency.format(summary.taxAmount)}'),
                if (isNormal) ...[
                  Text('通常飲料: ${currency.format(breakdown.mainDrinksTotal)}'),
                  Text('時間料金: ${currency.format(timeCharge)}'),
                  Text('別会計: ${currency.format(separate)}'),
                ],
                if (isPaid) const Text('※会計確定済み（固定金額）'),
              ],
            ),
            Text(
              currency.format(total),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ],
        ),
      ),
    );
  }
}
