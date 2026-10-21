import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/drink_family_theme.dart';
import '../../../core/drink_menu_family.dart';
import '../../../core/menu_admin_family_order.dart';
import '../../../data/repositories/check_repository.dart';
import '../../../data/repositories/store_settings_repository.dart';
import '../../../models/check_item.dart';
import '../../../models/menu_item.dart';
import '../kocha_hai_order.dart';

const _menuGridAspectRatio = 2.0;
const _sizeLabelStyle = TextStyle(fontSize: 14, fontWeight: FontWeight.w700);

/// ファミリ色チップ → 通常／メガ → 商品グリッド＋直近再注文。
class OrderDrinkFamilyPanel extends StatefulWidget {
  const OrderDrinkFamilyPanel({
    super.key,
    required this.sourceMenus,
    required this.isNormalCheck,
    required this.eventOrdering,
    required this.checkRepository,
    required this.openCheckId,
    required this.currency,
    required this.onMenuSelected,
    this.onReorderMissing,
  });

  final List<MenuItem> sourceMenus;
  final bool isNormalCheck;
  final bool eventOrdering;
  final CheckRepository checkRepository;
  final String openCheckId;
  final NumberFormat currency;
  final ValueChanged<MenuItem> onMenuSelected;
  final VoidCallback? onReorderMissing;

  @override
  State<OrderDrinkFamilyPanel> createState() => _OrderDrinkFamilyPanelState();
}

class _OrderDrinkFamilyPanelState extends State<OrderDrinkFamilyPanel> {
  String? _activeTabKey;
  DrinkSize _size = DrinkSize.regular;
  late final Stream<List<String>?> _familyOrderStream = Firebase.apps.isEmpty
      ? Stream<List<String>?>.value(null)
      : StoreSettingsRepository().streamDrinkFamilyOrderKeys();

  List<DrinkOrderTab> _tabsFor(List<String>? familyOrderKeys) =>
      drinkOrderTabsForMenus(
        widget.sourceMenus,
        eventOrdering: widget.eventOrdering,
        familyOrderKeys: familyOrderKeys,
      );

  String _effectiveTabKey(List<DrinkOrderTab> tabs) {
    if (_activeTabKey != null && tabs.any((t) => t.key == _activeTabKey)) {
      return _activeTabKey!;
    }
    return tabs.first.key;
  }

  Future<void> _selectMenu(MenuItem menu) async {
    final resolved = await pickKochaHaiSugarIfNeeded(context, menu);
    if (resolved != null) widget.onMenuSelected(resolved);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<String>?>(
      stream: _familyOrderStream,
      builder: (context, orderSnapshot) {
        final tabs = _tabsFor(orderSnapshot.data);
        if (tabs.isEmpty) {
          return const Center(child: Text('表示可能なドリンクがありません'));
        }
        return _buildPanel(context, tabs);
      },
    );
  }

  Widget _buildPanel(BuildContext context, List<DrinkOrderTab> tabs) {
    final activeKey = _effectiveTabKey(tabs);
    final tab = tabs.firstWhere((t) => t.key == activeKey);
    final size = tab.hasMega ? _size : DrinkSize.regular;
    final pairs = pairDrinkMenusForTab(tab, widget.sourceMenus);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.isNormalCheck) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Text(
              '通常営業中: 例外ドリンクのみ注文できます',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: 6),
        ],
        StreamBuilder<List<CheckItem>>(
          stream: widget.checkRepository.streamCheckItems(widget.openCheckId),
          builder: (context, snap) {
            final items = snap.data ?? const <CheckItem>[];
            final recent = recentDrinkSnapshots(items);
            if (recent.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'この伝票の直近',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 40,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: recent.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final snap = recent[index];
                        return ActionChip(
                          label: Text(
                            snap.menuName,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          onPressed: () => _reorder(snap),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        SizedBox(
          height: 44,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: tabs.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final t = tabs[index];
              final selected = t.key == activeKey;
              final color = DrinkFamilyTheme.colorForFamilyKey(t.themeKey);
              final fill = selected ? color.withValues(alpha: 0.95) : color;
              return ChoiceChip(
                key: ValueKey(t.key),
                label: DrinkFamilyStrokeLabel(text: t.label, fillColor: fill),
                selected: selected,
                selectedColor: color.withValues(alpha: 0.22),
                backgroundColor: color.withValues(alpha: 0.08),
                side: BorderSide(
                  color: selected
                      ? color.withValues(alpha: 0.85)
                      : color.withValues(alpha: 0.35),
                  width: selected ? 2 : 1,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                onSelected: (_) => setState(() {
                  _activeTabKey = t.key;
                  if (!t.hasMega) _size = DrinkSize.regular;
                }),
              );
            },
          ),
        ),
        if (tab.hasMega) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<DrinkSize>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: DrinkSize.regular,
                  label: Text('通常', style: _sizeLabelStyle),
                ),
                ButtonSegment(
                  value: DrinkSize.mega,
                  label: Text('メガ', style: _sizeLabelStyle),
                ),
              ],
              selected: {size},
              onSelectionChanged: (s) => setState(() => _size = s.first),
            ),
          ),
        ],
        const SizedBox(height: 8),
        Expanded(
          child: pairs.isEmpty
              ? const Center(child: Text('この種類のメニューはありません'))
              : GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: pairs.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: _menuGridAspectRatio,
                  ),
                  itemBuilder: (context, index) {
                    final pair = pairs[index];
                    final item = size == DrinkSize.mega
                        ? pair.mega
                        : pair.regular;
                    final fallback = pair.regular ?? pair.mega;
                    final menu = item ?? fallback;
                    if (menu == null) return const SizedBox.shrink();
                    final disabled = item == null;
                    final label = kochaHaiGridLabel(menu, pair.displayName);
                    return _PairGridButton(
                      displayName: label,
                      menu: menu,
                      disabled: disabled,
                      currency: widget.currency,
                      onPressed: _selectMenu,
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _reorder(CheckItemSnapshot snap) {
    final menu = resolveMenuForReorder(
      snapshot: snap,
      catalog: widget.sourceMenus,
    );
    if (menu == null) {
      widget.onReorderMissing?.call();
      return;
    }
    if (needsKochaHaiSugarPick(menu)) {
      _selectMenu(menu);
      return;
    }
    widget.onMenuSelected(menu);
  }
}

class _PairGridButton extends StatelessWidget {
  const _PairGridButton({
    required this.displayName,
    required this.menu,
    required this.disabled,
    required this.currency,
    required this.onPressed,
  });

  final String displayName;
  final MenuItem menu;
  final bool disabled;
  final NumberFormat currency;
  final Future<void> Function(MenuItem menu) onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonal(
      onPressed: disabled ? null : () => onPressed(menu),
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            displayName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              height: 1.2,
              color: disabled
                  ? Theme.of(context).colorScheme.onSurface.withValues(
                      alpha: 0.38,
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            disabled ? '—' : currency.format(menu.priceTaxIncluded),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: disabled
                  ? Theme.of(context).colorScheme.onSurface.withValues(
                      alpha: 0.38,
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}
