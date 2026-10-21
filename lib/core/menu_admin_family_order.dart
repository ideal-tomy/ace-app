import 'drink_menu_family.dart';

/// Firestore `stores/{storeId}.adminMenuFamilyOrder` に保存するファミリー key の並び。
const kAdminMenuFamilyOrderField = 'adminMenuFamilyOrder';

List<String> defaultDrinkFamilyOrderKeys() =>
    drinkMenuFamilies.map((f) => f.key).toList();

/// 保存値とコード上の定義をマージ（新規ファミリーは末尾、不明 key は除外）。
List<String> resolveDrinkFamilyOrderKeys(List<String>? stored) {
  final defaults = defaultDrinkFamilyOrderKeys();
  if (stored == null || stored.isEmpty) return defaults;
  final result = <String>[];
  for (final key in stored) {
    if (defaults.contains(key) && !result.contains(key)) {
      result.add(key);
    }
  }
  for (final key in defaults) {
    if (!result.contains(key)) result.add(key);
  }
  return result;
}

List<DrinkMenuFamily> sortDrinkFamiliesByOrderKeys(
  Iterable<DrinkMenuFamily> families,
  List<String> orderKeys,
) {
  final index = <String, int>{};
  for (var i = 0; i < orderKeys.length; i++) {
    index[orderKeys[i]] = i;
  }
  final list = families.toList();
  list.sort((a, b) {
    final ia = index[a.key] ?? 9999;
    final ib = index[b.key] ?? 9999;
    if (ia != ib) return ia.compareTo(ib);
    return a.key.compareTo(b.key);
  });
  return list;
}

/// 一覧で見えているファミリーだけ並べ替えたあと、全体の順序リストを更新する。
List<String> applyVisibleFamilyReorder({
  required List<String> fullOrder,
  required List<String> visibleKeys,
  required int oldIndex,
  required int newIndex,
}) {
  if (visibleKeys.isEmpty) return fullOrder;
  var target = newIndex;
  if (target > oldIndex) target--;
  final reorderedVisible = List<String>.from(visibleKeys);
  final moved = reorderedVisible.removeAt(oldIndex);
  reorderedVisible.insert(target, moved);

  final visibleSet = reorderedVisible.toSet();
  var vi = 0;
  return [
    for (final key in fullOrder)
      if (visibleSet.contains(key)) reorderedVisible[vi++] else key,
  ];
}
