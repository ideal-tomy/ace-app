import 'package:ace_app/core/drink_menu_family.dart';
import 'package:ace_app/models/menu_item.dart';
import 'package:flutter_test/flutter_test.dart';

MenuItem _menu(String name, String category, {int sortOrder = 10}) => MenuItem(
  id: '$category/$name',
  name: name,
  category: category,
  priceTaxIncluded: 550,
  isActive: true,
  sortOrder: sortOrder,
);

void main() {
  test('pairingKey はメガの接頭辞を除いて通常と一致する', () {
    expect(
      pairingKey(_menu('メガ緑茶ハイ', 'TEA_HAI_メガサイズ')),
      pairingKey(_menu('緑茶ハイ', 'TEA_HAI')),
    );
  });

  test('通常カテゴリの「メガ」始まりの名前はそのまま扱う', () {
    expect(
      displayNameForPair(_menu('メガハイボール（ブラックニッカ・角）', 'WHISKY')),
      'メガハイボール（ブラックニッカ・角）',
    );
  });

  test('categoryFor はサイズごとの category を返し、ビールはメガなし', () {
    final tea = familyForCategory('TEA_HAI_メガサイズ')!;
    expect(tea.key, 'tea_hai');
    expect(tea.categoryFor(DrinkSize.regular), 'TEA_HAI');
    expect(tea.categoryFor(DrinkSize.mega), 'TEA_HAI_メガサイズ');
    expect(familyForCategory('BEER')!.hasMega, isFalse);
    expect(familyForCategory('FOOD'), isNull);
  });

  test('イベント注文はテキーラ系ファミリーを末尾に並べる', () {
    final menus = [
      _menu('テキーラA', 'TEQUILA'),
      _menu('シャンパン', 'CHAMPAGNE'),
      _menu('レモン', 'SOUR'),
    ];
    final keys = drinkFamiliesForMenus(menus, eventOrdering: true)
        .map((f) => f.key)
        .toList();
    expect(keys.indexOf('sour'), lessThan(keys.indexOf('tequila')));
    expect(keys.indexOf('champagne'), lessThan(keys.indexOf('tequila')));
  });

  test('resolvedMegaName は「メガ」を一度だけ付ける', () {
    expect(resolvedMegaName(' 緑茶ハイ '), 'メガ緑茶ハイ');
    expect(resolvedMegaName('メガ緑茶ハイ'), 'メガ緑茶ハイ');
  });

  test('pairDrinkMenus は通常とメガを1行にまとめ、片方だけの行も残す', () {
    final family = familyForCategory('TEA_HAI')!;
    final pairs = pairDrinkMenus(family, [
      _menu('メガ緑茶ハイ', 'TEA_HAI_メガサイズ'),
      _menu('ウーロンハイ', 'TEA_HAI', sortOrder: 20),
      _menu('緑茶ハイ', 'TEA_HAI'),
      _menu('コーラ', 'SOFT_DRINK'),
    ]);
    expect(pairs.map((p) => p.displayName), ['緑茶ハイ', 'ウーロンハイ']);
    expect(pairs.first.mega?.name, 'メガ緑茶ハイ');
    expect(pairs.last.mega, isNull);
  });
}
