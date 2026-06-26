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
import '../order_custom_item_dialogs.dart';
import '../order_flow_state.dart';

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
            adminAuthService: widget.adminAuthService,
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

            final categories =
                sourceMenus
                    .map(
                      (m) => isNormalCheck
                          ? normalModeCategoryKey(m)
                          : m.category,
                    )
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
            final shown = sourceMenus.where((m) {
              if (!isNormalCheck) {
                return m.category == _activeCategory;
              }
              return normalModeCategoryKey(m) == _activeCategory;
            }).toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _openFoodOrderDialog,
                          icon: const Icon(Icons.restaurant_menu),
                          label: const Text('フード追加'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _openDartsGoodsDialog,
                          icon: const Icon(Icons.shopping_bag_outlined),
                          label: const Text('グッズ販売'),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isNormalCheck)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      '通常営業中: 例外ドリンクのみ注文できます',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                if (isNormalCheck) const SizedBox(height: 6),
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
                      final categoryLabel = isNormalCheck
                          ? normalModeCategoryLabel(cat)
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
                    padding: const EdgeInsets.symmetric(horizontal: 16),
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
                        onPressed: () => widget.onMenuSelected(item),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              item.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
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
        );
      },
    );
  }
}

class _EmptyMenuState extends StatelessWidget {
  const _EmptyMenuState({
    required this.adminAuthService,
    required this.menuRepository,
    required this.seeding,
    required this.onSeedingChanged,
  });

  final AdminAuthService adminAuthService;
  final MenuRepository menuRepository;
  final bool seeding;
  final ValueChanged<bool> onSeedingChanged;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: adminAuthService.isCurrentUserAnonymous
          ? Future<bool>.value(false)
          : adminAuthService.isCurrentUserAdmin(),
      builder: (context, adminSnapshot) {
        final isAdmin = adminSnapshot.data == true;
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
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
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: (seeding || !isAdmin)
                      ? null
                      : () async {
                          final messenger = ScaffoldMessenger.of(context);
                          onSeedingChanged(true);
                          try {
                            await menuRepository.seedMenusFromAssetIfEmpty();
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('初期メニューを登録しました'),
                              ),
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
          ),
        );
      },
    );
  }
}
