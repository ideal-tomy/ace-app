import '../models/check_item.dart';
import '../models/menu_item.dart';
import 'food_menu.dart';
import 'menu_category_catalog.dart';

enum DrinkSize { regular, mega }

const kMegaNamePrefix = 'メガ';

/// 管理画面でまとめて扱うドリンクの種類。通常とメガは Firestore 上は別 category。
class DrinkMenuFamily {
  const DrinkMenuFamily({
    required this.key,
    required this.regularCategory,
    required this.regularQuickPrices,
    this.megaCategory,
    this.megaQuickPrices = const [],
  });

  final String key;
  final String regularCategory;
  final String? megaCategory;
  final List<int> regularQuickPrices;
  final List<int> megaQuickPrices;

  String get label => MenuCategoryCatalog.labelFor(regularCategory);

  bool get hasMega => megaCategory != null;

  String categoryFor(DrinkSize size) =>
      size == DrinkSize.mega ? megaCategory! : regularCategory;

  List<int> quickPricesFor(DrinkSize size) =>
      size == DrinkSize.mega ? megaQuickPrices : regularQuickPrices;

  bool contains(String category) =>
      category == regularCategory || category == megaCategory;
}

const drinkMenuFamilies = [
  DrinkMenuFamily(
    key: 'sour',
    regularCategory: 'SOUR',
    megaCategory: 'SOUR_メガサイズ',
    regularQuickPrices: [550, 660, 770],
    megaQuickPrices: [880],
  ),
  DrinkMenuFamily(
    key: 'tea_hai',
    regularCategory: 'TEA_HAI',
    megaCategory: 'TEA_HAI_メガサイズ',
    regularQuickPrices: [550],
    megaQuickPrices: [880],
  ),
  DrinkMenuFamily(
    key: 'soft',
    regularCategory: 'SOFT_DRINK',
    megaCategory: 'SOFT_DRINK_メガサイズ',
    regularQuickPrices: [440, 550],
    megaQuickPrices: [770],
  ),
  DrinkMenuFamily(
    key: 'beer',
    regularCategory: 'BEER',
    regularQuickPrices: [660, 770],
  ),
  DrinkMenuFamily(
    key: 'cocktail',
    regularCategory: 'COCKTAIL',
    regularQuickPrices: [660, 770],
  ),
  DrinkMenuFamily(
    key: 'whisky',
    regularCategory: 'WHISKY',
    regularQuickPrices: [550, 660, 880],
  ),
  DrinkMenuFamily(
    key: 'shochu',
    regularCategory: 'SHOCHO',
    regularQuickPrices: [660, 770],
  ),
  DrinkMenuFamily(
    key: 'champagne',
    regularCategory: 'CHAMPAGNE',
    regularQuickPrices: [5500, 6600, 10000],
  ),
  DrinkMenuFamily(
    key: 'tequila',
    regularCategory: 'TEQUILA',
    regularQuickPrices: [500],
  ),
  DrinkMenuFamily(
    key: 'others',
    regularCategory: 'OTHERS',
    regularQuickPrices: [500, 700, 1000],
  ),
  DrinkMenuFamily(
    key: 'bottle',
    regularCategory: 'BOTTLE',
    regularQuickPrices: [2500],
  ),
  DrinkMenuFamily(
    key: 'pitcher',
    regularCategory: 'PITCHER',
    regularQuickPrices: [800],
  ),
];

/// [menus] に1件以上含まれるファミリーだけ、表示順で返す。
List<DrinkMenuFamily> drinkFamiliesForMenus(
  Iterable<MenuItem> menus, {
  required bool eventOrdering,
}) {
  final visible = drinkMenuFamilies
      .where((f) => menus.any((m) => f.contains(m.category)))
      .toList();
  visible.sort((a, b) {
    if (eventOrdering) {
      final aLate = _isLateFamily(a.key);
      final bLate = _isLateFamily(b.key);
      if (aLate != bLate) return aLate ? 1 : -1;
    } else {
      if (a.key == 'tequila') return b.key == 'tequila' ? 0 : -1;
      if (b.key == 'tequila') return 1;
      if (a.key == 'others') return b.key == 'others' ? 0 : -1;
      if (b.key == 'others') return 1;
    }
    final ra = MenuCategoryCatalog.compareKeys(
      a.regularCategory,
      b.regularCategory,
    );
    return ra != 0 ? ra : a.key.compareTo(b.key);
  });
  return visible;
}

