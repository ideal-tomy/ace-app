import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/admin_auth_service.dart';
import '../../data/repositories/check_repository.dart';
import '../../data/repositories/menu_repository.dart';
import '../../models/check_item.dart';
import '../../models/check_summary.dart';
import '../../models/person_option.dart';
import '../shared/check_item_actions.dart';
import '../shared/check_status_compact_card.dart';
import '../shared/person_selector.dart';
import 'order_flow_sheet.dart';
import 'order_flow_state.dart';
import 'order_items_sheet.dart';

const _orderCtaColor = Color(0xFFEA580C);

class OrderPage extends StatefulWidget {
  const OrderPage({super.key});

  static const routeName = '/order';

  @override
  State<OrderPage> createState() => _OrderPageState();
}

class _OrderPageState extends State<OrderPage> {
  final _checkRepository = CheckRepository();
  final _menuRepository = MenuRepository();
  final _adminAuthService = AdminAuthService();
  final _currency = NumberFormat.currency(
    locale: 'ja_JP',
    symbol: '¥',
    decimalDigits: 0,
  );
  PersonOption? _selectedPerson;
  String? _lastSelectedCheckId;
  final Map<String, DraftOrderLine> _draftOrders = {};
  bool _removingLine = false;
  bool _updatingLine = false;

  Future<void> _confirmRemoveCheckItem(CheckItem item) async {
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

  Future<void> _editCheckItemQty(CheckItem item) async {
    final person = _selectedPerson;
    if (person == null || _updatingLine || _removingLine) return;
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

  Future<void> _openOrderFlow() async {
    final result = await showOrderFlowSheet(
      context,
      checkRepository: _checkRepository,
      menuRepository: _menuRepository,
      adminAuthService: _adminAuthService,
      initialPerson: _selectedPerson,
      existingDraft: _draftOrders.isEmpty ? null : _draftOrders,
    );
    if (!mounted || result == null) return;
    setState(() {
      _selectedPerson = result.person;
      _lastSelectedCheckId = result.person?.openCheckId;
      _draftOrders
        ..clear()
        ..addAll(result.draftOrders);
    });
  }

  Future<void> _openOrderItems({
    required List<CheckItem> registered,
    required CheckSummary summary,
  }) async {
    await showOrderItemsSheet(
      context,
      registered: registered,
      draftOrders: _draftOrders,
      currency: _currency,
      isPaid: summary.status == 'paid',
      lineBusy: _removingLine || _updatingLine,
      onEdit: _editCheckItemQty,
      onDelete: _confirmRemoveCheckItem,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('注文・伝票')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              StreamBuilder<List<PersonOption>>(
                stream: _checkRepository.streamOpenPeople(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Text('登録者取得エラー: ${snapshot.error}');
                  }
                  final people = snapshot.data ?? const <PersonOption>[];
                  return PersonSelector(
                    people: people,
                    label: '伝票の対象者',
                    initialSelectedCheckId: _lastSelectedCheckId,
                    showSearchField: false,
                    onSelected: (person) => setState(() {
                      _selectedPerson = person;
                      _lastSelectedCheckId = person?.openCheckId;
                    }),
                  );
                },
              ),
              const SizedBox(height: 16),
              Expanded(child: _buildContent()),
              const SizedBox(height: 12),
              SizedBox(
                height: 56,
                child: FilledButton.icon(
                  onPressed: _openOrderFlow,
                  style: FilledButton.styleFrom(
                    backgroundColor: _orderCtaColor,
                    foregroundColor: const Color(0xFFFAFAFA),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.add),
                  label: Text(
                    _draftOrders.isEmpty ? '注文を追加' : '注文を追加（仮注文あり）',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: const Color(0xFFFAFAFA),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  int get _draftTotal => _draftOrders.values.fold(
    0,
    (sum, line) => sum + line.lineTotal,
  );

  int get _draftCount =>
      _draftOrders.values.fold(0, (sum, line) => sum + line.qty);

  Widget _buildContent() {
    final person = _selectedPerson;
    if (person == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(
              '対象者を選ぶと会計状況を確認できます',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return StreamBuilder<CheckSummary?>(
      stream: _checkRepository.streamCheckSummary(person.openCheckId),
      builder: (context, summarySnap) {
        if (summarySnap.hasError) {
          return Center(child: Text('伝票: ${summarySnap.error}'));
        }
        if (!summarySnap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final summary = summarySnap.data;
        if (summary == null) {
          return const Center(child: Text('伝票が見つかりません'));
        }

        return StreamBuilder<List<CheckItem>>(
          stream: _checkRepository.streamCheckItems(person.openCheckId),
          builder: (context, itemsSnap) {
            if (itemsSnap.hasError) {
              return Center(child: Text('明細: ${itemsSnap.error}'));
            }
            if (!itemsSnap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final registered = itemsSnap.data!;
            final itemCount =
                registered.fold(0, (s, i) => s + i.qty) + _draftCount;

            return Column(
              children: [
                const Spacer(),
                CheckStatusCompactCard(
                  summary: summary,
                  items: registered,
                  currency: _currency,
                  draftCount: _draftCount,
                  draftTotal: _draftTotal,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: () => _openOrderItems(
                      registered: registered,
                      summary: summary,
                    ),
                    icon: const Icon(Icons.list_alt_outlined),
                    label: Text(
                      itemCount > 0
                          ? '注文明細を見る（$itemCount 点）'
                          : '注文明細を見る',
                    ),
                  ),
                ),
                const Spacer(flex: 2),
              ],
            );
          },
        );
      },
    );
  }
}
