import 'package:ace_app/features/order/event_menu_tier_catalog.dart';
import 'package:ace_app/models/menu_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('eventMenuTierDefs', () {
    test('has expected slim group count and order', () {
      expect(
        eventMenuTierDefs.map((d) => d.groupKey).toList(),
        ['CHUHAI_SOUR', 'SOFT_DRINK', 'COCKTAIL', 'BEER'],
      );
    });

    test('chuhai sour tier prices match spec', () {
      final chuhai = eventMenuTierDefs.firstWhere(
        (d) => d.groupKey == 'CHUHAI_SOUR',
      );
      expect(chuhai.label, '酎ハイ・サワー');
      expect(chuhai.regularPrices, [550]);
      expect(chuhai.megaPrice, 880);
    });

    test('soft drink tier prices match spec', () {
      final soft = eventMenuTierDefs.firstWhere(
        (d) => d.groupKey == 'SOFT_DRINK',
      );
      expect(soft.regularPrices, [440]);
      expect(soft.megaPrice, 770);
    });

    test('cocktail has only 660', () {
      final cocktail = eventMenuTierDefs.firstWhere(
        (d) => d.groupKey == 'COCKTAIL',
      );
      expect(cocktail.regularPrices, [660]);
      expect(cocktail.megaPrice, isNull);
    });

    test('beer has 660 and 770', () {
      final beer = eventMenuTierDefs.firstWhere((d) => d.groupKey == 'BEER');
      expect(beer.regularPrices, [660, 770]);
      expect(beer.megaPrice, isNull);
    });
  });

  group('eventIndividualDisplayCategoryKey', () {
    test('merges tequila and others into shot', () {
      const tequila = MenuItem(
        id: 't1',
        name: 'テキーラ',
        category: 'TEQUILA',
        priceTaxIncluded: 500,
        isActive: true,
        sortOrder: 1,
      );
      const others = MenuItem(
        id: 'o1',
        name: 'イエガー',
        category: 'OTHERS',
        priceTaxIncluded: 500,
        isActive: true,
        sortOrder: 1,
      );
      expect(eventIndividualDisplayCategoryKey(tequila), kEventShotCategory);
      expect(eventIndividualDisplayCategoryKey(others), kEventShotCategory);
      expect(
        eventIndividualDisplayCategoryLabel(kEventShotCategory),
        'ショット',
      );
    });
  });

  group('isEventTierCategory', () {
    test('returns true for merged-away categories', () {
      expect(isEventTierCategory('SOUR'), isTrue);
      expect(isEventTierCategory('TEA_HAI'), isTrue);
      expect(isEventTierCategory('SHOCHO'), isTrue);
      expect(isEventTierCategory('WHISKY'), isTrue);
    });

    test('returns false for individual-only categories', () {
      expect(isEventTierCategory('CHAMPAGNE'), isFalse);
      expect(isEventTierCategory('TEQUILA'), isFalse);
      expect(isEventTierCategory('OTHERS'), isFalse);
    });
  });

  group('buildVirtualTierItem', () {
    test('regular chuhai sour item', () {
      final item = buildVirtualTierItem(
        groupKey: 'CHUHAI_SOUR',
        label: '酎ハイ・サワー',
        price: 550,
        isMega: false,
      );
      expect(item.id, 'event-tier::CHUHAI_SOUR::550');
      expect(item.name, '酎ハイ・サワー');
      expect(item.category, 'SOUR');
      expect(item.priceTaxIncluded, 550);
    });

    test('mega chuhai sour maps to SOUR_メガサイズ', () {
      final item = buildVirtualTierItem(
        groupKey: 'CHUHAI_SOUR',
        label: '酎ハイ・サワー',
        price: 880,
        isMega: true,
      );
      expect(item.id, 'event-tier::CHUHAI_SOUR::880:mega');
      expect(item.name, '酎ハイ・サワー（メガ）');
      expect(item.category, 'SOUR_メガサイズ');
    });

    test('mega soft drink maps to SOFT_DRINK_メガサイズ', () {
      final item = buildVirtualTierItem(
        groupKey: 'SOFT_DRINK',
        label: 'ソフトドリンク',
        price: 770,
        isMega: true,
      );
      expect(item.category, 'SOFT_DRINK_メガサイズ');
    });
  });

  group('buildAllEventTierMenuItems', () {
    test('generates unique ids', () {
      final items = buildAllEventTierMenuItems();
      final ids = items.map((i) => i.id).toList();
      expect(ids.length, ids.toSet().length);
    });

    test('total button count matches slim spec', () {
      // 4 groups: 2+2+1+2 = 7 buttons
      expect(buildAllEventTierMenuItems(), hasLength(7));
    });
  });
}
