import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/drink_menu_family.dart';
import '../../core/food_menu.dart';
import '../../core/menu_category_catalog.dart';
import '../../data/repositories/menu_repository.dart';
import '../../models/menu_item.dart';
import '../home/home_page.dart';

enum MenuRegisterKind { food, drink }

enum _EditMode { register, list, remove }

enum _RegisterStep { kind, family, size, name, price }

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
  const MenuEditPage({super.key, this.initialRegisterKind});

  static const routeName = '/menu-edit';

  final MenuRegisterKind? initialRegisterKind;

  @override
  State<MenuEditPage> createState() => _MenuEditPageState();
}

class _MenuEditPageState extends State<MenuEditPage> {
  final _repo = MenuRepository();
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
  DrinkSize _size = DrinkSize.regular;
  _DrinkRegisterScope _drinkScope = _DrinkRegisterScope.regular;

  _RemoveStep _removeStep = _RemoveStep.kind;
  MenuRegisterKind? _removeKind;
  DrinkMenuFamily? _removeFamily;
  DrinkSize _removeSize = DrinkSize.regular;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialRegisterKind;
    if (initial != null) _selectKind(initial);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _megaPriceController.dispose();
    super.dispose();
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
    _step = kind == MenuRegisterKind.food
        ? _RegisterStep.name
        : _RegisterStep.family;
  }

  void _selectFamily(DrinkMenuFamily family) {
    setState(() {
      _family = family;
      _size = DrinkSize.regular;
      _drinkScope = _DrinkRegisterScope.regular;
      _step = family.hasMega ? _RegisterStep.size : _RegisterStep.name;
    });
  }

  void _goBack() {
    setState(() {
      switch (_step) {
        case _RegisterStep.kind:
          break;
        case _RegisterStep.family:
          _step = _RegisterStep.kind;
        case _RegisterStep.size:
          _step = _RegisterStep.family;
        case _RegisterStep.name:
          if (_kind == MenuRegisterKind.food) {
            _step = _RegisterStep.kind;
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
        await _repo.addMenu(
          name: regularName,
          category: _family!.categoryFor(DrinkSize.regular),
          priceTaxIncluded: regularPrice,
        );
        await _repo.addMenu(
          name: megaName,
          category: _family!.categoryFor(DrinkSize.mega),
          priceTaxIncluded: megaPrice,
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
          category: _family!.categoryFor(_size),
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
                  style: Theme.of(
                    ctx,
                  ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
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
    if (FirebaseAuth.instance.currentUser == null) {
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
          icon: Icon(icon, size: 28),
          label: Text(label, style: _stepTitleStyle),
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
            for (final family in drinkMenuFamilies)
              ChoiceChip(
                label: Text(
                  family.label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                selected: family == selected,
                onSelected: (_) => onSelected(family),
              ),
          ],
        ),
      ],
    );
  }

  Widget _sizeStep(void Function(_DrinkRegisterScope scope) onSelected) {
    Widget scopeButton(
      _DrinkRegisterScope scope, {
      bool fullWidth = false,
    }) {
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
      if (_kind != null) _kind == MenuRegisterKind.food ? 'フード' : 'ドリンク',
      if (_kind == MenuRegisterKind.drink &&
          family != null &&
          _step.index > _RegisterStep.family.index)
        family.label,
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
        final pairs = pairDrinkMenus(_family!, snapshot.data ?? const [])
            .where((p) => p.regular != null && p.mega == null)
            .toList();
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
          textInputAction:
              submitOnDone ? TextInputAction.done : TextInputAction.next,
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
        : _family!.quickPricesFor(_size);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('金額（税込）を入力してください', style: _stepTitleStyle),
        const SizedBox(height: 16),
        _priceFields(
          title: _kind == MenuRegisterKind.food
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

  Widget _menuAccordion({
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    if (children.isEmpty) return const SizedBox.shrink();
    return Card(
      margin: const EdgeInsets.only(top: 12),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: false,
        title: Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(subtitle),
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
        final foods = menus.where(isRegisteredFoodMenu).toList();
        final others = <String, List<MenuItem>>{};
        for (final m in menus) {
          if (isRegisteredFoodMenu(m) || familyForCategory(m.category) != null) {
            continue;
          }
          others.putIfAbsent(m.category, () => []).add(m);
        }
        return ListView(
          children: [
            Text(
              'スイッチを切ると注文画面に出なくなります（休止）。\n'
              '単価を変えるときは、削除してから同じ名前で登録し直してください。',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            for (final family in drinkMenuFamilies)
              _familyAccordion(family, menus),
            if (foods.isNotEmpty)
              _menuAccordion(
                title: MenuCategoryCatalog.labelFor(kFoodRegisteredCategory),
                subtitle: '${foods.length}件',
                children: [for (final m in foods) _menuTile(m)],
              ),
            for (final entry in others.entries)
              _menuAccordion(
                title: MenuCategoryCatalog.labelFor(entry.key),
                subtitle: '${entry.value.length}件',
                children: [for (final m in entry.value) _menuTile(m)],
              ),
          ],
        );
      },
    );
  }

  Widget _familyAccordion(DrinkMenuFamily family, List<MenuItem> menus) {
    final pairs = pairDrinkMenus(family, menus);
    if (pairs.isEmpty) return const SizedBox.shrink();
    final children = [
      for (final pair in pairs)
        if (family.hasMega) _pairCard(pair) else _menuTile(pair.regular!),
    ];
    return _menuAccordion(
      title: family.label,
      subtitle: '${pairs.length}件',
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
        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
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
          if (_removeKind == MenuRegisterKind.food) {
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
      if (_removeKind != null)
        _removeKind == MenuRegisterKind.food ? 'フード' : 'ドリンク',
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
              _removeStep = kind == MenuRegisterKind.food
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
    final category = _removeKind == MenuRegisterKind.food
        ? kFoodRegisteredCategory
        : _removeFamily!.categoryFor(_removeSize);
    return StreamBuilder<List<MenuItem>>(
      stream: _repo.streamAllMenus(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text('読み込みエラー: ${snapshot.error}');
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snapshot.data!
            .where((m) => m.category == category)
            .toList();
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
