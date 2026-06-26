import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/admin_auth_service.dart';
import '../../data/repositories/check_repository.dart';
import '../../models/check_item.dart';
import '../../models/person_option.dart';
import '../shared/check_billing_summary_card.dart';
import '../shared/check_item_actions.dart';
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
  final _currency = NumberFormat.currency(
    locale: 'ja_JP',
    symbol: '¥',
    decimalDigits: 0,
  );
  PersonOption? _selectedPerson;
  bool _canOperate = false;
  String? _lastSelectedCheckId;
  bool _removingLine = false;
  bool _updatingLine = false;

  Future<void> _confirmRemoveLine(CheckItem item) async {
    final person = _selectedPerson;
    if (person == null || _removingLine) return;
    final ok = await confirmRemoveCheckItem(
      context,
      item: item,
      currency: _currency,
    );
    if (!ok || !mounted) return;
    setState(() => _removingLine = true);
    try {
      await _checkRepository.removeOrderItem(
        checkId: person.openCheckId,
        itemId: item.id,
        lineTotalTaxIncluded: item.lineTotalTaxIncluded,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('明細を削除しました')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('削除に失敗しました: $e')));
      }
    } finally {
      if (mounted) setState(() => _removingLine = false);
    }
  }

  Future<void> _editLineQty(CheckItem item) async {
    final person = _selectedPerson;
    if (person == null || !_canOperate || _updatingLine || _removingLine) {
      return;
    }
    final newQty = await showEditCheckItemQtyDialog(
      context,
      item: item,
      currency: _currency,
    );
    if (newQty == null || newQty == item.qty || !mounted) return;
    setState(() => _updatingLine = true);
    try {
      await _checkRepository.updateOrderItemQty(
        checkId: person.openCheckId,
        item: item,
        newQty: newQty,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('数量を変更しました')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('変更に失敗しました: $e')));
      }
    } finally {
      if (mounted) setState(() => _updatingLine = false);
    }
  }

  Future<void> _finalize() async {
    final person = _selectedPerson;
    if (person == null) return;
    await _checkRepository.finalizeCheck(person.openCheckId);
    if (mounted) {
      setState(() => _selectedPerson = null);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('会計を確定しました')));
    }
  }

  Future<void> _refreshAccessState() async {
    final canOperate = await _adminAuthService.isCurrentUserAdmin();
    if (mounted) setState(() => _canOperate = canOperate);
  }

  @override
  void initState() {
    super.initState();
    _refreshAccessState();
  }

  @override
  Widget build(BuildContext context) {
    final lineBusy = _removingLine || _updatingLine;

    return Scaffold(
      appBar: AppBar(title: const Text('会計')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
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
                    canOperate: _canOperate,
                    lineBusy: lineBusy,
                    onDeleteLine: _confirmRemoveLine,
                    onEditLine: _editLineQty,
                  ),
                )
              else
                const Expanded(child: Center(child: Text('会計対象の人を選択してください'))),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _selectedPerson == null || !_canOperate
                      ? null
                      : _finalize,
                  child: const Text('会計確定'),
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
    required this.canOperate,
    required this.lineBusy,
    required this.onDeleteLine,
    required this.onEditLine,
  });

  final String checkId;
  final NumberFormat currency;
  final bool canOperate;
  final bool lineBusy;
  final Future<void> Function(CheckItem item) onDeleteLine;
  final Future<void> Function(CheckItem item) onEditLine;

  @override
  Widget build(BuildContext context) {
    final repository = CheckRepository();
    return StreamBuilder(
      stream: repository.streamCheckSummary(checkId),
      builder: (context, summarySnapshot) {
        if (!summarySnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final summary = summarySnapshot.data!;
        final isPaid = summary.status == 'paid';

        return StreamBuilder<List<CheckItem>>(
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
                CheckBillingSummaryCard(
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
                            final editable =
                                canOperate && !isPaid && !lineBusy;
                            return ListTile(
                              dense: true,
                              onTap: editable ? () => onEditLine(item) : null,
                              title: Text(item.menuNameSnapshot),
                              subtitle: Text('数量 ${item.qty}'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(currency.format(item.lineTotalTaxIncluded)),
                                  if (canOperate && !isPaid) ...[
                                    IconButton(
                                      tooltip: '数量を変更',
                                      onPressed: lineBusy
                                          ? null
                                          : () => onEditLine(item),
                                      icon: const Icon(Icons.edit_outlined),
                                    ),
                                    IconButton(
                                      tooltip: 'この明細を削除',
                                      onPressed: lineBusy
                                          ? null
                                          : () => onDeleteLine(item),
                                      icon: const Icon(Icons.delete_outline),
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.error,
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
