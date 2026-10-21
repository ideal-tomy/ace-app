import 'package:ace_app/features/order/kocha_hai_order.dart';
import 'package:ace_app/models/menu_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final base = MenuItem(
    id: 'tea-kocha',
    name: '紅茶ハイ（無糖・加糖）',
    category: 'TEA_HAI',
    priceTaxIncluded: 550,
    isActive: true,
    sortOrder: 50,
  );

  test('無糖・加糖で別名の MenuItem になる', () {
    final unsweet = menuWithKochaHaiSugar(base, KochaHaiSugar.unsweetened);
    expect(unsweet.name, '紅茶ハイ（無糖）');
    final sweet = menuWithKochaHaiSugar(base, KochaHaiSugar.sweetened);
    expect(sweet.name, '紅茶ハイ（加糖）');
    expect(unsweet.id, isNot(sweet.id));
  });
}
