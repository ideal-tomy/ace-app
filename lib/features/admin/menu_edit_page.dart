import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/drink_family_theme.dart';
import '../../core/drink_menu_family.dart';
import '../../core/food_menu.dart';
import '../../core/list_reorder.dart';
import '../../core/menu_admin_family_order.dart';
import '../../core/menu_category_catalog.dart';
import '../../data/repositories/menu_repository.dart';
import '../../data/repositories/store_settings_repository.dart';
import '../../models/menu_item.dart';
import '../home/home_page.dart';

enum MenuRegisterKind { food, drink, goods }

String _kindLabel(MenuRegisterKind kind) => switch (kind) {
  MenuRegisterKind.food => 'フード',
  MenuRegisterKind.drink => 'ドリンク',
  MenuRegisterKind.goods => 'グッズ',
};

enum _EditMode { register, list, remove }

enum _RegisterStep { kind, family, shotStorage, size, name, price }

enum _RemoveStep { kind, family, size, item }

enum _DrinkRegisterScope { regular, mega, both }

String _sizeLabel(DrinkSize size) => size == DrinkSize.mega ? 'メガ' : '通常';

String _registerScopeLabel(_DrinkRegisterScope scope) => switch (scope) {
  _DrinkRegisterScope.regular => '通常',
  _DrinkRegisterScope.mega => 'メガ',
  _DrinkRegisterScope.both => '通常＋メガ',
};

/// フード・ドリンクの登録／休止／削除をまとめたメニュー管理画面（ログイン済みスタッフ全員）。
class MenuEditPage extends StatefulWidget {
  const MenuEditPage({
    super.key,
    this.initialRegisterKind,
    this.menuRepository,
    this.storeSettingsRepository,
    this.auth,
  });

  static const routeName = '/menu-edit';

  final MenuRegisterKind? initialRegisterKind;
  final MenuRepository? menuRepository;
  final StoreSettingsRepository? storeSettingsRepository;
  final FirebaseAuth? auth;

  @override
  State<MenuEditPage> createState() => _MenuEditPageState();
}

class _MenuEditPageState extends State<MenuEditPage> {
  static const _accordionTitleStyle = TextStyle(
    fontSize: 19,
    fontWeight: FontWeight.w700,
    height: 1.15,
  );

  late final _repo = widget.menuRepository ?? MenuRepository();
  late final StoreSettingsRepository _settingsRepo =
      widget.storeSettingsRepository ?? StoreSettingsRepository();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _megaPriceController = TextEditingController();
  final _currency = NumberFormat.currency(
    locale: 'ja_JP',
    symbol: '¥',
    decimalDigits: 0,
  );

  _EditMode _mode = _EditMode.register;
  _RegisterStep _step = _RegisterStep.kind;
  MenuRegisterKind? _kind;
  DrinkMenuFamily? _family;
  String? _registerStorageCategory;
  DrinkSize _size = DrinkSize.regular;
  _DrinkRegisterScope _drinkScope = _DrinkRegisterScope.regular;

  _RemoveStep _removeStep = _RemoveStep.kind;
  MenuRegisterKind? _removeKind;
  DrinkMenuFamily? _removeFamily;
  DrinkSize _removeSize = DrinkSize.regular;

