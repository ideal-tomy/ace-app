import 'package:ace_app/core/menu_admin_family_order.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('applyVisibleFamilyReorder は非表示ファミリーの順序を保つ', () {
    const full = ['a', 'b', 'c', 'd', 'e'];
    const visible = ['a', 'c', 'e'];
    final next = applyVisibleFamilyReorder(
      fullOrder: full,
      visibleKeys: visible,
      oldIndex: 0,
      newIndex: 2,
    );
    expect(next, ['c', 'b', 'a', 'd', 'e']);
  });

  test('resolveDrinkFamilyOrderKeys は未知 key を除き新規を末尾に足す', () {
    final resolved = resolveDrinkFamilyOrderKeys(['soft', 'unknown', 'beer']);
    expect(resolved.first, 'soft');
    expect(resolved.contains('beer'), isTrue);
    expect(resolved.contains('unknown'), isFalse);
    expect(resolved.length, defaultDrinkFamilyOrderKeys().length);
  });
}
