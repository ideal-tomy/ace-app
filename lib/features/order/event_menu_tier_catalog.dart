import '../../models/menu_item.dart';

/// イベント営業の個別グリッドでテキーラ＋アザーを統合表示する仮想カテゴリ。
const kEventShotCategory = 'EVENT_SHOT';

/// イベント営業時の価格帯注文定義。
class EventMenuTierDef {
  const EventMenuTierDef({
    required this.groupKey,
    required this.label,
    required this.regularPrices,
    this.megaPrice,
  });

  final String groupKey;
  final String label;
  final List<int> regularPrices;
  final int? megaPrice;
}

/// イベント営業で価格帯ボタン表示するカテゴリ（個別グリッドから除外）。
const eventTierCategoryKeys = {
  'SOUR',
  'SOUR_メガサイズ',
  'TEA_HAI',
  'TEA_HAI_メガサイズ',
  'SOFT_DRINK',
  'SOFT_DRINK_メガサイズ',
  'SHOCHO',
  'WHISKY',
  'COCKTAIL',
  'BEER',
  'BOTTLE',
  'PITCHER',
};

/// イベント営業で個別グリッド表示する元カテゴリ。
const eventIndividualCategoryKeys = {
  'CHAMPAGNE',
  'TEQUILA',
  'OTHERS',
};

const _regularCategoryByGroupKey = {
  'CHUHAI_SOUR': 'SOUR',
};

const _megaCategoryByGroupKey = {
  'CHUHAI_SOUR': 'SOUR_メガサイズ',
  'SOFT_DRINK': 'SOFT_DRINK_メガサイズ',
};

/// 価格帯ボタン定義（表示順）。
const eventMenuTierDefs = [
  EventMenuTierDef(
    groupKey: 'CHUHAI_SOUR',
    label: '酎ハイ・サワー',
    regularPrices: [550],
    megaPrice: 880,
  ),
  EventMenuTierDef(
    groupKey: 'SOFT_DRINK',
    label: 'ソフトドリンク',
    regularPrices: [440],
    megaPrice: 770,
  ),
  EventMenuTierDef(
    groupKey: 'COCKTAIL',
    label: 'カクテル',
    regularPrices: [660],
  ),
  EventMenuTierDef(
    groupKey: 'BEER',
    label: 'ビール',
    regularPrices: [660, 770],
  ),
  EventMenuTierDef(
    groupKey: 'BOTTLE',
    label: 'ボトル',
    regularPrices: [2500],
  ),
  EventMenuTierDef(
    groupKey: 'PITCHER',
    label: 'ピッチャー',
    regularPrices: [800],
  ),
];

bool isEventTierCategory(String category) {
  return eventTierCategoryKeys.contains(category);
}

bool isEventIndividualCategory(String category) {
  return eventIndividualCategoryKeys.contains(category);
}

String eventIndividualDisplayCategoryKey(MenuItem item) {
  if (item.category == 'TEQUILA' || item.category == 'OTHERS') {
    return kEventShotCategory;
  }
  return item.category;
}

String eventIndividualDisplayCategoryLabel(String categoryKey) {
  if (categoryKey == kEventShotCategory) return 'ショット';
  if (categoryKey == 'CHAMPAGNE') return 'シャンパン';
  return categoryKey;
}

String regularCategoryForGroupKey(String groupKey) {
  return _regularCategoryByGroupKey[groupKey] ?? groupKey;
}

String megaCategoryForGroupKey(String groupKey) {
  return _megaCategoryByGroupKey[groupKey] ?? groupKey;
}

MenuItem buildVirtualTierItem({
  required String groupKey,
  required String label,
  required int price,
  required bool isMega,
}) {
  final suffix = isMega ? ':mega' : '';
  return MenuItem(
    id: 'event-tier::$groupKey::$price$suffix',
    name: isMega ? '$label（メガ）' : label,
    category: isMega
        ? megaCategoryForGroupKey(groupKey)
        : regularCategoryForGroupKey(groupKey),
    priceTaxIncluded: price,
    isActive: true,
    sortOrder: 0,
  );
}

/// 全価格帯グループの仮想 [MenuItem] をフラットに返す。
List<MenuItem> buildAllEventTierMenuItems() {
  final items = <MenuItem>[];
  for (final def in eventMenuTierDefs) {
    for (final price in def.regularPrices) {
      items.add(
        buildVirtualTierItem(
          groupKey: def.groupKey,
          label: def.label,
          price: price,
          isMega: false,
        ),
      );
    }
    final mega = def.megaPrice;
    if (mega != null) {
      items.add(
        buildVirtualTierItem(
          groupKey: def.groupKey,
          label: def.label,
          price: mega,
          isMega: true,
        ),
      );
    }
  }
  return items;
}
