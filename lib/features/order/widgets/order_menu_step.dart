import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/admin_auth_service.dart';
import '../../../core/billing_rules.dart';
import '../../../core/business_mode.dart';
import '../../../core/menu_category_catalog.dart';
import '../../../data/repositories/check_repository.dart';
import '../../../data/repositories/menu_repository.dart';
import '../../../models/menu_item.dart';
import '../../../models/person_option.dart';
import '../../admin/menu_edit_page.dart';
import '../event_menu_tier_catalog.dart';
import '../order_custom_item_dialogs.dart';
import '../order_flow_state.dart';
import 'order_event_tier_section.dart';

enum _MenuTab { drink, food }

class OrderMenuStep extends StatefulWidget {
  const OrderMenuStep({
    super.key,
    required this.person,
    required this.checkRepository,
    required this.menuRepository,
    required this.adminAuthService,
    required this.onMenuSelected,
    required this.onCustomMenuSelected,
  });

  final PersonOption person;
  final CheckRepository checkRepository;
  final MenuRepository menuRepository;
  final AdminAuthService adminAuthService;
  final ValueChanged<MenuItem> onMenuSelected;
  final ValueChanged<MenuItem> onCustomMenuSelected;

  @override
  State<OrderMenuStep> createState() => _OrderMenuStepState();
}

class _OrderMenuStepState extends State<OrderMenuStep> {
  final _currency = NumberFormat.currency(
    locale: 'ja_JP',
    symbol: '¥',
    decimalDigits: 0,
  );
  String? _activeCategory;
  bool _seeding = false;
  _MenuTab _tab = _MenuTab.drink;

  Future<void> _openFoodOrderDialog() async {
    final form = await showDialog<CustomFoodOrderForm>(
      context: context,
      builder: (_) => const CustomFoodOrderDialog(),
    );
    if (form == null || !mounted) return;
    final menu = MenuItem(
      id: 'food-${DateTime.now().microsecondsSinceEpoch}',
      name: form.name,
      category: kFoodDailyCategory,
      priceTaxIncluded: form.priceTaxIncluded,
      isActive: true,
      sortOrder: 9999,
    );
    widget.onCustomMenuSelected(menu);
  }

