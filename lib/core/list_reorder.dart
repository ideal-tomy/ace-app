/// [ReorderableListView.onReorder] 用のリスト並べ替え。
List<T> reorderListAt<T>(List<T> items, int oldIndex, int newIndex) {
  if (items.isEmpty || oldIndex == newIndex) return items;
  var target = newIndex;
  if (target > oldIndex) target--;
  final copy = List<T>.from(items);
  final moved = copy.removeAt(oldIndex);
  copy.insert(target, moved);
  return copy;
}

Map<String, int> sortOrdersForOrderedIds(
  List<String> menuIds, {
  int step = 10,
}) {
  final result = <String, int>{};
  for (var i = 0; i < menuIds.length; i++) {
    result[menuIds[i]] = (i + 1) * step;
  }
  return result;
}
