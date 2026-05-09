import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/admin_auth_service.dart';
import '../../core/billing_rules.dart';
import '../../core/business_mode.dart';
import '../../core/menu_category_catalog.dart';
import '../../data/repositories/check_repository.dart';
import '../../data/repositories/menu_repository.dart';
import '../admin/menu_edit_page.dart';
import '../../models/check_item.dart';
import '../../models/check_summary.dart';
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
  static const _tequilaOthersCategory = 'TEQUILA_OTHERS';
  static const _foodDailyCategory = 'FOOD_DAILY';
  final _checkRepository = CheckRepository();
  final _menuRepository = MenuRepository();
  final _adminAuthService = AdminAuthService();
  final _currency = NumberFormat.currency(
    locale: 'ja_JP',
    symbol: '¥',
    decimalDigits: 0,
  );
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

  Future<void> _openFoodOrderDialog() async {
    if (_selectedPerson == null) return;
    final form = await showDialog<_CustomFoodOrderForm>(
      context: context,
      builder: (_) => const _CustomFoodOrderDialog(),
    );
    if (form == null) return;
    final menu = MenuItem(
      id: 'food-${DateTime.now().microsecondsSinceEpoch}',
      name: form.name,
      category: _foodDailyCategory,
      priceTaxIncluded: form.priceTaxIncluded,
      isActive: true,
      sortOrder: 9999,
    );
    setState(() {
      _draftOrders[menu.id] = _DraftOrderLine(menu: menu, qty: 1);
    });
  }

  Future<void> _openDartsGoodsDialog() async {
    if (_selectedPerson == null) return;
    final form = await showDialog<_DartsGoodsOrderForm>(
      context: context,
      builder: (_) => const _DartsGoodsOrderDialog(),
    );
    if (form == null) return;
    final menu = MenuItem(
      id: 'goods-${DateTime.now().microsecondsSinceEpoch}',
      name: 'ダーツグッズ（${form.typeLabel}）',
      category: form.categoryKey,
      priceTaxIncluded: form.priceTaxIncluded,
      isActive: true,
      sortOrder: 9999,
    );
    setState(() {
      _draftOrders[menu.id] = _DraftOrderLine(menu: menu, qty: 1);
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('注文確定に失敗しました: $error')));
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
                      trailing: Text(
                        _currency.format(line.menu.priceTaxIncluded * line.qty),
                      ),
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
  int get _draftCount =>
      _draftOrders.values.fold(0, (sum, line) => sum + line.qty);

  String _normalModeCategoryKey(MenuItem item) {
    if (item.category == 'TEQUILA' || item.category == 'OTHERS') {
      return _tequilaOthersCategory;
    }
    return item.category;
  }

  String _normalModeCategoryLabel(String categoryKey) {
    if (categoryKey == _tequilaOthersCategory) {
      return 'テキーラ他';
    }
    return MenuCategoryCatalog.labelFor(categoryKey);
  }

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
                  stream: _checkRepository.streamCheckItems(
                    _selectedPerson!.openCheckId,
                  ),
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
                    final hasAnyOrders =
                        registered.isNotEmpty || _draftOrders.isNotEmpty;
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
                                      _currency.format(
                                        line.menu.priceTaxIncluded * line.qty,
                                      ),
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
                                  if (i != registered.length - 1)
                                    const Divider(height: 1),
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
                                          final messenger =
                                              ScaffoldMessenger.of(context);
                                          setState(() => _seeding = true);
                                          try {
                                            await _menuRepository
                                                .seedMenusFromAssetIfEmpty();
                                            if (mounted) {
                                              messenger.showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    '初期メニューを登録しました',
                                                  ),
                                                ),
                                              );
                                            }
                                          } catch (error) {
                                            if (mounted) {
                                              messenger.showSnackBar(
                                                SnackBar(
                                                  content: Text('登録失敗: $error'),
                                                ),
                                              );
                                            }
                                          } finally {
                                            if (mounted) {
                                              setState(() => _seeding = false);
                                            }
                                          }
                                        },
                                  child: Text(
                                    _seeding ? '登録中...' : '初期メニューを登録',
                                  ),
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

                    final selectedPerson = _selectedPerson;
                    return StreamBuilder<CheckSummary?>(
                      stream: selectedPerson == null
                          ? null
                          : _checkRepository.streamCheckSummary(
                              selectedPerson.openCheckId,
                            ),
                      builder: (context, checkSummarySnapshot) {
                        final checkMode =
                            checkSummarySnapshot.data?.billingMode;
                        final globalMode = BusinessModeState.notifier.value;
                        final isNormalCheck =
                            checkMode == BusinessMode.normal &&
                            globalMode == BusinessMode.normal;
                        final sourceMenus = isNormalCheck
                            ? menus.where(isSeparateAccountingMenu).toList()
                            : menus;

                        if (sourceMenus.isEmpty) {
                          return Center(
                            child: Text(
                              isNormalCheck
                                  ? '通常営業では例外ドリンクのみ注文可能です（対象メニューが未登録です）'
                                  : '表示可能なメニューがありません',
                            ),
                          );
                        }

                        final categories =
                            sourceMenus
                                .map(
                                  (m) => isNormalCheck
                                      ? _normalModeCategoryKey(m)
                                      : m.category,
                                )
                                .toSet()
                                .toList()
                              ..sort((a, b) {
                                if (a == _tequilaOthersCategory) {
                                  return b == _tequilaOthersCategory ? 0 : 1;
                                }
                                if (b == _tequilaOthersCategory) return -1;
                                return MenuCategoryCatalog.compareKeys(a, b);
                              });
                        if (!categories.contains(_activeCategory)) {
                          _activeCategory = categories.first;
                        }
                        final shown = sourceMenus.where((m) {
                          if (!isNormalCheck) {
                            return m.category == _activeCategory;
                          }
                          return _normalModeCategoryKey(m) == _activeCategory;
                        }).toList();

                        return Column(
                          children: [
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(10),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                      '追加オーダー',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleSmall,
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: FilledButton.icon(
                                            onPressed: _selectedPerson == null
                                                ? null
                                                : _openFoodOrderDialog,
                                            icon: const Icon(
                                              Icons.restaurant_menu,
                                            ),
                                            label: const Text('フード追加'),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: FilledButton.icon(
                                            onPressed: _selectedPerson == null
                                                ? null
                                                : _openDartsGoodsDialog,
                                            icon: const Icon(
                                              Icons.shopping_bag_outlined,
                                            ),
                                            label: const Text('グッズ販売追加'),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (isNormalCheck)
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  '通常営業中: 例外ドリンクのみ注文できます',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                            if (isNormalCheck) const SizedBox(height: 6),
                            SizedBox(
                              height: 44,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: categories.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(width: 8),
                                itemBuilder: (context, index) {
                                  final cat = categories[index];
                                  final selected = cat == _activeCategory;
                                  final categoryLabel = isNormalCheck
                                      ? _normalModeCategoryLabel(cat)
                                      : MenuCategoryCatalog.labelFor(cat);
                                  return ChoiceChip(
                                    label: Text(categoryLabel),
                                    selected: selected,
                                    onSelected: (_) =>
                                        setState(() => _activeCategory = cat),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: GridView.builder(
                                itemCount: shown.length,
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                      mainAxisSpacing: 8,
                                      crossAxisSpacing: 8,
                                      childAspectRatio: 2.2,
                                    ),
                                itemBuilder: (context, index) {
                                  final item = shown[index];
                                  return FilledButton.tonal(
                                    onPressed: _selectedPerson == null
                                        ? null
                                        : () => _addDraftItem(item),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          item.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _currency.format(
                                            item.priceTaxIncluded,
                                          ),
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
                      onPressed: _submittingDraft
                          ? null
                          : _openDraftConfirmDialog,
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
      title: Text(
        item.menuNameSnapshot,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
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
          IconButton(
            onPressed: qty > 1 ? () => setState(() => qty--) : null,
            icon: const Icon(Icons.remove),
          ),
          Text('$qty', style: Theme.of(context).textTheme.headlineSmall),
          IconButton(
            onPressed: () => setState(() => qty++),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, qty),
          child: const Text('追加'),
        ),
      ],
    );
  }
}

class _CustomFoodOrderForm {
  const _CustomFoodOrderForm({
    required this.name,
    required this.priceTaxIncluded,
  });

  final String name;
  final int priceTaxIncluded;
}

class _CustomFoodOrderDialog extends StatefulWidget {
  const _CustomFoodOrderDialog();

  @override
  State<_CustomFoodOrderDialog> createState() => _CustomFoodOrderDialogState();
}

class _CustomFoodOrderDialogState extends State<_CustomFoodOrderDialog> {
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    final price = int.tryParse(
      _priceController.text.trim().replaceAll(',', ''),
    );
    if (name.isEmpty) {
      setState(() => _error = 'フード名を入力してください');
      return;
    }
    if (price == null || price < 0) {
      setState(() => _error = '金額を正しく入力してください');
      return;
    }
    Navigator.pop(
      context,
      _CustomFoodOrderForm(name: name, priceTaxIncluded: price),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('フード追加'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'オーダー名',
                hintText: '例）本日のおすすめ',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _priceController,
              decoration: const InputDecoration(
                labelText: '金額（税込）',
                prefixText: '¥',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
        FilledButton(onPressed: _submit, child: const Text('仮注文に追加')),
      ],
    );
  }
}

class _DartsGoodsOrderForm {
  const _DartsGoodsOrderForm({
    required this.typeLabel,
    required this.categoryKey,
    required this.priceTaxIncluded,
  });

  final String typeLabel;
  final String categoryKey;
  final int priceTaxIncluded;
}

class _DartsGoodsOrderDialog extends StatefulWidget {
  const _DartsGoodsOrderDialog();

  @override
  State<_DartsGoodsOrderDialog> createState() => _DartsGoodsOrderDialogState();
}

class _DartsGoodsOrderDialogState extends State<_DartsGoodsOrderDialog> {
  static const _goodsTypes = <_DartsGoodsType>[
    _DartsGoodsType(label: 'バレル', categoryKey: 'DARTS_BARREL'),
    _DartsGoodsType(label: 'フライト', categoryKey: 'DARTS_FLIGHT'),
    _DartsGoodsType(label: 'シャフト', categoryKey: 'DARTS_SHAFT'),
    _DartsGoodsType(label: 'チップ', categoryKey: 'DARTS_TIP'),
    _DartsGoodsType(label: 'その他', categoryKey: 'DARTS_OTHER'),
  ];

  _DartsGoodsType _selectedType = _goodsTypes.first;
  final _priceController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  void _submit() {
    final price = int.tryParse(
      _priceController.text.trim().replaceAll(',', ''),
    );
    if (price == null || price < 0) {
      setState(() => _error = '金額を正しく入力してください');
      return;
    }
    Navigator.pop(
      context,
      _DartsGoodsOrderForm(
        typeLabel: _selectedType.label,
        categoryKey: _selectedType.categoryKey,
        priceTaxIncluded: price,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('グッズ販売追加'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InputDecorator(
              decoration: const InputDecoration(
                labelText: '種類',
                border: OutlineInputBorder(),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<_DartsGoodsType>(
                  isExpanded: true,
                  value: _selectedType,
                  items: _goodsTypes
                      .map(
                        (type) => DropdownMenuItem<_DartsGoodsType>(
                          value: type,
                          child: Text(type.label),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedType = value);
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _priceController,
              decoration: const InputDecoration(
                labelText: '金額（税込）',
                prefixText: '¥',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
        FilledButton(onPressed: _submit, child: const Text('仮注文に追加')),
      ],
    );
  }
}

class _DartsGoodsType {
  const _DartsGoodsType({required this.label, required this.categoryKey});

  final String label;
  final String categoryKey;
}
