import 'package:ace_app/core/list_reorder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reorderListAt は要素を移動する', () {
    expect(reorderListAt(['a', 'b', 'c'], 0, 2), ['b', 'a', 'c']);
  });

  test('sortOrdersForOrderedIds は 10 刻みの sortOrder を付与する', () {
    expect(
      sortOrdersForOrderedIds(['x', 'y']),
      {'x': 10, 'y': 20},
    );
  });
}
