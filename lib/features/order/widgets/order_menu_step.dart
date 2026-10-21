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
import 'order_drink_family_panel.dart';

enum _MenuTab { drink, food, goods }

const _menuTabLabelStyle = TextStyle(
  fontSize: 14,
  fontWeight: FontWeight.w700,
);

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
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: _MenuTab.drink,
                label: Text('ドリンク', style: _menuTabLabelStyle),
              ),
              ButtonSegment(
                value: _MenuTab.food,
                label: Text('フード', style: _menuTabLabelStyle),
              ),
              ButtonSegment(
                value: _MenuTab.goods,
                label: Text('グッズ', style: _menuTabLabelStyle),
              ),
            ],
            selected: {_tab},
            onSelectionChanged: (s) => setState(() => _tab = s.first),
          ),
        ),
        Expanded(
          child: switch (_tab) {
            _MenuTab.drink => _buildDrinkTab(),
            _MenuTab.food => _buildFoodTab(),
            _MenuTab.goods => _buildGoodsTab(),
          },
        ),
      ],
    );
  }

  Widget _buildFoodTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: OutlinedButton(
            onPressed: _openFoodOrderDialog,
            child: const Text('その他フード'),
          ),
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
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  mainAxisExtent:
                      96 * MediaQuery.textScalerOf(context).scale(16) / 16,
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

  Widget _buildGoodsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: OutlinedButton(
            onPressed: _openDartsGoodsDialog,
            child: const Text('グッズを手入力'),
          ),
        ),
        Expanded(
          child: StreamBuilder<List<MenuItem>>(
            stream: widget.menuRepository.streamActiveGoodsMenus(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('メニュー取得エラー: ${snapshot.error}'));
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final goods = snapshot.data!;
              if (goods.isEmpty) {
                return const Center(child: Text('登録されたグッズがありません'));
              }
              return GridView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: goods.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: _menuGridAspectRatio,
                ),
                itemBuilder: (context, index) => _MenuGridButton(
                  item: goods[index],
                  currency: _currency,
                  onPressed: widget.onMenuSelected,
                ),
              );
            },
          ),
        ),
        TextButton.icon(
          onPressed: () => Navigator.pushNamed(
            context,
            MenuEditPage.routeName,
            arguments: MenuRegisterKind.goods,
          ),
          icon: const Icon(Icons.edit_note),
          label: const Text('グッズメニューを管理'),
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
            final checkMode =
                checkSummarySnapshot.data?.billingMode ??
                widget.person.billingMode;
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

            return OrderDrinkFamilyPanel(
              sourceMenus: sourceMenus,
              isNormalCheck: isNormalCheck,
              eventOrdering: !isNormalCheck,
              checkRepository: widget.checkRepository,
              openCheckId: widget.person.openCheckId,
              currency: _currency,
              onMenuSelected: widget.onMenuSelected,
              onReorderMissing: () {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('メニューが見つかりません。一覧から選んでください'),
                  ),
                );
              },
            );
          },
        );
      },
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