  bool _saving = false;
  bool _listReorderMode = false;
  bool _itemReorderMode = false;
  bool _savingFamilyOrder = false;
  bool _savingItemOrder = false;
  List<String> _familyOrderKeys = defaultDrinkFamilyOrderKeys();
  StreamSubscription<List<String>?>? _familyOrderSub;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialRegisterKind;
    if (initial != null) _selectKind(initial);
    if (Firebase.apps.isNotEmpty) {
      _familyOrderSub = _settingsRepo.streamDrinkFamilyOrderKeys().listen((keys) {
        if (mounted) {
          setState(
            () => _familyOrderKeys = keys ?? defaultDrinkFamilyOrderKeys(),
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _familyOrderSub?.cancel();
    _nameController.dispose();
    _priceController.dispose();
    _megaPriceController.dispose();
    super.dispose();
  }

  List<DrinkMenuFamily> _orderedDrinkFamilies() =>
      sortDrinkFamiliesByOrderKeys(drinkMenuFamilies, _familyOrderKeys);

  List<DrinkMenuFamily> _visibleDrinkFamilies(List<MenuItem> menus) {
    return _orderedDrinkFamilies()
        .where((f) => pairDrinkMenus(f, menus).isNotEmpty)
        .toList();
  }

  Future<void> _onVisibleFamilyReorder(
    int oldIndex,
    int newIndex,
    List<String> visibleKeys,
  ) async {
    final next = applyVisibleFamilyReorder(
      fullOrder: _familyOrderKeys,
      visibleKeys: visibleKeys,
      oldIndex: oldIndex,
      newIndex: newIndex,
    );
    setState(() => _familyOrderKeys = next);
    if (Firebase.apps.isEmpty) return;
    setState(() => _savingFamilyOrder = true);
    try {
      await _settingsRepo.saveDrinkFamilyOrderKeys(next);
    } catch (e) {
      if (mounted) _showMessage('並び順の保存に失敗しました: $e');
    } finally {
      if (mounted) setState(() => _savingFamilyOrder = false);
    }
  }

  Future<void> _persistMenuSortOrders(Map<String, int> updates) async {
    if (updates.isEmpty) return;
    if (Firebase.apps.isEmpty) return;
    setState(() => _savingItemOrder = true);
    try {
      await _repo.updateMenuSortOrders(updates);
    } catch (e) {
      if (mounted) _showMessage('メニュー順の保存に失敗しました: $e');
    } finally {
      if (mounted) setState(() => _savingItemOrder = false);
    }
  }

  Future<void> _onMenuItemsReorder(
    List<MenuItem> items,
    int oldIndex,
    int newIndex,
  ) async {
    final ordered = reorderListAt(items, oldIndex, newIndex);
    await _persistMenuSortOrders(
      sortOrdersForOrderedIds(ordered.map((m) => m.id).toList()),
    );
  }

  Future<void> _onPairItemsReorder(
    List<DrinkMenuPair> pairs,
    int oldIndex,
    int newIndex,
  ) async {
    final ordered = reorderListAt(pairs, oldIndex, newIndex);
    final updates = <String, int>{};
    for (var i = 0; i < ordered.length; i++) {
      final order = (i + 1) * 10;
      final pair = ordered[i];
      if (pair.regular != null) updates[pair.regular!.id] = order;
      if (pair.mega != null) updates[pair.mega!.id] = order;
    }
    await _persistMenuSortOrders(updates);
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  bool get _isMegaOnlyRegister =>
      _kind == MenuRegisterKind.drink &&
      _drinkScope == _DrinkRegisterScope.mega;

  bool get _registerBothSizes =>
      _kind == MenuRegisterKind.drink &&
      _drinkScope == _DrinkRegisterScope.both;

  String get _savedName => _isMegaOnlyRegister
      ? resolvedMegaName(_nameController.text)
      : _nameController.text.trim();

  void _selectKind(MenuRegisterKind kind) {
    _kind = kind;
    _step = kind != MenuRegisterKind.drink
        ? _RegisterStep.name
        : _RegisterStep.family;
  }

  void _selectFamily(DrinkMenuFamily family) {
    setState(() {
      _family = family;
      _registerStorageCategory = null;
      _size = DrinkSize.regular;
      _drinkScope = _DrinkRegisterScope.regular;
      if (family.isTequilaOthersGroup) {
        _step = _RegisterStep.shotStorage;
      } else {
        _step = family.hasMega ? _RegisterStep.size : _RegisterStep.name;
      }
    });
  }

  void _selectShotStorage(String category) {
    setState(() {
      _registerStorageCategory = category;
      _step = _RegisterStep.name;
    });
  }

  String _drinkRegisterCategory() {
    if (_registerStorageCategory != null) return _registerStorageCategory!;
    return _family!.categoryFor(_size);
  }

  void _goBack() {
    setState(() {
      switch (_step) {
        case _RegisterStep.kind:
          break;
        case _RegisterStep.family:
          _step = _RegisterStep.kind;
        case _RegisterStep.shotStorage:
          _step = _RegisterStep.family;
        case _RegisterStep.size:
          _step = _family!.isTequilaOthersGroup
              ? _RegisterStep.shotStorage
              : _RegisterStep.family;
        case _RegisterStep.name:
          if (_kind != MenuRegisterKind.drink) {
            _step = _RegisterStep.kind;
          } else if (_family!.isTequilaOthersGroup) {
            _step = _RegisterStep.shotStorage;
          } else {
            _step = _family!.hasMega
                ? _RegisterStep.size
                : _RegisterStep.family;
          }
        case _RegisterStep.price:
          _step = _RegisterStep.name;
      }
    });
  }

  void _submitName() {
    if (_nameController.text.trim().isEmpty) {
      _showMessage('メニュー名を入力してください');
      return;
    }
    setState(() => _step = _RegisterStep.price);
  }

  Future<void> _register() async {
    final regularPrice = int.tryParse(_priceController.text.trim());
    if (regularPrice == null || regularPrice < 0) {
      _showMessage('金額を正しく入力してください');
      return;
    }
    if (_registerBothSizes) {
      final megaPrice = int.tryParse(_megaPriceController.text.trim());
      if (megaPrice == null || megaPrice < 0) {
        _showMessage('メガの金額を正しく入力してください');
        return;
      }
      final baseName = _nameController.text.trim();
      final regularName = baseName;
      final megaName = resolvedMegaName(baseName);
      setState(() => _saving = true);
      try {
        await _repo.addMenuPair(
          regularName: regularName,
          megaName: megaName,
          regularCategory: _family!.categoryFor(DrinkSize.regular),
          megaCategory: _family!.categoryFor(DrinkSize.mega),
          regularPrice: regularPrice,
          megaPrice: megaPrice,
        );
      } on StateError catch (e) {
        if (mounted) _showMessage(e.message);
        return;
      } catch (e) {
        if (mounted) _showMessage('登録に失敗しました: $e');
        return;
      } finally {
        if (mounted) setState(() => _saving = false);
      }
      if (!mounted) return;
      await _showRegisteredDialog(
        lines: [
          '$regularName（${_currency.format(regularPrice)}）',
          '$megaName（${_currency.format(megaPrice)}）',
        ],
      );
      return;
    }

    final name = _savedName;
    setState(() => _saving = true);
    try {
      if (_kind == MenuRegisterKind.food) {
        await _repo.addFoodMenu(name: name, priceTaxIncluded: regularPrice);
      } else {
        await _repo.addMenu(
          name: name,
          category: _kind == MenuRegisterKind.goods
              ? 'DARTS_GOODS'
              : _drinkRegisterCategory(),
          priceTaxIncluded: regularPrice,
        );
      }
    } on StateError catch (e) {
      if (mounted) _showMessage(e.message);
      return;
    } catch (e) {
      if (mounted) _showMessage('登録に失敗しました: $e');
      return;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    if (!mounted) return;
    await _showRegisteredDialog(
      lines: ['$name（${_currency.format(regularPrice)}）'],
    );
  }

  Future<void> _showRegisteredDialog({required List<String> lines}) async {
    final continueRegister = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('登録しました'),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final line in lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  line,
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('終了'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('続けて登録'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (continueRegister == true) {
      setState(() {
        _nameController.clear();
        _priceController.clear();
        _megaPriceController.clear();
        _step = _RegisterStep.name;
      });
    } else {
      Navigator.pushNamedAndRemoveUntil(
        context,
        HomePage.routeName,
        (_) => false,
      );
    }
  }

  Future<void> _confirmAndDelete(MenuItem menu) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('メニューの削除'),
        content: Text(
          '「${menu.name}」を削除しますか？\n'
          '注文済みの伝票の明細は変わりません。',
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
    setState(() => _saving = true);
    try {
      await _repo.deleteMenu(menu.id);
      if (!mounted) return;
      _showMessage('「${menu.name}」を削除しました');
    } catch (e) {
      if (mounted) _showMessage('削除に失敗しました: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _setActive(MenuItem menu, bool isActive) async {
    try {
      await _repo.setMenuActive(menu.id, isActive);
    } catch (e) {
      if (mounted) _showMessage('更新に失敗しました: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if ((widget.auth ?? FirebaseAuth.instance).currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('メニュー管理')),
        body: const Center(child: Text('ログイン後に利用できます')),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('メニュー管理')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<_EditMode>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: _EditMode.register,
                    label: Text('登録'),
                    icon: Icon(Icons.add),
                  ),
                  ButtonSegment(
                    value: _EditMode.list,
                    label: Text('一覧'),
                    icon: Icon(Icons.list),
                  ),
                  ButtonSegment(
                    value: _EditMode.remove,
                    label: Text('削除'),
                    icon: Icon(Icons.delete_outline),
                  ),
                ],
                selected: {_mode},
                onSelectionChanged: (s) => setState(() => _mode = s.first),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: switch (_mode) {
                  _EditMode.register => _buildRegister(),
                  _EditMode.list => _buildList(),
                  _EditMode.remove => _buildRemove(),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  TextStyle? get _stepTitleStyle => Theme.of(
    context,
  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700);

  Widget _stepHeader(List<String> selections, VoidCallback onBack) {
    return Row(
      children: [
        IconButton(
          tooltip: '戻る',
          onPressed: _saving ? null : onBack,
          icon: const Icon(Icons.arrow_back),
        ),
        Expanded(
          child: Text(
            selections.join(' ・ '),
            style: Theme.of(context).textTheme.titleSmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _kindStep(String title, ValueChanged<MenuRegisterKind> onSelected) {
    Widget kindButton(MenuRegisterKind kind, IconData icon, String label) {
      return Expanded(
        child: FilledButton.tonalIcon(
          onPressed: () => onSelected(kind),
          style: FilledButton.styleFrom(minimumSize: const Size(0, 88)),
          icon: Icon(icon, size: 22),
          label: Text(
            label,
            maxLines: 1,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: _stepTitleStyle),
        const SizedBox(height: 16),
        Row(
          children: [
            kindButton(MenuRegisterKind.food, Icons.restaurant_menu, 'フード'),
            const SizedBox(width: 12),
            kindButton(MenuRegisterKind.drink, Icons.local_bar, 'ドリンク'),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            kindButton(
              MenuRegisterKind.goods,
              Icons.shopping_bag_outlined,
              'グッズ',
            ),
          ],
        ),
      ],
    );
  }

  Widget _familyStep(
    DrinkMenuFamily? selected,
    ValueChanged<DrinkMenuFamily> onSelected,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('ドリンクの種類を選んでください', style: _stepTitleStyle),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final family in _orderedDrinkFamilies())
              _familyChoiceChip(
                family: family,
                selected: selected?.key == family.key,
                onSelected: () => onSelected(family),
              ),
          ],
        ),
      ],
    );
  }

  Widget _familyChoiceChip({
    required DrinkMenuFamily family,
    required bool selected,
    required VoidCallback onSelected,
  }) {
    final color = DrinkFamilyTheme.colorForFamilyKey(family.key);
    final fill = selected ? color.withValues(alpha: 0.95) : color;
    return ChoiceChip(
      label: DrinkFamilyStrokeLabel(
        text: family.label,
        fillColor: fill,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
      selected: selected,
      selectedColor: color.withValues(alpha: 0.22),
      backgroundColor: color.withValues(alpha: 0.08),
      side: BorderSide(
        color: selected
            ? color.withValues(alpha: 0.85)
            : color.withValues(alpha: 0.35),
        width: selected ? 2 : 1,
      ),
      onSelected: (_) => onSelected(),
    );
  }

  Widget _shotStorageStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('テキーラ他の登録先を選んでください', style: _stepTitleStyle),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: FilledButton.tonal(
                onPressed: () =>
                    _selectShotStorage(kTequilaShotStorageCategory),
                style: FilledButton.styleFrom(minimumSize: const Size(0, 88)),
                child: Text('テキーラ', style: _stepTitleStyle),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.tonal(
                onPressed: () =>
                    _selectShotStorage(kOthersShotStorageCategory),
                style: FilledButton.styleFrom(minimumSize: const Size(0, 88)),
                child: Text('アザー', style: _stepTitleStyle),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _sizeStep(void Function(_DrinkRegisterScope scope) onSelected) {
    Widget scopeButton(_DrinkRegisterScope scope, {bool fullWidth = false}) {
      final child = FilledButton.tonal(
        onPressed: () => onSelected(scope),
        style: FilledButton.styleFrom(
          minimumSize: Size(fullWidth ? double.infinity : 0, 88),
        ),
        child: Text(_registerScopeLabel(scope), style: _stepTitleStyle),
      );
      return fullWidth ? child : Expanded(child: child);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('サイズを選んでください', style: _stepTitleStyle),
        const SizedBox(height: 16),
        Row(
          children: [
            scopeButton(_DrinkRegisterScope.regular),
            const SizedBox(width: 12),
            scopeButton(_DrinkRegisterScope.mega),
          ],
        ),
        const SizedBox(height: 12),
        scopeButton(_DrinkRegisterScope.both, fullWidth: true),
      ],
    );
  }

  Widget _removeSizeStep(ValueChanged<DrinkSize> onSelected) {
    Widget sizeButton(DrinkSize size) {
      return Expanded(
        child: FilledButton.tonal(
          onPressed: () => onSelected(size),
          style: FilledButton.styleFrom(minimumSize: const Size(0, 88)),
          child: Text(_sizeLabel(size), style: _stepTitleStyle),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('サイズを選んでください', style: _stepTitleStyle),
        const SizedBox(height: 16),
        Row(
          children: [
            sizeButton(DrinkSize.regular),
            const SizedBox(width: 12),
            sizeButton(DrinkSize.mega),
          ],
        ),
      ],
    );
  }

  Widget _buildRegister() {
    final family = _family;
    final selections = [
      if (_kind != null) _kindLabel(_kind!),
      if (_kind == MenuRegisterKind.drink &&
          family != null &&
          _step.index > _RegisterStep.family.index)
        family.label,
      if (_kind == MenuRegisterKind.drink &&
          _registerStorageCategory != null &&
          _step.index > _RegisterStep.shotStorage.index)
        _registerStorageCategory == kTequilaShotStorageCategory
            ? 'テキーラ'
            : 'アザー',
      if (_kind == MenuRegisterKind.drink &&
          family != null &&
          family.hasMega &&
          _step.index > _RegisterStep.size.index)
        _registerScopeLabel(_drinkScope),
      if (_step == _RegisterStep.price) _savedName,
    ];
    return ListView(
      children: [
        if (_step != _RegisterStep.kind) _stepHeader(selections, _goBack),
        const SizedBox(height: 8),
        switch (_step) {
          _RegisterStep.kind => _kindStep(
            '登録するメニューを選択',
            (kind) => setState(() => _selectKind(kind)),
          ),
          _RegisterStep.family => _familyStep(_family, _selectFamily),
          _RegisterStep.shotStorage => _shotStorageStep(),
          _RegisterStep.size => _sizeStep(
            (scope) => setState(() {
              _drinkScope = scope;
              _size = scope == _DrinkRegisterScope.mega
                  ? DrinkSize.mega
                  : DrinkSize.regular;
              _step = _RegisterStep.name;
            }),
          ),
          _RegisterStep.name => _buildNameStep(),
          _RegisterStep.price => _buildPriceStep(),
        },
      ],
    );
  }

  Widget _buildNameStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('メニュー名を入力してください', style: _stepTitleStyle),
        const SizedBox(height: 16),
        TextField(
          controller: _nameController,
          autofocus: true,
          maxLength: 50,
          style: const TextStyle(fontSize: 18),
          decoration: InputDecoration(
            labelText: 'メニュー名',
            hintText: _kind == MenuRegisterKind.food
                ? '例）唐揚げ'
                : _kind == MenuRegisterKind.goods
                ? '例）Tシャツ'
                : _isMegaOnlyRegister
                ? '例）緑茶ハイ'
                : '例）生レモンサワー',
            helperText: _isMegaOnlyRegister
                ? '先頭に「メガ」が自動で付きます'
                : _registerBothSizes
                ? '通常とメガをまとめて登録します'
                : null,
            border: const OutlineInputBorder(),
            counterText: '',
          ),
          textInputAction: TextInputAction.next,
          onSubmitted: (_) => _submitName(),
        ),
        if (_isMegaOnlyRegister || _registerBothSizes) _megaSuggestions(),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _submitName,
          style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
          child: const Text('次へ'),
        ),
      ],
    );
  }

  /// 通常サイズだけ登録済みのメニュー名を候補に出し、メガの表記ゆれを防ぐ。
  Widget _megaSuggestions() {
    return StreamBuilder<List<MenuItem>>(
      stream: _repo.streamAllMenus(),
      builder: (context, snapshot) {
        final pairs = pairDrinkMenus(
          _family!,
          snapshot.data ?? const [],
        ).where((p) => p.regular != null && p.mega == null).toList();
        if (pairs.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '通常サイズだけ登録済み（タップで入力）',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final p in pairs)
                    ActionChip(
                      label: Text(
                        p.displayName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onPressed: () => setState(() {
                        _nameController.text = p.displayName;
                      }),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _priceFields({
    required String title,
    required List<int> quickPrices,
    required TextEditingController controller,
    bool submitOnDone = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final price in quickPrices)
              ChoiceChip(
                label: Text(
                  _currency.format(price),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                selected: controller.text == '$price',
                onSelected: _saving
                    ? null
                    : (_) => setState(() => controller.text = '$price'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          enabled: !_saving,
          style: const TextStyle(fontSize: 18),
          decoration: const InputDecoration(
            labelText: 'その他の金額',
            prefixText: '¥',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          textInputAction: submitOnDone
              ? TextInputAction.done
              : TextInputAction.next,
          onChanged: (_) => setState(() {}),
          onSubmitted: submitOnDone
              ? (_) => _saving ? null : _register()
              : null,
        ),
      ],
    );
  }

  Widget _buildPriceStep() {
    if (_registerBothSizes) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('金額（税込）を入力してください', style: _stepTitleStyle),
          const SizedBox(height: 16),
          _priceFields(
            title: '通常サイズ',
            quickPrices: _family!.quickPricesFor(DrinkSize.regular),
            controller: _priceController,
          ),
          const SizedBox(height: 20),
          _priceFields(
            title: 'メガサイズ',
            quickPrices: _family!.quickPricesFor(DrinkSize.mega),
            controller: _megaPriceController,
            submitOnDone: true,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _saving ? null : _register,
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 52),
              backgroundColor: const Color(0xFF0F766E),
              foregroundColor: Colors.white,
            ),
            icon: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.save),
            label: Text(_saving ? '登録中…' : '2件まとめて登録する'),
          ),
        ],
      );
    }

    final quickPrices = _kind == MenuRegisterKind.food
        ? kFoodQuickPrices
        : _kind == MenuRegisterKind.goods
        ? <int>[]
        : _family!.quickPricesFor(_size);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('金額（税込）を入力してください', style: _stepTitleStyle),
        const SizedBox(height: 16),
        _priceFields(
          title: _kind != MenuRegisterKind.drink
              ? '金額'
              : '${_sizeLabel(_size)}サイズ',
          quickPrices: quickPrices,
          controller: _priceController,
          submitOnDone: true,
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _saving ? null : _register,
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 52),
            backgroundColor: const Color(0xFF0F766E),
            foregroundColor: Colors.white,
          ),
          icon: _saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.save),
          label: Text(_saving ? '登録中…' : '登録する'),
        ),
      ],
    );
  }

  Widget _accordionTitleText(
    String title, {
    Color? accent,
  }) {
    final color = accent ?? Theme.of(context).colorScheme.primary;
    if (accent != null) {
      return DrinkFamilyStrokeLabel(
        text: title,
        fillColor: color,
        style: _accordionTitleStyle,
      );
    }
    return Text(title, style: _accordionTitleStyle, textAlign: TextAlign.center);
  }

  Widget _menuAccordion({
    required String title,
    required String subtitle,
    required List<Widget> children,
    Color? accent,
    Key? key,
  }) {
    if (children.isEmpty) return const SizedBox.shrink();
    final color = accent ?? Theme.of(context).colorScheme.primary;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(top: 12),
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withValues(alpha: 0.5), width: 1.5),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: key,
          initiallyExpanded: false,
          minTileHeight: 72,
          iconColor: color,
          collapsedIconColor: color,
          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          visualDensity: VisualDensity.standard,
          title: SizedBox(
            height: 64,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _accordionTitleText(title, accent: accent),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _listReorderSwitch({
    required String firstLine,
    required String secondLine,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    final style = Theme.of(context).textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w600,
      height: 1.25,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text.rich(
              TextSpan(
                style: style,
                children: [
                  TextSpan(text: '$firstLine\n'),
                  TextSpan(text: secondLine),
                ],
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  Widget _familyReorderTile({
    required Key key,
    required int index,
    required DrinkMenuFamily family,
    required int itemCount,
  }) {
    final color = DrinkFamilyTheme.colorForFamilyKey(family.key);
    final scheme = Theme.of(context).colorScheme;
    return Card(
      key: key,
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withValues(alpha: 0.5), width: 1.5),
      ),
      child: SizedBox(
        height: 72,
        child: Row(
          children: [
            ReorderableDragStartListener(
              index: index,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.drag_handle, color: color),
              ),
            ),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _accordionTitleText(family.label, accent: color),
                  const SizedBox(height: 4),
                  Text(
                    '$itemCount件',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    return StreamBuilder<List<MenuItem>>(
      stream: _repo.streamAllMenus(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('読み込みエラー: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final menus = snapshot.data!;
        if (menus.isEmpty) {
          return const Center(child: Text('登録されたメニューがありません'));
        }
        final foods = menus.where(isRegisteredFoodMenu).toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
        final others = <String, List<MenuItem>>{};
        for (final m in menus) {
          if (isRegisteredFoodMenu(m) ||
              familyForCategory(m.category) != null) {
            continue;
          }
          others.putIfAbsent(m.category, () => []).add(m);
        }
        for (final list in others.values) {
          list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
        }
        final visibleFamilies = _visibleDrinkFamilies(menus);
        final visibleKeys = visibleFamilies.map((f) => f.key).toList();
        final trailingSections = <Widget>[
          if (foods.isNotEmpty)
            _menuAccordion(
              key: const ValueKey('accordion-food'),
              title: MenuCategoryCatalog.labelFor(kFoodRegisteredCategory),
              subtitle: '${foods.length}件',
              children: _menuSectionChildren(foods),
            ),
          for (final entry in others.entries)
            _menuAccordion(
              title: MenuCategoryCatalog.labelFor(entry.key),
              subtitle: '${entry.value.length}件',
              children: _menuSectionChildren(entry.value),
            ),
        ];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _listReorderSwitch(
              firstLine: 'ドリンクカテゴリの',
              secondLine: '並べ替え',
              value: _listReorderMode,
              onChanged: _savingFamilyOrder || _savingItemOrder
                  ? null
                  : (value) => setState(() {
                      _listReorderMode = value;
                      if (value) _itemReorderMode = false;
                    }),
            ),
            _listReorderSwitch(
              firstLine: 'ドリンクメニューの',
              secondLine: '並べ替え',
              value: _itemReorderMode,
              onChanged: _savingItemOrder ||
                      _savingFamilyOrder ||
                      _listReorderMode
                  ? null
                  : (value) => setState(() => _itemReorderMode = value),
            ),
            if (_savingFamilyOrder || _savingItemOrder)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: LinearProgressIndicator(),
              ),
            Expanded(
              child: _listReorderMode
                  ? ReorderableListView(
                      padding: EdgeInsets.zero,
                      onReorder: (oldIndex, newIndex) => _onVisibleFamilyReorder(
                        oldIndex,
                        newIndex,
                        visibleKeys,
                      ),
                      children: [
                        for (var i = 0; i < visibleFamilies.length; i++)
                          _familyReorderTile(
                            key: ValueKey(visibleFamilies[i].key),
                            index: i,
                            family: visibleFamilies[i],
                            itemCount:
                                pairDrinkMenus(visibleFamilies[i], menus).length,
                          ),
                      ],
                    )
                  : ListView(
                      children: [
                        for (final family in visibleFamilies)
                          _familyAccordion(family, menus),
                        ...trailingSections,
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }

  List<Widget> _menuSectionChildren(List<MenuItem> items) {
    if (items.isEmpty) return const [];
    if (!_itemReorderMode || _listReorderMode) {
      return [for (final m in items) _menuTile(m)];
    }
    return [_reorderableMenuList(items)];
  }

  Widget _reorderableMenuList(List<MenuItem> items) {
    return ReorderableListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      onReorder: (oldIndex, newIndex) =>
          _onMenuItemsReorder(items, oldIndex, newIndex),
      children: [
        for (var i = 0; i < items.length; i++)
          _menuReorderTile(menu: items[i], index: i),
      ],
    );
  }

  Widget _reorderablePairList(List<DrinkMenuPair> pairs) {
    return ReorderableListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      onReorder: (oldIndex, newIndex) =>
          _onPairItemsReorder(pairs, oldIndex, newIndex),
      children: [
        for (var i = 0; i < pairs.length; i++)
          _pairReorderTile(pair: pairs[i], index: i),
      ],
    );
  }

  Widget _menuReorderTile({required MenuItem menu, required int index}) {
    return Card(
      key: ValueKey('menu-order-${menu.id}'),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: ReorderableDragStartListener(
          index: index,
          child: const Icon(Icons.drag_handle),
        ),
        title: Text(
          menu.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(_currency.format(menu.priceTaxIncluded)),
      ),
    );
  }

  Widget _pairReorderTile({required DrinkMenuPair pair, required int index}) {
    final id = pair.regular?.id ?? pair.mega?.id ?? pair.displayName;
    return Card(
      key: ValueKey('pair-order-$id'),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: ReorderableDragStartListener(
          index: index,
          child: const Icon(Icons.drag_handle),
        ),
        title: Text(
          pair.displayName,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          [
            if (pair.regular != null)
              '通常 ${_currency.format(pair.regular!.priceTaxIncluded)}',
            if (pair.mega != null)
              'メガ ${_currency.format(pair.mega!.priceTaxIncluded)}',
          ].join(' / '),
        ),
      ),
    );
  }

  Widget _familyAccordion(DrinkMenuFamily family, List<MenuItem> menus) {
    final pairs = pairDrinkMenus(family, menus);
    if (pairs.isEmpty) return const SizedBox.shrink();
    final List<Widget> children;
    if (_itemReorderMode && !_listReorderMode) {
      children = family.hasMega
          ? [_reorderablePairList(pairs)]
          : _menuSectionChildren(
              pairs.map((p) => p.regular!).toList(),
            );
    } else {
      children = [
        for (final pair in pairs)
          if (family.hasMega) _pairCard(pair) else _menuTile(pair.regular!),
      ];
    }
    return _menuAccordion(
      key: ValueKey('accordion-${family.key}'),
      title: family.label,
      subtitle: '${pairs.length}件',
      accent: DrinkFamilyTheme.colorForFamilyKey(family.key),
      children: children,
    );
  }

  Widget _pairCard(DrinkMenuPair pair) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 4, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              pair.displayName,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            _sizeRow(DrinkSize.regular, pair.regular),
            _sizeRow(DrinkSize.mega, pair.mega),
          ],
        ),
      ),
    );
  }

  Widget _sizeRow(DrinkSize size, MenuItem? menu) {
    final theme = Theme.of(context);
    final label = SizedBox(
      width: 56,
      child: Text(
        _sizeLabel(size),
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
    );
    if (menu == null) {
      return SizedBox(
        height: 48,
        child: Row(
          children: [
            label,
            Text(
              '未登録',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }
    return Row(
      children: [
        label,
        Expanded(
          child: Text(
            menu.isActive
                ? _currency.format(menu.priceTaxIncluded)
                : '${_currency.format(menu.priceTaxIncluded)}（休止中）',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: menu.isActive ? null : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Switch(
          value: menu.isActive,
          onChanged: _saving ? null : (v) => _setActive(menu, v),
        ),
        IconButton(
          tooltip: '削除',
          icon: const Icon(Icons.delete_outline),
          onPressed: _saving ? null : () => _confirmAndDelete(menu),
        ),
      ],
    );
  }

  Widget _menuTile(MenuItem menu) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(
          menu.name,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: menu.isActive
                ? null
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        subtitle: Text(
          menu.isActive
              ? _currency.format(menu.priceTaxIncluded)
              : '${_currency.format(menu.priceTaxIncluded)}（休止中）',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: menu.isActive,
              onChanged: _saving ? null : (v) => _setActive(menu, v),
            ),
            IconButton(
              tooltip: '削除',
              icon: const Icon(Icons.delete_outline),
              onPressed: _saving ? null : () => _confirmAndDelete(menu),
            ),
          ],
        ),
      ),
    );
  }

  void _goBackRemove() {
    setState(() {
      switch (_removeStep) {
        case _RemoveStep.kind:
          break;
        case _RemoveStep.family:
          _removeStep = _RemoveStep.kind;
        case _RemoveStep.size:
          _removeStep = _RemoveStep.family;
        case _RemoveStep.item:
          if (_removeKind != MenuRegisterKind.drink) {
            _removeStep = _RemoveStep.kind;
          } else {
            _removeStep = _removeFamily!.hasMega
                ? _RemoveStep.size
                : _RemoveStep.family;
          }
      }
    });
  }

  Widget _buildRemove() {
    final family = _removeFamily;
    final selections = [
      if (_removeKind != null) _kindLabel(_removeKind!),
      if (_removeKind == MenuRegisterKind.drink &&
          family != null &&
          _removeStep.index > _RemoveStep.family.index)
        family.label,
      if (_removeKind == MenuRegisterKind.drink &&
          family != null &&
          family.hasMega &&
          _removeStep == _RemoveStep.item)
        _sizeLabel(_removeSize),
    ];
    return ListView(
      children: [
        if (_removeStep != _RemoveStep.kind)
          _stepHeader(selections, _goBackRemove),
        const SizedBox(height: 8),
        switch (_removeStep) {
          _RemoveStep.kind => _kindStep(
            '削除するメニューを選択',
            (kind) => setState(() {
              _removeKind = kind;
              _removeStep = kind != MenuRegisterKind.drink
                  ? _RemoveStep.item
                  : _RemoveStep.family;
            }),
          ),
          _RemoveStep.family => _familyStep(
            _removeFamily,
            (f) => setState(() {
              _removeFamily = f;
              _removeSize = DrinkSize.regular;
              _removeStep = f.hasMega ? _RemoveStep.size : _RemoveStep.item;
            }),
          ),
          _RemoveStep.size => _removeSizeStep(
            (size) => setState(() {
              _removeSize = size;
              _removeStep = _RemoveStep.item;
            }),
          ),
          _RemoveStep.item => _buildRemoveItems(),
        },
      ],
    );
  }

  Widget _buildRemoveItems() {
    final family = _removeFamily;
    return StreamBuilder<List<MenuItem>>(
      stream: _repo.streamAllMenus(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text('読み込みエラー: ${snapshot.error}');
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snapshot.data!.where((m) {
          if (_removeKind == MenuRegisterKind.food) {
            return m.category == kFoodRegisteredCategory;
          }
          if (_removeKind == MenuRegisterKind.goods) {
            return m.category == 'DARTS_GOODS';
          }
          return family!.contains(m.category);
        }).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('削除するメニューを選んでください', style: _stepTitleStyle),
            const SizedBox(height: 16),
            if (items.isEmpty) const Text('登録されたメニューがありません'),
            for (final m in items)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(
                    m.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(_currency.format(m.priceTaxIncluded)),
                  trailing: FilledButton.icon(
                    onPressed: _saving ? null : () => _confirmAndDelete(m),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF991B1B),
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.delete_forever),
                    label: const Text('削除'),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
