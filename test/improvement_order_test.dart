import 'package:ace_app/core/japanese_name_order.dart';
import 'package:ace_app/data/repositories/menu_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/memory_firestore.dart';

void main() {
  test('日本語表示名を照合し、読みを補わない', () {
    expect(compareJapaneseNames('あおき', 'やまだ'), lessThan(0));
    expect(compareJapaneseNames('  あおき ', 'あおき'), 0);
    final forward = compareJapaneseNames('佐藤', '鈴木');
    final reverse = compareJapaneseNames('鈴木', '佐藤');
    expect(forward.sign, -reverse.sign);
  });

  test('フードは価格・名前・IDで安定し、グッズがドリンクに混ざらない', () async {
    final store = MemoryFirestore();
    for (final row in [
      ('expensive', '唐揚げ', 'FOOD', 900, true),
      ('b', 'あえもの', 'FOOD', 300, true),
      ('a', 'あえもの', 'FOOD', 300, true),
      ('hidden', '休止', 'FOOD', 200, false),
      ('goods', 'Tシャツ', 'DARTS_GOODS', 2000, true),
      ('drink', 'ビール', 'BEER', 600, true),
    ]) {
      store.documents['stores/test/menus/${row.$1}'] = {
        'name': row.$2,
        'category': row.$3,
        'priceTaxIncluded': row.$4,
        'isActive': row.$5,
        'sortOrder': 10,
      };
    }
    final menus = MenuRepository(firestore: store, storeId: 'test');
    expect((await menus.streamActiveFoodMenus().first).map((m) => m.id), [
      'a',
      'b',
      'expensive',
    ]);
    expect((await menus.streamActiveGoodsMenus().first).single.id, 'goods');
    expect((await menus.streamActiveMenus().first).single.id, 'drink');
    expect(store.documents['stores/test/menus/expensive']!['sortOrder'], 10);
  });
}