  Future<void> _openDartsGoodsDialog() async {
    final form = await showDialog<CustomGoodsOrderForm>(
      context: context,
      builder: (_) => const CustomGoodsOrderDialog(),
    );
    if (form == null || !mounted) return;
    final menu = MenuItem(
      id: 'goods-${DateTime.now().microsecondsSinceEpoch}',
      name: form.name,
      category: kGoodsCategory,
      priceTaxIncluded: form.priceTaxIncluded,
      isActive: true,
      sortOrder: 9999,
    );
    widget.onCustomMenuSelected(menu);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: SegmentedButton<_MenuTab>(
            segments: const [
              ButtonSegment(
                value: _MenuTab.drink,
                label: Text('ドリンク'),
                icon: Icon(Icons.local_bar),
              ),
              ButtonSegment(
                value: _MenuTab.food,
                label: Text('フード'),
                icon: Icon(Icons.restaurant_menu),
              ),
            ],
            selected: {_tab},
            onSelectionChanged: (s) => setState(() => _tab = s.first),
          ),
        ),
        Expanded(
          child: _tab == _MenuTab.drink ? _buildDrinkTab() : _buildFoodTab(),
        ),
      ],
    );
  }

  Widget _buildFoodTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FoodGoodsActionSection(
          onOpenFood: _openFoodOrderDialog,
          onOpenGoods: _openDartsGoodsDialog,
        ),
        Expanded(
          child: StreamBuilder<List<MenuItem>>(
            stream: widget.menuRepository.streamActiveFoodMenus(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('メニュー取得エラー: ${snapshot.error}'));
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final foods = snapshot.data!;
              if (foods.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      '表示中のフードがありません。\n'
                      '下の「フードメニューを管理」から登録するか、\n'
                      '「その他フード」で手入力してください。',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                );
              }
              return GridView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: foods.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: _menuGridAspectRatio,
                ),
                itemBuilder: (context, index) => _MenuGridButton(
                  item: foods[index],
                  currency: _currency,
                  onPressed: widget.onMenuSelected,
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: TextButton.icon(
            onPressed: () => Navigator.pushNamed(
              context,
              MenuEditPage.routeName,
              arguments: MenuRegisterKind.food,
            ),
            icon: const Icon(Icons.edit_note),
            label: const Text('フードメニューを管理'),
          ),
        ),
      ],
    );
  }

  Widget _buildDrinkTab() {
    return StreamBuilder<List<MenuItem>>(
      stream: widget.menuRepository.streamActiveMenus(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('メニュー取得エラー: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final menus = snapshot.data!;
        if (menus.isEmpty) {
          return _EmptyMenuState(
            menuRepository: widget.menuRepository,
            seeding: _seeding,
            onSeedingChanged: (v) => setState(() => _seeding = v),
          );
        }

        return StreamBuilder(
          stream: widget.checkRepository.streamCheckSummary(
            widget.person.openCheckId,
          ),
          builder: (context, checkSummarySnapshot) {
            final checkMode = checkSummarySnapshot.data?.billingMode;
            final isNormalCheck = checkMode == BusinessMode.normal;
            final sourceMenus = isNormalCheck
                ? menus.where(isSeparateAccountingMenu).toList()
                : menus;

            if (sourceMenus.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    isNormalCheck
                        ? '通常営業では例外ドリンクのみ注文可能です（対象メニューが未登録です）'
                        : '表示可能なメニューがありません',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            final isEventCheck = !isNormalCheck;
            final gridSourceMenus = isEventCheck
                ? sourceMenus
                    .where((m) => isEventIndividualCategory(m.category))
                    .toList()
                : sourceMenus;

            if (isEventCheck) {
              return _EventMenuLayout(
                currency: _currency,
                individualMenus: gridSourceMenus,
                activeCategory: _activeCategory,
                onCategoryChanged: (cat) =>
                    setState(() => _activeCategory = cat),
                onMenuSelected: widget.onMenuSelected,
              );
            }

            if (gridSourceMenus.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    '通常営業では例外ドリンクのみ注文可能です（対象メニューが未登録です）',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            final categories =
                gridSourceMenus
                    .map((m) => normalModeCategoryKey(m))
                    .toSet()
                    .toList()
                  ..sort((a, b) {
                    if (a == kTequilaOthersCategory) {
                      return b == kTequilaOthersCategory ? 0 : 1;
                    }
                    if (b == kTequilaOthersCategory) return -1;
                    return MenuCategoryCatalog.compareKeys(a, b);
                  });
            if (!categories.contains(_activeCategory)) {
              _activeCategory = categories.first;
            }
            final shown = gridSourceMenus
                .where(
                  (m) => normalModeCategoryKey(m) == _activeCategory,
                )
                .toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                  child: Text(
                    '通常営業中: 例外ドリンクのみ注文できます',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  height: 44,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    itemCount: categories.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final cat = categories[index];
                      final selected = cat == _activeCategory;
                      return ChoiceChip(
                        label: Text(
                          normalModeCategoryLabel(cat),
                          style: _chipLabelStyle,
                        ),
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
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: shown.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          childAspectRatio: _menuGridAspectRatio,
                        ),
                    itemBuilder: (context, index) => _MenuGridButton(
                      item: shown[index],
                      currency: _currency,
                      onPressed: widget.onMenuSelected,
                    ),
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

class _EventMenuLayout extends StatefulWidget {
  const _EventMenuLayout({
    required this.currency,
    required this.individualMenus,
    required this.activeCategory,
    required this.onCategoryChanged,
    required this.onMenuSelected,
  });

  final NumberFormat currency;
  final List<MenuItem> individualMenus;
  final String? activeCategory;
  final ValueChanged<String> onCategoryChanged;
  final ValueChanged<MenuItem> onMenuSelected;

  @override
  State<_EventMenuLayout> createState() => _EventMenuLayoutState();
}

class _EventMenuLayoutState extends State<_EventMenuLayout> {
  String? _activeCategory;

  @override
  void initState() {
    super.initState();
    _activeCategory = widget.activeCategory;
  }

  @override
  void didUpdateWidget(covariant _EventMenuLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    final categories = _individualCategories;
    if (categories.isNotEmpty && !categories.contains(_activeCategory)) {
      _activeCategory = categories.first;
      widget.onCategoryChanged(_activeCategory!);
    }
  }

  List<String> get _individualCategories {
    return widget.individualMenus
        .map(eventIndividualDisplayCategoryKey)
        .toSet()
        .toList()
      ..sort((a, b) {
        if (a == 'CHAMPAGNE') return b == 'CHAMPAGNE' ? 0 : -1;
        if (b == 'CHAMPAGNE') return 1;
        return a.compareTo(b);
      });
  }

  List<MenuItem> get _shownIndividualMenus {
    final cat = _activeCategory;
    if (cat == null) return const [];
    return widget.individualMenus
        .where((m) => eventIndividualDisplayCategoryKey(m) == cat)
        .toList()
      ..sort((a, b) {
        final catCompare = MenuCategoryCatalog.compareKeys(
          a.category,
          b.category,
        );
        if (catCompare != 0) return catCompare;
        return a.sortOrder.compareTo(b.sortOrder);
      });
  }

  @override
  Widget build(BuildContext context) {
    final categories = _individualCategories;
    if (categories.isNotEmpty &&
        (_activeCategory == null || !categories.contains(_activeCategory))) {
      _activeCategory = categories.first;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              OrderEventTierSection(onTierSelected: widget.onMenuSelected),
              if (categories.isNotEmpty) ...[
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    '個別メニュー',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 44,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    itemCount: categories.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final cat = categories[index];
                      final selected = cat == _activeCategory;
                      return ChoiceChip(
                        label: Text(
                          eventIndividualDisplayCategoryLabel(cat),
                          style: _chipLabelStyle,
                        ),
                        selected: selected,
                        onSelected: (_) {
                          setState(() => _activeCategory = cat);
                          widget.onCategoryChanged(cat);
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _shownIndividualMenus.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: _menuGridAspectRatio,
                  ),
                  itemBuilder: (context, index) => _MenuGridButton(
                    item: _shownIndividualMenus[index],
                    currency: widget.currency,
                    onPressed: widget.onMenuSelected,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

const _menuGridAspectRatio = 2.0;
const _chipLabelStyle = TextStyle(fontSize: 15, fontWeight: FontWeight.w700);

class _MenuGridButton extends StatelessWidget {
  const _MenuGridButton({
    required this.item,
    required this.currency,
    required this.onPressed,
  });

  final MenuItem item;
  final NumberFormat currency;
  final ValueChanged<MenuItem> onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonal(
      onPressed: () => onPressed(item),
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            item.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            currency.format(item.priceTaxIncluded),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _FoodGoodsActionSection extends StatelessWidget {
  const _FoodGoodsActionSection({
    required this.onOpenFood,
    required this.onOpenGoods,
  });

  final VoidCallback onOpenFood;
  final VoidCallback onOpenGoods;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: _FoodGoodsActionRow(
        onOpenFood: onOpenFood,
        onOpenGoods: onOpenGoods,
      ),
    );
  }
}

class _FoodGoodsActionRow extends StatelessWidget {
  const _FoodGoodsActionRow({
    required this.onOpenFood,
    required this.onOpenGoods,
  });

  final VoidCallback onOpenFood;
  final VoidCallback onOpenGoods;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final buttonStyle = OutlinedButton.styleFrom(
      minimumSize: const Size(0, 52),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      backgroundColor: Colors.white,
      foregroundColor: colors.onSurface,
      side: BorderSide(color: colors.primary, width: 2),
      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
    );
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onOpenFood,
              style: buttonStyle,
              icon: Icon(Icons.restaurant_menu, size: 20, color: colors.primary),
              label: const Text('その他フード'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onOpenGoods,
              style: buttonStyle,
              icon: Icon(
                Icons.shopping_bag_outlined,
                size: 20,
                color: colors.primary,
              ),
              label: const Text('グッズ販売'),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyMenuState extends StatelessWidget {
  const _EmptyMenuState({
    required this.menuRepository,
    required this.seeding,
    required this.onSeedingChanged,
  });

  final MenuRepository menuRepository;
  final bool seeding;
  final ValueChanged<bool> onSeedingChanged;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('メニュー未登録です'),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: seeding
                  ? null
                  : () async {
                      final messenger = ScaffoldMessenger.of(context);
                      onSeedingChanged(true);
                      try {
                        await menuRepository.seedMenusFromAssetIfEmpty();
                        messenger.showSnackBar(
                          const SnackBar(content: Text('初期メニューを登録しました')),
                        );
                      } catch (error) {
                        messenger.showSnackBar(
                          SnackBar(content: Text('登録失敗: $error')),
                        );
                      } finally {
                        onSeedingChanged(false);
                      }
                    },
              child: Text(seeding ? '登録中...' : '初期メニューを登録'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () =>
                  Navigator.pushNamed(context, MenuEditPage.routeName),
              child: const Text('メニュー管理へ'),
            ),
          ],
        ),
      ),
    );
  }
}