bool _isLateFamily(String key) => key == 'tequila' || key == 'others';

/// 注文の再送用に、スナップショットからカタログの [MenuItem] を探す。
MenuItem? resolveMenuFromCatalog({
  required CheckItemSnapshot snapshot,
  required Iterable<MenuItem> catalog,
}) {
  for (final m in catalog) {
    if (snapshot.menuId != null && m.id == snapshot.menuId) return m;
  }
  for (final m in catalog) {
    if (m.name == snapshot.menuName &&
        m.category == snapshot.menuCategory &&
        m.priceTaxIncluded == snapshot.unitPrice) {
      return m;
    }
  }
  return null;
}

/// 伝票明細から直近再注文用のスナップショット。
class CheckItemSnapshot {
  const CheckItemSnapshot({
    this.menuId,
    required this.menuName,
    required this.menuCategory,
    required this.unitPrice,
    required this.orderedAt,
  });

  final String? menuId;
  final String menuName;
  final String menuCategory;
  final int unitPrice;
  final DateTime orderedAt;

  String get dedupeKey =>
      '${menuId ?? ''}|$menuCategory|$menuName|$unitPrice';
}

List<CheckItemSnapshot> recentDrinkSnapshots(
  Iterable<CheckItem> items, {
  int limit = 5,
}) {
  final sorted = items.toList()
    ..sort((a, b) => b.orderedAt.compareTo(a.orderedAt));
  final seen = <String>{};
  final out = <CheckItemSnapshot>[];
  for (final item in sorted) {
    final snap = CheckItemSnapshot(
      menuId: item.menuId,
      menuName: item.menuNameSnapshot,
      menuCategory: item.menuCategorySnapshot,
      unitPrice: item.unitPriceTaxIncluded,
      orderedAt: item.orderedAt,
    );
    if (seen.add(snap.dedupeKey)) {
      out.add(snap);
      if (out.length >= limit) break;
    }
  }
  return out;
}

DrinkMenuFamily? familyForCategory(String category) {
  for (final family in drinkMenuFamilies) {
    if (family.contains(category)) return family;
  }
  return null;
}

bool isMegaCategory(String category) =>
    familyForCategory(category)?.megaCategory == category;

/// 一覧に出す共通名。メガ側は先頭の「メガ」を除く。
String displayNameForPair(MenuItem item) {
  final name = item.name.trim();
  if (isMegaCategory(item.category) && name.startsWith(kMegaNamePrefix)) {
    return name.substring(kMegaNamePrefix.length).trim();
  }
  return name;
}

/// 通常とメガを同じ行にまとめるためのキー。
String pairingKey(MenuItem item) =>
    normalizeFoodMenuName(displayNameForPair(item));

/// メガ登録時の保存名。既に「メガ」で始まる場合はそのまま。
String resolvedMegaName(String baseName) {
  final trimmed = baseName.trim();
  return trimmed.startsWith(kMegaNamePrefix)
      ? trimmed
      : '$kMegaNamePrefix$trimmed';
}

class DrinkMenuPair {
  DrinkMenuPair({required this.displayName, this.regular, this.mega});

  final String displayName;
  MenuItem? regular;
  MenuItem? mega;
}

/// [menus] のうち [family] に属するものを通常／メガの行にまとめる（通常の並び順優先）。
List<DrinkMenuPair> pairDrinkMenus(
  DrinkMenuFamily family,
  Iterable<MenuItem> menus,
) {
  final sorted = menus.where((m) => family.contains(m.category)).toList()
    ..sort((a, b) {
      final aMega = isMegaCategory(a.category) ? 1 : 0;
      final bMega = isMegaCategory(b.category) ? 1 : 0;
      if (aMega != bMega) return aMega.compareTo(bMega);
      return a.sortOrder.compareTo(b.sortOrder);
    });
  final pairs = <DrinkMenuPair>[];
  for (final m in sorted) {
    final mega = isMegaCategory(m.category);
    final key = pairingKey(m);
    // 同名の重複データがあっても隠さないよう、空いている側がある行にだけ入れる。
    var pair = pairs
        .where(
          (p) =>
              normalizeFoodMenuName(p.displayName) == key &&
              (mega ? p.mega : p.regular) == null,
        )
        .firstOrNull;
    if (pair == null) {
      pair = DrinkMenuPair(displayName: displayNameForPair(m));
      pairs.add(pair);
    }
    if (mega) {
      pair.mega = m;
    } else {
      pair.regular = m;
    }
  }
  return pairs;
}
