import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/admin_auth_service.dart';
import '../../core/menu_category_catalog.dart';
import '../../data/repositories/check_repository.dart';
import '../../data/repositories/menu_repository.dart';
import '../admin/menu_edit_page.dart';
import '../../models/check_item.dart';
import '../../models/menu_item.dart';
import '../../models/person_option.dart';
import '../shared/person_selector.dart';

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
  final _currency = NumberFormat.currency(locale: 'ja_JP', symbol: '¥', decimalDigits: 0);
  PersonOption? _selectedPerson;
  String? _activeCategory;
  bool _seeding = false;
  String? _lastSelectedCheckId;
  final Map<String, _DraftOrderLine> _draftOrders = {};
  bool _submittingDraft = false;
  bool _removingLine = false;

  Future<void> _confirmRemoveCheckItem(CheckItem item) async {
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

  Future<void> _addDraftItem(MenuItem item) async {
    final qty = await showDialog<int>(
      context: context,
      builder: (_) => _QtyDialog(menuName: item.name),
    );
    if (qty == null || qty <= 0) return;
    setState(() {
      final existing = _draftOrders[item.id];
      if (existing == null) {
        _draftOrders[item.id] = _DraftOrderLine(menu: item, qty: qty);
      } else {
        _draftOrders[item.id] = existing.copyWith(qty: existing.qty + qty);
      }
    });
  }

  Future<void> _submitDraftOrder() async {
    final person = _selectedPerson;
    if (person == null || _draftOrders.isEmpty || _submittingDraft) return;

    setState(() => _submittingDraft = true);
    try {
      for (final line in _draftOrders.values) {
        await _checkRepository.addOrderItem(
          checkId: person.openCheckId,
          menu: line.menu,
          qty: line.qty,
        );
      }
      if (mounted) {
        setState(() => _draftOrders.clear());
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('注文確定に失敗しました: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _submittingDraft = false);
    }
  }

  Future<void> _openDraftConfirmDialog() async {
    if (_draftOrders.isEmpty) return;
    final result = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('注文内容の確認'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: _draftOrders.values
                  .map(
                    (line) => ListTile(
                      dense: true,
                      title: Text(line.menu.name),
                      subtitle: Text('数量 ${line.qty}'),
                      trailing: Text(_currency.format(line.menu.priceTaxIncluded * line.qty)),
                    ),
                  )
                  .toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('追加注文を続ける'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('注文を確定'),
            ),
          ],
        );
      },
    );
    if (result == true) {
      await _submitDraftOrder();
    }
  }

  int get _draftTotal => _draftOrders.values.fold(
        0,
        (sum, line) => sum + (line.menu.priceTaxIncluded * line.qty),
      );
  int get _draftCount => _draftOrders.values.fold(0, (sum, line) => sum + line.qty);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('注文受付')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
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
                    label: '注文対象の人',
                    initialSelectedCheckId: _lastSelectedCheckId,
                    showSearchField: false,
                    onSelected: (person) => setState(() {
                      _selectedPerson = person;
                      _lastSelectedCheckId = person?.openCheckId;
                    }),
                  );
                },
              ),
              const SizedBox(height: 12),
              if (_selectedPerson != null) ...[
                StreamBuilder<List<CheckItem>>(
                  stream: _checkRepository.streamCheckItems(_selectedPerson!.openCheckId),
                  builder: (context, snap) {
                    if (snap.hasError) {
                      return Center(child: Text('明細: ${snap.error}'));
                    }
                    if (!snap.hasData) {
                      return const SizedBox(
                        height: 72,
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final registered = snap.data!;
                    final hasAnyOrders = registered.isNotEmpty || _draftOrders.isNotEmpty;
                    if (!hasAnyOrders) {
                      return const SizedBox.shrink();
                    }
                    return Column(
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '登録済み注文',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                        const SizedBox(height: 6),
                        SizedBox(
                          height: 108,
                          child: Card(
                            clipBehavior: Clip.antiAlias,
                            child: ListView(
                              children: [
                                for (final line in _draftOrders.values) ...[
                                  ListTile(
                                    dense: true,
                                    title: Text(
                                      line.menu.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    subtitle: Text('数量 ${line.qty} ・ 未確定'),
                                    trailing: Text(
                                      _currency.format(line.menu.priceTaxIncluded * line.qty),
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ),
                                  const Divider(height: 1),
                                ],
                                for (var i = 0; i < registered.length; i++) ...[
                                  _RegisteredOrderLineTile(
                                    item: registered[i],
                                    currency: _currency,
                                    removingLine: _removingLine,
                                    onDelete: _confirmRemoveCheckItem,
                                  ),
                                  if (i != registered.length - 1) const Divider(height: 1),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    );
                  },
                ),
              ],
              Expanded(
                child: StreamBuilder<List<MenuItem>>(
                  stream: _menuRepository.streamActiveMenus(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Text('メニュー取得エラー: ${snapshot.error}'),
                      );
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final menus = snapshot.data!;
                    if (menus.isEmpty) {
                      return FutureBuilder<bool>(
                        future: _adminAuthService.isCurrentUserAnonymous
                            ? Future<bool>.value(false)
                            : _adminAuthService.isCurrentUserAdmin(),
                        builder: (context, adminSnapshot) {
                          final isAdmin = adminSnapshot.data == true;
                          return Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('メニュー未登録です'),
                                const SizedBox(height: 8),
                                Text(
                                  isAdmin
                                      ? '管理者として初期メニューを登録できます'
                                      : '管理者ログイン後に初期メニューを登録できます',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                const SizedBox(height: 12),
                                FilledButton(
                                  onPressed: (_seeding || !isAdmin)
                                      ? null
                                      : () async {
                                          final messenger = ScaffoldMessenger.of(context);
                                          setState(() => _seeding = true);
                                          try {
                                            await _menuRepository.seedMenusFromAssetIfEmpty();
                                            if (mounted) {
                                              messenger.showSnackBar(
                                                const SnackBar(content: Text('初期メニューを登録しました')),
                                              );
                                            }
                                          } catch (error) {
                                            if (mounted) {
                                              messenger.showSnackBar(
                                                SnackBar(content: Text('登録失敗: $error')),
                                              );
                                            }
                                          } finally {
                                            if (mounted) setState(() => _seeding = false);
                                          }
                                        },
                                  child: Text(_seeding ? '登録中...' : '初期メニューを登録'),
                                ),
                                if (!isAdmin) ...[
                                  const SizedBox(height: 8),
                                  TextButton(
                                    onPressed: () => Navigator.pushNamed(
                                      context,
                                      MenuEditPage.routeName,
                                    ),
                                    child: const Text('管理者ログインへ（メニュー編集）'),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      );
                    }

                    final categories = menus.map((m) => m.category).toSet().toList()
                      ..sort(MenuCategoryCatalog.compareKeys);
                    _activeCategory ??= categories.first;
                    final shown = menus.where((m) => m.category == _activeCategory).toList();

                    return Column(
                      children: [
                        SizedBox(
                          height: 44,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: categories.length,
                            separatorBuilder: (_, _) => const SizedBox(width: 8),
                            itemBuilder: (context, index) {
                              final cat = categories[index];
                              final selected = cat == _activeCategory;
                              return ChoiceChip(
                                label: Text(MenuCategoryCatalog.labelFor(cat)),
                                selected: selected,
                                onSelected: (_) => setState(() => _activeCategory = cat),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: GridView.builder(
                            itemCount: shown.length,
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 8,
                              crossAxisSpacing: 8,
                              childAspectRatio: 2.2,
                            ),
                            itemBuilder: (context, index) {
                              final item = shown[index];
                              return FilledButton.tonal(
                                onPressed: _selectedPerson == null ? null : () => _addDraftItem(item),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                                    const SizedBox(height: 4),
                                    Text(_currency.format(item.priceTaxIncluded)),
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
              if (_draftOrders.isNotEmpty) ...[
                const SizedBox(height: 8),
                Card(
                  child: ListTile(
                    title: Text('仮注文 $_draftCount 点'),
                    subtitle: Text(_currency.format(_draftTotal)),
                    trailing: FilledButton(
                      onPressed: _submittingDraft ? null : _openDraftConfirmDialog,
                      child: Text(_submittingDraft ? '確定中...' : '注文内容を確認'),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DraftOrderLine {
  const _DraftOrderLine({required this.menu, required this.qty});

  final MenuItem menu;
  final int qty;

  _DraftOrderLine copyWith({int? qty}) {
    return _DraftOrderLine(menu: menu, qty: qty ?? this.qty);
  }
}

class _RegisteredOrderLineTile extends StatelessWidget {
  const _RegisteredOrderLineTile({
    required this.item,
    required this.currency,
    required this.removingLine,
    required this.onDelete,
  });

  final CheckItem item;
  final NumberFormat currency;
  final bool removingLine;
  final Future<void> Function(CheckItem item) onDelete;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      title: Text(item.menuNameSnapshot, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text('数量 ${item.qty}'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            currency.format(item.lineTotalTaxIncluded),
            style: const TextStyle(fontSize: 13),
          ),
          IconButton(
            tooltip: 'この明細を削除',
            icon: const Icon(Icons.delete_outline, size: 20),
            color: Theme.of(context).colorScheme.error,
            onPressed: removingLine ? null : () => onDelete(item),
          ),
        ],
      ),
    );
  }
}

class _QtyDialog extends StatefulWidget {
  const _QtyDialog({required this.menuName});
  final String menuName;

  @override
  State<_QtyDialog> createState() => _QtyDialogState();
}

class _QtyDialogState extends State<_QtyDialog> {
  int qty = 1;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${widget.menuName} の数量'),
      content: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(onPressed: qty > 1 ? () => setState(() => qty--) : null, icon: const Icon(Icons.remove)),
          Text('$qty', style: Theme.of(context).textTheme.headlineSmall),
          IconButton(onPressed: () => setState(() => qty++), icon: const Icon(Icons.add)),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('キャンセル')),
        FilledButton(onPressed: () => Navigator.pop(context, qty), child: const Text('追加')),
      ],
    );
  }
}
