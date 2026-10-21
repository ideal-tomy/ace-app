import 'package:flutter/material.dart';

import '../../core/drink_menu_family.dart';
import '../../models/menu_item.dart';

const _combinedSugarMarker = '（無糖・加糖）';

/// 注文時に無糖／加糖を選ばせる紅茶ハイ（マスタは複合表記の1件）。
bool needsKochaHaiSugarPick(MenuItem menu) {
  return menu.name.contains('紅茶ハイ') && menu.name.contains(_combinedSugarMarker);
}

enum KochaHaiSugar { unsweetened, sweetened }

String _suffix(KochaHaiSugar sugar) =>
    sugar == KochaHaiSugar.unsweetened ? '（無糖）' : '（加糖）';

MenuItem menuWithKochaHaiSugar(MenuItem menu, KochaHaiSugar sugar) {
  final name = menu.name.replaceFirst(_combinedSugarMarker, _suffix(sugar));
  return MenuItem(
    id: '${menu.id}::kocha_${sugar.name}',
    name: name,
    category: menu.category,
    priceTaxIncluded: menu.priceTaxIncluded,
    isActive: menu.isActive,
    sortOrder: menu.sortOrder,
  );
}

/// グリッド表示用。複合表記は「紅茶ハイ」に短縮。
String kochaHaiGridLabel(MenuItem menu, String pairDisplayName) {
  if (needsKochaHaiSugarPick(menu)) {
    return pairDisplayName.replaceFirst(_combinedSugarMarker, '');
  }
  return pairDisplayName;
}

Future<MenuItem?> pickKochaHaiSugarIfNeeded(
  BuildContext context,
  MenuItem menu,
) async {
  if (!needsKochaHaiSugarPick(menu)) return menu;

  final sugar = await showModalBottomSheet<KochaHaiSugar>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '紅茶ハイ',
              style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(ctx, KochaHaiSugar.unsweetened),
              child: const Text('無糖', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 8),
            FilledButton.tonal(
              onPressed: () =>
                  Navigator.pop(ctx, KochaHaiSugar.sweetened),
              child: const Text('加糖', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    ),
  );
  if (sugar == null) return null;
  return menuWithKochaHaiSugar(menu, sugar);
}

/// 直近チップ・カタログ照合（紅茶ハイの無糖／加糖名を解決）。
MenuItem? resolveMenuForReorder({
  required CheckItemSnapshot snapshot,
  required Iterable<MenuItem> catalog,
}) {
  final direct = resolveMenuFromCatalog(
    snapshot: snapshot,
    catalog: catalog,
  );
  if (direct != null && !needsKochaHaiSugarPick(direct)) return direct;

  if (snapshot.menuName.contains('紅茶ハイ')) {
    MenuItem? base;
    for (final m in catalog) {
      if (needsKochaHaiSugarPick(m)) {
        base = m;
        break;
      }
    }
    if (base != null) {
      if (snapshot.menuName.contains('（無糖）')) {
        return menuWithKochaHaiSugar(base, KochaHaiSugar.unsweetened);
      }
      if (snapshot.menuName.contains('（加糖）')) {
        return menuWithKochaHaiSugar(base, KochaHaiSugar.sweetened);
      }
      if (direct != null) return direct;
    }
  }
  return direct;
}
